# Kustomize Deployment Guide for External DNS Extended RBAC

## Quick Start

```bash
# 1. Deploy External DNS with Helm
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -n external-dns \
  --create-namespace

# 2. Deploy extended RBAC with Kustomize
kubectl apply -k k8s-resources/external-dns/

# 3. Verify
kubectl get clusterrole external-dns-extended
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns
```

## Why Use Kustomize?

### Advantages

1. **Template-Free**: No complex templating syntax
2. **Declarative**: Pure Kubernetes YAML
3. **Composable**: Layer configurations with overlays
4. **GitOps Ready**: Perfect for ArgoCD, Flux
5. **Built-in**: Available in kubectl 1.14+
6. **Reusable**: Share base configurations

### Use Cases

- **Multi-Environment**: Dev, staging, prod with overlays
- **GitOps**: ArgoCD, Flux integration
- **CI/CD**: Automated deployments
- **Customization**: Environment-specific patches
- **Version Control**: Track configuration changes

## Directory Structure

```
k8s-resources/external-dns/
├── kustomization.yaml              # Base configuration
├── extended-rbac.yaml              # RBAC resources
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml     # Dev overlay
│   └── prod/
│       └── kustomization.yaml     # Prod overlay
├── README.md
└── KUSTOMIZE-DEPLOYMENT-GUIDE.md  # This file
```

## Deployment Methods

### Method 1: Base Configuration

Deploy without environment-specific customizations:

```bash
# Preview
kubectl kustomize k8s-resources/external-dns/

# Deploy
kubectl apply -k k8s-resources/external-dns/

# Verify
kubectl get clusterrole,clusterrolebinding | grep external-dns
```

### Method 2: Development Overlay

Deploy with dev-specific labels and annotations:

```bash
# Preview
kubectl kustomize k8s-resources/external-dns/overlays/dev/

# Deploy
kubectl apply -k k8s-resources/external-dns/overlays/dev/

# Verify
kubectl get clusterrole external-dns-extended -o yaml | grep environment
```

### Method 3: Production Overlay

Deploy with prod-specific configurations:

```bash
# Preview
kubectl kustomize k8s-resources/external-dns/overlays/prod/

# Deploy
kubectl apply -k k8s-resources/external-dns/overlays/prod/

# Verify
kubectl get clusterrole external-dns-extended -o yaml | grep -A 5 labels
```

## Complete Workflow

### Step 1: Deploy External DNS

```bash
# Deploy External DNS with Helm
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -n external-dns \
  --create-namespace \
  --wait

# Verify External DNS is running
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=20
```

### Step 2: Preview RBAC Resources

```bash
# Preview what will be deployed
kubectl kustomize k8s-resources/external-dns/

# Or with overlay
kubectl kustomize k8s-resources/external-dns/overlays/dev/
```

### Step 3: Deploy RBAC

```bash
# Deploy base configuration
kubectl apply -k k8s-resources/external-dns/

# Or with overlay
kubectl apply -k k8s-resources/external-dns/overlays/dev/
```

### Step 4: Verify Deployment

```bash
# Check ClusterRoles
kubectl get clusterrole | grep external-dns
# Expected output:
# external-dns-extended
# external-dns-crd-reader

# Check ClusterRoleBindings
kubectl get clusterrolebinding | grep external-dns
# Expected output:
# external-dns-extended
# external-dns-crd-reader

# Check namespace Role
kubectl get role -n external-dns
# Expected output:
# external-dns-namespace

# Check namespace RoleBinding
kubectl get rolebinding -n external-dns
# Expected output:
# external-dns-namespace
```

### Step 5: Test Permissions

```bash
# Test Gateway API
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns
# Expected: yes

# Test Istio
kubectl auth can-i list virtualservices.networking.istio.io \
  --as=system:serviceaccount:external-dns:external-dns
# Expected: yes

# Test DNSEndpoint
kubectl auth can-i list dnsendpoints.externaldns.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns
# Expected: yes

# Test Events
kubectl auth can-i create events \
  --as=system:serviceaccount:external-dns:external-dns
# Expected: yes
```

## Customization

### Add Custom Labels

Edit `kustomization.yaml`:

```yaml
commonLabels:
  app.kubernetes.io/name: external-dns
  app.kubernetes.io/component: rbac-extended
  app.kubernetes.io/managed-by: kustomize
  team: platform                    # Add custom label
  cost-center: engineering          # Add custom label
```

### Add Custom Annotations

```yaml
commonAnnotations:
  deployed-by: kustomize
  documentation: "https://github.com/kubernetes-sigs/external-dns"
  contact: platform-team@example.com  # Add custom annotation
```

### Change Namespace

```yaml
namespace: my-external-dns-namespace
```

### Add Resource Patches

Create a patch file or inline patch:

```yaml
# In overlays/dev/kustomization.yaml
patches:
  - target:
      kind: ClusterRole
      name: external-dns-extended
    patch: |-
      - op: add
        path: /metadata/annotations/custom-key
        value: custom-value
```

## Environment-Specific Configurations

### Development Environment

**File:** `overlays/dev/kustomization.yaml`

**Features:**
- Labels: `environment=dev`
- Annotations: `environment=development`
- Owner: `platform-team`

**Deploy:**
```bash
kubectl apply -k k8s-resources/external-dns/overlays/dev/
```

### Production Environment

**File:** `overlays/prod/kustomization.yaml`

**Features:**
- Labels: `environment=prod`, `criticality=high`
- Annotations: `environment=production`, `compliance=required`
- Additional security annotations

**Deploy:**
```bash
kubectl apply -k k8s-resources/external-dns/overlays/prod/
```

### Create Staging Environment

```bash
# Create directory
mkdir -p k8s-resources/external-dns/overlays/staging

# Create kustomization
cat > k8s-resources/external-dns/overlays/staging/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../

namespace: external-dns

commonLabels:
  environment: staging
  managed-by: kustomize

commonAnnotations:
  environment: staging
  owner: platform-team
EOF

# Deploy
kubectl apply -k k8s-resources/external-dns/overlays/staging/
```

## GitOps Integration

### ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-dns-rbac-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/platform-k8-gitops
    targetRevision: main
    path: k8s-resources/external-dns/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: external-dns
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false  # Namespace created by Helm
```

### Flux Kustomization

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
  healthChecks:
    - apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      name: external-dns-extended
```

## CI/CD Integration

### GitLab CI

```yaml
deploy-external-dns-rbac:
  stage: deploy
  script:
    # Preview changes
    - kubectl kustomize k8s-resources/external-dns/overlays/${ENVIRONMENT}/
    
    # Deploy
    - kubectl apply -k k8s-resources/external-dns/overlays/${ENVIRONMENT}/
    
    # Verify
    - kubectl get clusterrole external-dns-extended
    - kubectl auth can-i list gateways.gateway.networking.k8s.io --as=system:serviceaccount:external-dns:external-dns
  only:
    - main
  environment:
    name: ${ENVIRONMENT}
```

### GitHub Actions

```yaml
- name: Deploy External DNS RBAC
  run: |
    # Preview
    kubectl kustomize k8s-resources/external-dns/overlays/${{ env.ENVIRONMENT }}/
    
    # Deploy
    kubectl apply -k k8s-resources/external-dns/overlays/${{ env.ENVIRONMENT }}/
    
    # Verify
    kubectl get clusterrole external-dns-extended
```

## Troubleshooting

### Issue: Kustomize Command Not Found

**Solution:**
```bash
# Use kubectl built-in
kubectl apply -k k8s-resources/external-dns/

# Or install standalone
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
```

### Issue: Resources Already Exist

**Solution:**
```bash
# Delete and recreate
kubectl delete -k k8s-resources/external-dns/
kubectl apply -k k8s-resources/external-dns/

# Or use server-side apply
kubectl apply -k k8s-resources/external-dns/ --server-side
```

### Issue: Namespace Not Found

**Solution:**
```bash
# Create namespace
kubectl create namespace external-dns

# Or deploy External DNS first (Helm creates namespace)
helm upgrade --install external-dns ... --create-namespace
```

### Issue: Permission Denied

**Solution:**
```bash
# Check if service account exists
kubectl get sa -n external-dns external-dns

# Check if ClusterRoleBinding references correct SA
kubectl get clusterrolebinding external-dns-extended -o yaml

# Verify namespace in binding
kubectl get clusterrolebinding external-dns-extended -o jsonpath='{.subjects[0].namespace}'
```

## Cleanup

### Remove RBAC Resources

```bash
# Delete base
kubectl delete -k k8s-resources/external-dns/

# Or delete specific overlay
kubectl delete -k k8s-resources/external-dns/overlays/dev/
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

## Best Practices

1. **Always Preview First**
   ```bash
   kubectl kustomize k8s-resources/external-dns/ | less
   ```

2. **Use Overlays for Environments**
   - Keep base generic
   - Environment-specific in overlays

3. **Version Control Everything**
   - Commit kustomization files
   - Track changes in Git

4. **Test in Dev First**
   ```bash
   kubectl apply -k k8s-resources/external-dns/overlays/dev/ --dry-run=client
   ```

5. **Use GitOps**
   - ArgoCD or Flux for automated deployment
   - Declarative configuration

6. **Document Customizations**
   - Comment patches
   - Explain why changes are needed

## Comparison with Other Methods

| Method | Pros | Cons | Best For |
|--------|------|------|----------|
| **Kustomize** | GitOps ready, composable, no templates | Learning curve | Multi-env, GitOps |
| kubectl apply | Simple, direct | No customization | Quick deployments |
| Helm templates | Very flexible | Complex | Full chart integration |

## Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kubectl Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [External DNS](https://github.com/kubernetes-sigs/external-dns)
- [ArgoCD Kustomize](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [Flux Kustomize](https://fluxcd.io/flux/components/kustomize/)

