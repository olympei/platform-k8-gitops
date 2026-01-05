# GitLab CI Modular Split - Summary

## Problem

The `.gitlab-ci.yml` file has grown to **1842 lines**, making it difficult to:
- Navigate and find specific jobs
- Maintain and update
- Review changes in pull requests
- Collaborate without conflicts

## Solution

Split the monolithic file into **modular, focused files** using GitLab's `include` feature.

## Quick Start

### Option 1: Automatic Split (Recommended)

```bash
# Run the Python script
python3 scripts/split_gitlab_ci.py

# Review the generated files
ls -la .gitlab-ci/

# Test the new structure
mv .gitlab-ci-modular.yml .gitlab-ci.yml

# Commit and test
git add .gitlab-ci/ .gitlab-ci.yml
git commit -m "Split GitLab CI into modular files"
git push
```

### Option 2: Manual Split

Follow the detailed guide in `GITLAB-CI-MODULAR-SPLIT-GUIDE.md`

## New Structure

```
.gitlab-ci.yml                    # Main file (~100 lines)
.gitlab-ci/
├── validation-jobs.yml           # Validation & testing (~400 lines)
├── helm-jobs.yml                 # Helm jobs (~820 lines)
├── k8s-resources-jobs.yml        # K8s-resources jobs (~470 lines)
└── verification-jobs.yml         # Verification & status (~140 lines)
```

## Benefits

| Aspect | Before | After |
|--------|--------|-------|
| Main file size | 1842 lines | ~100 lines |
| Findability | Difficult | Easy |
| Maintainability | Hard | Simple |
| Collaboration | Conflicts | Isolated |
| Readability | Poor | Excellent |

## Files Created

1. **GITLAB-CI-MODULAR-SPLIT-GUIDE.md** - Comprehensive guide with examples
2. **scripts/split_gitlab_ci.py** - Automatic splitting script
3. **scripts/split-gitlab-ci.sh** - Shell script alternative
4. **GITLAB-CI-SPLIT-SUMMARY.md** - This file

## How It Works

### Main File (.gitlab-ci.yml)

```yaml
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
    # ... setup commands

# Include modular files
include:
  - local: '.gitlab-ci/validation-jobs.yml'
  - local: '.gitlab-ci/helm-jobs.yml'
  - local: '.gitlab-ci/k8s-resources-jobs.yml'
  - local: '.gitlab-ci/verification-jobs.yml'
```

### Included Files

Each file contains related jobs:

**validation-jobs.yml:**
- validate:helm
- validate:kustomize
- test:dependencies
- test:package
- plan

**helm-jobs.yml:**
- All Helm deployment templates and jobs
- All Helm uninstall templates and jobs
- 40+ Helm-related jobs

**k8s-resources-jobs.yml:**
- All K8s-resources deployment templates and jobs
- All K8s-resources uninstall templates and jobs
- 20+ K8s-resources jobs

**verification-jobs.yml:**
- verify:dev / verify:prod
- status:dev / status:prod

## Testing

### 1. Validate Syntax

```bash
# Check if files are valid YAML
python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))"
```

### 2. Preview in GitLab

1. Create feature branch
2. Push changes
3. View pipeline in GitLab UI
4. Verify all jobs appear

### 3. Run Test Job

```bash
# Trigger a validation job to test
# In GitLab UI: Pipelines > Run Pipeline > validate:helm
```

## Migration Checklist

- [ ] Backup current .gitlab-ci.yml
- [ ] Run split script or manual split
- [ ] Review generated files
- [ ] Test syntax validation
- [ ] Create feature branch
- [ ] Commit and push
- [ ] Verify pipeline in GitLab
- [ ] Run test jobs
- [ ] Merge to main

## Rollback Plan

If issues occur:

```bash
# Restore from backup
cp .gitlab-ci.yml.backup .gitlab-ci.yml

# Or revert commit
git revert HEAD

# Or restore from Git history
git checkout HEAD~1 -- .gitlab-ci.yml
```

## Best Practices

### 1. File Organization
- Keep related jobs together
- Use descriptive filenames
- Add headers to each file

### 2. Documentation
- Document variables in main file
- Add comments in included files
- Update README

### 3. Maintenance
- Update all related files together
- Test after changes
- Keep backups

## Common Issues

### Issue: Jobs not appearing

**Solution:** Check include paths and ensure files are committed

```bash
git status
git add .gitlab-ci/
```

### Issue: Template not found

**Solution:** Ensure template is in same file or defined before use

### Issue: Variables not accessible

**Solution:** Define variables in main file or each included file

## Performance

GitLab caches included files, so there's **no performance penalty** for splitting files.

## Examples

### Adding a New Helm Chart

1. Open `.gitlab-ci/helm-jobs.yml`
2. Add deployment job:
```yaml
deploy:new-chart:dev:
  extends: .deploy_single_chart
  variables:
    ENVIRONMENT: dev
    CHART_TO_DEPLOY: new-chart
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
```
3. Add uninstall job
4. Commit and push

### Adding a New K8s-Resources App

1. Open `.gitlab-ci/k8s-resources-jobs.yml`
2. Add deployment job:
```yaml
deploy:k8s:new-app:dev:
  extends: .deploy_k8s_app
  variables:
    ENVIRONMENT: dev
    APP_NAME: new-app
    KUBECONFIG_DATA: $DEV_KUBECONFIG_B64
```
3. Add uninstall job
4. Commit and push

## Advanced Features

### Conditional Includes

```yaml
include:
  - local: '.gitlab-ci/helm-jobs.yml'
    rules:
      - if: '$DEPLOY_HELM == "true"'
```

### Multiple Environments

```yaml
include:
  - local: '.gitlab-ci/validation-jobs.yml'
  - local: '.gitlab-ci/helm-jobs-dev.yml'
  - local: '.gitlab-ci/helm-jobs-prod.yml'
```

### External Includes

```yaml
include:
  - project: 'group/shared-ci'
    file: '/templates/helm-jobs.yml'
```

## Resources

- [GitLab Include Documentation](https://docs.gitlab.com/ee/ci/yaml/#include)
- [GitLab CI Best Practices](https://docs.gitlab.com/ee/ci/yaml/yaml_optimization.html)
- [GITLAB-CI-MODULAR-SPLIT-GUIDE.md](GITLAB-CI-MODULAR-SPLIT-GUIDE.md) - Detailed guide

## Conclusion

Splitting the GitLab CI configuration:
- ✅ Reduces main file from 1842 to ~100 lines
- ✅ Improves maintainability and readability
- ✅ Enables better collaboration
- ✅ Follows GitLab best practices
- ✅ No performance impact

**Recommendation:** Use the automatic split script for quick, accurate results.
