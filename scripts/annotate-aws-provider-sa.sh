#!/bin/bash
# Script to annotate the AWS Secrets Manager Provider service account with IAM role
# This is required for the provider to access AWS Secrets Manager

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="kube-system"
SA_NAME="secrets-store-csi-driver-provider-aws"
ENVIRONMENT=""
AWS_ACCOUNT_ID=""

# Usage function
usage() {
    echo "Usage: $0 -e <environment> -a <aws-account-id>"
    echo ""
    echo "Options:"
    echo "  -e    Environment (dev or prod)"
    echo "  -a    AWS Account ID"
    echo "  -n    Namespace (default: secrets-store-csi-driver)"
    echo "  -s    Service Account name (default: secrets-store-csi-driver-provider-aws)"
    echo "  -h    Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -e dev -a 123456789012"
    echo "  $0 -e prod -a 123456789012"
    exit 1
}

# Parse command line arguments
while getopts "e:a:n:s:h" opt; do
    case $opt in
        e) ENVIRONMENT="$OPTARG" ;;
        a) AWS_ACCOUNT_ID="$OPTARG" ;;
        n) NAMESPACE="$OPTARG" ;;
        s) SA_NAME="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required parameters
if [ -z "$ENVIRONMENT" ] || [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Environment and AWS Account ID are required${NC}"
    usage
fi

# Validate environment
if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}Error: Environment must be 'dev' or 'prod'${NC}"
    exit 1
fi

# Construct IAM role ARN
IAM_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/EKS-SecretsStore-Role-${ENVIRONMENT}"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Annotating AWS Provider Service Account${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Environment:      $ENVIRONMENT"
echo "AWS Account ID:   $AWS_ACCOUNT_ID"
echo "Namespace:        $NAMESPACE"
echo "Service Account:  $SA_NAME"
echo "IAM Role ARN:     $IAM_ROLE_ARN"
echo ""

# Check if service account exists
echo -e "${YELLOW}Checking if service account exists...${NC}"
if ! kubectl get sa "$SA_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo -e "${RED}Error: Service account '$SA_NAME' not found in namespace '$NAMESPACE'${NC}"
    echo ""
    echo "Please deploy the AWS provider first:"
    echo "  helm upgrade --install secrets-store-csi-driver-provider-aws \\"
    echo "    charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \\"
    echo "    -n $NAMESPACE --create-namespace \\"
    echo "    -f charts/secrets-store-csi-driver-provider-aws/values-${ENVIRONMENT}.yaml"
    exit 1
fi

echo -e "${GREEN}✓ Service account found${NC}"
echo ""

# Add IRSA annotation
echo -e "${YELLOW}Adding IRSA annotation...${NC}"
kubectl annotate sa "$SA_NAME" -n "$NAMESPACE" \
    eks.amazonaws.com/role-arn="$IAM_ROLE_ARN" \
    --overwrite

echo -e "${GREEN}✓ IRSA annotation added${NC}"
echo ""

# Add Pod Identity annotation
echo -e "${YELLOW}Adding Pod Identity annotation...${NC}"
kubectl annotate sa "$SA_NAME" -n "$NAMESPACE" \
    eks.amazonaws.com/pod-identity-association-role-arn="$IAM_ROLE_ARN" \
    --overwrite

echo -e "${GREEN}✓ Pod Identity annotation added${NC}"
echo ""

# Verify annotations
echo -e "${YELLOW}Verifying annotations...${NC}"
kubectl get sa "$SA_NAME" -n "$NAMESPACE" -o yaml | grep -A 3 "annotations:"
echo ""

# Restart DaemonSet to pick up new annotations
echo -e "${YELLOW}Restarting DaemonSet to apply changes...${NC}"
kubectl rollout restart daemonset/"$SA_NAME" -n "$NAMESPACE" 2>/dev/null || \
    kubectl rollout restart daemonset/secrets-store-csi-driver-provider-aws -n "$NAMESPACE" 2>/dev/null || \
    echo -e "${YELLOW}Note: Could not restart DaemonSet automatically. You may need to restart it manually.${NC}"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Service account annotated successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "1. Wait for DaemonSet pods to restart"
echo "2. Verify pods are running:"
echo "   kubectl get pods -n $NAMESPACE -l app=csi-secrets-store-provider-aws"
echo "3. Check logs for any errors:"
echo "   kubectl logs -n $NAMESPACE -l app=csi-secrets-store-provider-aws --tail=50"
echo ""
