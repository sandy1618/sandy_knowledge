#!/bin/bash
# Script: Get External IP Address
# Description: Retrieves and tests the Gateway's external IP address
# Usage: ./05-get-external-ip.sh

set -e  # Exit on error

# Configuration
CLUSTER_NAME="demo-cluster"
REGION="us-central1"
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project)}"

echo "========================================="
echo "Getting Gateway External IP"
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

# Get Gateway IP address
echo ""
echo "Retrieving Gateway IP address..."
GATEWAY_IP=$(kubectl get gateway demo-gateway -n demo-app \
    -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")

if [ -z "$GATEWAY_IP" ] || [ "$GATEWAY_IP" = "null" ]; then
    echo ""
    echo "Gateway IP address not yet assigned."
    echo ""
    echo "The Gateway is still provisioning. This can take 5-10 minutes."
    echo "Run this script again in a few minutes."
    echo ""
    echo "To check Gateway status:"
    echo "  kubectl describe gateway demo-gateway -n demo-app"
    exit 1
fi

echo ""
echo "========================================="
echo "Gateway Information"
echo "========================================="
echo "External IP: $GATEWAY_IP"
echo "URL: http://$GATEWAY_IP"
echo "========================================="

# Test connectivity
echo ""
echo "Testing connectivity..."
echo "Sending HTTP request to Gateway..."
echo ""

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$GATEWAY_IP" -m 10 || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "SUCCESS! Gateway is responding."
    echo ""
    echo "Full response:"
    curl -s "http://$GATEWAY_IP" | head -20
    echo ""
elif [ "$HTTP_STATUS" = "000" ]; then
    echo "WARNING: Unable to connect to Gateway."
    echo "This may be due to:"
    echo "1. Gateway still provisioning (wait a few more minutes)"
    echo "2. Firewall rules blocking access"
    echo "3. Backend not ready"
    echo ""
    echo "Check backend status:"
    echo "  kubectl get pods -n demo-app"
    echo "  kubectl get service -n demo-app"
else
    echo "WARNING: Gateway responded with HTTP status: $HTTP_STATUS"
    echo ""
    echo "This is unexpected. Check the following:"
    echo "1. Backend pods: kubectl get pods -n demo-app"
    echo "2. Service endpoints: kubectl describe service demo-app -n demo-app"
    echo "3. HTTPRoute status: kubectl describe httproute demo-app-route -n demo-app"
fi

echo ""
echo "========================================="
echo "Additional Information"
echo "========================================="

# Show Google Cloud Load Balancer details
echo ""
echo "Google Cloud Load Balancer components:"
gcloud compute forwarding-rules list \
    --project="$PROJECT_ID" \
    --filter="IPAddress=$GATEWAY_IP" \
    --format="table(name,IPAddress,target,portRange)" 2>/dev/null || echo "No forwarding rules found"

echo ""
echo "========================================="
echo "Commands Reference"
echo "========================================="
echo "Test the application:"
echo "  curl http://$GATEWAY_IP"
echo ""
echo "Watch pod status:"
echo "  kubectl get pods -n demo-app -w"
echo ""
echo "View Gateway status:"
echo "  kubectl describe gateway demo-gateway -n demo-app"
echo ""
echo "Check HPA scaling:"
echo "  kubectl get hpa -n demo-app -w"
echo ""
echo "Generate load (requires hey tool):"
echo "  hey -z 60s -c 50 http://$GATEWAY_IP"
echo "========================================="
