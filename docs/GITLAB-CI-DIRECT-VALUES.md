# GitLab CI/CD - Direct Values Support

## Overview

The GitLab CI/CD pipeline now supports deploying charts using direct values files (without wrapper structure) to avoid coalesce warnings and use the official chart format.

**Important:** When using direct values files, the pipeline deploys the packaged `.tgz` chart file directly from the `charts/` subdirectory, ensuring the values structure matches the official chart format exactly.

## New Environment Variable

### `USE_DIRECT_VALUES`

Controls whether to use direct values files or wrapper values files.

**Values:**
- `true`, `1`, or `yes` - Use direct values files (`values-{env}-direct.yaml`)
- `false`, `0`, `no`, or unset - Use wrapper values files (`values-{env}.yaml`) - **Default**

## Usage

### Option 1: Set in GitLab CI/CD Variables

1. Navigate to your GitLab project
2. Go to **Settings** → **CI/CD** → **Variables**
3. Add a new variable:
   - **Key:** `USE_DIRECT_VALUES`
   - **Value:** `true`
   - **Type:** Variable
   - **Environment scope:** All (or specific environment)

### Option 2: Set in Pipeline Trigger

When manually triggering a pipeline:

1. Click **Run Pipeline**
2. Add variable:
   - **Key:** `USE_DIRECT_VALUES`
   - **Value:** `true`
3. Click **Run Pipeline**

### Option 3: Set in `.gitlab-ci.yml` (Per Job)

```yaml
deploy:helm:dev:
  extends: .deploy_helm_hybrid
  variables:
    ENVIRONMENT: dev
    HELM_RELEASES: $HELM_RELEASES_DEV
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
    USE_DIRECT_VALUES: "true"  # Use direct values
```

## Values File Selection

### With `USE_DIRECT_VALUES=true`

The pipeline will use:
- `charts/external-dns/values-dev-direct.yaml`
- `charts/external-dns/values-prod-direct.yaml`
- `charts/aws-load-balancer-controller/values-dev-direct.yaml`
- `charts/aws-load-balancer-controller/values-prod-direct.yaml`
- etc.

**Structure:** Root-level configuration (no wrapper)
```yaml
clusterName: "my-eks-cluster"
region: "us-east-1"
serviceAccount:
  create: true
```

### With `USE_DIRECT_VALUES=false` or unset (Default)

The pipeline will use:
- `charts/external-dns/values-dev.yaml`
- `charts/external-dns/values-prod.yaml`
- `charts/aws-load-balancer-controller/values-dev.yaml`
- `charts/aws-load-balancer-controller/values-prod.yaml`
- etc.

**Structure:** Nested under chart name (wrapper)
```yaml
external-dns:
  clusterName: "my-eks-cluster"
  region: "us-east-1"
  serviceAccount:
    create: true
```

## Benefits of Direct Values

✅ **No Coalesce Warnings** - Avoids Helm coalesce warnings  
✅ **Official Format** - Uses the official chart structure  
✅ **Cleaner** - Simpler, more straightforward configuration  
✅ **Easier Maintenance** - Matches upstream chart documentation  
✅ **Direct Deployment** - Deploys the .tgz file directly, bypassing parent chart wrapper

## How the Pipeline Works

### Deployment Mechanism

The pipeline uses the following logic for both wrapper and direct values:

1. **Values File Selection:**
   ```bash
   if [ "$USE_DIRECT_VALUES" = "true" ]; then
     VALUES_FILE="charts/<chart>/values-${ENVIRONMENT}-direct.yaml"
   else
     VALUES_FILE="charts/<chart>/values-${ENVIRONMENT}.yaml"
   fi
   ```

2. **Chart Package Discovery:**
   ```bash
   # Find the .tgz file in the charts/ subdirectory
   TGZ_FILE=$(find "charts/<chart>/charts" -name "*.tgz" -type f | head -1)
   ```

3. **Direct Deployment:**
   ```bash
   # Deploy the .tgz file directly with selected values
   helm upgrade --install <release-name> "$TGZ_FILE" \
     -n <namespace> --create-namespace \
     -f "$VALUES_FILE" \
     --wait --timeout 10m
   ```

### Key Points

- **Both approaches deploy the .tgz file directly** - The difference is only in the values file structure
- **No parent chart wrapper** - The packaged chart from the `charts/` subdirectory is used
- **Values structure must match** - Direct values must match the official chart's values.yaml structure
- **Automatic detection** - The pipeline automatically finds the .tgz file in the charts/ subdirectory  

## Deployment Examples

### Deploy All Charts with Direct Values

```bash
# Set variable in GitLab CI/CD settings
USE_DIRECT_VALUES=true

# Then trigger the job
# Job: deploy:helm:dev or deploy:helm:prod
```

### Deploy Single Chart with Direct Values

```bash
# Set variable in GitLab CI/CD settings
USE_DIRECT_VALUES=true

# Then trigger the specific chart job
# Job: deploy:external-dns:dev
# Job: deploy:aws-load-balancer-controller:prod
```

### Mixed Deployment (Not Recommended)

You can use different values files for different environments, but it's not recommended:

```yaml
deploy:helm:dev:
  variables:
    USE_DIRECT_VALUES: "true"  # Dev uses direct

deploy:helm:prod:
  variables:
    USE_DIRECT_VALUES: "false"  # Prod uses wrapper
```

## Verification

The pipeline will show which values file is being used:

```
📦 Processing: external-dns
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Using direct values file (no wrapper)
Namespace: external-dns
Values file: charts/external-dns/values-dev-direct.yaml
```

Or:

```
📦 Processing: external-dns
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Using wrapper values file
Namespace: external-dns
Values file: charts/external-dns/values-dev.yaml
```

## Charts Supporting Direct Values

The following charts have direct values files:

✅ **external-dns**
- `values-dev-direct.yaml`
- `values-prod-direct.yaml`

✅ **aws-load-balancer-controller**
- `values-dev-direct.yaml`
- `values-prod-direct.yaml`

Other charts will continue to use wrapper values files until direct versions are created.

## Migration Guide

### From Wrapper to Direct Values

1. **Create Direct Values Files** (if not already present)
   ```bash
   # Copy and remove wrapper key
   cp charts/my-chart/values-dev.yaml charts/my-chart/values-dev-direct.yaml
   # Edit values-dev-direct.yaml to remove the wrapper key
   ```

2. **Test Locally**
   ```bash
   helm upgrade --install my-chart \
     ./charts/my-chart/charts/my-chart-x.y.z.tgz \
     -f charts/my-chart/values-dev-direct.yaml \
     --dry-run --debug
   ```

3. **Enable in GitLab**
   ```bash
   # Set USE_DIRECT_VALUES=true in GitLab CI/CD variables
   ```

4. **Deploy and Verify**
   ```bash
   # Trigger deployment job
   # Check logs to confirm direct values are used
   ```

## Troubleshooting

### Values File Not Found

**Error:**
```
⚠️  Values file not found: charts/external-dns/values-dev-direct.yaml
Skipping chart: external-dns
```

**Solution:**
- Ensure direct values files exist for the chart
- Or set `USE_DIRECT_VALUES=false` to use wrapper values

### Wrong Values File Used

**Check the logs:**
```
Using direct values file (no wrapper)
Values file: charts/external-dns/values-dev-direct.yaml
```

**If wrong file is used:**
- Verify `USE_DIRECT_VALUES` variable is set correctly
- Check variable scope (project vs. environment)
- Ensure variable value is exactly `true`, `1`, or `yes`

### Validation Stage Failing

**Error:**
```
❌ Lint failed for charts/external-dns
```

**Solution:**
- If using `USE_DIRECT_VALUES=true`, ensure the variable is set in the validation job too
- The validation stage automatically adapts:
  - With `USE_DIRECT_VALUES=true`: Lints .tgz files directly
  - With `USE_DIRECT_VALUES=false`: Lints parent chart (wrapper)
- Ensure .tgz files exist in `charts/<chart>/charts/` directory
- Run `helm dependency update` if .tgz files are missing

### Coalesce Warnings Still Appearing

If using direct values but still seeing warnings:
- Verify the direct values file has no wrapper key
- Check that the correct file is being used (check logs)
- Ensure the chart package (.tgz) is the official version

## Compatibility

### Supported Environments
- ✅ Development (`dev`)
- ✅ Production (`prod`)

### Supported Deployment Methods
- ✅ Bulk deployment (`deploy:helm:dev`, `deploy:helm:prod`)
- ✅ Individual chart deployment (`deploy:external-dns:dev`, etc.)

### Validation Stage
- ✅ `validate:helm` - Automatically adapts based on `USE_DIRECT_VALUES`
  - When `USE_DIRECT_VALUES=true`: Lints the .tgz files directly
  - When `USE_DIRECT_VALUES=false`: Lints the parent chart (wrapper)

### Not Affected
- ❌ Kustomize deployments (use different mechanism)
- ❌ Uninstall jobs (use same values file as deployment)

## Best Practices

1. **Consistency:** Use the same approach (direct or wrapper) across all environments
2. **Documentation:** Update chart README files when switching to direct values
3. **Testing:** Always test in dev before deploying to prod
4. **Validation:** Use `--dry-run --debug` to verify configuration
5. **Version Control:** Keep both wrapper and direct values files for flexibility

## Examples

### Example 1: Deploy ExternalDNS with Direct Values

```yaml
# In GitLab CI/CD Variables
USE_DIRECT_VALUES=true

# Trigger job: deploy:external-dns:dev
```

**Result:**
- Uses `charts/external-dns/values-dev-direct.yaml`
- No coalesce warnings
- Clean deployment logs

### Example 2: Deploy All Charts with Direct Values

```yaml
# In GitLab CI/CD Variables
USE_DIRECT_VALUES=true

# Trigger job: deploy:helm:dev
```

**Result:**
- All charts use `-direct.yaml` values files
- Consistent deployment approach
- No wrapper-related issues

### Example 3: Selective Direct Values

```yaml
# In .gitlab-ci.yml
deploy:external-dns:dev:
  extends: .deploy_single_chart
  variables:
    ENVIRONMENT: dev
    CHART_TO_DEPLOY: external-dns
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
    USE_DIRECT_VALUES: "true"  # Only this chart uses direct

deploy:aws-load-balancer-controller:dev:
  extends: .deploy_single_chart
  variables:
    ENVIRONMENT: dev
    CHART_TO_DEPLOY: aws-load-balancer-controller
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
    # USE_DIRECT_VALUES not set - uses wrapper
```

## Summary

The `USE_DIRECT_VALUES` variable provides flexibility to choose between wrapper and direct values files:

- **Default (wrapper):** Maintains backward compatibility with existing deployments
- **Direct values:** Provides cleaner structure and avoids coalesce warnings

Choose the approach that best fits your workflow and gradually migrate charts to direct values as needed.
