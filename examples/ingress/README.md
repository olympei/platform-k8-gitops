# AWS Load Balancer Controller - Ingress Examples

This directory contains practical examples for using the AWS Load Balancer Controller with Kubernetes Ingress resources.

## Overview

The AWS Load Balancer Controller provisions Application Load Balancers (ALBs) for Kubernetes Ingress resources. These examples demonstrate various configurations and use cases.

## Examples

### 1. Basic Shared ALB (`01-basic-shared-alb.yaml`)
**Use Case:** Multiple applications sharing a single ALB to reduce costs

**Features:**
- Creates a shared ALB using `group.name`
- Multiple Ingresses on the same ALB
- Host-based routing
- Path-based routing

**Deploy:**
```bash
kubectl apply -f 01-basic-shared-alb.yaml
```

### 2. Multi-Namespace Shared ALB (`02-multi-namespace-shared-alb.yaml`)
**Use Case:** Share an ALB across different namespaces

**Features:**
- Cross-namespace ALB sharing
- Isolated services in different namespaces
- Centralized ingress management

**Deploy:**
```bash
kubectl apply -f 02-multi-namespace-shared-alb.yaml
```

### 3. Priority-Based Routing (`03-priority-based-routing.yaml`)
**Use Case:** Control rule evaluation order for overlapping paths

**Features:**
- Rule priority using `group.order`
- Specific paths before catch-all routes
- Admin routes with higher priority

**Deploy:**
```bash
kubectl apply -f 03-priority-based-routing.yaml
```

### 4. Multiple SSL Certificates (`04-multiple-ssl-certificates.yaml`)
**Use Case:** Serve multiple domains with different certificates (SNI)

**Features:**
- Server Name Indication (SNI)
- Multiple certificates on one ALB
- Different domains with their own certificates

**Prerequisites:**
- Certificates uploaded to AWS Certificate Manager (ACM)

**Deploy:**
```bash
# Update certificate ARNs first
kubectl apply -f 04-multiple-ssl-certificates.yaml
```

### 5. Custom Health Checks (`05-custom-health-checks.yaml`)
**Use Case:** Configure different health check settings per service

**Features:**
- Custom health check paths
- Different intervals and timeouts
- HTTP and HTTPS health checks
- Custom success codes

**Deploy:**
```bash
kubectl apply -f 05-custom-health-checks.yaml
```

### 6. Cognito Authentication (`06-cognito-authentication.yaml`)
**Use Case:** Protect applications with AWS Cognito authentication

**Features:**
- AWS Cognito integration
- User authentication before accessing services
- Public and protected apps on same ALB
- Session management

**Prerequisites:**
- AWS Cognito User Pool configured
- User Pool Client created

**Deploy:**
```bash
# Update Cognito configuration first
kubectl apply -f 06-cognito-authentication.yaml
```

### 7. HTTP to HTTPS Redirect (`07-http-to-https-redirect.yaml`)
**Use Case:** Redirect HTTP traffic to HTTPS

**Features:**
- Simple SSL redirect
- Custom redirect with 301/302 status
- HTTPS-only configuration
- Conditional redirects

**Deploy:**
```bash
kubectl apply -f 07-http-to-https-redirect.yaml
```

### 8. Terraform-Managed ALB (`08-terraform-managed-alb.yaml`)
**Use Case:** Use an ALB created by Terraform with Kubernetes Ingress

**Features:**
- ALB lifecycle managed by Terraform
- Kubernetes adds/removes listener rules dynamically
- Separation between infrastructure and application routing
- Multiple Ingresses on Terraform-managed ALB

**Prerequisites:**
- ALB created by Terraform with proper tags
- See `terraform-alb-example.tf` for Terraform configuration
- See `TERRAFORM-ALB-INTEGRATION.md` for complete guide

**Deploy:**
```bash
# First create ALB with Terraform
terraform apply

# Then deploy Ingress
kubectl apply -f 08-terraform-managed-alb.yaml
```

## Prerequisites

### Required

1. **AWS Load Balancer Controller installed:**
   ```bash
   kubectl get deployment -n aws-load-balancer-controller aws-load-balancer-controller
   ```

2. **IngressClass configured:**
   ```bash
   kubectl get ingressclass alb
   ```

3. **IAM permissions:**
   - Controller has permissions to create ALBs
   - Controller can access ACM certificates

### Optional (depending on example)

- **ACM Certificates:** For HTTPS examples
- **AWS Cognito:** For authentication examples
- **Multiple namespaces:** For cross-namespace examples

## Quick Start

### 1. Update Configuration

Before deploying, update these values in the examples:

```yaml
# Replace these placeholders:
ACCOUNT_ID: Your AWS account ID
CERTIFICATE_ID: Your ACM certificate ID
us-east-1: Your AWS region

# Example:
alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234-..."
```

### 2. Create Services

Ensure your Kubernetes services exist:

```bash
# Example service
kubectl create deployment app1 --image=nginx
kubectl expose deployment app1 --port=80 --target-port=80
```

### 3. Deploy Ingress

```bash
kubectl apply -f 01-basic-shared-alb.yaml
```

### 4. Verify

```bash
# Check Ingress status
kubectl get ingress

# Get ALB DNS name
kubectl get ingress app1-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test the endpoint
curl http://<alb-dns-name> -H "Host: app1.example.com"
```

## Common Annotations

### Required for Shared ALB

```yaml
alb.ingress.kubernetes.io/group.name: shared-alb
alb.ingress.kubernetes.io/target-type: ip
```

### SSL/TLS

```yaml
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."
alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
alb.ingress.kubernetes.io/ssl-redirect: '443'
```

### Health Checks

```yaml
alb.ingress.kubernetes.io/healthcheck-path: /health
alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
alb.ingress.kubernetes.io/healthy-threshold-count: '2'
alb.ingress.kubernetes.io/unhealthy-threshold-count: '3'
```

### Authentication

```yaml
alb.ingress.kubernetes.io/auth-type: cognito
alb.ingress.kubernetes.io/auth-idp-cognito: '{"userPoolArn":"...","userPoolClientId":"...","userPoolDomain":"..."}'
```

## Troubleshooting

### Ingress Not Creating ALB

**Check controller logs:**
```bash
kubectl logs -n aws-load-balancer-controller -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Verify IngressClass:**
```bash
kubectl get ingressclass
kubectl describe ingress <ingress-name>
```

### Certificate Not Found

**Verify certificate exists:**
```bash
aws acm list-certificates --region us-east-1
```

**Check certificate ARN in annotation:**
```bash
kubectl get ingress <ingress-name> -o yaml | grep certificate-arn
```

### Rules Not Applied

**Check group configuration:**
```bash
kubectl get ingress -A -o custom-columns=NAME:.metadata.name,GROUP:.metadata.annotations.alb\.ingress\.kubernetes\.io/group\.name,ORDER:.metadata.annotations.alb\.ingress\.kubernetes\.io/group\.order
```

**Verify ALB listener rules:**
```bash
# Get ALB ARN
ALB_ARN=$(kubectl get ingress <ingress-name> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | xargs -I {} aws elbv2 describe-load-balancers --query "LoadBalancers[?DNSName=='{}'].LoadBalancerArn" --output text)

# List rules
aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN"
```

### Service Not Reachable

**Check target group health:**
```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query 'TargetGroups[0].TargetGroupArn' --output text)

# Check target health
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
```

**Verify service and pods:**
```bash
kubectl get svc <service-name>
kubectl get pods -l app=<app-label>
kubectl get endpoints <service-name>
```

## Best Practices

### 1. Use Shared ALBs

Share ALBs across multiple Ingresses to reduce costs:

```yaml
alb.ingress.kubernetes.io/group.name: production-alb
```

### 2. Set Priorities

Use `group.order` for overlapping paths:

```yaml
alb.ingress.kubernetes.io/group.order: '10'  # Higher priority
```

### 3. Enable HTTPS

Always use HTTPS in production:

```yaml
alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'
```

### 4. Configure Health Checks

Set appropriate health checks for your services:

```yaml
alb.ingress.kubernetes.io/healthcheck-path: /health
alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
```

### 5. Tag Resources

Tag ALBs for cost tracking and management:

```yaml
alb.ingress.kubernetes.io/tags: Environment=production,Team=platform,CostCenter=engineering
```

### 6. Use Target Type IP

For better integration with Kubernetes:

```yaml
alb.ingress.kubernetes.io/target-type: ip
```

## Terraform Integration

For using Terraform-managed ALBs with Kubernetes Ingress:

- **Terraform Configuration:** `terraform-alb-example.tf`
- **Kubernetes Example:** `08-terraform-managed-alb.yaml`
- **Complete Guide:** `TERRAFORM-ALB-INTEGRATION.md`

This approach allows you to manage ALB lifecycle with Terraform while dynamically adding/removing listener rules with Kubernetes Ingress.

## Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Terraform AWS ALB Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)

## Support

For issues or questions:
1. Check controller logs
2. Review AWS CloudWatch logs
3. Verify IAM permissions
4. Check security groups and network configuration
