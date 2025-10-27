# OIDC Provider Configuration Guide

This guide explains how to obtain and configure the OIDC provider URL and ARN for your EKS cluster, which are required for IRSA (IAM Roles for Service Accounts) authentication.

## Overview

The OIDC (OpenID Connect) provider enables your EKS cluster to integrate with AWS IAM for service account authentication. Each EKS cluster has a unique OIDC provider that must be configured in your Terraform variables.

## OIDC Provider URL Format

The OIDC provider URL follows this format:
```
https://oidc.eks.{region}.amazonaws.com/id/{unique-identifier}
```

## Examples

### Real-world Examples

#### US East 1 (Virginia)
```bash
# OIDC Provider URL
oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"

# OIDC Provider ARN
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"
```

#### US West 2 (Oregon)
```bash
# OIDC Provider URL
oidc_provider_url = "https://oidc.eks.us-west-2.amazonaws.com/id/B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7"

# OIDC Provider ARN
oidc_provider_arn = "arn:aws:iam::987654321098:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7"
```

#### Europe West 1 (Ireland)
```bash
# OIDC Provider URL
oidc_provider_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8"

# OIDC Provider ARN
oidc_provider_arn = "arn:aws:iam::456789012345:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R8"
```

## How to Obtain OIDC Provider Information

### Method 1: AWS CLI (Recommended)

#### Get OIDC Provider URL from EKS Cluster
```bash
# Get the OIDC issuer URL from your EKS cluster
aws eks describe-cluster \
  --name your-cluster-name \
  --query "cluster.identity.oidc.issuer" \
  --output text

# Example output:
# https://oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6
```

#### Get OIDC Provider ARN
```bash
# Extract the OIDC ID from the URL
OIDC_URL=$(aws eks describe-cluster --name your-cluster-name --query "cluster.identity.oidc.issuer" --output text)
OIDC_ID=$(echo $OIDC_URL | cut -d '/' -f 5)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Construct the OIDC Provider ARN
echo "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"
```

#### Complete Script to Get Both Values
```bash
#!/bin/bash

CLUSTER_NAME="your-cluster-name"
AWS_REGION="us-east-1"

# Get OIDC issuer URL
OIDC_URL=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query "cluster.identity.oidc.issuer" \
  --output text)

# Extract OIDC ID
OIDC_ID=$(echo $OIDC_URL | cut -d '/' -f 5)

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Construct OIDC Provider ARN
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"

echo "OIDC Provider URL: $OIDC_URL"
echo "OIDC Provider ARN: $OIDC_ARN"
echo ""
echo "Terraform variables:"
echo "oidc_provider_url = \"$OIDC_URL\""
echo "oidc_provider_arn = \"$OIDC_ARN\""
```

### Method 2: AWS Console

1. **Navigate to EKS Console**:
   - Go to AWS Console → EKS → Clusters
   - Select your cluster

2. **Find OIDC Provider URL**:
   - In the cluster details, look for "OpenID Connect provider URL"
   - Copy the full URL

3. **Construct OIDC Provider ARN**:
   - Format: `arn:aws:iam::{account-id}:oidc-provider/{oidc-url-without-https}`
   - Example: `arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6`

### Method 3: Terraform Data Source

You can also retrieve the OIDC provider information using Terraform data sources:

```hcl
# data.tf
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Extract OIDC provider URL
locals {
  oidc_provider_url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.oidc_provider_url, "https://", "")}"
}

data "aws_caller_identity" "current" {}
```

## Terraform Configuration Examples

### Complete terraform.tfvars Example

```hcl
# terraform.tfvars

# AWS Configuration
aws_account_id = "123456789012"
aws_region     = "us-east-1"

# EKS Cluster Configuration
cluster_name = "my-production-cluster"

# OIDC Provider Configuration (obtained from EKS cluster)
oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"

# Environment
environment = "prod"

# Authentication Method
enable_pod_identity = false  # Use IRSA

# Tags
tags = {
  Terraform   = "true"
  Environment = "prod"
  Project     = "eks-addons"
  Owner       = "platform-team"
  CostCenter  = "production"
}
```

### Environment-Specific Examples

#### Development Environment
```hcl
# environments/dev.tfvars
cluster_name = "my-dev-cluster"
oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/DEV123456789ABCDEF"
oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/DEV123456789ABCDEF"
environment = "dev"
enable_pod_identity = true
```

#### Production Environment
```hcl
# environments/prod.tfvars
cluster_name = "my-prod-cluster"
oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/PROD987654321FEDCBA"
oidc_provider_arn = "arn:aws:iam::987654321098:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/PROD987654321FEDCBA"
environment = "prod"
enable_pod_identity = false  # Use IRSA for production
```

## Validation

### Verify OIDC Provider Exists

```bash
# Check if OIDC provider exists in IAM
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6"

# List all OIDC providers
aws iam list-open-id-connect-providers
```

### Test OIDC Configuration

```bash
# Test OIDC endpoint accessibility
curl -s "https://oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6/.well-known/openid_configuration" | jq .

# Verify issuer matches
curl -s "https://oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6/.well-known/openid_configuration" | jq -r .issuer
```

## Common Issues and Solutions

### Issue 1: OIDC Provider Not Found

**Error**: `InvalidIdentityToken: OpenIDConnect provider's HTTPS certificate doesn't match configured thumbprint`

**Solution**: Ensure the OIDC provider is properly associated with your EKS cluster:

```bash
# Associate OIDC provider with cluster (if not already done)
eksctl utils associate-iam-oidc-provider \
  --cluster your-cluster-name \
  --approve
```

### Issue 2: Incorrect OIDC URL Format

**Error**: `Invalid OIDC provider URL`

**Solution**: Ensure the URL includes the full path:
- ✅ Correct: `https://oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6`
- ❌ Incorrect: `oidc.eks.us-east-1.amazonaws.com/id/A1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6`

### Issue 3: Region Mismatch

**Error**: `OIDC provider not found in region`

**Solution**: Ensure the region in the OIDC URL matches your EKS cluster region:
- EKS cluster in `us-west-2` should have OIDC URL with `us-west-2`
- EKS cluster in `eu-west-1` should have OIDC URL with `eu-west-1`

## Automation Script

Here's a complete script to automatically extract and format OIDC provider information:

```bash
#!/bin/bash
# get-oidc-info.sh

set -e

CLUSTER_NAME=${1:-""}
AWS_REGION=${2:-"us-east-1"}

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name> [aws-region]"
    echo "Example: $0 my-eks-cluster us-east-1"
    exit 1
fi

echo "Getting OIDC provider information for cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo ""

# Get OIDC issuer URL
OIDC_URL=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" \
  --output text 2>/dev/null)

if [ -z "$OIDC_URL" ] || [ "$OIDC_URL" = "None" ]; then
    echo "Error: Could not retrieve OIDC provider URL for cluster $CLUSTER_NAME"
    echo "Please check:"
    echo "1. Cluster name is correct"
    echo "2. Cluster exists in region $AWS_REGION"
    echo "3. AWS credentials are configured"
    echo "4. OIDC provider is associated with the cluster"
    exit 1
fi

# Extract OIDC ID
OIDC_ID=$(echo "$OIDC_URL" | cut -d '/' -f 5)

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Construct OIDC Provider ARN
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"

echo "✅ OIDC Provider Information:"
echo ""
echo "OIDC Provider URL: $OIDC_URL"
echo "OIDC Provider ARN: $OIDC_ARN"
echo "OIDC ID: $OIDC_ID"
echo "Account ID: $ACCOUNT_ID"
echo ""
echo "📋 Terraform Configuration:"
echo ""
echo "# Add these to your terraform.tfvars file:"
echo "cluster_name      = \"$CLUSTER_NAME\""
echo "oidc_provider_url = \"$OIDC_URL\""
echo "oidc_provider_arn = \"$OIDC_ARN\""
echo "aws_account_id    = \"$ACCOUNT_ID\""
echo "aws_region        = \"$AWS_REGION\""
echo ""
echo "🔍 Verification:"
echo "You can verify this OIDC provider exists by running:"
echo "aws iam get-open-id-connect-provider --open-id-connect-provider-arn \"$OIDC_ARN\""
```

Save this script and run it to automatically get your OIDC provider information:

```bash
chmod +x get-oidc-info.sh
./get-oidc-info.sh my-cluster-name us-east-1
```

This will provide you with the exact values needed for your Terraform configuration.