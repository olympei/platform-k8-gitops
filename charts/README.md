# EKS Add-ons Helm Charts

This directory contains Helm charts for EKS add-ons. Each chart is stored as a `.tgz` file and deployed directly without wrapper charts.

## Chart Structure

Each chart directory contains:
- `charts/*.tgz` - The packaged Helm chart
- `values-dev.yaml` - Development environment configuration
- `values-prod.yaml` - Production environment configuration

## Available Charts

| Chart | Version | Description |
|-------|---------|-------------|
| aws-efs-csi-driver | 3.2.4 | AWS EFS CSI Driver for persistent storage |
| aws-load-balancer-controller | 1.14.1 | AWS Load Balancer Controller for ALB/NLB |
| cluster-autoscaler | 9.52.1 | Cluster Autoscaler for node scaling |
| external-dns | 1.19.0 | External DNS for Route 53 integration |
| external-secrets-operator | 0.20.4 | External Secrets Operator |
| ingress-nginx | 4.13.3 | NGINX Ingress Controller |
| metrics-server | 3.13.0 | Metrics Server for resource metrics |

| secrets-store-csi-driver | 1.5.4 | Secrets Store CSI Driver |

## Deployment Pattern

All charts follow the same deployment pattern - direct installation from the .tgz file:

```bash
helm upgrade --install <release-name> \
  charts/<chart-name>/charts/<chart-tgz-file> \
  -n <namespace> \
  --create-namespace \
  -f charts/<chart-name>/values-<env>.yaml
```

### Example: Deploy Metrics Server

```bash
# Development
helm upgrade --install metrics-server \
  charts/metrics-server/charts/metrics-server-3.12.1.tgz \
  -n kube-system \
  -f charts/metrics-server/values-dev.yaml

# Production
helm upgrade --install metrics-server \
  charts/metrics-server/charts/metrics-server-3.12.1.tgz \
  -n kube-system \
  -f charts/metrics-server/values-prod.yaml
```

## Helm Chart Repositories

Each chart is sourced from its official Helm repository:

| Chart | Repository Name | Repository URL | Version |
|-------|----------------|----------------|---------|
| aws-efs-csi-driver | aws-efs-csi-driver | https://kubernetes-sigs.github.io/aws-efs-csi-driver/ | 3.2.4 |
| aws-load-balancer-controller | eks | https://aws.github.io/eks-charts | 1.14.1 |
| cluster-autoscaler | autoscaler | https://kubernetes.github.io/autoscaler | 9.52.1 |
| external-dns | external-dns | https://kubernetes-sigs.github.io/external-dns/ | 1.19.0 |
| external-secrets | external-secrets | https://charts.external-secrets.io | 0.20.4 |
| ingress-nginx | ingress-nginx | https://kubernetes.github.io/ingress-nginx | 4.13.3 |
| metrics-server | metrics-server | https://kubernetes-sigs.github.io/metrics-server/ | 3.13.0 |

| secrets-store-csi-driver | secrets-store-csi-driver | https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts | 1.5.4 |

## Download Charts

If you need to download or update chart .tgz files:

```bash
# Add all repositories
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo add eks https://aws.github.io/eks-charts
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo add external-secrets https://charts.external-secrets.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update

# Download specific charts
helm pull aws-efs-csi-driver/aws-efs-csi-driver --version 3.2.4
helm pull eks/aws-load-balancer-controller --version 1.14.1
helm pull autoscaler/cluster-autoscaler --version 9.52.1
helm pull external-dns/external-dns --version 1.19.0
helm pull external-secrets/external-secrets --version 0.20.4
helm pull ingress-nginx/ingress-nginx --version 4.13.3
helm pull metrics-server/metrics-server --version 3.13.0

helm pull secrets-store-csi-driver/secrets-store-csi-driver --version 1.5.4

# Move to appropriate directories
mv aws-efs-csi-driver-3.2.4.tgz charts/aws-efs-csi-driver/charts/
mv aws-load-balancer-controller-1.14.1.tgz charts/aws-load-balancer-controller/charts/
mv cluster-autoscaler-9.52.1.tgz charts/cluster-autoscaler/charts/
mv external-dns-1.19.0.tgz charts/external-dns/charts/
mv external-secrets-0.20.4.tgz charts/external-secrets-operator/charts/
mv ingress-nginx-4.13.3.tgz charts/ingress-nginx/charts/
mv metrics-server-3.13.0.tgz charts/metrics-server/charts/

mv secrets-store-csi-driver-1.5.4.tgz charts/secrets-store-csi-driver/charts/

# Or use the automated download script
./scripts/download-all-dependencies.sh
```

## Configuration

Before deploying, update the values files with your environment-specific settings:

**Common required fields:**
- Cluster name
- AWS region
- IAM role ARNs
- VPC/subnet IDs (where applicable)

See individual chart directories for specific configuration requirements.

## Deployment via GitLab CI/CD

Charts can be deployed through the GitLab CI/CD pipeline. Enable/disable charts using environment variables:

```yaml
# Enable chart installation
INSTALL_METRICS_SERVER: "true"
INSTALL_CLUSTER_AUTOSCALER: "true"

# Disable chart installation
INSTALL_INGRESS_NGINX: "false"
```

See `.gitlab-ci.yml` for full CI/CD configuration.

## Benefits of This Pattern

✅ **No wrapper charts** - Simpler structure  
✅ **No dependency builds** - Charts are ready to deploy  
✅ **Version locked** - Exact chart versions in repository  
✅ **Air-gap friendly** - Works offline  
✅ **Faster deployments** - No remote fetching  

## Troubleshooting

### Chart not found

Ensure the .tgz file exists:
```bash
ls -l charts/*/charts/*.tgz
```

### Download missing charts

```bash
./scripts/download-all-dependencies.sh
```

### Verify chart contents

```bash
helm show chart charts/metrics-server/charts/metrics-server-3.12.1.tgz
helm show values charts/metrics-server/charts/metrics-server-3.12.1.tgz
```

## References

- [Helm Documentation](https://helm.sh/docs/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- Individual chart documentation in each directory
