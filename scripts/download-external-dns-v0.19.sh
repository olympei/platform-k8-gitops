#!/bin/bash

# Script to download ExternalDNS Helm chart v1.20.0 (app v0.20.0)
# Compatible with Kubernetes 1.33

set -e

CHART_VERSION="1.19.0"
CHART_NAME="external-dns"
CHART_DIR="charts/external-dns/charts"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Downloading ExternalDNS Helm Chart v${CHART_VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create charts directory if it doesn't exist
mkdir -p "$CHART_DIR"

# Check if chart already exists
if [ -f "$CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz" ]; then
    echo "⚠️  Chart already exists: $CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz"
    read -p "Do you want to re-download? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "✅ Using existing chart"
        exit 0
    fi
    rm -f "$CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz"
fi

echo "🔍 Attempting to download chart..."
echo ""

# Method 1: Try Kubernetes SIGs repository
echo "Method 1: Trying Kubernetes SIGs repository..."
if helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ 2>/dev/null || helm repo update external-dns; then
    echo "✅ Repository added/updated"
    
    if helm pull external-dns/external-dns --version "$CHART_VERSION" --destination "$CHART_DIR" 2>/dev/null; then
        echo "✅ Chart downloaded successfully from Kubernetes SIGs!"
        ls -lh "$CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz"
        exit 0
    else
        echo "⚠️  Version $CHART_VERSION not found in Kubernetes SIGs repository"
    fi
else
    echo "⚠️  Could not access Kubernetes SIGs repository"
fi

echo ""

# Method 2: Try Bitnami repository
echo "Method 2: Trying Bitnami repository..."
if helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || helm repo update bitnami; then
    echo "✅ Bitnami repository added/updated"
    
    # Search for chart with app version 0.20.0
    echo "🔍 Searching for chart with app version 0.20.0..."
    BITNAMI_VERSION=$(helm search repo bitnami/external-dns --versions | grep "0.20.0" | head -1 | awk '{print $2}')
    
    if [ -n "$BITNAMI_VERSION" ]; then
        echo "Found Bitnami chart version: $BITNAMI_VERSION"
        
        if helm pull bitnami/external-dns --version "$BITNAMI_VERSION" --destination "$CHART_DIR"; then
            # Rename to match our naming convention
            mv "$CHART_DIR/external-dns-${BITNAMI_VERSION}.tgz" "$CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz"
            echo "✅ Chart downloaded successfully from Bitnami!"
            ls -lh "$CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz"
            exit 0
        fi
    else
        echo "⚠️  Chart with app version 0.20.0 not found in Bitnami repository"
    fi
else
    echo "⚠️  Could not access Bitnami repository"
fi

echo ""

# Method 3: Try direct GitHub release download
echo "Method 3: Trying GitHub releases..."
GITHUB_URL="https://github.com/kubernetes-sigs/external-dns/releases/download/external-dns-helm-chart-${CHART_VERSION}/external-dns-${CHART_VERSION}.tgz"

echo "Attempting download from: $GITHUB_URL"
if curl -L -f -o "$CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz" "$GITHUB_URL" 2>/dev/null; then
    echo "✅ Chart downloaded successfully from GitHub!"
    ls -lh "$CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz"
    exit 0
else
    echo "⚠️  Could not download from GitHub releases"
fi

echo ""

# Method 4: Manual instructions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "❌ Automatic download failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Please download the chart manually:"
echo ""
echo "Option 1: Using Helm CLI"
echo "  helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/"
echo "  helm repo update"
echo "  helm search repo external-dns/external-dns --versions | grep 0.20"
echo "  helm pull external-dns/external-dns --version <version> --destination $CHART_DIR"
echo ""
echo "Option 2: From GitHub Releases"
echo "  Visit: https://github.com/kubernetes-sigs/external-dns/releases"
echo "  Download: external-dns-${CHART_VERSION}.tgz"
echo "  Move to: $CHART_DIR/"
echo ""
echo "Option 3: Using Bitnami"
echo "  helm repo add bitnami https://charts.bitnami.com/bitnami"
echo "  helm repo update"
echo "  helm search repo bitnami/external-dns --versions | grep 0.20"
echo "  helm pull bitnami/external-dns --version <version> --destination $CHART_DIR"
echo "  mv $CHART_DIR/external-dns-<version>.tgz $CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz"
echo ""
echo "After downloading, verify with:"
echo "  ls -lh $CHART_DIR/${CHART_NAME}-${CHART_VERSION}.tgz"
echo ""

exit 1
