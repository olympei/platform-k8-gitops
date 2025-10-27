#!/bin/bash

# IAM Setup Script for EKS Add-ons
# Supports both Pod Identity and IRSA authentication methods

set -e

# Configuration
ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
REGION=${AWS_REGION:-us-east-1}
CLUSTER_NAME=${EKS_CLUSTER_NAME}
ENVIRONMENT=${ENVIRONMENT:-dev}

if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: EKS_CLUSTER_NAME environment variable is required"
    exit 1
fi

echo "Setting up IAM for EKS cluster: $CLUSTER_NAME"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"

# Get OIDC provider ID
OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
echo "OIDC Provider ID: $OIDC_ID"

# Function to create IAM policy and role
create_iam_resources() {
    local addon_name=$1
    local policy_file=$2
    local role_file=$3
    local namespace=$4
    local service_account=$5
    
    echo "Creating IAM resources for $addon_name..."
    
    # Replace placeholders in policy and role files
    sed -e "s/ACCOUNT_ID/$ACCOUNT_ID/g" \
        -e "s/REGION/$REGION/g" \
        -e "s/OIDC_ID/$OIDC_ID/g" \
        $policy_file > /tmp/${addon_name}-policy.json
    
    sed -e "s/ACCOUNT_ID/$ACCOUNT_ID/g" \
        -e "s/REGION/$REGION/g" \
        -e "s/OIDC_ID/$OIDC_ID/g" \
        $role_file > /tmp/${addon_name}-role.json
    
    # Create policy
    POLICY_NAME="EKS-${addon_name}-Policy-${ENVIRONMENT}"
    aws iam create-policy \
        --policy-name $POLICY_NAME \
        --policy-document file:///tmp/${addon_name}-policy.json \
        --description "Policy for EKS $addon_name in $ENVIRONMENT" \
        2>/dev/null || echo "Policy $POLICY_NAME already exists"
    
    # Create role
    ROLE_NAME="EKS-${addon_name}-Role-${ENVIRONMENT}"
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file:///tmp/${addon_name}-role.json \
        --description "Role for EKS $addon_name in $ENVIRONMENT" \
        2>/dev/null || echo "Role $ROLE_NAME already exists"
    
    # Attach policy to role
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME
    
    echo "Created IAM resources for $addon_name: $ROLE_NAME"
    
    # Clean up temp files
    rm -f /tmp/${addon_name}-policy.json /tmp/${addon_name}-role.json
}

# Function to create Pod Identity Association
create_pod_identity_association() {
    local addon_name=$1
    local namespace=$2
    local service_account=$3
    
    ROLE_NAME="EKS-${addon_name}-Role-${ENVIRONMENT}"
    ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"
    
    echo "Creating Pod Identity Association for $service_account in $namespace..."
    
    aws eks create-pod-identity-association \
        --cluster-name $CLUSTER_NAME \
        --namespace $namespace \
        --service-account $service_account \
        --role-arn $ROLE_ARN \
        2>/dev/null || echo "Pod Identity Association for $service_account already exists"
}

# Create IAM resources for each add-on
echo "Creating IAM resources..."

# AWS EFS CSI Driver
create_iam_resources "EFS-CSI-Driver" "aws-efs-csi-driver-policy.json" "aws-efs-csi-driver-role.json" "kube-system" "efs-csi-controller-sa"

# External Secrets Operator
create_iam_resources "ExternalSecrets" "external-secrets-operator-policy.json" "external-secrets-operator-role.json" "external-secrets-system" "external-secrets-sa"

# Ingress NGINX
create_iam_resources "IngressNginx" "ingress-nginx-policy.json" "ingress-nginx-role.json" "ingress-nginx" "ingress-nginx"

# Pod Identity Agent
create_iam_resources "PodIdentity" "pod-identity-policy.json" "pod-identity-role.json" "kube-system" "eks-pod-identity-agent"

# Secrets Store CSI Driver
create_iam_resources "SecretsStore" "secrets-store-csi-driver-policy.json" "secrets-store-csi-driver-role.json" "secrets-store-csi-driver" "secrets-store-csi-driver-provider-aws"

# Cluster Autoscaler
create_iam_resources "ClusterAutoscaler" "cluster-autoscaler-policy.json" "cluster-autoscaler-role.json" "kube-system" "cluster-autoscaler"

# Metrics Server
create_iam_resources "MetricsServer" "metrics-server-policy.json" "metrics-server-role.json" "kube-system" "metrics-server"

# External DNS
create_iam_resources "ExternalDNS" "external-dns-policy.json" "external-dns-role.json" "external-dns" "external-dns"

echo ""
echo "IAM resources created successfully!"
echo ""

# Optionally create Pod Identity Associations
read -p "Do you want to create Pod Identity Associations? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating Pod Identity Associations..."
    
    create_pod_identity_association "EFS-CSI-Driver" "kube-system" "efs-csi-controller-sa"
    create_pod_identity_association "EFS-CSI-Driver" "kube-system" "efs-csi-node-sa"
    create_pod_identity_association "ExternalSecrets" "external-secrets-system" "external-secrets-sa"
    create_pod_identity_association "IngressNginx" "ingress-nginx" "ingress-nginx"
    create_pod_identity_association "PodIdentity" "kube-system" "eks-pod-identity-agent"
    create_pod_identity_association "SecretsStore" "secrets-store-csi-driver" "secrets-store-csi-driver-provider-aws"
    create_pod_identity_association "ClusterAutoscaler" "kube-system" "cluster-autoscaler"
    create_pod_identity_association "MetricsServer" "kube-system" "metrics-server"
    create_pod_identity_association "ExternalDNS" "external-dns" "external-dns"
    
    echo "Pod Identity Associations created successfully!"
fi

echo ""
echo "Setup complete! You can now deploy your Helm charts with Pod Identity authentication."
echo ""
echo "To use IRSA instead, ensure your cluster has an OIDC provider associated:"
echo "eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve"