# AWS Secrets Manager Provider - Final Configuration Summary

## Overview

The AWS Secrets Manager Provider has been configured to deploy to the `kube-system` namespace with proper IAM role integration.

## Configuration Summary

### Namespace
- **Deployment Namespace**: `kube-system`
- **Service Account**: `secrets-store-csi-driver-provider-aws`
- **IAM Role**: `EKS-SecretsStore-Role-{environment}`

### Files Updated

#### 1. Terraform Configuration
**File**: `terraform/locals.tf`
```terraform
secrets-store-csi-driver = {
  addon_name      = "secrets-store-csi-driver"
  namespace       = "kube-system"  # ← Updated to kube-system
  service_account = "secrets-store-csi-driver-provider-aws"
  policy_name     = "EKS-SecretsStore-Policy"
  role_name       = "EKS-SecretsStore-Role"
}
```

**Trust Policy**: Allows service account `system:serviceaccount:kube-system:secrets-store-csi-driver-provider-aws` to assume the role.

#### 2. Helm Chart Values
**Files**: 
- `charts/secrets-store-csi-driver-provider-aws/values-dev.yaml`
- `charts/secrets-store-csi-driver-provider-aws/values-prod.yaml`

```yaml
# Service Account configuration with IAM role annotations
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-{env}"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-{env}"

secrets-store-csi-driver-provider-aws:
  rbac:
    install: true
    serviceAccountName: secrets-store-csi-driver-provider-aws
```

#### 3. Custom Template
**File**: `charts/secrets-store-csi-driver-provider-aws/templates/serviceaccount-patch.yaml`

This template patches the service account created by the upstream chart to add IAM role annotations.

#### 4. Kubernetes Patches
**Files**:
- `k8s-resources/patches/aws-provider-sa-dev.yaml`
- `k8s-resources/patches/aws-provider-sa-prod.yaml`

Updated namespace to `kube-system`.

#### 5. Scripts
**File**: `scripts/annotate-aws-provider-sa.sh`

Default namespace changed to `kube-system`.

#### 6. GitLab CI/CD
**File**: `.gitlab-ci.yml`

Jobs:
- `deploy:secrets-store-provider-aws:dev`
- `deploy:secrets-store-provider-aws:prod`

These jobs deploy the chart using the standard `.deploy_single_chart` template.

## Deployment Instructions

### Prerequisites
1. Update `ACCOUNT_ID` in values files with your AWS account ID
2. Ensure IAM role `EKS-SecretsStore-Role-{env}` exists in Terraform
3. Apply Terraform changes if needed

### Step 1: Update AWS Account ID

Edit both values files:
- `charts/secrets-store-csi-driver-provider-aws/values-dev.yaml`
- `charts/secrets-store-csi-driver-provider-aws/values-prod.yaml`

Replace `ACCOUNT_ID` with your actual AWS account ID.

### Step 2: Deploy via GitLab CI/CD

1. Commit and push changes
2. Run deployment job in GitLab:
   - For dev: `deploy:secrets-store-provider-aws:dev`
   - For prod: `deploy:secrets-store-provider-aws:prod`

### Step 3: Verify Deployment

```bash
# Check DaemonSet
kubectl get daemonset -n kube-system | grep secrets-store

# Expected output:
# secrets-store-csi-driver                  3         3         3
# secrets-store-csi-driver-provider-aws     3         3         3

# Check service account annotations
kubectl get sa secrets-store-csi-driver-provider-aws -n kube-system -o yaml

# Should show:
# metadata:
#   annotations:
#     eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev
#     eks.amazonaws.com/pod-identity-association-role-arn: arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev

# Check pods
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# Check logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50
```

## IAM Configuration

### Trust Policy
The IAM role trust policy allows:
- **IRSA**: Service account in `kube-system` namespace
- **Pod Identity**: EKS Pod Identity service

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PodIdentityAssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": ["sts:AssumeRole", "sts:TagSession"]
    },
    {
      "Sid": "IRSAAssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:kube-system:secrets-store-csi-driver-provider-aws",
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

### IAM Policy
The role has permissions to:
- `secretsmanager:GetSecretValue`
- `secretsmanager:DescribeSecret`
- `ssm:GetParameter`
- `ssm:GetParameters`

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Application Pod (any namespace)                         │
│  └─ SecretProviderClass references AWS secrets          │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ Secrets Store CSI Driver (kube-system)                  │
│  └─ Communicates with provider via gRPC                 │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ AWS Secrets Manager Provider (kube-system)              │
│  └─ Service Account: secrets-store-csi-driver-provider-aws │
│  └─ IAM Role: EKS-SecretsStore-Role-{env}              │
│  └─ Fetches secrets from AWS                            │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ AWS Secrets Manager / Systems Manager Parameter Store  │
└─────────────────────────────────────────────────────────┘
```

## Key Points

1. ✅ **Single Namespace**: Everything deploys to `kube-system`
2. ✅ **Unified IAM Role**: One role supports both IRSA and Pod Identity
3. ✅ **Automatic Configuration**: Service account annotations applied via Helm
4. ✅ **No Manual Steps**: Deploy and it works!

## Troubleshooting

### Provider Not Found
```bash
# Check if provider DaemonSet is running
kubectl get daemonset -n kube-system secrets-store-csi-driver-provider-aws

# Restart CSI driver if needed
kubectl rollout restart daemonset/secrets-store-csi-driver -n kube-system
```

### Permission Denied
```bash
# Verify service account has IAM role annotation
kubectl get sa secrets-store-csi-driver-provider-aws -n kube-system -o yaml | grep eks.amazonaws.com/role-arn

# Check pod can assume role
kubectl exec -it -n kube-system <provider-pod> -- env | grep AWS
```

### Secrets Not Created
Remember: Kubernetes secrets are only created when a pod mounts the CSI volume!

See: `docs/SECRETS-NOT-CREATED-QUICK-FIX.md`

## Related Documentation

- **Setup Guide**: `docs/AWS-SECRETS-MANAGER-PROVIDER-SETUP.md`
- **Troubleshooting**: `docs/SECRETPROVIDERCLASS-TROUBLESHOOTING.md`
- **Quick Fix**: `docs/SECRETS-NOT-CREATED-QUICK-FIX.md`
- **Chart README**: `charts/secrets-store-csi-driver-provider-aws/README.md`

## Summary

The AWS Secrets Manager Provider is now configured to:
- Deploy to `kube-system` namespace
- Use service account `secrets-store-csi-driver-provider-aws`
- Assume IAM role `EKS-SecretsStore-Role-{environment}`
- Support both IRSA and Pod Identity authentication
- Work seamlessly with the Secrets Store CSI Driver

Just update the AWS account ID and deploy! 🚀
