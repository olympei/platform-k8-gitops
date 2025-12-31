# External DNS Templates Usage Guide

## Overview

The External DNS chart now includes Helm templates for extended RBAC permissions in the `templates/` directory. These templates provide additional permissions beyond the default chart for watching Gateway API, Istio, and other ingress controllers.

## Templates Structure

```
charts/external-dns/
├── templates/
│   ├── _helpers.tpl                    # Helper functions
│   ├── extended-clusterrole.yaml       # Extended ClusterRole and binding
│   ├── crd-reader-clusterrole.yaml     # CRD reader role and binding
│   └── namespace-role.yaml             # Namespace-scoped role and binding
├── values-extended-rbac.yaml           # Extended RBAC configuration
├── values-dev-direct.yaml              # Dev values (includes RBAC config)
└── values-prod-direct.yaml             # Prod values (includes RBAC config)
```

## Quick Start

### Method 1: Using Packaged Chart with Templates

```bash
# Deploy with extended RBAC enabled (already in values-dev-direct.yaml)
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -f charts/external-dns/templates/extended-clusterrole.yaml \
  -f charts/external-dns/templates/crd-reader-clusterrole.yaml \
  -f charts/external-dns/templates/namespace-role.yaml \
  -n external-dns \
  --create-namespace
```

### Method 2: Apply Templates Separately

```bash
# 1. Deploy External DNS with Helm
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -n external-dns \
  --create-namespace

# 2. Apply templates manually (with values substitution)
helm template external-dns \
  ./charts/external-dns \
  -f charts/external-dns/values-dev-direct.yaml \
  -s templates/extended-clusterrole.yaml \
  -s templates/crd-reader-clusterrole.yaml \
  -s templates/namespace-role.yaml \
  | kubectl apply -f -
```

### Method 3: Using values-extended-rbac.yaml

```bash
# Deploy with extended RBAC configuration
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -f charts/external-dns/values-extended-rbac.yaml \
  -n external-dns \
  --create-namespace
```

## Configuration

### Enable/Disable Extended RBAC

In your values file:

```yaml
rbac:
  extended:
    enabled: true  # Set to false to disable
```

### Configure Resource Types

Enable only the resource types you need:

```yaml
rbac:
  extended:
    enabled: true
    rules:
      core: { enabled: true }
      ingress: { enabled: true }
      gatewayAPI: { enabled: true }    # Gateway API
      istio: { enabled: true }         # Istio
      contour: { enabled: false }      # Contour (disabled)
      traefik: { enabled: false }      # Traefik (disabled)
      # ... etc
```

### Add Custom Rules

```yaml
rbac:
  extended:
    enabled: true
    additionalRules:
      - apiGroups: ["your-api.example.com"]
        resources: ["yourcustomresources"]
        verbs: ["get", "list", "watch"]
```

### Namespace Role Configuration

```yaml
rbac:
  namespaceRole:
    enabled: true
    rules:
      configmaps: { enabled: true }
      secrets: { enabled: false }      # Not needed with IRSA
      leases: { enabled: true }        # For leader election
```

## Deployment Scenarios

### Scenario 1: Gateway API Only

```yaml
# values-gateway-api.yaml
rbac:
  extended:
    enabled: true
    rules:
      core: { enabled: true }
      ingress: { enabled: true }
      gatewayAPI: { enabled: true }
      istio: { enabled: false }
      dnsendpoint: { enabled: true }
      events: { enabled: true }
      # Disable all other ingress controllers
      contour: { enabled: false }
      ambassador: { enabled: false }
      traefik: { enabled: false }
      f5: { enabled: false }
      openshift: { enabled: false }
      kong: { enabled: false }
      gloo: { enabled: false }
      skipper: { enabled: false }
```

Deploy:
```bash
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -f values-gateway-api.yaml \
  -n external-dns \
  --create-namespace
```

### Scenario 2: Istio Service Mesh

```yaml
# values-istio.yaml
rbac:
  extended:
    enabled: true
    rules:
      core: { enabled: true }
      ingress: { enabled: true }
      gatewayAPI: { enabled: true }
      istio: { enabled: true }          # Enable Istio
      dnsendpoint: { enabled: true }
      events: { enabled: true }
```

### Scenario 3: Multi-Ingress Controllers

```yaml
# values-multi-ingress.yaml
rbac:
  extended:
    enabled: true
    rules:
      core: { enabled: true }
      ingress: { enabled: true }
      gatewayAPI: { enabled: true }
      istio: { enabled: true }
      contour: { enabled: true }
      traefik: { enabled: true }
      ambassador: { enabled: true }
      dnsendpoint: { enabled: true }
      events: { enabled: true }
```

### Scenario 4: Minimal Permissions

```yaml
# values-minimal.yaml
rbac:
  extended:
    enabled: false  # Disable extended RBAC
  crdReader:
    enabled: false
  namespaceRole:
    enabled: false
```

## Verification

### Check Templates Rendered

```bash
# Render templates to see what will be created
helm template external-dns \
  ./charts/external-dns \
  -f charts/external-dns/values-dev-direct.yaml \
  -s templates/extended-clusterrole.yaml
```

### Verify ClusterRole Created

```bash
# Check ClusterRole
kubectl get clusterrole | grep external-dns

# View extended ClusterRole
kubectl get clusterrole external-dns-extended -o yaml

# Check ClusterRoleBinding
kubectl get clusterrolebinding external-dns-extended -o yaml
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

## Template Variables

### Available Variables

The templates use these values from your values file:

```yaml
# Chart metadata
.Chart.Name                    # Chart name
.Chart.Version                 # Chart version
.Chart.AppVersion              # App version

# Release information
.Release.Name                  # Release name
.Release.Namespace             # Release namespace
.Release.Service               # Helm service

# Values
.Values.rbac.extended.enabled  # Enable extended RBAC
.Values.rbac.extended.rules    # Rule configuration
.Values.serviceAccount.name    # Service account name
```

### Helper Functions

```yaml
{{- include "external-dns.fullname" . }}        # Full name
{{- include "external-dns.name" . }}            # Short name
{{- include "external-dns.labels" . }}          # Common labels
{{- include "external-dns.serviceAccountName" . }}  # SA name
```

## Customization

### Override Resource Names

```yaml
# values.yaml
nameOverride: "my-external-dns"
fullnameOverride: "custom-external-dns"
```

This will create:
- ClusterRole: `custom-external-dns-extended`
- ClusterRoleBinding: `custom-external-dns-extended`

### Add Custom Annotations

```yaml
rbac:
  extended:
    annotations:
      description: "Custom description"
      owner: "platform-team"
      managed-by: "terraform"
```

### Modify Service Account

```yaml
serviceAccount:
  create: true
  name: custom-sa-name
```

## Troubleshooting

### Templates Not Applied

**Issue:** Extended RBAC not created

**Solution:**
```bash
# Check if enabled in values
helm get values external-dns -n external-dns | grep -A 5 "rbac:"

# Verify templates exist
ls -la charts/external-dns/templates/

# Re-render templates
helm template external-dns ./charts/external-dns \
  -f charts/external-dns/values-dev-direct.yaml
```

### Permission Denied

**Issue:** External DNS can't watch resources

**Solution:**
```bash
# Check ClusterRole rules
kubectl get clusterrole external-dns-extended -o yaml

# Verify binding
kubectl get clusterrolebinding external-dns-extended -o yaml

# Check service account
kubectl get sa -n external-dns external-dns
```

### Template Rendering Errors

**Issue:** Helm template errors

**Solution:**
```bash
# Validate values file
helm lint ./charts/external-dns -f charts/external-dns/values-dev-direct.yaml

# Debug template rendering
helm template external-dns ./charts/external-dns \
  -f charts/external-dns/values-dev-direct.yaml \
  --debug
```

## Migration from Static YAML

If you were using `custom-clusterrole.yaml`:

### Before (Static YAML)
```bash
kubectl apply -f charts/external-dns/custom-clusterrole.yaml
```

### After (Helm Templates)
```bash
# Option 1: Include in Helm deployment
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -f charts/external-dns/values-dev-direct.yaml \
  -n external-dns

# Option 2: Apply templates separately
helm template external-dns ./charts/external-dns \
  -f charts/external-dns/values-dev-direct.yaml \
  -s templates/extended-clusterrole.yaml \
  | kubectl apply -f -
```

### Cleanup Old Resources

```bash
# Remove old static ClusterRole
kubectl delete clusterrole external-dns-extended
kubectl delete clusterrolebinding external-dns-extended

# Deploy with Helm templates
helm upgrade --install external-dns ...
```

## Best Practices

1. **Use Values Files**
   - Keep configuration in values files
   - Don't modify templates directly
   - Use separate values files per environment

2. **Enable Only What You Need**
   - Disable unused ingress controllers
   - Reduces ClusterRole size
   - Improves security posture

3. **Version Control**
   - Commit values files to Git
   - Track changes over time
   - Use GitOps for deployment

4. **Test Before Production**
   - Use `helm template` to preview
   - Test in dev environment first
   - Verify permissions with `kubectl auth can-i`

5. **Document Customizations**
   - Comment your values files
   - Explain why specific rules are enabled
   - Include in runbooks

## Additional Resources

- [Helm Templates Guide](https://helm.sh/docs/chart_template_guide/)
- [External DNS Documentation](https://github.com/kubernetes-sigs/external-dns)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)

