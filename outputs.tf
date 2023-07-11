output "eks_fargate_profile_role_arn" {
  description = "DEPRECATED (use `eks_fargate_pod_execution_role_arn` instead): ARN of the EKS Fargate Profile IAM role"
  value       = local.fargate_pod_execution_role_enabled ? one(aws_iam_role.default[*].arn) : var.fargate_pod_execution_role_arn
}

output "eks_fargate_pod_execution_role_arn" {
  description = "ARN of the EKS Fargate Pod Execution role"
  value       = local.fargate_pod_execution_role_enabled ? one(aws_iam_role.default[*].arn) : var.fargate_pod_execution_role_arn
}

output "eks_fargate_profile_role_name" {
  description = "DEPRECATED (use `eks_fargate_pod_execution_role_name` instead): Name of the EKS Fargate Profile IAM role"
  value = local.fargate_pod_execution_role_enabled ? one(aws_iam_role.default[*].name) : (
    local.enabled ? one(regex(".*:role/(.+)$", var.fargate_pod_execution_role_arn)[*]) : null
  )
}

output "eks_fargate_pod_execution_role_name" {
  description = "Name of the EKS Fargate Pod Execution role"
  value = local.fargate_pod_execution_role_enabled ? one(aws_iam_role.default[*].name) : (
    local.enabled ? one(regex(".*:role/(.+)$", var.fargate_pod_execution_role_arn)[*]) : null
  )
}

output "eks_fargate_profile_id" {
  description = "EKS Cluster name and EKS Fargate Profile name separated by a colon"
  value       = one(aws_eks_fargate_profile.default[*].id)
}

output "eks_fargate_profile_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Fargate Profile"
  value       = one(aws_eks_fargate_profile.default[*].arn)
}

output "eks_fargate_profile_status" {
  description = "Status of the EKS Fargate Profile"
  value       = one(aws_eks_fargate_profile.default[*].status)
}
