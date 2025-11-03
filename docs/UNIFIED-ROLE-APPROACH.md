# Unified IAM Role Approach

## Overview

This project uses a **unified IAM role approach** where each service has a single IAM role with a combined trust policy that supports **both IRSA and Pod Identity** authentication methods.

## Key Benefits

1. **Simplified Management**: Only one role per service instead of separate roles for each authentication method
2. **Seamless Switching**: Switch between IRSA and Pod Identity without changing role ARNs
3. **Reduced Complexity**: Fewer resources to manage in Terraform and AWS
4. **Consistent Configuration**: Same role ARN used in both annotations

## How It Works

### Combined Trust Policy

Each IAM role has a trust policy with two statements:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PodIdentityAssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    },
    {
      "Sid": "IRSAAssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT",
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

### Role Naming Convention

All roles follow this pattern:
```
EKS-<ServiceName>-Role-<environment>
```

Examples:
- `EKS-ExternalDNS-Role-dev`
- `EKS-ExternalDNS-Role-prod`
- `EKS-EFS-CSI-DriverRole-dev`
- `EKS-ClusterAutoscaler-Role-prod`

**Note**: There is NO `-irsa-` suffix. The same role works for both authentication methods.

## Values File Configuration

All Helm chart values files include both annotations pointing to the **same role**:

```yaml
serviceAccount:
  annotations:
    # IRSA annotation (used when authMethod is "irsa")
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-prod"
    # Pod Identity annotation (used when authMethod is "pod-identity")
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-prod"
```

### Which Annotation is Used?

Kubernetes automatically uses the appropriate annotation based on your cluster configuration:

- **Pod Identity enabled**: Uses `eks.amazonaws.com/pod-identity-association-role-arn`
- **IRSA enabled**: Uses `eks.amazonaws.com/role-arn`

## Terraform Configuration

### Creating Roles

Roles are created in `terraform/iam-roles.tf` using the combined trust policy:

```hcl
resource "aws_iam_role" "external_dns" {
  name        = "${local.unique_roles["EKS-ExternalDNS-Role"].name}-${var.environment}"
  description = "${local.unique_roles["EKS-ExternalDNS-Role"].description} for ${var.environment}"

  # Combined trust policy supports both IRSA and Pod Identity
  assume_role_policy = data.aws_iam_policy_document.combined_trust_policy["external-dns"].json

  tags = local.common_tags
}
```

### Trust Policy Definition

The combined trust policy is defined in `terraform/data.tf`:

```hcl
data "aws_iam_policy_document" "combined_trust_policy" {
  for_each = local.service_accounts

  # Pod Identity trust policy
  statement {
    sid    = "PodIdentityAssumeRole"
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }

  # IRSA trust policy
  statement {
    sid    = "IRSAAssumeRole"
    effect = "Allow"
    
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    
    actions = ["sts:AssumeRoleWithWebIdentity"]
    
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}
```

## Switching Authentication Methods

### No Values File Changes Required!

Since both annotations point to the same role, you can switch authentication methods by only changing your Terraform configuration:

1. **Update Terraform variable**:
   ```hcl
   # terraform/terraform.tfvars
   enable_pod_identity = true  # or false
   ```

2. **Apply Terraform**:
   ```bash
   cd terraform
   terraform apply
   ```

3. **Redeploy charts** (to pick up Pod Identity associations if switching to Pod Identity):
   ```bash
   helm upgrade --install external-dns \
     charts/external-dns/charts/external-dns-1.19.0.tgz \
     -n external-dns \
     -f charts/external-dns/values-prod.yaml
   ```

## Service List

All services use the unified role approach:

| Service | Role Name Pattern |
|---------|------------------|
| AWS EFS CSI Driver | `EKS-EFS-CSI-DriverRole-{env}` |
| AWS Load Balancer Controller | `EKS-AWSLoadBalancerController-Role-{env}` |
| Cluster Autoscaler | `EKS-ClusterAutoscaler-Role-{env}` |
| External DNS | `EKS-ExternalDNS-Role-{env}` |
| External Secrets Operator | `EKS-ExternalSecrets-Role-{env}` |
| Ingress NGINX | `EKS-IngressNginx-Role-{env}` |
| Metrics Server | `EKS-MetricsServer-Role-{env}` |
| Pod Identity Agent | `EKS-PodIdentity-Role-{env}` |
| Secrets Store CSI Driver | `EKS-SecretsStore-Role-{env}` |

## Verification

### Check Role Trust Policy

```bash
aws iam get-role --role-name EKS-ExternalDNS-Role-prod --query 'Role.AssumeRolePolicyDocument'
```

You should see both Pod Identity and IRSA statements in the trust policy.

### Check Service Account

```bash
kubectl get sa external-dns -n external-dns -o yaml
```

You should see both annotations with the same role ARN.

### Check Pod Credentials

```bash
# Get the assumed role
kubectl exec -it <pod-name> -n external-dns -- aws sts get-caller-identity
```

The role ARN should match your configured role, regardless of authentication method.

## Migration from Separate Roles

If you previously had separate `-irsa-` roles, the migration is straightforward:

1. **Apply the new Terraform configuration** - This creates roles with combined trust policies
2. **Update values files** - Remove `-irsa-` suffix from role ARNs (already done in this repo)
3. **Redeploy charts** - Use updated values files
4. **Clean up old roles** - Delete the old `-irsa-` roles after verification

## Troubleshooting

### Pod can't assume role

**Check which authentication method is active:**
```bash
# Check for Pod Identity associations
aws eks list-pod-identity-associations --cluster-name your-cluster

# Check service account annotations
kubectl get sa <service-account> -n <namespace> -o yaml
```

**Verify trust policy:**
```bash
aws iam get-role --role-name EKS-ExternalDNS-Role-prod
```

### Wrong authentication method being used

The authentication method is determined by:
1. **Pod Identity**: Requires Pod Identity associations created by Terraform
2. **IRSA**: Falls back to IRSA if no Pod Identity association exists

To switch methods, update `enable_pod_identity` in Terraform and apply.

## Related Documentation

- `docs/POD-IDENTITY-VS-IRSA.md` - Comparison of authentication methods
- `docs/ROLE-ARN-REFERENCE.md` - Complete role ARN reference
- `terraform/iam-roles.tf` - Role definitions
- `terraform/data.tf` - Trust policy definitions
