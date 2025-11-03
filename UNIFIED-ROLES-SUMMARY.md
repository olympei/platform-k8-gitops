# Unified IAM Roles - Implementation Summary

## Overview

Successfully implemented a **unified IAM role approach** where each EKS service has a single IAM role with a combined trust policy supporting both IRSA and Pod Identity authentication methods.

## Key Changes

### 1. Terraform Configuration

**File: `terraform/data.tf`**
- Added `combined_trust_policy` data source
- Combines Pod Identity and IRSA trust statements in a single policy
- Each role can now be assumed via either authentication method

**File: `terraform/iam-roles.tf`**
- Removed all conditional IRSA role resources (previously created with `count`)
- All roles now use `combined_trust_policy`
- Reduced from ~300 lines to ~150 lines
- Simplified role management

### 2. Helm Values Files

Updated **19 values files** across all services:
- Both annotations now point to the **same role ARN**
- Removed `-irsa-` suffix from all role names
- No need to change values files when switching authentication methods

**Pattern used:**
```yaml
serviceAccount:
  annotations:
    # IRSA annotation (used when authMethod is "irsa")
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ServiceName-Role-env"
    # Pod Identity annotation (used when authMethod is "pod-identity")
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ServiceName-Role-env"
```

### 3. Documentation

Created comprehensive documentation:

1. **`docs/UNIFIED-ROLE-APPROACH.md`**
   - Detailed explanation of the unified approach
   - How combined trust policies work
   - Configuration examples

2. **`docs/ROLE-ARN-REFERENCE.md`**
   - Complete list of all role ARNs
   - Deployment examples
   - Verification commands

3. **`docs/MIGRATION-TO-UNIFIED-ROLES.md`**
   - Migration guide from old approach
   - Step-by-step instructions
   - Rollback plan

4. **`docs/VALUES-FILES-UPDATE-SUMMARY.md`**
   - Updated to reflect unified roles
   - Usage examples

## Benefits

### Before (Separate Roles)
- 2 roles per service per environment
- Example: `EKS-ExternalDNS-Role-dev` AND `EKS-ExternalDNS-Role-irsa-dev`
- Conditional creation based on `enable_pod_identity`
- Different role ARNs in values files
- Complex Terraform configuration

### After (Unified Roles)
- 1 role per service per environment
- Example: `EKS-ExternalDNS-Role-dev` (works for both methods)
- Always created, no conditional logic
- Same role ARN everywhere
- Simplified Terraform configuration

### Quantifiable Improvements
- **50% fewer IAM roles** to manage
- **~50% reduction** in Terraform code complexity
- **Zero values file changes** needed when switching authentication methods
- **Single source of truth** for role ARNs

## How It Works

### Combined Trust Policy Structure

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

### Authentication Method Selection

Controlled by Terraform variable:
```hcl
enable_pod_identity = true  # or false
```

- **`true`**: Creates Pod Identity associations → Pods use Pod Identity
- **`false`**: No Pod Identity associations → Pods fall back to IRSA

**Same role, different authentication path!**

## Services Updated

All 9 services now use unified roles:

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

## Usage

### Deploying with Unified Roles

1. **Update ACCOUNT_ID** in values files
2. **Deploy Terraform**:
   ```bash
   cd terraform
   terraform apply
   ```
3. **Deploy Helm charts**:
   ```bash
   helm upgrade --install external-dns \
     charts/external-dns/charts/external-dns-1.19.0.tgz \
     -n external-dns \
     -f charts/external-dns/values-prod.yaml
   ```

### Switching Authentication Methods

1. **Update Terraform variable**:
   ```hcl
   enable_pod_identity = true  # or false
   ```
2. **Apply Terraform**:
   ```bash
   terraform apply
   ```
3. **Redeploy charts** (to pick up Pod Identity associations):
   ```bash
   helm upgrade --install <chart> ...
   ```

**No values file changes needed!**

## Verification

### Check Role Trust Policy
```bash
aws iam get-role --role-name EKS-ExternalDNS-Role-prod \
  --query 'Role.AssumeRolePolicyDocument'
```

Should show both Pod Identity and IRSA statements.

### Check Service Account
```bash
kubectl get sa external-dns -n external-dns -o yaml
```

Should show both annotations with the same role ARN.

### Check Pod Credentials
```bash
kubectl exec -it <pod-name> -n external-dns -- aws sts get-caller-identity
```

Should return the unified role ARN.

## Files Modified

### Terraform Files (2)
- `terraform/data.tf` - Added combined trust policy
- `terraform/iam-roles.tf` - Simplified to use unified roles

### Helm Values Files (19)
- `charts/aws-efs-csi-driver/values-{dev,prod}.yaml`
- `charts/aws-load-balancer-controller/values-{dev,prod}.yaml`
- `charts/cluster-autoscaler/values-{dev,prod}.yaml`
- `charts/external-dns/values-{dev,prod}.yaml`
- `charts/external-secrets-operator/values-{dev,prod}.yaml`
- `charts/ingress-nginx/values-{dev,prod,external}.yaml`
- `charts/metrics-server/values-{dev,prod}.yaml`
- `charts/pod-identity/values-{dev,prod}.yaml`
- `charts/secrets-store-csi-driver/values-{dev,prod}.yaml`

### Documentation Files (4)
- `docs/UNIFIED-ROLE-APPROACH.md` - New
- `docs/ROLE-ARN-REFERENCE.md` - New
- `docs/MIGRATION-TO-UNIFIED-ROLES.md` - New
- `docs/VALUES-FILES-UPDATE-SUMMARY.md` - Updated

## Next Steps

1. **Test in Dev Environment**:
   - Apply Terraform changes
   - Deploy charts
   - Verify both IRSA and Pod Identity work

2. **Validate Switching**:
   - Switch from IRSA to Pod Identity
   - Switch from Pod Identity to IRSA
   - Verify seamless transition

3. **Deploy to Production**:
   - After successful dev testing
   - Follow migration guide
   - Monitor applications

## Support

For questions or issues:
- Review documentation in `docs/` directory
- Check Terraform plan output before applying
- Verify role trust policies in AWS IAM console
- Test in dev environment first

## Conclusion

The unified IAM role approach significantly simplifies the management of EKS service authentication while maintaining full flexibility to switch between IRSA and Pod Identity authentication methods. This implementation reduces complexity, improves maintainability, and provides a better developer experience.
