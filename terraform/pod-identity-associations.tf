# Pod Identity Associations for EKS Add-ons
# These are only created when Pod Identity is enabled

# EFS CSI Controller Pod Identity Association
resource "aws_eks_pod_identity_association" "efs_csi_controller" {
  count = var.enable_pod_identity && var.enable_pod_identity_efs_csi ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["efs-csi-controller"].namespace
  service_account = local.service_accounts["efs-csi-controller"].service_account
  role_arn        = aws_iam_role.efs_csi_driver.arn

  tags = local.common_tags
}

# EFS CSI Node Pod Identity Association
resource "aws_eks_pod_identity_association" "efs_csi_node" {
  count = var.enable_pod_identity && var.enable_pod_identity_efs_csi ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["efs-csi-node"].namespace
  service_account = local.service_accounts["efs-csi-node"].service_account
  role_arn        = aws_iam_role.efs_csi_driver.arn

  tags = local.common_tags
}

# External Secrets Pod Identity Association
resource "aws_eks_pod_identity_association" "external_secrets" {
  count = var.enable_pod_identity && var.enable_pod_identity_external_secrets ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["external-secrets"].namespace
  service_account = local.service_accounts["external-secrets"].service_account
  role_arn        = aws_iam_role.external_secrets.arn

  tags = local.common_tags
}

# Ingress NGINX Pod Identity Association
resource "aws_eks_pod_identity_association" "ingress_nginx" {
  count = var.enable_pod_identity && var.enable_pod_identity_ingress_nginx ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["ingress-nginx"].namespace
  service_account = local.service_accounts["ingress-nginx"].service_account
  role_arn        = aws_iam_role.ingress_nginx.arn

  tags = local.common_tags
}

# Pod Identity Agent Pod Identity Association
resource "aws_eks_pod_identity_association" "pod_identity_agent" {
  count = var.enable_pod_identity ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["pod-identity-agent"].namespace
  service_account = local.service_accounts["pod-identity-agent"].service_account
  role_arn        = aws_iam_role.pod_identity.arn

  tags = local.common_tags
}

# Secrets Store CSI Driver Pod Identity Association
resource "aws_eks_pod_identity_association" "secrets_store" {
  count = var.enable_pod_identity && var.enable_pod_identity_secrets_store ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["secrets-store-csi-driver"].namespace
  service_account = local.service_accounts["secrets-store-csi-driver"].service_account
  role_arn        = aws_iam_role.secrets_store.arn

  tags = local.common_tags
}

# Cluster Autoscaler Pod Identity Association
resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  count = var.enable_pod_identity && var.enable_pod_identity_cluster_autoscaler ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["cluster-autoscaler"].namespace
  service_account = local.service_accounts["cluster-autoscaler"].service_account
  role_arn        = aws_iam_role.cluster_autoscaler.arn

  tags = local.common_tags
}

# Metrics Server Pod Identity Association
resource "aws_eks_pod_identity_association" "metrics_server" {
  count = var.enable_pod_identity && var.enable_pod_identity_metrics_server ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["metrics-server"].namespace
  service_account = local.service_accounts["metrics-server"].service_account
  role_arn        = aws_iam_role.metrics_server.arn

  tags = local.common_tags
}

# External DNS Pod Identity Association
resource "aws_eks_pod_identity_association" "external_dns" {
  count = var.enable_pod_identity && var.enable_pod_identity_external_dns ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["external-dns"].namespace
  service_account = local.service_accounts["external-dns"].service_account
  role_arn        = aws_iam_role.external_dns.arn

  tags = local.common_tags
}

# AWS Load Balancer Controller Pod Identity Association
resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  count = var.enable_pod_identity && var.enable_pod_identity_aws_load_balancer_controller ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["aws-load-balancer-controller"].namespace
  service_account = local.service_accounts["aws-load-balancer-controller"].service_account
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn

  tags = local.common_tags
}