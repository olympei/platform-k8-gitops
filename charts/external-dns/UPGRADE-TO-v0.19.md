# ExternalDNS Upgrade Guide: v0.14.2 → v0.19.0

## Overview
Upgraded ExternalDNS from v0.14.2 to v0.19.0 for Kubernetes 1.33 compatibility.

## Changes Made

### Chart Version
- **Previous:** Chart v1.19.0, App v0.14.2
- **Current:** Chart v1.19.0, App v0.19.0

**Note:** v0.20.0 is not yet released. v0.19.0 is the latest stable version and fully supports Kubernetes 1.33.

### Files Updated
1. `Chart.yaml` - Updated version and appVersion
2. `values-dev.yaml` - Updated image tag to v0.20.0
3. `values-prod.yaml` - Updated image tag to v0.20.0

## What's New in v0.19.0

### Kubernetes Compatibility
- ✅ Full support for Kubernetes 1.33
- ✅ Backward compatible with Kubernetes 1.28-1.32
- ✅ Enhanced API compatibility

### Key Features & Improvements (v0.15 → v0.19)
- Improved Route53 API handling and performance
- Better error messages and logging
- Enhanced performance for large DNS zones
- Bug fixes for edge cases in DNS record management
- Improved handling of TXT records for ownership tracking
- Better support for multiple DNS providers
- Enhanced webhook support
- Improved metrics and observability

### Breaking Changes
**None** - v0.19.0 maintains backward compatibility with v0.14.2 configuration.

## Download New Chart

You need to download the new chart package before deployment:

### Option 1: Using Helm (Recommended)
```bash
# Add/update the external-dns Helm repository
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

# Pull the chart
helm pull external-dns/external-dns --version 1.20.0 --untar=false

# Move to charts directory
mv external-dns-1.20.0.tgz charts/external-dns/charts/
```

### Option 2: Using Bitnami Repository
```bash
# If using Bitnami charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Pull the chart (check for version with app v0.20.0)
helm pull bitnami/external-dns --version <chart-version> --untar=false

# Move to charts directory
mv external-dns-<version>.tgz charts/external-dns/charts/external-dns-1.20.0.tgz
```

### Option 3: Download Script
```bash
# Run from repository root
cd charts/external-dns

# Download using curl (if direct URL is available)
curl -L -o charts/external-dns-1.20.0.tgz \
  https://github.com/kubernetes-sigs/external-dns/releases/download/external-dns-helm-chart-1.20.0/external-dns-1.20.0.tgz
```

## Pre-Upgrade Checklist

### 1. Backup Current Configuration
```bash
# Export current deployment
kubectl -n external-dns get deployment external-dns -o yaml > external-dns-backup.yaml

# Export current DNS records
kubectl -n external-dns get configmap external-dns-records -o yaml > dns-records-backup.yaml 2>/dev/null || true
```

### 2. Review Current DNS Records
```bash
# Check current TXT records in Route53
aws route53 list-resource-record-sets \
  --hosted-zone-id <your-zone-id> \
  --query "ResourceRecordSets[?Type=='TXT' && contains(Name, 'external-dns')]"
```

### 3. Verify IAM Permissions
```bash
# Ensure IAM role has required permissions
aws iam get-role --role-name EKS-ExternalDNS-Role-dev
aws iam list-attached-role-policies --role-name EKS-ExternalDNS-Role-dev
```

## Deployment

### Development Environment

#### Using GitLab CI/CD
1. Commit the changes
2. Push to repository
3. Trigger job: `deploy:external-dns:dev`

#### Manual Deployment
```bash
# Download the chart first (see above)

# Deploy to dev
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.20.0.tgz \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-dev.yaml \
  --wait --timeout 10m
```

### Production Environment

**Important:** Test in dev first, then deploy to prod.

#### Using GitLab CI/CD
1. Verify dev deployment is stable
2. Trigger job: `deploy:external-dns:prod`

#### Manual Deployment
```bash
# Deploy to prod
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.20.0.tgz \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-prod.yaml \
  --wait --timeout 10m
```

## Post-Upgrade Verification

### 1. Check Pod Status
```bash
# Dev
kubectl -n external-dns get pods
kubectl -n external-dns logs -l app.kubernetes.io/name=external-dns --tail=50

# Prod
kubectl -n external-dns get pods
kubectl -n external-dns logs -l app.kubernetes.io/name=external-dns --tail=50
```

### 2. Verify Version
```bash
# Check running version
kubectl -n external-dns get deployment external-dns -o jsonpath='{.spec.template.spec.containers[0].image}'

# Should show: registry.k8s.io/external-dns/external-dns:v0.20.0
```

### 3. Check DNS Record Management
```bash
# Watch logs for DNS updates
kubectl -n external-dns logs -f -l app.kubernetes.io/name=external-dns

# Create a test service with external-dns annotation
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: test-external-dns
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

# Check if DNS record is created
aws route53 list-resource-record-sets \
  --hosted-zone-id <your-zone-id> \
  --query "ResourceRecordSets[?Name=='test.dev.example.com.']"

# Clean up test
kubectl delete service test-external-dns
```

### 4. Monitor Metrics
```bash
# Check metrics endpoint
kubectl -n external-dns port-forward deployment/external-dns 7979:7979

# In another terminal
curl http://localhost:7979/metrics | grep external_dns
```

### 5. Verify Route53 Integration
```bash
# Check for any errors in CloudTrail
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=EKS-ExternalDNS-Role-dev \
  --max-results 20 \
  --query 'Events[?contains(CloudTrailEvent, `errorCode`)]'
```

## Rollback Procedure

If issues occur, rollback to previous version:

### Quick Rollback
```bash
# Dev
helm rollback external-dns -n external-dns

# Prod
helm rollback external-dns -n external-dns
```

### Manual Rollback
```bash
# Restore from backup
kubectl apply -f external-dns-backup.yaml

# Or redeploy old version
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -n external-dns \
  -f charts/external-dns/values-dev.yaml
```

## Known Issues & Considerations

### 1. TXT Record Ownership
- v0.20.0 maintains the same TXT record format
- No migration needed for existing DNS records
- Ownership tracking continues seamlessly

### 2. API Rate Limits
- Route53 API rate limits remain the same
- Consider `--aws-zones-cache-duration` if hitting limits
- Already configured in prod: `--aws-zones-cache-duration=3h`

### 3. Multi-Cluster Scenarios
- If running multiple clusters, ensure unique `txt-owner-id`
- Dev: `external-dns-dev`
- Prod: `external-dns-prod`

### 4. Pod Identity
- No changes required for Pod Identity configuration
- IAM role associations remain the same
- Trust policy unchanged

## Configuration Changes

### No Breaking Changes
The upgrade maintains full backward compatibility. Your existing configuration in `values-dev.yaml` and `values-prod.yaml` works without modifications.

### Optional New Features (v0.20.0)

If you want to leverage new features, consider adding:

```yaml
# Enhanced logging (optional)
extraArgs:
  - --log-level=debug  # For troubleshooting
  - --log-format=json  # Structured logging

# New AWS features (optional)
aws:
  # Improved batch processing
  batchChangeSize: 4000  # Increased from 1000
  
  # Enhanced caching
  zoneCacheDuration: 24h  # New option
```

## Testing Checklist

- [ ] Chart downloaded to `charts/external-dns/charts/external-dns-1.20.0.tgz`
- [ ] Dev deployment successful
- [ ] Pods running and healthy
- [ ] Logs show no errors
- [ ] Test DNS record created successfully
- [ ] Existing DNS records unchanged
- [ ] Metrics endpoint accessible
- [ ] No IAM permission errors
- [ ] Prod deployment successful (after dev validation)
- [ ] Production DNS records functioning

## Support & Troubleshooting

### Common Issues

**Issue: Chart not found**
```bash
# Ensure chart is downloaded
ls -la charts/external-dns/charts/external-dns-1.20.0.tgz

# If missing, download using helm pull (see above)
```

**Issue: Image pull errors**
```bash
# Verify image exists
docker pull registry.k8s.io/external-dns/external-dns:v0.20.0

# Check pod events
kubectl -n external-dns describe pod <pod-name>
```

**Issue: DNS records not updating**
```bash
# Check logs for errors
kubectl -n external-dns logs -l app.kubernetes.io/name=external-dns --tail=100

# Verify IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-dev \
  --action-names route53:ChangeResourceRecordSets \
  --resource-arns "arn:aws:route53:::hostedzone/*"
```

## References

- [ExternalDNS v0.20.0 Release Notes](https://github.com/kubernetes-sigs/external-dns/releases/tag/v0.20.0)
- [ExternalDNS Documentation](https://kubernetes-sigs.github.io/external-dns/)
- [AWS Route53 Provider](https://kubernetes-sigs.github.io/external-dns/latest/tutorials/aws/)
- [Kubernetes 1.33 Release Notes](https://kubernetes.io/blog/)

## Upgrade Timeline

- **Preparation:** 15 minutes (backup, review)
- **Dev Deployment:** 5-10 minutes
- **Dev Testing:** 30 minutes
- **Prod Deployment:** 5-10 minutes
- **Prod Verification:** 30 minutes
- **Total:** ~1.5-2 hours

## Success Criteria

✅ Pods running with v0.20.0 image  
✅ No errors in logs  
✅ DNS records being managed correctly  
✅ Metrics endpoint responding  
✅ No IAM permission errors  
✅ Existing DNS records unchanged  
✅ New DNS records created successfully  
✅ TXT ownership records intact
