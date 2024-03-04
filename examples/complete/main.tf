provider "aws" {
  region = var.region
}

module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  # This is the preferred way to add attributes. It will put "cluster" last
  # after any attributes set in `var.attributes` or `context.attributes`.
  # In this case, we do not care, because we are only using this instance
  # of this module to create tags.
  attributes = ["cluster"]

  context = module.this.context
}

locals {
  # The usage of the specific kubernetes.io/cluster/* resource tags below are required
  # for EKS and Kubernetes to discover and manage networking resources
  # https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html#base-vpc-networking
  tags = try(merge(module.label.tags, tomap("kubernetes.io/cluster/${module.label.id}", "shared")), null)

  # Unfortunately, most_recent (https://github.com/cloudposse/terraform-aws-eks-workers/blob/34a43c25624a6efb3ba5d2770a601d7cb3c0d391/main.tf#L141)
  # variable does not work as expected, if you are not going to use custom ami you should
  # enforce usage of eks_worker_ami_name_filter variable to set the right kubernetes version for EKS workers,
  # otherwise will be used the first version of Kubernetes supported by AWS (v1.11) for EKS workers but
  # EKS control plane will use the version specified by kubernetes_version variable.
  eks_worker_ami_name_filter = "amazon-eks-node-${var.kubernetes_version}*"

  allow_all_ingress_rule = {
    key              = "allow_all_ingress"
    type             = "ingress"
    from_port        = 0
    to_port          = 0 # [sic] from and to port ignored when protocol is "-1", warning if not zero
    protocol         = "-1"
    description      = "Allow all ingress"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  allow_http_ingress_rule = {
    key              = "http"
    type             = "ingress"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    description      = "Allow HTTP ingress"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  extra_policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.1.0"

  ipv4_primary_cidr_block = var.vpc_cidr_block
  tags                    = local.tags

  context = module.this.context
}

module "subnets" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.4.1"

  availability_zones = var.availability_zones
  vpc_id             = module.vpc.vpc_id
  igw_id             = [module.vpc.igw_id]
  ipv4_cidr_block    = [module.vpc.vpc_cidr_block]

  # Need to create NAT gateway since the Fargate nodes are provisioned only in private subnets, and the nodes need to join the cluster
  nat_gateway_enabled  = true
  max_nats             = 1
  nat_instance_enabled = false

  route_create_timeout = "5m"
  route_delete_timeout = "10m"

  subnet_type_tag_key = "cpco.io/subnet/type"

  tags = local.tags

  context = module.this.context
}

module "ssh_source_access" {
  source  = "cloudposse/security-group/aws"
  version = "2.2.0"

  attributes                 = ["ssh", "source"]
  security_group_description = "Test source security group ssh access only"
  allow_all_egress           = true

  rules = [local.allow_all_ingress_rule]

  vpc_id = module.vpc.vpc_id

  context = module.label.context
}

module "https_sg" {
  source  = "cloudposse/security-group/aws"
  version = "2.2.0"

  attributes                 = ["http"]
  security_group_description = "Allow http access"
  allow_all_egress           = true

  rules = [local.allow_http_ingress_rule]

  vpc_id = module.vpc.vpc_id

  context = module.label.context
}

module "eks_cluster" {
  source  = "cloudposse/eks-cluster/aws"
  version = "2.9.0"

  region                       = var.region
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.subnets.public_subnet_ids
  kubernetes_version           = var.kubernetes_version
  local_exec_interpreter       = var.local_exec_interpreter
  oidc_provider_enabled        = var.oidc_provider_enabled
  enabled_cluster_log_types    = var.enabled_cluster_log_types
  cluster_log_retention_period = var.cluster_log_retention_period

  # data auth has problems destroying the auth-map
  kube_data_auth_enabled = false
  kube_exec_auth_enabled = true

  context = module.this.context
}

module "eks_node_group" {
  source  = "cloudposse/eks-node-group/aws"
  version = "2.10.0"

  subnet_ids                    = module.this.enabled ? module.subnets.public_subnet_ids : ["filler_string_for_enabled_is_false"]
  cluster_name                  = module.this.enabled ? module.eks_cluster.eks_cluster_id : "disabled"
  instance_types                = var.instance_types
  desired_size                  = var.desired_size
  min_size                      = var.min_size
  max_size                      = var.max_size
  kubernetes_version            = [var.kubernetes_version]
  kubernetes_labels             = merge(var.kubernetes_labels, { attributes = coalesce(join(module.this.delimiter, module.this.attributes), "none") })
  kubernetes_taints             = var.kubernetes_taints
  ec2_ssh_key_name              = var.ec2_ssh_key_name
  ssh_access_security_group_ids = [module.ssh_source_access.id]
  associated_security_group_ids = [module.ssh_source_access.id, module.https_sg.id]
  node_role_policy_arns         = [local.extra_policy_arn]
  update_config                 = var.update_config

  after_cluster_joining_userdata = var.after_cluster_joining_userdata

  ami_type            = var.ami_type
  ami_release_version = var.ami_release_version

  before_cluster_joining_userdata = [var.before_cluster_joining_userdata]

  # Ensure ordering of resource creation to eliminate the race conditions when applying the Kubernetes Auth ConfigMap.
  # Do not create Node Group before the EKS cluster is created and the `aws-auth` Kubernetes ConfigMap is applied.
  depends_on = [module.eks_cluster, module.eks_cluster.kubernetes_config_map_id]

  create_before_destroy = true

  node_group_terraform_timeouts = [{
    create = "40m"
    update = null
    delete = "20m"
  }]

  context = module.this.context
}

module "eks_fargate_profile" {
  source = "../../"

  subnet_ids                              = module.this.enabled ? module.subnets.private_subnet_ids : ["filler_string_for_enabled_is_false"]
  cluster_name                            = module.eks_cluster.eks_cluster_id
  kubernetes_namespace                    = var.kubernetes_namespace
  kubernetes_labels                       = var.kubernetes_labels
  iam_role_kubernetes_namespace_delimiter = var.iam_role_kubernetes_namespace_delimiter
  fargate_profile_name                    = var.fargate_profile_name
  fargate_profile_iam_role_name           = var.fargate_profile_iam_role_name

  context = module.this.context
}

# Verify that when disabled, the module tolerates bad inputs
# No explicit test needed, it is sufficient to verify that the apply does not fail
module "eks_fargate_profile_disabled_profile" {
  count  = module.this.enabled ? 0 : 1
  source = "../../"

  subnet_ids                              = null
  cluster_name                            = null
  kubernetes_namespace                    = null
  kubernetes_labels                       = null
  iam_role_kubernetes_namespace_delimiter = null
  fargate_profile_name                    = null
  fargate_profile_iam_role_name           = null
  fargate_pod_execution_role_arn          = null

  fargate_pod_execution_role_enabled = false
  fargate_profile_enabled            = true

  context = module.this.context
}

# Verify that when disabled, the module tolerates bad inputs
module "eks_fargate_profile_disabled_role" {
  count  = module.this.enabled ? 0 : 1
  source = "../../"

  subnet_ids                              = null
  cluster_name                            = null
  kubernetes_namespace                    = null
  kubernetes_labels                       = null
  iam_role_kubernetes_namespace_delimiter = null
  fargate_profile_name                    = null
  fargate_profile_iam_role_name           = null
  fargate_pod_execution_role_arn          = null

  fargate_pod_execution_role_enabled = true
  fargate_profile_enabled            = false

  context = module.this.context
}

