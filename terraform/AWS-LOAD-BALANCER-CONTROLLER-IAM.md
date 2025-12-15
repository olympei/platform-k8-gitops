# AWS Load Balancer Controller - Terraform IAM Configuration

## Summary
Added complete IAM policy for AWS Load Balancer Controller to Terraform configuration.

## Changes Made

### 1. IAM Policy Added (`terraform/iam-policies.tf`)

Added comprehensive IAM policy resource: `aws_iam_policy.aws_load_balancer_controller`

**Policy Name:** `EKS-AWSLoadBalancerController-Policy-{environment}`

**Permissions Included:**
- **EC2 Permissions:**
  - Describe VPCs, subnets, security groups, instances, network interfaces
  - Create, modify, and delete security groups (with cluster tags)
  - Manage security group rules
  - Tag resources

- **Elastic Load Balancing Permissions:**
  - Create, modify, and delete Application Load Balancers (ALB)
  - Create, modify, and delete Network Load Balancers (NLB)
  - Manage target groups and targets
  - Configure listeners and rules
  - Manage load balancer attributes
  - Tag load balancers and target groups

- **Certificate Management:**
  - List and describe ACM certificates
  - List and get IAM server certificates

- **WAF Integration:**
  - Associate/disassociate WAF and WAFv2 web ACLs
  - Get web ACL information

- **AWS Shield:**
  - Get subscription state
  - Describe, create, and delete protections

- **Cognito Integration:**
  - Describe user pool clients (for authentication)

- **Service-Linked Roles:**
  - Create service-linked role for ELB

**Resource Tagging Requirements:**
All resources created by the controller are tagged with:
```
elbv2.k8s.aws/cluster = <cluster-name>
```

This ensures the controller only manages resources it created.

## Existing Configuration

### 2. IAM Role (`terraform/iam-roles.tf`)
Already configured:
```hcl
resource "aws_iam_role" "aws_load_balancer_controller" {
  name        = "EKS-AWSLoadBalancerController-Role-${var.environment}"
  description = "Role for AWS Load Balancer Controller for ${var.environment}"
  
  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["aws-load-balancer-controller"].json
  
  tags = local.common_tags
}
```

### 3. Policy Attachment (`terraform/iam-roles.tf`)
Already configured:
```hcl
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}
```

### 4. Service Account Configuration (`terraform/locals.tf`)
Already configured:
```hcl
aws-load-balancer-controller = {
  addon_name      = "aws-load-balancer-controller"
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  policy_name     = "EKS-AWSLoadBalancerController-Policy"
  role_name       = "EKS-AWSLoadBalancerController-Role"
}
```

### 5. Policy Definition (`terraform/locals.tf`)
Already configured:
```hcl
"EKS-AWSLoadBalancerController-Policy" = {
  name        = "EKS-AWSLoadBalancerController-Policy"
  description = "Policy for AWS Load Balancer Controller"
  policy_file = "aws-load-balancer-controller-policy.json"
}
```

### 6. Role Definition (`terraform/locals.tf`)
Already configured:
```hcl
"EKS-AWSLoadBalancerController-Role" = {
  name         = "EKS-AWSLoadBalancerController-Role"
  description  = "Role for AWS Load Balancer Controller"
  policy_names = ["EKS-AWSLoadBalancerController-Policy"]
}
```

### 7. Pod Identity Association (`terraform/pod-identity-associations.tf`)
Already configured:
```hcl
resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  count = var.enable_pod_identity && var.enable_pod_identity_aws_load_balancer_controller ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = local.service_accounts["aws-load-balancer-controller"].namespace
  service_account = local.service_accounts["aws-load-balancer-controller"].service_account
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn

  tags = local.common_tags
}
```

### 8. Variable Definition (`terraform/variables.tf`)
Already configured:
```hcl
variable "enable_pod_identity_aws_load_balancer_controller" {
  description = "Enable Pod Identity for AWS Load Balancer Controller"
  type        = bool
  default     = true
}
```

### 9. Combined Trust Policy (`terraform/data.tf`)
Already configured - automatically includes aws-load-balancer-controller through the `for_each` loop over `local.service_accounts`.

## Trust Policy Details

The role uses a **unified trust policy** that supports both authentication methods:

### Pod Identity Trust
```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "pods.eks.amazonaws.com"
  },
  "Action": [
    "sts:AssumeRole",
    "sts:TagSession"
  ]
}
```

### IRSA Trust
```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "<OIDC_PROVIDER_ARN>"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "<OIDC_PROVIDER>:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
      "<OIDC_PROVIDER>:aud": "sts.amazonaws.com"
    }
  }
}
```

## Deployment

### Apply Terraform Changes
```bash
cd terraform

# Initialize (if needed)
terraform init

# Plan changes
terraform plan -var-file="environments/dev.tfvars"

# Apply changes
terraform apply -var-file="environments/dev.tfvars"
```

### Verify IAM Resources
```bash
# Check if policy exists
aws iam get-policy --policy-arn arn:aws:iam::ACCOUNT_ID:policy/EKS-AWSLoadBalancerController-Policy-dev

# Check if role exists
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev

# Check role trust policy
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev \
  --query 'Role.AssumeRolePolicyDocument'

# Check attached policies
aws iam list-attached-role-policies --role-name EKS-AWSLoadBalancerController-Role-dev

# Check Pod Identity associations (if enabled)
aws eks list-pod-identity-associations --cluster-name your-cluster-name
```

## Configuration Variables

### Required Variables
```hcl
aws_account_id     = "123456789012"
aws_region         = "us-east-1"
cluster_name       = "my-eks-cluster"
oidc_provider_arn  = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/XXXXX"
oidc_provider_url  = "https://oidc.eks.us-east-1.amazonaws.com/id/XXXXX"
environment        = "dev"
```

### Optional Variables
```hcl
enable_pod_identity                              = true   # Global Pod Identity toggle
enable_pod_identity_aws_load_balancer_controller = true   # Specific to this controller
```

## IAM Policy Highlights

### Security Features
1. **Resource Tagging:** All resources must be tagged with `elbv2.k8s.aws/cluster`
2. **Conditional Access:** Many permissions require specific tags to be present
3. **Service-Linked Roles:** Can only create ELB service-linked roles
4. **Regional Restrictions:** Some actions are region-specific

### Key Permissions
- **Load Balancer Management:** Full lifecycle management of ALB/NLB
- **Target Group Management:** Create, modify, delete target groups
- **Security Group Management:** Create and manage security groups for load balancers
- **Certificate Management:** List and use ACM/IAM certificates
- **WAF Integration:** Associate WAF/WAFv2 web ACLs with load balancers
- **Shield Integration:** Manage DDoS protection

## Troubleshooting

### Permission Denied Errors
```bash
# Check CloudTrail for denied API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=EKS-AWSLoadBalancerController-Role-dev \
  --max-results 50

# Verify policy is attached to role
aws iam list-attached-role-policies --role-name EKS-AWSLoadBalancerController-Role-dev
```

### Trust Policy Issues
```bash
# Verify trust policy includes both Pod Identity and IRSA
aws iam get-role --role-name EKS-AWSLoadBalancerController-Role-dev \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json | jq
```

### Pod Identity Association Issues
```bash
# List all pod identity associations
aws eks list-pod-identity-associations --cluster-name your-cluster-name

# Describe specific association
aws eks describe-pod-identity-association \
  --cluster-name your-cluster-name \
  --association-id <association-id>
```

## Next Steps

1. **Apply Terraform:** Deploy the IAM resources
2. **Verify Resources:** Confirm policy and role creation
3. **Update Helm Values:** Ensure role ARN is correct in values files
4. **Deploy Controller:** Use GitLab CI/CD or manual Helm deployment
5. **Test Functionality:** Create a sample Ingress resource

## References

- [AWS Load Balancer Controller IAM Policy](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)
- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [EKS IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## Notes

- The IAM policy is based on the official AWS Load Balancer Controller policy
- The policy includes permissions for both ALB and NLB
- WAF and Shield permissions are included for production use
- The unified role approach simplifies management and supports both IRSA and Pod Identity
- Resource tagging ensures the controller only manages its own resources
