#!/bin/bash

# NGINX Ingress Controller Load Balancer Configuration Script
# This script helps configure the ingress controller for internal or external load balancer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHART_DIR="charts/ingress-nginx"
VALUES_DEV="$CHART_DIR/values-dev.yaml"
VALUES_PROD="$CHART_DIR/values-prod.yaml"
VALUES_EXTERNAL="$CHART_DIR/values-external.yaml"

# Function to print usage
usage() {
    echo -e "${BLUE}NGINX Ingress Load Balancer Configuration${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  configure-internal    Configure for internal load balancer"
    echo "  configure-external    Configure for external load balancer"
    echo "  show-config          Show current configuration"
    echo "  validate-subnets     Validate subnet configuration"
    echo "  deploy               Deploy ingress controller"
    echo ""
    echo "Options:"
    echo "  --environment ENV    Environment (dev|prod) [default: dev]"
    echo "  --vpc-id VPC_ID      VPC ID for the load balancer"
    echo "  --subnets SUBNETS    Comma-separated list of subnet IDs"
    echo "  --dry-run           Show what would be changed without making changes"
    echo ""
    echo "Examples:"
    echo "  $0 configure-internal --environment dev --vpc-id vpc-12345 --subnets subnet-123,subnet-456"
    echo "  $0 configure-external --environment prod --subnets subnet-pub1,subnet-pub2"
    echo "  $0 show-config --environment prod"
    echo "  $0 validate-subnets --vpc-id vpc-12345"
}

# Function to validate AWS CLI and credentials
validate_aws() {
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}Error: AWS CLI not found${NC}"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}Error: AWS credentials not configured${NC}"
        exit 1
    fi
}

# Function to get VPC information
get_vpc_info() {
    local vpc_id=$1
    
    echo -e "${BLUE}VPC Information:${NC}"
    aws ec2 describe-vpcs --vpc-ids "$vpc_id" \
        --query 'Vpcs[0].[VpcId,CidrBlock,State,Tags[?Key==`Name`].Value|[0]]' \
        --output table
}

# Function to get subnet information
get_subnet_info() {
    local vpc_id=$1
    
    echo -e "${BLUE}Available Subnets in VPC $vpc_id:${NC}"
    aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$vpc_id" \
        --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch,Tags[?Key==`Name`].Value|[0]]' \
        --output table
}

# Function to validate subnets
validate_subnets() {
    local vpc_id=$1
    local subnets=$2
    
    echo -e "${BLUE}Validating subnets...${NC}"
    
    IFS=',' read -ra SUBNET_ARRAY <<< "$subnets"
    for subnet in "${SUBNET_ARRAY[@]}"; do
        subnet=$(echo "$subnet" | xargs)  # Trim whitespace
        
        echo "Checking subnet: $subnet"
        
        # Check if subnet exists and get details
        SUBNET_INFO=$(aws ec2 describe-subnets --subnet-ids "$subnet" \
            --query 'Subnets[0].[SubnetId,VpcId,AvailabilityZone,MapPublicIpOnLaunch,State]' \
            --output text 2>/dev/null || echo "NOT_FOUND")
        
        if [ "$SUBNET_INFO" = "NOT_FOUND" ]; then
            echo -e "  ${RED}❌ Subnet $subnet not found${NC}"
            return 1
        fi
        
        # Parse subnet info
        read -r subnet_id subnet_vpc az public_ip state <<< "$SUBNET_INFO"
        
        if [ "$subnet_vpc" != "$vpc_id" ]; then
            echo -e "  ${RED}❌ Subnet $subnet is not in VPC $vpc_id${NC}"
            return 1
        fi
        
        if [ "$state" != "available" ]; then
            echo -e "  ${YELLOW}⚠️  Subnet $subnet is not available (state: $state)${NC}"
        fi
        
        if [ "$public_ip" = "True" ]; then
            echo -e "  ${GREEN}✅ $subnet (AZ: $az, Public)${NC}"
        else
            echo -e "  ${GREEN}✅ $subnet (AZ: $az, Private)${NC}"
        fi
    done
    
    return 0
}

# Function to update values file
update_values_file() {
    local values_file=$1
    local scheme=$2
    local vpc_id=$3
    local subnets=$4
    local dry_run=$5
    
    if [ "$dry_run" = "true" ]; then
        echo -e "${YELLOW}DRY RUN: Would update $values_file with:${NC}"
        echo "  Scheme: $scheme"
        echo "  VPC ID: $vpc_id"
        echo "  Subnets: $subnets"
        return 0
    fi
    
    # Create backup
    cp "$values_file" "$values_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update load balancer scheme
    sed -i.tmp "s/service\.beta\.kubernetes\.io\/aws-load-balancer-scheme: .*/service.beta.kubernetes.io\/aws-load-balancer-scheme: \"$scheme\"/" "$values_file"
    
    # Update subnets
    sed -i.tmp "s/service\.beta\.kubernetes\.io\/aws-load-balancer-subnets: .*/service.beta.kubernetes.io\/aws-load-balancer-subnets: \"$subnets\"/" "$values_file"
    
    # Clean up temp files
    rm -f "$values_file.tmp"
    
    echo -e "${GREEN}✅ Updated $values_file${NC}"
}

# Function to show current configuration
show_config() {
    local environment=$1
    local values_file
    
    if [ "$environment" = "prod" ]; then
        values_file="$VALUES_PROD"
    else
        values_file="$VALUES_DEV"
    fi
    
    echo -e "${BLUE}Current Configuration for $environment:${NC}"
    echo ""
    
    # Extract current scheme
    SCHEME=$(grep "aws-load-balancer-scheme:" "$values_file" | head -1 | sed 's/.*: "\(.*\)"/\1/')
    echo "Load Balancer Scheme: $SCHEME"
    
    # Extract current subnets
    SUBNETS=$(grep "aws-load-balancer-subnets:" "$values_file" | head -1 | sed 's/.*: "\(.*\)"/\1/')
    echo "Subnets: $SUBNETS"
    
    # Extract VPC from comments or config
    VPC=$(grep -E "vpc:|# vpc-" "$values_file" | head -1 | sed 's/.*vpc-\([a-z0-9]*\).*/vpc-\1/')
    if [ -n "$VPC" ]; then
        echo "VPC: $VPC"
    fi
}

# Function to deploy ingress controller
deploy_ingress() {
    local environment=$1
    local values_file
    
    if [ "$environment" = "prod" ]; then
        values_file="$VALUES_PROD"
    else
        values_file="$VALUES_DEV"
    fi
    
    echo -e "${BLUE}Deploying NGINX Ingress Controller for $environment...${NC}"
    
    # Update Helm dependencies
    helm dependency update "$CHART_DIR"
    
    # Deploy with Helm
    helm upgrade --install ingress-nginx "$CHART_DIR" \
        -n ingress-nginx --create-namespace \
        -f "$values_file" \
        --wait --timeout 10m
    
    echo -e "${GREEN}✅ Deployment completed${NC}"
    
    # Show service status
    echo ""
    echo "Service Status:"
    kubectl get svc -n ingress-nginx ingress-nginx-controller
}

# Parse command line arguments
ENVIRONMENT="dev"
VPC_ID=""
SUBNETS=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --vpc-id)
            VPC_ID="$2"
            shift 2
            ;;
        --subnets)
            SUBNETS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

# Validate environment
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
    echo -e "${RED}Error: Environment must be 'dev' or 'prod'${NC}"
    exit 1
fi

# Set values file based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    VALUES_FILE="$VALUES_PROD"
else
    VALUES_FILE="$VALUES_DEV"
fi

# Main script logic
case "${COMMAND:-}" in
    "configure-internal")
        if [ -z "$VPC_ID" ] || [ -z "$SUBNETS" ]; then
            echo -e "${RED}Error: --vpc-id and --subnets are required for internal configuration${NC}"
            exit 1
        fi
        
        validate_aws
        
        echo -e "${BLUE}Configuring internal load balancer for $ENVIRONMENT...${NC}"
        
        if validate_subnets "$VPC_ID" "$SUBNETS"; then
            update_values_file "$VALUES_FILE" "internal" "$VPC_ID" "$SUBNETS" "$DRY_RUN"
            echo -e "${GREEN}✅ Internal load balancer configuration completed${NC}"
        else
            echo -e "${RED}❌ Subnet validation failed${NC}"
            exit 1
        fi
        ;;
    
    "configure-external")
        if [ -z "$SUBNETS" ]; then
            echo -e "${RED}Error: --subnets is required for external configuration${NC}"
            exit 1
        fi
        
        validate_aws
        
        echo -e "${BLUE}Configuring external load balancer for $ENVIRONMENT...${NC}"
        
        # For external LB, we still validate subnets if VPC is provided
        if [ -n "$VPC_ID" ]; then
            if validate_subnets "$VPC_ID" "$SUBNETS"; then
                update_values_file "$VALUES_FILE" "internet-facing" "$VPC_ID" "$SUBNETS" "$DRY_RUN"
            else
                echo -e "${RED}❌ Subnet validation failed${NC}"
                exit 1
            fi
        else
            update_values_file "$VALUES_FILE" "internet-facing" "" "$SUBNETS" "$DRY_RUN"
        fi
        
        echo -e "${GREEN}✅ External load balancer configuration completed${NC}"
        ;;
    
    "show-config")
        show_config "$ENVIRONMENT"
        ;;
    
    "validate-subnets")
        if [ -z "$VPC_ID" ]; then
            echo -e "${RED}Error: --vpc-id is required for subnet validation${NC}"
            exit 1
        fi
        
        validate_aws
        get_vpc_info "$VPC_ID"
        echo ""
        get_subnet_info "$VPC_ID"
        ;;
    
    "deploy")
        deploy_ingress "$ENVIRONMENT"
        ;;
    
    "help"|"-h"|"--help")
        usage
        ;;
    
    *)
        echo -e "${RED}Error: Unknown command '${COMMAND:-}'${NC}"
        echo ""
        usage
        exit 1
        ;;
esac