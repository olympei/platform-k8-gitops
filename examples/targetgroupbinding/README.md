# TargetGroupBinding Examples

## Overview

TargetGroupBinding is a Custom Resource Definition (CRD) provided by the AWS Load Balancer Controller that allows you to bind Kubernetes Services directly to existing AWS Target Groups. This provides more flexibility than Ingress resources and enables advanced use cases.

## When to Use TargetGroupBinding

### Use TargetGroupBinding When:
- You have existing ALB/NLB created outside Kubernetes (Terraform, CloudFormation, Console)
- You need fine-grained control over target group configuration
- You want to share target groups across multiple clusters
- You need to integrate with non-Kubernetes targets (EC2, Lambda, IP addresses)
- You're migrating from EC2-based deployments to Kubernetes gradually

### Use Ingress When:
- You want the controller to manage the entire ALB lifecycle
- You need simple host/path-based routing
- You prefer declarative Kubernetes-native configuration

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Existing AWS Resources                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  • ALB/NLB (created by Terraform/CloudFormation)       │ │
│  │  • Target Group (empty or with existing targets)       │ │
│  │  • Listener Rules                                      │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              AWS Load Balancer Controller                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  • Watches TargetGroupBinding resources               │ │
│  │  • Discovers pods from Service selector                │ │
│  │  • Registers pod IPs to Target Group                   │ │
│  │  • Manages target health                               │ │
│  │  • Handles pod lifecycle (add/remove targets)          │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  TargetGroupBinding CRD                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  • References Target Group ARN                         │ │
│  │  • References Kubernetes Service                       │ │
│  │  • Specifies target type (ip/instance)                 │ │
│  │  • Configures networking mode                          │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Service & Pods                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  • Service selects pods                                │ │
│  │  • Pods registered as targets                          │ │
│  │  • Traffic flows directly from ALB/NLB to pods         │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Examples in This Directory

### 1. Basic TargetGroupBinding (`01-basic-targetgroupbinding.yaml`)
Simple binding of a Kubernetes Service to an existing Target Group

### 2. Terraform-Managed ALB with TargetGroupBinding (`02-terraform-alb-targetgroupbinding.yaml`)
Complete example using Terraform to create ALB and Target Groups, then binding Kubernetes Services

### 3. Multi-Port Service (`03-multi-port-targetgroupbinding.yaml`)
Binding multiple ports from a single Service to different Target Groups

### 4. Instance Mode (`04-instance-mode-targetgroupbinding.yaml`)
Using instance target type instead of IP mode

### 5. Blue-Green Deployment (`05-blue-green-deployment.yaml`)
Using TargetGroupBinding for blue-green deployments with traffic shifting

### 6. Cross-Cluster Target Group (`06-cross-cluster-targetgroupbinding.yaml`)
Sharing a Target Group across multiple Kubernetes clusters

## Prerequisites

1. **AWS Load Balancer Controller installed** with TargetGroupBinding CRD
2. **Existing Target Group** created in AWS
3. **IAM permissions** for controller to register/deregister targets
4. **Network connectivity** between ALB/NLB and pods

## Quick Start

### 1. Verify CRD Installation

```bash
kubectl get crd targetgroupbindings.elbv2.k8s.aws
```

### 2. Create Target Group (AWS CLI or Terraform)

```bash
# Create target group
aws elbv2 create-target-group \
  --name my-k8s-app-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-xxxxx \
  --target-type ip \
  --health-check-path /health

# Get Target Group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names my-k8s-app-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo $TG_ARN
```

### 3. Create Kubernetes Service

```bash
kubectl create deployment my-app --image=nginx
kubectl expose deployment my-app --port=80 --target-port=80
```

### 4. Create TargetGroupBinding

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: my-app-tgb
  namespace: default
spec:
  serviceRef:
    name: my-app
    port: 80
  targetGroupARN: arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/my-k8s-app-tg/xxxxx
  targetType: ip
```

### 5. Verify Binding

```bash
# Check TargetGroupBinding status
kubectl get targetgroupbinding my-app-tgb

# Check targets in AWS
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN
```

## Common Use Cases

### Use Case 1: Terraform-Managed Infrastructure

**Scenario:** Infrastructure team manages ALB with Terraform, application team deploys to Kubernetes

**Solution:**
1. Terraform creates ALB, listeners, and target groups
2. Terraform outputs target group ARNs
3. Application team creates TargetGroupBinding referencing the ARN
4. Controller automatically registers pods

**Benefits:**
- Clear separation of concerns
- Infrastructure as code
- No Kubernetes access needed for infrastructure changes

### Use Case 2: Gradual Migration

**Scenario:** Migrating from EC2-based application to Kubernetes

**Solution:**
1. Existing ALB points to EC2 target group
2. Create new target group for Kubernetes pods
3. Create TargetGroupBinding
4. Gradually shift traffic using weighted target groups
5. Decommission EC2 instances

**Benefits:**
- Zero-downtime migration
- Easy rollback
- Gradual traffic shifting

### Use Case 3: Multi-Cluster Setup

**Scenario:** Multiple Kubernetes clusters serving the same application

**Solution:**
1. Single ALB with one target group
2. TargetGroupBinding in each cluster pointing to same target group
3. Pods from all clusters registered as targets
4. ALB distributes traffic across all clusters

**Benefits:**
- High availability across clusters
- Simplified load balancing
- Cost optimization

### Use Case 4: Hybrid Targets

**Scenario:** Mix of Kubernetes pods and EC2 instances behind same ALB

**Solution:**
1. Target group with both EC2 and IP targets
2. EC2 instances registered manually or via Auto Scaling
3. TargetGroupBinding registers Kubernetes pods
4. ALB distributes traffic to both

**Benefits:**
- Gradual modernization
- Flexibility during migration
- Support for legacy components

## Comparison: Ingress vs TargetGroupBinding

| Feature | Ingress | TargetGroupBinding |
|---------|---------|-------------------|
| **ALB Management** | Controller creates/manages | Use existing ALB |
| **Target Group** | Controller creates | Use existing TG |
| **Routing Rules** | Defined in Ingress | Defined in ALB |
| **Terraform Integration** | Limited | Excellent |
| **Multi-Cluster** | Difficult | Easy |
| **Hybrid Targets** | Not supported | Supported |
| **Complexity** | Lower | Higher |
| **Flexibility** | Lower | Higher |
| **Best For** | New deployments | Existing infrastructure |

## Troubleshooting

### TargetGroupBinding Not Working

```bash
# Check TargetGroupBinding status
kubectl describe targetgroupbinding <name>

# Check controller logs
kubectl logs -n aws-load-balancer-controller \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  --tail=100 | grep -i targetgroup

# Verify service exists
kubectl get svc <service-name>

# Check endpoints
kubectl get endpoints <service-name>
```

### Targets Not Registered

**Common causes:**
1. Target Group ARN incorrect
2. Target type mismatch (ip vs instance)
3. VPC/subnet mismatch
4. Security group blocking traffic
5. IAM permissions missing

**Verify:**
```bash
# Check target group details
aws elbv2 describe-target-groups \
  --target-group-arns <arn>

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <arn>

# Check security groups
aws ec2 describe-security-groups \
  --group-ids <sg-id>
```

### Targets Unhealthy

```bash
# Check health check configuration
aws elbv2 describe-target-groups \
  --target-group-arns <arn> \
  --query 'TargetGroups[0].HealthCheckPath'

# Test health check from pod
kubectl exec <pod-name> -- curl localhost:<port>/health

# Check pod logs
kubectl logs <pod-name>
```

## Best Practices

### 1. Use Descriptive Names

```yaml
metadata:
  name: production-api-tgb
  labels:
    app: api
    environment: production
```

### 2. Match Target Types

Ensure target type in TargetGroupBinding matches Target Group:

```yaml
spec:
  targetType: ip  # Must match TG configuration
```

### 3. Configure Health Checks

Set appropriate health checks in Target Group:

```bash
aws elbv2 modify-target-group \
  --target-group-arn <arn> \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2
```

### 4. Use Networking Mode

For better performance with IP mode:

```yaml
spec:
  networking:
    ingress:
      - from:
          - securityGroup:
              groupID: sg-xxxxx
        ports:
          - protocol: TCP
            port: 80
```

### 5. Monitor Target Health

```bash
# Create CloudWatch alarm
aws cloudwatch put-metric-alarm \
  --alarm-name unhealthy-targets \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold
```

### 6. Tag Resources

```bash
aws elbv2 add-tags \
  --resource-arns <tg-arn> \
  --tags Key=kubernetes.io/service-name,Value=my-app \
         Key=kubernetes.io/namespace,Value=default
```

## Additional Resources

- [TargetGroupBinding CRD Reference](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/targetgroupbinding/targetgroupbinding/)
- [AWS Target Groups Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html)
- [Controller IAM Permissions](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)

