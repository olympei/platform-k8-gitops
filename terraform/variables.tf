variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC Provider URL"
  type        = string
}

variable "environment" {
  description = "Environment (dev, prod, etc.)"
  type        = string
  default     = "dev"
}

variable "enable_pod_identity" {
  description = "Enable Pod Identity associations globally"
  type        = bool
  default     = true
}

# Individual Pod Identity toggles for each service
variable "enable_pod_identity_efs_csi" {
  description = "Enable Pod Identity for EFS CSI Driver"
  type        = bool
  default     = true
}

variable "enable_pod_identity_external_secrets" {
  description = "Enable Pod Identity for External Secrets Operator"
  type        = bool
  default     = true
}

variable "enable_pod_identity_ingress_nginx" {
  description = "Enable Pod Identity for Ingress NGINX"
  type        = bool
  default     = true
}

variable "enable_pod_identity_secrets_store" {
  description = "Enable Pod Identity for Secrets Store CSI Driver"
  type        = bool
  default     = true
}

variable "enable_pod_identity_cluster_autoscaler" {
  description = "Enable Pod Identity for Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "enable_pod_identity_metrics_server" {
  description = "Enable Pod Identity for Metrics Server"
  type        = bool
  default     = true
}

variable "enable_pod_identity_external_dns" {
  description = "Enable Pod Identity for External DNS"
  type        = bool
  default     = true
}

variable "enable_pod_identity_aws_load_balancer_controller" {
  description = "Enable Pod Identity for AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
    Project     = "eks-addons"
  }
}