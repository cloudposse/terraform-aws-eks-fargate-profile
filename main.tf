locals {
  enabled                            = module.this.enabled
  fargate_profile_enabled            = var.fargate_profile_enabled && local.enabled
  fargate_pod_execution_role_enabled = var.fargate_pod_execution_role_enabled && local.enabled

  tags = try(length(var.cluster_name), 0) == 0 ? module.this.tags : merge(
    module.this.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )

  fargate_pod_execution_role_name = var.fargate_pod_execution_role_name != null ? var.fargate_pod_execution_role_name : var.fargate_profile_iam_role_name

  fargate_profile_name = var.fargate_profile_name != null ? var.fargate_profile_name : module.fargate_profile_label.id

  fargate_profile_iam_role_name = local.fargate_pod_execution_role_name != null ? local.fargate_pod_execution_role_name : (
    local.fargate_profile_enabled ? "${module.role_label.id}${var.iam_role_kubernetes_namespace_delimiter}${var.kubernetes_namespace}" :
  module.role_label.id)
}

module "fargate_profile_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.fargate_profile_enabled
  # Append the provided Kubernetes namespace to the Fargate Profile name
  attributes      = [var.kubernetes_namespace]
  id_length_limit = 62

  tags = local.tags

  context = module.this.context
}

module "role_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  enabled = local.fargate_pod_execution_role_enabled
  # Append 'fargate' to the Fargate Role name to specify that the role is for Fargate
  attributes      = ["fargate"]
  id_length_limit = 64

  tags = local.tags

  context = module.this.context
}

data "aws_partition" "current" {
  count = local.enabled ? 1 : 0
}

data "aws_iam_policy_document" "assume_role" {
  count = local.fargate_pod_execution_role_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "default" {
  count = local.fargate_pod_execution_role_enabled ? 1 : 0

  name                 = local.fargate_profile_iam_role_name
  assume_role_policy   = one(data.aws_iam_policy_document.assume_role[*].json)
  tags                 = module.role_label.tags
  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy_attachment" "amazon_eks_fargate_pod_execution_role_policy" {
  count = local.fargate_pod_execution_role_enabled ? 1 : 0

  policy_arn = "arn:${one(data.aws_partition.current[*].partition)}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = one(aws_iam_role.default[*].name)
}

resource "aws_eks_fargate_profile" "default" {
  count = local.fargate_profile_enabled ? 1 : 0

  cluster_name           = var.cluster_name
  fargate_profile_name   = local.fargate_profile_name
  pod_execution_role_arn = var.fargate_pod_execution_role_enabled ? one(aws_iam_role.default[*].arn) : var.fargate_pod_execution_role_arn
  subnet_ids             = var.subnet_ids
  tags                   = module.fargate_profile_label.tags

  selector {
    namespace = var.kubernetes_namespace
    labels    = var.kubernetes_labels
  }
}
