#!/bin/bash
# Script: Verify Deployment
# Description: Checks the status of all deployed resources
# Usage: ./04-verify.sh

set -e  # Exit on error

# Configuration
CLUSTER_NAME="demo-cluster"
REGION="us-central1"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"

echo "========================================="
echo "Verifying Deployment"
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
gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --quiet

# Check namespace
echo ""
echo "1. Checking Namespace..."
kubectl get namespace demo-app

# Check service account
echo ""
echo "2. Checking Service Account..."
kubectl get serviceaccount -n demo-app

# Check deployment
echo ""
echo "3. Checking Deployment..."
kubectl get deployment -n demo-app
kubectl rollout status deployment/demo-app -n demo-app --timeout=30s || echo "Deployment still rolling out..."

# Check pods
echo ""
echo "4. Checking Pods..."
kubectl get pods -n demo-app -o wide

# Check pod logs (last 10 lines)
echo ""
echo "5. Checking Pod Logs (last 10 lines)..."
POD_NAME=$(kubectl get pods -n demo-app -l app=demo-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$POD_NAME" ]; then
    kubectl logs "$POD_NAME" -n demo-app --tail=10 || echo "No logs available yet"
else
    echo "No pods found"
fi

# Check service
echo ""
echo "6. Checking Service..."
kubectl get service -n demo-app
kubectl describe service demo-app -n demo-app | grep -A 3 "Endpoints:"

# Check HPA
echo ""
echo "7. Checking HorizontalPodAutoscaler..."
kubectl get hpa -n demo-app
kubectl describe hpa demo-app-hpa -n demo-app | grep -A 3 "Metrics:"

# Check Gateway
echo ""
echo "8. Checking Gateway..."
kubectl get gateway -n demo-app
kubectl describe gateway demo-gateway -n demo-app | grep -A 5 "Status:"

# Check HTTPRoute
echo ""
echo "9. Checking HTTPRoute..."
kubectl get httproute -n demo-app
kubectl describe httproute demo-app-route -n demo-app | grep -A 5 "Parent Refs:"

# Get Gateway IP address
echo ""
echo "10. Getting Gateway External IP..."
GATEWAY_IP=$(kubectl get gateway demo-gateway -n demo-app \
    -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")

if [ -n "$GATEWAY_IP" ] && [ "$GATEWAY_IP" != "null" ]; then
    echo "Gateway External IP: $GATEWAY_IP"
    echo ""
    echo "Testing connectivity..."
    curl -I "http://$GATEWAY_IP" -m 5 || echo "Gateway not yet responding (this is normal, it may take a few more minutes)"
else
    echo "Gateway IP not yet assigned (still provisioning)"
fi

# Check Google Cloud Load Balancer
echo ""
echo "11. Checking Google Cloud Load Balancer..."
echo "Listing forwarding rules..."
gcloud compute forwarding-rules list \
    --project="$PROJECT_ID" \
    --filter="description~demo-gateway" \
    --format="table(name,IPAddress,target)"

echo ""
echo "========================================="
echo "Verification completed!"
echo "========================================="
echo ""
if [ -n "$GATEWAY_IP" ] && [ "$GATEWAY_IP" != "null" ]; then
    echo "Your application is accessible at:"
    echo "http://$GATEWAY_IP"
    echo ""
    echo "Test with: curl http://$GATEWAY_IP"
else
    echo "Gateway is still provisioning. Wait a few minutes and run:"
    echo "./05-get-external-ip.sh"
fi
echo "========================================="
