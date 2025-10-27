# Production environment configuration

environment = "prod"
enable_pod_identity = true

tags = {
  Terraform   = "true"
  Environment = "prod"
  Project     = "eks-addons"
  Owner       = "platform-team"
  CostCenter  = "production"
}