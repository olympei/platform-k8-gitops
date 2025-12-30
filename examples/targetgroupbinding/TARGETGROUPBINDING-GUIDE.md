# TargetGroupBinding Complete Guide

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Configuration Reference](#configuration-reference)
- [Use Cases](#use-cases)
- [Terraform Integration](#terraform-integration)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

TargetGroupBinding is a Custom Resource Definition (CRD) provided by the AWS Load Balancer Controller that enables direct binding of Kubernetes Services to AWS Target Groups. This provides greater flexibility than Ingress resources and enables advanced deployment patterns.

### Key Benefits

1. **Infrastructure Separation**: Infrastructure team manages ALB/NLB with Terraform, application team manages Kubernetes deployments
2. **Existing Infrastructure**: Use existing load balancers created outside Kubernetes
3. **Advanced Patterns**: Enable blue-green deployments, canary releases, and multi-cluster setups
4. **Hybrid Deployments**: Mix Kubernetes pods with EC2 instances or Lambda functions in same target group
5. **Fine-Grained Control**: Direct control over target registration and health checks

### When to Use

**Use TargetGroupBinding when:**
- You have existing ALB/NLB infrastructure managed by Terraform or CloudFormation
- You need to share load balancers across multiple clusters
- You want to implement blue-green or canary deployments
- You need to integrate Kubernetes with non-Kubernetes targets
- You require fine-grained control over target group configuration

**Use Ingress when:**
- You want the controller to manage the entire ALB lifecycle
- You need simple host/path-based routing
- You prefer fully declarative Kubernetes-native configuration
- You're starting fresh without existing infrastructure

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      AWS Infrastructure                           │
│                                                                   │
│  ┌────────────────┐         ┌──────────────────┐                │
│  │  ALB/NLB       │────────▶│  Target Group    │                │
│  │  (Terraform)   │         │  (Terraform)     │                │
│  └────────────────┘         └──────────────────┘                │
│         │                            ▲                            │
│         │                            │                            │
│         │                            │ Register/Deregister        │
│         │                            │ Targets                    │
└─────────┼────────────────────────────┼────────────────────────────┘
          │                            │
          │ Traffic                    │
          │                            │
┌─────────▼────────────────────────────┼────────────────────────────┐
│                    Kubernetes Cluster                             │
│                                      │                            │
│  ┌──────────────────────────────────┼──────────────────────────┐ │
│  │  AWS Load Balancer Controller    │                          │ │
│  │                                   │                          │ │
│  │  • Watches TargetGroupBinding ───┘                          │ │
│  │  • Discovers pods via Service selector                      │ │
│  │  • Registers pod IPs to Target Group                        │ │
│  │  • Manages target health                                    │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                      │                            │
│  ┌──────────────────────────────────▼──────────────────────────┐ │
│  │  TargetGroupBinding CRD                                     │ │
│  │                                                              │ │
│  │  spec:                                                       │ │
│  │    serviceRef:                                               │ │
│  │      name: my-service                                        │ │
│  │      port: 80                                                │ │
│  │    targetGroupARN: arn:aws:...                               │ │
│  │    targetType: ip                                            │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                      │                            │
│  ┌──────────────────────────────────▼──────────────────────────┐ │
│  │  Service                                                     │ │
│  │  selector: app=myapp                                         │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                      │                            │
│  ┌──────────────────────────────────▼──────────────────────────┐ │
│  │  Pods (app=myapp)                                            │ │
│  │  • Pod 1: 10.0.1.10:80                                       │ │
│  │  • Pod 2: 10.0.1.11:80                                       │ │
│  │  • Pod 3: 10.0.1.12:80                                       │ │
│  └──────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required

1. **AWS Load Balancer Controller** installed in your cluster
   ```bash
   kubectl get deployment -n aws-load-balancer-controller aws-load-balancer-controller
   ```

2. **TargetGroupBinding CRD** installed
   ```bash
   kubectl get crd targetgroupbindings.elbv2.k8s.aws
   ```

3. **Existing Target Group** in AWS
   ```bash
   aws elbv2 describe-target-groups --names my-target-group
   ```

4. **IAM Permissions** for the controller:
   - `elasticloadbalancing:RegisterTargets`
   - `elasticloadbalancing:DeregisterTargets`
   - `elasticloadbalancing:DescribeTargetGroups`
   - `elasticloadbalancing:DescribeTargetHealth`
   - `elasticloadbalancing:ModifyTargetGroup`
   - `elasticloadbalancing:ModifyTargetGroupAttributes`

5. **Network Connectivity** between ALB/NLB and pods

### Optional

- **Terraform** for infrastructure management
- **VPC CNI** for IP mode (or any CNI for instance mode)
- **Security Groups** properly configured

## Getting Started

### Step 1: Create Target Group

Using AWS CLI:

```bash
# Create target group with IP target type
aws elbv2 create-target-group \
  --name my-app-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-xxxxx \
  --target-type ip \
  --health-check-enabled \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --matcher HttpCode=200-299 \
  --tags Key=kubernetes.io/service-name,Value=my-app \
         Key=kubernetes.io/namespace,Value=default

# Get the Target Group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names my-app-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Target Group ARN: $TG_ARN"
```

Using Terraform:

```hcl
resource "aws_lb_target_group" "app" {
  name_prefix = "app-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  tags = {
    "kubernetes.io/service-name" = "my-app"
    "kubernetes.io/namespace"    = "default"
  }
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}
```

### Step 2: Create Kubernetes Resources

```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: nginx:alpine
          ports:
            - containerPort: 80
          livenessProbe:
            httpGet:
              path: /health
              port: 80
          readinessProbe:
            httpGet:
              path: /health
              port: 80

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP

---
# TargetGroupBinding
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: my-app-tgb
  namespace: default
spec:
  serviceRef:
    name: my-app
    port: 80
  targetGroupARN: <TARGET_GROUP_ARN_FROM_STEP_1>
  targetType: ip
```

### Step 3: Apply and Verify

```bash
# Apply the manifests
kubectl apply -f my-app.yaml

# Check TargetGroupBinding status
kubectl get targetgroupbinding my-app-tgb
kubectl describe targetgroupbinding my-app-tgb

# Verify targets registered in AWS
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --query 'TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]' \
  --output table

# Check controller logs
kubectl logs -n aws-load-balancer-controller \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  --tail=50 | grep -i targetgroup
```

## Configuration Reference

### TargetGroupBinding Spec

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: my-tgb
  namespace: default
spec:
  # Required: Reference to Kubernetes Service
  serviceRef:
    name: my-service      # Service name
    port: 80              # Service port (number or name)
  
  # Required: ARN of the Target Group
  targetGroupARN: arn:aws:elasticloadbalancing:region:account:targetgroup/name/id
  
  # Required: Target type (must match Target Group)
  targetType: ip          # Options: ip, instance
  
  # Optional: Node selector for instance mode
  nodeSelector:
    matchLabels:
      node-type: application
      kubernetes.io/role: worker
  
  # Optional: Networking configuration
  networking:
    ingress:
      - from:
          - securityGroup:
              groupID: sg-xxxxx
          - ipBlock:
              cidr: 10.0.0.0/8
        ports:
          - protocol: TCP
            port: 80
  
  # Optional: IP address type
  ipAddressType: ipv4     # Options: ipv4, ipv6, dualstack
  
  # Optional: VPC ID (auto-detected if not specified)
  vpcID: vpc-xxxxx
```

### Target Types

#### IP Mode (Recommended)

**Characteristics:**
- Targets are pod IP addresses
- Works with ClusterIP services
- Direct pod-to-ALB communication
- Requires VPC CNI or compatible networking
- Better performance (no extra hop)

**Configuration:**
```yaml
spec:
  targetType: ip
  serviceRef:
    name: my-service
    port: 80

# Service must be ClusterIP
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
```

**Target Group:**
```bash
aws elbv2 create-target-group \
  --target-type ip \
  --port 80 \
  --protocol HTTP \
  --vpc-id vpc-xxxxx
```

#### Instance Mode

**Characteristics:**
- Targets are EC2 instances (nodes)
- Works with NodePort services
- Compatible with any CNI
- Extra network hop (node -> pod)
- Limited by NodePort range (30000-32767)

**Configuration:**
```yaml
spec:
  targetType: instance
  serviceRef:
    name: my-service
    port: 80

# Service must be NodePort
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080  # Optional
```

**Target Group:**
```bash
aws elbv2 create-target-group \
  --target-type instance \
  --port 30080 \
  --protocol HTTP \
  --vpc-id vpc-xxxxx
```

### Networking Configuration

Control which sources can access your pods:

```yaml
spec:
  networking:
    ingress:
      # Allow from specific security group (ALB)
      - from:
          - securityGroup:
              groupID: sg-alb-xxxxx
        ports:
          - protocol: TCP
            port: 80
      
      # Allow from IP range
      - from:
          - ipBlock:
              cidr: 10.0.0.0/16
        ports:
          - protocol: TCP
            port: 80
      
      # Allow from multiple sources
      - from:
          - securityGroup:
              groupID: sg-xxxxx
          - ipBlock:
              cidr: 192.168.0.0/16
        ports:
          - protocol: TCP
            port: 80
          - protocol: TCP
            port: 443
```

## Use Cases

### 1. Terraform-Managed Infrastructure

**Scenario:** Infrastructure team manages ALB with Terraform, application team deploys to Kubernetes.

**Benefits:**
- Clear separation of concerns
- Infrastructure as code
- No Kubernetes access needed for infrastructure changes

**Implementation:** See `02-terraform-alb-targetgroupbinding.yaml` and `terraform-targetgroupbinding.tf`

### 2. Blue-Green Deployments

**Scenario:** Deploy new version alongside old version, switch traffic instantly.

**Benefits:**
- Zero-downtime deployments
- Instant rollback capability
- Test new version before switching

**Implementation:** See `05-blue-green-deployment.yaml`

### 3. Multi-Cluster Setup

**Scenario:** Multiple Kubernetes clusters serving the same application.

**Benefits:**
- High availability across clusters
- Disaster recovery
- Geographic distribution

**Implementation:** See `06-cross-cluster-targetgroupbinding.yaml`

### 4. Gradual Migration

**Scenario:** Migrating from EC2-based application to Kubernetes.

**Process:**
1. Existing ALB points to EC2 target group
2. Create new target group for Kubernetes
3. Create TargetGroupBinding
4. Use weighted target groups to shift traffic gradually
5. Decommission EC2 instances

### 5. Hybrid Deployments

**Scenario:** Mix Kubernetes pods with EC2 instances or Lambda functions.

**Configuration:**
- Target group with mixed target types
- EC2 instances registered manually
- Kubernetes pods registered via TargetGroupBinding
- Lambda functions registered via console/API

## Terraform Integration

### Complete Example

See `terraform-targetgroupbinding.tf` for a complete Terraform configuration that creates:
- Application Load Balancer
- Target Groups for multiple services
- Listeners with routing rules
- Security Groups
- Outputs for use in Kubernetes manifests

### Workflow

1. **Terraform creates infrastructure:**
   ```bash
   terraform apply
   terraform output target_group_arn
   ```

2. **Update Kubernetes manifest with ARN:**
   ```yaml
   spec:
     targetGroupARN: <output_from_terraform>
   ```

3. **Deploy to Kubernetes:**
   ```bash
   kubectl apply -f app.yaml
   ```

4. **Verify integration:**
   ```bash
   aws elbv2 describe-target-health --target-group-arn <arn>
   ```

### Terraform Outputs

```hcl
output "targetgroupbinding_config" {
  description = "Configuration for TargetGroupBinding"
  value = {
    target_group_arn      = aws_lb_target_group.app.arn
    alb_security_group_id = aws_security_group.alb.id
    alb_dns_name          = aws_lb.main.dns_name
  }
}
```

Use in CI/CD:
```bash
# Get ARN from Terraform
TG_ARN=$(terraform output -raw target_group_arn)

# Update Kubernetes manifest
sed -i "s|TARGET_GROUP_ARN|$TG_ARN|g" app.yaml

# Deploy
kubectl apply -f app.yaml
```

## Troubleshooting

### TargetGroupBinding Not Working

**Symptoms:**
- TargetGroupBinding created but no targets registered
- Status shows errors

**Diagnosis:**
```bash
# Check TargetGroupBinding status
kubectl describe targetgroupbinding <name>

# Check controller logs
kubectl logs -n aws-load-balancer-controller \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  --tail=100 | grep -i "targetgroup\|error"

# Verify service exists
kubectl get svc <service-name>
kubectl get endpoints <service-name>
```

**Common Causes:**
1. **Incorrect Target Group ARN**
   - Verify ARN is correct
   - Check region matches

2. **Target Type Mismatch**
   - TargetGroupBinding `targetType` must match Target Group configuration
   - IP mode requires ClusterIP service
   - Instance mode requires NodePort service

3. **IAM Permissions Missing**
   - Controller needs permissions to register targets
   - Check IAM role/policy

4. **Service Has No Endpoints**
   - Pods not ready
   - Selector doesn't match pods

### Targets Not Healthy

**Symptoms:**
- Targets registered but showing unhealthy
- ALB returns 502/503 errors

**Diagnosis:**
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <arn>

# Check health check configuration
aws elbv2 describe-target-groups \
  --target-group-arns <arn> \
  --query 'TargetGroups[0].HealthCheckPath'

# Test health check from pod
kubectl exec <pod-name> -- curl -v localhost:<port>/health

# Check pod logs
kubectl logs <pod-name>
```

**Common Causes:**
1. **Health Check Path Wrong**
   - Update target group health check path
   - Ensure application responds on health check path

2. **Security Groups Blocking Traffic**
   - ALB security group must allow outbound to pods
   - Pod security group must allow inbound from ALB

3. **Application Not Ready**
   - Check readiness probe
   - Verify application is listening on correct port

4. **Network Issues**
   - Verify VPC configuration
   - Check subnet routing

### Targets Not Deregistering

**Symptoms:**
- Deleted pods still showing as targets
- Draining targets not removed

**Diagnosis:**
```bash
# Check target health (look for draining)
aws elbv2 describe-target-health --target-group-arn <arn>

# Check deregistration delay
aws elbv2 describe-target-group-attributes \
  --target-group-arn <arn> \
  --query 'Attributes[?Key==`deregistration_delay.timeout_seconds`]'
```

**Solution:**
- Wait for deregistration delay to expire
- Reduce deregistration delay if too long:
  ```bash
  aws elbv2 modify-target-group-attributes \
    --target-group-arn <arn> \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30
  ```

## Best Practices

### 1. Use Descriptive Names

```yaml
metadata:
  name: production-api-tgb
  labels:
    app: api
    environment: production
    team: backend
```

### 2. Match Target Types

Ensure consistency between Target Group and TargetGroupBinding:

```yaml
# Target Group: target-type=ip
spec:
  targetType: ip  # Must match
```

### 3. Configure Appropriate Health Checks

```bash
aws elbv2 modify-target-group \
  --target-group-arn <arn> \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3
```

### 4. Use Networking Configuration

Restrict access to pods:

```yaml
spec:
  networking:
    ingress:
      - from:
          - securityGroup:
              groupID: sg-alb-xxxxx
        ports:
          - protocol: TCP
            port: 80
```

### 5. Tag Resources

```bash
aws elbv2 add-tags \
  --resource-arns <tg-arn> \
  --tags \
    Key=kubernetes.io/service-name,Value=my-app \
    Key=kubernetes.io/namespace,Value=default \
    Key=environment,Value=production \
    Key=managed-by,Value=kubernetes
```

### 6. Monitor Target Health

```bash
# Create CloudWatch alarm
aws cloudwatch put-metric-alarm \
  --alarm-name unhealthy-targets-my-app \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=TargetGroup,Value=targetgroup/my-app-tg/xxxxx \
  --evaluation-periods 2
```

### 7. Set Deregistration Delay

Balance between connection draining and deployment speed:

```bash
# 30 seconds for fast deployments
aws elbv2 modify-target-group-attributes \
  --target-group-arn <arn> \
  --attributes Key=deregistration_delay.timeout_seconds,Value=30
```

### 8. Use Infrastructure as Code

Manage Target Groups with Terraform:
- Version control
- Reproducible infrastructure
- Easy rollback
- Documentation

### 9. Implement Proper Readiness Probes

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

### 10. Document ARN Sources

```yaml
metadata:
  annotations:
    targetgroup-arn-source: "terraform output web_target_group_arn"
    terraform-workspace: "production"
    last-updated: "2025-12-30"
```

## Additional Resources

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [TargetGroupBinding CRD Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/targetgroupbinding/targetgroupbinding/)
- [AWS Target Groups Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

