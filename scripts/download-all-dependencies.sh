#!/bin/bash
# Script to download dependencies for all charts
# Usage: ./scripts/download-all-dependencies.sh

set -e

SKIP_TLS="${SKIP_TLS_VERIFY:-false}"

echo "📥 Downloading dependencies for all charts"
echo ""

# Set TLS skip if needed
if [ "$SKIP_TLS" = "true" ]; then
  echo "⚠️  Skipping TLS verification"
  export HELM_REPO_SKIP_TLS_VERIFY=true
  TLS_FLAG="--insecure-skip-tls-verify"
else
  TLS_FLAG=""
fi

# Find all chart directories
CHART_DIRS=$(find charts -maxdepth 1 -type d -not -path charts)

TOTAL_CHARTS=0
PROCESSED_CHARTS=0
FAILED_CHARTS=0
declare -a FAILED_CHART_NAMES

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
    PROCESSED_CHARTS=$((PROCESSED_CHARTS + 1))
    echo ""
    continue
  fi
  
  # Extract repository URLs
  REPOS=$(grep -A 10 "dependencies:" "$chart_dir/Chart.yaml" | grep "repository:" | awk '{print $2}' | tr -d '"' | sort -u)
  
  if [ -z "$REPOS" ]; then
    echo "  ℹ️  No repositories found"
    PROCESSED_CHARTS=$((PROCESSED_CHARTS + 1))
    echo ""
    continue
  fi
  
  # Add repositories
  for repo_url in $REPOS; do
    repo_name=$(echo "$repo_url" | sed 's|https://||' | sed 's|http://||' | sed 's|/.*||' | tr '.' '-')
    echo "  → Adding repository: $repo_name"
    helm repo add "$repo_name" "$repo_url" $TLS_FLAG 2>/dev/null || true
  done
  
  # Update repositories
  echo "  → Updating repositories..."
  helm repo update 2>/dev/null || true
  
  # Build dependencies
  echo "  → Building dependencies..."
  cd "$chart_dir"
  
  if helm dependency build --skip-refresh; then
    echo "  ✅ Success"
    PROCESSED_CHARTS=$((PROCESSED_CHARTS + 1))
  else
    echo "  ⚠️  Build failed, trying update..."
    if helm dependency update; then
      echo "  ✅ Success (via update)"
      PROCESSED_CHARTS=$((PROCESSED_CHARTS + 1))
    else
      echo "  ❌ Failed"
      FAILED_CHARTS=$((FAILED_CHARTS + 1))
      FAILED_CHART_NAMES+=("$CHART_NAME")
    fi
  fi
  
  cd - > /dev/null
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total charts: $TOTAL_CHARTS"
echo "Successful: $PROCESSED_CHARTS"
echo "Failed: $FAILED_CHARTS"

if [ $FAILED_CHARTS -gt 0 ]; then
  echo ""
  echo "❌ Failed charts:"
  for chart in "${FAILED_CHART_NAMES[@]}"; do
    echo "  • $chart"
  done
  echo ""
  exit 1
fi

echo ""
echo "✅ All dependencies downloaded successfully!"
echo ""
echo "Dependencies are stored in each chart's 'charts/' subdirectory:"
for chart_dir in $CHART_DIRS; do
  CHART_NAME=$(basename "$chart_dir")
  if [ -d "$chart_dir/charts" ]; then
    DEP_COUNT=$(ls -1 "$chart_dir/charts" | wc -l)
    echo "  • $CHART_NAME: $DEP_COUNT file(s)"
  fi
done
