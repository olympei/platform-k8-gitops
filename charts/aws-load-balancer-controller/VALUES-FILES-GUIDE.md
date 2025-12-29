# AWS Load Balancer Controller Values Files Guide

## Available Values Files

This directory contains two sets of values files for different deployment methods:

### 1. Wrapper-Based Deployment (GitLab CI/CD)

**Files:**
- `values-dev.yaml` - Dev environment with wrapper
- `values-prod.yaml` - Prod environment with wrapper
- `Chart.yaml` or `Chart_with_wrapper.yaml` - Chart with dependencies

**Structure:**
```yaml
aws-load-balancer-controller:
  clusterName: "my-eks-cluster-dev"
  region: "us-east-1"
  vpcId: "vpc-xxxxx"
  serviceAccount:
    create: true
  # ... other settings
```

**When to use:**
- When using the parent chart with dependencies
- When deploying via GitLab CI/CD (configured for wrapper structure)
- Consistent with other charts in this repository

**Deployment:**
```bash
# Via GitLab CI/CD (recommended)
# Trigger job: deploy:aws-load-balancer-controller:dev or prod

# Manual deployment with wrapper
helm upgrade --install aws-load-balancer-controller ./charts/aws-load-balancer-controller \
  -n kube-system \
  -f charts/aws-load-balancer-controller/values-dev.yaml \
  --wait --timeout 10m
```

### 2. Direct Chart Deployment

**Files:**
- `values-dev-direct.yaml` - Dev environment without wrapper
- `values-prod-direct.yaml` - Prod environment without wrapper
- `Chart_no_wrapper.yaml` - Chart without dependencies

**Structure:**
```yaml
clusterName: "my-eks-cluster-dev"
region: "us-east-1"
vpcId: "vpc-xxxxx"
serviceAccount:
  create: true
# ... other settings
```

**When to use:**
- When deploying the chart directly without wrapper
- For testing or standalone deployments
- When you want to use the official chart structure
- To avoid coalesce warnings

**Deployment:**
```bash
# Direct deployment using the packaged chart
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  -n kube-system \
  -f charts/aws-load-balancer-controller/values-dev-direct.yaml \
  --wait --timeout 10m
```

## Key Differences

| Aspect | Wrapper (GitLab CI/CD) | Direct |
|--------|------------------------|--------|
| **Values Structure** | Nested under `aws-load-balancer-controller:` | Root level |
| **Chart.yaml** | Has dependencies section | No dependencies |
| **Deployment** | Via parent chart | Via packaged chart directly |
| **GitLab CI/CD** | ✅ Configured | ❌ Not configured |
| **Customization** | Can add custom templates | Uses chart as-is |
| **Coalesce Warnings** | May occur | ❌ None |

## Configuration Comparison

### Wrapper Format (values-dev.yaml)
```yaml
aws-load-balancer-controller:
  clusterName: "my-eks-cluster-dev"
  region: "us-east-1"
  vpcId: "vpc-xxxxx"
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/..."
  replicaCount: 2
  enableShield: false
```

### Direct Format (values-dev-direct.yaml)
```yaml
clusterName: "my-eks-cluster-dev"
region: "us-east-1"
vpcId: "vpc-xxxxx"
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/..."
replicaCount: 2
enableShield: false
```

## Required Configuration

Both formats require the same configuration values:

### Cluster Information (REQUIRED)
```yaml
clusterName: "your-eks-cluster-name"  # REQUIRED
region: "us-east-1"                   # REQUIRED
vpcId: "vpc-xxxxx"                    # REQUIRED
```

### IAM Configuration
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-{env}"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-{env}"
```

## Environment-Specific Settings

### Development (values-dev.yaml / values-dev-direct.yaml)
```yaml
replicaCount: 2
resources:
  limits:
    cpu: 200m
    memory: 500Mi
  requests:
    cpu: 100m
    memory: 200Mi
enableShield: false
enableWaf: false
enableWafv2: false
```

### Production (values-prod.yaml / values-prod-direct.yaml)
```yaml
replicaCount: 3
resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 500Mi
enableShield: true
enableWaf: false
enableWafv2: true
priorityClassName: system-cluster-critical
```

## Recommendation

**Use direct deployment files (recommended)** to avoid coalesce warnings:

✅ **Direct (values-dev-direct.yaml, values-prod-direct.yaml):**
- No coalesce warnings
- Cleaner structure
- Official chart format
- Easier to maintain

⚠️ **Wrapper (values-dev.yaml, values-prod.yaml):**
- Integrated with GitLab CI/CD
- May have coalesce warnings
- Requires dependency management
- Current production setup

## Converting Between Formats

### From Wrapper to Direct

1. Remove the `aws-load-balancer-controller:` wrapper key
2. Move all nested values to root level
3. No other changes needed

### From Direct to Wrapper

1. Add `aws-load-balancer-controller:` wrapper key
2. Nest all values under it
3. No other changes needed

## Chart Files

### Chart.yaml (Current - With Wrapper)
```yaml
dependencies:
  - name: aws-load-balancer-controller
    version: 1.17.0
    repository: "file://./charts/aws-load-balancer-controller-1.17.0.tgz"
```

### Chart_with_wrapper.yaml (Backup)
Same as Chart.yaml - kept for reference

### Chart_no_wrapper.yaml (Alternative)
```yaml
# No dependencies section
# Use for direct deployment
```

## Testing

### Test Wrapper Deployment
```bash
# Dry run
helm upgrade --install aws-load-balancer-controller ./charts/aws-load-balancer-controller \
  -n kube-system \
  -f charts/aws-load-balancer-controller/values-dev.yaml \
  --dry-run --debug

# Actual deployment
helm upgrade --install aws-load-balancer-controller ./charts/aws-load-balancer-controller \
  -n kube-system \
  -f charts/aws-load-balancer-controller/values-dev.yaml \
  --wait --timeout 10m
```

### Test Direct Deployment
```bash
# Dry run
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  -n kube-system \
  -f charts/aws-load-balancer-controller/values-dev-direct.yaml \
  --dry-run --debug

# Actual deployment
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  -n kube-system \
  -f charts/aws-load-balancer-controller/values-dev-direct.yaml \
  --wait --timeout 10m
```

## Verification

After deployment with either method:

```bash
# Check pods
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller

# Check version
kubectl -n kube-system get deployment aws-load-balancer-controller \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Expected: public.ecr.aws/eks/aws-load-balancer-controller:v2.17.0

# Check logs
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Check service account
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml

# Check IngressClass
kubectl get ingressclass
```

## Prerequisites

Before deployment with either method:

1. **IAM Role Created** (via Terraform)
   ```bash
   aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev
   ```

2. **VPC Subnet Tags** (Required)
   - Public subnets: `kubernetes.io/role/elb = 1`
   - Private subnets: `kubernetes.io/role/internal-elb = 1`

3. **Updated Values**
   - Replace `clusterName` with your EKS cluster name
   - Replace `region` with your AWS region
   - Replace `vpcId` with your VPC ID
   - Replace `ACCOUNT_ID` with your AWS account ID

## Troubleshooting

### Coalesce Warnings (Wrapper)
If you see warnings like:
```
coalesce.go:286: warning: cannot overwrite table with non table
```

**Solution:** Use direct deployment files instead:
- Use `values-dev-direct.yaml` instead of `values-dev.yaml`
- Deploy with the packaged chart directly

### Chart Not Found
```bash
# Verify chart exists
ls -la charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz

# If missing, download
helm pull eks/aws-load-balancer-controller --version 1.17.0 \
  --destination charts/aws-load-balancer-controller/charts/
```

## Summary

- **Recommended:** Use direct deployment files (`values-dev-direct.yaml`, `values-prod-direct.yaml`)
- **Alternative:** Use wrapper files (`values-dev.yaml`, `values-prod.yaml`) for GitLab CI/CD
- **Both formats:** Support the same features and IAM configuration
- **Version:** v2.17.0 (compatible with Kubernetes 1.33)

Choose the format that best fits your deployment workflow!
