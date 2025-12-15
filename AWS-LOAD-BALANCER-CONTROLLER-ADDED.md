# AWS Load Balancer Controller - GitLab CI/CD Integration

## Summary
Successfully integrated the AWS Load Balancer Controller chart into the GitLab CI/CD pipeline.

## Changes Made

### 1. GitLab CI/CD Pipeline Updates (`.gitlab-ci.yml`)

#### Added Control Variables
```yaml
# Installation control
INSTALL_AWS_LOAD_BALANCER_CONTROLLER - Controls chart installation (default: true)

# Uninstallation control
UNINSTALL_AWS_LOAD_BALANCER_CONTROLLER - Controls chart uninstallation (default: false)

# Namespace override
HELM_NAMESPACE_AWS_LOAD_BALANCER_CONTROLLER - Override default namespace
```

#### Added Deployment Jobs

**Development Environment:**
```yaml
deploy:aws-load-balancer-controller:dev:
  extends: .deploy_single_chart
  variables:
    ENVIRONMENT: dev
    CHART_TO_DEPLOY: aws-load-balancer-controller
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
```

**Production Environment:**
```yaml
deploy:aws-load-balancer-controller:prod:
  extends: .deploy_single_chart
  variables:
    ENVIRONMENT: prod
    CHART_TO_DEPLOY: aws-load-balancer-controller
    KUBECONFIG_DATA: $PROD_KUBECONFIG_B64
```

### 2. Documentation Created

**File:** `charts/aws-load-balancer-controller/DEPLOYMENT.md`

Comprehensive deployment guide including:
- Prerequisites and IAM role requirements
- Cluster configuration steps
- Deployment methods (GitLab CI/CD and manual)
- Configuration differences between dev and prod
- Verification procedures
- Troubleshooting guide
- Uninstallation instructions

## Existing Chart Configuration

The AWS Load Balancer Controller chart was already properly configured:

### Chart Structure
```
charts/aws-load-balancer-controller/
├── Chart.yaml                          # Chart metadata with dependencies
├── charts/
│   └── aws-load-balancer-controller-1.14.1.tgz  # Packaged chart
├── templates/                          # Kubernetes templates
├── values-dev.yaml                     # Dev environment values
├── values-prod.yaml                    # Prod environment values
├── README.md                           # Chart documentation
└── DEPLOYMENT.md                       # NEW: Deployment guide
```

### IAM Role Configuration
Uses unified IAM role approach (both IRSA and Pod Identity):

**Dev:**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-dev"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-dev"
```

**Prod:**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-prod"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-prod"
```

## Usage

### Deploy via GitLab CI/CD

#### Individual Chart Deployment
1. Navigate to GitLab CI/CD Pipelines
2. Trigger manual job:
   - Dev: `deploy:aws-load-balancer-controller:dev`
   - Prod: `deploy:aws-load-balancer-controller:prod`

#### Deploy with All Charts
The controller is automatically included when running:
- `deploy:helm:dev` - Deploys all enabled charts to dev
- `deploy:helm:prod` - Deploys all enabled charts to prod

#### Disable Installation
Set in GitLab CI/CD variables:
```bash
INSTALL_AWS_LOAD_BALANCER_CONTROLLER=false
```

#### Enable Debug Mode
```bash
HELM_DEBUG=true
```

### Manual Deployment

#### Prerequisites
Before deploying, update these values in `values-{dev,prod}.yaml`:
```yaml
clusterName: "your-eks-cluster-name"  # REQUIRED
region: "us-east-1"                   # REQUIRED
vpcId: "vpc-xxxxx"                    # REQUIRED
```

#### Deploy to Dev
```bash
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  -n aws-load-balancer-controller --create-namespace \
  -f charts/aws-load-balancer-controller/values-dev.yaml \
  --wait --timeout 10m
```

#### Deploy to Prod
```bash
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  -n aws-load-balancer-controller --create-namespace \
  -f charts/aws-load-balancer-controller/values-prod.yaml \
  --wait --timeout 10m
```

## Verification

### Check Deployment Status
```bash
# Check pods
kubectl -n aws-load-balancer-controller get pods

# Check logs
kubectl -n aws-load-balancer-controller logs -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify service account
kubectl -n aws-load-balancer-controller get sa aws-load-balancer-controller -o yaml
```

### Verify IAM Role
```bash
# Check annotations
kubectl -n aws-load-balancer-controller get sa aws-load-balancer-controller \
  -o jsonpath='{.metadata.annotations}'

# List pod identity associations
aws eks list-pod-identity-associations --cluster-name your-cluster-name
```

## Configuration Highlights

### Development Environment
- **Replicas:** 2
- **CPU:** 100m request, 200m limit
- **Memory:** 200Mi request, 500Mi limit
- **Shield/WAF:** Disabled
- **Log Level:** info

### Production Environment
- **Replicas:** 3
- **CPU:** 200m request, 500m limit
- **Memory:** 500Mi request, 1Gi limit
- **Shield:** Enabled
- **WAFv2:** Enabled
- **Priority Class:** system-cluster-critical
- **Log Level:** info

## Important Notes

### VPC Subnet Requirements
For the controller to work properly, subnets must be tagged:

**Public Subnets (for internet-facing ALBs):**
```
kubernetes.io/role/elb = 1
```

**Private Subnets (for internal ALBs):**
```
kubernetes.io/role/internal-elb = 1
```

### IAM Permissions
The IAM role must have permissions to:
- Create/delete/modify ALB and NLB
- Manage target groups
- Configure security groups
- Manage WAF associations (prod)

### Ingress Class
The controller is configured with ingress class `alb`. Use this in your Ingress resources:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: alb
```

## Troubleshooting

### Controller Not Starting
1. Check pod events: `kubectl -n aws-load-balancer-controller describe pod <pod-name>`
2. Verify IAM role exists and has correct trust policy
3. Check service account annotations

### Load Balancer Not Created
1. Check controller logs
2. Verify VPC and subnet tags
3. Check IAM permissions in CloudTrail
4. Verify security group configuration

### Common Issues
- Missing subnet tags
- Insufficient IAM permissions
- Incorrect VPC ID in values file
- Security group rules blocking traffic

## Next Steps

1. **Update Values Files** - Replace placeholder values:
   - `clusterName`
   - `region`
   - `vpcId`
   - `ACCOUNT_ID` in IAM role ARNs

2. **Verify IAM Role** - Ensure the IAM role exists in Terraform:
   - `EKS-AWSLoadBalancerController-Role-dev`
   - `EKS-AWSLoadBalancerController-Role-prod`

3. **Tag Subnets** - Add required tags to VPC subnets

4. **Deploy** - Use GitLab CI/CD or manual Helm commands

5. **Test** - Create a sample Ingress resource to verify functionality

## References

- [AWS Load Balancer Controller Docs](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [IAM Policy JSON](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)
- Chart Version: 1.14.1
- App Version: v2.14.1
