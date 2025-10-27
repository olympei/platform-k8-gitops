# Data sources for EKS cluster information
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_caller_identity" "current" {}

# OIDC provider data
data "aws_iam_openid_connect_provider" "eks" {
  url = var.oidc_provider_url
}

# Trust policy for IRSA
data "aws_iam_policy_document" "irsa_trust_policy" {
  for_each = local.service_accounts

  statement {
    effect = "Allow"
    
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    
    actions = ["sts:AssumeRoleWithWebIdentity"]
    
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Trust policy for Pod Identity
data "aws_iam_policy_document" "pod_identity_trust_policy" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}