#!/bin/bash

# SSL Certificate Management Script for NGINX Ingress Controller
# This script helps manage ACM certificates and update ingress configuration

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

# Function to print usage
usage() {
    echo -e "${BLUE}SSL Certificate Management for NGINX Ingress${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  list-certificates     List ACM certificates"
    echo "  request-certificate   Request new ACM certificate"
    echo "  import-certificate    Import existing certificate"
    echo "  update-config        Update ingress configuration with certificate"
    echo "  validate-certificate  Validate certificate configuration"
    echo "  check-expiration     Check certificate expiration"
    echo ""
    echo "Options:"
    echo "  --domain DOMAIN      Domain name for certificate"
    echo "  --environment ENV    Environment (dev|prod) [default: dev]"
    echo "  --certificate-arn ARN Certificate ARN"
    echo "  --region REGION      AWS region [default: us-east-1]"
    echo "  --validation-method METHOD Validation method (DNS|EMAIL) [default: DNS]"
    echo "  --cert-file FILE     Certificate file path"
    echo "  --key-file FILE      Private key file path"
    echo "  --chain-file FILE    Certificate chain file path"
    echo ""
    echo "Examples:"
    echo "  $0 list-certificates --region us-east-1"
    echo "  $0 request-certificate --domain '*.internal.example.com' --validation-method DNS"
    echo "  $0 update-config --environment prod --certificate-arn arn:aws:acm:..."
    echo "  $0 check-expiration --certificate-arn arn:aws:acm:..."
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

# Function to list ACM certificates
list_certificates() {
    local region=$1
    
    echo -e "${BLUE}ACM Certificates in region $region:${NC}"
    echo ""
    
    aws acm list-certificates \
        --region "$region" \
        --query 'CertificateSummaryList[*].[DomainName,CertificateArn,Status]' \
        --output table
}

# Function to request new certificate
request_certificate() {
    local domain=$1
    local validation_method=$2
    local region=$3
    
    echo -e "${BLUE}Requesting certificate for domain: $domain${NC}"
    
    # Prepare SANs (Subject Alternative Names)
    local sans=""
    if [[ "$domain" == *.* ]]; then
        # If it's a wildcard, add the base domain as SAN
        local base_domain="${domain#*.}"
        sans="--subject-alternative-names $base_domain"
    fi
    
    # Request certificate
    local cert_arn=$(aws acm request-certificate \
        --domain-name "$domain" \
        $sans \
        --validation-method "$validation_method" \
        --region "$region" \
        --query 'CertificateArn' \
        --output text)
    
    echo -e "${GREEN}✅ Certificate requested successfully${NC}"
    echo "Certificate ARN: $cert_arn"
    
    if [ "$validation_method" = "DNS" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  DNS validation required. Add the following CNAME records to your DNS:${NC}"
        
        # Wait a moment for the certificate to be processed
        sleep 5
        
        aws acm describe-certificate \
            --certificate-arn "$cert_arn" \
            --region "$region" \
            --query 'Certificate.DomainValidationOptions[*].[DomainName,ResourceRecord.Name,ResourceRecord.Value]' \
            --output table
    fi
    
    return 0
}

# Function to import existing certificate
import_certificate() {
    local cert_file=$1
    local key_file=$2
    local chain_file=$3
    local region=$4
    
    echo -e "${BLUE}Importing certificate...${NC}"
    
    # Validate files exist
    for file in "$cert_file" "$key_file"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}Error: File not found: $file${NC}"
            exit 1
        fi
    done
    
    # Prepare chain parameter
    local chain_param=""
    if [ -n "$chain_file" ] && [ -f "$chain_file" ]; then
        chain_param="--certificate-chain fileb://$chain_file"
    fi
    
    # Import certificate
    local cert_arn=$(aws acm import-certificate \
        --certificate "fileb://$cert_file" \
        --private-key "fileb://$key_file" \
        $chain_param \
        --region "$region" \
        --query 'CertificateArn' \
        --output text)
    
    echo -e "${GREEN}✅ Certificate imported successfully${NC}"
    echo "Certificate ARN: $cert_arn"
    
    return 0
}

# Function to update ingress configuration
update_config() {
    local environment=$1
    local certificate_arn=$2
    
    local values_file
    if [ "$environment" = "prod" ]; then
        values_file="$VALUES_PROD"
    else
        values_file="$VALUES_DEV"
    fi
    
    echo -e "${BLUE}Updating $environment configuration with certificate...${NC}"
    
    # Create backup
    cp "$values_file" "$values_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update certificate ARN in values file
    sed -i.tmp "s|certificateArn: .*|certificateArn: \"$certificate_arn\"|" "$values_file"
    sed -i.tmp "s|aws-load-balancer-ssl-cert: .*|service.beta.kubernetes.io/aws-load-balancer-ssl-cert: \"$certificate_arn\"|" "$values_file"
    
    # Clean up temp files
    rm -f "$values_file.tmp"
    
    echo -e "${GREEN}✅ Configuration updated successfully${NC}"
    echo "Updated file: $values_file"
    
    return 0
}

# Function to validate certificate configuration
validate_certificate() {
    local certificate_arn=$1
    local region=$2
    
    echo -e "${BLUE}Validating certificate: $certificate_arn${NC}"
    
    # Get certificate details
    local cert_info=$(aws acm describe-certificate \
        --certificate-arn "$certificate_arn" \
        --region "$region" \
        --query 'Certificate.[Status,DomainName,SubjectAlternativeNames,NotAfter]' \
        --output text 2>/dev/null)
    
    if [ -z "$cert_info" ]; then
        echo -e "${RED}❌ Certificate not found or invalid ARN${NC}"
        return 1
    fi
    
    # Parse certificate info
    read -r status domain_name sans not_after <<< "$cert_info"
    
    echo "Status: $status"
    echo "Domain: $domain_name"
    echo "SANs: $sans"
    echo "Expires: $not_after"
    
    if [ "$status" != "ISSUED" ]; then
        echo -e "${YELLOW}⚠️  Certificate status is not ISSUED${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Certificate is valid and issued${NC}"
    return 0
}

# Function to check certificate expiration
check_expiration() {
    local certificate_arn=$1
    local region=$2
    
    echo -e "${BLUE}Checking certificate expiration...${NC}"
    
    # Get expiration date
    local not_after=$(aws acm describe-certificate \
        --certificate-arn "$certificate_arn" \
        --region "$region" \
        --query 'Certificate.NotAfter' \
        --output text 2>/dev/null)
    
    if [ -z "$not_after" ]; then
        echo -e "${RED}❌ Certificate not found${NC}"
        return 1
    fi
    
    # Convert to epoch time
    local expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$not_after" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    echo "Certificate expires: $not_after"
    echo "Days until expiry: $days_until_expiry"
    
    if [ $days_until_expiry -lt 30 ]; then
        echo -e "${RED}⚠️  Certificate expires in less than 30 days!${NC}"
    elif [ $days_until_expiry -lt 60 ]; then
        echo -e "${YELLOW}⚠️  Certificate expires in less than 60 days${NC}"
    else
        echo -e "${GREEN}✅ Certificate expiration is acceptable${NC}"
    fi
    
    return 0
}

# Function to show current configuration
show_current_config() {
    local environment=$1
    
    local values_file
    if [ "$environment" = "prod" ]; then
        values_file="$VALUES_PROD"
    else
        values_file="$VALUES_DEV"
    fi
    
    echo -e "${BLUE}Current SSL configuration for $environment:${NC}"
    echo ""
    
    # Extract certificate ARN
    local cert_arn=$(grep "certificateArn:" "$values_file" | sed 's/.*: "\(.*\)"/\1/')
    if [ -n "$cert_arn" ]; then
        echo "Certificate ARN: $cert_arn"
        
        # Validate the certificate
        validate_certificate "$cert_arn" "$REGION"
    else
        echo "No certificate configured"
    fi
}

# Parse command line arguments
ENVIRONMENT="dev"
REGION="us-east-1"
VALIDATION_METHOD="DNS"
DOMAIN=""
CERTIFICATE_ARN=""
CERT_FILE=""
KEY_FILE=""
CHAIN_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --certificate-arn)
            CERTIFICATE_ARN="$2"
            shift 2
            ;;
        --validation-method)
            VALIDATION_METHOD="$2"
            shift 2
            ;;
        --cert-file)
            CERT_FILE="$2"
            shift 2
            ;;
        --key-file)
            KEY_FILE="$2"
            shift 2
            ;;
        --chain-file)
            CHAIN_FILE="$2"
            shift 2
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

# Main script logic
case "${COMMAND:-}" in
    "list-certificates")
        validate_aws
        list_certificates "$REGION"
        ;;
    
    "request-certificate")
        if [ -z "$DOMAIN" ]; then
            echo -e "${RED}Error: --domain is required${NC}"
            exit 1
        fi
        
        validate_aws
        request_certificate "$DOMAIN" "$VALIDATION_METHOD" "$REGION"
        ;;
    
    "import-certificate")
        if [ -z "$CERT_FILE" ] || [ -z "$KEY_FILE" ]; then
            echo -e "${RED}Error: --cert-file and --key-file are required${NC}"
            exit 1
        fi
        
        validate_aws
        import_certificate "$CERT_FILE" "$KEY_FILE" "$CHAIN_FILE" "$REGION"
        ;;
    
    "update-config")
        if [ -z "$CERTIFICATE_ARN" ]; then
            echo -e "${RED}Error: --certificate-arn is required${NC}"
            exit 1
        fi
        
        update_config "$ENVIRONMENT" "$CERTIFICATE_ARN"
        ;;
    
    "validate-certificate")
        if [ -z "$CERTIFICATE_ARN" ]; then
            echo -e "${RED}Error: --certificate-arn is required${NC}"
            exit 1
        fi
        
        validate_aws
        validate_certificate "$CERTIFICATE_ARN" "$REGION"
        ;;
    
    "check-expiration")
        if [ -z "$CERTIFICATE_ARN" ]; then
            echo -e "${RED}Error: --certificate-arn is required${NC}"
            exit 1
        fi
        
        validate_aws
        check_expiration "$CERTIFICATE_ARN" "$REGION"
        ;;
    
    "show-config")
        show_current_config "$ENVIRONMENT"
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