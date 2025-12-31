# K8s-Resources Uninstall Jobs - GitLab CI Pipeline Update

## Summary

Added comprehensive uninstall jobs for k8s-resources (Kustomize-based deployments) to the GitLab CI pipeline. The pipeline now supports both deployment and uninstallation of k8s-resources apps including External DNS RBAC configurations.

## What Was Added

### 1. Uninstall Templates

#### `.uninstall_k8s_apps` Template
- Flexible template for uninstalling one or more k8s-resources apps
- Supports `K8S_APPS` variable for batch uninstallation
- Supports `APP_NAME` variable for single app uninstallation
- Auto-detects available apps if no variables are set
- Uninstalls apps in **reverse order** to handle dependencies correctly
- Includes comprehensive error handling and status reporting

#### `.uninstall_kustomize` Template
- Uninstalls all resources from `k8s-resources/environments/{env}/`
- Environment-level uninstallation (removes everything at once)
- Includes safety warnings before deletion

### 2. Batch Uninstall Jobs

```yaml
uninstall:k8s:apps:dev
uninstall:k8s:apps:prod
```

**Features:**
- Uninstall multiple apps at once
- Use `K8S_APPS` variable to specify apps: `K8S_APPS="external-dns,ingress,storage"`
- Auto-detects all apps if `K8S_APPS` is not set
- Manual trigger for safety
- Reverse order processing for dependency handling

### 3. Individual App Uninstall Jobs

#### Development Environment
```yaml
uninstall:k8s:external-dns:dev
uninstall:k8s:ingress:dev
uninstall:k8s:external-secrets:dev
uninstall:k8s:storage:dev
uninstall:k8s:secrets-store-provider-aws:dev
```

#### Production Environment
```yaml
uninstall:k8s:external-dns:prod
uninstall:k8s:ingress:prod
uninstall:k8s:external-secrets:prod
uninstall:k8s:storage:prod
uninstall:k8s:secrets-store-provider-aws:prod
```

### 4. Environment-Level Uninstall Jobs

```yaml
uninstall:kustomize:dev
uninstall:kustomize:prod
```

**Purpose:**
- Uninstall ALL k8s-resources for an environment
- Uses `k8s-resources/environments/{env}/` kustomization
- Nuclear option - removes everything managed by kustomize

### 5. Deployment Jobs for External DNS

Added missing deployment jobs for external-dns k8s-resources:

```yaml
deploy:k8s:external-dns:dev
deploy:k8s:external-dns:prod
```

## Usage Examples

### Uninstall Single App

**Development:**
```bash
# Trigger the job manually in GitLab CI
# Job: uninstall:k8s:external-dns:dev
```

**Production:**
```bash
# Trigger the job manually in GitLab CI
# Job: uninstall:k8s:external-dns:prod
```

### Uninstall Multiple Apps

Set `K8S_APPS` variable in GitLab CI/CD variables:
```
K8S_APPS=external-dns,ingress,storage
```

Then trigger:
```bash
# Job: uninstall:k8s:apps:dev
# or
# Job: uninstall:k8s:apps:prod
```

### Uninstall All Apps (Auto-detect)

Don't set `K8S_APPS` variable, just trigger:
```bash
# Job: uninstall:k8s:apps:dev
# This will auto-detect and uninstall all apps in k8s-resources/
```

### Uninstall Everything (Environment-Level)

```bash
# Job: uninstall:kustomize:dev
# Removes ALL resources from k8s-resources/environments/dev/
```

## Safety Features

### 1. Manual Trigger Required
All uninstall jobs require manual trigger - they won't run automatically.

### 2. Reverse Order Processing
Apps are uninstalled in reverse order to handle dependencies:
```
Last deployed → First uninstalled
First deployed → Last uninstalled
```

### 3. Ignore Not Found
Uses `--ignore-not-found=true` to prevent errors if resources don't exist.

### 4. Timeout Protection
5-minute timeout for app uninstalls, 10-minute for environment-level uninstalls.

### 5. Status Reporting
Comprehensive summary showing:
- Successfully uninstalled apps
- Skipped apps (path not found)
- Failed apps with details

### 6. Warning Messages
Clear warnings before deletion:
```
⚠️  WARNING: This will delete resources from the cluster!
```

## Pipeline Structure

```
stages:
  - validate
  - test
  - plan
  - deploy
  - verify
  - uninstall    ← Uninstall jobs run here
  - status
```

## Job Dependencies

### Deployment Flow
```
deploy:helm:dev
  ↓
deploy:kustomize:dev (needs: deploy:helm:dev)
  ↓
verify:dev (needs: deploy:kustomize:dev)
```

### Uninstall Flow
```
uninstall:k8s:apps:dev (manual)
  ↓
uninstall:helm:dev (manual)
```

**Note:** Uninstall jobs are independent and don't have dependencies. They can be triggered in any order.

## Available Apps

The following apps are available in `k8s-resources/`:

1. **external-dns** - External DNS RBAC configurations
2. **ingress** - Ingress resources
3. **external-secrets** - External Secrets resources
4. **storage** - Storage resources (PVC, StorageClass, etc.)
5. **secrets-store-provider-aws** - AWS Secrets Manager Provider

## Kustomize Paths

### App-Level Paths
```
k8s-resources/{app}/overlays/dev/
k8s-resources/{app}/overlays/prod/
```

### Environment-Level Paths
```
k8s-resources/environments/dev/
k8s-resources/environments/prod/
```

## Commands Used

### Deployment
```bash
kubectl apply -k k8s-resources/{app}/overlays/{env}/
```

### Uninstallation
```bash
kubectl delete -k k8s-resources/{app}/overlays/{env}/ --ignore-not-found=true --timeout=5m
```

### Preview (Dry-run)
```bash
kubectl kustomize k8s-resources/{app}/overlays/{env}/
```

## Error Handling

### Build Failures
If kustomize build fails, the app is skipped:
```
⚠️  WARNING: Failed to build kustomize for {app}
Skipping {app}
```

### Path Not Found
If app path doesn't exist, the app is skipped:
```
⚠️  WARNING: App path not found: k8s-resources/{app}/overlays/{env}
Skipping {app}
```

### Deletion Failures
If deletion fails, the error is reported and the job fails:
```
❌ Failed to uninstall {app}
```

## Integration with Existing Pipeline

### Helm Charts
- Helm chart uninstall jobs remain unchanged
- Use `UNINSTALL_*` variables to mark charts for uninstallation
- Example: `UNINSTALL_EXTERNAL_DNS=true`

### K8s-Resources
- New uninstall jobs for k8s-resources
- Use `K8S_APPS` variable to specify apps
- Example: `K8S_APPS="external-dns,ingress"`

### Both Together
You can uninstall both Helm charts and k8s-resources:
1. Trigger `uninstall:k8s:apps:dev` (uninstall k8s-resources)
2. Trigger `uninstall:helm:dev` (uninstall Helm charts)

## Best Practices

### 1. Uninstall Order
Recommended order for complete cleanup:
```
1. uninstall:k8s:apps:dev     (k8s-resources first)
2. uninstall:helm:dev         (Helm charts second)
```

### 2. Selective Uninstallation
For specific apps:
```
1. Use individual jobs: uninstall:k8s:external-dns:dev
2. Or use K8S_APPS: K8S_APPS="external-dns"
```

### 3. Testing
Test in dev environment first:
```
1. uninstall:k8s:apps:dev
2. Verify resources are deleted
3. Then proceed to prod: uninstall:k8s:apps:prod
```

### 4. Verification
After uninstallation, verify:
```bash
kubectl get all -n {namespace}
kubectl get clusterrole,clusterrolebinding | grep external-dns
```

## Troubleshooting

### Job Fails with "Path not found"
**Cause:** App doesn't exist in k8s-resources/
**Solution:** Check available apps with `ls k8s-resources/`

### Job Fails with "Failed to build kustomize"
**Cause:** Invalid kustomization.yaml or missing resources
**Solution:** Test locally with `kubectl kustomize k8s-resources/{app}/overlays/{env}/`

### Resources Not Deleted
**Cause:** Resources may have finalizers or be protected
**Solution:** 
1. Check resource status: `kubectl get {resource} -n {namespace} -o yaml`
2. Remove finalizers if needed
3. Force delete if necessary: `kubectl delete {resource} --force --grace-period=0`

### Timeout Errors
**Cause:** Resources taking too long to delete
**Solution:** Increase timeout in job definition or delete manually

## Documentation Updates

Updated the following sections in `.gitlab-ci.yml` header:

### Usage Examples
Added comprehensive examples for k8s-resources uninstallation.

### K8S_APPS Variable
Documented usage for both deployment and uninstallation.

### Available Apps
Listed all available apps including external-dns.

## Files Modified

- `.gitlab-ci.yml` - Added uninstall jobs and templates

## Files Created

- `K8S-RESOURCES-UNINSTALL-SUMMARY.md` - This documentation

## Related Documentation

- `docs/GITLAB-CI-K8S-RESOURCES.md` - K8s-resources deployment guide
- `k8s-resources/external-dns/README.md` - External DNS RBAC documentation
- `k8s-resources/external-dns/KUSTOMIZE-DEPLOYMENT-GUIDE.md` - Kustomize deployment guide

## Next Steps

1. **Test the uninstall jobs** in dev environment
2. **Verify resource deletion** after uninstallation
3. **Update ArgoCD applications** if using GitOps
4. **Document any custom uninstall procedures** for specific apps

## Example Workflow

### Complete Cleanup Workflow

```bash
# 1. Uninstall k8s-resources apps
Trigger: uninstall:k8s:apps:dev
K8S_APPS: "external-dns,ingress,storage"

# 2. Verify k8s-resources deletion
kubectl get clusterrole,clusterrolebinding | grep external-dns
kubectl get all -n ingress-nginx
kubectl get all -n storage

# 3. Uninstall Helm charts
Trigger: uninstall:helm:dev
UNINSTALL_EXTERNAL_DNS: true
UNINSTALL_INGRESS_NGINX: true

# 4. Verify Helm chart deletion
helm list -A
kubectl get all -A

# 5. Clean up namespaces (if needed)
kubectl delete namespace external-dns
kubectl delete namespace ingress-nginx
```

## Conclusion

The GitLab CI pipeline now has complete support for k8s-resources lifecycle management:
- ✅ Deployment (existing)
- ✅ Uninstallation (new)
- ✅ Verification (existing)
- ✅ Status checking (existing)

All uninstall jobs include safety features, comprehensive error handling, and detailed status reporting.
