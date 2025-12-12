# AWS Secrets Manager Provider for Secrets Store CSI Driver

This Helm chart installs the AWS Secrets Manager and Config Provider for the Secrets Store CSI Driver.

## Overview

The AWS provider enables the Secrets Store CSI Driver to fetch secrets from:
- AWS Secrets Manager
- AWS Systems Manager Parameter Store

## Prerequisites

1. **Secrets Store CSI Driver** must be installed first (via `secrets-store-csi-driver` chart)
2. **IAM Role** with permissions to access AWS Secrets Manager/SSM
3. **Pod Identity or IRSA** configured for the EKS cluster

## Installation

### Using GitLab CI/CD

```bash
# Deploy to dev
deploy:secrets-store-provider-aws:dev

# Deploy to prod
deploy:secrets-store-provider-aws:prod
```

### Manual Installation

```bash
# Dev environment
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml

# Prod environment
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-prod.yaml
```

## Configuration

### Required Updates

Before deploying, update the following in `values-{env}.yaml`:

1. **AWS Region**: Set `awsRegion` to your cluster's region
2. **AWS Account ID**: Replace `ACCOUNT_ID` in the IAM role ARNs

### IAM Role

The chart uses unified IAM roles that support both IRSA and Pod Identity:

```yaml
podAnnotations:
  eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
  eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
```

The IAM role should have permissions to:
- `secretsmanager:GetSecretValue`
- `secretsmanager:DescribeSecret`
- `ssm:GetParameter`
- `ssm:GetParameters`

## Verification

### Check DaemonSet

```bash
kubectl get daemonset -n secrets-store-csi-driver

# Expected output:
NAME                                      DESIRED   CURRENT   READY
secrets-store-csi-driver-provider-aws     3         3         3
secrets-store-csi-driver                  3         3         3
```

### Check Pods

```bash
kubectl get pods -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws
```

### Check Logs

```bash
kubectl logs -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws
```

### Test Secret Mounting

Create a test SecretProviderClass and pod to verify the provider works:

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: test-aws-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "my-secret"
        objectType: "secretsmanager"
```

## Troubleshooting

### Provider Not Found Error

If you see `provider not found: provider "aws"`, check:

1. DaemonSet is running:
   ```bash
   kubectl get daemonset -n secrets-store-csi-driver secrets-store-csi-driver-provider-aws
   ```

2. Provider is registered:
   ```bash
   kubectl exec -it -n secrets-store-csi-driver <csi-driver-pod> -- \
     ls -la /var/run/secrets-store-csi-providers/
   ```

3. Restart CSI driver if needed:
   ```bash
   kubectl rollout restart daemonset/secrets-store-csi-driver -n secrets-store-csi-driver
   ```

### Permission Denied Errors

Check IAM role configuration:

```bash
# Verify service account annotations
kubectl get sa -n secrets-store-csi-driver -o yaml

# Test IAM role assumption from a pod
kubectl exec -it <pod-name> -n <namespace> -- aws sts get-caller-identity
```

## Related Documentation

- [AWS Secrets Manager CSI Provider](https://github.com/aws/secrets-store-csi-driver-provider-aws)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- `examples/secrets-store-csi-driver-usage.yaml` - Usage examples
- `docs/SECRETS-STORE-AWS-PROVIDER-FIX.md` - Detailed troubleshooting guide

## Chart Values

Key configuration options:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `awsRegion` | AWS region | `""` |
| `image.repository` | Container image repository | `public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws` |
| `image.tag` | Container image tag | `2.1.0` |
| `resources.requests.cpu` | CPU request | `50m` |
| `resources.requests.memory` | Memory request | `100Mi` |
| `nodeSelector` | Node selector | `kubernetes.io/os: linux` |
| `tolerations` | Pod tolerations | `[]` |
| `secrets-store-csi-driver.install` | Install base CSI driver | `false` |

For all available values, see the [official chart documentation](https://github.com/aws/secrets-store-csi-driver-provider-aws/tree/main/charts/secrets-store-csi-driver-provider-aws).
