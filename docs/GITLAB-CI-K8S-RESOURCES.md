# GitLab CI/CD - K8s-Resources Deployment Guide

## Overview

The GitLab CI/CD pipeline supports deploying Kubernetes resources from the `k8s-resources/` directory using Kustomize. Resources are organized by application with environment-specific overlays.

## K8s-Resources Structure

```
k8s-resources/
├── environments/          # Environment-level kustomizations
│   ├── dev/              # All apps for dev
│   └── prod/             # All apps for prod
├── ingress/              # Ingress resources
│   └── overlays/
│       ├── dev/
│       └── prod/
├── external-secrets/     # External Secrets resources
│   └── overlays/
│       ├── dev/
│       └── prod/
├── storage/              # Storage resources (PVC, StorageClass)
│   └── overlays/
│       ├── dev/
│       └── prod/
└── secrets-store-provider-aws/  # AWS Secrets Manager Provider
    └── overlays/
        ├── dev/
        └── prod/
```

## Deployment Jobs

### Deploy All K8s Resources (Environment-Level)

Deploy all applications for an environment using environment kustomization:

**Jobs:**
- `deploy:kustomize:dev` - Deploy all k8s resources to dev
- `deploy:kustomize:prod` - Deploy all k8s resources to prod

**What it does:**
```bash
kubectl apply -k k8s-resources/environments/dev
```

**Deploys:**
- Ingress resources
- External Secrets resources
- Storage resources
- AWS Secrets Manager Provider

### Deploy Multiple Apps Dynamically

Deploy specific apps or all apps dynamically:

**Jobs:**
- `deploy:k8s:apps:dev` - Deploy apps to dev (controlled by K8S_APPS variable)
- `deploy:k8s:apps:prod` - Deploy apps to prod (controlled by K8S_APPS variable)

**Configuration via K8S_APPS Variable:**

Set `K8S_APPS` in GitLab CI/CD variables:

| K8S_APPS Value | Behavior |
|----------------|----------|
| `"ingress,storage"` | Deploy only ingress and storage |
| `"secrets-store-provider-aws"` | Deploy only AWS provider |
| `""` (empty) or unset | Auto-detect and deploy all apps |

**Examples:**

```yaml
# In GitLab CI/CD Variables:
K8S_APPS: "ingress,storage,secrets-store-provider-aws"

# Or leave empty to deploy all apps
K8S_APPS: ""
```

**What it does:**
```bash
# If K8S_APPS="ingress,storage"
kubectl apply -k k8s-resources/ingress/overlays/dev
kubectl apply -k k8s-resources/storage/overlays/dev

# If K8S_APPS is empty, auto-detects all apps
kubectl apply -k k8s-resources/ingress/overlays/dev
kubectl apply -k k8s-resources/external-secrets/overlays/dev
kubectl apply -k k8s-resources/storage/overlays/dev
kubectl apply -k k8s-resources/secrets-store-provider-aws/overlays/dev
```

### Deploy Individual Apps

Deploy a specific application to an environment:

#### Dev Environment Jobs:
- `deploy:k8s:ingress:dev` - Deploy ingress resources to dev
- `deploy:k8s:external-secrets:dev` - Deploy external-secrets resources to dev
- `deploy:k8s:storage:dev` - Deploy storage resources to dev
- `deploy:k8s:secrets-store-provider-aws:dev` - Deploy AWS provider to dev

#### Prod Environment Jobs:
- `deploy:k8s:ingress:prod` - Deploy ingress resources to prod
- `deploy:k8s:external-secrets:prod` - Deploy external-secrets resources to prod
- `deploy:k8s:storage:prod` - Deploy storage resources to prod
- `deploy:k8s:secrets-store-provider-aws:prod` - Deploy AWS provider to prod

**What it does:**
```bash
kubectl apply -k k8s-resources/<app-name>/overlays/<environment>
```

## Job Template

The `.deploy_k8s_app` template handles individual app deployments:

```yaml
.deploy_k8s_app:
  stage: deploy
  script:
    - kubectl kustomize k8s-resources/${APP_NAME}/overlays/${ENVIRONMENT}
    - kubectl apply -k k8s-resources/${APP_NAME}/overlays/${ENVIRONMENT}
  only: [main]
  when: manual
```

## Usage Examples

### Scenario 1: Deploy Everything to Dev

1. Run job: `deploy:helm:dev` (deploy Helm charts)
2. Run job: `deploy:kustomize:dev` (deploy k8s resources)
3. Run job: `verify:dev` (verify deployment)

### Scenario 2: Deploy Only Ingress to Prod

1. Run job: `deploy:k8s:ingress:prod`

This deploys only the ingress resources without affecting other apps.

### Scenario 3: Update AWS Provider in Dev

1. Update files in `k8s-resources/secrets-store-provider-aws/overlays/dev/`
2. Commit and push
3. Run job: `deploy:k8s:secrets-store-provider-aws:dev`

### Scenario 4: Deploy Multiple Specific Apps

1. Set CI/CD variable: `K8S_APPS="ingress,storage"`
2. Run job: `deploy:k8s:apps:dev`

This deploys only ingress and storage, skipping other apps.

### Scenario 5: Deploy All Apps Dynamically

1. Leave `K8S_APPS` unset or set to empty string
2. Run job: `deploy:k8s:apps:dev`

This auto-detects and deploys all available apps.

### Scenario 6: Deploy New App

1. Create app structure:
   ```
   k8s-resources/my-app/
   ├── base/
   │   ├── kustomization.yaml
   │   └── resources.yaml
   └── overlays/
       ├── dev/
       │   ├── kustomization.yaml
       │   └── patches.yaml
       └── prod/
           ├── kustomization.yaml
           └── patches.yaml
   ```

2. Add to environment kustomization:
   ```yaml
   # k8s-resources/environments/dev/kustomization.yaml
   resources:
     - ../../my-app/overlays/dev
   ```

3. Add CI/CD job:
   ```yaml
   deploy:k8s:my-app:dev:
     extends: .deploy_k8s_app
     variables:
       ENVIRONMENT: dev
       APP_NAME: my-app
       KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
   ```

4. Run job: `deploy:k8s:my-app:dev`

## Job Output

Each deployment job provides:

1. **Preview**: Shows resources that will be applied
   ```
   🔍 Previewing resources to be applied...
   apiVersion: v1
   kind: ServiceAccount
   ...
   ```

2. **Application**: Applies the resources
   ```
   🚀 Applying resources...
   serviceaccount/my-sa created
   deployment.apps/my-app created
   ```

3. **Status**: Shows deployed resources
   ```
   📊 Resource Status:
   Namespace: my-namespace
   NAME                     READY   STATUS    RESTARTS   AGE
   pod/my-app-abc123        1/1     Running   0          10s
   ```

## Prerequisites

### Required CI/CD Variables

Set these in GitLab: **Settings → CI/CD → Variables**

| Variable | Description | Example |
|----------|-------------|---------|
| `DEV_KUBECONFIG_B64` | Base64 encoded kubeconfig for dev cluster | `<base64-string>` |
| `PROD_KUBECONFIG_B64` | Base64 encoded kubeconfig for prod cluster | `<base64-string>` |
| `AWS_ACCOUNT_ID` | AWS account ID (optional, for IAM roles) | `123456789012` |

### Encoding Kubeconfig

```bash
# Encode kubeconfig
cat ~/.kube/config | base64 -w 0

# Or on macOS
cat ~/.kube/config | base64
```

## Deployment Order

Recommended deployment order:

1. **Helm Charts** (infrastructure components)
   - `deploy:helm:dev` or `deploy:helm:prod`

2. **K8s Resources** (application resources)
   - `deploy:kustomize:dev` or `deploy:kustomize:prod`
   - Or individual apps: `deploy:k8s:<app>:dev`

3. **Verification**
   - `verify:dev` or `verify:prod`

## Error Handling

### App Not Found

```
❌ ERROR: App path not found: k8s-resources/my-app/overlays/dev
Available apps:
k8s-resources/ingress/overlays/dev
k8s-resources/external-secrets/overlays/dev
...
```

**Solution**: Check app name and ensure overlay exists for the environment.

### Kustomize Build Error

```
Error: accumulating resources: accumulation err='accumulating resources from '../../base': ...
```

**Solution**: Validate kustomization locally:
```bash
kubectl kustomize k8s-resources/<app>/overlays/dev
```

### Apply Error

```
Error from server (NotFound): error when creating "...": namespaces "my-namespace" not found
```

**Solution**: Ensure namespace is created or add to kustomization:
```yaml
namespace: my-namespace
```

## Best Practices

### 1. Test Locally First

```bash
# Preview changes
kubectl kustomize k8s-resources/<app>/overlays/dev

# Dry run
kubectl apply -k k8s-resources/<app>/overlays/dev --dry-run=client

# Apply
kubectl apply -k k8s-resources/<app>/overlays/dev
```

### 2. Use Specific App Jobs

Deploy individual apps instead of all resources when:
- Testing changes to a single app
- Updating configuration for one component
- Troubleshooting a specific app

### 3. Deploy to Dev First

Always deploy to dev before prod:
```
deploy:k8s:<app>:dev → verify → deploy:k8s:<app>:prod
```

### 4. Review Job Output

Check the job output for:
- Resources being created/updated
- Any warnings or errors
- Final status of deployed resources

### 5. Use Manual Triggers

All deployment jobs require manual trigger for safety:
- Review changes before deploying
- Control deployment timing
- Prevent accidental deployments

## Verification

After deployment, verify resources:

```bash
# Check all resources in namespace
kubectl get all -n <namespace>

# Check specific resources
kubectl get deployment,service,ingress -n <namespace>

# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

Or use the verify job:
```
verify:dev  # or verify:prod
```

## Troubleshooting

### Job Fails with "command not found"

Ensure `kubectl` is available in the CI/CD environment. The pipeline uses `alpine:3.20` with kubectl installed.

### Permission Denied

Check that the kubeconfig has proper permissions for the cluster.

### Resources Not Updating

Force apply:
```bash
kubectl apply -k k8s-resources/<app>/overlays/dev --force
```

Or delete and recreate:
```bash
kubectl delete -k k8s-resources/<app>/overlays/dev
kubectl apply -k k8s-resources/<app>/overlays/dev
```

## Related Documentation

- [K8s-Resources README](../k8s-resources/README.md)
- [K8s-Resources Restructure Summary](../K8S-RESOURCES-RESTRUCTURE-SUMMARY.md)
- [GitLab CI/CD Pipeline](../.gitlab-ci.yml)
- [Kustomize Documentation](https://kustomize.io/)

## Adding New Apps to CI/CD

To add a new app to the pipeline:

1. **Create app structure** in `k8s-resources/`
2. **Add to environment kustomization**
3. **Add CI/CD jobs**:

```yaml
deploy:k8s:my-app:dev:
  extends: .deploy_k8s_app
  variables:
    ENVIRONMENT: dev
    APP_NAME: my-app
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64

deploy:k8s:my-app:prod:
  extends: .deploy_k8s_app
  variables:
    ENVIRONMENT: prod
    APP_NAME: my-app
    KUBECONFIG_DATA: $PROD_KUBECONFIG_B64
```

4. **Commit and push**
5. **Run the new job** in GitLab

## Summary

The GitLab CI/CD pipeline provides flexible deployment options:

- ✅ **Deploy all resources**: `deploy:kustomize:dev|prod`
- ✅ **Deploy specific app**: `deploy:k8s:<app>:dev|prod`
- ✅ **Preview before apply**: Job shows resources to be deployed
- ✅ **Manual triggers**: All jobs require manual approval
- ✅ **Status reporting**: Shows deployed resources after apply

Choose the deployment method that fits your needs!
