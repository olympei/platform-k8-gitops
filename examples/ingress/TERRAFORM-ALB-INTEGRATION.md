# Using Terraform-Managed ALB with Kubernetes Ingress

## Overview

This guide shows how to use an Application Load Balancer (ALB) created by Terraform with Kubernetes Ingress resources managed by the AWS Load Balancer Controller. This approach allows you to:

- Manage ALB lifecycle with Terraform (infrastructure as code)
- Add/remove listener rules dynamically with Kubernetes Ingress
- Maintain separation between infrastructure and application routing

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Terraform                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  • Creates ALB                                         │ │
│  │  • Creates Listeners (HTTP/HTTPS)                      │ │
│  │  • Manages Security Groups                             │ │
│  │  • Sets default actions                                │ │
│  │  • Tags ALB with ingress.k8s.aws/stack                 │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              AWS Load Balancer Controller                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  • Discovers ALB by group name tag                     │ │
│  │  • Adds listener rules for Ingress resources           │ │
│  │  • Creates target groups                               │ │
│  │  • Manages target registration                         │ │
│  │  • Does NOT modify ALB itself                          │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Ingress                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  • References ALB by group name                        │ │
│  │  • Defines routing rules (host/path)                   │ │
│  │  • Configures health checks                            │ │
│  │  • Sets rule priorities                                │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **Terraform installed** (v1.0+)
2. **AWS Load Balancer Controller deployed** in Kubernetes
3. **ACM certificate** for HTTPS
4. **VPC and subnets** configured
5. **IAM permissions** for controller to modify listener rules

## Step 1: Create ALB with Terraform

### Terraform Configuration

See `terraform-alb-example.tf` for the complete configuration.

**Key Components:**

1. **Security Group:**
   - Allows inbound HTTP (80) and HTTPS (443)
   - Allows all outbound traffic

2. **ALB:**
   - Internet-facing or internal
   - Tagged with `ingress.k8s.aws/stack` (group name)
   - Tagged with cluster name

3. **Listeners:**
   - HTTPS listener with default 404 response
   - HTTP listener with redirect to HTTPS

### Critical Tags

```hcl
tags = {
  "ingress.k8s.aws/stack"    = "terraform-managed-alb"  # Group name
  "ingress.k8s.aws/resource" = "LoadBalancer"
  "elbv2.k8s.aws/cluster"    = "my-eks-cluster"         # Your cluster name
}
```

### Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file=terraform.tfvars

# Apply the configuration
terraform apply -var-file=terraform.tfvars

# Get outputs
terraform output alb_dns_name
terraform output ingress_group_name
```

### Example terraform.tfvars

```hcl
vpc_id            = "vpc-0123456789abcdef0"
public_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234-5678-90ab-cdef-1234567890ab"
environment       = "dev"
```

## Step 2: Verify ALB Creation

```bash
# Get ALB details
aws elbv2 describe-load-balancers \
  --names terraform-managed-alb-dev

# Verify tags
aws elbv2 describe-tags \
  --resource-arns <alb-arn> \
  --query 'TagDescriptions[0].Tags'

# Check listeners
aws elbv2 describe-listeners \
  --load-balancer-arn <alb-arn>
```

**Expected Tags:**
```json
[
  {
    "Key": "ingress.k8s.aws/stack",
    "Value": "terraform-managed-alb"
  },
  {
    "Key": "elbv2.k8s.aws/cluster",
    "Value": "my-eks-cluster"
  }
]
```

## Step 3: Create Kubernetes Ingress

### Basic Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: default
  annotations:
    # MUST match the Terraform tag: ingress.k8s.aws/stack
    alb.ingress.kubernetes.io/group.name: terraform-managed-alb
    
    # Must match ALB configuration
    alb.ingress.kubernetes.io/target-type: ip
    
    # Rule priority
    alb.ingress.kubernetes.io/group.order: '100'
spec:
  ingressClassName: alb
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
```

### Deploy Ingress

```bash
# Apply the Ingress
kubectl apply -f 08-terraform-managed-alb.yaml

# Check Ingress status
kubectl get ingress app-on-terraform-alb

# Verify it's using the Terraform ALB
kubectl get ingress app-on-terraform-alb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Step 4: Verify Integration

### Check Listener Rules

```bash
# Get HTTPS listener ARN
HTTPS_LISTENER_ARN=$(terraform output -raw https_listener_arn)

# List rules
aws elbv2 describe-rules \
  --listener-arn "$HTTPS_LISTENER_ARN" \
  --query 'Rules[*].[Priority,Conditions[0].Values[0]]' \
  --output table
```

**Expected Output:**
```
---------------------------------
|        DescribeRules          |
+----------+--------------------+
|  100     |  app.example.com   |
|  default |  N/A               |
+----------+--------------------+
```

### Check Target Groups

```bash
# List target groups
aws elbv2 describe-target-groups \
  --load-balancer-arn <alb-arn> \
  --query 'TargetGroups[*].[TargetGroupName,HealthCheckPath,Port]' \
  --output table
```

### Test Routing

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTP (should redirect to HTTPS)
curl -I http://$ALB_DNS -H "Host: app.example.com"

# Test HTTPS
curl https://$ALB_DNS -H "Host: app.example.com" -k
```

## Complete Example

### 1. Terraform Configuration

```hcl
# main.tf
resource "aws_lb" "main" {
  name               = "terraform-managed-alb-dev"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    "ingress.k8s.aws/stack"    = "terraform-managed-alb"
    "elbv2.k8s.aws/cluster"    = "my-eks-cluster"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}
```

### 2. Deploy with Terraform

```bash
terraform apply
```

### 3. Kubernetes Ingress

```yaml
# app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    alb.ingress.kubernetes.io/group.name: terraform-managed-alb
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
```

### 4. Deploy Ingress

```bash
kubectl apply -f app-ingress.yaml
```

## Important Considerations

### 1. Group Name Consistency

The group name MUST match between Terraform and Kubernetes:

**Terraform:**
```hcl
tags = {
  "ingress.k8s.aws/stack" = "terraform-managed-alb"
}
```

**Kubernetes:**
```yaml
annotations:
  alb.ingress.kubernetes.io/group.name: terraform-managed-alb
```

### 2. Target Type Consistency

The target type in Ingress must match the ALB configuration:

```yaml
annotations:
  alb.ingress.kubernetes.io/target-type: ip  # or instance
```

### 3. Listener Management

- Terraform creates listeners with default actions
- Controller adds rules to existing listeners
- Controller does NOT modify listener configuration

### 4. Certificate Management

Certificates are managed by Terraform:

```hcl
resource "aws_lb_listener" "https" {
  certificate_arn = var.certificate_arn
}
```

To add more certificates (SNI):

```hcl
resource "aws_lb_listener_certificate" "additional" {
  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = var.additional_certificate_arn
}
```

### 5. Security Groups

Security groups are managed by Terraform:

```hcl
resource "aws_security_group" "alb" {
  # ... configuration
}
```

The controller will NOT modify security groups.

## Troubleshooting

### Ingress Not Using Terraform ALB

**Check group name:**
```bash
# Terraform tag
aws elbv2 describe-tags --resource-arns <alb-arn> | grep "ingress.k8s.aws/stack"

# Ingress annotation
kubectl get ingress <name> -o yaml | grep group.name
```

**Verify they match exactly.**

### Rules Not Added to Listener

**Check controller logs:**
```bash
kubectl logs -n aws-load-balancer-controller \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  --tail=100
```

**Common issues:**
- Group name mismatch
- Missing cluster tag on ALB
- IAM permissions insufficient

### Target Groups Not Created

**Check IAM permissions:**
```bash
# Controller needs these permissions:
# - elasticloadbalancing:CreateTargetGroup
# - elasticloadbalancing:RegisterTargets
# - elasticloadbalancing:CreateRule
```

**Verify service exists:**
```bash
kubectl get svc <service-name>
kubectl get endpoints <service-name>
```

### Certificate Errors

**Verify certificate in listener:**
```bash
aws elbv2 describe-listeners \
  --listener-arn <listener-arn> \
  --query 'Listeners[0].Certificates'
```

**Check certificate status:**
```bash
aws acm describe-certificate \
  --certificate-arn <cert-arn> \
  --query 'Certificate.Status'
```

## Updating the ALB

### Terraform Changes

When updating ALB configuration with Terraform:

```bash
# Plan changes
terraform plan

# Apply changes
terraform apply
```

**Safe to update:**
- Tags (except group name)
- Security groups
- Subnets
- Listener certificates
- Default actions

**Requires coordination:**
- Changing group name (update Ingresses first)
- Deleting listeners (remove Ingresses first)

### Adding New Ingress

Simply create new Ingress with same group name:

```bash
kubectl apply -f new-ingress.yaml
```

The controller will automatically add rules to the existing ALB.

### Removing Ingress

```bash
kubectl delete ingress <name>
```

The controller will automatically remove rules from the ALB.

## Best Practices

### 1. Use Descriptive Group Names

```hcl
tags = {
  "ingress.k8s.aws/stack" = "production-public-alb"
}
```

### 2. Document Group Name

```yaml
metadata:
  annotations:
    alb.ingress.kubernetes.io/group.name: production-public-alb
    description: "Uses Terraform-managed ALB for production"
```

### 3. Set Rule Priorities

```yaml
annotations:
  alb.ingress.kubernetes.io/group.order: '10'  # Higher priority
```

### 4. Tag Resources

```hcl
tags = {
  Environment = "production"
  ManagedBy   = "terraform"
  Team        = "platform"
}
```

### 5. Use Terraform Outputs

```hcl
output "ingress_group_name" {
  value = "terraform-managed-alb"
}
```

Reference in documentation or CI/CD.

### 6. Monitor Both Layers

- **Terraform:** ALB, listeners, security groups
- **Kubernetes:** Ingress, target groups, rules

## Migration Strategy

### From Controller-Managed to Terraform-Managed

1. **Export existing ALB configuration:**
   ```bash
   aws elbv2 describe-load-balancers --names <alb-name>
   ```

2. **Create Terraform configuration** matching existing ALB

3. **Import ALB into Terraform:**
   ```bash
   terraform import aws_lb.main <alb-arn>
   terraform import aws_lb_listener.https <listener-arn>
   ```

4. **Update Ingress annotations** (no changes needed if group name matches)

5. **Verify** rules still work

### From Terraform-Managed to Controller-Managed

1. **Remove Terraform resources:**
   ```bash
   terraform destroy -target=aws_lb.main
   ```

2. **Update Ingress** to let controller create ALB:
   ```yaml
   annotations:
     alb.ingress.kubernetes.io/scheme: internet-facing
     # Remove or change group.name
   ```

3. **Apply Ingress:**
   ```bash
   kubectl apply -f ingress.yaml
   ```

## References

- [AWS Load Balancer Controller - IngressGroup](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/#ingressgroup)
- [Terraform AWS ALB](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)
- [AWS ALB Tagging](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-tags.html)
