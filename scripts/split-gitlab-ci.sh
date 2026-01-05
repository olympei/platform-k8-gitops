#!/bin/bash
# Script to split .gitlab-ci.yml into modular files
# Usage: bash scripts/split-gitlab-ci.sh

set -e

echo "🔧 Splitting .gitlab-ci.yml into modular files..."
echo ""

# Create directory
mkdir -p .gitlab-ci
echo "✅ Created .gitlab-ci/ directory"

# Backup original file
cp .gitlab-ci.yml .gitlab-ci.yml.backup
echo "✅ Backed up original file to .gitlab-ci.yml.backup"

# Extract line ranges (you'll need to adjust these based on your actual file)
# These are approximate - verify with: grep -n "^validate:helm:" .gitlab-ci.yml

# Extract validation jobs (lines 1-412)
echo "📝 Extracting validation jobs..."
sed -n '1,412p' .gitlab-ci.yml > .gitlab-ci/validation-jobs.yml.tmp

# Extract helm jobs (lines 413-1230)
echo "📝 Extracting Helm jobs..."
sed -n '413,1230p' .gitlab-ci.yml > .gitlab-ci/helm-jobs.yml.tmp

# Extract k8s-resources jobs (lines 1231-1700)
echo "📝 Extracting K8s-resources jobs..."
sed -n '1231,1700p' .gitlab-ci.yml > .gitlab-ci/k8s-resources-jobs.yml.tmp

# Extract verification jobs (lines 1701-1842)
echo "📝 Extracting verification jobs..."
sed -n '1701,1842p' .gitlab-ci.yml > .gitlab-ci/verification-jobs.yml.tmp

echo ""
echo "⚠️  MANUAL STEPS REQUIRED:"
echo "1. Review the extracted files in .gitlab-ci/*.tmp"
echo "2. Add file headers to each file"
echo "3. Rename .tmp files to .yml"
echo "4. Update main .gitlab-ci.yml with includes"
echo "5. Test the configuration"
echo ""
echo "See GITLAB-CI-MODULAR-SPLIT-GUIDE.md for detailed instructions"
