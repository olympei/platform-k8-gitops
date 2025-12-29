# AWS Load Balancer Controller Deployment Commands

## Using the Default Chart Directly (Recommended)

Use the packaged chart directly with the `-direct` values files to avoid coalesce warnings.

### Development Environment

```bash
# Install/Upgrade
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-dev-direct.yaml \
  --wait \
  --timeout 10m

# Dry run first (recommended)
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-dev-direct.yaml \
  --dry-run \
  --debug
```

### Production Environment

```bash
# Install/Upgrade
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-prod-direct.yaml \
  --wait \
  --timeout 10m

# Dry run first (recommended)
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.17.0.tgz \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-prod-direct.yaml \
  --dry-run \
  --debug
```

## Using Helm Repository (Alternative)

If you prefer to use the chart from the EKS repository directly:

```bash
# Add repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install dev
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version 1.17.0 \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-dev-direct.yaml \
  --wait \
  --timeout 10m

# Install prod
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version 1.17.0 \
  --namespace kube-system \
  --values charts/aws-load-balancer-controller/values-prod-direct.yaml \
  --wait \
  --timeout 10m
```

## Prerequisites

Before deploying, ensure you have:

1. **IAM Role Created** (via Terraform)
   ```bash
   # Verify role exists
   aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev
   ```

2. **VPC Subnet Tags** (Required for ALB/NLB creation)
   ```bash
   # Public subnets (for internet-facing ALBs)
   kubernetes.io/role/elb = 1
   
   # Private subnets (for internal ALBs)
   kubernetes.io/role/internal-elb = 1
   ```

3. **Updated Values File**
   - Replace `clusterName` with your EKS cluster name
   - Replace `region` with your AWS region
   - Replace `vpcId` with your VPC ID
   - Replace `ACCOUNT_ID` with your AWS account ID

## Verification

After deployment:

```bash
# Check pods
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller

# Check deployment
kubectl -n kube-system get deployment aws-load-balancer-controller

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

## Test with Sample Ingress

Create a test Ingress to verify the controller is working:

```bash
# Create test Ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-alb
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
kubectl describe ingress test-alb -n default

# Check controller logs for ALB creation
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Check AWS Console or CLI for ALB
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-default-testalb`)].LoadBalancerArn'

# Clean up test
kubectl delete ingress test-alb -n default
```

## Uninstall

```bash
# Uninstall from dev
helm uninstall aws-load-balancer-controller --namespace kube-system

# Uninstall from prod
helm uninstall aws-load-balancer-controller --namespace kube-system
```

**Warning:** Uninstalling the controller will not automatically delete existing load balancers. Delete all Ingress resources first.

## Troubleshooting

### Check Helm Release
```bash
helm list -n kube-system
helm status aws-load-balancer-controller -n kube-system
helm get values aws-load-balancer-controller -n kube-system
```

### Controller Not Starting
```bash
# Pod events
kubectl -n kube-system describe pod -l app.kubernetes.io/name=aws-load-balancer-controller

# Deployment events
kubectl -n kube-system describe deployment aws-load-balancer-controller

# Recent events
kubectl -n kube-system get events --sort-by='.lastTimestamp' | grep aws-load-balancer
```

### IAM Permission Issues
```bash
# Check service account annotations
kubectl -n kube-system get sa aws-load-balancer-controller \
  -o jsonpath='{.metadata.annotations}'

# Check CloudTrail for denied API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=EKS-AWSLoadBalancerController-Role-dev \
  --max-results 20
```

### Load Balancer Not Created
```bash
# Check controller logs
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=200

# Check ingress events
kubectl describe ingress <ingress-name> -n <namespace>

# Verify subnet tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[*].[SubnetId,Tags]'
```

### Common Issues

1. **Missing Subnet Tags**
   - Public subnets need: `kubernetes.io/role/elb=1`
   - Private subnets need: `kubernetes.io/role/internal-elb=1`

2. **IAM Permission Errors**
   - Verify IAM role has all required permissions
   - Check trust policy includes both IRSA and Pod Identity

3. **VPC Configuration**
   - Ensure VPC ID is correct in values file
   - Verify security groups allow traffic

4. **Webhook Issues**
   - Check webhook service is running
   - Verify webhook certificates are valid

## Configuration Notes

### Required Values
```yaml
clusterName: "your-eks-cluster-name"  # REQUIRED
region: "us-east-1"                   # REQUIRED
vpcId: "vpc-xxxxx"                    # REQUIRED
```

### Service Account Annotations
Both IRSA and Pod Identity annotations are configured:
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-{env}"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-{env}"
```

### Environment Differences

**Dev:**
- 2 replicas
- Lower resources (200m CPU, 500Mi memory)
- Shield/WAF disabled
- Preferred pod anti-affinity

**Prod:**
- 3 replicas
- Higher resources (500m CPU, 1Gi memory)
- Shield and WAFv2 enabled
- Required pod anti-affinity across zones
- Priority class: system-cluster-critical

## Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [Service Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/annotations/)
- [IAM Policy](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)

## Notes

- Use `values-dev-direct.yaml` and `values-prod-direct.yaml` for direct chart deployment
- These files have the correct structure without the wrapper
- Controller is deployed to `kube-system` namespace by default
- Ensure IAM roles are created via Terraform before deployment
- VPC subnet tags are critical for ALB/NLB creation
