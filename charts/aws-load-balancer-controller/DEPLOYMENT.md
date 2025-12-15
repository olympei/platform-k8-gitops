# AWS Load Balancer Controller Deployment Guide

## Overview
The AWS Load Balancer Controller manages AWS Elastic Load Balancers for Kubernetes clusters. It provisions:
- **Application Load Balancers (ALB)** for Kubernetes Ingress resources
- **Network Load Balancers (NLB)** for Kubernetes Service resources with type LoadBalancer

## Prerequisites

### 1. IAM Role
The controller requires an IAM role with permissions to manage AWS load balancers. The unified role approach is used:

**Role Name Pattern:**
- Dev: `EKS-AWSLoadBalancerController-Role-dev`
- Prod: `EKS-AWSLoadBalancerController-Role-prod`

**Required Permissions:**
- Create/Delete/Modify ALB/NLB
- Manage target groups
- Configure security groups
- Manage WAF associations (prod only)

### 2. Cluster Configuration
Before deployment, update the values files with your cluster-specific information:

**Required Values:**
```yaml
clusterName: "your-eks-cluster-name"  # REQUIRED
region: "us-east-1"                   # REQUIRED
vpcId: "vpc-xxxxx"                    # REQUIRED
```

### 3. Service Account Annotations
Both IRSA and Pod Identity annotations are configured to use the same unified role:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-dev"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-dev"
```

## Deployment Methods

### Method 1: GitLab CI/CD (Recommended)

#### Deploy to Dev
```bash
# Trigger the deployment job in GitLab CI
# Job: deploy:aws-load-balancer-controller:dev
```

#### Deploy to Prod
```bash
# Trigger the deployment job in GitLab CI
# Job: deploy:aws-load-balancer-controller:prod
```

#### Deploy with All Charts
The controller is automatically included when deploying all charts:
```bash
# Jobs: deploy:helm:dev or deploy:helm:prod
```

#### Control Variables
```bash
# Disable installation
INSTALL_AWS_LOAD_BALANCER_CONTROLLER=false

# Enable uninstallation
UNINSTALL_AWS_LOAD_BALANCER_CONTROLLER=true

# Override namespace (default: aws-load-balancer-controller)
HELM_NAMESPACE_AWS_LOAD_BALANCER_CONTROLLER=kube-system

# Enable debug mode
HELM_DEBUG=true
```

### Method 2: Manual Helm Deployment

#### Dev Environment
```bash
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  -n aws-load-balancer-controller --create-namespace \
  -f charts/aws-load-balancer-controller/values-dev.yaml \
  --wait --timeout 10m
```

#### Prod Environment
```bash
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  -n aws-load-balancer-controller --create-namespace \
  -f charts/aws-load-balancer-controller/values-prod.yaml \
  --wait --timeout 10m
```

## Configuration Differences

### Development Environment
- **Replicas:** 2
- **Resources:** Lower limits (200m CPU, 500Mi memory)
- **Shield/WAF:** Disabled
- **Affinity:** Preferred pod anti-affinity

### Production Environment
- **Replicas:** 3
- **Resources:** Higher limits (500m CPU, 1Gi memory)
- **Shield/WAF:** Enabled (WAFv2)
- **Affinity:** Required pod anti-affinity across zones
- **Priority Class:** system-cluster-critical

## Verification

### Check Controller Status
```bash
# Check pods
kubectl -n aws-load-balancer-controller get pods

# Check logs
kubectl -n aws-load-balancer-controller logs -l app.kubernetes.io/name=aws-load-balancer-controller

# Check service account
kubectl -n aws-load-balancer-controller get sa aws-load-balancer-controller -o yaml
```

### Verify IAM Role Association
```bash
# Check service account annotations
kubectl -n aws-load-balancer-controller get sa aws-load-balancer-controller -o jsonpath='{.metadata.annotations}'

# For Pod Identity, check pod identity associations
aws eks list-pod-identity-associations --cluster-name your-cluster-name
```

### Test with Sample Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
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
```

## Troubleshooting

### Controller Not Starting
```bash
# Check pod events
kubectl -n aws-load-balancer-controller describe pod <pod-name>

# Check IAM role permissions
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev

# Verify trust policy
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev --query 'Role.AssumeRolePolicyDocument'
```

### Load Balancer Not Created
```bash
# Check controller logs
kubectl -n aws-load-balancer-controller logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Check ingress events
kubectl describe ingress <ingress-name>

# Verify VPC and subnet tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
```

### Common Issues

1. **Missing VPC/Subnet Tags**
   - Public subnets need: `kubernetes.io/role/elb=1`
   - Private subnets need: `kubernetes.io/role/internal-elb=1`

2. **IAM Permission Errors**
   - Verify the IAM role has all required permissions
   - Check CloudTrail for denied API calls

3. **Security Group Issues**
   - Ensure `enableBackendSecurityGroup: true` is set
   - Verify security group rules allow traffic

## Uninstallation

### GitLab CI/CD
```bash
# Set uninstall flag
UNINSTALL_AWS_LOAD_BALANCER_CONTROLLER=true

# Trigger job: uninstall:aws-load-balancer-controller:dev or prod
```

### Manual Uninstallation
```bash
# Dev
helm uninstall aws-load-balancer-controller -n aws-load-balancer-controller

# Prod
helm uninstall aws-load-balancer-controller -n aws-load-balancer-controller
```

**Warning:** Uninstalling the controller will not automatically delete existing load balancers. You must delete all Ingress resources first.

## Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [Service Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/annotations/)
- [IAM Policy](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)

## Support

For issues or questions:
1. Check controller logs
2. Review AWS CloudTrail for API errors
3. Verify IAM permissions and trust policies
4. Check VPC and subnet configurations
