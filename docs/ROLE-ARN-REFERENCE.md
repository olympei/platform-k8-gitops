# Role ARN Reference Guide

This document provides the IAM role ARNs for all EKS services. Each role uses a **unified approach** with a combined trust policy that supports both IRSA and Pod Identity authentication methods.

## Unified Role Naming Pattern

All services use a single role:
```
EKS-<ServiceName>-Role-<environment>
```

**Key Point**: There is NO separate role for IRSA vs Pod Identity. The same role works for both authentication methods through a combined trust policy.

## Service Role ARNs

### AWS EFS CSI Driver

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-EFS-CSI-DriverRole-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-EFS-CSI-DriverRole-prod`

### External Secrets Operator

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalSecrets-Role-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalSecrets-Role-prod`

### Ingress NGINX

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-IngressNginx-Role-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-IngressNginx-Role-prod`

### Secrets Store CSI Driver

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-SecretsStore-Role-prod`

### Cluster Autoscaler

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-ClusterAutoscaler-Role-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-ClusterAutoscaler-Role-prod`

### Metrics Server

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-MetricsServer-Role-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-MetricsServer-Role-prod`

### External DNS

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-prod`

### AWS Load Balancer Controller

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-AWSLoadBalancerController-Role-prod`

### Pod Identity Agent

**Dev**: `arn:aws:iam::ACCOUNT_ID:role/EKS-PodIdentity-Role-dev`  
**Prod**: `arn:aws:iam::ACCOUNT_ID:role/EKS-PodIdentity-Role-prod`

## Getting Role ARNs from Terraform

After running `terraform apply`, get the actual ARNs:

```bash
# Get all role ARNs
terraform output helm_role_arns

# Get specific role ARN
terraform output external_dns_role_arn
```

## Values File Configuration

All values files use both annotations pointing to the **same role**:

```yaml
serviceAccount:
  annotations:
    # IRSA annotation (used when authMethod is "irsa")
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-prod"
    # Pod Identity annotation (used when authMethod is "pod-identity")
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-prod"
```

## How It Works

### Combined Trust Policy

Each role has a trust policy with two statements:

1. **Pod Identity Statement**: Allows `pods.eks.amazonaws.com` to assume the role
2. **IRSA Statement**: Allows the OIDC provider to assume the role with web identity

This means:
- The **same role** can be assumed via Pod Identity OR IRSA
- No need to change role ARNs when switching authentication methods
- Kubernetes automatically uses the appropriate annotation based on your cluster configuration

### Authentication Method Selection

The authentication method is determined by your Terraform configuration:

```hcl
# terraform/terraform.tfvars
enable_pod_identity = true  # or false
```

- **`true`**: Creates Pod Identity associations, pods use Pod Identity
- **`false`**: No Pod Identity associations, pods fall back to IRSA

## Deployment Example

### Step 1: Update ACCOUNT_ID

Replace `ACCOUNT_ID` in values files with your AWS account ID:

```yaml
# charts/external-dns/values-prod.yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/EKS-ExternalDNS-Role-prod"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::123456789012:role/EKS-ExternalDNS-Role-prod"
```

### Step 2: Deploy Chart

```bash
helm upgrade --install external-dns \
  charts/external-dns/charts/external-dns-1.19.0.tgz \
  -n external-dns \
  -f charts/external-dns/values-prod.yaml
```

### Step 3: Verify

```bash
# Check service account
kubectl get sa external-dns -n external-dns -o yaml

# Check pod credentials
kubectl exec -it <pod-name> -n external-dns -- aws sts get-caller-identity
```

## Switching Authentication Methods

To switch between IRSA and Pod Identity:

1. **Update Terraform**:
   ```hcl
   enable_pod_identity = true  # or false
   ```

2. **Apply Terraform**:
   ```bash
   terraform apply
   ```

3. **Redeploy charts** (to pick up Pod Identity associations if switching to Pod Identity):
   ```bash
   helm upgrade --install <chart> ...
   ```

**No need to modify values files!** Both annotations already point to the same role.

## Verification Commands

### Check Role Trust Policy

```bash
aws iam get-role --role-name EKS-ExternalDNS-Role-prod \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json
```

You should see both Pod Identity and IRSA statements.

### Check Service Account Annotations

```bash
kubectl get sa external-dns -n external-dns -o jsonpath='{.metadata.annotations}'
```

You should see both `eks.amazonaws.com/role-arn` and `eks.amazonaws.com/pod-identity-association-role-arn`.

### Check Active Authentication Method

```bash
# Check for Pod Identity associations
aws eks list-pod-identity-associations --cluster-name your-cluster

# If associations exist, Pod Identity is active
# If no associations, IRSA is active
```

### Check Assumed Role

```bash
kubectl exec -it <pod-name> -n <namespace> -- aws sts get-caller-identity
```

The `Arn` field shows which role the pod assumed.

## Troubleshooting

### Pod Can't Assume Role

1. **Check trust policy**:
   ```bash
   aws iam get-role --role-name EKS-ExternalDNS-Role-prod
   ```

2. **Check service account annotations**:
   ```bash
   kubectl get sa external-dns -n external-dns -o yaml
   ```

3. **Check Pod Identity associations** (if using Pod Identity):
   ```bash
   aws eks list-pod-identity-associations --cluster-name your-cluster
   ```

4. **Check OIDC provider** (if using IRSA):
   ```bash
   aws iam list-open-id-connect-providers
   ```

### Wrong Role Being Used

Check which authentication method is active:

```bash
# Describe the pod
kubectl describe pod <pod-name> -n <namespace>

# Look for:
# - Pod Identity: AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE environment variable
# - IRSA: AWS_WEB_IDENTITY_TOKEN_FILE environment variable
```

## Related Documentation

- `docs/UNIFIED-ROLE-APPROACH.md` - Detailed explanation of the unified role approach
- `docs/POD-IDENTITY-VS-IRSA.md` - Comparison of authentication methods
- `docs/VALUES-FILES-UPDATE-SUMMARY.md` - Values file configuration summary
- `terraform/iam-roles.tf` - Role definitions
- `terraform/data.tf` - Trust policy definitions
