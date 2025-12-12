# ArgoCD GitOps Configuration

This directory contains ArgoCD Application and AppProject manifests for managing platform infrastructure using GitOps principles.

## Directory Structure

```
argocd/
├── README.md
├── projects/
│   └── platform.yaml              # AppProject for platform components
├── applications/
│   ├── k8s-ingress-dev.yaml      # Ingress resources - Dev
│   ├── k8s-ingress-prod.yaml     # Ingress resources - Prod
│   ├── k8s-storage-dev.yaml      # Storage resources - Dev
│   ├── k8s-storage-prod.yaml     # Storage resources - Prod
│   ├── k8s-external-secrets-dev.yaml  # External Secrets - Dev
│   ├── k8s-external-secrets-prod.yaml # External Secrets - Prod
│   ├── k8s-secrets-store-provider-aws-dev.yaml   # AWS Provider - Dev
│   ├── k8s-secrets-store-provider-aws-prod.yaml  # AWS Provider - Prod
│   └── helm-charts-dev.yaml      # Helm charts - Dev
└── app-of-apps/
    ├── platform-dev.yaml          # App of Apps for Dev
    └── platform-prod.yaml         # App of Apps for Prod
```

## GitOps Workflow

### Traditional vs GitOps

**Traditional (Push-based)**:
```
Developer → Git Push → CI/CD Pipeline → kubectl apply → Cluster
```

**GitOps (Pull-based)**:
```
Developer → Git Push → Git Repository ← ArgoCD (polls) → Cluster
```

### Benefits

1. **Declarative**: Entire system state in Git
2. **Version Control**: Full audit trail of changes
3. **Automated**: ArgoCD continuously syncs desired state
4. **Self-Healing**: Automatically corrects drift
5. **Rollback**: Easy rollback via Git revert
6. **Security**: No cluster credentials in CI/CD

## Setup

### Prerequisites

1. **ArgoCD Installed**: ArgoCD must be installed in the cluster
2. **Git Repository**: This repository accessible to ArgoCD
3. **Cluster Access**: ArgoCD has permissions to deploy resources

### Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI at: https://localhost:8080
# Username: admin
# Password: <from above command>
```

### Configure Repository

```bash
# Add Git repository to ArgoCD
argocd repo add https://gitlab.com/your-org/platform-k8-gitops.git \
  --username <username> \
  --password <token>

# Or via UI: Settings → Repositories → Connect Repo
```

## Deployment

### Method 1: App of Apps Pattern (Recommended)

Deploy all applications for an environment using the App of Apps pattern:

```bash
# Deploy all dev applications
kubectl apply -f argocd/projects/platform.yaml
kubectl apply -f argocd/app-of-apps/platform-dev.yaml

# Deploy all prod applications
kubectl apply -f argocd/projects/platform.yaml
kubectl apply -f argocd/app-of-apps/platform-prod.yaml
```

**What happens:**
1. ArgoCD creates the platform-dev Application
2. platform-dev discovers all *-dev.yaml applications
3. ArgoCD creates individual Applications for each component
4. Each Application syncs its resources from Git

### Method 2: Individual Applications

Deploy specific applications:

```bash
# Deploy project first
kubectl apply -f argocd/projects/platform.yaml

# Deploy specific applications
kubectl apply -f argocd/applications/k8s-ingress-dev.yaml
kubectl apply -f argocd/applications/k8s-storage-dev.yaml
kubectl apply -f argocd/applications/k8s-secrets-store-provider-aws-dev.yaml
```

### Method 3: ArgoCD CLI

```bash
# Create application via CLI
argocd app create platform-ingress-dev \
  --project platform \
  --repo https://gitlab.com/your-org/platform-k8-gitops.git \
  --path k8s-resources/ingress/overlays/dev \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ingress-nginx \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Sync application
argocd app sync platform-ingress-dev

# Get application status
argocd app get platform-ingress-dev
```

## Application Configuration

### Sync Policy

Each application has automated sync enabled:

```yaml
syncPolicy:
  automated:
    prune: true        # Delete resources not in Git
    selfHeal: true     # Automatically sync when drift detected
    allowEmpty: false  # Don't sync if no resources
```

### Sync Options

```yaml
syncOptions:
  - CreateNamespace=true              # Auto-create namespace
  - PrunePropagationPolicy=foreground # Wait for resources to be deleted
  - PruneLast=true                    # Prune resources last
```

### Retry Policy

```yaml
retry:
  limit: 5           # Retry up to 5 times
  backoff:
    duration: 5s     # Initial backoff
    factor: 2        # Exponential backoff
    maxDuration: 3m  # Max backoff duration
```

## Sync Waves

Control deployment order using sync waves:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Deploy first
```

**Recommended order:**
- Wave 0: Namespaces, CRDs
- Wave 1: Infrastructure (storage, secrets)
- Wave 2: Platform services (ingress, monitoring)
- Wave 3: Applications

## Managing Applications

### Via ArgoCD UI

1. **Access UI**: https://localhost:8080 (after port-forward)
2. **View Applications**: See all applications and their status
3. **Sync**: Click "Sync" to manually trigger sync
4. **Diff**: View differences between Git and cluster
5. **Rollback**: Rollback to previous Git commit

### Via ArgoCD CLI

```bash
# List applications
argocd app list

# Get application details
argocd app get platform-ingress-dev

# Sync application
argocd app sync platform-ingress-dev

# View application history
argocd app history platform-ingress-dev

# Rollback to previous version
argocd app rollback platform-ingress-dev <revision>

# Delete application
argocd app delete platform-ingress-dev
```

### Via kubectl

```bash
# List applications
kubectl get applications -n argocd

# Get application status
kubectl get application platform-ingress-dev -n argocd -o yaml

# Delete application
kubectl delete application platform-ingress-dev -n argocd
```

## Monitoring

### Application Health

ArgoCD monitors application health:

- **Healthy**: All resources are healthy
- **Progressing**: Resources are being created/updated
- **Degraded**: Some resources are unhealthy
- **Suspended**: Application is suspended
- **Missing**: Resources are missing
- **Unknown**: Health status unknown

### Sync Status

- **Synced**: Git matches cluster
- **OutOfSync**: Git differs from cluster
- **Unknown**: Sync status unknown

### Check Status

```bash
# Via CLI
argocd app get platform-ingress-dev

# Via kubectl
kubectl get application platform-ingress-dev -n argocd -o jsonpath='{.status.sync.status}'
kubectl get application platform-ingress-dev -n argocd -o jsonpath='{.status.health.status}'
```

## Troubleshooting

### Application Not Syncing

**Check:**
```bash
argocd app get platform-ingress-dev
```

**Common issues:**
- Repository not accessible
- Invalid kustomization
- Resource conflicts
- RBAC permissions

**Solution:**
```bash
# Refresh application
argocd app get platform-ingress-dev --refresh

# Hard refresh (bypass cache)
argocd app get platform-ingress-dev --hard-refresh

# View sync errors
argocd app get platform-ingress-dev -o yaml | grep -A 10 "message:"
```

### Sync Failed

**Check application events:**
```bash
kubectl describe application platform-ingress-dev -n argocd
```

**View sync operation:**
```bash
argocd app get platform-ingress-dev --show-operation
```

**Retry sync:**
```bash
argocd app sync platform-ingress-dev --retry-limit 3
```

### Resource Drift

ArgoCD detects when cluster state differs from Git:

**View diff:**
```bash
argocd app diff platform-ingress-dev
```

**Auto-heal:**
With `selfHeal: true`, ArgoCD automatically corrects drift.

**Manual sync:**
```bash
argocd app sync platform-ingress-dev
```

### Application Stuck

**Force sync:**
```bash
argocd app sync platform-ingress-dev --force
```

**Prune resources:**
```bash
argocd app sync platform-ingress-dev --prune
```

**Replace resources:**
```bash
argocd app sync platform-ingress-dev --replace
```

## Best Practices

### 1. Use App of Apps Pattern

Manage multiple applications with a single Application:
```yaml
# argocd/app-of-apps/platform-dev.yaml
source:
  path: argocd/applications
  directory:
    include: '*-dev.yaml'
```

### 2. Separate Environments

Use different Application manifests for each environment:
- `*-dev.yaml` for development
- `*-prod.yaml` for production

### 3. Enable Auto-Sync with Caution

**Dev**: Enable auto-sync for faster feedback
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Prod**: Consider manual sync for control
```yaml
syncPolicy:
  automated: null  # Disable auto-sync
```

### 4. Use Sync Waves

Control deployment order:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

### 5. Implement Health Checks

Define custom health checks for CRDs:
```yaml
health:
  - group: apps
    kind: Deployment
    check: |
      # Custom health check logic
```

### 6. Use Projects for RBAC

Organize applications into projects:
```yaml
spec:
  project: platform  # Reference AppProject
```

### 7. Monitor Application Status

Set up alerts for:
- Sync failures
- Health degradation
- Out of sync status

## Integration with GitLab CI/CD

ArgoCD complements CI/CD:

**CI/CD Role**: Build, test, update Git
**ArgoCD Role**: Deploy, sync, monitor

### Workflow

```
1. Developer commits code
2. GitLab CI builds and tests
3. GitLab CI updates values files in Git
4. ArgoCD detects change
5. ArgoCD syncs to cluster
6. ArgoCD monitors health
```

### Update from CI/CD

```yaml
# .gitlab-ci.yml
update:image:
  script:
    - |
      # Update image tag in values file
      sed -i "s/tag: .*/tag: ${CI_COMMIT_SHA}/" charts/my-app/values-dev.yaml
      
      # Commit and push
      git add charts/my-app/values-dev.yaml
      git commit -m "Update image to ${CI_COMMIT_SHA}"
      git push origin main
      
      # ArgoCD will automatically sync the change
```

## Security

### Repository Credentials

Store credentials securely:
```bash
# Use SSH key
argocd repo add git@gitlab.com:your-org/platform-k8-gitops.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Use token
argocd repo add https://gitlab.com/your-org/platform-k8-gitops.git \
  --username gitlab-ci-token \
  --password $GITLAB_TOKEN
```

### RBAC

Control access using AppProjects:
```yaml
roles:
  - name: developer
    policies:
      - p, proj:platform:developer, applications, sync, platform/*, allow
    groups:
      - platform-developers
```

### Secrets Management

Don't store secrets in Git:
- Use External Secrets Operator
- Use Sealed Secrets
- Use AWS Secrets Manager

## Migration from GitLab CI/CD

### Phase 1: Parallel Run

1. Keep existing GitLab CI/CD jobs
2. Deploy ArgoCD Applications
3. Verify both methods work

### Phase 2: Gradual Migration

1. Migrate non-critical apps to ArgoCD
2. Monitor and validate
3. Migrate critical apps

### Phase 3: Full GitOps

1. Disable GitLab CI/CD deployment jobs
2. Use GitLab CI/CD only for build/test
3. ArgoCD handles all deployments

## Related Documentation

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [K8s Resources README](../k8s-resources/README.md)
- [GitLab CI/CD Pipeline](../.gitlab-ci.yml)

## Summary

ArgoCD provides:
- ✅ **Declarative GitOps**: Entire system state in Git
- ✅ **Automated Sync**: Continuous deployment from Git
- ✅ **Self-Healing**: Automatic drift correction
- ✅ **Audit Trail**: Full history in Git
- ✅ **Easy Rollback**: Git revert to rollback
- ✅ **Multi-Environment**: Separate apps per environment
- ✅ **RBAC**: Fine-grained access control

Welcome to GitOps! 🚀
