# ExternalDNS Deployment Commands

## Extended RBAC (Optional but Recommended)

External DNS includes extended RBAC permissions available in multiple formats:

### Option 1: Apply Standalone RBAC (Simplest)

Apply the pre-configured RBAC file after Helm deployment:

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

### Option 2: Use Wrapper Chart with Templates

Use the wrapper chart that includes both the packaged chart and custom templates:

```bash
# Build dependencies first
cd charts/external-dns
helm dependency build

# Deploy wrapper chart
helm upgrade --install external-dns . \
  -f values-wrapper.yaml \
  -n external-dns \
  --create-namespace
```

### Option 3: Static YAML (Legacy)

Apply the original static ClusterRole:

```bash
kubectl apply -f charts/external-dns/custom-clusterrole.yaml
```

### What's Included

Extended permissions for:
- **Gateway API**: Gateways, HTTPRoutes, TLSRoutes, TCPRoutes, UDPRoutes, GRPCRoutes
- **Istio**: VirtualServices, Gateways
- **DNSEndpoint CRD**: Custom DNS management
- **Events**: Debugging and monitoring
- **Leader Election**: Multi-replica support

**Verify permissions:**
```bash
# Gateway API
kubectl auth can-i list gateways.gateway.networking.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns

# Istio
kubectl auth can-i list virtualservices.networking.istio.io \
  --as=system:serviceaccount:external-dns:external-dns

# DNSEndpoint
kubectl auth can-i list dnsendpoints.externaldns.k8s.io \
  --as=system:serviceaccount:external-dns:external-dns
```

**Documentation:**
- Standalone RBAC: `k8s-resources/extended-rbac.yaml`
- Wrapper Chart: `values-wrapper.yaml` + `templates/`
- Static YAML: `custom-clusterrole.yaml`
- Guides: `CUSTOM-CLUSTERROLE-GUIDE.md`, `TEMPLATES-USAGE-GUIDE.md`

## Using the Default Chart Directly (Recommended)

Since you're getting coalesce warnings with the wrapper structure, use the chart directly with the `-direct` values files.

### Development Environment

```bash
# Method 1: Packaged chart + Standalone RBAC (Recommended)
# =========================================================

# 1. Deploy External DNS
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  --namespace external-dns \
  --create-namespace \
  --values charts/external-dns/values-dev-direct.yaml \
  --wait \
  --timeout 10m

# 2. Apply extended RBAC
kubectl apply -f charts/external-dns/k8s-resources/extended-rbac.yaml

# 3. Verify
kubectl get pods -n external-dns
kubectl get clusterrole external-dns-extended
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50

# Method 2: Wrapper Chart (Alternative)
# ======================================

# 1. Build dependencies
cd charts/external-dns
helm dependency build

# 2. Deploy wrapper chart
helm upgrade --install external-dns . \
  -f values-wrapper.yaml \
  -n external-dns \
  --create-namespace \
  --wait \
  --timeout 10m

# Dry run first (recommended)
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  --namespace external-dns \
  --create-namespace \
  --values charts/external-dns/values-dev-direct.yaml \
  --dry-run \
  --debug
```

### Production Environment

```bash
# 1. (Optional) Apply custom ClusterRole for extended permissions
kubectl apply -f charts/external-dns/custom-clusterrole.yaml

# 2. Install/Upgrade External DNS
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  --namespace external-dns \
  --create-namespace \
  --values charts/external-dns/values-prod-direct.yaml \
  --wait \
  --timeout 10m

# 3. Verify deployment
kubectl get pods -n external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50

# Dry run first (recommended)
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  --namespace external-dns \
  --create-namespace \
  --values charts/external-dns/values-prod-direct.yaml \
  --dry-run \
  --debug
```

## Using Helm Repository (Alternative)

If you prefer to use the chart from the repository directly:

```bash
# Add repository
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

# Install dev
helm upgrade --install external-dns external-dns/external-dns \
  --version 1.19.0 \
  --namespace external-dns \
  --create-namespace \
  --values charts/external-dns/values-dev-direct.yaml \
  --wait \
  --timeout 10m

# Install prod
helm upgrade --install external-dns external-dns/external-dns \
  --version 1.19.0 \
  --namespace external-dns \
  --create-namespace \
  --values charts/external-dns/values-prod-direct.yaml \
  --wait \
  --timeout 10m
```

## Verification

After deployment:

```bash
# Check pods
kubectl -n external-dns get pods

# Check deployment
kubectl -n external-dns get deployment external-dns

# Check version
kubectl -n external-dns get deployment external-dns \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Expected: registry.k8s.io/external-dns/external-dns:v0.19.0

# Check logs
kubectl -n external-dns logs -l app.kubernetes.io/name=external-dns --tail=50

# Check service account
kubectl -n external-dns get sa external-dns -o yaml
```

## Uninstall

```bash
# Uninstall from dev
helm uninstall external-dns --namespace external-dns

# Uninstall from prod
helm uninstall external-dns --namespace external-dns
```

## Troubleshooting

### Check Helm Release
```bash
helm list -n external-dns
helm status external-dns -n external-dns
helm get values external-dns -n external-dns
```

### Check for Errors
```bash
# Pod events
kubectl -n external-dns describe pod -l app.kubernetes.io/name=external-dns

# Deployment events
kubectl -n external-dns describe deployment external-dns

# Recent events
kubectl -n external-dns get events --sort-by='.lastTimestamp'
```

### Test DNS Record Creation
```bash
# Create test service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: test-external-dns
  namespace: default
  annotations:
    external-dns.alpha.kubernetes.io/hostname: test.dev.example.com
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: test
EOF

# Wait a few minutes, then check Route53
aws route53 list-resource-record-sets \
  --hosted-zone-id <your-zone-id> \
  --query "ResourceRecordSets[?Name=='test.dev.example.com.']"

# Clean up
kubectl delete service test-external-dns -n default
```

## Notes

- Use `values-dev-direct.yaml` and `values-prod-direct.yaml` for direct chart deployment
- These files have the correct structure without the wrapper
- Update `ACCOUNT_ID` and domain names in the values files before deployment
- Ensure IAM roles are created via Terraform first
