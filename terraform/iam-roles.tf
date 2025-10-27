# IAM Roles for EKS Add-ons

# AWS EFS CSI Driver Role
resource "aws_iam_role" "efs_csi_driver" {
  name        = "${local.unique_roles["EKS-EFS-CSI-DriverRole"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-EFS-CSI-DriverRole"].description} for ${var.environment}"

  # Use Pod Identity trust policy by default, can be overridden
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust_policy.json

  tags = local.common_tags
}

# Attach EFS CSI Driver policy to role
resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = aws_iam_policy.efs_csi_driver.arn
  role       = aws_iam_role.efs_csi_driver.name
}

# External Secrets Operator Role
resource "aws_iam_role" "external_secrets" {
  name        = "${local.unique_roles["EKS-ExternalSecrets-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-ExternalSecrets-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust_policy.json

  tags = local.common_tags
}

# Attach External Secrets policy to role
resource "aws_iam_role_policy_attachment" "external_secrets" {
  policy_arn = aws_iam_policy.external_secrets.arn
  role       = aws_iam_role.external_secrets.name
}

# Ingress NGINX Role
resource "aws_iam_role" "ingress_nginx" {
  name        = "${local.unique_roles["EKS-IngressNginx-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-IngressNginx-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust_policy.json

  tags = local.common_tags
}

# Attach Ingress NGINX policy to role
resource "aws_iam_role_policy_attachment" "ingress_nginx" {
  policy_arn = aws_iam_policy.ingress_nginx.arn
  role       = aws_iam_role.ingress_nginx.name
}

# Pod Identity Agent Role
resource "aws_iam_role" "pod_identity" {
  name        = "${local.unique_roles["EKS-PodIdentity-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-PodIdentity-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust_policy.json

  tags = local.common_tags
}

# Attach Pod Identity policy to role
resource "aws_iam_role_policy_attachment" "pod_identity" {
  policy_arn = aws_iam_policy.pod_identity.arn
  role       = aws_iam_role.pod_identity.name
}

# Secrets Store CSI Driver Role
resource "aws_iam_role" "secrets_store" {
  name        = "${local.unique_roles["EKS-SecretsStore-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-SecretsStore-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust_policy.json

  tags = local.common_tags
}

# Attach Secrets Store policy to role
resource "aws_iam_role_policy_attachment" "secrets_store" {
  policy_arn = aws_iam_policy.secrets_store.arn
  role       = aws_iam_role.secrets_store.name
}

# Cluster Autoscaler Role
resource "aws_iam_role" "cluster_autoscaler" {
  name        = "${local.unique_roles["EKS-ClusterAutoscaler-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-ClusterAutoscaler-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust_policy.json

  tags = local.common_tags
}

# Attach Cluster Autoscaler policy to role
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

# Metrics Server Role
resource "aws_iam_role" "metrics_server" {
  name        = "${local.unique_roles["EKS-MetricsServer-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-MetricsServer-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust_policy.json

  tags = local.common_tags
}

# Attach Metrics Server policy to role
resource "aws_iam_role_policy_attachment" "metrics_server" {
  policy_arn = aws_iam_policy.metrics_server.arn
  role       = aws_iam_role.metrics_server.name
}

# External DNS Role
resource "aws_iam_role" "external_dns" {
  name        = "${local.unique_roles["EKS-ExternalDNS-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-ExternalDNS-Role"].description} for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust_policy.json

  tags = local.common_tags
}

# Attach External DNS policy to role
resource "aws_iam_role_policy_attachment" "external_dns" {
  policy_arn = aws_iam_policy.external_dns.arn
  role       = aws_iam_role.external_dns.name
}

# IRSA Roles (alternative trust policy for IRSA authentication)
# These are created separately to support both authentication methods

# IRSA Role for EFS CSI Driver
resource "aws_iam_role" "efs_csi_driver_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  name        = "${local.unique_roles["EKS-EFS-CSI-DriverRole"].name}-irsa-${var.environment}"
  description = "${local.unique_roles["EKS-EFS-CSI-DriverRole"].description} IRSA for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy["efs-csi-controller"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  policy_arn = aws_iam_policy.efs_csi_driver.arn
  role       = aws_iam_role.efs_csi_driver_irsa[0].name
}

# IRSA Role for External Secrets
resource "aws_iam_role" "external_secrets_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  name        = "${local.unique_roles["EKS-ExternalSecrets-Role"].name}-irsa-${var.environment}"
  description = "${local.unique_roles["EKS-ExternalSecrets-Role"].description} IRSA for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy["external-secrets"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_secrets_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  policy_arn = aws_iam_policy.external_secrets.arn
  role       = aws_iam_role.external_secrets_irsa[0].name
}

# IRSA Role for Ingress NGINX
resource "aws_iam_role" "ingress_nginx_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  name        = "${local.unique_roles["EKS-IngressNginx-Role"].name}-irsa-${var.environment}"
  description = "${local.unique_roles["EKS-IngressNginx-Role"].description} IRSA for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy["ingress-nginx"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ingress_nginx_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  policy_arn = aws_iam_policy.ingress_nginx.arn
  role       = aws_iam_role.ingress_nginx_irsa[0].name
}

# IRSA Role for Pod Identity Agent
resource "aws_iam_role" "pod_identity_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  name        = "${local.unique_roles["EKS-PodIdentity-Role"].name}-irsa-${var.environment}"
  description = "${local.unique_roles["EKS-PodIdentity-Role"].description} IRSA for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy["pod-identity-agent"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "pod_identity_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  policy_arn = aws_iam_policy.pod_identity.arn
  role       = aws_iam_role.pod_identity_irsa[0].name
}

# IRSA Role for Secrets Store CSI Driver
resource "aws_iam_role" "secrets_store_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  name        = "${local.unique_roles["EKS-SecretsStore-Role"].name}-irsa-${var.environment}"
  description = "${local.unique_roles["EKS-SecretsStore-Role"].description} IRSA for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy["secrets-store-csi-driver"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "secrets_store_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  policy_arn = aws_iam_policy.secrets_store.arn
  role       = aws_iam_role.secrets_store_irsa[0].name
}

# IRSA Role for Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  name        = "${local.unique_roles["EKS-ClusterAutoscaler-Role"].name}-irsa-${var.environment}"
  description = "${local.unique_roles["EKS-ClusterAutoscaler-Role"].description} IRSA for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy["cluster-autoscaler"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler_irsa[0].name
}

# IRSA Role for Metrics Server
resource "aws_iam_role" "metrics_server_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  name        = "${local.unique_roles["EKS-MetricsServer-Role"].name}-irsa-${var.environment}"
  description = "${local.unique_roles["EKS-MetricsServer-Role"].description} IRSA for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy["metrics-server"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "metrics_server_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  policy_arn = aws_iam_policy.metrics_server.arn
  role       = aws_iam_role.metrics_server_irsa[0].name
}

# IRSA Role for External DNS
resource "aws_iam_role" "external_dns_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  name        = "${local.unique_roles["EKS-ExternalDNS-Role"].name}-irsa-${var.environment}"
  description = "${local.unique_roles["EKS-ExternalDNS-Role"].description} IRSA for ${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy["external-dns"].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_dns_irsa" {
  count = var.enable_pod_identity ? 0 : 1
  
  policy_arn = aws_iam_policy.external_dns.arn
  role       = aws_iam_role.external_dns_irsa[0].name
}