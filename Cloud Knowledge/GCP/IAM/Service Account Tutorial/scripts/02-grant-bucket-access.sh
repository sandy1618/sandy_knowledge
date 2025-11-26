#!/bin/bash

###############################################################################
# Script: Grant Storage Object Creator Role on Bucket
# Purpose: Creates a Cloud Storage bucket and grants the Service Account
#          the Storage Object Creator role on that bucket
# Usage: ./02-grant-bucket-access.sh [BUCKET_NAME]
###############################################################################

set -e  # Exit on error

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Grant Storage Object Creator Role${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get current project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}No project set. Please set a project:${NC}"
    echo "gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${GREEN}Using project:${NC} $PROJECT_ID"
echo ""

# Service Account details
SA_NAME="demo-uploader"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Check if Service Account exists
if ! gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    echo -e "${RED}Error: Service Account does not exist:${NC} $SA_EMAIL"
    echo "Please run ./01-create-service-account.sh first"
    exit 1
fi

echo -e "${GREEN}✓ Service Account found:${NC} $SA_EMAIL"
echo ""

# Bucket name (use parameter or default)
if [ -n "$1" ]; then
    BUCKET_NAME="$1"
else
    # Use project ID to make bucket name unique
    BUCKET_NAME="demo-upload-bucket-${PROJECT_ID}"
fi

BUCKET_URI="gs://${BUCKET_NAME}"

echo -e "${BLUE}Bucket name:${NC} $BUCKET_NAME"
echo ""

# Check if bucket exists
if gsutil ls "$BUCKET_URI" &>/dev/null; then
    echo -e "${YELLOW}Bucket already exists:${NC} $BUCKET_URI"
else
    echo -e "${BLUE}Creating bucket:${NC} $BUCKET_URI"

    # Create bucket with uniform bucket-level access
    gcloud storage buckets create "$BUCKET_URI" \
        --location=us-central1 \
        --uniform-bucket-level-access \
        --project="$PROJECT_ID"

    echo -e "${GREEN}✓ Bucket created successfully${NC}"
fi

echo ""
echo -e "${BLUE}Granting Storage Object Creator role on bucket...${NC}"

# Grant the IAM role
gcloud storage buckets add-iam-policy-binding "$BUCKET_URI" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/storage.objectCreator" \
    --quiet

echo -e "${GREEN}✓ IAM role granted successfully${NC}"
echo ""

# Display the bucket's IAM policy
echo -e "${BLUE}Current IAM Policy for bucket:${NC}"
echo "----------------------------------------"
gcloud storage buckets get-iam-policy "$BUCKET_URI" \
    --format="table(bindings.role,bindings.members.flatten())" \
    --filter="bindings.members:serviceAccount:${SA_EMAIL}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Service Account: $SA_EMAIL"
echo "Bucket: $BUCKET_URI"
echo "Role: Storage Object Creator (roles/storage.objectCreator)"
echo ""
echo "What this means:"
echo "  ✓ The Service Account CAN upload new files to the bucket"
echo "  ✗ The Service Account CANNOT read existing files"
echo "  ✗ The Service Account CANNOT delete files"
echo "  ✗ The Service Account CANNOT modify bucket settings"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Run: ./03-verify-permissions.sh"
echo "   To verify the permissions are correctly configured"
echo ""
echo "2. Try uploading a file using the Service Account"
echo "   See ../code/upload_to_gcs.py for Python example"
echo ""

# Save bucket name to a file for other scripts to use
echo "$BUCKET_NAME" > /tmp/demo-bucket-name.txt
