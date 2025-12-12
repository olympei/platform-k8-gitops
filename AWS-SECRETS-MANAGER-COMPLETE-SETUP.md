# AWS Secrets Manager Provider - Complete Setup Summary

## Overview

This document provides a comprehensive summary of the AWS Secrets Manager Provider setup for the Secrets Store CSI Driver, including all configurations, deployment methods, and verification steps.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     EKS Cluster                              │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Application Pod (namespace: gs)                      │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  Volume Mount: /mnt/secrets                     │  │  │
│  │  │  SecretProviderClass: edm-app-gold100-spc      │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Secrets Store CSI Driver (DaemonSet)                │  │
│  │  Namespace: kube-system                              │  │
│  │  Version: 1.5.4                                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  AWS Secrets Manager Provider (DaemonSet)            │  │
│  │  Namespace: kube-system                              │  │
│  │  Version: 2.1.1                                      │  │
│  │  Service Account: secrets-store-csi-driver-provider-aws │
│  │  IAM Role: EKS-SecretsStore-Role-{env}              │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                   │
└──────────────────────────┼───────────────────────────────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │  AWS Services   │
                  │  - Secrets Mgr  │
                  │  - SSM Params   │
                  └─────────────────┘
```

## Components

### 1. Secrets Store CSI Driver
- **Version**: 1.5.4
- **Namespace**: kube-system
- **Chart Location**: `charts/secrets-store-csi-driver/`
- **Purpose**: Core CSI driver that mounts secrets as volumes

### 2. AWS Secrets Manager Provider
- **Version**: 2.1.1 (chart), 2.1.0 (app)
- **Namespace**: kube-system
- **Chart Location**: `charts/secrets-store-csi-driver-provider-aws/`
- **Purpose**: Provider plugin that fetches secrets from AWS

### 3. IAM Configuration
- **Role Name Pattern**: `EKS-SecretsStore-Role-{environment}`
- **Service Account**: `secrets-store-csi-driver-provider-aws`
- **Authentication**: Unified role supporting both IRSA and Pod Identity

## Deployment Methods

### Method 1: Helm Chart (Recommended for Initial Setup)

```bash
# Dev environment
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n kube-system --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml

# Prod environment
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n kube-system --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-prod.yaml
```

### Method 2: GitLab CI/CD

```bash
# Trigger deployment via GitLab CI/CD
# Dev
deploy:secrets-store-provider-aws:dev

# Prod
deploy:secrets-store-provider-aws:prod
```

### Method 3: Kustomize (Alternative)

```bash
# Dev
kubectl apply -k k8s-resources/secrets-store-provider-aws/overlays/dev

# Prod
kubectl apply -k k8s-resources/secrets-store-provider-aws/overlays/prod
```

### Method 4: ArgoCD GitOps (Recommended for Production)

```bash
# Deploy ArgoCD Application
kubectl apply -f argocd/applications/k8s-secrets-store-provider-aws-dev.yaml
kubectl apply -f argocd/applications/k8s-secrets-store-provider-aws-prod.yaml

# Or use App of Apps
kubectl apply -f argocd/app-of-apps/platform-dev.yaml
```

## Configuration Files

### Helm Chart Values

**Dev**: `charts/secrets-store-csi-driver-provider-aws/values-dev.yaml`
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"

secrets-store-csi-driver-provider-aws:
  awsRegion: "us-east-1"
  rbac:
    install: true
    serviceAccountName: secrets-store-csi-driver-provider-aws
  secrets-store-csi-driver:
    install: false  # Already installed separately
```

**Prod**: `charts/secrets-store-csi-driver-provider-aws/values-prod.yaml`
- Same structure as dev with prod-specific role ARN

### Terraform Configuration

**Location**: `terraform/locals.tf`

```hcl
secrets-store-csi-driver = {
  addon_name      = "secrets-store-csi-driver"
  namespace       = "kube-system"
  service_account = "secrets-store-csi-driver-provider-aws"
  policy_name     = "EKS-SecretsStore-Policy"
  role_name       = "EKS-SecretsStore-Role"
}
```

### IAM Role Trust Policy

**Location**: `terraform/data.tf`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:kube-system:secrets-store-csi-driver-provider-aws"
        }
      }
    }
  ]
}
```

### IAM Policy

**Location**: `terraform/iam-policies/secrets-store-csi-driver-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:*:ACCOUNT_ID:secret:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:*:ACCOUNT_ID:parameter/*"
    }
  ]
}
```

## Verification Steps

### 1. Check DaemonSets

```bash
kubectl get daemonset -n kube-system | grep secrets-store

# Expected output:
# secrets-store-csi-driver                  3         3         3
# secrets-store-csi-driver-provider-aws     3         3         3
```

### 2. Check Pods

```bash
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# All pods should be Running
```

### 3. Check Service Account

```bash
kubectl get sa secrets-store-csi-driver-provider-aws -n kube-system -o yaml

# Verify annotations:
# eks.amazonaws.com/role-arn
# eks.amazonaws.com/pod-identity-association-role-arn
```

### 4. Check Provider Registration

```bash
# Get CSI driver pod name
CSI_POD=$(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}')

# Check provider socket
kubectl exec -n kube-system $CSI_POD -- ls -la /var/run/secrets-store-csi-providers/

# Should show: aws.sock
```

### 5. Check Logs

```bash
# AWS Provider logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50

# CSI Driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver --tail=50
```

### 6. Test IAM Role

```bash
# Get provider pod name
PROVIDER_POD=$(kubectl get pod -n kube-system -l app=csi-secrets-store-provider-aws -o jsonpath='{.items[0].metadata.name}')

# Test IAM role assumption
kubectl exec -n kube-system $PROVIDER_POD -- aws sts get-caller-identity

# Should show the EKS-SecretsStore-Role
```

## Usage Example

### Create SecretProviderClass

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: my-app-secrets
  namespace: my-namespace
spec:
  provider: aws
  parameters:
    region: us-east-1
    objects: |
      - objectName: "my-secret-name"
        objectType: "secretsmanager"
        jmesPath:
          - path: username
            objectAlias: db_username
          - path: password
            objectAlias: db_password
  secretObjects:
    - secretName: my-app-db-credentials
      type: Opaque
      data:
        - objectName: db_username
          key: username
        - objectName: db_password
          key: password
```

### Use in Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: my-namespace
spec:
  serviceAccountName: my-app-sa  # Must have IAM role annotation
  containers:
    - name: app
      image: my-app:latest
      volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets"
          readOnly: true
      env:
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: my-app-db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-app-db-credentials
              key: password
  volumes:
    - name: secrets-store
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "my-app-secrets"
```

## Troubleshooting

### Issue 1: Provider Not Found

**Error**: `provider not found: provider "aws"`

**Solution**:
```bash
# Check provider DaemonSet
kubectl get daemonset -n kube-system secrets-store-csi-driver-provider-aws

# Check provider pods
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# Restart CSI driver
kubectl rollout restart daemonset/secrets-store-csi-driver -n kube-system
```

### Issue 2: Secrets Not Created

**Error**: SecretProviderClass exists but Kubernetes secrets not created

**Cause**: Secrets are only created when a pod mounts the volume

**Solution**:
1. Ensure pod has `volumes` section with CSI driver
2. Ensure pod has `volumeMounts` section
3. Pod must be running for secrets to be created

### Issue 3: Permission Denied

**Error**: `AccessDeniedException: User is not authorized`

**Solution**:
```bash
# Check service account annotations
kubectl get sa -n my-namespace my-app-sa -o yaml

# Verify IAM role trust policy
aws iam get-role --role-name EKS-SecretsStore-Role-dev

# Verify IAM policy
aws iam list-attached-role-policies --role-name EKS-SecretsStore-Role-dev
```

### Issue 4: Secret Not Found in AWS

**Error**: `ResourceNotFoundException: Secrets Manager can't find the specified secret`

**Solution**:
1. Verify secret exists in AWS Secrets Manager
2. Check region matches in SecretProviderClass
3. Verify secret name is correct (case-sensitive)

## Version Compatibility

| Component | Version | Status |
|-----------|---------|--------|
| Secrets Store CSI Driver | 1.5.4 | ✅ Compatible |
| AWS Provider | 2.1.1 | ✅ Compatible |
| Kubernetes | 1.17+ | ✅ Supported |
| IRSA | All versions | ✅ Supported |
| Pod Identity | All versions | ✅ Supported |

See `docs/SECRETS-STORE-VERSION-COMPATIBILITY.md` for detailed compatibility information.

## Security Best Practices

1. **Least Privilege**: Grant only necessary permissions in IAM policy
2. **Namespace Isolation**: Use separate service accounts per namespace
3. **Secret Rotation**: Enable automatic rotation in AWS Secrets Manager
4. **Audit Logging**: Enable CloudTrail for secret access auditing
5. **Encryption**: Use KMS encryption for secrets at rest

## Related Documentation

- [AWS Provider Deployment Guide](docs/AWS-PROVIDER-DEPLOYMENT-GUIDE.md)
- [AWS Secrets Manager Provider Setup](docs/AWS-SECRETS-MANAGER-PROVIDER-SETUP.md)
- [SecretProviderClass Troubleshooting](docs/SECRETPROVIDERCLASS-TROUBLESHOOTING.md)
- [Version Compatibility](docs/SECRETS-STORE-VERSION-COMPATIBILITY.md)
- [GitOps Migration Guide](docs/GITOPS-MIGRATION-GUIDE.md)
- [ArgoCD README](argocd/README.md)

## Quick Reference Commands

```bash
# Check status
kubectl get daemonset -n kube-system | grep secrets-store
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws

# View logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50

# Test provider
kubectl exec -n kube-system <csi-driver-pod> -- ls -la /var/run/secrets-store-csi-providers/

# List SecretProviderClasses
kubectl get secretproviderclass -A

# Describe SecretProviderClass
kubectl describe secretproviderclass <name> -n <namespace>

# Check secret sync
kubectl get secret <secret-name> -n <namespace> -o yaml
```

## Summary

✅ **Setup Complete**

- Secrets Store CSI Driver: Installed (v1.5.4)
- AWS Provider: Installed (v2.1.1)
- IAM Roles: Configured with unified trust policy
- Service Account: Annotated with IAM role
- Deployment Methods: Helm, GitLab CI/CD, Kustomize, ArgoCD
- Documentation: Comprehensive guides available
- Verification: All components tested and working

The AWS Secrets Manager Provider is now ready to use. Applications can mount secrets from AWS Secrets Manager and SSM Parameter Store as volumes in their pods.

