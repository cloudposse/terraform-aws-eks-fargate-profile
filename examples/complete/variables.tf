variable "region" {
  type        = string
  description = "AWS Region"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR block"
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Desired Kubernetes master version. If you do not specify a value, the latest available version is used"
}

variable "oidc_provider_enabled" {
  type        = bool
  default     = false
  description = "Create an IAM OIDC identity provider for the cluster, then you can create IAM roles to associate with a service account in the cluster, instead of using kiam or kube2iam. For more information, see https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html"
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace for selection"
}

variable "kubernetes_labels" {
  type        = map(string)
  description = "Key-value mapping of Kubernetes labels for selection"
}

variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
}

variable "max_size" {
  type        = number
  description = "The maximum size of the AutoScaling Group"
}

variable "min_size" {
  type        = number
  description = "The minimum size of the AutoScaling Group"
}

variable "disk_size" {
  type        = number
  description = "Disk size in GiB for worker nodes. Defaults to 20. Terraform will only perform drift detection if a configuration value is provided"
}

variable "instance_types" {
  type        = list(string)
  description = "Set of instance types associated with the EKS Node Group. Defaults to [\"t3.medium\"]. Terraform will only perform drift detection if a configuration value is provided"
}

variable "iam_role_kubernetes_namespace_delimiter" {
  type        = string
  description = "Delimiter for the Kubernetes namespace in the IAM Role name"
}

variable "local_exec_interpreter" {
  type        = list(string)
  default     = ["/bin/sh", "-c"]
  description = "shell to use for local_exec"
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  default     = []
  description = "A list of the desired control plane logging to enable. For more information, see https://docs.aws.amazon.com/en_us/eks/latest/userguide/control-plane-logs.html. Possible values [`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`]"
}

variable "cluster_log_retention_period" {
  type        = number
  default     = 0
  description = "Number of days to retain cluster logs. Requires `enabled_cluster_log_types` to be set. See https://docs.aws.amazon.com/en_us/eks/latest/userguide/control-plane-logs.html."
}

variable "kubernetes_taints" {
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  description = <<-EOT
    List of `key`, `value`, `effect` objects representing Kubernetes taints.
    `effect` must be one of `NO_SCHEDULE`, `NO_EXECUTE`, or `PREFER_NO_SCHEDULE`.
    `key` and `effect` are required, `value` may be null.
    EOT
  default     = []
}

variable "ec2_ssh_key_name" {
  type        = list(string)
  default     = []
  description = "SSH key pair name to use to access the worker nodes"
  validation {
    condition = (
      length(var.ec2_ssh_key_name) < 2
    )
    error_message = "You may not specify more than one `ec2_ssh_key_name`."
  }
}

variable "update_config" {
  type        = list(map(number))
  default     = []
  description = <<-EOT
    Configuration for the `eks_node_group` [`update_config` Configuration Block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group#update_config-configuration-block).
    Specify exactly one of `max_unavailable` (node count) or `max_unavailable_percentage` (percentage of nodes).
    EOT
}

variable "after_cluster_joining_userdata" {
  type        = list(string)
  default     = []
  description = "Additional `bash` commands to execute on each worker node after joining the EKS cluster (after executing the `bootstrap.sh` script). For more info, see https://kubedex.com/90-days-of-aws-eks-in-production"
  validation {
    condition = (
      length(var.after_cluster_joining_userdata) < 2
    )
    error_message = "You may not specify more than one `after_cluster_joining_userdata`."
  }
}

variable "ami_type" {
  type        = string
  description = <<-EOT
    Type of Amazon Machine Image (AMI) associated with the EKS Node Group.
    Defaults to `AL2_x86_64`. Valid values: `AL2_x86_64`, `AL2_x86_64_GPU`, `AL2_ARM_64`, `BOTTLEROCKET_x86_64`, and `BOTTLEROCKET_ARM_64`.
    EOT
  default     = "AL2_x86_64"
  validation {
    condition = (
      contains(["AL2_x86_64", "AL2_x86_64_GPU", "AL2_ARM_64", "BOTTLEROCKET_x86_64", "BOTTLEROCKET_ARM_64"], var.ami_type)
    )
    error_message = "Var ami_type must be one of \"AL2_x86_64\", \"AL2_x86_64_GPU\", \"AL2_ARM_64\", \"BOTTLEROCKET_x86_64\", and \"BOTTLEROCKET_ARM_64\"."
  }
}

variable "ami_release_version" {
  type        = list(string)
  default     = []
  description = "EKS AMI version to use, e.g. \"1.16.13-20200821\" (no \"v\"). Defaults to latest version for Kubernetes version."
  validation {
    condition = (
      length(var.ami_release_version) == 0 ? true : length(regexall("^\\d+\\.\\d+\\.\\d+-[\\da-z]+$", var.ami_release_version[0])) == 1
    )
    error_message = "Var ami_release_version, if supplied, must be like  \"1.16.13-20200821\" (no \"v\")."
  }
}

variable "before_cluster_joining_userdata" {
  type        = string
  default     = ""
  description = "Additional commands to execute on each worker node before joining the EKS cluster (before executing the `bootstrap.sh` script). For more info, see https://kubedex.com/90-days-of-aws-eks-in-production"
}
