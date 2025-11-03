# Values Files Update Summary

All Helm chart values files have been updated with BOTH annotations pointing to a **unified IAM role** that supports both Pod Identity and IRSA authentication methods.

## Unified Role Naming Pattern

All services use a single role:
```
EKS-<ServiceName>-Role-<environment>
```

Examples:
- `EKS-ExternalDNS-Role-dev`
- `EKS-ExternalDNS-Role-prod`
- `EKS-EFS-CSI-DriverRole-dev`

**Note**: There is NO `-irsa-` suffix. The same role works for both authentication methods.

## Annotation Format

All serviceAccount annotations now include BOTH annotations pointing to the **SAME role**:

```yaml
serviceAccount:
  annotations:
    # IRSA annotation (used when authMethod is "irsa")
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ServiceName-Role-env"
    # Pod Identity annotation (used when authMethod is "pod-identity")
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ServiceName-Role-env"
```

**Key Points:**
- Both annotations point to the **same role ARN**
- The role has a combined trust policy supporting both IRSA and Pod Identity
- Kubernetes automatically uses the appropriate annotation based on your cluster configuration
- No need to change values files when switching authentication methods

### List of Updated Files

**AWS EFS CSI Driver:**
- `charts/aws-efs-csi-driver/values-dev.yaml` (controller, node, and podIdentity sections)
- `charts/aws-efs-csi-driver/values-prod.yaml` (controller, node, and podIdentity sections)

**AWS Load Balancer Controller:**
- `charts/aws-load-balancer-controller/values-dev.yaml`
- `charts/aws-load-balancer-controller/values-prod.yaml`

**Cluster Autoscaler:**
- `charts/cluster-autoscaler/values-dev.yaml`
- `charts/cluster-autoscaler/values-prod.yaml`

**External DNS:**
- `charts/external-dns/values-dev.yaml`
- `charts/external-dns/values-prod.yaml`

**External Secrets Operator:**
- `charts/external-secrets-operator/values-dev.yaml`
- `charts/external-secrets-operator/values-prod.yaml`

**Ingress NGINX:**
- `charts/ingress-nginx/values-dev.yaml`
- `charts/ingress-nginx/values-prod.yaml`
- `charts/ingress-nginx/values-external.yaml`

**Metrics Server:**
- `charts/metrics-server/values-dev.yaml`
- `charts/metrics-server/values-prod.yaml`

**Pod Identity Agent:**
- `charts/pod-identity/values-dev.yaml`
- `charts/pod-identity/values-prod.yaml`

**Secrets Store CSI Driver:**
- `charts/secrets-store-csi-driver/values-dev.yaml`
- `charts/secrets-store-csi-driver/values-prod.yaml`

## How to Use

1. **Replace ACCOUNT_ID** with your actual AWS account ID in both annotations

2. **Deploy the chart** - The authentication method configured in your cluster will determine which annotation is used:
   - If using **Pod Identity**: Kubernetes uses `eks.amazonaws.com/pod-identity-association-role-arn`
   - If using **IRSA**: Kubernetes uses `eks.amazonaws.com/role-arn`

3. **No need to modify values files** when switching authentication methods - both annotations point to the same role!

## Example

For External DNS in production, the values file contains:

```yaml
serviceAccount:
  annotations:
    # IRSA annotation (used when authMethod is "irsa")
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/EKS-ExternalDNS-Role-prod"
    # Pod Identity annotation (used when authMethod is "pod-identity")
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::123456789012:role/EKS-ExternalDNS-Role-prod"
```

When you deploy:
- **With Pod Identity enabled**: The pod assumes `EKS-ExternalDNS-Role-prod` via Pod Identity
- **With IRSA enabled**: The pod assumes `EKS-ExternalDNS-Role-prod` via IRSA

**Same role, different authentication method!**

## Related Documentation

- `docs/ROLE-ARN-REFERENCE.md` - Complete role ARN reference for all services
- `docs/POD-IDENTITY-VS-IRSA.md` - Detailed comparison of authentication methods
- `terraform/iam-roles.tf` - Terraform configuration creating these roles
