#!/bin/bash
# Test script to verify packaging logic without requiring Helm
# Usage: ./scripts/test-package-script.sh

set -e

OUTPUT_DIR="test-chart-dependencies"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE_NAME="helm-charts-${TIMESTAMP}.zip"

echo "🧪 Testing chart packaging script (dry-run)"
echo "Output directory: $OUTPUT_DIR"
echo "Package name: $PACKAGE_NAME"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Find all chart directories
CHART_DIRS=$(find charts -maxdepth 1 -type d -not -path charts)

TOTAL_CHARTS=0
CHARTS_WITH_DEPS=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Phase 1: Analyzing Charts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for chart_dir in $CHART_DIRS; do
  CHART_NAME=$(basename "$chart_dir")
  
  if [ ! -f "$chart_dir/Chart.yaml" ]; then
    continue
  fi
  
  TOTAL_CHARTS=$((TOTAL_CHARTS + 1))
  
  echo "📦 $CHART_NAME"
  
  # Check if chart has dependencies
  if grep -q "dependencies:" "$chart_dir/Chart.yaml"; then
    CHARTS_WITH_DEPS=$((CHARTS_WITH_DEPS + 1))
    DEP_COUNT=$(grep -A 20 "dependencies:" "$chart_dir/Chart.yaml" | grep -E "^\s+- name:" | wc -l)
    echo "  ✓ Has $DEP_COUNT dependency/dependencies"
  else
    echo "  • No dependencies"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Phase 2: Simulating File Copy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL_FILES=0

for chart_dir in $CHART_DIRS; do
  CHART_NAME=$(basename "$chart_dir")
  
  if [ ! -f "$chart_dir/Chart.yaml" ]; then
    continue
  fi
  
  echo "📁 Copying $CHART_NAME..."
  mkdir -p "$OUTPUT_DIR/$CHART_NAME"
  
  # Copy Chart.yaml
  if [ -f "$chart_dir/Chart.yaml" ]; then
    cp "$chart_dir/Chart.yaml" "$OUTPUT_DIR/$CHART_NAME/"
    echo "  ✓ Chart.yaml"
    TOTAL_FILES=$((TOTAL_FILES + 1))
  fi
  
  # Copy values files
  VALUES_COUNT=0
  for values_file in "$chart_dir"/values-*.yaml; do
    if [ -f "$values_file" ]; then
      cp "$values_file" "$OUTPUT_DIR/$CHART_NAME/"
      VALUES_COUNT=$((VALUES_COUNT + 1))
      TOTAL_FILES=$((TOTAL_FILES + 1))
    fi
  done
  if [ $VALUES_COUNT -gt 0 ]; then
    echo "  ✓ $VALUES_COUNT values file(s)"
  fi
  
  # Check for charts directory (would contain dependencies)
  if [ -d "$chart_dir/charts" ]; then
    cp -r "$chart_dir/charts" "$OUTPUT_DIR/$CHART_NAME/"
    DEP_FILES=$(find "$chart_dir/charts" -type f | wc -l)
    echo "  ✓ charts/ directory ($DEP_FILES file(s))"
    TOTAL_FILES=$((TOTAL_FILES + DEP_FILES))
  else
    echo "  • No charts/ directory (dependencies not built yet)"
  fi
  
  # Copy Chart.lock if exists
  if [ -f "$chart_dir/Chart.lock" ]; then
    cp "$chart_dir/Chart.lock" "$OUTPUT_DIR/$CHART_NAME/"
    echo "  ✓ Chart.lock"
    TOTAL_FILES=$((TOTAL_FILES + 1))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Phase 3: Creating Package"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create zip file
if command -v zip &> /dev/null; then
  cd "$OUTPUT_DIR"
  zip -r "../$PACKAGE_NAME" . -q
  cd - > /dev/null
  echo "✅ Package created: $PACKAGE_NAME"
  
  # Show package size
  PACKAGE_SIZE=$(du -h "$PACKAGE_NAME" | cut -f1)
  echo "📊 Package size: $PACKAGE_SIZE"
  
  # Show package contents
  echo ""
  echo "📦 Package contents:"
  unzip -l "$PACKAGE_NAME" | head -20
else
  echo "⚠️  'zip' command not found, creating tar.gz instead..."
  tar -czf "${PACKAGE_NAME%.zip}.tar.gz" -C "$OUTPUT_DIR" .
  echo "✅ Package created: ${PACKAGE_NAME%.zip}.tar.gz"
  
  # Show package size
  PACKAGE_SIZE=$(du -h "${PACKAGE_NAME%.zip}.tar.gz" | cut -f1)
  echo "📊 Package size: $PACKAGE_SIZE"
  
  # Show package contents
  echo ""
  echo "📦 Package contents:"
  tar -tzf "${PACKAGE_NAME%.zip}.tar.gz" | head -20
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total charts: $TOTAL_CHARTS"
echo "Charts with dependencies: $CHARTS_WITH_DEPS"
echo "Total files copied: $TOTAL_FILES"
echo "Output directory: $OUTPUT_DIR"
if [ -f "$PACKAGE_NAME" ]; then
  echo "Package file: $PACKAGE_NAME ($PACKAGE_SIZE)"
else
  echo "Package file: ${PACKAGE_NAME%.zip}.tar.gz ($PACKAGE_SIZE)"
fi
echo ""
echo "✅ Packaging script logic verified!"
echo ""
echo "⚠️  Note: Dependencies (charts/ subdirectories) are not present because"
echo "   Helm is not installed. In a real environment with Helm, the script would:"
echo "   1. Download all dependencies using 'helm dependency build'"
echo "   2. Store them in each chart's charts/ subdirectory"
echo "   3. Include them in the package"
echo ""
echo "To test with actual dependencies, run on a machine with Helm installed:"
echo "  ./scripts/download-and-package-charts.sh"
echo ""

# Clean up
read -p "Remove test files? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  rm -rf "$OUTPUT_DIR"
  if [ -f "$PACKAGE_NAME" ]; then
    rm "$PACKAGE_NAME"
  else
    rm "${PACKAGE_NAME%.zip}.tar.gz"
  fi
  echo "✅ Cleaned up test files"
fi
