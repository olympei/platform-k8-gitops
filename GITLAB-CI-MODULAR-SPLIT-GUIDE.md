# GitLab CI Modular Split Guide

## Overview

The `.gitlab-ci.yml` file has grown to 1842 lines. This guide explains how to split it into modular files for better maintainability.

## Proposed Structure

```
.gitlab-ci.yml                    # Main file (stages, defaults, includes)
.gitlab-ci/
├── helm-jobs.yml                 # All Helm deployment/uninstall jobs
├── k8s-resources-jobs.yml        # All K8s-resources deployment/uninstall jobs
├── validation-jobs.yml           # Validation and test jobs
└── verification-jobs.yml         # Verification and status jobs
```

## Benefits

1. **Maintainability** - Easier to find and update specific job types
2. **Readability** - Each file focuses on one concern
3. **Collaboration** - Team members can work on different files without conflicts
4. **Reusability** - Files can be included in other pipelines
5. **Performance** - GitLab caches included files

## Main .gitlab-ci.yml Structure

The main file should contain:
- Header documentation
- Stages definition
- Default configuration (before_script, image, etc.)
- Include statements for modular files

```yaml
# GitLab CI/CD Pipeline for EKS Add-ons
# Modular structure for better maintainability

stages:
  - validate
  - test
  - plan
  - deploy
  - verify
  - uninstall
  - status

default:
  image: alpine:3.20
  before_script:
    - echo "🔧 Setting up environment..."
    - apk add --no-cache bash curl git jq yq kubectl helm
    # ... rest of before_script

# Include modular job definitions
include:
  - local: '.gitlab-ci/validation-jobs.yml'
  - local: '.gitlab-ci/helm-jobs.yml'
  - local: '.gitlab-ci/k8s-resources-jobs.yml'
  - local: '.gitlab-ci/verification-jobs.yml'
```

## File Breakdown

### 1. validation-jobs.yml (Lines 1-412)

**Contains:**
- `validate:helm` - Helm chart linting
- `validate:kustomize` - Kustomize validation
- `test:dependencies` - Dependency tests
- `test:package` - Package tests
- `plan` - Kustomize diff

**Size:** ~400 lines

### 2. helm-jobs.yml (Lines 413-1230)

**Contains:**
- `.deploy_helm_hybrid` - Template for deploying all Helm charts
- `.deploy_single_chart` - Template for single chart deployment
- `deploy:helm:dev` / `deploy:helm:prod` - Batch deployment jobs
- `deploy:*:dev` / `deploy:*:prod` - Individual chart deployment jobs (20 jobs)
- `.uninstall_helm_all` - Template for uninstalling all charts
- `.uninstall_single_chart` - Template for single chart uninstall
- `uninstall:helm:dev` / `uninstall:helm:prod` - Batch uninstall jobs
- `uninstall:*:dev` / `uninstall:*:prod` - Individual chart uninstall jobs (20 jobs)

**Size:** ~820 lines

### 3. k8s-resources-jobs.yml (Lines 1231-1700)

**Contains:**
- `.uninstall_k8s_apps` - Template for uninstalling k8s-resources apps
- `.uninstall_k8s_app` - Alias template
- `uninstall:k8s:apps:dev` / `uninstall:k8s:apps:prod` - Batch uninstall
- `uninstall:k8s:*:dev` / `uninstall:k8s:*:prod` - Individual app uninstall (10 jobs)
- `.uninstall_kustomize` - Template for environment-level uninstall
- `uninstall:kustomize:dev` / `uninstall:kustomize:prod`
- `.deploy_kustomize` - Template for deploying kustomize resources
- `deploy:kustomize:dev` / `deploy:kustomize:prod`
- `.deploy_k8s_apps` - Template for deploying k8s-resources apps
- `deploy:k8s:apps:dev` / `deploy:k8s:apps:prod` - Batch deployment
- `.deploy_k8s_app` - Alias template
- `deploy:k8s:*:dev` / `deploy:k8s:*:prod` - Individual app deployment (10 jobs)

**Size:** ~470 lines

### 4. verification-jobs.yml (Lines 1701-1842)

**Contains:**
- `.verify_template` - Template for verification
- `verify:dev` / `verify:prod` - Verification jobs
- `.status_template` - Template for status checking
- `status:dev` / `status:prod` - Status jobs

**Size:** ~140 lines

## Implementation Steps

### Step 1: Create Directory

```bash
mkdir -p .gitlab-ci
```

### Step 2: Extract Validation Jobs

Create `.gitlab-ci/validation-jobs.yml`:

```yaml
# Validation and Testing Jobs
# Included in main .gitlab-ci.yml

validate:helm:
  stage: validate
  script:
    # ... (copy from main file)

validate:kustomize:
  stage: validate
  script:
    # ... (copy from main file)

test:dependencies:
  stage: test
  script:
    # ... (copy from main file)

test:package:
  stage: test
  script:
    # ... (copy from main file)

plan:
  stage: plan
  script:
    # ... (copy from main file)
```

### Step 3: Extract Helm Jobs

Create `.gitlab-ci/helm-jobs.yml`:

```yaml
# Helm Deployment and Uninstallation Jobs
# Included in main .gitlab-ci.yml

# ============================================================================
# HELM DEPLOYMENT JOBS
# ============================================================================

.deploy_helm_hybrid:
  stage: deploy
  script:
    # ... (copy from main file)

.deploy_single_chart:
  stage: deploy
  script:
    # ... (copy from main file)

# Batch deployment jobs
deploy:helm:dev:
  extends: .deploy_helm_hybrid
  variables:
    ENVIRONMENT: dev
    HELM_RELEASES: $HELM_RELEASES_DEV
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64

deploy:helm:prod:
  extends: .deploy_helm_hybrid
  variables:
    ENVIRONMENT: prod
    HELM_RELEASES: $HELM_RELEASES_PROD
    KUBECONFIG_DATA: $PROD_KUBECONFIG_B64

# Individual chart deployment jobs
# ... (all deploy:*:dev and deploy:*:prod jobs)

# ============================================================================
# HELM UNINSTALLATION JOBS
# ============================================================================

.uninstall_helm_all:
  stage: uninstall
  script:
    # ... (copy from main file)

.uninstall_single_chart:
  stage: uninstall
  script:
    # ... (copy from main file)

# Batch uninstall jobs
uninstall:helm:dev:
  extends: .uninstall_helm_all
  variables:
    ENVIRONMENT: dev
    HELM_RELEASES: $HELM_RELEASES_DEV
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64

uninstall:helm:prod:
  extends: .uninstall_helm_all
  variables:
    ENVIRONMENT: prod
    HELM_RELEASES: $HELM_RELEASES_PROD
    KUBECONFIG_DATA: $PROD_KUBECONFIG_B64

# Individual chart uninstall jobs
# ... (all uninstall:*:dev and uninstall:*:prod jobs)
```

### Step 4: Extract K8s-Resources Jobs

Create `.gitlab-ci/k8s-resources-jobs.yml`:

```yaml
# K8s-Resources Deployment and Uninstallation Jobs
# Included in main .gitlab-ci.yml

# ============================================================================
# K8S-RESOURCES UNINSTALLATION JOBS
# ============================================================================

.uninstall_k8s_apps:
  stage: uninstall
  script:
    # ... (copy from main file)

# ... (all k8s-resources uninstall jobs)

# ============================================================================
# K8S-RESOURCES DEPLOYMENT JOBS
# ============================================================================

.deploy_kustomize:
  stage: deploy
  script:
    # ... (copy from main file)

.deploy_k8s_apps:
  stage: deploy
  script:
    # ... (copy from main file)

# ... (all k8s-resources deployment jobs)
```

### Step 5: Extract Verification Jobs

Create `.gitlab-ci/verification-jobs.yml`:

```yaml
# Verification and Status Jobs
# Included in main .gitlab-ci.yml

.verify_template:
  stage: verify
  script:
    # ... (copy from main file)

verify:dev:
  extends: .verify_template
  variables:
    ENVIRONMENT: dev
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
  needs: ["deploy:kustomize:dev"]

verify:prod:
  extends: .verify_template
  variables:
    ENVIRONMENT: prod
    KUBECONFIG_DATA: $PROD_KUBECONFIG_B64
  needs: ["deploy:kustomize:prod"]

.status_template:
  stage: status
  script:
    # ... (copy from main file)

status:dev:
  extends: .status_template
  variables:
    ENVIRONMENT: dev
    HELM_RELEASES: $HELM_RELEASES_DEV
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64

status:prod:
  extends: .status_template
  variables:
    ENVIRONMENT: prod
    HELM_RELEASES: $HELM_RELEASES_PROD
    KUBECONFIG_DATA: $PROD_KUBECONFIG_B64
```

### Step 6: Update Main .gitlab-ci.yml

Simplify the main file to:

```yaml
# GitLab CI/CD Pipeline for EKS Add-ons
# Modular structure for better maintainability
#
# Documentation: See individual job files in .gitlab-ci/ directory
# - validation-jobs.yml: Validation and testing
# - helm-jobs.yml: Helm chart deployment/uninstallation
# - k8s-resources-jobs.yml: K8s-resources deployment/uninstallation
# - verification-jobs.yml: Verification and status checking

# Environment Variables:
#   HELM_RELEASES_DEV/PROD        - Comma-separated list of charts
#   DEV_KUBECONFIG_B64/PROD_KUBECONFIG_B64 - Base64 encoded kubeconfig
#   HELM_DEBUG                    - Enable Helm debug output
#   K8S_APPS                      - Comma-separated list of k8s-resources apps
#   INSTALL_*                     - Control chart installation (true/false)
#   UNINSTALL_*                   - Control chart uninstallation (true/false)

stages:
  - validate
  - test
  - plan
  - deploy
  - verify
  - uninstall
  - status

default:
  image: alpine:3.20
  before_script:
    - echo "🔧 Setting up environment..."
    - apk add --no-cache bash curl git jq yq kubectl helm
    - mkdir -p ~/.kube
    - |
      # Only decode kubeconfig if KUBECONFIG_DATA is set
      if [ -n "$KUBECONFIG_DATA" ]; then
        echo "📝 Decoding kubeconfig..."
        echo "$KUBECONFIG_DATA" | base64 -d > ~/.kube/config
        export KUBECONFIG=~/.kube/config
        echo "✅ Kubeconfig configured"
      else
        echo "⚠️  KUBECONFIG_DATA not set in before_script (this is normal for some jobs)"
      fi
    - echo "🔍 Checking tool versions..."
    - helm version --short || echo "⚠️  Helm check skipped"
    - kubectl version --client || echo "⚠️  Kubectl check skipped"
    - echo "✅ Environment setup complete"

# Include modular job definitions
include:
  - local: '.gitlab-ci/validation-jobs.yml'
  - local: '.gitlab-ci/helm-jobs.yml'
  - local: '.gitlab-ci/k8s-resources-jobs.yml'
  - local: '.gitlab-ci/verification-jobs.yml'
```

## Testing the Split

### 1. Validate Syntax

```bash
# Install GitLab CI linter (if not already installed)
npm install -g @gitlab/ci-lint

# Lint main file
gitlab-ci-lint .gitlab-ci.yml

# Or use GitLab's API
curl --header "Content-Type: application/json" \
  "https://gitlab.com/api/v4/ci/lint" \
  --data @<(cat .gitlab-ci.yml | jq -Rs '{content: .}')
```

### 2. Test Locally

```bash
# Preview the merged configuration
gitlab-runner exec shell --dry-run validate:helm
```

### 3. Test in GitLab

1. Create a feature branch
2. Push the changes
3. Check the pipeline visualization
4. Run a test job to verify includes work

## Migration Checklist

- [ ] Create `.gitlab-ci/` directory
- [ ] Extract validation jobs to `validation-jobs.yml`
- [ ] Extract Helm jobs to `helm-jobs.yml`
- [ ] Extract K8s-resources jobs to `k8s-resources-jobs.yml`
- [ ] Extract verification jobs to `verification-jobs.yml`
- [ ] Update main `.gitlab-ci.yml` with includes
- [ ] Test syntax validation
- [ ] Test in feature branch
- [ ] Verify all jobs appear in pipeline
- [ ] Run test deployments
- [ ] Merge to main branch
- [ ] Update documentation

## Troubleshooting

### Issue: Jobs not appearing in pipeline

**Cause:** Include path incorrect or file not committed

**Solution:**
```bash
# Check file exists
ls -la .gitlab-ci/

# Verify include paths in main file
grep "include:" .gitlab-ci.yml -A 5

# Ensure files are committed
git status
git add .gitlab-ci/
git commit -m "Add modular CI files"
```

### Issue: Variables not accessible in included files

**Cause:** Variables defined in main file after includes

**Solution:** Define variables before includes or in each included file

### Issue: Template not found

**Cause:** Template defined in different included file

**Solution:** Ensure templates are defined before they're used, or move to same file

## Best Practices

### 1. File Organization

- Keep related jobs together
- Use clear, descriptive filenames
- Add header comments to each file
- Document dependencies between files

### 2. Template Management

- Define templates in the same file as jobs that use them
- Or create a separate `templates.yml` file
- Use consistent naming: `.template_name`

### 3. Variable Management

- Define global variables in main file
- Define job-specific variables in job definitions
- Document all variables in main file header

### 4. Documentation

- Keep main file header documentation
- Add file-specific documentation in each included file
- Update README with new structure
- Document the include order if it matters

## Advanced: Conditional Includes

You can conditionally include files based on variables:

```yaml
include:
  - local: '.gitlab-ci/validation-jobs.yml'
  - local: '.gitlab-ci/helm-jobs.yml'
    rules:
      - if: '$DEPLOY_HELM == "true"'
  - local: '.gitlab-ci/k8s-resources-jobs.yml'
    rules:
      - if: '$DEPLOY_K8S_RESOURCES == "true"'
```

## File Size Comparison

| File | Before | After |
|------|--------|-------|
| .gitlab-ci.yml | 1842 lines | ~100 lines |
| validation-jobs.yml | - | ~400 lines |
| helm-jobs.yml | - | ~820 lines |
| k8s-resources-jobs.yml | - | ~470 lines |
| verification-jobs.yml | - | ~140 lines |
| **Total** | **1842 lines** | **1930 lines** |

*Note: Total increases slightly due to file headers and documentation*

## Conclusion

Splitting the GitLab CI configuration into modular files:
- ✅ Improves maintainability
- ✅ Enhances readability
- ✅ Enables better collaboration
- ✅ Follows GitLab best practices
- ✅ Makes the pipeline easier to understand and modify

The modular structure is especially beneficial for large pipelines with many jobs and templates.
