#!/bin/bash

# Test script for validate:helm stage
# Simulates the GitLab CI validation logic

set -e

echo "🧪 Testing Helm Chart Validation Logic"
echo "========================================"
echo ""

# Simulate environment variable (change this to test different modes)
# Set to "true" to test direct values mode, or leave empty for wrapper mode
USE_DIRECT_VALUES="${USE_DIRECT_VALUES:-}"

echo "🔍 Configuration:"
echo "  USE_DIRECT_VALUES: ${USE_DIRECT_VALUES:-not set}"
echo ""

# Check if using direct values
if [ "$USE_DIRECT_VALUES" = "true" ] || [ "$USE_DIRECT_VALUES" = "1" ] || [ "$USE_DIRECT_VALUES" = "yes" ]; then
  echo "ℹ️  USE_DIRECT_VALUES is enabled - will lint .tgz files directly"
  LINT_MODE="direct"
else
  echo "ℹ️  Using wrapper mode - will lint parent charts"
  LINT_MODE="wrapper"
fi
echo ""

# Function to check if chart should be validated
should_validate_chart() {
  local chart_name=$1
  local enable_var="INSTALL_$(echo $chart_name | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
  local enable_value=${!enable_var}
  
  # Default to true if variable not set
  if [ -z "$enable_value" ]; then
    return 0
  fi
  
  # Check if explicitly disabled
  if [ "$enable_value" = "false" ] || [ "$enable_value" = "0" ] || [ "$enable_value" = "no" ]; then
    return 1
  fi
  
  return 0
}

LINT_ERRORS=0
SKIPPED_COUNT=0
VALIDATED_COUNT=0
VALUES_VALIDATED=0

for chart in charts/*; do
  [ -d "$chart" ] || continue
  chart_name=$(basename "$chart")
  
  if ! should_validate_chart "$chart_name"; then
    echo "⏭️  Skipping lint for $chart (disabled)"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Linting: $chart_name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [ "$LINT_MODE" = "direct" ]; then
    # Lint the .tgz file directly with direct values files
    TGZ_FILE=$(find "$chart/charts" -name "*.tgz" -type f 2>/dev/null | head -1)
    
    if [ -z "$TGZ_FILE" ]; then
      echo "⚠️  No .tgz file found in $chart/charts/"
      echo "   Falling back to parent chart lint"
      if helm lint "$chart"; then
        echo "✅ Lint passed for $chart"
        VALIDATED_COUNT=$((VALIDATED_COUNT + 1))
      else
        echo "❌ Lint failed for $chart"
        LINT_ERRORS=$((LINT_ERRORS + 1))
      fi
    else
      echo "📦 Chart package: $TGZ_FILE"
      
      # Validate with direct values files for each environment
      CHART_LINT_FAILED=false
      CHART_VALUES_COUNT=0
      
      for env in dev prod; do
        VALUES_FILE="$chart/values-${env}-direct.yaml"
        
        if [ -f "$VALUES_FILE" ]; then
          echo ""
          echo "🔍 Validating with: values-${env}-direct.yaml"
          if helm lint "$TGZ_FILE" -f "$VALUES_FILE"; then
            echo "✅ Lint passed with values-${env}-direct.yaml"
            VALUES_VALIDATED=$((VALUES_VALIDATED + 1))
            CHART_VALUES_COUNT=$((CHART_VALUES_COUNT + 1))
          else
            echo "❌ Lint failed with values-${env}-direct.yaml"
            CHART_LINT_FAILED=true
            LINT_ERRORS=$((LINT_ERRORS + 1))
          fi
        else
          echo ""
          echo "ℹ️  No values-${env}-direct.yaml found, skipping"
        fi
      done
      
      # If no direct values files exist, lint without values
      if [ $CHART_VALUES_COUNT -eq 0 ]; then
        echo ""
        echo "🔍 No direct values files found, linting chart without values"
        if helm lint "$TGZ_FILE"; then
          echo "✅ Lint passed for $TGZ_FILE"
          VALIDATED_COUNT=$((VALIDATED_COUNT + 1))
        else
          echo "❌ Lint failed for $TGZ_FILE"
          LINT_ERRORS=$((LINT_ERRORS + 1))
        fi
      else
        VALIDATED_COUNT=$((VALIDATED_COUNT + 1))
      fi
    fi
  else
    # Lint the parent chart (wrapper mode)
    if helm lint "$chart"; then
      echo "✅ Lint passed for $chart"
      VALIDATED_COUNT=$((VALIDATED_COUNT + 1))
    else
      echo "❌ Lint failed for $chart"
      LINT_ERRORS=$((LINT_ERRORS + 1))
    fi
  fi
  
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Mode: $LINT_MODE"
echo "Charts validated: $VALIDATED_COUNT"
if [ "$LINT_MODE" = "direct" ]; then
  echo "Direct values files validated: $VALUES_VALIDATED"
fi
echo "Errors: $LINT_ERRORS"
echo "Skipped: $SKIPPED_COUNT"

if [ $LINT_ERRORS -gt 0 ]; then
  echo ""
  echo "❌ $LINT_ERRORS chart(s) failed linting"
  exit 1
fi

echo ""
echo "✅ All enabled charts passed linting"
