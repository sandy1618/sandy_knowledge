#!/bin/bash
# Script: Create GKE Autopilot Cluster
# Description: Creates a GKE Autopilot cluster with Gateway API enabled
# Usage: ./01-create-cluster.sh

set -e  # Exit on error

# Configuration
CLUSTER_NAME="demo-cluster"
REGION="us-central1"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"

echo "========================================="
echo "Creating GKE Autopilot Cluster"
echo "========================================="
echo "Project ID: $PROJECT_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "========================================="

# Check if project ID is set
if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: PROJECT_ID is not set"
    echo "Set it with: export PROJECT_ID=your-project-id"
    exit 1
fi

# Set the project
echo "Setting project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo ""
echo "Enabling required Google Cloud APIs..."
gcloud services enable container.googleapis.com \
    compute.googleapis.com \
    --project="$PROJECT_ID"

# Check if cluster already exists
if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
    echo ""
    echo "WARNING: Cluster '$CLUSTER_NAME' already exists in region '$REGION'"
    read -p "Do you want to delete and recreate it? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        echo "Deleting existing cluster..."
        gcloud container clusters delete "$CLUSTER_NAME" \
            --region="$REGION" \
            --project="$PROJECT_ID" \
            --quiet
    else
        echo "Keeping existing cluster. Exiting."
        exit 0
    fi
fi

# Create GKE Autopilot cluster
echo ""
echo "Creating GKE Autopilot cluster..."
echo "This will take approximately 5-10 minutes..."
gcloud container clusters create-auto "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --release-channel=regular \
    --enable-master-authorized-networks \
    --master-authorized-networks=0.0.0.0/0 \
    --enable-private-nodes

# Wait for cluster to be ready
echo ""
echo "Waiting for cluster to be ready..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID"

# Verify cluster is running
echo ""
echo "Verifying cluster status..."
kubectl cluster-info

echo ""
echo "========================================="
echo "Cluster creation completed successfully!"
echo "========================================="
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo "Project: $PROJECT_ID"
echo ""
echo "Next steps:"
echo "1. Run: ./02-enable-gateway-api.sh"
echo "========================================="
