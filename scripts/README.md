# Scripts Documentation

This directory contains utility scripts for managing Helm charts and their dependencies.

## Chart Dependency Management

### download-all-dependencies.sh

Downloads all chart dependencies for every chart in the `charts/` directory.

**Usage:**
```bash
# Normal usage
./scripts/download-all-dependencies.sh

# Skip TLS verification (for corporate proxies)
SKIP_TLS_VERIFY=true ./scripts/download-all-dependencies.sh
```

**What it does:**
- Scans all charts in the `charts/` directory
- Extracts repository URLs from each Chart.yaml
- Adds repositories to Helm
- Downloads dependencies using `helm dependency build`
- Stores dependencies in each chart's `charts/` subdirectory

**Output:**
```
charts/
├── aws-efs-csi-driver/
│   ├── Chart.yaml
│   ├── Chart.lock
│   ├── charts/
│   │   └── aws-efs-csi-driver-2.5.0.tgz
│   └── values-*.yaml
├── external-secrets-operator/
│   ├── Chart.yaml
│   ├── Chart.lock
│   ├── charts/
│   │   └── external-secrets-0.9.11.tgz
│   └── values-*.yaml
...
```

---

### download-and-package-charts.sh

Downloads all dependencies AND packages everything into a zip/tar.gz file for offline deployment.

**Usage:**
```bash
# Create package in default directory
./scripts/download-and-package-charts.sh

# Specify custom output directory
./scripts/download-and-package-charts.sh my-charts-backup

# Skip TLS verification
SKIP_TLS_VERIFY=true ./scripts/download-and-package-charts.sh
```

**What it does:**
1. Downloads all chart dependencies
2. Copies all charts with their dependencies to output directory
3. Creates a timestamped zip/tar.gz package
4. Provides extraction instructions

**Output:**
```
helm-charts-20241027-143022.zip  (or .tar.gz)
```

**Package contents:**
```
helm-charts-20241027-143022.zip
├── aws-efs-csi-driver/
│   ├── Chart.yaml
│   ├── Chart.lock
│   ├── charts/
│   │   └── aws-efs-csi-driver-2.5.0.tgz
│   └── values-*.yaml
├── external-secrets-operator/
│   ├── Chart.yaml
│   ├── Chart.lock
│   ├── charts/
│   │   └── external-secrets-0.9.11.tgz
│   └── values-*.yaml
...
```

**Extracting and using:**
```bash
# Extract
unzip helm-charts-20241027-143022.zip -d my-charts
# or
tar -xzf helm-charts-20241027-143022.tar.gz -C my-charts

# Deploy
cd my-charts
helm upgrade --install platform-efs-csi-driver aws-efs-csi-driver \
  -n kube-system \
  -f aws-efs-csi-driver/values-prod.yaml
```

---

### build-chart-dependencies.sh

Builds dependencies for a single chart.

**Usage:**
```bash
# Build dependencies for a specific chart
./scripts/build-chart-dependencies.sh external-secrets-operator

# Skip TLS verification
SKIP_TLS_VERIFY=true ./scripts/build-chart-dependencies.sh external-secrets-operator
```

**What it does:**
- Extracts repositories from the specified chart's Chart.yaml
- Adds only the required repositories
- Downloads dependencies for that chart only

---

## Chart Management

### manage-charts.sh

Interactive script for managing chart installations and uninstallations.

**Usage:**
```bash
./scripts/manage-charts.sh
```

**Features:**
- List all available charts
- Install/upgrade specific charts
- Uninstall charts
- Check chart status
- Environment selection (dev/prod)

---

## Infrastructure Scripts

### configure-ingress-lb.sh

Configures load balancer settings for NGINX Ingress Controller.

**Usage:**
```bash
# Configure internal load balancer
./scripts/configure-ingress-lb.sh internal dev

# Configure external load balancer
./scripts/configure-ingress-lb.sh external prod
```

---

### manage-ssl-certificates.sh

Manages SSL certificates for load balancers using AWS Certificate Manager.

**Usage:**
```bash
# Add SSL certificate
./scripts/manage-ssl-certificates.sh add arn:aws:acm:us-east-1:123456789012:certificate/abc123

# List certificates
./scripts/manage-ssl-certificates.sh list

# Remove certificate
./scripts/manage-ssl-certificates.sh remove arn:aws:acm:us-east-1:123456789012:certificate/abc123
```

---

### get-oidc-info.sh

Retrieves OIDC provider information for EKS cluster.

**Usage:**
```bash
# Get OIDC info for cluster
./scripts/get-oidc-info.sh my-eks-cluster us-east-1

# Output includes:
# - OIDC Provider URL
# - OIDC Provider ARN
# - Thumbprint
```

---

## Common Use Cases

### Offline/Air-gapped Deployment

1. **On a machine with internet access:**
   ```bash
   # Download and package all charts
   ./scripts/download-and-package-charts.sh
   
   # Transfer helm-charts-*.zip to air-gapped environment
   ```

2. **On air-gapped machine:**
   ```bash
   # Extract package
   unzip helm-charts-20241027-143022.zip -d charts-offline
   
   # Deploy charts
   cd charts-offline
   helm upgrade --install platform-efs-csi-driver aws-efs-csi-driver \
     -n kube-system -f aws-efs-csi-driver/values-prod.yaml
   ```

### Corporate Proxy/TLS Issues

If you're behind a corporate proxy with TLS inspection:

```bash
# Set environment variable for all scripts
export SKIP_TLS_VERIFY=true

# Then run any script
./scripts/download-all-dependencies.sh
./scripts/download-and-package-charts.sh
./scripts/build-chart-dependencies.sh external-secrets-operator
```

### Pre-download Before CI/CD

To speed up CI/CD pipelines, pre-download dependencies:

```bash
# Download all dependencies locally
./scripts/download-all-dependencies.sh

# Commit the charts/ subdirectories
git add charts/*/charts/
git add charts/*/Chart.lock
git commit -m "Add pre-downloaded chart dependencies"
git push

# Now CI/CD can skip dependency download step
```

### Backup Charts

Create a backup of all charts with their dependencies:

```bash
# Create timestamped backup
./scripts/download-and-package-charts.sh charts-backup-$(date +%Y%m%d)

# Store the zip file safely
mv helm-charts-*.zip /backup/location/
```

---

## Troubleshooting

### TLS Certificate Errors

**Error:**
```
tls: failed to verify certificate: x509: certificate signed by unknown authority
```

**Solution:**
```bash
SKIP_TLS_VERIFY=true ./scripts/download-all-dependencies.sh
```

### Repository Not Found

**Error:**
```
Error: no cached repository found
```

**Solution:**
```bash
# Clear Helm cache and retry
rm -rf ~/.cache/helm/repository/*
./scripts/download-all-dependencies.sh
```

### Dependency Build Failed

**Error:**
```
Error: An error occurred while checking for chart dependencies
```

**Solution:**
```bash
# Try building specific chart
./scripts/build-chart-dependencies.sh <chart-name>

# Or force update
cd charts/<chart-name>
helm dependency update --skip-refresh
```

---

## Environment Variables

| Variable | Description | Default | Used By |
|----------|-------------|---------|---------|
| `SKIP_TLS_VERIFY` | Skip TLS certificate verification | `false` | All dependency scripts |
| `HELM_REPO_SKIP_TLS_VERIFY` | Helm-specific TLS skip (auto-set) | - | Set by scripts when needed |

---

## Notes

- All scripts are designed to be idempotent (safe to run multiple times)
- Dependencies are stored in `charts/*/charts/` subdirectories
- Chart.lock files track exact dependency versions
- Scripts work on Linux, macOS, and Windows (Git Bash/WSL)
