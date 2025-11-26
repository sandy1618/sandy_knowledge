#!/bin/bash

###############################################################################
# Script: Create Service Account for Cloud Storage Upload
# Purpose: Creates a GCP Service Account that will be granted Storage Object
#          Creator role on a specific bucket
# Usage: ./01-create-service-account.sh
###############################################################################

set -e  # Exit on error

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Create Service Account${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get current project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}No project set. Please set a project:${NC}"
    echo "gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

echo -e "${GREEN}Using project:${NC} $PROJECT_ID"
echo ""

# Service Account details
SA_NAME="demo-uploader"
SA_DISPLAY_NAME="Demo File Uploader Service Account"
SA_DESCRIPTION="Service account for demonstrating Storage Object Creator role"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Check if Service Account already exists
if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    echo -e "${YELLOW}Service Account already exists:${NC} $SA_EMAIL"
    echo -e "${YELLOW}Skipping creation.${NC}"
else
    echo -e "${BLUE}Creating Service Account:${NC} $SA_NAME"

    gcloud iam service-accounts create "$SA_NAME" \
        --display-name="$SA_DISPLAY_NAME" \
        --description="$SA_DESCRIPTION"

    echo -e "${GREEN}✓ Service Account created successfully${NC}"
fi

echo ""
echo -e "${BLUE}Service Account Details:${NC}"
echo "  Name: $SA_NAME"
echo "  Email: $SA_EMAIL"
echo "  Display Name: $SA_DISPLAY_NAME"
echo ""

# List all service accounts in the project
echo -e "${BLUE}All Service Accounts in project:${NC}"
gcloud iam service-accounts list --format="table(email,displayName)"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Next Steps:${NC}"
echo -e "${GREEN}========================================${NC}"
echo "1. Run: ./02-grant-bucket-access.sh"
echo "   This will grant the Service Account permission to upload to a bucket"
echo ""
echo "2. Run: ./03-verify-permissions.sh"
echo "   This will verify the permissions are correctly set"
echo ""
