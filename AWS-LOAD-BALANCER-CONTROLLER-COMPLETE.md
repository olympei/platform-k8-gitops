# AWS Load Balancer Controller - Complete Integration Summary

## Overview
Successfully integrated AWS Load Balancer Controller into the platform with complete GitLab CI/CD pipeline support and Terraform IAM configuration.

## What Was Added

### 1. GitLab CI/CD Pipeline Integration

**File:** `.gitlab-ci.yml`

#### Control Variables Added
```yaml
# Installation control
INSTALL_AWS_LOAD_BALANCER_CONTROLLER - Enable/disable chart installation (default: true)

# Uninstallation control  
UNINSTALL_AWS_LOAD_BALANCER_CONTROLLER - Enable/disable chart uninstallation (default: false)

# Namespace override
HELM_NAMESPACE_AWS_LOAD_BALANCER_CONTROLLER - Override default namespace
```

#### Deployment Jobs Added
- `deploy:aws-load-balancer-controller:dev` - Deploy to dev environment
- `deploy:aws-load-balancer-controller:prod` - Deploy to prod environment

Both jobs:
- Extend `.deploy_single_chart` template
- Support manual triggering
- Include debug mode via `HELM_DEBUG` variable
- Provide comprehensive error handling and logging

### 2. Terraform IAM Configuration

**Files Modified:**
- `terraform/iam-policies.tf` - Added IAM policy
- `terraform/outputs.tf` - Added outputs for policy and role ARNs

**Already Configured (from previous work):**
- `terraform/locals.tf` - Service account and policy definitions
- `terraform/iam-roles.tf` - IAM role with unified trust policy
- `terraform/pod-identity-associations.tf` - Pod Identity association
- `terraform/variables.tf` - Enable flag variable
- `terraform/data.tf` - Combined trust policy

#### IAM Policy Details
**Policy Name:** `EKS-AWSLoadBalancerController-Policy-{environment}`

**Key Permissions:**
- EC2: VPC, subnet, security group, instance management
- ELB: ALB/NLB lifecycle management
- Target Groups: Create, modify, delete, register/deregister targets
- Security Groups: Create, modify, delete (with cluster tags)
- Certificates: List and describe ACM/IAM certificates
- WAF: Associate/disassociate web ACLs
- Shield: DDoS protection management
- Cognito: User pool client integration

**Security Features:**
- Resource tagging requirements (`elbv2.k8s.aws/cluster`)
- Conditional access based on tags
- Service-linked role creation for ELB only
- Regional restrictions on certain actions

#### IAM Role Details
**Role Name:** `EKS-AWSLoadBalancerController-Role-{environment}`

**Trust Policy:** Unified approach supporting both:
- **Pod Identity:** `pods.eks.amazonaws.com` service principal
- **IRSA:** OIDC provider with service account conditions

**Service Account:**
- Namespace: `kube-system`
- Name: `aws-load-balancer-controller`

### 3. Documentation Created

#### `charts/aws-load-balancer-controller/DEPLOYMENT.md`
Comprehensive deployment guide including:
- Prerequisites and IAM requirements
- Cluster configuration steps
- Deployment methods (GitLab CI/CD and manual)
- Configuration differences (dev vs prod)
- Verification procedures
- Troubleshooting guide
- Uninstallation instructions

#### `terraform/AWS-LOAD-BALANCER-CONTROLLER-IAM.md`
Detailed Terraform IAM documentation including:
- Complete IAM policy breakdown
- Trust policy details
- Deployment instructions
- Verification commands
- Troubleshooting steps
- Configuration variables

#### `AWS-LOAD-BALANCER-CONTROLLER-ADDED.md`
Quick reference guide for:
- Usage instructions
- GitLab CI/CD integration
- Manual deployment commands
- Configuration highlights
- Important notes and requirements

## Existing Configuration (Already in Place)

### Helm Chart Structure
```
charts/aws-load-balancer-controller/
├── Chart.yaml                          # v1.14.1 with dependencies
├── charts/
│   └── aws-load-balancer-controller-1.14.1.tgz
├── templates/                          # Kubernetes templates
├── values-dev.yaml                     # Dev configuration
├── values-prod.yaml                    # Prod configuration
├── README.md                           # Chart documentation
└── DEPLOYMENT.md                       # NEW: Deployment guide
```

### Values Files Configuration

Both `values-dev.yaml` and `values-prod.yaml` include:

**Unified IAM Role Annotations:**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-{env}"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-{env}"
```

**Environment-Specific Settings:**

**Dev:**
- Replicas: 2
- CPU: 100m request, 200m limit
- Memory: 200Mi request, 500Mi limit
- Shield/WAF: Disabled
- Affinity: Preferred pod anti-affinity

**Prod:**
- Replicas: 3
- CPU: 200m request, 500m limit
- Memory: 500Mi request, 1Gi limit
- Shield: Enabled
- WAFv2: Enabled
- Priority Class: system-cluster-critical
- Affinity: Required pod anti-affinity across zones

## Deployment Workflow

### Option 1: GitLab CI/CD (Recommended)

#### Deploy Individual Chart
1. Navigate to GitLab CI/CD → Pipelines
2. Trigger manual job:
   - Dev: `deploy:aws-load-balancer-controller:dev`
   - Prod: `deploy:aws-load-balancer-controller:prod`

#### Deploy All Charts
The controller is automatically included when running:
- `deploy:helm:dev`
- `deploy:helm:prod`

#### Control Deployment
```bash
# Disable installation
INSTALL_AWS_LOAD_BALANCER_CONTROLLER=false

# Enable debug mode
HELM_DEBUG=true

# Override namespace
HELM_NAMESPACE_AWS_LOAD_BALANCER_CONTROLLER=aws-load-balancer-controller
```

### Option 2: Manual Deployment

#### Prerequisites
1. Apply Terraform IAM resources
2. Update values files with:
   - `clusterName`: Your EKS cluster name
   - `region`: AWS region
   - `vpcId`: VPC ID
   - `ACCOUNT_ID`: AWS account ID in role ARNs

#### Deploy Commands

**Dev:**
```bash
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  -n aws-load-balancer-controller --create-namespace \
  -f charts/aws-load-balancer-controller/values-dev.yaml \
  --wait --timeout 10m
```

**Prod:**
```bash
helm upgrade --install aws-load-balancer-controller \
  ./charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  -n aws-load-balancer-controller --create-namespace \
  -f charts/aws-load-balancer-controller/values-prod.yaml \
  --wait --timeout 10m
```

## Terraform Deployment

### Apply IAM Resources
```bash
cd terraform

# Plan changes
terraform plan -var-file="environments/dev.tfvars"

# Apply changes
terraform apply -var-file="environments/dev.tfvars"
```

### Verify Resources
```bash
# Check policy
aws iam get-policy --policy-arn arn:aws:iam::ACCOUNT_ID:policy/EKS-AWSLoadBalancerController-Policy-dev

# Check role
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev

# Check trust policy
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev \
  --query 'Role.AssumeRolePolicyDocument'

# Check Pod Identity associations
aws eks list-pod-identity-associations --cluster-name your-cluster-name
```

### Terraform Outputs
```bash
# Get policy ARN
terraform output aws_load_balancer_controller_policy_arn

# Get role ARN
terraform output aws_load_balancer_controller_role_arn

# Get all role ARNs for Helm
terraform output helm_role_arns

# Get Pod Identity association IDs
terraform output pod_identity_associations
```

## Verification Steps

### 1. Check Controller Deployment
```bash
# Check pods
kubectl -n aws-load-balancer-controller get pods

# Check logs
kubectl -n aws-load-balancer-controller logs -l app.kubernetes.io/name=aws-load-balancer-controller

# Check service account
kubectl -n aws-load-balancer-controller get sa aws-load-balancer-controller -o yaml
```

### 2. Verify IAM Configuration
```bash
# Check service account annotations
kubectl -n aws-load-balancer-controller get sa aws-load-balancer-controller \
  -o jsonpath='{.metadata.annotations}'

# Verify Pod Identity association
aws eks list-pod-identity-associations --cluster-name your-cluster-name \
  --query "associations[?serviceAccount=='aws-load-balancer-controller']"
```

### 3. Test with Sample Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-alb
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

## Important Prerequisites

### 1. VPC Subnet Tags
Subnets must be properly tagged for the controller to work:

**Public Subnets (internet-facing ALBs):**
```
kubernetes.io/role/elb = 1
```

**Private Subnets (internal ALBs):**
```
kubernetes.io/role/internal-elb = 1
```

### 2. IAM Permissions
The IAM role must have all required permissions from the policy.

### 3. Cluster Configuration
Update values files with actual cluster information:
- Cluster name
- AWS region
- VPC ID
- AWS account ID

## Troubleshooting

### Controller Not Starting
```bash
# Check pod events
kubectl -n aws-load-balancer-controller describe pod <pod-name>

# Check IAM role
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev

# Verify trust policy
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev \
  --query 'Role.AssumeRolePolicyDocument' | jq
```

### Load Balancer Not Created
```bash
# Check controller logs
kubectl -n aws-load-balancer-controller logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Check ingress events
kubectl describe ingress <ingress-name>

# Verify subnet tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'Subnets[*].[SubnetId,Tags]'
```

### Permission Errors
```bash
# Check CloudTrail for denied API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=EKS-AWSLoadBalancerController-Role-dev \
  --max-results 50
```

## Next Steps

1. **Apply Terraform Changes**
   ```bash
   cd terraform
   terraform apply -var-file="environments/dev.tfvars"
   ```

2. **Update Values Files**
   - Replace `clusterName` with actual cluster name
   - Replace `region` with AWS region
   - Replace `vpcId` with VPC ID
   - Replace `ACCOUNT_ID` with AWS account ID

3. **Tag VPC Subnets**
   - Add required tags to public and private subnets

4. **Deploy Controller**
   - Use GitLab CI/CD pipeline or manual Helm commands

5. **Verify Deployment**
   - Check pods are running
   - Verify IAM role association
   - Test with sample Ingress

6. **Create Test Ingress**
   - Deploy sample application
   - Create Ingress resource
   - Verify ALB creation in AWS console

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Ingress Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/)
- [Service Annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/service/annotations/)
- [Official IAM Policy](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [EKS IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## Summary

The AWS Load Balancer Controller is now fully integrated with:
- ✅ GitLab CI/CD pipeline support
- ✅ Terraform IAM configuration (policy, role, Pod Identity)
- ✅ Unified IAM role (supports both IRSA and Pod Identity)
- ✅ Environment-specific configurations (dev and prod)
- ✅ Comprehensive documentation
- ✅ Troubleshooting guides
- ✅ Verification procedures

The controller can be deployed using GitLab CI/CD or manual Helm commands after applying Terraform changes and updating cluster-specific values.
