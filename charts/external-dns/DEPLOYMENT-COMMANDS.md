# ExternalDNS Deployment Commands

## Using the Default Chart Directly (Recommended)

Since you're getting coalesce warnings with the wrapper structure, use the chart directly with the `-direct` values files.

### Development Environment

```bash
# Install/Upgrade
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  --namespace external-dns \
  --create-namespace \
  --values charts/external-dns/values-dev-direct.yaml \
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
# Install/Upgrade
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  --namespace external-dns \
  --create-namespace \
  --values charts/external-dns/values-prod-direct.yaml \
  --wait \
  --timeout 10m

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
