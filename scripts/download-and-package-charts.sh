#!/bin/bash
# Script to download all chart dependencies and package them
# Usage: ./scripts/download-and-package-charts.sh [output-dir]

set -e

OUTPUT_DIR="${1:-chart-dependencies}"
SKIP_TLS="${SKIP_TLS_VERIFY:-false}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_NAME="helm-charts-${TIMESTAMP}.zip"

echo "📦 Downloading and packaging Helm chart dependencies"
echo "Output directory: $OUTPUT_DIR"
echo "Package name: $PACKAGE_NAME"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

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

for chart_dir in $CHART_DIRS; do
  CHART_NAME=$(basename "$chart_dir")
  
  if [ ! -f "$chart_dir/Chart.yaml" ]; then
    echo "⏭️  Skipping $CHART_NAME (no Chart.yaml found)"
    continue
  fi
  
  TOTAL_CHARTS=$((TOTAL_CHARTS + 1))
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📥 Processing: $CHART_NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Check if chart has dependencies
  if ! grep -q "dependencies:" "$chart_dir/Chart.yaml"; then
    echo "  ℹ️  No dependencies found, skipping"
    PROCESSED_CHARTS=$((PROCESSED_CHARTS + 1))
    continue
  fi
  
  # Extract repository URLs
  REPOS=$(grep -A 10 "dependencies:" "$chart_dir/Chart.yaml" | grep "repository:" | awk '{print $2}' | tr -d '"' | sort -u)
  
  if [ -z "$REPOS" ]; then
    echo "  ℹ️  No repositories found in dependencies"
    PROCESSED_CHARTS=$((PROCESSED_CHARTS + 1))
    continue
  fi
  
  # Add repositories
  echo "  → Adding repositories..."
  for repo_url in $REPOS; do
    repo_name=$(echo "$repo_url" | sed 's|https://||' | sed 's|http://||' | sed 's|/.*||' | tr '.' '-')
    echo "    • $repo_name: $repo_url"
    helm repo add "$repo_name" "$repo_url" $TLS_FLAG 2>/dev/null || true
  done
  
  # Update repositories
  echo "  → Updating repositories..."
  helm repo update 2>/dev/null || true
  
  # Build dependencies
  echo "  → Building dependencies..."
  cd "$chart_dir"
  
  if helm dependency build --skip-refresh 2>/dev/null; then
    echo "  ✅ Dependencies built successfully"
    PROCESSED_CHARTS=$((PROCESSED_CHARTS + 1))
  else
    echo "  ⚠️  Build failed, trying with update..."
    if helm dependency update 2>/dev/null; then
      echo "  ✅ Dependencies updated successfully"
      PROCESSED_CHARTS=$((PROCESSED_CHARTS + 1))
    else
      echo "  ❌ Failed to build dependencies"
      FAILED_CHARTS=$((FAILED_CHARTS + 1))
    fi
  fi
  
  cd - > /dev/null
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total charts: $TOTAL_CHARTS"
echo "Processed: $PROCESSED_CHARTS"
echo "Failed: $FAILED_CHARTS"
echo ""

# Copy all charts with their dependencies to output directory
echo "📋 Copying charts to output directory..."
for chart_dir in $CHART_DIRS; do
  CHART_NAME=$(basename "$chart_dir")
  
  if [ -f "$chart_dir/Chart.yaml" ]; then
    echo "  → Copying $CHART_NAME..."
    mkdir -p "$OUTPUT_DIR/$CHART_NAME"
    
    # Copy Chart.yaml
    cp "$chart_dir/Chart.yaml" "$OUTPUT_DIR/$CHART_NAME/"
    
    # Copy values files
    cp "$chart_dir"/values-*.yaml "$OUTPUT_DIR/$CHART_NAME/" 2>/dev/null || true
    
    # Copy charts directory (downloaded dependencies)
    if [ -d "$chart_dir/charts" ]; then
      cp -r "$chart_dir/charts" "$OUTPUT_DIR/$CHART_NAME/"
      echo "    ✓ Included dependencies"
    fi
    
    # Copy Chart.lock if exists
    if [ -f "$chart_dir/Chart.lock" ]; then
      cp "$chart_dir/Chart.lock" "$OUTPUT_DIR/$CHART_NAME/"
    fi
  fi
done

echo ""
echo "📦 Creating package..."

# Create zip file
if command -v zip &> /dev/null; then
  cd "$OUTPUT_DIR"
  zip -r "../$PACKAGE_NAME" . -q
  cd - > /dev/null
  echo "  ✅ Package created: $PACKAGE_NAME"
  
  # Show package size
  PACKAGE_SIZE=$(du -h "$PACKAGE_NAME" | cut -f1)
  echo "  📊 Package size: $PACKAGE_SIZE"
else
  echo "  ⚠️  'zip' command not found, creating tar.gz instead..."
  tar -czf "${PACKAGE_NAME%.zip}.tar.gz" -C "$OUTPUT_DIR" .
  echo "  ✅ Package created: ${PACKAGE_NAME%.zip}.tar.gz"
  
  # Show package size
  PACKAGE_SIZE=$(du -h "${PACKAGE_NAME%.zip}.tar.gz" | cut -f1)
  echo "  📊 Package size: $PACKAGE_SIZE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Output directory: $OUTPUT_DIR"
if [ -f "$PACKAGE_NAME" ]; then
  echo "📦 Package file: $PACKAGE_NAME"
else
  echo "📦 Package file: ${PACKAGE_NAME%.zip}.tar.gz"
fi
echo ""
echo "To extract and use:"
if [ -f "$PACKAGE_NAME" ]; then
  echo "  unzip $PACKAGE_NAME -d my-charts"
else
  echo "  tar -xzf ${PACKAGE_NAME%.zip}.tar.gz -C my-charts"
fi
echo "  cd my-charts"
echo "  helm upgrade --install <release-name> <chart-name> -f <chart-name>/values-<env>.yaml"
echo ""

# Optionally clean up the output directory
read -p "Do you want to remove the temporary directory '$OUTPUT_DIR'? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "$OUTPUT_DIR"
  echo "  ✅ Cleaned up $OUTPUT_DIR"
fi

if [ $FAILED_CHARTS -gt 0 ]; then
  echo ""
  echo "⚠️  Warning: $FAILED_CHARTS chart(s) failed to download dependencies"
  exit 1
fi
