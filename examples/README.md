# AWS Load Balancer Controller Examples

This directory contains practical examples for using the AWS Load Balancer Controller with Kubernetes.

## Directory Structure

### [ingress/](ingress/)
Examples for using Kubernetes Ingress resources with the AWS Load Balancer Controller.

**Contents:**
- Basic shared ALB configuration
- Multi-namespace ALB sharing
- Priority-based routing
- Multiple SSL certificates (SNI)
- Custom health checks
- Cognito authentication
- HTTP to HTTPS redirects
- Terraform-managed ALB integration

**Quick Start:**
```bash
cd ingress/
kubectl apply -f 01-basic-shared-alb.yaml
```

**Documentation:**
- [Ingress Examples README](ingress/README.md)
- [Terraform ALB Integration Guide](ingress/TERRAFORM-ALB-INTEGRATION.md)

### [targetgroupbinding/](targetgroupbinding/)
Examples for using TargetGroupBinding CRD to bind Kubernetes Services directly to AWS Target Groups.

**Contents:**
- Basic TargetGroupBinding
- Terraform-managed ALB with TargetGroupBinding
- Multi-port service binding
- Instance mode configuration
- Blue-green deployments
- Cross-cluster target group sharing

**Quick Start:**
```bash
cd targetgroupbinding/
# Create target group first
aws elbv2 create-target-group --name my-app-tg --protocol HTTP --port 80 --vpc-id vpc-xxxxx --target-type ip

# Deploy application
kubectl apply -f 01-basic-targetgroupbinding.yaml
```

**Documentation:**
- [TargetGroupBinding Examples README](targetgroupbinding/README.md)
- [TargetGroupBinding Complete Guide](targetgroupbinding/TARGETGROUPBINDING-GUIDE.md)

## Choosing Between Ingress and TargetGroupBinding

### Use Ingress When:
- ✓ You want the controller to manage the entire ALB lifecycle
- ✓ You need simple host/path-based routing
- ✓ You prefer declarative Kubernetes-native configuration
- ✓ You're starting fresh without existing infrastructure
- ✓ You want automatic ALB creation and management

### Use TargetGroupBinding When:
- ✓ You have existing ALB/NLB infrastructure (Terraform, CloudFormation)
- ✓ You need to share load balancers across multiple clusters
- ✓ You want to implement blue-green or canary deployments
- ✓ You need to integrate Kubernetes with non-Kubernetes targets (EC2, Lambda)
- ✓ You require fine-grained control over target group configuration
- ✓ Infrastructure and application teams are separate

## Comparison Table

| Feature | Ingress | TargetGroupBinding |
|---------|---------|-------------------|
| **ALB Management** | Controller creates/manages | Use existing ALB |
| **Target Group** | Controller creates | Use existing TG |
| **Routing Rules** | Defined in Ingress | Defined in ALB |
| **Terraform Integration** | Limited | Excellent |
| **Multi-Cluster** | Difficult | Easy |
| **Hybrid Targets** | Not supported | Supported |
| **Blue-Green** | Complex | Simple |
| **Complexity** | Lower | Higher |
| **Flexibility** | Lower | Higher |
| **Best For** | New deployments | Existing infrastructure |

## Prerequisites

### Required for All Examples

1. **AWS Load Balancer Controller installed:**
   ```bash
   kubectl get deployment -n aws-load-balancer-controller aws-load-balancer-controller
   ```

2. **IAM permissions configured** for the controller

3. **VPC and subnets** properly tagged

4. **Security groups** configured to allow traffic

### Additional for Ingress Examples

- IngressClass configured:
  ```bash
  kubectl get ingressclass alb
  ```

### Additional for TargetGroupBinding Examples

- TargetGroupBinding CRD installed:
  ```bash
  kubectl get crd targetgroupbindings.elbv2.k8s.aws
  ```

- Existing Target Groups created in AWS

## Quick Reference

### Ingress Annotations

```yaml
annotations:
  # Shared ALB
  alb.ingress.kubernetes.io/group.name: shared-alb
  
  # Target type
  alb.ingress.kubernetes.io/target-type: ip
  
  # SSL
  alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."
  alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  
  # Health checks
  alb.ingress.kubernetes.io/healthcheck-path: /health
  alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
```

### TargetGroupBinding Spec

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: my-app-tgb
spec:
  serviceRef:
    name: my-service
    port: 80
  targetGroupARN: arn:aws:elasticloadbalancing:...
  targetType: ip
```

## Common Tasks

### Create Target Group (for TargetGroupBinding)

```bash
aws elbv2 create-target-group \
  --name my-app-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-xxxxx \
  --target-type ip \
  --health-check-path /health
```

### Check Target Health

```bash
TG_ARN="arn:aws:elasticloadbalancing:..."
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

### View ALB Details

```bash
# From Ingress
ALB_DNS=$(kubectl get ingress my-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$ALB_DNS'].LoadBalancerArn" \
  --output text)

# View listener rules
aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN
```

### Test Endpoints

```bash
# Test HTTP
curl http://<alb-dns-name> -H "Host: app.example.com"

# Test HTTPS
curl https://<alb-dns-name> -H "Host: app.example.com"

# Test with verbose output
curl -v http://<alb-dns-name>
```

## Troubleshooting

### Ingress Not Creating ALB

```bash
# Check controller logs
kubectl logs -n aws-load-balancer-controller \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  --tail=100

# Verify IngressClass
kubectl get ingressclass
kubectl describe ingress <name>
```

### TargetGroupBinding Not Working

```bash
# Check TargetGroupBinding status
kubectl describe targetgroupbinding <name>

# Verify service and endpoints
kubectl get svc <service-name>
kubectl get endpoints <service-name>

# Check target health
aws elbv2 describe-target-health --target-group-arn <arn>
```

### Targets Unhealthy

```bash
# Check health check configuration
aws elbv2 describe-target-groups --target-group-arns <arn>

# Test health check from pod
kubectl exec <pod-name> -- curl localhost:<port>/health

# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>
```

## Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [TargetGroupBinding Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/targetgroupbinding/targetgroupbinding/)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Contributing

When adding new examples:
1. Place in appropriate subdirectory (ingress/ or targetgroupbinding/)
2. Use numbered prefixes for ordering (01-, 02-, etc.)
3. Include inline comments explaining configuration
4. Add verification steps at the end
5. Update the subdirectory README
6. Test examples before committing

