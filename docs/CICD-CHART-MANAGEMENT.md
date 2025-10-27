# GitLab CI/CD Chart Management Guide

This guide explains how to manage EKS add-on charts entirely through GitLab CI/CD variables and pipeline jobs.

## Overview

The GitLab CI/CD pipeline provides complete chart lifecycle management through:
- **Environment Variables**: Control chart installation/uninstallation
- **Pipeline Jobs**: Execute chart operations
- **Manual Triggers**: Safety controls for destructive operations

## Pipeline Stages

1. **validate** - Lint and validate charts
2. **plan** - Preview changes (merge requests)
3. **deploy** - Install/upgrade charts
4. **verify** - Verify cluster state
5. **uninstall** - Remove charts
6. **status** - Check chart status

## Environment Variables

### Chart Installation Control
Set these variables in GitLab Project Settings > CI/CD > Variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALL_AWS_EFS_CSI_DRIVER` | `true` | Enable/disable EFS CSI driver |
| `INSTALL_EXTERNAL_SECRETS_OPERATOR` | `true` | Enable/disable External Secrets |
| `INSTALL_INGRESS_NGINX` | `true` | Enable/disable Ingress NGINX |
| `INSTALL_POD_IDENTITY` | `true` | Enable/disable Pod Identity |

**Values**: `true`/`false`, `1`/`0`, `yes`/`no`

### Chart Uninstallation Control
Set these variables to mark charts for removal:

| Variable | Default | Description |
|----------|---------|-------------|
| `UNINSTALL_AWS_EFS_CSI_DRIVER` | `false` | Mark EFS CSI driver for removal |
| `UNINSTALL_EXTERNAL_SECRETS_OPERATOR` | `false` | Mark External Secrets for removal |
| `UNINSTALL_INGRESS_NGINX` | `false` | Mark Ingress NGINX for removal |
| `UNINSTALL_POD_IDENTITY` | `false` | Mark Pod Identity for removal |

**Values**: `true`/`false`, `1`/`0`, `yes`/`no`

### Environment Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `DEV_KUBECONFIG_B64` | Base64 encoded kubeconfig for dev cluster | Yes |
| `PROD_KUBECONFIG_B64` | Base64 encoded kubeconfig for prod cluster | Yes |
| `HELM_RELEASES_DEV` | Comma-separated list of charts for dev | No |
| `HELM_RELEASES_PROD` | Comma-separated list of charts for prod | No |

### Namespace Overrides

| Variable | Default | Description |
|----------|---------|-------------|
| `HELM_NAMESPACE_AWS_EFS_CSI_DRIVER` | `aws-efs-csi-driver` | Override EFS CSI namespace |
| `HELM_NAMESPACE_EXTERNAL_SECRETS_OPERATOR` | `external-secrets-operator` | Override External Secrets namespace |
| `HELM_NAMESPACE_INGRESS_NGINX` | `ingress-nginx` | Override Ingress NGINX namespace |
| `HELM_NAMESPACE_POD_IDENTITY` | `pod-identity` | Override Pod Identity namespace |

## Pipeline Jobs

### Validation Jobs
- `validate:helm` - Lint all enabled charts
- `validate:kustomize` - Validate Kustomize overlays

### Deployment Jobs

#### All Charts
- `deploy:helm:dev` - Deploy all enabled charts to dev
- `deploy:helm:prod` - Deploy all enabled charts to prod

#### Individual Charts
- `deploy:efs-csi:dev/prod` - Deploy EFS CSI driver
- `deploy:external-secrets:dev/prod` - Deploy External Secrets
- `deploy:ingress-nginx:dev/prod` - Deploy Ingress NGINX
- `deploy:pod-identity:dev/prod` - Deploy Pod Identity

### Uninstall Jobs

#### All Charts
- `uninstall:helm:dev` - Uninstall all marked charts from dev
- `uninstall:helm:prod` - Uninstall all marked charts from prod

#### Individual Charts
- `uninstall:efs-csi:dev/prod` - Uninstall EFS CSI driver
- `uninstall:external-secrets:dev/prod` - Uninstall External Secrets
- `uninstall:ingress-nginx:dev/prod` - Uninstall Ingress NGINX
- `uninstall:pod-identity:dev/prod` - Uninstall Pod Identity

### Status Jobs
- `status:dev` - Check chart status in dev environment
- `status:prod` - Check chart status in prod environment

### Verification Jobs
- `verify:dev` - Verify dev cluster state
- `verify:prod` - Verify prod cluster state

## Usage Examples

### 1. Deploy All Charts to Dev
1. Ensure all `INSTALL_*` variables are set to `true` (default)
2. Go to GitLab project > CI/CD > Pipelines
3. Run pipeline on `main` branch
4. Manually trigger `deploy:helm:dev` job

### 2. Skip a Chart During Deployment
1. Set `INSTALL_INGRESS_NGINX=false` in CI/CD variables
2. Run `deploy:helm:dev` - Ingress NGINX will be skipped

### 3. Deploy Only Specific Chart
1. Manually trigger `deploy:external-secrets:dev` job
2. Only External Secrets will be deployed

### 4. Uninstall a Chart
1. Set `UNINSTALL_INGRESS_NGINX=true` in CI/CD variables
2. Manually trigger `uninstall:helm:dev` job
3. Only charts marked for uninstall will be removed

### 5. Check Chart Status
1. Manually trigger `status:dev` job
2. View detailed status of all charts

## Workflow Examples

### Adding a New Chart
1. Create chart directory in `charts/`
2. Add values files for dev/prod environments
3. Chart will be auto-detected and deployed

### Removing a Chart Temporarily
```bash
# Set in GitLab CI/CD Variables
INSTALL_CHART_NAME=false
```

### Removing a Chart Permanently
```bash
# Set in GitLab CI/CD Variables
UNINSTALL_CHART_NAME=true
```
Then run uninstall job and remove chart directory.

### Environment Promotion
1. Test in dev: `deploy:helm:dev`
2. Verify: `status:dev`
3. Promote to prod: `deploy:helm:prod`

## Safety Features

### Manual Triggers
- All deploy/uninstall jobs require manual trigger
- Prevents accidental deployments

### Validation
- Charts are linted before deployment
- Values files are checked for existence

### Status Reporting
- Detailed status information for troubleshooting
- Pod health checks included

### Rollback Support
- Helm rollback can be performed manually:
```bash
helm rollback RELEASE_NAME REVISION -n NAMESPACE
```

## Troubleshooting

### Chart Not Deploying
1. Check `INSTALL_*` variable is not set to `false`
2. Verify values file exists: `charts/CHART/values-ENV.yaml`
3. Check pipeline logs for specific errors

### Chart Not Uninstalling
1. Verify `UNINSTALL_*` variable is set to `true`
2. Check if chart is actually deployed: run `status:ENV` job
3. Review uninstall job logs

### Permission Issues
1. Verify kubeconfig variables are correctly set
2. Check cluster connectivity in job logs
3. Ensure service account has required permissions

### Namespace Issues
1. Check namespace override variables
2. Verify namespace exists or can be created
3. Review RBAC permissions for namespace

## Best Practices

### Variable Management
- Use GitLab environments for different variable sets
- Document variable changes in merge requests
- Use protected variables for production

### Deployment Strategy
- Always test in dev first
- Use status jobs to verify deployments
- Keep uninstall variables as `false` by default

### Monitoring
- Monitor pipeline job success/failure
- Set up alerts for failed deployments
- Regular status checks on production

### Security
- Protect production variables
- Use separate kubeconfigs for each environment
- Regular rotation of kubeconfig credentials

## Advanced Configuration

### Custom Chart Lists
```bash
# Deploy only specific charts
HELM_RELEASES_DEV="aws-efs-csi-driver,ingress-nginx"
HELM_RELEASES_PROD="aws-efs-csi-driver,external-secrets-operator,ingress-nginx"
```

### Custom Namespaces
```bash
# Override default namespaces
HELM_NAMESPACE_INGRESS_NGINX="custom-ingress"
HELM_NAMESPACE_EXTERNAL_SECRETS_OPERATOR="secrets"
```

### Environment-Specific Control
Use GitLab environments to set different variables for dev/prod:
- Environment: `dev` - Set dev-specific variables
- Environment: `prod` - Set prod-specific variables

This provides complete chart lifecycle management through GitLab CI/CD without requiring external scripts or manual intervention.