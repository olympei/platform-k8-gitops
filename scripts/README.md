# Scripts Directory

## Available Scripts

### split_gitlab_ci.py

**Purpose:** Automatically split `.gitlab-ci.yml` into modular files

**Usage:**
```bash
python3 scripts/split_gitlab_ci.py
```

**What it does:**
1. Creates `.gitlab-ci/` directory
2. Backs up original `.gitlab-ci.yml` to `.gitlab-ci.yml.backup`
3. Extracts jobs into separate files:
   - `validation-jobs.yml` - Validation and testing jobs
   - `helm-jobs.yml` - Helm deployment/uninstall jobs
   - `k8s-resources-jobs.yml` - K8s-resources deployment/uninstall jobs
   - `verification-jobs.yml` - Verification and status jobs
4. Creates new main file as `.gitlab-ci-modular.yml`

**Requirements:**
- Python 3.6+
- No external dependencies

### split-gitlab-ci.sh

**Purpose:** Shell script alternative for splitting GitLab CI

**Usage:**
```bash
bash scripts/split-gitlab-ci.sh
```

**What it does:**
- Creates `.gitlab-ci/` directory
- Backs up original file
- Extracts sections using `sed`
- Creates `.tmp` files for manual review

**Requirements:**
- Bash
- sed

### download-all-dependencies.sh

**Purpose:** Download Helm chart dependencies

**Usage:**
```bash
bash scripts/download-all-dependencies.sh
```

**What it does:**
- Scans all charts in `charts/` directory
- Downloads dependencies for charts with `Chart.yaml`
- Creates `Chart.lock` files
- Downloads `.tgz` files to `charts/` subdirectories

### download-and-package-charts.sh

**Purpose:** Package Helm charts for distribution

**Usage:**
```bash
bash scripts/download-and-package-charts.sh [output-dir]
```

**What it does:**
- Downloads chart dependencies
- Packages charts
- Creates compressed archive (zip or tar.gz)

## Quick Reference

| Task | Command |
|------|---------|
| Split GitLab CI | `python3 scripts/split_gitlab_ci.py` |
| Download dependencies | `bash scripts/download-all-dependencies.sh` |
| Package charts | `bash scripts/download-and-package-charts.sh` |

## Notes

- Always backup files before running scripts
- Review generated files before committing
- Test in feature branch first
- Scripts are idempotent (safe to run multiple times)
