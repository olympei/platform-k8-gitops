# GitOps Migration Guide - From GitLab CI/CD to ArgoCD

## Overview

This guide covers migrating from push-based GitLab CI/CD deployments to pull-based GitOps with ArgoCD.

## Current State (Push-based)

```
Developer → Git Push → GitLab CI/CD → kubectl apply → Cluster
```

**Characteristics:**
- CI/CD pipeline has cluster credentials
- Manual trigger required for deployment
- No automatic drift correction
- Limited visibility into cluster state

## Target State (Pull-based GitOps)

```
Developer → Git Push → Git Repository ← ArgoCD (polls) → Cluster
```

**Characteristics:**
- No cluster credentials in CI/CD
- Automatic deployment on Git changes
- Automatic drift correction (self-healing)
- Full visibility via ArgoCD UI

## Migration Strategy

### Phase 1: Setup (Week 1)

#### 1.1 Install ArgoCD

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### 1.2 Configure Repository Access

```bash
# Add repository
argocd repo add https://gitlab.com/your-org/platform-k8-gitops.git \
  --username <username> \
  --password <gitlab-token>
```

#### 1.3 Create AppProject

```bash
kubectl apply -f argocd/projects/platform.yaml
```

### Phase 2: Parallel Run (Week 2-3)

Run both GitLab CI/CD and ArgoCD in parallel to validate.

#### 2.1 Deploy Non-Critical Apps to ArgoCD

Start with non-critical applications:

```bash
# Deploy storage (low risk)
kubectl apply -f argocd/applications/k8s-storage-dev.yaml

# Verify sync
argocd app get platform-storage-dev
argocd app wait platform-storage-dev --health
```

#### 2.2 Monitor Both Systems

**GitLab CI/CD:**
- Continue running existing deployment jobs
- Monitor for any issues

**ArgoCD:**
- Monitor sync status
- Verify resources are healthy
- Check for drift detection

#### 2.3 Validate Consistency

```bash
# Compare resources deployed by both methods
kubectl get all -n <namespace> -o yaml > gitlab-deployed.yaml
# After ArgoCD sync
kubectl get all -n <namespace> -o yaml > argocd-deployed.yaml
diff gitlab-deployed.yaml argocd-deployed.yaml
```

### Phase 3: Gradual Migration (Week 4-6)

Migrate applications one by one.

#### 3.1 Migration Order

**Recommended order:**
1. Storage resources (low risk, no dependencies)
2. Secrets management (AWS provider)
3. Ingress (moderate risk)
4. External Secrets (depends on secrets management)
5. Applications (highest risk)

#### 3.2 Per-App Migration Steps

For each application:

**Step 1: Deploy via ArgoCD**
```bash
kubectl apply -f argocd/applications/k8s-<app>-dev.yaml
```

**Step 2: Verify Sync**
```bash
argocd app get platform-<app>-dev
argocd app wait platform-<app>-dev --health
```

**Step 3: Test Functionality**
```bash
# Run smoke tests
# Verify application works as expected
```

**Step 4: Monitor for 24-48 hours**
- Check ArgoCD UI for sync status
- Monitor application health
- Verify no drift detected

**Step 5: Disable GitLab CI/CD Job**
```yaml
# .gitlab-ci.yml
deploy:k8s:<app>:dev:
  when: manual  # Keep for emergency rollback
  # Or comment out entirely
```

#### 3.3 Rollback Plan

If issues occur:

**Option 1: Disable ArgoCD sync**
```bash
argocd app set platform-<app>-dev --sync-policy none
```

**Option 2: Delete ArgoCD Application**
```bash
argocd app delete platform-<app>-dev
```

**Option 3: Re-enable GitLab CI/CD**
```bash
# Run GitLab job: deploy:k8s:<app>:dev
```

### Phase 4: Full GitOps (Week 7+)

Complete migration to GitOps.

#### 4.1 Deploy App of Apps

```bash
# Deploy all dev applications
kubectl apply -f argocd/app-of-apps/platform-dev.yaml

# Deploy all prod applications
kubectl apply -f argocd/app-of-apps/platform-prod.yaml
```

#### 4.2 Update GitLab CI/CD

**Keep:**
- Build jobs
- Test jobs
- Image building
- Values file updates

**Remove:**
- kubectl apply jobs
- Kustomize deployment jobs
- Cluster credentials

**Updated .gitlab-ci.yml:**
```yaml
stages:
  - build
  - test
  - update-manifests  # New stage

build:
  stage: build
  script:
    - docker build -t myapp:${CI_COMMIT_SHA} .
    - docker push myapp:${CI_COMMIT_SHA}

test:
  stage: test
  script:
    - run tests

update-manifests:
  stage: update-manifests
  script:
    - |
      # Update image tag in values file
      sed -i "s/tag: .*/tag: ${CI_COMMIT_SHA}/" charts/myapp/values-dev.yaml
      
      # Commit and push
      git config user.email "ci@example.com"
      git config user.name "GitLab CI"
      git add charts/myapp/values-dev.yaml
      git commit -m "Update myapp image to ${CI_COMMIT_SHA}"
      git push origin main
      
      # ArgoCD will automatically sync
```

#### 4.3 Remove Cluster Credentials

```bash
# Remove from GitLab CI/CD variables
# Settings → CI/CD → Variables
# Delete: DEV_KUBECONFIG_B64, PROD_KUBECONFIG_B64
```

#### 4.4 Enable Notifications

Configure ArgoCD notifications:

```yaml
# argocd-notifications-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} synced successfully.
      {{.app.status.operationState.message}}
  
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]
```

### Phase 5: Optimization (Ongoing)

#### 5.1 Enable Auto-Sync

For stable applications:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

#### 5.2 Implement Sync Waves

Control deployment order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

#### 5.3 Add Health Checks

Custom health checks for CRDs:

```yaml
health:
  - group: apps
    kind: Deployment
    check: |
      # Custom health logic
```

#### 5.4 Configure RBAC

Implement fine-grained access control:

```yaml
# AppProject
roles:
  - name: developer
    policies:
      - p, proj:platform:developer, applications, sync, platform/*, allow
```

## Comparison

### Before (GitLab CI/CD)

| Aspect | Implementation |
|--------|----------------|
| Deployment | Push-based via kubectl |
| Credentials | Stored in GitLab CI/CD |
| Drift Detection | None |
| Rollback | Re-run old pipeline |
| Visibility | GitLab job logs |
| Automation | Manual trigger |

### After (ArgoCD GitOps)

| Aspect | Implementation |
|--------|----------------|
| Deployment | Pull-based via ArgoCD |
| Credentials | Only in ArgoCD |
| Drift Detection | Automatic |
| Rollback | Git revert |
| Visibility | ArgoCD UI + Git history |
| Automation | Automatic on Git push |

## Benefits Realized

### Security
- ✅ No cluster credentials in CI/CD
- ✅ All changes audited in Git
- ✅ RBAC via AppProjects

### Reliability
- ✅ Automatic drift correction
- ✅ Self-healing applications
- ✅ Consistent deployments

### Visibility
- ✅ Real-time sync status
- ✅ Application health monitoring
- ✅ Diff view before sync

### Developer Experience
- ✅ Faster deployments (automatic)
- ✅ Easy rollback (Git revert)
- ✅ Better visibility (ArgoCD UI)

## Troubleshooting Migration

### Issue: ArgoCD Can't Access Repository

**Symptoms:**
- Application shows "ComparisonError"
- "repository not found" error

**Solution:**
```bash
# Verify repository access
argocd repo list

# Re-add repository
argocd repo add https://gitlab.com/your-org/platform-k8-gitops.git \
  --username <username> \
  --password <new-token>
```

### Issue: Resources Out of Sync

**Symptoms:**
- Application shows "OutOfSync"
- Resources differ from Git

**Solution:**
```bash
# View diff
argocd app diff platform-<app>-dev

# Sync application
argocd app sync platform-<app>-dev

# Or enable auto-sync
argocd app set platform-<app>-dev --sync-policy automated
```

### Issue: Sync Fails

**Symptoms:**
- Sync operation fails
- Resources not created

**Solution:**
```bash
# Check sync status
argocd app get platform-<app>-dev

# View detailed error
kubectl describe application platform-<app>-dev -n argocd

# Force sync
argocd app sync platform-<app>-dev --force
```

### Issue: Both Systems Deploying

**Symptoms:**
- Resources being updated by both GitLab CI/CD and ArgoCD
- Constant drift detection

**Solution:**
```bash
# Disable GitLab CI/CD job
# Comment out or set when: manual

# Or delete ArgoCD Application temporarily
argocd app delete platform-<app>-dev
```

## Rollback Strategy

If migration needs to be rolled back:

### Emergency Rollback

```bash
# 1. Disable all ArgoCD Applications
argocd app set platform-dev --sync-policy none

# 2. Delete ArgoCD Applications
kubectl delete application -n argocd -l environment=dev

# 3. Re-enable GitLab CI/CD jobs
# Uncomment deployment jobs in .gitlab-ci.yml

# 4. Re-add cluster credentials to GitLab
# Settings → CI/CD → Variables
# Add: DEV_KUBECONFIG_B64

# 5. Run GitLab deployment jobs
# Manually trigger: deploy:kustomize:dev
```

### Gradual Rollback

Roll back one application at a time:

```bash
# 1. Disable ArgoCD for specific app
argocd app set platform-<app>-dev --sync-policy none

# 2. Delete ArgoCD Application
argocd app delete platform-<app>-dev

# 3. Deploy via GitLab CI/CD
# Run job: deploy:k8s:<app>:dev
```

## Success Criteria

Migration is successful when:

- ✅ All applications deployed via ArgoCD
- ✅ Auto-sync enabled and working
- ✅ No drift detected
- ✅ GitLab CI/CD only builds/tests
- ✅ No cluster credentials in GitLab
- ✅ Team comfortable with ArgoCD UI
- ✅ Rollback tested and documented

## Timeline

| Week | Phase | Activities |
|------|-------|------------|
| 1 | Setup | Install ArgoCD, configure repository |
| 2-3 | Parallel Run | Deploy non-critical apps, monitor both systems |
| 4-6 | Gradual Migration | Migrate apps one by one |
| 7+ | Full GitOps | App of Apps, remove CI/CD deployments |

## Next Steps

1. **Install ArgoCD** in dev cluster
2. **Deploy first application** (storage)
3. **Monitor for 48 hours**
4. **Migrate next application**
5. **Repeat until all migrated**
6. **Deploy to prod** using same process

## Related Documentation

- [ArgoCD README](../argocd/README.md)
- [GitLab CI/CD K8s Resources](./GITLAB-CI-K8S-RESOURCES.md)
- [K8s Resources Structure](../k8s-resources/README.md)

## Support

For issues during migration:
1. Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-server`
2. Review application status: `argocd app get <app-name>`
3. Consult [ArgoCD documentation](https://argo-cd.readthedocs.io/)

Welcome to GitOps! 🚀
