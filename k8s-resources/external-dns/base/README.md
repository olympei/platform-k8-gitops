# External DNS Extended RBAC - Base Configuration

## Overview

This directory contains the **base** Kustomize configuration for External DNS extended RBAC permissions. The base layer defines common resources that are shared across all environments.

## Structure

```
base/
├── kustomization.yaml      # Base kustomization configuration
├── extended-rbac.yaml      # RBAC resources (ClusterRole, ClusterRoleBinding, etc.)
└── README.md              # This file
```

## Resources Included

### ClusterRoles
1. **external-dns-extended** - Extended permissions for External DNS
   - Core resources (services, endpoints, pods, nodes)
   - Ingress resources
   - Gateway API resources
   - Istio resources
   - DNSEndpoint CRD
   - Events

2. **external-dns-crd-reader** - CRD reading permissions
   - CustomResourceDefinitions

### ClusterRoleBindings
1. **external-dns-extended** - Binds extended ClusterRole to ServiceAccount
2. **external-dns-crd-reader** - Binds CRD reader ClusterRole to ServiceAccount

### Namespace Resources
1. **Role: external-dns-namespace** - Namespace-scoped permissions
   - ConfigMaps
   - Leases (for leader election)

2. **RoleBinding: external-dns-namespace** - Binds namespace Role to ServiceAccount

## Usage

### Direct Deployment (Not Recommended)
```bash
# Deploy base directly (not recommended - use overlays instead)
kubectl apply -k k8s-resources/external-dns/base/
```

### Recommended: Use Overlays
```bash
# Deploy with dev overlay
kubectl apply -k k8s-resources/external-dns/overlays/dev/

# Deploy with prod overlay
kubectl apply -k k8s-resources/external-dns/overlays/prod/
```

## Customization

The base configuration should contain **only common resources** that are shared across all environments. Environment-specific customizations should be done in overlays:

- **Dev overlay**: `../overlays/dev/`
- **Prod overlay**: `../overlays/prod/`

## Common Labels

All resources in the base include these labels:
```yaml
app.kubernetes.io/name: external-dns
app.kubernetes.io/component: rbac-extended
app.kubernetes.io/managed-by: kustomize
```

## Common Annotations

All resources in the base include these annotations:
```yaml
deployed-by: kustomize
documentation: "https://github.com/kubernetes-sigs/external-dns"
```

## Kustomize Best Practices

### Base Layer Should:
- ✅ Contain common resources
- ✅ Be environment-agnostic
- ✅ Define default configurations
- ✅ Be reusable across overlays

### Base Layer Should NOT:
- ❌ Contain environment-specific values
- ❌ Reference specific namespaces (unless truly common)
- ❌ Include secrets or sensitive data
- ❌ Have environment-specific patches

## Modifying Base Resources

When modifying base resources:

1. **Test locally first**:
   ```bash
   kubectl kustomize k8s-resources/external-dns/base/
   ```

2. **Verify overlays still work**:
   ```bash
   kubectl kustomize k8s-resources/external-dns/overlays/dev/
   kubectl kustomize k8s-resources/external-dns/overlays/prod/
   ```

3. **Deploy to dev first**:
   ```bash
   kubectl apply -k k8s-resources/external-dns/overlays/dev/
   ```

4. **Verify in dev**:
   ```bash
   kubectl get clusterrole,clusterrolebinding | grep external-dns
   ```

5. **Then deploy to prod**:
   ```bash
   kubectl apply -k k8s-resources/external-dns/overlays/prod/
   ```

## Validation

### Validate Kustomize Build
```bash
kubectl kustomize k8s-resources/external-dns/base/
```

### Check for Errors
```bash
kubectl kustomize k8s-resources/external-dns/base/ | kubectl apply --dry-run=client -f -
```

### Lint YAML
```bash
yamllint k8s-resources/external-dns/base/
```

## Related Documentation

- [Parent README](../README.md) - External DNS k8s-resources overview
- [Dev Overlay](../overlays/dev/) - Development environment configuration
- [Prod Overlay](../overlays/prod/) - Production environment configuration
- [Kustomize Deployment Guide](../KUSTOMIZE-DEPLOYMENT-GUIDE.md) - Detailed deployment guide

## Troubleshooting

### Issue: Resources not found

**Cause:** Base path incorrect in overlay

**Solution:**
```yaml
# In overlay kustomization.yaml
resources:
  - ../../base  # Correct path
```

### Issue: Duplicate resources

**Cause:** Base resources also defined in overlay

**Solution:** Remove duplicate resources from overlay, use patches instead

### Issue: Namespace conflicts

**Cause:** Namespace defined in both base and overlay

**Solution:** Define namespace only in overlays, not in base

## Examples

### Adding a New Permission to Base

```yaml
# In base/extended-rbac.yaml
rules:
  # Add new permission
  - apiGroups: [example.com]
    resources: [customresources]
    verbs: [get, list, watch]
```

### Testing Base Changes

```bash
# 1. Build base
kubectl kustomize k8s-resources/external-dns/base/

# 2. Build dev overlay
kubectl kustomize k8s-resources/external-dns/overlays/dev/

# 3. Dry-run apply
kubectl apply -k k8s-resources/external-dns/overlays/dev/ --dry-run=client

# 4. Apply to dev
kubectl apply -k k8s-resources/external-dns/overlays/dev/
```

## Version History

- **v1.0** - Initial base configuration with extended RBAC
  - ClusterRole: external-dns-extended
  - ClusterRole: external-dns-crd-reader
  - Role: external-dns-namespace
  - Corresponding bindings

## Contributing

When contributing to the base configuration:

1. Ensure changes are environment-agnostic
2. Test with all overlays
3. Update this README if structure changes
4. Document any new resources added
5. Follow Kustomize best practices
