# Kubernetes Resources

This directory contains Kubernetes manifests organized using Kustomize for various platform components and applications.

## Directory Structure

```
k8s-resources/
├── environments/          # Environment-specific configurations
│   ├── dev/              # Development environment
│   └── prod/             # Production environment
├── external-secrets/     # External Secrets Operator resources
│   ├── base/
│   └── overlays/
├── ingress/              # Ingress resources
│   ├── base/
│   └── overlays/
├── secrets-store-provider-aws/  # AWS Secrets Manager Provider
│   ├── base/
│   └── overlays/
├── storage/              # Storage resources (PVC, StorageClass, etc.)
│   ├── base/
│   └── overlays/
└── patches/              # Deprecated - patches moved to app-specific overlays
```

## Organization Pattern

Each application/component follows this structure:

```
<app-name>/
├── base/
│   ├── kustomization.yaml
│   └── <resource-files>.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── <patches>.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── <patches>.yaml
└── README.md
```

### Base
Contains environment-agnostic resource definitions that are common across all environments.

### Overlays
Contains environment-specific customizations:
- **dev**: Development environment patches (IAM roles, resource limits, replicas, etc.)
- **prod**: Production environment patches (IAM roles, resource limits, replicas, etc.)

## Deployment

### Deploy Entire Environment

```bash
# Deploy all dev resources
kubectl apply -k environments/dev

# Deploy all prod resources
kubectl apply -k environments/prod
```

### Deploy Specific Application

```bash
# Deploy only ingress to dev
kubectl apply -k ingress/overlays/dev

# Deploy only secrets-store-provider-aws to prod
kubectl apply -k secrets-store-provider-aws/overlays/prod
```

### Preview Changes (Dry Run)

```bash
# Preview dev deployment
kubectl apply -k environments/dev --dry-run=client

# Preview specific app
kubectl apply -k ingress/overlays/dev --dry-run=client
```

### Build Manifests Without Applying

```bash
# Build dev manifests
kubectl kustomize environments/dev > dev-manifests.yaml

# Build prod manifests
kubectl kustomize environments/prod > prod-manifests.yaml
```

## Adding New Applications

To add a new application to the k8s-resources structure:

### 1. Create Directory Structure

```bash
mkdir -p k8s-resources/<app-name>/base
mkdir -p k8s-resources/<app-name>/overlays/dev
mkdir -p k8s-resources/<app-name>/overlays/prod
```

### 2. Create Base Resources

**File**: `<app-name>/base/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

namespace: <default-namespace>
```

**File**: `<app-name>/base/<resource>.yaml`
```yaml
# Your Kubernetes resources
```

### 3. Create Overlay Kustomizations

**File**: `<app-name>/overlays/dev/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: <namespace>

resources:
  - ../../base

patches:
  - path: <patch-file>.yaml
    target:
      kind: <Kind>
      name: <name>
```

**File**: `<app-name>/overlays/dev/<patch-file>.yaml`
```yaml
# Environment-specific patches
```

### 4. Add to Environment Kustomization

**File**: `environments/dev/kustomization.yaml`
```yaml
resources:
  - ../../<app-name>/overlays/dev
```

### 5. Create README

**File**: `<app-name>/README.md`
```markdown
# <App Name>

Description of the application and its resources.

## Structure
## Deployment
## Configuration
```

## Best Practices

### 1. Keep Base Generic
- Base resources should work in any environment
- Use placeholders for environment-specific values
- Avoid hardcoding namespaces, resource limits, or IAM roles

### 2. Use Overlays for Customization
- Environment-specific values go in overlays
- Use patches for targeted modifications
- Keep patches minimal and focused

### 3. Namespace Management
- Define namespace in overlay kustomization
- Don't hardcode namespaces in base resources
- Use consistent namespace naming

### 4. IAM Role Annotations
- Add IAM role annotations in overlays
- Use separate patches for ServiceAccount annotations
- Follow naming convention: `EKS-<Service>-Role-{environment}`

### 5. Documentation
- Each app directory should have a README
- Document required configurations
- Include deployment examples

## Environment Kustomizations

The `environments/` directory contains top-level kustomizations that deploy all applications for a specific environment.

### Dev Environment
**File**: `environments/dev/kustomization.yaml`
```yaml
resources:
  - ../../ingress/overlays/dev
  - ../../external-secrets/overlays/dev
  - ../../storage/overlays/dev
  - ../../secrets-store-provider-aws/overlays/dev
```

### Prod Environment
**File**: `environments/prod/kustomization.yaml`
```yaml
resources:
  - ../../ingress/overlays/prod
  - ../../external-secrets/overlays/prod
  - ../../storage/overlays/prod
  - ../../secrets-store-provider-aws/overlays/prod
```

## GitLab CI/CD Integration

The GitLab CI pipeline includes jobs for deploying Kustomize resources:

```yaml
deploy:kustomize:dev:
  script:
    - kubectl apply -k k8s-resources/environments/dev

deploy:kustomize:prod:
  script:
    - kubectl apply -k k8s-resources/environments/prod
```

## Helm vs Kustomize

This repository uses both Helm and Kustomize:

### Use Helm For:
- Third-party charts (ingress-nginx, external-secrets, etc.)
- Complex applications with many configuration options
- Applications that need version management

### Use Kustomize For:
- Custom application manifests
- Environment-specific patches
- Simple resource customizations
- Combining multiple Helm-deployed resources

## Troubleshooting

### Validation Errors

```bash
# Validate kustomization
kubectl kustomize environments/dev

# Check for syntax errors
kubectl apply -k environments/dev --dry-run=server
```

### Resource Conflicts

```bash
# Check what will be applied
kubectl diff -k environments/dev

# Force apply (use with caution)
kubectl apply -k environments/dev --force
```

### Debugging

```bash
# Build and inspect manifests
kubectl kustomize environments/dev > /tmp/manifests.yaml
cat /tmp/manifests.yaml

# Check specific resource
kubectl kustomize environments/dev | grep -A 20 "kind: ServiceAccount"
```

## Related Documentation

- [Kustomize Documentation](https://kustomize.io/)
- [Kubectl Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [GitLab CI/CD Pipeline](../.gitlab-ci.yml)
- [Helm Charts](../charts/)

## Migration Notes

### From Patches Directory
The `patches/` directory is deprecated. Patches have been moved to app-specific overlay directories:

- `patches/aws-provider-sa-dev.yaml` → `secrets-store-provider-aws/overlays/dev/serviceaccount-patch.yaml`
- `patches/aws-provider-sa-prod.yaml` → `secrets-store-provider-aws/overlays/prod/serviceaccount-patch.yaml`

### From Base Directory
App-specific resources in `base/` have been moved to app-specific directories:

- `base/secrets-store-csi-driver-provider-aws.yaml` → `secrets-store-provider-aws/base/`
