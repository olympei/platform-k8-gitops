# Outputs for IAM roles and policies

# Policy ARNs
output "efs_csi_driver_policy_arn" {
  description = "ARN of the EFS CSI Driver IAM policy"
  value       = aws_iam_policy.efs_csi_driver.arn
}

output "external_secrets_policy_arn" {
  description = "ARN of the External Secrets Operator IAM policy"
  value       = aws_iam_policy.external_secrets.arn
}

output "ingress_nginx_policy_arn" {
  description = "ARN of the Ingress NGINX IAM policy"
  value       = aws_iam_policy.ingress_nginx.arn
}

output "pod_identity_policy_arn" {
  description = "ARN of the Pod Identity Agent IAM policy"
  value       = aws_iam_policy.pod_identity.arn
}

output "secrets_store_policy_arn" {
  description = "ARN of the Secrets Store CSI Driver IAM policy"
  value       = aws_iam_policy.secrets_store.arn
}

output "cluster_autoscaler_policy_arn" {
  description = "ARN of the Cluster Autoscaler IAM policy"
  value       = aws_iam_policy.cluster_autoscaler.arn
}

output "metrics_server_policy_arn" {
  description = "ARN of the Metrics Server IAM policy"
  value       = aws_iam_policy.metrics_server.arn
}

output "external_dns_policy_arn" {
  description = "ARN of the External DNS IAM policy"
  value       = aws_iam_policy.external_dns.arn
}

# Pod Identity Role ARNs
output "efs_csi_driver_role_arn" {
  description = "ARN of the EFS CSI Driver IAM role for Pod Identity"
  value       = aws_iam_role.efs_csi_driver.arn
}

output "external_secrets_role_arn" {
  description = "ARN of the External Secrets Operator IAM role for Pod Identity"
  value       = aws_iam_role.external_secrets.arn
}

output "ingress_nginx_role_arn" {
  description = "ARN of the Ingress NGINX IAM role for Pod Identity"
  value       = aws_iam_role.ingress_nginx.arn
}

output "pod_identity_role_arn" {
  description = "ARN of the Pod Identity Agent IAM role for Pod Identity"
  value       = aws_iam_role.pod_identity.arn
}

output "secrets_store_role_arn" {
  description = "ARN of the Secrets Store CSI Driver IAM role for Pod Identity"
  value       = aws_iam_role.secrets_store.arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role for Pod Identity"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "metrics_server_role_arn" {
  description = "ARN of the Metrics Server IAM role for Pod Identity"
  value       = aws_iam_role.metrics_server.arn
}

output "external_dns_role_arn" {
  description = "ARN of the External DNS IAM role for Pod Identity"
  value       = aws_iam_role.external_dns.arn
}

# IRSA Role ARNs (only when IRSA is enabled)
output "efs_csi_driver_irsa_role_arn" {
  description = "ARN of the EFS CSI Driver IAM role for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_role.efs_csi_driver_irsa[0].arn
}

output "external_secrets_irsa_role_arn" {
  description = "ARN of the External Secrets Operator IAM role for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_role.external_secrets_irsa[0].arn
}

output "ingress_nginx_irsa_role_arn" {
  description = "ARN of the Ingress NGINX IAM role for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_role.ingress_nginx_irsa[0].arn
}

output "pod_identity_irsa_role_arn" {
  description = "ARN of the Pod Identity Agent IAM role for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_role.pod_identity_irsa[0].arn
}

output "secrets_store_irsa_role_arn" {
  description = "ARN of the Secrets Store CSI Driver IAM role for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_role.secrets_store_irsa[0].arn
}

output "cluster_autoscaler_irsa_role_arn" {
  description = "ARN of the Cluster Autoscaler IAM role for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_role.cluster_autoscaler_irsa[0].arn
}

output "metrics_server_irsa_role_arn" {
  description = "ARN of the Metrics Server IAM role for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_role.metrics_server_irsa[0].arn
}

output "external_dns_irsa_role_arn" {
  description = "ARN of the External DNS IAM role for IRSA"
  value       = var.enable_pod_identity ? null : aws_iam_role.external_dns_irsa[0].arn
}

# Pod Identity Association IDs
output "pod_identity_associations" {
  description = "Pod Identity Association IDs"
  value = var.enable_pod_identity ? {
    efs_csi_controller = aws_eks_pod_identity_association.efs_csi_controller[0].association_id
    efs_csi_node       = aws_eks_pod_identity_association.efs_csi_node[0].association_id
    external_secrets   = aws_eks_pod_identity_association.external_secrets[0].association_id
    ingress_nginx      = aws_eks_pod_identity_association.ingress_nginx[0].association_id
    pod_identity_agent = aws_eks_pod_identity_association.pod_identity_agent[0].association_id
    secrets_store      = aws_eks_pod_identity_association.secrets_store[0].association_id
    cluster_autoscaler = aws_eks_pod_identity_association.cluster_autoscaler[0].association_id
    metrics_server     = aws_eks_pod_identity_association.metrics_server[0].association_id
    external_dns       = aws_eks_pod_identity_association.external_dns[0].association_id
  } : {}
}

# Role names for Helm values
output "role_names" {
  description = "IAM role names for use in Helm values"
  value = {
    efs_csi_driver    = aws_iam_role.efs_csi_driver.name
    external_secrets  = aws_iam_role.external_secrets.name
    ingress_nginx     = aws_iam_role.ingress_nginx.name
    pod_identity      = aws_iam_role.pod_identity.name
    secrets_store     = aws_iam_role.secrets_store.name
    cluster_autoscaler = aws_iam_role.cluster_autoscaler.name
    metrics_server     = aws_iam_role.metrics_server.name
    external_dns       = aws_iam_role.external_dns.name
  }
}

# Complete role ARNs for Helm values
output "helm_role_arns" {
  description = "Complete role ARNs for use in Helm values files"
  value = {
    efs_csi_driver = var.enable_pod_identity ? aws_iam_role.efs_csi_driver.arn : aws_iam_role.efs_csi_driver_irsa[0].arn
    external_secrets = var.enable_pod_identity ? aws_iam_role.external_secrets.arn : aws_iam_role.external_secrets_irsa[0].arn
    ingress_nginx = var.enable_pod_identity ? aws_iam_role.ingress_nginx.arn : aws_iam_role.ingress_nginx_irsa[0].arn
    pod_identity = var.enable_pod_identity ? aws_iam_role.pod_identity.arn : aws_iam_role.pod_identity_irsa[0].arn
    secrets_store = var.enable_pod_identity ? aws_iam_role.secrets_store.arn : aws_iam_role.secrets_store_irsa[0].arn
    cluster_autoscaler = var.enable_pod_identity ? aws_iam_role.cluster_autoscaler.arn : aws_iam_role.cluster_autoscaler_irsa[0].arn
    metrics_server = var.enable_pod_identity ? aws_iam_role.metrics_server.arn : aws_iam_role.metrics_server_irsa[0].arn
    external_dns = var.enable_pod_identity ? aws_iam_role.external_dns.arn : aws_iam_role.external_dns_irsa[0].arn
  }
}