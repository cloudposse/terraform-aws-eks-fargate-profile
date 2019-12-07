locals {
  tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  )
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  delimiter  = var.delimiter
  attributes = compact(concat(var.attributes, ["fargate"]))
  tags       = local.tags
  enabled    = var.enabled
}

data "aws_iam_policy_document" "assume_role" {
  count = var.enabled ? 1 : 0

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
  count              = var.enabled ? 1 : 0
  name               = module.label.id
  assume_role_policy = join("", data.aws_iam_policy_document.assume_role.*.json)
  tags               = module.label.tags
}

resource "aws_iam_role_policy_attachment" "amazon_eks_fargate_pod_execution_role_policy" {
  count      = var.enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_eks_fargate_profile" "default" {
  count                  = var.enabled ? 1 : 0
  cluster_name           = var.cluster_name
  fargate_profile_name   = module.label.id
  pod_execution_role_arn = join("", aws_iam_role.default.*.arn)
  subnet_ids             = var.subnet_ids
  tags                   = module.label.tags

  selector {
    namespace = var.kubernetes_namespace
    labels    = var.kubernetes_labels
  }
}
