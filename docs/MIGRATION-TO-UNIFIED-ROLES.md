# Migration to Unified IAM Roles

## Summary of Changes

This document summarizes the migration from separate IRSA and Pod Identity roles to a unified role approach.

## What Changed

### Before: Separate Roles

Previously, we had separate roles for each authentication method:

- **Pod Identity roles**: `EKS-ExternalDNS-Role-dev`
- **IRSA roles**: `EKS-ExternalDNS-Role-irsa-dev`

This required:
- Managing twice as many IAM roles
- Conditional creation based on `enable_pod_identity` variable
- Different role ARNs in values files depending on authentication method

### After: Unified Roles

Now, we have a single role per service:

- **Unified role**: `EKS-ExternalDNS-Role-dev`

This role has a **combined trust policy** that supports both authentication methods.

## Benefits

1. **Simplified Management**: 50% fewer IAM roles to manage
2. **Seamless Switching**: Change authentication methods without updating values files
3. **Reduced Complexity**: No conditional role creation in Terraform
4. **Consistent Configuration**: Same role ARN everywhere

## Technical Implementation

### Combined Trust Policy

Each role now has a trust policy with two statements:

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
      "Action": ["sts:AssumeRole", "sts:TagSession"]
    },
    {
      "Sid": "IRSAAssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/..."
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc-provider:sub": "system:serviceaccount:namespace:sa",
          "oidc-provider:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

### Values File Configuration

All values files now have both annotations pointing to the **same role**:

```yaml
serviceAccount:
  annotations:
    # IRSA annotation
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-dev"
    # Pod Identity annotation
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-dev"
```

## Files Modified

### Terraform Files

1. **`terraform/data.tf`**:
   - Added `combined_trust_policy` data source
   - Combines Pod Identity and IRSA trust statements

2. **`terraform/iam-roles.tf`**:
   - Removed all conditional IRSA role resources
   - Updated all roles to use `combined_trust_policy`
   - Simplified from ~300 lines to ~150 lines

### Helm Values Files

Updated all 19 values files to use the same role ARN in both annotations:

- `charts/aws-efs-csi-driver/values-{dev,prod}.yaml`
- `charts/aws-load-balancer-controller/values-{dev,prod}.yaml`
- `charts/cluster-autoscaler/values-{dev,prod}.yaml`
- `charts/external-dns/values-{dev,prod}.yaml`
- `charts/external-secrets-operator/values-{dev,prod}.yaml`
- `charts/ingress-nginx/values-{dev,prod,external}.yaml`
- `charts/metrics-server/values-{dev,prod}.yaml`
- `charts/pod-identity/values-{dev,prod}.yaml`
- `charts/secrets-store-csi-driver/values-{dev,prod}.yaml`

### Documentation Files

Created/updated:

1. **`docs/UNIFIED-ROLE-APPROACH.md`** - Comprehensive guide to the unified approach
2. **`docs/ROLE-ARN-REFERENCE.md`** - Complete role ARN reference
3. **`docs/VALUES-FILES-UPDATE-SUMMARY.md`** - Updated to reflect unified roles
4. **`docs/MIGRATION-TO-UNIFIED-ROLES.md`** - This file

## Migration Steps

If you're migrating from the old approach:

### Step 1: Backup Current State

```bash
# Backup Terraform state
terraform state pull > terraform-state-backup.json

# List current roles
aws iam list-roles --query 'Roles[?contains(RoleName, `EKS-`)].RoleName' > current-roles.txt
```

### Step 2: Update Terraform

```bash
cd terraform

# Pull latest changes
git pull

# Review changes
terraform plan

# Apply changes
terraform apply
```

This will:
- Create new roles with combined trust policies
- Update existing roles if they already exist
- Remove old `-irsa-` roles (if they exist)

### Step 3: Update Values Files

```bash
# Pull latest values files
git pull

# Verify role ARNs are updated
grep -r "role-arn" charts/*/values-*.yaml
```

All `-irsa-` suffixes should be removed.

### Step 4: Redeploy Charts

```bash
# Redeploy all charts to pick up new role ARNs
helm upgrade --install external-dns \
  charts/external-dns/charts/external-dns-1.19.0.tgz \
  -n external-dns \
  -f charts/external-dns/values-prod.yaml

# Repeat for other charts...
```

### Step 5: Verify

```bash
# Check role trust policies
aws iam get-role --role-name EKS-ExternalDNS-Role-prod

# Check service accounts
kubectl get sa -A -o yaml | grep -A 5 "eks.amazonaws.com"

# Check pod credentials
kubectl exec -it <pod-name> -n <namespace> -- aws sts get-caller-identity
```

### Step 6: Clean Up Old Roles (Optional)

If you had old `-irsa-` roles:

```bash
# List old roles
aws iam list-roles --query 'Roles[?contains(RoleName, `-irsa-`)].RoleName'

# Delete old roles (after verification)
aws iam delete-role --role-name EKS-ExternalDNS-Role-irsa-prod
```

## Rollback Plan

If you need to rollback:

### Option 1: Terraform State Rollback

```bash
# Restore Terraform state
terraform state push terraform-state-backup.json

# Revert code changes
git revert <commit-hash>

# Apply old configuration
terraform apply
```

### Option 2: Manual Rollback

1. Recreate old `-irsa-` roles manually
2. Update values files with old role ARNs
3. Redeploy charts

## Verification Checklist

After migration, verify:

- [ ] All roles exist in AWS IAM
- [ ] Each role has both Pod Identity and IRSA trust statements
- [ ] All service accounts have both annotations
- [ ] Both annotations point to the same role ARN
- [ ] Pods can successfully assume roles
- [ ] Applications function correctly
- [ ] No old `-irsa-` roles remain (unless intentionally kept)

## Testing

### Test IRSA

```bash
# Disable Pod Identity
# terraform/terraform.tfvars
enable_pod_identity = false

# Apply
terraform apply

# Redeploy chart
helm upgrade --install external-dns ...

# Verify IRSA is used
kubectl exec -it <pod-name> -n external-dns -- env | grep AWS_WEB_IDENTITY_TOKEN_FILE
```

### Test Pod Identity

```bash
# Enable Pod Identity
# terraform/terraform.tfvars
enable_pod_identity = true

# Apply
terraform apply

# Redeploy chart
helm upgrade --install external-dns ...

# Verify Pod Identity is used
kubectl exec -it <pod-name> -n external-dns -- env | grep AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE
```

## Troubleshooting

### Issue: Role doesn't have combined trust policy

**Solution**: Terraform may not have updated the existing role. Delete and recreate:

```bash
# Delete role
aws iam delete-role --role-name EKS-ExternalDNS-Role-prod

# Reapply Terraform
terraform apply
```

### Issue: Pods can't assume role

**Check**:
1. Trust policy has both statements
2. Service account has both annotations
3. Pod Identity associations exist (if using Pod Identity)
4. OIDC provider is configured (if using IRSA)

### Issue: Wrong authentication method being used

**Solution**: Check which method is active:

```bash
# Check for Pod Identity associations
aws eks list-pod-identity-associations --cluster-name your-cluster

# If associations exist, Pod Identity is active
# If no associations, IRSA is active
```

## Support

For issues or questions:

1. Check documentation in `docs/` directory
2. Review Terraform plan output
3. Check AWS IAM console for role trust policies
4. Verify service account annotations in Kubernetes

## Related Documentation

- `docs/UNIFIED-ROLE-APPROACH.md` - Detailed explanation
- `docs/ROLE-ARN-REFERENCE.md` - Role ARN reference
- `docs/POD-IDENTITY-VS-IRSA.md` - Authentication method comparison
- `terraform/iam-roles.tf` - Role definitions
- `terraform/data.tf` - Trust policy definitions
