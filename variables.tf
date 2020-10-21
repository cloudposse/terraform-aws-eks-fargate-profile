variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster"
}

variable "subnet_ids" {
  description = "Identifiers of private EC2 Subnets to associate with the EKS Fargate Profile. These subnets must have the following resource tag: kubernetes.io/cluster/CLUSTER_NAME (where CLUSTER_NAME is replaced with the name of the EKS Cluster)"
  type        = list(string)
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace for selection"
}

variable "kubernetes_labels" {
  type        = map(string)
  description = "Key-value mapping of Kubernetes labels for selection"
  default     = {}
}

variable "iam_role_kubernetes_namespace_delimiter" {
  type        = string
  description = "Delimiter for the Kubernetes namespace in the IAM Role name"
  default     = "-"
}
