# AWS EKS Pod Identity Agent

**Note:** The EKS Pod Identity Agent is **not available as a Helm chart**. It must be installed as an **EKS add-on** using the AWS CLI or AWS Console.

## Installation via AWS CLI

### Enable Pod Identity Add-on

```bash
# Enable the EKS Pod Identity Agent add-on
aws eks create-addon \
  --cluster-name my-eks-cluster \
  --addon-name eks-pod-identity-agent \
  --region us-east-1
```

### Check Add-on Status

```bash
# Check if the add-on is installed
aws eks describe-addon \
  --cluster-name my-eks-cluster \
  --addon-name eks-pod-identity-agent \
  --region us-east-1
```

### Update Add-on

```bash
# Update to latest version
aws eks update-addon \
  --cluster-name my-eks-cluster \
  --addon-name eks-pod-identity-agent \
  --region us-east-1
```

### Remove Add-on

```bash
# Remove the add-on
aws eks delete-addon \
  --cluster-name my-eks-cluster \
  --addon-name eks-pod-identity-agent \
  --region us-east-1
```

## Installation via Terraform

```hcl
resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "eks-pod-identity-agent"
  
  addon_version = "v1.3.2-eksbuild.2"  # Check for latest version
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Verification

Check that the Pod Identity Agent is running:

```bash
# Check DaemonSet
kubectl get daemonset eks-pod-identity-agent -n kube-system

# Check pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=eks-pod-identity-agent --tail=50
```

## Using Pod Identity

Once the agent is installed, you can create Pod Identity associations:

### Via AWS CLI

```bash
aws eks create-pod-identity-association \
  --cluster-name my-eks-cluster \
  --namespace default \
  --service-account my-service-account \
  --role-arn arn:aws:iam::123456789012:role/MyRole \
  --region us-east-1
```

### Via Terraform

See `terraform/pod-identity-associations.tf` for examples.

## Why Not a Helm Chart?

The EKS Pod Identity Agent is:
- Deeply integrated with EKS control plane
- Managed by AWS as a native add-on
- Automatically updated by AWS
- Requires specific EKS cluster permissions

Using the EKS add-on ensures:
- ✅ Compatibility with your EKS version
- ✅ Automatic security updates
- ✅ AWS support
- ✅ Proper integration with EKS

## Alternative: Manual DaemonSet Installation

If you cannot use EKS add-ons, you can install manually:

```bash
kubectl apply -f https://raw.githubusercontent.com/aws/eks-pod-identity-agent/main/deploy/eks-pod-identity-agent.yaml
```

However, this is **not recommended** as you lose the benefits of managed add-ons.

## References

- [EKS Pod Identity Documentation](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [EKS Add-ons Documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
- [Pod Identity Agent GitHub](https://github.com/aws/eks-pod-identity-agent)
