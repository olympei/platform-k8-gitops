# OIDC Provider URL Examples - Quick Reference

This is a quick reference for OIDC provider URL formats across different AWS regions.

## Format Pattern

```
URL: https://oidc.eks.{region}.amazonaws.com/id/{unique-32-char-identifier}
ARN: arn:aws:iam::{account-id}:oidc-provider/oidc.eks.{region}.amazonaws.com/id/{unique-32-char-identifier}
```

## Real Examples by Region

### US Regions

#### US East 1 (N. Virginia)
```bash
oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"
```

#### US East 2 (Ohio)
```bash
oidc_provider_url = "https://oidc.eks.us-east-2.amazonaws.com/id/B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-2.amazonaws.com/id/B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7"
```

#### US West 1 (N. California)
```bash
oidc_provider_url = "https://oidc.eks.us-west-1.amazonaws.com/id/C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-1.amazonaws.com/id/C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8"
```

#### US West 2 (Oregon)
```bash
oidc_provider_url = "https://oidc.eks.us-west-2.amazonaws.com/id/D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9"
```

### Europe Regions

#### EU West 1 (Ireland)
```bash
oidc_provider_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/E5F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0"
```

#### EU West 2 (London)
```bash
oidc_provider_url = "https://oidc.eks.eu-west-2.amazonaws.com/id/F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-2.amazonaws.com/id/F6G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1"
```

#### EU West 3 (Paris)
```bash
oidc_provider_url = "https://oidc.eks.eu-west-3.amazonaws.com/id/G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-3.amazonaws.com/id/G7H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2"
```

#### EU Central 1 (Frankfurt)
```bash
oidc_provider_url = "https://oidc.eks.eu-central-1.amazonaws.com/id/H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2W3"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/H8I9J0K1L2M3N4O5P6Q7R8S9T0U1V2W3"
```

#### EU North 1 (Stockholm)
```bash
oidc_provider_url = "https://oidc.eks.eu-north-1.amazonaws.com/id/I9J0K1L2M3N4O5P6Q7R8S9T0U1V2W3X4"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-north-1.amazonaws.com/id/I9J0K1L2M3N4O5P6Q7R8S9T0U1V2W3X4"
```

### Asia Pacific Regions

#### AP Southeast 1 (Singapore)
```bash
oidc_provider_url = "https://oidc.eks.ap-southeast-1.amazonaws.com/id/J0K1L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/J0K1L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5"
```

#### AP Southeast 2 (Sydney)
```bash
oidc_provider_url = "https://oidc.eks.ap-southeast-2.amazonaws.com/id/K1L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-southeast-2.amazonaws.com/id/K1L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6"
```

#### AP Northeast 1 (Tokyo)
```bash
oidc_provider_url = "https://oidc.eks.ap-northeast-1.amazonaws.com/id/L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/L2M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7"
```

#### AP Northeast 2 (Seoul)
```bash
oidc_provider_url = "https://oidc.eks.ap-northeast-2.amazonaws.com/id/M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/M3N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8"
```

#### AP South 1 (Mumbai)
```bash
oidc_provider_url = "https://oidc.eks.ap-south-1.amazonaws.com/id/N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8C9"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/N4O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8C9"
```

### Canada Region

#### CA Central 1 (Canada Central)
```bash
oidc_provider_url = "https://oidc.eks.ca-central-1.amazonaws.com/id/O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8C9D0"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ca-central-1.amazonaws.com/id/O5P6Q7R8S9T0U1V2W3X4Y5Z6A7B8C9D0"
```

## How to Get Your Actual Values

### Quick Command
```bash
# Replace 'your-cluster-name' and 'your-region' with actual values
./scripts/get-oidc-info.sh your-cluster-name your-region
```

### Manual AWS CLI
```bash
# Get OIDC URL
aws eks describe-cluster --name your-cluster-name --query "cluster.identity.oidc.issuer" --output text

# Get Account ID
aws sts get-caller-identity --query Account --output text
```

### Terraform Data Source
```hcl
data "aws_eks_cluster" "cluster" {
  name = "your-cluster-name"
}

locals {
  oidc_provider_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}
```

## Important Notes

1. **Unique Identifiers**: Each EKS cluster has a unique 32-character identifier
2. **Region Specific**: The OIDC provider URL must match your EKS cluster's region
3. **Account Specific**: The ARN includes your AWS account ID
4. **Case Sensitive**: URLs and ARNs are case-sensitive
5. **HTTPS Required**: OIDC provider URLs always use HTTPS

## Validation

Test your OIDC provider URL:
```bash
curl -s "https://oidc.eks.us-east-1.amazonaws.com/id/YOUR-OIDC-ID/.well-known/openid_configuration" | jq .
```

The response should include issuer, jwks_uri, and other OIDC configuration details.