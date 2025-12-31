# K8s-Resources Uninstall - Quick Reference

## Quick Commands

### Uninstall Single App

| Environment | Job Name | Description |
|-------------|----------|-------------|
| Dev | `uninstall:k8s:external-dns:dev` | Uninstall External DNS RBAC |
| Dev | `uninstall:k8s:ingress:dev` | Uninstall Ingress resources |
| Dev | `uninstall:k8s:storage:dev` | Uninstall Storage resources |
| Dev | `uninstall:k8s:external-secrets:dev` | Uninstall External Secrets |
| Dev | `uninstall:k8s:secrets-store-provider-aws:dev` | Uninstall AWS Provider |
| Prod | `uninstall:k8s:external-dns:prod` | Uninstall External DNS RBAC |
| Prod | `uninstall:k8s:ingress:prod` | Uninstall Ingress resources |
| Prod | `uninstall:k8s:storage:prod` | Uninstall Storage resources |
| Prod | `uninstall:k8s:external-secrets:prod` | Uninstall External Secrets |
| Prod | `uninstall:k8s:secrets-store-provider-aws:prod` | Uninstall AWS Provider |

### Uninstall Multiple Apps

| Environment | Job Name | Variable | Description |
|-------------|----------|----------|-------------|
| Dev | `uninstall:k8s:apps:dev` | `K8S_APPS="external-dns,ingress"` | Uninstall specific apps |
| Dev | `uninstall:k8s:apps:dev` | (no variable) | Uninstall all apps |
| Prod | `uninstall:k8s:apps:prod` | `K8S_APPS="external-dns,ingress"` | Uninstall specific apps |
| Prod | `uninstall:k8s:apps:prod` | (no variable) | Uninstall all apps |

### Uninstall Everything

| Environment | Job Name | Description |
|-------------|----------|-------------|
| Dev | `uninstall:kustomize:dev` | Uninstall ALL k8s-resources |
| Prod | `uninstall:kustomize:prod` | Uninstall ALL k8s-resources |

## Common Scenarios

### Scenario 1: Remove External DNS RBAC Only

**GitLab CI:**
```
Trigger: uninstall:k8s:external-dns:dev
```

**Manual (for testing):**
```bash
kubectl delete -k k8s-resources/external-dns/overlays/dev/
```

### Scenario 2: Remove Multiple Apps

**GitLab CI:**
```
Job: uninstall:k8s:apps:dev
Variable: K8S_APPS=external-dns,ingress,storage
```

**Manual (for testing):**
```bash
kubectl delete -k k8s-resources/external-dns/overlays/dev/
kubectl delete -k k8s-resources/ingress/overlays/dev/
kubectl delete -k k8s-resources/storage/overlays/dev/
```

### Scenario 3: Complete Environment Cleanup

**GitLab CI:**
```
1. Trigger: uninstall:kustomize:dev
2. Trigger: uninstall:helm:dev (with UNINSTALL_* variables set)
```

**Manual (for testing):**
```bash
# Uninstall k8s-resources
kubectl delete -k k8s-resources/environments/dev/

# Uninstall Helm charts
helm uninstall external-dns -n external-dns
helm uninstall aws-load-balancer-controller -n aws-load-balancer-controller
# ... etc
```

### Scenario 4: Rollback After Failed Deployment

**GitLab CI:**
```
1. Trigger: uninstall:k8s:external-dns:dev
2. Fix the issue in k8s-resources/external-dns/
3. Trigger: deploy:k8s:external-dns:dev
```

## Verification Commands

### Check if Resources Exist

```bash
# Check ClusterRole
kubectl get clusterrole | grep external-dns

# Check ClusterRoleBinding
kubectl get clusterrolebinding | grep external-dns

# Check all resources in namespace
kubectl get all -n external-dns

# Check specific resource types
kubectl get ingress -A
kubectl get pvc -A
kubectl get secretproviderclass -A
```

### Verify Deletion

```bash
# Should return "No resources found"
kubectl get clusterrole | grep external-dns
kubectl get clusterrolebinding | grep external-dns

# Check for remaining resources
kubectl get all -n external-dns
```

## Troubleshooting

### Issue: Job fails with "Path not found"

**Error:**
```
⚠️  WARNING: App path not found: k8s-resources/external-dns/overlays/dev
```

**Solution:**
```bash
# Check if path exists
ls -la k8s-resources/external-dns/overlays/dev/

# Check available apps
ls -la k8s-resources/
```

### Issue: Resources not deleted

**Error:**
```
❌ Failed to uninstall external-dns
```

**Solution:**
```bash
# Check resource status
kubectl get clusterrole external-dns-extended -o yaml

# Check for finalizers
kubectl get clusterrole external-dns-extended -o jsonpath='{.metadata.finalizers}'

# Remove finalizers if needed
kubectl patch clusterrole external-dns-extended -p '{"metadata":{"finalizers":[]}}' --type=merge

# Force delete
kubectl delete clusterrole external-dns-extended --force --grace-period=0
```

### Issue: Timeout errors

**Error:**
```
error: timed out waiting for the condition
```

**Solution:**
```bash
# Check what's blocking deletion
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check pod status
kubectl get pods -A | grep Terminating

# Force delete stuck pods
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
```

## Safety Checklist

Before uninstalling, verify:

- [ ] Correct environment (dev/prod)
- [ ] No active workloads depending on the resources
- [ ] Backup any important data
- [ ] Notify team members
- [ ] Have rollback plan ready

## Best Practices

### 1. Test in Dev First
Always test uninstallation in dev before prod:
```
1. uninstall:k8s:external-dns:dev
2. Verify deletion
3. Test redeployment
4. Then proceed to prod
```

### 2. Use Selective Uninstallation
Prefer individual app jobs over batch uninstallation:
```
✅ Good: uninstall:k8s:external-dns:dev
⚠️  Careful: uninstall:k8s:apps:dev (uninstalls all)
```

### 3. Verify Before and After
```bash
# Before
kubectl get clusterrole,clusterrolebinding | grep external-dns

# Uninstall
# (trigger job)

# After
kubectl get clusterrole,clusterrolebinding | grep external-dns
# Should return nothing
```

### 4. Document Changes
Keep track of what was uninstalled and why:
```
Date: 2025-12-31
Environment: dev
Action: Uninstalled external-dns RBAC
Reason: Upgrading to new version
Job: uninstall:k8s:external-dns:dev
```

## Related Jobs

### Deployment Jobs
- `deploy:k8s:external-dns:dev` - Deploy External DNS RBAC
- `deploy:k8s:apps:dev` - Deploy multiple apps
- `deploy:kustomize:dev` - Deploy all k8s-resources

### Verification Jobs
- `verify:dev` - Verify cluster state
- `status:dev` - Check Helm chart status

### Helm Uninstall Jobs
- `uninstall:external-dns:dev` - Uninstall External DNS Helm chart
- `uninstall:helm:dev` - Uninstall all marked Helm charts

## Environment Variables

### K8S_APPS
Controls which apps to deploy/uninstall:
```
K8S_APPS="external-dns"              # Single app
K8S_APPS="external-dns,ingress"      # Multiple apps
K8S_APPS=""                          # All apps (auto-detect)
```

### KUBECONFIG_DATA
Automatically set by job:
```
Dev:  $DEV_KUBECONFIG_B64
Prod: $PROD_KUBECONFIG_B64
```

## Manual Commands Reference

### Deploy
```bash
kubectl apply -k k8s-resources/external-dns/overlays/dev/
```

### Uninstall
```bash
kubectl delete -k k8s-resources/external-dns/overlays/dev/ --ignore-not-found=true
```

### Preview
```bash
kubectl kustomize k8s-resources/external-dns/overlays/dev/
```

### Diff
```bash
kubectl diff -k k8s-resources/external-dns/overlays/dev/
```

## Job Output Examples

### Successful Uninstall
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗑️  K8s Apps Uninstall for dev
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Single app to uninstall: external-dns

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗑️  Processing: external-dns
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📂 Path: k8s-resources/external-dns/overlays/dev

🔍 Checking for existing resources...
📋 Resources to be deleted:
      2 kind: ClusterRole
      2 kind: ClusterRoleBinding

🗑️  Deleting resources...
clusterrole.rbac.authorization.k8s.io "external-dns-extended" deleted
clusterrolebinding.rbac.authorization.k8s.io "external-dns-extended" deleted
✅ Successfully uninstalled external-dns

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Uninstall Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Successfully uninstalled: 1 apps
⏭️  Skipped: 0 apps
❌ Failed: 0 apps

✅ All apps uninstalled successfully!
```

### Failed Uninstall
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🗑️  Processing: external-dns
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  WARNING: App path not found: k8s-resources/external-dns/overlays/dev
Skipping external-dns

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Uninstall Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Successfully uninstalled: 0 apps
⏭️  Skipped: 1 apps
❌ Failed: 0 apps

✅ All apps uninstalled successfully!
```

## Additional Resources

- [K8S-RESOURCES-UNINSTALL-SUMMARY.md](../K8S-RESOURCES-UNINSTALL-SUMMARY.md) - Detailed documentation
- [GITLAB-CI-K8S-RESOURCES.md](GITLAB-CI-K8S-RESOURCES.md) - Deployment guide
- [k8s-resources/external-dns/README.md](../k8s-resources/external-dns/README.md) - External DNS RBAC
- [k8s-resources/external-dns/KUSTOMIZE-DEPLOYMENT-GUIDE.md](../k8s-resources/external-dns/KUSTOMIZE-DEPLOYMENT-GUIDE.md) - Kustomize guide
