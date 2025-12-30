# TargetGroupBinding Examples - Complete Summary

## Overview

Created comprehensive TargetGroupBinding examples and documentation in the `examples/targetgroupbinding/` directory. TargetGroupBinding is a CRD that allows direct binding of Kubernetes Services to AWS Target Groups, enabling advanced deployment patterns and integration with existing infrastructure.

## Files Created

### Documentation

1. **examples/targetgroupbinding/README.md**
   - Overview of TargetGroupBinding and when to use it
   - Architecture diagrams
   - Complete list of all examples with descriptions
   - Prerequisites and quick start guide
   - Common use cases and comparison with Ingress
   - Troubleshooting guide
   - Best practices

2. **examples/targetgroupbinding/TARGETGROUPBINDING-GUIDE.md** (400+ lines)
   - Complete technical guide
   - Detailed architecture explanation
   - Step-by-step getting started tutorial
   - Full configuration reference
   - Target type comparison (IP vs Instance mode)
   - Networking configuration
   - Terraform integration workflow
   - Comprehensive troubleshooting section
   - Best practices with examples

### Example Manifests

1. **01-basic-targetgroupbinding.yaml**
   - Simple binding of Service to Target Group
   - Deployment, Service, and TargetGroupBinding
   - AWS CLI commands for Target Group creation
   - Verification steps

2. **02-terraform-alb-targetgroupbinding.yaml**
   - Complete example with Terraform-managed infrastructure
   - Multiple applications (web and API)
   - Networking configuration with security groups
   - References companion Terraform file

3. **03-multi-port-targetgroupbinding.yaml**
   - Binding multiple ports from single Service
   - Separate Target Groups for HTTP and metrics
   - Use case: public HTTP, private metrics
   - Different ALBs for different ports

4. **04-instance-mode-targetgroupbinding.yaml**
   - Instance target type instead of IP mode
   - NodePort service configuration
   - Comparison of IP vs Instance mode
   - Security group configuration for NodePort
   - When to use instance mode

5. **05-blue-green-deployment.yaml**
   - Complete blue-green deployment pattern
   - Separate deployments for blue and green versions
   - Production and staging TargetGroupBindings
   - Step-by-step deployment process
   - Traffic switching commands
   - Weighted traffic splitting
   - Rollback strategies
   - Monitoring and automation

6. **06-cross-cluster-targetgroupbinding.yaml**
   - Sharing Target Group across multiple clusters
   - Configurations for Cluster 1 and Cluster 2
   - High availability and disaster recovery
   - Multi-region active-active setup
   - Traffic distribution strategies
   - Monitoring and failover procedures

### Terraform Configuration

**terraform-targetgroupbinding.tf** (300+ lines)
- Complete Terraform configuration for ALB with Target Groups
- Security groups for ALB
- Application Load Balancer
- Multiple Target Groups (web and API)
- HTTPS and HTTP listeners
- Listener rules for host and path-based routing
- Comprehensive outputs for Kubernetes integration
- Example terraform.tfvars
- Tags for Kubernetes integration

## Key Features

### Architecture Benefits

1. **Infrastructure Separation**
   - Infrastructure team manages ALB with Terraform
   - Application team manages Kubernetes deployments
   - Clear separation of concerns

2. **Existing Infrastructure Integration**
   - Use existing load balancers
   - No need to recreate infrastructure
   - Gradual migration path

3. **Advanced Deployment Patterns**
   - Blue-green deployments
   - Canary releases
   - Multi-cluster setups
   - Hybrid deployments (K8s + EC2 + Lambda)

4. **Fine-Grained Control**
   - Direct control over target registration
   - Custom health check configuration
   - Networking policies
   - Target group attributes

### Use Cases Covered

1. **Terraform-Managed Infrastructure**
   - Complete workflow from Terraform to Kubernetes
   - Output integration
   - CI/CD automation

2. **Blue-Green Deployments**
   - Zero-downtime deployments
   - Instant rollback
   - Weighted traffic splitting
   - Testing before cutover

3. **Multi-Cluster High Availability**
   - Share Target Group across clusters
   - Automatic failover
   - Geographic distribution
   - Disaster recovery

4. **Gradual Migration**
   - Migrate from EC2 to Kubernetes
   - Mix EC2 and Kubernetes targets
   - Controlled traffic shifting

5. **Multi-Port Services**
   - Different Target Groups per port
   - Public and private endpoints
   - Separate security policies

6. **Instance Mode**
   - Compatible with any CNI
   - NodePort-based routing
   - Legacy infrastructure support

## Configuration Options

### Target Types

**IP Mode (Recommended):**
- Direct pod IP registration
- Works with ClusterIP services
- Better performance
- Requires VPC CNI

**Instance Mode:**
- Node-based registration
- Works with NodePort services
- Compatible with any CNI
- Extra network hop

### Networking Configuration

- Security group-based access control
- IP block restrictions
- Multi-port configuration
- IPv4/IPv6/dualstack support

### Service Integration

- ClusterIP for IP mode
- NodePort for instance mode
- Port number or name reference
- Multiple ports per service

## Terraform Integration

### Workflow

1. **Terraform creates infrastructure:**
   ```bash
   terraform apply
   terraform output target_group_arn
   ```

2. **Update Kubernetes manifest:**
   ```yaml
   spec:
     targetGroupARN: <output_from_terraform>
   ```

3. **Deploy to Kubernetes:**
   ```bash
   kubectl apply -f app.yaml
   ```

4. **Verify:**
   ```bash
   aws elbv2 describe-target-health --target-group-arn <arn>
   ```

### Terraform Resources Created

- Application Load Balancer
- Security Groups
- Target Groups (web and API)
- HTTPS Listener (with certificate)
- HTTP Listener (redirect to HTTPS)
- Listener Rules (host and path-based)
- Outputs for Kubernetes integration

## Comparison: Ingress vs TargetGroupBinding

| Feature | Ingress | TargetGroupBinding |
|---------|---------|-------------------|
| **ALB Management** | Controller creates | Use existing |
| **Target Group** | Controller creates | Use existing |
| **Routing Rules** | In Ingress | In ALB |
| **Terraform Integration** | Limited | Excellent |
| **Multi-Cluster** | Difficult | Easy |
| **Hybrid Targets** | Not supported | Supported |
| **Blue-Green** | Complex | Simple |
| **Complexity** | Lower | Higher |
| **Flexibility** | Lower | Higher |

## Troubleshooting Coverage

### Common Issues Addressed

1. **TargetGroupBinding Not Working**
   - Diagnosis commands
   - Common causes
   - Solutions

2. **Targets Not Registered**
   - IAM permissions
   - Target type mismatch
   - Network issues
   - Security groups

3. **Targets Unhealthy**
   - Health check configuration
   - Application issues
   - Network connectivity
   - Security group rules

4. **Targets Not Deregistering**
   - Deregistration delay
   - Connection draining
   - Configuration updates

## Best Practices Documented

1. Use descriptive names and labels
2. Match target types between TG and TGB
3. Configure appropriate health checks
4. Use networking configuration for security
5. Tag resources for tracking
6. Monitor target health continuously
7. Set appropriate deregistration delay
8. Use Infrastructure as Code
9. Implement proper readiness probes
10. Document ARN sources

## Directory Structure

```
examples/
├── README.md                          # Main examples overview
├── ingress/                           # Ingress examples (existing)
│   ├── README.md
│   ├── 01-basic-shared-alb.yaml
│   ├── 02-multi-namespace-shared-alb.yaml
│   ├── 03-priority-based-routing.yaml
│   ├── 04-multiple-ssl-certificates.yaml
│   ├── 05-custom-health-checks.yaml
│   ├── 06-cognito-authentication.yaml
│   ├── 07-http-to-https-redirect.yaml
│   ├── 08-terraform-managed-alb.yaml
│   ├── terraform-alb-example.tf
│   └── TERRAFORM-ALB-INTEGRATION.md
└── targetgroupbinding/                # NEW: TargetGroupBinding examples
    ├── README.md                      # Overview and quick start
    ├── TARGETGROUPBINDING-GUIDE.md    # Complete technical guide
    ├── 01-basic-targetgroupbinding.yaml
    ├── 02-terraform-alb-targetgroupbinding.yaml
    ├── 03-multi-port-targetgroupbinding.yaml
    ├── 04-instance-mode-targetgroupbinding.yaml
    ├── 05-blue-green-deployment.yaml
    ├── 06-cross-cluster-targetgroupbinding.yaml
    └── terraform-targetgroupbinding.tf
```

## Quick Start Examples

### Basic Usage

```bash
# 1. Create Target Group
aws elbv2 create-target-group \
  --name my-app-tg \
  --protocol HTTP \
  --port 80 \
  --vpc-id vpc-xxxxx \
  --target-type ip

# 2. Deploy application
kubectl apply -f 01-basic-targetgroupbinding.yaml

# 3. Verify
kubectl get targetgroupbinding
aws elbv2 describe-target-health --target-group-arn <arn>
```

### Terraform Integration

```bash
# 1. Deploy infrastructure
cd examples/targetgroupbinding/
terraform apply

# 2. Get Target Group ARN
TG_ARN=$(terraform output -raw web_target_group_arn)

# 3. Update manifest and deploy
sed -i "s|TARGET_GROUP_ARN|$TG_ARN|g" 02-terraform-alb-targetgroupbinding.yaml
kubectl apply -f 02-terraform-alb-targetgroupbinding.yaml
```

### Blue-Green Deployment

```bash
# 1. Deploy both versions
kubectl apply -f 05-blue-green-deployment.yaml

# 2. Test green version via staging
curl https://staging.example.com

# 3. Switch production to green
kubectl patch targetgroupbinding app-production-tgb \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/serviceRef/name", "value":"app-green-service"}]'

# 4. Rollback if needed
kubectl patch targetgroupbinding app-production-tgb \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/serviceRef/name", "value":"app-blue-service"}]'
```

## Integration with Existing Documentation

### Updated Files

1. **examples/README.md**
   - Added targetgroupbinding/ section
   - Comparison table between Ingress and TargetGroupBinding
   - Quick reference for both approaches
   - Common tasks and troubleshooting

2. **examples/ingress/README.md**
   - Added reference to Terraform example (08-terraform-managed-alb.yaml)
   - Added Terraform Integration section
   - Updated Additional Resources

## Key Takeaways

### When to Use TargetGroupBinding

✓ **Use TargetGroupBinding when:**
- You have existing ALB/NLB infrastructure (Terraform, CloudFormation)
- You need to share load balancers across multiple clusters
- You want blue-green or canary deployments
- You need hybrid deployments (K8s + EC2 + Lambda)
- Infrastructure and application teams are separate
- You need fine-grained control over target groups

✓ **Use Ingress when:**
- You want automatic ALB lifecycle management
- You need simple host/path-based routing
- You prefer Kubernetes-native configuration
- You're starting fresh without existing infrastructure

### Benefits of This Implementation

1. **Comprehensive Coverage**: 6 different use cases with complete examples
2. **Production-Ready**: Includes monitoring, rollback, and troubleshooting
3. **Terraform Integration**: Complete workflow from infrastructure to application
4. **Best Practices**: Security, networking, health checks, and monitoring
5. **Clear Documentation**: Step-by-step guides with verification commands
6. **Real-World Scenarios**: Blue-green, multi-cluster, gradual migration

## Next Steps

### For Users

1. Review the README to understand when to use TargetGroupBinding
2. Start with `01-basic-targetgroupbinding.yaml` for simple use case
3. Progress to Terraform integration for production
4. Implement blue-green deployments for zero-downtime releases
5. Consider multi-cluster setup for high availability

### For Maintenance

1. Keep examples updated with latest controller versions
2. Add new use cases as they emerge
3. Update Terraform configuration for new AWS features
4. Expand troubleshooting section based on user feedback
5. Add CI/CD integration examples

## Resources Created

- **7 YAML files**: Complete Kubernetes manifests with inline documentation
- **1 Terraform file**: Production-ready infrastructure configuration
- **2 Markdown guides**: Comprehensive documentation (600+ lines total)
- **1 Main README**: Overview and integration with existing examples

**Total Lines of Code/Documentation**: ~1,500 lines

## Conclusion

The TargetGroupBinding examples provide a complete, production-ready solution for integrating Kubernetes with existing AWS infrastructure. The examples cover basic usage through advanced patterns like blue-green deployments and multi-cluster setups, with comprehensive documentation and Terraform integration.

This complements the existing Ingress examples by providing an alternative approach for teams with existing infrastructure or advanced deployment requirements.

