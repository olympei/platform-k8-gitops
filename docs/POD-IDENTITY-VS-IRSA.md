# Pod Identity vs IRSA Configuration Guide

## Overview

This document explains how to configure service accounts for either **Pod Identity** (recommended for EKS 1.24+) or **IRSA** (legacy method).

## Key Annotation

**Important:** The annotation `eks.amazonaws.com/role-arn` works for **BOTH** Pod Identity and IRSA!

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/MyRole"
```

## How It Works

### With Pod Identity (Recommended)

When Pod Identity is enabled:
1. Create Pod Identity association in Terraform (see `terraform/pod-identity-associations.tf`)
2. Use `eks.amazonaws.com/role-arn` annotation in service account
3. Pod Identity Agent automatically handles authentication

**Terraform:**
```hcl
resource "aws_eks_pod_identity_association" "example" {
  cluster_name    = var.cluster_name
  namespace       = "default"
  service_account = "my-service-account"
  role_arn        = aws_iam_role.example.arn
}
```

**Helm values:**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/MyRole"
```

### With IRSA (Legacy)

When using IRSA:
1. IAM role must have trust policy for OIDC provider
2. Use `eks.amazonaws.com/role-arn` annotation in service account
3. EKS automatically injects credentials

**Terraform:**
```hcl
resource "aws_iam_role" "example" {
  name = "MyRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:default:my-service-account"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}
```

**Helm values:**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/MyRole"
```

## Configuration in This Repository

### Terraform Toggle

Control which method is used via Terraform variables:

```hcl
# Enable Pod Identity globally
enable_pod_identity = true

# Or disable for specific services
enable_pod_identity_metrics_server = false
```

### IAM Role Naming

Terraform creates different roles based on the authentication method:

**Pod Identity roles:**
```
EKS-ExternalDNS-Role-dev
EKS-ExternalDNS-Role-prod
```

**IRSA roles:**
```
EKS-ExternalDNS-Role-irsa-dev
EKS-ExternalDNS-Role-irsa-prod
```

### Helm Values Configuration

Update the role ARN in your values files based on which method you're using:

**For Pod Identity:**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/EKS-ExternalDNS-Role-prod"
```

**For IRSA:**
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/EKS-ExternalDNS-Role-irsa-prod"
```

### Getting Role ARNs from Terraform

After running `terraform apply`, get the correct ARNs:

```bash
# For Pod Identity
terraform output helm_role_arns

# For IRSA (when enable_pod_identity = false)
terraform output -json | jq '.helm_role_arns.value'
```

The `helm_role_arns` output automatically returns the correct ARN based on your configuration.

## Chart-Specific Configuration

### Charts with Single Service Account

Most charts (metrics-server, external-dns, cluster-autoscaler, etc.):

```yaml
serviceAccount:
  create: true
  name: my-service-account
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/MyRole"
```

### Charts with Multiple Service Accounts

Some charts like EFS CSI Driver have multiple service accounts:

```yaml
controller:
  serviceAccount:
    create: true
    name: efs-csi-controller-sa
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EFS-Role"

node:
  serviceAccount:
    create: true
    name: efs-csi-node-sa
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EFS-Role"
```

## Switching Between Methods

### From IRSA to Pod Identity

1. **Enable Pod Identity in Terraform:**
   ```hcl
   enable_pod_identity = true
   ```

2. **Apply Terraform:**
   ```bash
   terraform apply
   ```
   This creates Pod Identity associations.

3. **Redeploy Helm charts:**
   ```bash
   helm upgrade --install <chart> ...
   ```
   No changes needed to values files!

4. **Verify:**
   ```bash
   kubectl describe sa <service-account> -n <namespace>
   aws eks list-pod-identity-associations --cluster-name <cluster>
   ```

### From Pod Identity to IRSA

1. **Disable Pod Identity in Terraform:**
   ```hcl
   enable_pod_identity = false
   ```

2. **Apply Terraform:**
   ```bash
   terraform apply
   ```
   This removes Pod Identity associations but keeps IAM roles.

3. **Redeploy Helm charts:**
   ```bash
   helm upgrade --install <chart> ...
   ```
   No changes needed to values files!

4. **Verify:**
   ```bash
   kubectl describe sa <service-account> -n <namespace>
   # Should see: eks.amazonaws.com/role-arn annotation
   ```

## Verification

### Check Service Account

```bash
kubectl get sa <service-account> -n <namespace> -o yaml
```

Should show:
```yaml
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/MyRole
```

### Check Pod Identity Associations

```bash
aws eks list-pod-identity-associations \
  --cluster-name my-cluster \
  --region us-east-1
```

### Check Pod Credentials

```bash
kubectl exec -it <pod> -n <namespace> -- env | grep AWS
```

Should show AWS credentials environment variables.

### Test AWS Access

```bash
kubectl exec -it <pod> -n <namespace> -- aws sts get-caller-identity
```

Should return the assumed role ARN.

## Troubleshooting

### Pod Can't Assume Role

**With Pod Identity:**
- Check Pod Identity association exists: `aws eks list-pod-identity-associations`
- Check Pod Identity Agent is running: `kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent`
- Check service account annotation matches association

**With IRSA:**
- Check OIDC provider exists: `aws iam list-open-id-connect-providers`
- Check IAM role trust policy includes correct OIDC conditions
- Check service account annotation matches role ARN

### Wrong Credentials

```bash
# Check what identity the pod is using
kubectl exec -it <pod> -n <namespace> -- aws sts get-caller-identity

# Should show the role ARN, not node instance profile
```

## Best Practices

1. ✅ **Use Pod Identity for new clusters** (EKS 1.24+)
2. ✅ **Keep the same annotation format** for both methods
3. ✅ **Use Terraform to manage associations** and roles
4. ✅ **Test in dev before prod** when switching methods
5. ✅ **Monitor pod logs** after switching authentication methods
6. ❌ **Don't mix methods** for the same service account
7. ❌ **Don't manually create** Pod Identity associations (use Terraform)

## References

- [EKS Pod Identity Documentation](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Service Account Annotations](https://docs.aws.amazon.com/eks/latest/userguide/pod-configuration.html)
