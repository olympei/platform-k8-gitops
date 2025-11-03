# AWS Load Balancer Controller Usage Guide

The AWS Load Balancer Controller manages AWS Elastic Load Balancers for Kubernetes clusters. It provisions:
- **Application Load Balancers (ALB)** for Kubernetes Ingress resources
- **Network Load Balancers (NLB)** for Kubernetes Service resources with type LoadBalancer

## Prerequisites

1. **EKS Cluster** with version 1.19 or later
2. **IAM Role** with required permissions (created via Terraform)
3. **VPC** with properly tagged subnets
4. **Pod Identity** or **IRSA** configured

## Subnet Tagging Requirements

For the controller to auto-discover subnets, tag them appropriately:

### Public Subnets (for internet-facing load balancers):
```
kubernetes.io/role/elb = 1
kubernetes.io/cluster/<cluster-name> = owned|shared
```

### Private Subnets (for internal load balancers):
```
kubernetes.io/role/internal-elb = 1
kubernetes.io/cluster/<cluster-name> = owned|shared
```

## Configuration

### 1. Update values files

**Dev environment** (`charts/aws-load-balancer-controller/values-dev.yaml`):
```yaml
aws-load-balancer-controller:
  clusterName: "my-eks-cluster-dev"
  region: "us-east-1"
  vpcId: "vpc-xxxxx"
  
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-dev"
```

**Prod environment** (`charts/aws-load-balancer-controller/values-prod.yaml`):
```yaml
aws-load-balancer-controller:
  clusterName: "my-eks-cluster-prod"
  region: "us-east-1"
  vpcId: "vpc-xxxxx"
  
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-prod"
```

### 2. Deploy via GitLab CI/CD

Enable in CI/CD variables:
```bash
INSTALL_AWS_LOAD_BALANCER_CONTROLLER=true
```

Or deploy manually:
```bash
helm upgrade --install platform-aws-load-balancer-controller \
  charts/aws-load-balancer-controller \
  -n kube-system \
  -f charts/aws-load-balancer-controller/values-prod.yaml
```

## Usage Examples

### Example 1: Internet-Facing ALB with Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: default
  annotations:
    # Specify ALB ingress class
    kubernetes.io/ingress.class: alb
    
    # ALB scheme
    alb.ingress.kubernetes.io/scheme: internet-facing
    
    # Target type (ip or instance)
    alb.ingress.kubernetes.io/target-type: ip
    
    # Health check configuration
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    
    # SSL/TLS configuration
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxxxx
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    
    # Tags
    alb.ingress.kubernetes.io/tags: Environment=prod,Team=platform
spec:
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

### Example 2: Internal ALB

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: internal-app-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    
    # Specify subnets (optional, auto-discovered if tagged)
    alb.ingress.kubernetes.io/subnets: subnet-xxxxx,subnet-yyyyy
    
    # Security groups
    alb.ingress.kubernetes.io/security-groups: sg-xxxxx
spec:
  rules:
    - host: internal.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: internal-service
                port:
                  number: 8080
```

### Example 3: NLB with Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nlb-service
  namespace: default
  annotations:
    # Use NLB
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    
    # Scheme
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    
    # Cross-zone load balancing
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    
    # Health check
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol: "HTTP"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/health"
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "8080"
    
    # Tags
    service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "Environment=prod,Team=platform"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
```

### Example 4: Internal NLB

```yaml
apiVersion: v1
kind: Service
metadata:
  name: internal-nlb-service
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "ip"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"
    
    # Specify subnets
    service.beta.kubernetes.io/aws-load-balancer-subnets: subnet-xxxxx,subnet-yyyyy
spec:
  type: LoadBalancer
  selector:
    app: internal-app
  ports:
    - protocol: TCP
      port: 443
      targetPort: 8443
```

### Example 5: ALB with WAF

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: waf-protected-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    
    # Associate WAF WebACL
    alb.ingress.kubernetes.io/wafv2-acl-arn: arn:aws:wafv2:us-east-1:123456789012:regional/webacl/my-webacl/xxxxx
    
    # Enable Shield Advanced (requires subscription)
    alb.ingress.kubernetes.io/shield-advanced-protection: "true"
spec:
  rules:
    - host: secure.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: secure-service
                port:
                  number: 80
```

### Example 6: Multiple Target Groups (Advanced)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-target-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    
    # Group multiple ingresses into single ALB
    alb.ingress.kubernetes.io/group.name: my-app-group
    alb.ingress.kubernetes.io/group.order: '10'
    
    # Actions for different paths
    alb.ingress.kubernetes.io/actions.forward-multiple: |
      {
        "type": "forward",
        "forwardConfig": {
          "targetGroups": [
            {
              "serviceName": "service-a",
              "servicePort": "80",
              "weight": 70
            },
            {
              "serviceName": "service-b",
              "servicePort": "80",
              "weight": 30
            }
          ]
        }
      }
spec:
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: forward-multiple
                port:
                  name: use-annotation
```

## Common Annotations

### ALB Ingress Annotations

| Annotation | Description | Example |
|------------|-------------|---------|
| `alb.ingress.kubernetes.io/scheme` | Load balancer scheme | `internet-facing` or `internal` |
| `alb.ingress.kubernetes.io/target-type` | Target type | `ip` or `instance` |
| `alb.ingress.kubernetes.io/certificate-arn` | ACM certificate ARN | `arn:aws:acm:...` |
| `alb.ingress.kubernetes.io/ssl-redirect` | Redirect HTTP to HTTPS | `443` |
| `alb.ingress.kubernetes.io/listen-ports` | Listener ports | `[{"HTTP": 80}, {"HTTPS": 443}]` |
| `alb.ingress.kubernetes.io/subnets` | Subnet IDs | `subnet-xxx,subnet-yyy` |
| `alb.ingress.kubernetes.io/security-groups` | Security group IDs | `sg-xxx,sg-yyy` |
| `alb.ingress.kubernetes.io/wafv2-acl-arn` | WAF WebACL ARN | `arn:aws:wafv2:...` |
| `alb.ingress.kubernetes.io/group.name` | Ingress group name | `my-group` |
| `alb.ingress.kubernetes.io/healthcheck-path` | Health check path | `/health` |
| `alb.ingress.kubernetes.io/tags` | Resource tags | `Env=prod,Team=platform` |

### NLB Service Annotations

| Annotation | Description | Example |
|------------|-------------|---------|
| `service.beta.kubernetes.io/aws-load-balancer-type` | Load balancer type | `external` or `internal` |
| `service.beta.kubernetes.io/aws-load-balancer-nlb-target-type` | Target type | `ip` or `instance` |
| `service.beta.kubernetes.io/aws-load-balancer-scheme` | Scheme | `internet-facing` or `internal` |
| `service.beta.kubernetes.io/aws-load-balancer-subnets` | Subnet IDs | `subnet-xxx,subnet-yyy` |
| `service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled` | Cross-zone LB | `true` or `false` |
| `service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol` | Health check protocol | `HTTP` or `TCP` |
| `service.beta.kubernetes.io/aws-load-balancer-healthcheck-path` | Health check path | `/health` |

## Verification

### Check Controller Status

```bash
# Check controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Check webhook
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
```

### Check Load Balancers

```bash
# List ingresses
kubectl get ingress -A

# Describe ingress
kubectl describe ingress my-app-ingress -n default

# List services with load balancers
kubectl get svc -A --field-selector spec.type=LoadBalancer

# Check ALB in AWS
aws elbv2 describe-load-balancers --region us-east-1

# Check target groups
aws elbv2 describe-target-groups --region us-east-1
```

## Troubleshooting

### Controller Not Creating Load Balancers

1. **Check controller logs:**
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   ```

2. **Verify IAM permissions:**
   ```bash
   # Check service account annotation
   kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
   ```

3. **Check subnet tags:**
   ```bash
   aws ec2 describe-subnets --subnet-ids subnet-xxxxx --region us-east-1
   ```

### Ingress Not Working

1. **Check ingress events:**
   ```bash
   kubectl describe ingress my-app-ingress -n default
   ```

2. **Verify target health:**
   ```bash
   # Get target group ARN from ingress
   kubectl get ingress my-app-ingress -n default -o yaml
   
   # Check target health in AWS
   aws elbv2 describe-target-health --target-group-arn <arn>
   ```

3. **Check security groups:**
   - Ensure ALB security group allows inbound traffic
   - Ensure pod security group allows traffic from ALB

### Webhook Errors

```bash
# Check webhook configuration
kubectl get validatingwebhookconfigurations aws-load-balancer-webhook

# Delete and recreate if needed
kubectl delete validatingwebhookconfigurations aws-load-balancer-webhook
kubectl delete mutatingwebhookconfigurations aws-load-balancer-webhook

# Restart controller
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
```

## Best Practices

1. **Use IP target type** for better pod-to-pod communication
2. **Tag subnets properly** for auto-discovery
3. **Use ingress groups** to share ALBs across multiple ingresses
4. **Enable WAF** for internet-facing applications
5. **Use ACM certificates** for SSL/TLS termination
6. **Set appropriate health checks** for your applications
7. **Use internal load balancers** for internal services
8. **Monitor costs** - each ALB/NLB has hourly charges

## Cost Optimization

- **Share ALBs** using ingress groups instead of creating one per ingress
- **Use NLB** only when needed (TCP/UDP traffic, static IPs)
- **Delete unused load balancers** by removing ingress/service resources
- **Use internal load balancers** when external access isn't needed

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ALB Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.8/guide/ingress/annotations/)
- [NLB Service Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.8/guide/service/annotations/)
