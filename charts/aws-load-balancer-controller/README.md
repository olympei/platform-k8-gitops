# AWS Load Balancer Controller

This directory contains the AWS Load Balancer Controller chart (.tgz) and configuration values for deployment.

## Files

- `aws-load-balancer-controller-1.14.1.tgz` - The Helm chart package
- `values-dev.yaml` - Development environment configuration
- `values-prod.yaml` - Production environment configuration

## Deployment

Deploy directly from the .tgz file without needing a wrapper chart:

### Development Environment

```bash
helm upgrade --install aws-load-balancer-controller \
  charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  -n kube-system \
  --create-namespace \
  -f charts/aws-load-balancer-controller/values-dev.yaml
```

### Production Environment

```bash
helm upgrade --install aws-load-balancer-controller \
  charts/aws-load-balancer-controller/charts/aws-load-balancer-controller-1.14.1.tgz \
  -n kube-system \
  --create-namespace \
  -f charts/aws-load-balancer-controller/values-prod.yaml
```

## Configuration

Before deploying, update the values files with your cluster information:

**Required fields:**
- `clusterName` - Your EKS cluster name
- `region` - AWS region
- `vpcId` - VPC ID where your cluster is deployed
- `serviceAccount.annotations.eks.amazonaws.com/role-arn` - IAM role ARN

Example:
```yaml
aws-load-balancer-controller:
  clusterName: "my-eks-cluster-prod"
  region: "us-east-1"
  vpcId: "vpc-0123456789abcdef"
  
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/EKS-AWSLoadBalancerController-Role-prod"
```

## Verification

Check the deployment:

```bash
# Check pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Check webhook
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
```

## Uninstall

```bash
helm uninstall aws-load-balancer-controller -n kube-system
```

## IAM Configuration

The IAM policy and Terraform configuration are located in:
- IAM Policy: `iam/aws-load-balancer-controller-policy.json`
- Terraform: `terraform/locals.tf` (includes service account and role configuration)

## References

- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Helm Chart Repository](https://github.com/aws/eks-charts)
