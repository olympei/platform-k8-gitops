# Extended RBAC Deployment - Quick Reference

## TL;DR - Recommended Approach

```bash
# 1. Deploy External DNS with Helm
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -n external-dns \
  --create-namespace

# 2. Apply extended RBAC
kubectl apply -f charts/external-dns/k8s-resources/extended-rbac.yaml

# 3. Verify
kubectl get clusterrole external-dns-extended
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns
```

## Why Can't We Use `-f charts/external-dns/templates/`?

**Short Answer:** The `-f` flag is for **values files** (configuration), not template files.

**Explanation:**
- `-f` expects YAML files with configuration values
- Templates (`.yaml` files in `templates/`) are **Helm templates** that need to be rendered
- Templates use Go templating syntax (`{{ }}`) and need a chart context
- Packaged charts (`.tgz`) don't see external template directories

## Available Options

### Option 1: Standalone RBAC File (Simplest) ✅

**When to use:** You're using the packaged chart and want simple RBAC extension

**File:** `k8s-resources/extended-rbac.yaml`

**Pros:**
- Simple `kubectl apply`
- No Helm complexity
- Works with any chart deployment method
- Easy to version control

**Cons:**
- Not integrated with Helm lifecycle
- Manual application required
- No templating/customization

**Usage:**
```bash
kubectl apply -f charts/external-dns/k8s-resources/extended-rbac.yaml
```

### Option 2: Wrapper Chart with Templates

**When to use:** You want full Helm integration and templating

**Files:** `Chart.yaml`, `values-wrapper.yaml`, `templates/`

**Pros:**
- Full Helm lifecycle management
- Templating and customization
- Single deployment command
- Integrated with Helm hooks

**Cons:**
- More complex setup
- Requires dependency build
- Larger chart structure

**Usage:**
```bash
cd charts/external-dns
helm dependency build
helm upgrade --install external-dns . -f values-wrapper.yaml -n external-dns --create-namespace
```

### Option 3: Static YAML (Legacy)

**When to use:** Backward compatibility or manual control

**File:** `custom-clusterrole.yaml`

**Usage:**
```bash
kubectl apply -f charts/external-dns/custom-clusterrole.yaml
```

## File Structure

```
charts/external-dns/
├── charts/
│   └── external-dns-1.19.0.tgz          # Packaged chart
├── templates/                            # Helm templates (for wrapper chart)
│   ├── _helpers.tpl
│   ├── extended-clusterrole.yaml
│   ├── crd-reader-clusterrole.yaml
│   └── namespace-role.yaml
├── k8s-resources/                        # Standalone Kubernetes resources
│   └── extended-rbac.yaml               # ✅ Use this with packaged chart
├── Chart.yaml                            # Wrapper chart definition
├── values-wrapper.yaml                   # Wrapper chart values
├── values-dev-direct.yaml                # Direct chart values
├── custom-clusterrole.yaml               # Legacy static YAML
└── DEPLOYMENT-COMMANDS.md                # This guide

```

## Comparison

| Method | Complexity | Flexibility | Helm Integration | Recommended |
|--------|-----------|-------------|------------------|-------------|
| **Standalone RBAC** | Low | Low | No | ✅ Yes |
| **Wrapper Chart** | Medium | High | Yes | For advanced users |
| **Static YAML** | Low | None | No | Legacy only |

## Common Questions

### Q: Why not just use `-f templates/extended-clusterrole.yaml`?

**A:** Because:
1. Templates contain Go template syntax (`{{ .Values.rbac.extended.enabled }}`)
2. They need to be rendered by Helm with a chart context
3. The `-f` flag expects plain YAML values, not templates
4. Packaged charts don't process external templates

### Q: What's the difference between templates/ and k8s-resources/?

**A:**
- **`templates/`**: Helm templates with Go templating, need rendering
- **`k8s-resources/`**: Plain Kubernetes YAML, ready to apply

### Q: Can I customize the standalone RBAC file?

**A:** Yes, edit `k8s-resources/extended-rbac.yaml` directly:
```yaml
# Remove resources you don't need
# - apiGroups: [networking.istio.io]
#   resources: [gateways, virtualservices]
#   verbs: [get, list, watch]
```

### Q: How do I use the wrapper chart?

**A:**
```bash
# 1. Build dependencies
cd charts/external-dns
helm dependency build

# 2. Deploy
helm upgrade --install external-dns . \
  -f values-wrapper.yaml \
  -n external-dns \
  --create-namespace
```

### Q: Which method should I use?

**A:** For most users: **Option 1 (Standalone RBAC)**
- Simple
- Works with packaged chart
- Easy to understand and maintain

Use wrapper chart only if you need:
- Dynamic configuration via values
- Helm lifecycle integration
- Complex templating logic

## Quick Commands

### Deploy with Standalone RBAC
```bash
# Deploy chart
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -n external-dns --create-namespace

# Apply RBAC
kubectl apply -f charts/external-dns/k8s-resources/extended-rbac.yaml
```

### Deploy with Wrapper Chart
```bash
cd charts/external-dns
helm dependency build
helm upgrade --install external-dns . \
  -f values-wrapper.yaml \
  -n external-dns --create-namespace
```

### Verify RBAC
```bash
# Check ClusterRoles
kubectl get clusterrole | grep external-dns

# Test permissions
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

kubectl auth can-i list virtualservices.networking.istio.io \
  --as=system:serviceaccount:external-dns:external-dns
```

### Remove RBAC
```bash
# Standalone RBAC
kubectl delete -f charts/external-dns/k8s-resources/extended-rbac.yaml

# Or manually
kubectl delete clusterrole external-dns-extended external-dns-crd-reader
kubectl delete clusterrolebinding external-dns-extended external-dns-crd-reader
kubectl delete role external-dns-namespace -n external-dns
kubectl delete rolebinding external-dns-namespace -n external-dns
```

## Summary

**Recommended for most users:**
1. Deploy External DNS with packaged chart
2. Apply standalone RBAC file with `kubectl apply`
3. Simple, clear, and maintainable

**For advanced users:**
- Use wrapper chart for full Helm integration
- Customize via values files
- Leverage Helm templating

