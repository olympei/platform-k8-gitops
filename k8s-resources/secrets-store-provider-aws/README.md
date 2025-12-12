# AWS Secrets Manager Provider - Kubernetes Resources

This directory contains Kubernetes manifests for the AWS Secrets Manager Provider, organized using Kustomize.

## Structure

```
secrets-store-provider-aws/
├── base/
│   ├── kustomization.yaml
│   └── secrets-store-csi-driver-provider-aws.yaml  # DaemonSet and ServiceAccount
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── serviceaccount-patch.yaml  # Dev IAM role annotations
│   └── prod/
│       ├── kustomization.yaml
│       └── serviceaccount-patch.yaml  # Prod IAM role annotations
└── README.md
```

## Base Resources

The base directory contains:
- **DaemonSet**: Runs the AWS provider on all nodes
- **ServiceAccount**: Used by the provider pods

## Overlays

Each environment overlay patches the ServiceAccount with environment-specific IAM role annotations:

### Dev
- IAM Role: `arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev`
- Namespace: `kube-system`

### Prod
- IAM Role: `arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-prod`
- Namespace: `kube-system`

## Deployment

### Using Kustomize

```bash
# Deploy to dev
kubectl apply -k overlays/dev

# Deploy to prod
kubectl apply -k overlays/prod
```

### Via Environment Kustomization

The provider is included in the environment-level kustomization:

```bash
# Deploy all dev resources (including provider)
kubectl apply -k ../../environments/dev

# Deploy all prod resources (including provider)
kubectl apply -k ../../environments/prod
```

## Configuration

Before deploying, update the IAM role ARNs in the overlay patches:

**File**: `overlays/dev/serviceaccount-patch.yaml`
```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
```

**File**: `overlays/prod/serviceaccount-patch.yaml`
```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-prod"
```

## Verification

```bash
# Check DaemonSet
kubectl get daemonset -n kube-system csi-secrets-store-provider-aws

# Check ServiceAccount annotations
kubectl get sa secrets-store-csi-driver-provider-aws -n kube-system -o yaml

# Check pods
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-aws
```

## Integration with Helm

This Kustomize setup is an alternative to the Helm chart deployment. Choose one method:

- **Helm** (Recommended): Use `charts/secrets-store-csi-driver-provider-aws/`
- **Kustomize**: Use this directory

The Helm chart is preferred as it includes the upstream chart and handles updates better.

## Related Documentation

- [AWS Provider Setup Guide](../../docs/AWS-SECRETS-MANAGER-PROVIDER-SETUP.md)
- [Troubleshooting Guide](../../docs/SECRETPROVIDERCLASS-TROUBLESHOOTING.md)
- [Helm Chart](../../charts/secrets-store-csi-driver-provider-aws/)
