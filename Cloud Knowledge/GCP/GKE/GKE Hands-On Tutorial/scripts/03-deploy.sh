#!/bin/bash
# Script: Deploy Application to GKE
# Description: Deploys all Kubernetes resources using Kustomize
# Usage: ./03-deploy.sh

set -e  # Exit on error

# Configuration
CLUSTER_NAME="demo-cluster"
REGION="us-central1"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"

echo "========================================="
echo "Deploying Application to GKE"
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

# Navigate to the k8s directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$SCRIPT_DIR/../k8s"

if [ ! -d "$K8S_DIR" ]; then
    echo "ERROR: k8s directory not found at $K8S_DIR"
    exit 1
fi

# Validate YAML files before applying
echo ""
echo "Validating Kubernetes manifests..."
kubectl apply -k "$K8S_DIR" --dry-run=client

# Apply all resources using Kustomize
echo ""
echo "Applying Kubernetes resources..."
kubectl apply -k "$K8S_DIR"

# Wait for deployments to be ready
echo ""
echo "Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/demo-app -n demo-app

# Wait for Gateway to get an IP address
echo ""
echo "Waiting for Gateway to provision (this may take 5-10 minutes)..."
echo "The Gateway creates a Google Cloud Load Balancer, which takes time to provision."
echo ""

timeout=600  # 10 minutes
elapsed=0
while [ $elapsed -lt $timeout ]; do
    # Check if Gateway has an address
    GATEWAY_IP=$(kubectl get gateway demo-gateway -n demo-app \
        -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")

    if [ -n "$GATEWAY_IP" ] && [ "$GATEWAY_IP" != "null" ]; then
        echo ""
        echo "Gateway provisioned successfully!"
        echo "External IP: $GATEWAY_IP"
        break
    fi

    if [ $((elapsed % 30)) -eq 0 ]; then
        echo "Still waiting for Gateway IP... ($elapsed/$timeout seconds)"
    fi

    sleep 5
    elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $timeout ]; then
    echo ""
    echo "WARNING: Gateway provisioning is taking longer than expected."
    echo "This is normal for first-time Gateway creation."
    echo "Run ./04-verify.sh to check status."
fi

echo ""
echo "========================================="
echo "Deployment completed!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Run: ./04-verify.sh"
echo "2. Run: ./05-get-external-ip.sh"
echo "========================================="
