#!/bin/bash

###############################################################################
# Script: Cleanup Demo Resources
# Purpose: Removes the Service Account and bucket created during the tutorial
# Usage: ./04-cleanup.sh [--keep-bucket]
###############################################################################

set -e  # Exit on error

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cleanup Demo Resources${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Parse arguments
KEEP_BUCKET=false
if [ "$1" == "--keep-bucket" ]; then
    KEEP_BUCKET=true
    echo -e "${YELLOW}Note: Bucket will be kept (--keep-bucket flag detected)${NC}"
    echo ""
fi

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

# Get bucket name
if [ -f /tmp/demo-bucket-name.txt ]; then
    BUCKET_NAME=$(cat /tmp/demo-bucket-name.txt)
else
    BUCKET_NAME="demo-upload-bucket-${PROJECT_ID}"
fi

BUCKET_URI="gs://${BUCKET_NAME}"

# Confirm deletion
echo -e "${YELLOW}WARNING: This will delete the following resources:${NC}"
echo "  • Service Account: $SA_EMAIL"
if [ "$KEEP_BUCKET" = false ]; then
    echo "  • Bucket: $BUCKET_URI (and all contents)"
else
    echo "  • Bucket: $BUCKET_URI (IAM bindings only, bucket will be kept)"
fi
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""

# Remove IAM binding from bucket (if bucket exists)
if gsutil ls "$BUCKET_URI" &>/dev/null; then
    echo -e "${BLUE}Removing IAM binding from bucket...${NC}"

    # Check if binding exists
    if gcloud storage buckets get-iam-policy "$BUCKET_URI" \
        --format="value(bindings.members.flatten())" \
        --filter="bindings.members:serviceAccount:${SA_EMAIL}" \
        | grep -q "$SA_EMAIL"; then

        gcloud storage buckets remove-iam-policy-binding "$BUCKET_URI" \
            --member="serviceAccount:${SA_EMAIL}" \
            --role="roles/storage.objectCreator" \
            --quiet || echo -e "${YELLOW}No IAM binding found or already removed${NC}"

        echo -e "${GREEN}✓ IAM binding removed${NC}"
    else
        echo -e "${YELLOW}No IAM binding found for this Service Account${NC}"
    fi

    # Delete bucket if requested
    if [ "$KEEP_BUCKET" = false ]; then
        echo ""
        echo -e "${BLUE}Deleting bucket and all contents...${NC}"

        gsutil -m rm -r "$BUCKET_URI" || echo -e "${YELLOW}Bucket already deleted or doesn't exist${NC}"

        echo -e "${GREEN}✓ Bucket deleted${NC}"
    fi
else
    echo -e "${YELLOW}Bucket does not exist: $BUCKET_URI${NC}"
fi

echo ""

# Delete Service Account keys (if any)
echo -e "${BLUE}Checking for Service Account keys...${NC}"

if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    KEY_COUNT=$(gcloud iam service-accounts keys list \
        --iam-account="$SA_EMAIL" \
        --filter="keyType=USER_MANAGED" \
        --format="value(name)" | wc -l)

    if [ "$KEY_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}Found $KEY_COUNT user-managed key(s)${NC}"
        echo "Deleting keys..."

        gcloud iam service-accounts keys list \
            --iam-account="$SA_EMAIL" \
            --filter="keyType=USER_MANAGED" \
            --format="value(name)" | while read -r key; do
                echo "  Deleting key: $key"
                gcloud iam service-accounts keys delete "$key" \
                    --iam-account="$SA_EMAIL" \
                    --quiet
            done

        echo -e "${GREEN}✓ Keys deleted${NC}"
    else
        echo "No user-managed keys found"
    fi
fi

echo ""

# Delete Service Account
echo -e "${BLUE}Deleting Service Account...${NC}"

if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    gcloud iam service-accounts delete "$SA_EMAIL" --quiet

    echo -e "${GREEN}✓ Service Account deleted${NC}"
else
    echo -e "${YELLOW}Service Account does not exist: $SA_EMAIL${NC}"
fi

# Clean up temp file
rm -f /tmp/demo-bucket-name.txt

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cleanup Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Removed resources:"
echo "  ✓ Service Account: $SA_EMAIL"
if [ "$KEEP_BUCKET" = false ]; then
    echo "  ✓ Bucket: $BUCKET_URI"
else
    echo "  ✓ IAM bindings on bucket: $BUCKET_URI"
    echo "    (Bucket was kept as requested)"
fi
echo ""
echo "To remove the bucket manually (if kept):"
echo "  gsutil -m rm -r $BUCKET_URI"
echo ""
echo "Note: If you created a local key file (demo-uploader-key.json),"
echo "remember to delete it manually for security:"
echo "  rm ~/demo-uploader-key.json"
echo ""
