# K8s Apps Deployment - Quick Reference

## Deployment Methods

### Method 1: Deploy All Apps (Environment Kustomization)
```
Job: deploy:kustomize:dev or deploy:kustomize:prod
Command: kubectl apply -k k8s-resources/environments/dev
```
✅ Use when: Deploying entire environment

### Method 2: Deploy Multiple Apps Dynamically
```
Job: deploy:k8s:apps:dev or deploy:k8s:apps:prod
Variable: K8S_APPS="app1,app2,app3"
Command: Loops through apps and deploys each
```
✅ Use when: Deploying specific subset of apps

### Method 3: Deploy Single App
```
Job: deploy:k8s:ingress:dev (or other specific app job)
Variable: APP_NAME="ingress"
Command: kubectl apply -k k8s-resources/ingress/overlays/dev
```
✅ Use when: Deploying one specific app

## K8S_APPS Variable Examples

| Scenario | K8S_APPS Value | Result |
|----------|----------------|--------|
| Deploy specific apps | `"ingress,storage"` | Deploys only ingress and storage |
| Deploy one app | `"secrets-store-provider-aws"` | Deploys only AWS provider |
| Deploy all apps | `""` (empty) or unset | Auto-detects and deploys all apps |
| Use individual jobs | Don't set K8S_APPS | Use specific jobs like `deploy:k8s:ingress:dev` |

## Setting K8S_APPS Variable

### In GitLab UI
1. Go to: **Settings → CI/CD → Variables**
2. Click: **Add variable**
3. Key: `K8S_APPS`
4. Value: `"ingress,storage,secrets-store-provider-aws"`
5. Save

### In Pipeline
The variable is automatically picked up by `deploy:k8s:apps:dev` and `deploy:k8s:apps:prod` jobs.

## Available Apps

Current apps in `k8s-resources/`:
- `ingress` - Ingress resources
- `external-secrets` - External Secrets resources
- `storage` - Storage resources (PVC, StorageClass)
- `secrets-store-provider-aws` - AWS Secrets Manager Provider

## Job Comparison

| Job | Apps Deployed | Configuration |
|-----|---------------|---------------|
| `deploy:kustomize:dev` | All (via environment kustomization) | Fixed list in `environments/dev/kustomization.yaml` |
| `deploy:k8s:apps:dev` | Specific or all (dynamic) | Via `K8S_APPS` variable |
| `deploy:k8s:ingress:dev` | Single app (ingress) | Hardcoded `APP_NAME="ingress"` |
| `deploy:k8s:storage:dev` | Single app (storage) | Hardcoded `APP_NAME="storage"` |

## Common Use Cases

### Use Case 1: Update Only Ingress and Storage
```
1. Set K8S_APPS="ingress,storage"
2. Run: deploy:k8s:apps:dev
```

### Use Case 2: Deploy Everything
```
Option A: Run deploy:kustomize:dev
Option B: Set K8S_APPS="" and run deploy:k8s:apps:dev
```

### Use Case 3: Test New App
```
1. Create app in k8s-resources/my-app/
2. Set K8S_APPS="my-app"
3. Run: deploy:k8s:apps:dev
```

### Use Case 4: Deploy to Multiple Environments
```
Dev:
  Set K8S_APPS="ingress,storage"
  Run: deploy:k8s:apps:dev

Prod:
  Set K8S_APPS="ingress,storage"
  Run: deploy:k8s:apps:prod
```

## Job Output

The dynamic deployment job provides detailed output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 K8s Apps Deployment for dev
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Apps to deploy (from K8S_APPS): ingress,storage

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Processing: ingress
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📂 Path: k8s-resources/ingress/overlays/dev

🔍 Previewing resources...
✅ Kustomize build successful

🚀 Applying resources...
✅ Successfully deployed ingress

📊 Resources in namespace: ingress-nginx
NAME                                   READY   STATUS    RESTARTS   AGE
pod/ingress-nginx-controller-abc123    1/1     Running   0          10s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Processing: storage
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Deployment Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Successfully deployed: 2 apps
⏭️  Skipped: 0 apps
❌ Failed: 0 apps

✅ All apps deployed successfully!
```

## Error Handling

### App Not Found
```
⚠️  WARNING: App path not found: k8s-resources/my-app/overlays/dev
Skipping my-app
```
**Action**: Check app name spelling and ensure overlay exists

### Kustomize Build Failed
```
❌ ERROR: Failed to build kustomize for ingress
```
**Action**: Validate kustomization locally:
```bash
kubectl kustomize k8s-resources/ingress/overlays/dev
```

### Apply Failed
```
❌ Failed to deploy storage
```
**Action**: Check job logs for specific error and fix resources

## Best Practices

### 1. Use Specific Apps for Targeted Updates
```
K8S_APPS="ingress"  # Only update ingress
```

### 2. Test in Dev First
```
# Dev
K8S_APPS="my-app"
Run: deploy:k8s:apps:dev

# Then Prod
K8S_APPS="my-app"
Run: deploy:k8s:apps:prod
```

### 3. Deploy All Apps for Initial Setup
```
K8S_APPS=""  # Auto-detect all
Run: deploy:k8s:apps:dev
```

### 4. Use Individual Jobs for Single App
```
# Instead of K8S_APPS="ingress"
# Use: deploy:k8s:ingress:dev
```

## Troubleshooting

### Variable Not Working
**Check**: Ensure `K8S_APPS` is set in CI/CD variables, not in the job definition

### Apps Not Auto-Detected
**Check**: Ensure apps have proper directory structure:
```
k8s-resources/<app-name>/overlays/dev/
```

### Deployment Fails Midway
**Result**: Job shows summary with failed apps
**Action**: Fix failed apps and re-run with only those apps:
```
K8S_APPS="failed-app1,failed-app2"
```

## Quick Commands

```bash
# List available apps
ls -d k8s-resources/*/overlays/dev | cut -d'/' -f2

# Preview what will be deployed
kubectl kustomize k8s-resources/<app>/overlays/dev

# Deploy manually
kubectl apply -k k8s-resources/<app>/overlays/dev

# Check deployed resources
kubectl get all -n <namespace>
```

## Summary

| Need | Use This |
|------|----------|
| Deploy everything | `deploy:kustomize:dev` |
| Deploy specific apps | `deploy:k8s:apps:dev` with `K8S_APPS="app1,app2"` |
| Deploy all apps dynamically | `deploy:k8s:apps:dev` with `K8S_APPS=""` |
| Deploy one app | `deploy:k8s:ingress:dev` (or other specific job) |
| Add new app | Create structure, set `K8S_APPS="new-app"`, run job |

The dynamic deployment gives you maximum flexibility! 🚀
