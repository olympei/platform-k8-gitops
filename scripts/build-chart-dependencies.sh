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

# Add required repositories based on Chart.yaml dependencies
echo "Detecting required Helm repositories..."
REPOS_ADDED=0

if [ "$SKIP_TLS" = "true" ]; then
  echo "⚠️  Skipping TLS verification"
  TLS_FLAG="--insecure-skip-tls-verify"
else
  TLS_FLAG=""
fi

if grep -q "charts.external-secrets.io" "$CHART_DIR/Chart.yaml"; then
  echo "  → Adding external-secrets repository"
  helm repo add external-secrets https://charts.external-secrets.io $TLS_FLAG || true
  REPOS_ADDED=$((REPOS_ADDED + 1))
fi

if grep -q "aws.github.io/eks-charts" "$CHART_DIR/Chart.yaml"; then
  echo "  → Adding eks repository"
  helm repo add eks https://aws.github.io/eks-charts $TLS_FLAG || true
  REPOS_ADDED=$((REPOS_ADDED + 1))
fi

if grep -q "kubernetes.github.io/autoscaler" "$CHART_DIR/Chart.yaml"; then
  echo "  → Adding autoscaler repository"
  helm repo add autoscaler https://kubernetes.github.io/autoscaler $TLS_FLAG || true
  REPOS_ADDED=$((REPOS_ADDED + 1))
fi

if grep -q "kubernetes.github.io/ingress-nginx" "$CHART_DIR/Chart.yaml"; then
  echo "  → Adding ingress-nginx repository"
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx $TLS_FLAG || true
  REPOS_ADDED=$((REPOS_ADDED + 1))
fi

if grep -q "kubernetes-sigs.github.io/metrics-server" "$CHART_DIR/Chart.yaml"; then
  echo "  → Adding metrics-server repository"
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server $TLS_FLAG || true
  REPOS_ADDED=$((REPOS_ADDED + 1))
fi

if grep -q "kubernetes-sigs.github.io/secrets-store-csi-driver" "$CHART_DIR/Chart.yaml"; then
  echo "  → Adding secrets-store-csi-driver repository"
  helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts $TLS_FLAG || true
  REPOS_ADDED=$((REPOS_ADDED + 1))
fi

if [ $REPOS_ADDED -eq 0 ]; then
  echo "  ℹ️  No known repositories detected in Chart.yaml"
else
  echo ""
  echo "Updating $REPOS_ADDED repository/repositories..."
  if [ "$SKIP_TLS" = "true" ]; then
    helm repo update --insecure-skip-tls-verify
  else
    helm repo update
  fi
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
