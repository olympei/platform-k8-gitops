# AWS Secrets Manager Provider - Helm Chart Setup Complete

## Summary

Successfully created a Helm chart for the AWS Secrets Manager Provider to resolve the "provider not found: provider 'aws'" error.

## What Was Created

### 1. Chart Structure
```
charts/secrets-store-csi-driver-provider-aws/
├── Chart.yaml                                              # Chart metadata with dependencies
├── README.md                                               # Chart-specific documentation
├── values-dev.yaml                                         # Dev environment configuration
├── values-prod.yaml                                        # Prod environment configuration
└── charts/
    └── secrets-store-csi-driver-provider-aws-2.1.1.tgz    # Upstream Helm chart
```

### 2. GitLab CI/CD Integration
Added deployment jobs to `.gitlab-ci.yml`:
- `deploy:secrets-store-provider-aws:dev` - Deploy to dev environment
- `deploy:secrets-store-provider-aws:prod` - Deploy to prod environment

Added control variables:
- `INSTALL_SECRETS_STORE_CSI_DRIVER_PROVIDER_AWS` - Enable/disable installation
- `UNINSTALL_SECRETS_STORE_CSI_DRIVER_PROVIDER_AWS` - Enable/disable uninstallation
- `HELM_NAMESPACE_SECRETS_STORE_CSI_DRIVER_PROVIDER_AWS` - Override namespace

### 3. Documentation
- `charts/secrets-store-csi-driver-provider-aws/README.md` - Chart usage guide
- `docs/AWS-SECRETS-MANAGER-PROVIDER-SETUP.md` - Complete setup and deployment guide
- `docs/SECRETS-STORE-AWS-PROVIDER-FIX.md` - Updated with Helm deployment method
- `charts/README.md` - Updated with new chart information

## Configuration Required

Before deploying, you need to update **2 files** with your AWS account ID:

### File 1: `charts/secrets-store-csi-driver-provider-aws/values-dev.yaml`
```yaml
podAnnotations:
  eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
  eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-dev"
```

### File 2: `charts/secrets-store-csi-driver-provider-aws/values-prod.yaml`
```yaml
podAnnotations:
  eks.amazonaws.com/role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-prod"
  eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::YOUR_ACCOUNT_ID:role/EKS-SecretsStore-Role-prod"
```

**Also update AWS region if not using `us-east-1`:**
```yaml
secrets-store-csi-driver-provider-aws:
  awsRegion: "us-east-1"  # Change to your region
```

## Deployment Steps

### Step 1: Update Configuration
```bash
# Edit the values files with your AWS account ID
# Replace ACCOUNT_ID with your actual AWS account ID
```

### Step 2: Commit Changes
```bash
git add charts/secrets-store-csi-driver-provider-aws/
git add .gitlab-ci.yml
git add docs/
git add charts/README.md
git commit -m "Add AWS Secrets Manager Provider Helm chart"
git push
```

### Step 3: Deploy via GitLab CI/CD
In GitLab, manually trigger one of these jobs:
- `deploy:secrets-store-provider-aws:dev` (for dev environment)
- `deploy:secrets-store-provider-aws:prod` (for prod environment)

### Alternative: Deploy Manually
```bash
# For dev environment
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml \
  --wait --timeout 5m

# For prod environment
helm upgrade --install secrets-store-csi-driver-provider-aws \
  charts/secrets-store-csi-driver-provider-aws/charts/secrets-store-csi-driver-provider-aws-2.1.1.tgz \
  -n secrets-store-csi-driver --create-namespace \
  -f charts/secrets-store-csi-driver-provider-aws/values-prod.yaml \
  --wait --timeout 5m
```

## Verification

After deployment, verify the provider is running:

```bash
# Check Helm release
helm list -n secrets-store-csi-driver

# Check DaemonSet
kubectl get daemonset -n secrets-store-csi-driver

# Check pods
kubectl get pods -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws

# Check logs
kubectl logs -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws --tail=50
```

Expected output:
```
NAME                                      DESIRED   CURRENT   READY
secrets-store-csi-driver                  3         3         3
secrets-store-csi-driver-provider-aws     3         3         3
```

## What This Fixes

This chart resolves the error:
```
failed to mount secrets store object content: error connecting to provider "aws": provider not found
```

The AWS provider enables pods to:
- ✅ Fetch secrets from AWS Secrets Manager
- ✅ Fetch parameters from AWS Systems Manager Parameter Store
- ✅ Mount secrets as files in pod volumes
- ✅ Sync secrets to Kubernetes secrets (optional)
- ✅ Support automatic secret rotation

## Chart Features

- **Unified IAM Roles**: Supports both IRSA and Pod Identity with same role
- **Resource Limits**: Configured with appropriate CPU/memory limits
- **Node Selector**: Deploys on all Linux nodes
- **Tolerations**: Runs on all nodes including tainted ones
- **Security**: Non-privileged containers with read-only root filesystem
- **High Availability**: DaemonSet ensures provider runs on every node

## Key Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| `awsRegion` | `us-east-1` | AWS region for the provider |
| `image.tag` | `2.1.0` | Provider image version |
| `resources.requests.cpu` | `50m` | CPU request |
| `resources.requests.memory` | `100Mi` | Memory request |
| `secrets-store-csi-driver.install` | `false` | Install base CSI driver (already installed separately) |

## Troubleshooting

### Provider not found after deployment
```bash
# Restart CSI driver to pick up the new provider
kubectl rollout restart daemonset/secrets-store-csi-driver -n secrets-store-csi-driver
```

### Permission denied errors
```bash
# Verify IAM role annotations
kubectl get pods -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws -o yaml | grep eks.amazonaws.com/role-arn

# Check IAM role trust policy includes Pod Identity or IRSA
```

### Pods not starting
```bash
# Check DaemonSet status
kubectl describe daemonset secrets-store-csi-driver-provider-aws -n secrets-store-csi-driver

# Check pod events
kubectl describe pod -n secrets-store-csi-driver -l app=csi-secrets-store-provider-aws
```

## Related Files

- **Chart**: `charts/secrets-store-csi-driver-provider-aws/`
- **Setup Guide**: `docs/AWS-SECRETS-MANAGER-PROVIDER-SETUP.md`
- **Fix Documentation**: `docs/SECRETS-STORE-AWS-PROVIDER-FIX.md`
- **Usage Examples**: `examples/secrets-store-csi-driver-usage.yaml`
- **GitLab CI**: `.gitlab-ci.yml` (lines with `secrets-store-provider-aws`)

## Next Steps

1. ✅ Update AWS account ID in values files
2. ✅ Update AWS region if needed
3. ✅ Commit and push changes
4. ✅ Deploy via GitLab CI/CD or Helm
5. ✅ Verify deployment
6. ✅ Test with a sample SecretProviderClass
7. ✅ Update application deployments to use secrets

## Support

For detailed documentation, see:
- `docs/AWS-SECRETS-MANAGER-PROVIDER-SETUP.md` - Complete setup guide
- `charts/secrets-store-csi-driver-provider-aws/README.md` - Chart documentation
- [Official GitHub](https://github.com/aws/secrets-store-csi-driver-provider-aws) - Upstream documentation
