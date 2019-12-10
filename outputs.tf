output "eks_fargate_profile_role_arn" {
  description = "ARN of the EKS Fargate Profile IAM role"
  value       = join("", aws_iam_role.default.*.arn)
}

output "eks_fargate_profile_role_name" {
  description = "Name of the EKS Fargate Profile IAM role"
  value       = join("", aws_iam_role.default.*.name)
}

output "eks_fargate_profile_id" {
  description = "EKS Cluster name and EKS Fargate Profile name separated by a colon"
  value       = join("", aws_eks_fargate_profile.default.*.id)
}

output "eks_fargate_profile_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Fargate Profile"
  value       = join("", aws_eks_fargate_profile.default.*.arn)
}

output "eks_fargate_profile_status" {
  description = "Status of the EKS Fargate Profile"
  value       = join("", aws_eks_fargate_profile.default.*.status)
}
