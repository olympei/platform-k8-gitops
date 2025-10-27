# IAM Roles and Policies for EKS Add-ons

This directory contains IAM roles and policies for each EKS add-on, supporting both Pod Identity and IRSA (IAM Roles for Service Accounts) authentication methods.

## Authentication Methods

### Pod Identity (Recommended)
- Modern AWS authentication method for EKS
- Simpler setup and management
- Better security with temporary credentials
- Requires EKS Pod Identity Agent

### IRSA (Legacy)
- Traditional method using OIDC provider
- Requires OIDC provider setup
- Uses service account annotations

## Add-ons and Their IAM Requirements

### 1. AWS EFS CSI Driver
- **Role**: `EKS-EFS-CSI-DriverRole-{env}`
- **Policy**: Allows EFS operations (create/delete access points, describe file systems)
- **Service Accounts**: `efs-csi-controller-sa`, `efs-csi-node-sa`

### 2. External Secrets Operator
- **Role**: `EKS-ExternalSecrets-Role-{env}`
- **Policy**: Allows access to AWS Secrets Manager and SSM Parameter Store
- **Service Account**: `external-secrets-sa`

### 3. Ingress NGINX
- **Role**: `EKS-IngressNginx-Role-{env}`
- **Policy**: Allows ELB operations and EC2 describe permissions
- **Service Account**: `ingress-nginx`

### 4. Pod Identity Agent
- **Role**: `EKS-PodIdentity-Role-{env}`
- **Policy**: Allows EKS cluster operations and STS assume role
- **Service Account**: `eks-pod-identity-agent`

## Setup Instructions

### Prerequisites
Replace the following placeholders in all files:
- `ACCOUNT_ID`: Your AWS account ID
- `REGION`: Your AWS region (e.g., us-east-1)
- `OIDC_ID`: Your EKS cluster's OIDC provider ID

### For Pod Identity (Recommended)

1. **Create IAM Roles and Policies**:
```bash
# Create policy
aws iam create-policy \
  --policy-name EKS-EFS-CSI-DriverPolicy-dev \
  --policy-document file://iam/aws-efs-csi-driver-policy.json

# Create role
aws iam create-role \
  --role-name EKS-EFS-CSI-DriverRole-dev \
  --assume-role-policy-document file://iam/aws-efs-csi-driver-role.json

# Attach policy to role
aws iam attach-role-policy \
  --role-name EKS-EFS-CSI-DriverRole-dev \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/EKS-EFS-CSI-DriverPolicy-dev
```

2. **Create Pod Identity Association**:
```bash
aws eks create-pod-identity-association \
  --cluster-name your-cluster-name \
  --namespace kube-system \
  --service-account efs-csi-controller-sa \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/EKS-EFS-CSI-DriverRole-dev
```

3. **Set authMethod to "pod-identity"** in your values files

### For IRSA (Legacy)

1. **Create OIDC Provider** (if not exists):
```bash
eksctl utils associate-iam-oidc-provider --cluster your-cluster-name --approve
```

2. **Create IAM Roles and Policies** (same as Pod Identity step 1)

3. **Set authMethod to "irsa"** in your values files

## Switching Between Authentication Methods

To switch between Pod Identity and IRSA:

1. Update the `authMethod` value in your Helm values files:
   - `authMethod: "pod-identity"` for Pod Identity
   - `authMethod: "irsa"` for IRSA

2. Redeploy the Helm charts:
```bash
helm upgrade --install addon-name charts/addon-name \
  -n namespace --create-namespace \
  -f charts/addon-name/values-{env}.yaml
```

## Environment-Specific Roles

Each environment (dev/prod) should have separate IAM roles:
- Dev: `EKS-{AddonName}-Role-dev`
- Prod: `EKS-{AddonName}-Role-prod`

This provides environment isolation and follows security best practices.

## Troubleshooting

### Common Issues

1. **Pod Identity not working**:
   - Ensure Pod Identity Agent is installed and running
   - Verify Pod Identity Association exists
   - Check service account annotations

2. **IRSA not working**:
   - Verify OIDC provider is associated with cluster
   - Check service account annotations
   - Ensure trust relationship in IAM role is correct

3. **Permission denied errors**:
   - Verify IAM policy permissions
   - Check CloudTrail logs for specific denied actions
   - Ensure role ARN is correct in configurations

### Verification Commands

```bash
# Check Pod Identity Associations
aws eks list-pod-identity-associations --cluster-name your-cluster-name

# Check service account annotations
kubectl describe sa service-account-name -n namespace

# Check pod environment variables
kubectl describe pod pod-name -n namespace
```