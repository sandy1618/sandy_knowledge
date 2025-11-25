#!/bin/bash
# Script: Cleanup Resources
# Description: Deletes all created resources including the GKE cluster
# Usage: ./99-cleanup.sh

set -e  # Exit on error

# Configuration
CLUSTER_NAME="demo-cluster"
REGION="us-central1"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"

echo "========================================="
echo "CLEANUP WARNING"
echo "========================================="
echo "This will delete:"
echo "1. All Kubernetes resources in demo-app namespace"
echo "2. GKE cluster: $CLUSTER_NAME"
echo "3. Google Cloud Load Balancer"
echo ""
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "========================================="
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Check if project ID is set
if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID is not set"
    echo "Set it with: export PROJECT_ID=your-project-id"
    exit 1
fi

# Try to get cluster credentials
echo ""
echo "Getting cluster credentials..."
if gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet 2>/dev/null; then

    # Delete Kubernetes resources first
    echo ""
    echo "Deleting Kubernetes resources..."

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    K8S_DIR="$SCRIPT_DIR/../k8s"

    if [ -d "$K8S_DIR" ]; then
        echo "Deleting resources using Kustomize..."
        kubectl delete -k "$K8S_DIR" --ignore-not-found=true --wait=true --timeout=300s
    else
        echo "Deleting namespace (cascading delete)..."
        kubectl delete namespace demo-app --ignore-not-found=true --wait=true --timeout=300s
    fi

    echo "Kubernetes resources deleted."

    # Wait a moment for Load Balancer cleanup
    echo ""
    echo "Waiting for Load Balancer cleanup..."
    sleep 30
else
    echo "Could not connect to cluster. Will proceed with cluster deletion."
fi

# Delete the GKE cluster
echo ""
echo "Deleting GKE cluster..."
if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
    gcloud container clusters delete "$CLUSTER_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --quiet
    echo "Cluster deleted successfully."
else
    echo "Cluster not found. Skipping cluster deletion."
fi

# Check for any remaining load balancer resources
echo ""
echo "Checking for remaining Load Balancer resources..."
FORWARDING_RULES=$(gcloud compute forwarding-rules list \
    --project="$PROJECT_ID" \
    --filter="description~demo-gateway" \
    --format="value(name)" 2>/dev/null || echo "")

if [ -n "$FORWARDING_RULES" ]; then
    echo "WARNING: Some Load Balancer resources may still exist:"
    gcloud compute forwarding-rules list \
        --project="$PROJECT_ID" \
        --filter="description~demo-gateway" \
        --format="table(name,IPAddress,target)"
    echo ""
    echo "These should be automatically cleaned up, but you may want to verify:"
    echo "gcloud compute forwarding-rules list --project=$PROJECT_ID"
else
    echo "No remaining Load Balancer resources found."
fi

echo ""
echo "========================================="
echo "Cleanup completed!"
echo "========================================="
echo ""
echo "All resources have been deleted."
echo ""
echo "To verify cleanup:"
echo "1. Check clusters: gcloud container clusters list --project=$PROJECT_ID"
echo "2. Check forwarding rules: gcloud compute forwarding-rules list --project=$PROJECT_ID"
echo "========================================="
