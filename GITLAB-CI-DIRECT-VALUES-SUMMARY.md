# GitLab CI/CD Direct Values Support - Summary

## ✅ Feature Added

The GitLab CI/CD pipeline now supports deploying charts using direct values files (without wrapper) to avoid coalesce warnings.

## New Environment Variable

### `USE_DIRECT_VALUES`

**Purpose:** Choose between wrapper and direct values files

**Values:**
- `true`, `1`, `yes` → Use direct values (`values-{env}-direct.yaml`)
- `false`, `0`, `no`, unset → Use wrapper values (`values-{env}.yaml`) **[Default]**

## Quick Setup

### In GitLab CI/CD Variables

1. Go to **Settings** → **CI/CD** → **Variables**
2. Add variable:
   - **Key:** `USE_DIRECT_VALUES`
   - **Value:** `true`
3. Save

### In Pipeline Trigger

When running a pipeline manually:
1. Click **Run Pipeline**
2. Add variable: `USE_DIRECT_VALUES` = `true`
3. Run

## What Changes

### With `USE_DIRECT_VALUES=true`

**Values Files Used:**
```
charts/external-dns/values-dev-direct.yaml
charts/external-dns/values-prod-direct.yaml
charts/aws-load-balancer-controller/values-dev-direct.yaml
charts/aws-load-balancer-controller/values-prod-direct.yaml
```

**Structure:** Root level (no wrapper)
```yaml
clusterName: "my-eks-cluster"
region: "us-east-1"
```

### With `USE_DIRECT_VALUES=false` (Default)

**Values Files Used:**
```
charts/external-dns/values-dev.yaml
charts/external-dns/values-prod.yaml
charts/aws-load-balancer-controller/values-dev.yaml
charts/aws-load-balancer-controller/values-prod.yaml
```

**Structure:** Nested under chart name
```yaml
external-dns:
  clusterName: "my-eks-cluster"
  region: "us-east-1"
```

## Benefits of Direct Values

✅ No Helm coalesce warnings  
✅ Official chart structure  
✅ Cleaner configuration  
✅ Easier to maintain  
✅ Matches upstream documentation  
✅ Direct .tgz deployment - Deploys packaged chart directly from charts/ subdirectory  

## Supported Charts

Currently have direct values files:
- ✅ external-dns (v0.19.0)
- ✅ aws-load-balancer-controller (v2.17.0)

## Pipeline Changes Made

### 1. Updated `.gitlab-ci.yml`

**Added:**
- New environment variable `USE_DIRECT_VALUES`
- Logic to select values file based on variable
- Documentation in header comments

**Modified Templates:**
- `.deploy_helm_hybrid` - Bulk deployment template
- `.deploy_single_chart` - Individual chart deployment template

### 2. Values File Selection Logic

```bash
if [ "$USE_DIRECT_VALUES" = "true" ]; then
  VALUES_FILE="$CHART_DIR/values-${ENVIRONMENT}-direct.yaml"
  echo "Using direct values file (no wrapper)"
else
  VALUES_FILE="$CHART_DIR/values-${ENVIRONMENT}.yaml"
  echo "Using wrapper values file"
fi
```

### 3. Pipeline Output

The logs now show which values file is being used:

```
📦 Processing: external-dns
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Using direct values file (no wrapper)
Namespace: external-dns
Values file: charts/external-dns/values-dev-direct.yaml
```

## Usage Examples

### Example 1: Deploy All Charts with Direct Values

```bash
# Set in GitLab CI/CD Variables
USE_DIRECT_VALUES=true

# Trigger job
deploy:helm:dev  # or deploy:helm:prod
```

### Example 2: Deploy Single Chart with Direct Values

```bash
# Set in GitLab CI/CD Variables
USE_DIRECT_VALUES=true

# Trigger specific chart job
deploy:external-dns:dev
deploy:aws-load-balancer-controller:prod
```

### Example 3: Per-Job Configuration

```yaml
# In .gitlab-ci.yml
deploy:external-dns:dev:
  extends: .deploy_single_chart
  variables:
    ENVIRONMENT: dev
    CHART_TO_DEPLOY: external-dns
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
    USE_DIRECT_VALUES: "true"  # Use direct for this chart
```

## Backward Compatibility

✅ **Fully backward compatible**
- Default behavior unchanged (uses wrapper values)
- Existing deployments continue to work
- No breaking changes

## Migration Path

### Gradual Migration (Recommended)

1. **Phase 1:** Test with direct values in dev
   ```bash
   USE_DIRECT_VALUES=true
   # Deploy to dev and verify
   ```

2. **Phase 2:** Deploy to prod with direct values
   ```bash
   USE_DIRECT_VALUES=true
   # Deploy to prod after successful dev testing
   ```

3. **Phase 3:** Make direct values the default (optional)
   ```yaml
   # Update .gitlab-ci.yml
   deploy:helm:dev:
     variables:
       USE_DIRECT_VALUES: "true"
   ```

### Immediate Migration

Set `USE_DIRECT_VALUES=true` globally in GitLab CI/CD variables.

## Verification

### Check Pipeline Logs

Look for:
```
Using direct values file (no wrapper)
Values file: charts/external-dns/values-dev-direct.yaml
```

### Verify Deployment

```bash
# Check deployed resources
kubectl -n external-dns get all

# Check Helm release
helm list -n external-dns

# Check values used
helm get values external-dns -n external-dns
```

## Troubleshooting

### Values File Not Found

**Error:** `Values file not found: charts/external-dns/values-dev-direct.yaml`

**Solution:**
- Ensure direct values files exist
- Or set `USE_DIRECT_VALUES=false`

### Validation Stage Failing

**Error:** `❌ Lint failed for charts/external-dns`

**Solution:**
- Ensure `USE_DIRECT_VALUES` is set in the validation job
- The validation stage automatically adapts based on the variable:
  - `USE_DIRECT_VALUES=true`: Lints .tgz files directly
  - `USE_DIRECT_VALUES=false`: Lints parent chart (wrapper)
- Verify .tgz files exist in `charts/<chart>/charts/` directory
- Run `helm dependency update` if needed

### Still Seeing Coalesce Warnings

**Check:**
- Verify direct values file has no wrapper key
- Confirm correct file is being used (check logs)
- Ensure using official chart package

## Documentation

**Detailed Guide:** `docs/GITLAB-CI-DIRECT-VALUES.md`

**Chart-Specific Guides:**
- `charts/external-dns/VALUES-FILES-GUIDE.md`
- `charts/aws-load-balancer-controller/VALUES-FILES-GUIDE.md`

## Summary

The GitLab CI/CD pipeline now supports both deployment methods:

| Method | Values Files | Use Case |
|--------|-------------|----------|
| **Wrapper** | `values-{env}.yaml` | Legacy, backward compatible |
| **Direct** | `values-{env}-direct.yaml` | Clean, no warnings, recommended |

Set `USE_DIRECT_VALUES=true` to use direct values and avoid coalesce warnings!
