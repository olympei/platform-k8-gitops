# ExternalDNS Values Files Guide

## Available Values Files

This directory contains two sets of values files for different deployment methods:

### 1. Wrapper-Based Deployment (Current/Default)

**Files:**
- `values-dev.yaml` - Dev environment with wrapper
- `values-prod.yaml` - Prod environment with wrapper

**Structure:**
```yaml
external-dns:
  image:
    repository: registry.k8s.io/external-dns/external-dns
    tag: v0.19.0
  serviceAccount:
    create: true
  # ... other settings
```

**When to use:**
- When using the parent chart with dependencies (current setup)
- When deploying via GitLab CI/CD (configured for wrapper structure)
- Consistent with other charts in this repository

**Deployment:**
```bash
# Via GitLab CI/CD (recommended)
# Trigger job: deploy:external-dns:dev or deploy:external-dns:prod

# Manual deployment
helm upgrade --install external-dns ./charts/external-dns \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-dev.yaml \
  --wait --timeout 10m
```

### 2. Direct Chart Deployment

**Files:**
- `values-dev-direct.yaml` - Dev environment without wrapper
- `values-prod-direct.yaml` - Prod environment without wrapper

**Structure:**
```yaml
image:
  repository: registry.k8s.io/external-dns/external-dns
  tag: v0.19.0
serviceAccount:
  create: true
# ... other settings
```

**When to use:**
- When deploying the chart directly without wrapper
- For testing or standalone deployments
- When you want to use the official chart structure

**Deployment:**
```bash
# Direct deployment using the packaged chart
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-dev-direct.yaml \
  --wait --timeout 10m
```

## Key Differences

| Aspect | Wrapper (Default) | Direct |
|--------|------------------|--------|
| **Values Structure** | Nested under `external-dns:` | Root level |
| **Chart.yaml** | Has dependencies section | No dependencies |
| **Deployment** | Via parent chart | Via packaged chart directly |
| **GitLab CI/CD** | ✅ Configured | ❌ Not configured |
| **Customization** | Can add custom templates | Uses chart as-is |

## Configuration Comparison

### Wrapper Format (values-dev.yaml)
```yaml
external-dns:
  provider: aws
  domainFilters:
    - "dev.example.com"
  extraArgs:
    - --log-level=info
```

### Direct Format (values-dev-direct.yaml)
```yaml
provider:
  name: aws
domainFilters:
  - "dev.example.com"
extraArgs:
  - --aws-zone-type=private
  - --log-level=info
```

## AWS-Specific Configuration

Both formats support the same AWS configuration, but the structure differs:

### Wrapper Format
```yaml
external-dns:
  provider: aws
  aws:
    region: us-east-1
    zoneType: private
```

### Direct Format
```yaml
provider:
  name: aws
extraArgs:
  - --aws-zone-type=private
  - --aws-batch-change-size=1000
```

**Note:** In direct format, AWS-specific settings are passed via `extraArgs` as command-line flags.

## IAM Configuration

Both formats use the same IAM role annotations:

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-{env}"
    eks.amazonaws.com/pod-identity-association-role-arn: "arn:aws:iam::ACCOUNT_ID:role/EKS-ExternalDNS-Role-{env}"
```

## Recommendation

**Use the wrapper-based files (default)** unless you have a specific reason to use direct deployment:

✅ **Wrapper (values-dev.yaml, values-prod.yaml):**
- Integrated with GitLab CI/CD
- Consistent with other charts
- Easier to manage custom configurations
- Current production setup

⚠️ **Direct (values-dev-direct.yaml, values-prod-direct.yaml):**
- For testing or standalone use
- Requires manual deployment
- Not integrated with CI/CD pipeline

## Converting Between Formats

### From Wrapper to Direct

1. Remove the `external-dns:` wrapper key
2. Move all nested values to root level
3. Convert AWS settings to `extraArgs` flags
4. Update provider format from `provider: aws` to `provider: { name: aws }`

### From Direct to Wrapper

1. Add `external-dns:` wrapper key
2. Nest all values under it
3. Convert `extraArgs` AWS flags to `aws:` section
4. Update provider format from `provider: { name: aws }` to `provider: aws`

## Testing

### Test Wrapper Deployment
```bash
# Dry run
helm upgrade --install external-dns ./charts/external-dns \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-dev.yaml \
  --dry-run --debug

# Actual deployment
helm upgrade --install external-dns ./charts/external-dns \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-dev.yaml \
  --wait --timeout 10m
```

### Test Direct Deployment
```bash
# Dry run
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-dev-direct.yaml \
  --dry-run --debug

# Actual deployment
helm upgrade --install external-dns \
  ./charts/external-dns/charts/external-dns-1.19.0.tgz \
  -n external-dns --create-namespace \
  -f charts/external-dns/values-dev-direct.yaml \
  --wait --timeout 10m
```

## Verification

After deployment with either method:

```bash
# Check pods
kubectl -n external-dns get pods

# Check version
kubectl -n external-dns get deployment external-dns \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check logs
kubectl -n external-dns logs -l app.kubernetes.io/name=external-dns --tail=50

# Check service account
kubectl -n external-dns get sa external-dns -o yaml
```

## Summary

- **Default:** Use wrapper-based files (`values-dev.yaml`, `values-prod.yaml`)
- **Alternative:** Use direct files (`values-dev-direct.yaml`, `values-prod-direct.yaml`) for standalone deployments
- **GitLab CI/CD:** Only configured for wrapper-based deployment
- **Both formats:** Support the same features and IAM configuration

Choose the format that best fits your deployment workflow!
