# External DNS Extended RBAC - Kustomize Deployment

## Overview

This directory contains Kustomize configurations for deploying Extended RBAC permissions for External DNS. Kustomize provides a template-free way to customize Kubernetes configurations.

## Directory Structure

```
k8s-resources/external-dns/
├── base/                        # Base Kustomize configuration
│   ├── kustomization.yaml      # Base kustomization
│   ├── extended-rbac.yaml      # RBAC resources
│   └── README.md               # Base documentation
├── overlays/                    # Environment-specific overlays
│   ├── dev/
│   │   └── kustomization.yaml  # Dev environment overlay
│   └── prod/
│       └── kustomization.yaml  # Prod environment overlay
├── README.md                    # This file
└── KUSTOMIZE-DEPLOYMENT-GUIDE.md # Detailed deployment guide
```

### Kustomize Structure

Following Kustomize best practices:
- **base/** - Contains common resources shared across all environments
- **overlays/** - Contains environment-specific configurations that extend/modify the base

## Quick Start

### Deploy with Environment Overlay (Recommended)

```bash
# Development
kubectl apply -k k8s-resources/external-dns/overlays/dev/

# Production
kubectl apply -k k8s-resources/external-dns/overlays/prod/
```

### Deploy Base Configuration Directly (Not Recommended)

```bash
# Preview what will be deployed
kubectl kustomize k8s-resources/external-dns/base/

# Deploy to cluster (use overlays instead)
kubectl apply -k k8s-resources/external-dns/base/
```

## What Gets Deployed

The kustomization deploys the following resources:

1. **ClusterRole: external-dns-extended**
   - Extended permissions for Gateway API, Istio, etc.

2. **ClusterRoleBinding: external-dns-extended**
   - Binds extended role to External DNS service account

3. **ClusterRole: external-dns-crd-reader**
   - Permissions to read CRD definitions

4. **ClusterRoleBinding: external-dns-crd-reader**
   - Binds CRD reader role to service account

5. **Role: external-dns-namespace**
   - Namespace-scoped permissions (ConfigMaps, Leases)

6. **RoleBinding: external-dns-namespace**
   - Binds namespace role to service account

## Prerequisites

1. **Kustomize installed** (or use kubectl 1.14+)
   ```bash
   # Check if available
   kubectl kustomize --help
   
   # Or install standalone
   curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
   ```

2. **External DNS deployed** with Helm
   ```bash
   helm upgrade --install external-dns \
     ./charts/external-dns/charts/external-dns-1.19.0.tgz \
     -f charts/external-dns/values-dev-direct.yaml \
     -n external-dns \
     --create-namespace
   ```

3. **Namespace exists**
   ```bash
   kubectl get namespace external-dns
   ```

## Usage

### Preview Changes

Before applying, preview what will be deployed:

```bash
# Base configuration
kubectl kustomize k8s-resources/external-dns/

# Dev overlay
kubectl kustomize k8s-resources/external-dns/overlays/dev/

# Prod overlay
kubectl kustomize k8s-resources/external-dns/overlays/prod/
```

### Deploy

```bash
# Base configuration
kubectl apply -k k8s-resources/external-dns/

# With environment overlay
kubectl apply -k k8s-resources/external-dns/overlays/dev/
kubectl apply -k k8s-resources/external-dns/overlays/prod/
```

### Verify Deployment

```bash
# Check ClusterRoles
kubectl get clusterrole | grep external-dns

# Check ClusterRoleBindings
kubectl get clusterrolebinding | grep external-dns

# Check namespace Role
kubectl get role -n external-dns external-dns-namespace

# Check namespace RoleBinding
kubectl get rolebinding -n external-dns external-dns-namespace

# Verify labels
kubectl get clusterrole external-dns-extended -o yaml | grep -A 5 labels
```

### Test Permissions

```bash
# Test Gateway API permissions
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

# Test Istio permissions
kubectl auth can-i list virtualservices.networking.istio.io \
  --as=system:serviceaccount:external-dns:external-dns

# Test DNSEndpoint permissions
kubectl auth can-i list dnsendpoints.externaldns.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns
```

## Customization

### Modify Base Configuration

Edit `kustomization.yaml` to customize:

```yaml
# Change namespace
namespace: my-external-dns-namespace

# Add more labels
commonLabels:
  team: platform
  cost-center: engineering

# Add more annotations
commonAnnotations:
  contact: platform-team@example.com
```

### Create Custom Overlay

```bash
# Create new overlay directory
mkdir -p k8s-resources/external-dns/overlays/staging

# Create kustomization
cat > k8s-resources/external-dns/overlays/staging/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../

namespace: external-dns

commonLabels:
  environment: staging

commonAnnotations:
  environment: staging
EOF

# Deploy
kubectl apply -k k8s-resources/external-dns/overlays/staging/
```

### Add Patches

Modify resources with patches:

```yaml
# In overlays/dev/kustomization.yaml
patches:
  # Add annotation to ClusterRole
  - target:
      kind: ClusterRole
      name: external-dns-extended
    patch: |-
      - op: add
        path: /metadata/annotations/custom-annotation
        value: custom-value
  
  # Modify rules (advanced)
  - target:
      kind: ClusterRole
      name: external-dns-extended
    patch: |-
      - op: add
        path: /rules/-
        value:
          apiGroups: ["custom.example.com"]
          resources: ["customresources"]
          verbs: ["get", "list", "watch"]
```

## Environment Overlays

### Development Overlay

**Features:**
- Namespace: `external-dns`
- Labels: `environment=dev`
- Annotations: `environment=development`

**Deploy:**
```bash
kubectl apply -k k8s-resources/external-dns/overlays/dev/
```

### Production Overlay

**Features:**
- Namespace: `external-dns`
- Labels: `environment=prod`, `criticality=high`
- Annotations: `environment=production`, `compliance=required`

**Deploy:**
```bash
kubectl apply -k k8s-resources/external-dns/overlays/prod/
```

## Integration with GitOps

### ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-dns-rbac
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: main
    path: k8s-resources/external-dns/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: external-dns
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Flux

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: external-dns-rbac
  namespace: flux-system
spec:
  interval: 10m
  path: ./k8s-resources/external-dns/overlays/prod
  prune: true
  sourceRef:
    kind: GitRepository
    name: platform-repo
  targetNamespace: external-dns
```

## Troubleshooting

### Kustomize Not Found

```bash
# Use kubectl built-in kustomize
kubectl apply -k k8s-resources/external-dns/

# Or install standalone
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

### Namespace Not Found

```bash
# Create namespace first
kubectl create namespace external-dns

# Or let Helm create it
helm upgrade --install external-dns ... --create-namespace
```

### Permission Denied

```bash
# Check if ClusterRole was created
kubectl get clusterrole external-dns-extended

# Check if binding exists
kubectl get clusterrolebinding external-dns-extended

# Verify service account
kubectl get sa -n external-dns external-dns
```

### Resources Already Exist

```bash
# Delete existing resources
kubectl delete -k k8s-resources/external-dns/

# Or force apply
kubectl apply -k k8s-resources/external-dns/ --force
```

## Cleanup

### Remove RBAC Resources

```bash
# Delete base configuration
kubectl delete -k k8s-resources/external-dns/

# Delete specific overlay
kubectl delete -k k8s-resources/external-dns/overlays/dev/
kubectl delete -k k8s-resources/external-dns/overlays/prod/
```

### Verify Cleanup

```bash
# Check ClusterRoles removed
kubectl get clusterrole | grep external-dns

# Check ClusterRoleBindings removed
kubectl get clusterrolebinding | grep external-dns

# Check namespace resources removed
kubectl get role,rolebinding -n external-dns | grep external-dns
```

## Comparison with Other Methods

| Method | Complexity | Flexibility | GitOps Ready | Recommended For |
|--------|-----------|-------------|--------------|-----------------|
| **Kustomize** | Low | High | ✅ Yes | GitOps, CI/CD |
| kubectl apply | Very Low | Low | ✅ Yes | Quick deployments |
| Helm templates | Medium | Very High | ✅ Yes | Complex charts |
| Static YAML | Very Low | None | ✅ Yes | Simple setups |

## Best Practices

1. **Use Overlays for Environments**
   - Keep base configuration generic
   - Use overlays for environment-specific changes
   - Don't duplicate resources

2. **Version Control**
   - Commit kustomization files to Git
   - Use GitOps for deployment
   - Track changes over time

3. **Test Before Applying**
   - Always preview with `kubectl kustomize`
   - Test in dev before prod
   - Use dry-run: `kubectl apply -k ... --dry-run=client`

4. **Document Customizations**
   - Comment your patches
   - Explain why changes are needed
   - Include in README

5. **Keep It Simple**
   - Don't over-complicate patches
   - Use strategic merge when possible
   - Avoid complex JSON patches

## Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kubectl Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [Kustomize GitHub](https://github.com/kubernetes-sigs/kustomize)
- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns)

## Support

For issues or questions:
1. Check kustomize build output: `kubectl kustomize k8s-resources/external-dns/`
2. Verify resources exist: `kubectl get -k k8s-resources/external-dns/`
3. Check External DNS logs: `kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns`

