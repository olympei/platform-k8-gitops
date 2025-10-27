# Chart Naming Convention

## Overview

All wrapper charts in this repository use the `platform-` prefix to distinguish them from their upstream dependencies. This follows Helm best practices and prevents naming conflicts.

## Chart Name Mapping

| Folder Name | Chart Name (in Chart.yaml) | Upstream Dependency |
|-------------|---------------------------|---------------------|
| `aws-efs-csi-driver` | `platform-efs-csi-driver` | `aws-efs-csi-driver` |
| `external-secrets-operator` | `platform-external-secrets-operator` | `external-secrets` |
| `ingress-nginx` | `platform-ingress-nginx` | `ingress-nginx` |
| `pod-identity` | `platform-pod-identity` | `eks-pod-identity-agent` |
| `secrets-store-csi-driver` | `platform-secrets-store-csi-driver` | `secrets-store-csi-driver` |
| `cluster-autoscaler` | `platform-cluster-autoscaler` | `cluster-autoscaler` |
| `metrics-server` | `platform-metrics-server` | `metrics-server` |
| `external-dns` | `platform-external-dns` | `external-dns` |

## Why This Matters

### Problem with Same Names
When a wrapper chart has the same name as its dependency:
```yaml
# ❌ BAD - Naming conflict
name: metrics-server
dependencies:
  - name: metrics-server
    repository: "https://..."
```

This causes:
- Confusion between wrapper and upstream chart
- Potential Helm resolution conflicts
- Unclear which chart is being modified
- Release naming ambiguity

### Solution with Prefix
Using a prefix clearly distinguishes your wrapper:
```yaml
# ✅ GOOD - Clear distinction
name: platform-metrics-server
dependencies:
  - name: metrics-server
    repository: "https://..."
```

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
