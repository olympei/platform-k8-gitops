#!/bin/bash
# get-oidc-info.sh
# Script to automatically extract OIDC provider information from EKS cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME=${1:-""}
AWS_REGION=${2:-"us-east-1"}

# Function to print usage
usage() {
    echo -e "${BLUE}OIDC Provider Information Extractor${NC}"
    echo ""
    echo "Usage: $0 <cluster-name> [aws-region]"
    echo ""
    echo "Parameters:"
    echo "  cluster-name    EKS cluster name (required)"
    echo "  aws-region      AWS region (optional, default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0 my-eks-cluster"
    echo "  $0 my-prod-cluster us-west-2"
    echo "  $0 my-eu-cluster eu-west-1"
    echo ""
    echo "Output:"
    echo "  - OIDC Provider URL"
    echo "  - OIDC Provider ARN"
    echo "  - Terraform configuration snippet"
}

# Validate input
if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}Error: Cluster name is required${NC}"
    echo ""
    usage
    exit 1
fi

# Validate AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Validate AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please configure AWS credentials using 'aws configure' or environment variables"
    exit 1
fi

echo -e "${BLUE}Getting OIDC provider information for cluster: ${YELLOW}$CLUSTER_NAME${NC}"
echo -e "${BLUE}Region: ${YELLOW}$AWS_REGION${NC}"
echo ""

# Get OIDC issuer URL
echo -e "${BLUE}🔍 Retrieving OIDC provider information...${NC}"

OIDC_URL=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" \
  --output text 2>/dev/null)

if [ -z "$OIDC_URL" ] || [ "$OIDC_URL" = "None" ] || [ "$OIDC_URL" = "null" ]; then
    echo -e "${RED}❌ Error: Could not retrieve OIDC provider URL for cluster $CLUSTER_NAME${NC}"
    echo ""
    echo -e "${YELLOW}Please check:${NC}"
    echo "1. Cluster name is correct: $CLUSTER_NAME"
    echo "2. Cluster exists in region: $AWS_REGION"
    echo "3. AWS credentials have EKS permissions"
    echo "4. OIDC provider is associated with the cluster"
    echo ""
    echo -e "${BLUE}To associate OIDC provider with cluster:${NC}"
    echo "eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $AWS_REGION --approve"
    exit 1
fi

# Extract OIDC ID
OIDC_ID=$(echo "$OIDC_URL" | cut -d '/' -f 5)

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Construct OIDC Provider ARN
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"

# Verify OIDC provider exists in IAM
echo -e "${BLUE}🔍 Verifying OIDC provider exists in IAM...${NC}"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" &> /dev/null; then
    echo -e "${GREEN}✅ OIDC provider verified in IAM${NC}"
else
    echo -e "${YELLOW}⚠️  OIDC provider not found in IAM${NC}"
    echo "You may need to associate the OIDC provider with your cluster:"
    echo "eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $AWS_REGION --approve"
fi

echo ""
echo -e "${GREEN}✅ OIDC Provider Information:${NC}"
echo ""
echo -e "${BLUE}Cluster Name:${NC}      $CLUSTER_NAME"
echo -e "${BLUE}AWS Region:${NC}        $AWS_REGION"
echo -e "${BLUE}Account ID:${NC}        $ACCOUNT_ID"
echo -e "${BLUE}OIDC ID:${NC}           $OIDC_ID"
echo ""
echo -e "${BLUE}OIDC Provider URL:${NC} $OIDC_URL"
echo -e "${BLUE}OIDC Provider ARN:${NC} $OIDC_ARN"
echo ""

# Generate Terraform configuration
echo -e "${GREEN}📋 Terraform Configuration:${NC}"
echo ""
echo "# Add these variables to your terraform.tfvars file:"
echo ""
echo "# AWS Configuration"
echo "aws_account_id = \"$ACCOUNT_ID\""
echo "aws_region     = \"$AWS_REGION\""
echo ""
echo "# EKS Cluster Configuration"
echo "cluster_name = \"$CLUSTER_NAME\""
echo ""
echo "# OIDC Provider Configuration"
echo "oidc_provider_url = \"$OIDC_URL\""
echo "oidc_provider_arn = \"$OIDC_ARN\""
echo ""

# Generate environment-specific files
echo -e "${GREEN}📁 Environment-Specific Configuration:${NC}"
echo ""

# Development environment
cat > terraform.tfvars.dev << EOF
# Development Environment Configuration
# Generated on $(date)

# AWS Configuration
aws_account_id = "$ACCOUNT_ID"
aws_region     = "$AWS_REGION"

# EKS Cluster Configuration
cluster_name = "$CLUSTER_NAME"

# OIDC Provider Configuration
oidc_provider_url = "$OIDC_URL"
oidc_provider_arn = "$OIDC_ARN"

# Environment
environment = "dev"

# Authentication Method
enable_pod_identity = true

# Tags
tags = {
  Terraform   = "true"
  Environment = "dev"
  Project     = "eks-addons"
  Owner       = "platform-team"
  Cluster     = "$CLUSTER_NAME"
}
EOF

# Production environment
cat > terraform.tfvars.prod << EOF
# Production Environment Configuration
# Generated on $(date)

# AWS Configuration
aws_account_id = "$ACCOUNT_ID"
aws_region     = "$AWS_REGION"

# EKS Cluster Configuration
cluster_name = "$CLUSTER_NAME"

# OIDC Provider Configuration
oidc_provider_url = "$OIDC_URL"
oidc_provider_arn = "$OIDC_ARN"

# Environment
environment = "prod"

# Authentication Method
enable_pod_identity = false  # Use IRSA for production

# Tags
tags = {
  Terraform   = "true"
  Environment = "prod"
  Project     = "eks-addons"
  Owner       = "platform-team"
  Cluster     = "$CLUSTER_NAME"
  CostCenter  = "production"
}
EOF

echo "Generated configuration files:"
echo "  - terraform.tfvars.dev"
echo "  - terraform.tfvars.prod"
echo ""

# Verification commands
echo -e "${GREEN}🔍 Verification Commands:${NC}"
echo ""
echo "# Verify OIDC provider exists:"
echo "aws iam get-open-id-connect-provider \\"
echo "  --open-id-connect-provider-arn \"$OIDC_ARN\""
echo ""
echo "# Test OIDC endpoint:"
echo "curl -s \"$OIDC_URL/.well-known/openid_configuration\" | jq ."
echo ""
echo "# List all OIDC providers:"
echo "aws iam list-open-id-connect-providers"
echo ""

# Additional cluster information
echo -e "${GREEN}📊 Additional Cluster Information:${NC}"
echo ""

# Get cluster version
CLUSTER_VERSION=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.version" \
  --output text 2>/dev/null || echo "Unknown")

# Get cluster status
CLUSTER_STATUS=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.status" \
  --output text 2>/dev/null || echo "Unknown")

# Get cluster endpoint
CLUSTER_ENDPOINT=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.endpoint" \
  --output text 2>/dev/null || echo "Unknown")

echo "Cluster Version: $CLUSTER_VERSION"
echo "Cluster Status:  $CLUSTER_STATUS"
echo "Cluster Endpoint: $CLUSTER_ENDPOINT"
echo ""

# Next steps
echo -e "${GREEN}🚀 Next Steps:${NC}"
echo ""
echo "1. Copy the terraform.tfvars content to your Terraform configuration"
echo "2. Or use the generated terraform.tfvars.dev / terraform.tfvars.prod files"
echo "3. Run 'terraform plan' to verify the configuration"
echo "4. Run 'terraform apply' to create the IAM resources"
echo ""
echo -e "${BLUE}For more information, see:${NC}"
echo "  - examples/oidc-provider-configuration.md"
echo "  - terraform/README.md"