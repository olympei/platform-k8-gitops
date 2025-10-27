# Terraform IAM Configuration for EKS Add-ons

This Terraform configuration creates IAM roles and policies for EKS add-ons with support for both Pod Identity and IRSA (IAM Roles for Service Accounts) authentication methods.

## Features

- **Dual Authentication Support**: Supports both Pod Identity and IRSA
- **Environment Separation**: Separate resources for dev/prod environments
- **Comprehensive Policies**: Minimal required permissions for each add-on
- **Pod Identity Associations**: Automatic creation when Pod Identity is enabled
- **Flexible Configuration**: Easy switching between authentication methods

## Supported Add-ons

1. **AWS EFS CSI Driver**
2. **External Secrets Operator**
3. **Ingress NGINX Controller**
4. **Pod Identity Agent**

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured
- EKS cluster with OIDC provider (for IRSA) or Pod Identity enabled

## Quick Start

### 1. Get EKS Cluster Information

```bash
# Get cluster OIDC issuer URL
aws eks describe-cluster --name your-cluster-name --query "cluster.identity.oidc.issuer" --output text

# Get OIDC provider ARN
aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'your-oidc-id')]"
```

### 2. Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="environments/dev.tfvars"

# Apply configuration
terraform apply -var-file="environments/dev.tfvars"
```

## Configuration

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_account_id` | AWS Account ID | - | Yes |
| `aws_region` | AWS Region | `us-east-1` | No |
| `cluster_name` | EKS Cluster Name | - | Yes |
| `oidc_provider_arn` | EKS OIDC Provider ARN | - | Yes |
| `oidc_provider_url` | EKS OIDC Provider URL | - | Yes |
| `environment` | Environment name | `dev` | No |
| `enable_pod_identity` | Enable Pod Identity | `true` | No |
| `tags` | Resource tags | `{}` | No |

### Authentication Methods

#### Pod Identity (Recommended)
```hcl
enable_pod_identity = true
```

Creates:
- IAM roles with Pod Identity trust policy
- Pod Identity associations for service accounts
- Policies with minimal required permissions

#### IRSA (Legacy)
```hcl
enable_pod_identity = false
```

Creates:
- IAM roles with OIDC trust policy
- Service account specific trust relationships
- Policies with minimal required permissions

## Environment-Specific Deployment

### Development
```bash
terraform apply -var-file="environments/dev.tfvars"
```

### Production
```bash
terraform apply -var-file="environments/prod.tfvars"
```

## Outputs

The configuration provides several outputs for use in Helm charts:

```hcl
# Role ARNs for current authentication method
helm_role_arns = {
  efs_csi_driver   = "arn:aws:iam::123456789012:role/EKS-EFS-CSI-DriverRole-dev"
  external_secrets = "arn:aws:iam::123456789012:role/EKS-ExternalSecrets-Role-dev"
  ingress_nginx    = "arn:aws:iam::123456789012:role/EKS-IngressNginx-Role-dev"
  pod_identity     = "arn:aws:iam::123456789012:role/EKS-PodIdentity-Role-dev"
}
```

## Integration with Helm Charts

After applying Terraform, update your Helm values files with the output role ARNs:

```bash
# Get role ARNs
terraform output helm_role_arns

# Update Helm values files
# Replace ACCOUNT_ID placeholders with actual role ARNs
```

## File Structure

```
terraform/
├── data.tf                          # Data sources
├── iam-policies.tf                  # IAM policies
├── iam-roles.tf                     # IAM roles
├── locals.tf                        # Local values
├── outputs.tf                       # Outputs
├── pod-identity-associations.tf     # Pod Identity associations
├── terraform.tf                     # Provider configuration
├── variables.tf                     # Variable definitions
├── terraform.tfvars.example        # Example variables
├── environments/
│   ├── dev.tfvars                  # Dev environment
│   └── prod.tfvars                 # Prod environment
└── README.md                       # This file
```

## Best Practices

### Security
- Use least privilege IAM policies
- Separate roles for different environments
- Regular policy reviews and updates

### Operations
- Use remote state for production
- Enable state locking
- Tag all resources consistently

### Monitoring
- Monitor IAM role usage
- Set up CloudTrail for audit logging
- Regular access reviews

## Troubleshooting

### Common Issues

1. **OIDC Provider Not Found**
   ```bash
   # Associate OIDC provider with cluster
   eksctl utils associate-iam-oidc-provider --cluster your-cluster-name --approve
   ```

2. **Pod Identity Association Fails**
   ```bash
   # Ensure Pod Identity add-on is installed
   aws eks describe-addon --cluster-name your-cluster-name --addon-name eks-pod-identity-agent
   ```

3. **Permission Denied**
   - Verify Terraform has sufficient IAM permissions
   - Check role trust relationships
   - Validate policy permissions

### Verification

```bash
# List Pod Identity associations
aws eks list-pod-identity-associations --cluster-name your-cluster-name

# Describe IAM role
aws iam get-role --role-name EKS-EFS-CSI-DriverRole-dev

# Test assume role
aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/EKS-EFS-CSI-DriverRole-dev --role-session-name test
```

## Migration

### From IRSA to Pod Identity

1. Apply Terraform with `enable_pod_identity = true`
2. Update Helm values to use Pod Identity
3. Redeploy Helm charts
4. Verify functionality
5. Clean up old IRSA resources

### From Pod Identity to IRSA

1. Apply Terraform with `enable_pod_identity = false`
2. Update Helm values to use IRSA
3. Redeploy Helm charts
4. Verify functionality
5. Clean up Pod Identity associations

## Contributing

1. Follow Terraform best practices
2. Update documentation for changes
3. Test in dev environment first
4. Use consistent naming conventions