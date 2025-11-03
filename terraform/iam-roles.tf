# IAM Roles for EKS Add-ons
# Each role uses a combined trust policy that supports both IRSA and Pod Identity

# AWS EFS CSI Driver Role
resource "aws_iam_role" "efs_csi_driver" {
  name        = "${local.unique_roles["EKS-EFS-CSI-DriverRole"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-EFS-CSI-DriverRole"].description} for ${var.environment}"

  # Combined trust policy supports both IRSA and Pod Identity
  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["efs-csi-controller"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = aws_iam_policy.efs_csi_driver.arn
  role       = aws_iam_role.efs_csi_driver.name
}

# External Secrets Operator Role
resource "aws_iam_role" "external_secrets" {
  name        = "${local.unique_roles["EKS-ExternalSecrets-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-ExternalSecrets-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["external-secrets"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  policy_arn = aws_iam_policy.external_secrets.arn
  role       = aws_iam_role.external_secrets.name
}

# Ingress NGINX Role
resource "aws_iam_role" "ingress_nginx" {
  name        = "${local.unique_roles["EKS-IngressNginx-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-IngressNginx-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["ingress-nginx"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ingress_nginx" {
  policy_arn = aws_iam_policy.ingress_nginx.arn
  role       = aws_iam_role.ingress_nginx.name
}

# Pod Identity Agent Role
resource "aws_iam_role" "pod_identity" {
  name        = "${local.unique_roles["EKS-PodIdentity-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-PodIdentity-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["pod-identity-agent"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "pod_identity" {
  policy_arn = aws_iam_policy.pod_identity.arn
  role       = aws_iam_role.pod_identity.name
}

# Secrets Store CSI Driver Role
resource "aws_iam_role" "secrets_store" {
  name        = "${local.unique_roles["EKS-SecretsStore-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-SecretsStore-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["secrets-store-csi-driver"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "secrets_store" {
  policy_arn = aws_iam_policy.secrets_store.arn
  role       = aws_iam_role.secrets_store.name
}

# Cluster Autoscaler Role
resource "aws_iam_role" "cluster_autoscaler" {
  name        = "${local.unique_roles["EKS-ClusterAutoscaler-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-ClusterAutoscaler-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["cluster-autoscaler"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

# Metrics Server Role
resource "aws_iam_role" "metrics_server" {
  name        = "${local.unique_roles["EKS-MetricsServer-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-MetricsServer-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["metrics-server"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "metrics_server" {
  policy_arn = aws_iam_policy.metrics_server.arn
  role       = aws_iam_role.metrics_server.name
}

# External DNS Role
resource "aws_iam_role" "external_dns" {
  name        = "${local.unique_roles["EKS-ExternalDNS-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-ExternalDNS-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["external-dns"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  policy_arn = aws_iam_policy.external_dns.arn
  role       = aws_iam_role.external_dns.name
}

# AWS Load Balancer Controller Role
resource "aws_iam_role" "aws_load_balancer_controller" {
  name        = "${local.unique_roles["EKS-AWSLoadBalancerController-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-AWSLoadBalancerController-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["aws-load-balancer-controller"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}
