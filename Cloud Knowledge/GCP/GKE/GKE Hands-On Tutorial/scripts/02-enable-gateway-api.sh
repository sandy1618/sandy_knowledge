#!/bin/bash
# Script: Enable Gateway API on GKE Cluster
# Description: Enables Gateway API and verifies GatewayClass is available
# Usage: ./02-enable-gateway-api.sh

set -e  # Exit on error

# Configuration
CLUSTER_NAME="demo-cluster"
REGION="us-central1"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"

echo "========================================="
echo "Enabling Gateway API"
echo "========================================="
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Project: $PROJECT_ID"
echo "========================================="

# Check if project ID is set
if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID is not set"
    echo "Set it with: export PROJECT_ID=your-project-id"
    exit 1
fi

# Get cluster credentials
echo "Getting cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID"

# Enable Gateway API
echo ""
echo "Enabling Gateway API on the cluster..."
gcloud container clusters update "$CLUSTER_NAME" \
    --gateway-api=standard \
    --region="$REGION" \
    --project="$PROJECT_ID"

# Wait a moment for the API to be fully available
echo ""
echo "Waiting for Gateway API to be fully available..."
sleep 10

# Verify Gateway API CRDs are installed
echo ""
echo "Verifying Gateway API CRDs..."
kubectl get crd | grep gateway.networking.k8s.io || echo "Gateway CRDs not found yet, waiting..."

# Wait for GatewayClass to be available
echo ""
echo "Waiting for GatewayClass to be available..."
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if kubectl get gatewayclass gke-l7-global-external-managed &> /dev/null; then
        echo "GatewayClass 'gke-l7-global-external-managed' is available!"
        break
    fi
    echo "Waiting for GatewayClass... ($elapsed/$timeout seconds)"
    sleep 5
    elapsed=$((elapsed + 5))
done

# Display available GatewayClasses
echo ""
echo "Available GatewayClasses:"
kubectl get gatewayclass

# Verify specific GatewayClass
echo ""
echo "GatewayClass details:"
kubectl describe gatewayclass gke-l7-global-external-managed

echo ""
echo "========================================="
echo "Gateway API enabled successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Run: ./03-deploy.sh"
echo "========================================="
