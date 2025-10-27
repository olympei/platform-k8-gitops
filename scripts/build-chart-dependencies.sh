#!/bin/bash
# Script to build Helm chart dependencies
# Usage: ./scripts/build-chart-dependencies.sh <chart-name>

set -e

CHART_NAME="${1}"
SKIP_TLS="${SKIP_TLS_VERIFY:-false}"

if [ -z "$CHART_NAME" ]; then
  echo "Usage: $0 <chart-name>"
  echo "Example: $0 external-secrets-operator"
  exit 1
fi

CHART_DIR="charts/${CHART_NAME}"

if [ ! -d "$CHART_DIR" ]; then
  echo "❌ Chart directory not found: $CHART_DIR"
  exit 1
fi

if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
  echo "❌ Chart.yaml not found in: $CHART_DIR"
  exit 1
fi

# Check if chart has dependencies
if ! grep -q "dependencies:" "$CHART_DIR/Chart.yaml"; then
  echo "ℹ️  Chart has no dependencies, nothing to build"
  exit 0
fi

echo "📦 Building dependencies for chart: $CHART_NAME"
echo "Chart directory: $CHART_DIR"
echo ""

# Extract and add repositories from Chart.yaml dependencies
echo "Extracting repositories from Chart.yaml..."

if [ "$SKIP_TLS" = "true" ]; then
  echo "⚠️  Skipping TLS verification"
  export HELM_REPO_SKIP_TLS_VERIFY=true
  TLS_FLAG="--insecure-skip-tls-verify"
else
  TLS_FLAG=""
fi

# Extract unique repository URLs from Chart.yaml
REPOS=$(grep -A 10 "dependencies:" "$CHART_DIR/Chart.yaml" | grep "repository:" | awk '{print $2}' | tr -d '"' | sort -u)

REPOS_ADDED=0
for repo_url in $REPOS; do
  # Generate a simple repo name from the URL (e.g., charts.external-secrets.io -> charts-external-secrets-io)
  repo_name=$(echo "$repo_url" | sed 's|https://||' | sed 's|http://||' | sed 's|/.*||' | tr '.' '-')
  echo "  → Adding repository: $repo_name"
  echo "    URL: $repo_url"
  helm repo add "$repo_name" "$repo_url" $TLS_FLAG || true
  REPOS_ADDED=$((REPOS_ADDED + 1))
done

if [ $REPOS_ADDED -eq 0 ]; then
  echo "  ℹ️  No repositories found in Chart.yaml"
else
  echo ""
  echo "Updating $REPOS_ADDED repository/repositories..."
  helm repo update || true
fi

echo ""
echo "Building chart dependencies..."
cd "$CHART_DIR"

# Try dependency build first (uses existing repo cache)
if helm dependency build --skip-refresh; then
  echo "✅ Dependencies built successfully"
else
  echo "⚠️  Build failed, trying with update..."
  if helm dependency update; then
    echo "✅ Dependencies updated successfully"
  else
    echo "❌ Failed to build/update dependencies"
    exit 1
  fi
fi

echo ""
echo "📋 Dependency status:"
helm dependency list

echo ""
echo "✅ Chart dependencies ready for: $CHART_NAME"
