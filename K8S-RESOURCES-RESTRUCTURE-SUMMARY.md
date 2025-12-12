# K8s-Resources Restructure Summary

## Overview

Reorganized the `k8s-resources/` directory to follow a consistent app-specific pattern using Kustomize best practices.

## New Structure

```
k8s-resources/
├── README.md                    # Main documentation
├── environments/                # Environment-level kustomizations
│   ├── dev/
│   │   └── kustomization.yaml  # References all app overlays for dev
│   └── prod/
│       └── kustomization.yaml  # References all app overlays for prod
├── external-secrets/            # External Secrets Operator
│   ├── base/
│   └── overlays/
│       ├── dev/
│       └── prod/
├── ingress/                     # Ingress resources
│   ├── base/
│   └── overlays/
│       ├── dev/
│       └── prod/
├── secrets-store-provider-aws/  # AWS Secrets Manager Provider (NEW)
│   ├── README.md
│   ├── base/
│   │   ├── kustomization.yaml
│   │   └── secrets-store-csi-driver-provider-aws.yaml
│   └── overlays/
│       ├── dev/
│       │   ├── kustomization.yaml
│       │   └── serviceaccount-patch.yaml
│       └── prod/
│           ├── kustomization.yaml
│           └── serviceaccount-patch.yaml
└── storage/                     # Storage resources
    ├── base/
    └── overlays/
        ├── dev/
        └── prod/
```

## Changes Made

### 1. Created App-Specific Directory
**New**: `k8s-resources/secrets-store-provider-aws/`

Following the same pattern as `external-secrets/`, `ingress/`, and `storage/`.

### 2. Moved Files

| Old Location | New Location |
|-------------|--------------|
| `base/secrets-store-csi-driver-provider-aws.yaml` | `secrets-store-provider-aws/base/secrets-store-csi-driver-provider-aws.yaml` |
| `patches/aws-provider-sa-dev.yaml` | `secrets-store-provider-aws/overlays/dev/serviceaccount-patch.yaml` |
| `patches/aws-provider-sa-prod.yaml` | `secrets-store-provider-aws/overlays/prod/serviceaccount-patch.yaml` |
| `environments/dev/secrets-store-provider-aws-patch.yaml` | Deleted (moved to app overlay) |
| `environments/prod/secrets-store-provider-aws-patch.yaml` | Deleted (moved to app overlay) |

### 3. Created Kustomization Files

**Base**: `secrets-store-provider-aws/base/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - secrets-store-csi-driver-provider-aws.yaml

namespace: kube-system
```

**Overlays**: `secrets-store-provider-aws/overlays/{dev,prod}/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: kube-system

resources:
  - ../../base

patches:
  - path: serviceaccount-patch.yaml
    target:
      kind: ServiceAccount
      name: secrets-store-csi-driver-provider-aws
```

### 4. Updated Environment Kustomizations

**Before** (`environments/dev/kustomization.yaml`):
```yaml
resources:
  - ../../ingress/overlays/dev
  - ../../external-secrets/overlays/dev
  - ../../storage/overlays/dev
  - ../../base/secrets-store-csi-driver-provider-aws.yaml  # ← Direct reference

patches:
  - path: secrets-store-provider-aws-patch.yaml  # ← Patch in environment dir
    target:
      kind: ServiceAccount
      name: secrets-store-csi-driver-provider-aws
```

**After** (`environments/dev/kustomization.yaml`):
```yaml
resources:
  - ../../ingress/overlays/dev
  - ../../external-secrets/overlays/dev
  - ../../storage/overlays/dev
  - ../../secrets-store-provider-aws/overlays/dev  # ← Reference to app overlay
```

### 5. Cleaned Up Empty Directories
- Removed `k8s-resources/base/` (empty)
- Removed `k8s-resources/patches/` (empty)

### 6. Added Documentation
- `k8s-resources/README.md` - Main documentation for the structure
- `k8s-resources/secrets-store-provider-aws/README.md` - App-specific documentation

## Benefits

### 1. Consistency
All applications follow the same structure:
```
<app-name>/
├── base/
│   ├── kustomization.yaml
│   └── <resources>.yaml
├── overlays/
│   ├── dev/
│   └── prod/
└── README.md
```

### 2. Modularity
- Each app is self-contained
- Easy to add/remove applications
- Clear separation of concerns

### 3. Reusability
- Base resources can be reused across environments
- Overlays contain only environment-specific changes
- Easy to add new environments (staging, qa, etc.)

### 4. Maintainability
- Changes to an app are isolated to its directory
- No cross-app dependencies in patches
- Clear ownership and responsibility

### 5. Discoverability
- Each app has its own README
- Structure is self-documenting
- Easy to understand what resources belong to which app

## Deployment

### Deploy Entire Environment
```bash
# Deploy all apps to dev
kubectl apply -k k8s-resources/environments/dev

# Deploy all apps to prod
kubectl apply -k k8s-resources/environments/prod
```

### Deploy Specific App
```bash
# Deploy only AWS provider to dev
kubectl apply -k k8s-resources/secrets-store-provider-aws/overlays/dev

# Deploy only ingress to prod
kubectl apply -k k8s-resources/ingress/overlays/prod
```

### Preview Changes
```bash
# Preview what will be deployed
kubectl kustomize k8s-resources/environments/dev

# Diff against cluster
kubectl diff -k k8s-resources/environments/dev
```

## Adding New Applications

To add a new application, follow this pattern:

```bash
# 1. Create directory structure
mkdir -p k8s-resources/<app-name>/base
mkdir -p k8s-resources/<app-name>/overlays/dev
mkdir -p k8s-resources/<app-name>/overlays/prod

# 2. Create base resources
cat > k8s-resources/<app-name>/base/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - <resource-files>.yaml
namespace: <default-namespace>
EOF

# 3. Create overlay kustomizations
cat > k8s-resources/<app-name>/overlays/dev/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <namespace>
resources:
  - ../../base
patches:
  - path: <patch-file>.yaml
EOF

# 4. Add to environment kustomization
# Edit k8s-resources/environments/dev/kustomization.yaml
# Add: - ../../<app-name>/overlays/dev

# 5. Create README
cat > k8s-resources/<app-name>/README.md <<EOF
# <App Name>
Description and usage
EOF
```

## Migration Guide

If you have existing resources in the old structure:

### 1. Move Base Resources
```bash
mv k8s-resources/base/<app-resource>.yaml \
   k8s-resources/<app-name>/base/
```

### 2. Move Patches
```bash
mv k8s-resources/patches/<app-patch-dev>.yaml \
   k8s-resources/<app-name>/overlays/dev/<patch>.yaml

mv k8s-resources/patches/<app-patch-prod>.yaml \
   k8s-resources/<app-name>/overlays/prod/<patch>.yaml
```

### 3. Create Kustomizations
Create `kustomization.yaml` files in base and overlays.

### 4. Update Environment Kustomizations
Replace direct resource references with overlay references.

### 5. Test
```bash
kubectl kustomize k8s-resources/environments/dev
kubectl apply -k k8s-resources/environments/dev --dry-run=client
```

## Verification

Test the new structure:

```bash
# Verify kustomize builds correctly
kubectl kustomize k8s-resources/secrets-store-provider-aws/overlays/dev

# Check environment kustomization
kubectl kustomize k8s-resources/environments/dev

# Dry run deployment
kubectl apply -k k8s-resources/environments/dev --dry-run=server
```

## Related Files

- `k8s-resources/README.md` - Main documentation
- `k8s-resources/secrets-store-provider-aws/README.md` - App-specific docs
- `.gitlab-ci.yml` - CI/CD pipeline (includes kustomize deployment jobs)
- `terraform/locals.tf` - IAM role configuration

## Summary

The k8s-resources directory now follows a clean, consistent, app-specific structure that:
- ✅ Matches industry best practices for Kustomize
- ✅ Is easy to understand and maintain
- ✅ Scales well as new applications are added
- ✅ Provides clear separation between base and environment-specific configs
- ✅ Includes comprehensive documentation

All existing functionality is preserved, just better organized! 🎉
