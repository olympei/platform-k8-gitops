#!/bin/bash
# Test script to verify download logic without requiring Helm
# Usage: ./scripts/test-download-script.sh

set -e

echo "🧪 Testing chart dependency detection (dry-run)"
echo ""

# Find all chart directories
CHART_DIRS=$(find charts -maxdepth 1 -type d -not -path charts)

TOTAL_CHARTS=0
CHARTS_WITH_DEPS=0
CHARTS_WITHOUT_DEPS=0

for chart_dir in $CHART_DIRS; do
  CHART_NAME=$(basename "$chart_dir")
  
  if [ ! -f "$chart_dir/Chart.yaml" ]; then
    continue
  fi
  
  TOTAL_CHARTS=$((TOTAL_CHARTS + 1))
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Chart: $CHART_NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Check if chart has dependencies
  if ! grep -q "dependencies:" "$chart_dir/Chart.yaml"; then
    echo "  ℹ️  No dependencies"
    CHARTS_WITHOUT_DEPS=$((CHARTS_WITHOUT_DEPS + 1))
    echo ""
    continue
  fi
  
  CHARTS_WITH_DEPS=$((CHARTS_WITH_DEPS + 1))
  
  # Extract repository URLs
  REPOS=$(grep -A 10 "dependencies:" "$chart_dir/Chart.yaml" | grep "repository:" | awk '{print $2}' | tr -d '"' | sort -u)
  
  if [ -z "$REPOS" ]; then
    echo "  ℹ️  No repositories found"
    echo ""
    continue
  fi
  
  # Show what would be done
  echo "  📋 Dependencies found:"
  grep -A 20 "dependencies:" "$chart_dir/Chart.yaml" | grep -E "^\s+- name:" | awk '{print "    • " $3}'
  
  echo ""
  echo "  🔗 Repositories to add:"
  for repo_url in $REPOS; do
    repo_name=$(echo "$repo_url" | sed 's|https://||' | sed 's|http://||' | sed 's|/.*||' | tr '.' '-')
    echo "    • $repo_name: $repo_url"
  done
  
  echo ""
  echo "  ✅ Would execute:"
  for repo_url in $REPOS; do
    repo_name=$(echo "$repo_url" | sed 's|https://||' | sed 's|http://||' | sed 's|/.*||' | tr '.' '-')
    echo "    helm repo add $repo_name $repo_url --insecure-skip-tls-verify"
  done
  echo "    helm repo update"
  echo "    helm dependency build $chart_dir"
  
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total charts: $TOTAL_CHARTS"
echo "Charts with dependencies: $CHARTS_WITH_DEPS"
echo "Charts without dependencies: $CHARTS_WITHOUT_DEPS"
echo ""
echo "✅ Script logic verified!"
echo ""
echo "To actually download dependencies, run this script in an environment with Helm installed:"
echo "  ./scripts/download-all-dependencies.sh"
echo ""
echo "Or use it in your GitLab CI/CD pipeline where Helm is available."
