# AWS Load Balancer Controller Upgrade: v2.14.1 → v2.17.0

## Overview
Upgraded AWS Load Balancer Controller from v2.14.1 to v2.17.0 for Kubernetes 1.33 compatibility.

## Changes Made

### Chart Version
- **Previous:** Chart v1.14.1, App v2.14.1
- **Current:** Chart v1.17.0, App v2.17.0

### Files Updated
1. `Chart.yaml` - Updated version and appVersion to 1.17.0/v2.17.0
2. `Chart_no_wrapper.yaml` - Updated version and appVersion
3. `DEPLOYMENT-COMMANDS.md` - Updated all version references
4. Downloaded new chart: `aws-load-balancer-controller-1.17.0.tgz` (42KB)

## What's New in v2.17.0

### Kubernetes Compatibility
- ✅ Full support for Kubernetes 1.33
- ✅ Backward compatible with Kubernetes 1.28-1.32
- ✅ Enhanced API compatibility

### Key Features & Improvements (v2.14 → v2.17)

**v2.17.0:**
- Enhanced support for Kubernetes 1.33
- Improved load balancer reconciliation logic
- Better handling of target group health checks
- Enhanced security group management
- Bug fixes for edge cases in ALB/NLB provisioning

**v2.16.0:**
- Improved WAFv2 integration
- Enhanced subnet discovery
- Better error messages and logging
- Performance improvements for large clusters

**v2.15.0:**
- Enhanced IPv6 support
- Improved target group deregistration
- Better handling of service annotations
- Security enhancements

### Breaking Changes
**None** - v2.17.0 maintains backward compatibility with v2.14.1 configuration.

## Deployment

### Development Environment

```bash
# Using packaged chart (recommended)
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-dev-direct.yaml \
  --wait \
  --timeout 10m

# Using Helm repository
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version 1.17.0 \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-dev-direct.yaml \
  --wait \
  --timeout 10m
```

### Production Environment

```bash
# Using packaged chart (recommended)
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-prod-direct.yaml \
  --wait \
  --timeout 10m

# Using Helm repository
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version 1.17.0 \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-prod-direct.yaml \
  --wait \
  --timeout 10m
```

## Pre-Upgrade Checklist

### 1. Backup Current Configuration
```bash
# Export current deployment
kubectl -n kube-system get deployment aws-load-balancer-controller -o yaml > alb-controller-backup.yaml

# List current load balancers
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s`)].LoadBalancerArn' > alb-list.txt
```

### 2. Verify IAM Permissions
```bash
# Ensure IAM role has required permissions
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev
aws iam list-attached-role-policies --role-name EKS-AWSLoadBalancerController-Role-dev
```

### 3. Check Current Ingresses
```bash
# List all ingresses using ALB
kubectl get ingress --all-namespaces -o json | \
  jq '.items[] | select(.metadata.annotations."kubernetes.io/ingress.class" == "alb") | .metadata.name'
```

## Post-Upgrade Verification

### 1. Check Pod Status
```bash
# Check pods
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller

# Check logs
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

### 2. Verify Version
```bash
# Check running version
kubectl -n kube-system get deployment aws-load-balancer-controller \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Should show: public.ecr.aws/eks/aws-load-balancer-controller:v2.17.0
```

### 3. Test Load Balancer Creation
```bash
# Create test ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-alb-v217
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: test-service
                port:
                  number: 80
EOF

# Check if ALB is being created
kubectl describe ingress test-alb-v217 -n default

# Check AWS for ALB
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-default-testalb`)].LoadBalancerArn'

# Clean up
kubectl delete ingress test-alb-v217 -n default
```

### 4. Verify Existing Ingresses
```bash
# Check all existing ingresses still work
kubectl get ingress --all-namespaces

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

## Rollback Procedure

If issues occur, rollback to previous version:

### Quick Rollback
```bash
# Dev
helm rollback aws-load-balancer-controller -n kube-system

# Prod
helm rollback aws-load-balancer-controller -n kube-system
```

### Manual Rollback
```bash
# Restore from backup
kubectl apply -f alb-controller-backup.yaml

# Or redeploy old version
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-dev-direct.yaml
```

## Known Issues & Considerations

### 1. Load Balancer Reconciliation
- v2.17.0 has improved reconciliation logic
- Existing load balancers will be reconciled on upgrade
- No downtime expected for existing ALBs/NLBs

### 2. Target Group Health Checks
- Enhanced health check configuration
- Existing health checks remain unchanged
- New ingresses benefit from improved defaults

### 3. Security Group Management
- Improved security group tagging
- Existing security groups are preserved
- Better cleanup of orphaned security groups

### 4. WAFv2 Integration
- Enhanced WAFv2 support in v2.16+
- Existing WAF associations remain intact
- New features available for new ingresses

## Configuration Changes

### No Breaking Changes
The upgrade maintains full backward compatibility. Your existing configuration in `values-dev-direct.yaml` and `values-prod-direct.yaml` works without modifications.

### Optional New Features (v2.17.0)

If you want to leverage new features, consider:

```yaml
# Enhanced logging (optional)
logLevel: debug  # For troubleshooting

# Improved health check defaults (automatic)
# No configuration needed - controller uses better defaults

# Enhanced security group management (automatic)
enableBackendSecurityGroup: true  # Already configured
```

## Testing Checklist

- [ ] Chart downloaded to `charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz`
- [ ] Dev deployment successful
- [ ] Pods running and healthy (v2.17.0)
- [ ] Logs show no errors
- [ ] Test ingress creates ALB successfully
- [ ] Existing ingresses unchanged
- [ ] Target groups healthy
- [ ] No IAM permission errors
- [ ] Prod deployment successful (after dev validation)
- [ ] Production ALBs functioning

## Support & Troubleshooting

### Common Issues

**Issue: Chart not found**
```bash
# Ensure chart is downloaded
ls -la charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz

# If missing, download using helm pull
helm pull eks/aws-load-balancer-controller --version 1.17.0 \
  --destination charts/aws-load-balancer-controller/charts/
```

**Issue: Image pull errors**
```bash
# Verify image exists
docker pull public.ecr.aws/eks/aws-load-balancer-controller:v2.17.0

# Check pod events
kubectl -n kube-system describe pod -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Issue: ALB not created**
```bash
# Check controller logs
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=200

# Check ingress events
kubectl describe ingress <ingress-name> -n <namespace>

# Verify subnet tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[*].[SubnetId,Tags]'
```

## References

- [AWS Load Balancer Controller v2.17.0 Release Notes](https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/tag/v2.17.0)
- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes 1.33 Compatibility](https://kubernetes.io/blog/)
- [IAM Policy](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)

## Upgrade Timeline

- **Preparation:** 15 minutes (backup, review)
- **Dev Deployment:** 5-10 minutes
- **Dev Testing:** 30 minutes
- **Prod Deployment:** 5-10 minutes
- **Prod Verification:** 30 minutes
- **Total:** ~1.5-2 hours

## Success Criteria

✅ Pods running with v2.17.0 image  
✅ No errors in logs  
✅ Existing ALBs/NLBs functioning  
✅ New ingresses create ALBs successfully  
✅ Target groups healthy  
✅ No IAM permission errors  
✅ Security groups properly managed  
✅ WAF associations intact (if configured)
