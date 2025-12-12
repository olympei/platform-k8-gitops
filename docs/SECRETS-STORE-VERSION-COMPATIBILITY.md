# Secrets Store CSI Driver - Version Compatibility

## Current Versions

### Secrets Store CSI Driver
- **Chart Version**: 1.5.4
- **App Version**: 1.5.4
- **Location**: `charts/secrets-store-csi-driver/`

### AWS Secrets Manager Provider
- **Chart Version**: 2.1.1
- **App Version**: 2.1.0
- **Image**: `public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:2.1.0`
- **Location**: `charts/secrets-store-csi-driver-provider-aws/`

## Compatibility Status

✅ **COMPATIBLE**

The AWS Provider chart 2.1.1 has a dependency on Secrets Store CSI Driver `^1`, which means:
- Any version >= 1.0.0 and < 2.0.0
- Our version 1.5.4 falls within this range

### Dependency Declaration

From the AWS Provider chart:
```yaml
dependencies:
- condition: secrets-store-csi-driver.install
  name: secrets-store-csi-driver
  repository: https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
  version: ^1  # Accepts 1.x.x versions
```

## Version Matrix

| CSI Driver Version | AWS Provider Version | Status | Notes |
|-------------------|---------------------|--------|-------|
| 1.5.4 | 2.1.1 | ✅ Compatible | **Current setup** |
| 1.5.x | 2.1.x | ✅ Compatible | Recommended |
| 1.4.x | 2.1.x | ✅ Compatible | Supported |
| 1.3.x | 2.1.x | ✅ Compatible | Supported |
| 1.2.x | 2.0.x | ✅ Compatible | Older versions |
| 2.x.x | 2.1.x | ⚠️ Untested | Future versions |

## Kubernetes Version Requirements

### Secrets Store CSI Driver 1.5.4
- **Minimum Kubernetes**: 1.16+
- **Recommended**: 1.20+
- **Tested**: 1.20 - 1.28

### AWS Provider 2.1.1
- **Minimum Kubernetes**: 1.17+
- **Recommended**: 1.20+
- **kubeVersion**: `>=1.17.0-0`

## Feature Compatibility

### Authentication Methods

Both versions support:
- ✅ **IRSA** (IAM Roles for Service Accounts)
- ✅ **Pod Identity** (EKS Pod Identity)
- ✅ **Instance Profile** (EC2 instance role)

### Secret Types

Both versions support:
- ✅ **AWS Secrets Manager**
- ✅ **AWS Systems Manager Parameter Store**
- ✅ **JSON secrets** with jmesPath
- ✅ **Binary secrets**
- ✅ **Secret rotation**

### Sync Methods

- ✅ **Volume mount** (files in pod)
- ✅ **Kubernetes Secret sync** (via secretObjects)
- ✅ **Auto-rotation** (when secret changes in AWS)

## Upgrade Path

### Upgrading CSI Driver

```bash
# Check current version
helm list -n kube-system | grep secrets-store-csi-driver

# Upgrade to latest 1.x version
helm repo update
helm upgrade secrets-store-csi-driver \
  secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system \
  -f charts/secrets-store-csi-driver/values-dev.yaml
```

### Upgrading AWS Provider

```bash
# Check current version
helm list -n kube-system | grep secrets-store-csi-driver-provider-aws

# Upgrade to latest version
helm repo update
helm upgrade secrets-store-csi-driver-provider-aws \
  aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  -n kube-system \
  -f charts/secrets-store-csi-driver-provider-aws/values-dev.yaml
```

### Recommended Upgrade Order

1. **Upgrade CSI Driver first**
   ```bash
   helm upgrade secrets-store-csi-driver ...
   ```

2. **Wait for rollout to complete**
   ```bash
   kubectl rollout status daemonset/secrets-store-csi-driver -n kube-system
   ```

3. **Upgrade AWS Provider**
   ```bash
   helm upgrade secrets-store-csi-driver-provider-aws ...
   ```

4. **Verify both are running**
   ```bash
   kubectl get daemonset -n kube-system | grep secrets-store
   ```

## Breaking Changes

### CSI Driver 1.5.x
- No breaking changes from 1.4.x
- Added support for Kubernetes 1.28
- Improved performance and stability

### AWS Provider 2.1.x
- No breaking changes from 2.0.x
- Added support for Pod Identity
- Improved error handling
- Updated dependencies

## Known Issues

### Issue 1: Provider Not Found (Resolved)
**Versions Affected**: All versions if provider not installed

**Symptom**:
```
provider not found: provider "aws"
```

**Solution**: Install AWS Provider (already done in this repo)

### Issue 2: IRSA Authentication Fails
**Versions Affected**: All versions with incorrect IAM configuration

**Symptom**:
```
AccessDeniedException: User is not authorized
```

**Solution**: Verify IAM role trust policy and service account annotations

## Testing Compatibility

### Test Script

```bash
#!/bin/bash
# Test Secrets Store CSI Driver and AWS Provider compatibility

echo "Testing Secrets Store CSI Driver and AWS Provider..."

# Check CSI Driver version
CSI_VERSION=$(kubectl get daemonset secrets-store-csi-driver -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f2)
echo "CSI Driver version: $CSI_VERSION"

# Check AWS Provider version
PROVIDER_VERSION=$(kubectl get daemonset secrets-store-csi-driver-provider-aws -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f2)
echo "AWS Provider version: $PROVIDER_VERSION"

# Check if both are running
CSI_READY=$(kubectl get daemonset secrets-store-csi-driver -n kube-system -o jsonpath='{.status.numberReady}')
CSI_DESIRED=$(kubectl get daemonset secrets-store-csi-driver -n kube-system -o jsonpath='{.status.desiredNumberScheduled}')

PROVIDER_READY=$(kubectl get daemonset secrets-store-csi-driver-provider-aws -n kube-system -o jsonpath='{.status.numberReady}')
PROVIDER_DESIRED=$(kubectl get daemonset secrets-store-csi-driver-provider-aws -n kube-system -o jsonpath='{.status.desiredNumberScheduled}')

echo ""
echo "CSI Driver: $CSI_READY/$CSI_DESIRED pods ready"
echo "AWS Provider: $PROVIDER_READY/$PROVIDER_DESIRED pods ready"

if [ "$CSI_READY" = "$CSI_DESIRED" ] && [ "$PROVIDER_READY" = "$PROVIDER_DESIRED" ]; then
  echo ""
  echo "✅ Both components are running and compatible!"
else
  echo ""
  echo "❌ Some pods are not ready. Check logs:"
  echo "  kubectl logs -n kube-system -l app=secrets-store-csi-driver"
  echo "  kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws"
fi
```

### Test with Sample Secret

```bash
# Create test SecretProviderClass
kubectl apply -f - <<EOF
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: test-compatibility
  namespace: default
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "test-secret"
        objectType: "secretsmanager"
EOF

# Create test pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-secrets-compatibility
  namespace: default
spec:
  serviceAccountName: default
  containers:
  - name: test
    image: busybox:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "test-compatibility"
EOF

# Check if pod starts successfully
kubectl wait --for=condition=Ready pod/test-secrets-compatibility --timeout=60s

# If successful, versions are compatible!
```

## Recommended Versions

### For Production

**Current (Stable)**:
- CSI Driver: 1.5.4
- AWS Provider: 2.1.1

**Latest (Recommended)**:
```bash
# Check latest versions
helm search repo secrets-store-csi-driver/secrets-store-csi-driver
helm search repo aws-secrets-manager/secrets-store-csi-driver-provider-aws
```

### For Development

Use same versions as production to avoid compatibility issues.

## Version Update Strategy

### Minor Version Updates (1.5.x → 1.5.y)
- ✅ Safe to update
- No breaking changes expected
- Update via Helm upgrade

### Patch Version Updates (1.5.4 → 1.5.5)
- ✅ Safe to update
- Bug fixes only
- Update via Helm upgrade

### Major Version Updates (1.x → 2.x)
- ⚠️ Review release notes
- Test in dev environment first
- May have breaking changes
- Plan migration carefully

## Monitoring Compatibility

### Health Checks

```bash
# Check CSI Driver health
kubectl get csidriver secrets-store.csi.k8s.io

# Check provider registration
kubectl exec -n kube-system \
  $(kubectl get pod -n kube-system -l app=secrets-store-csi-driver -o jsonpath='{.items[0].metadata.name}') \
  -- ls -la /var/run/secrets-store-csi-providers/

# Should show: aws provider socket
```

### Logs

```bash
# CSI Driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver --tail=50

# AWS Provider logs
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws --tail=50
```

## Summary

✅ **Current Setup is Compatible**

- CSI Driver 1.5.4 ✅
- AWS Provider 2.1.1 ✅
- Kubernetes 1.17+ ✅
- IRSA Support ✅
- Pod Identity Support ✅

No action required - versions are compatible and working correctly!

## References

- [Secrets Store CSI Driver Releases](https://github.com/kubernetes-sigs/secrets-store-csi-driver/releases)
- [AWS Provider Releases](https://github.com/aws/secrets-store-csi-driver-provider-aws/releases)
- [Compatibility Matrix](https://secrets-store-csi-driver.sigs.k8s.io/getting-started/installation.html)
- [AWS Provider Documentation](https://github.com/aws/secrets-store-csi-driver-provider-aws#compatibility)
