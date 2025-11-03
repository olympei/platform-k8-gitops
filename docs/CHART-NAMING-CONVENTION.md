# Chart Deployment Pattern

## Overview

All charts in this repository are deployed directly from `.tgz` files without wrapper charts. This simplifies the structure and eliminates dependency management complexity.

## Chart Structure

| Folder Name | Chart File | Version |
|-------------|-----------|---------|
| `aws-efs-csi-driver` | `aws-efs-csi-driver-3.2.4.tgz` | 3.2.4 |
| `aws-load-balancer-controller` | `aws-load-balancer-controller-1.14.1.tgz` | 1.14.1 |
| `cluster-autoscaler` | `cluster-autoscaler-9.52.1.tgz` | 9.52.1 |
| `external-dns` | `external-dns-1.19.0.tgz` | 1.19.0 |
| `external-secrets-operator` | `external-secrets-0.20.4.tgz` | 0.20.4 |
| `ingress-nginx` | `ingress-nginx-4.13.3.tgz` | 4.13.3 |
| `metrics-server` | `metrics-server-3.13.0.tgz` | 3.13.0 |

| `secrets-store-csi-driver` | `secrets-store-csi-driver-1.5.4.tgz` | 1.5.4 |

## Deployment Pattern

### Direct Deployment from .tgz
All charts are deployed directly from packaged .tgz files:

```bash
helm upgrade --install <release-name> \
  charts/<chart-dir>/charts/<chart-file>.tgz \
  -n <namespace> \
  -f charts/<chart-dir>/values-<env>.yaml
```

### Benefits
- ✅ No wrapper charts needed
- ✅ No dependency builds required
- ✅ Simpler directory structure
- ✅ Faster deployments
- ✅ Air-gap friendly
- ✅ Version locked in repository

## CI/CD Integration

The GitLab CI pipeline automatically extracts the correct chart name from `Chart.yaml`:

```bash
# Extract actual chart name from Chart.yaml
if [ -f "$CHART_DIR/Chart.yaml" ]; then
  RELEASE_NAME=$(grep "^name:" "$CHART_DIR/Chart.yaml" | awk '{print $2}' | tr -d '"')
else
  RELEASE_NAME="$FOLDER_NAME"
fi
```

### Important Notes

1. **Folder names remain unchanged** - You still reference charts by their folder names in CI/CD variables
2. **Helm release names use Chart.yaml** - The actual Helm release will use the `platform-*` name
3. **Namespace variables use folder names** - Environment variables like `HELM_NAMESPACE_AWS_EFS_CSI_DRIVER` still use the folder name

## Examples

### Deploying a Chart
```bash
# In CI/CD, you still use the folder name
CHART_TO_DEPLOY=aws-efs-csi-driver

# But Helm will create a release named:
# platform-efs-csi-driver
```

### Checking Release Status
```bash
# List releases - you'll see platform-* names
helm list -A

# Example output:
# NAME                              NAMESPACE           STATUS
# platform-efs-csi-driver          aws-efs-csi-driver  deployed
# platform-metrics-server          metrics-server      deployed
# platform-ingress-nginx           ingress-nginx       deployed
```

### Environment Variables
```yaml
# CI/CD variables still use folder names
INSTALL_AWS_EFS_CSI_DRIVER: "true"
HELM_NAMESPACE_AWS_EFS_CSI_DRIVER: "kube-system"

# But the Helm release will be named:
# platform-efs-csi-driver
```

## Migration Notes

If you have existing deployments with the old names, you'll need to:

1. **Uninstall old releases** (optional, if you want clean names):
   ```bash
   helm uninstall aws-efs-csi-driver -n aws-efs-csi-driver
   ```

2. **Deploy with new names**:
   ```bash
   helm upgrade --install platform-efs-csi-driver charts/aws-efs-csi-driver \
     -n aws-efs-csi-driver -f charts/aws-efs-csi-driver/values-dev.yaml
   ```

Or simply let the CI/CD pipeline handle it - it will create new releases with the correct names.

## Best Practices

1. ✅ Always use a prefix for wrapper charts (`platform-`, `myorg-`, etc.)
2. ✅ Keep folder names simple and descriptive
3. ✅ Document the mapping between folder and chart names
4. ✅ Use Chart.yaml as the source of truth for release names
5. ❌ Never name a wrapper chart the same as its dependency
