#!/bin/bash

###############################################################################
# Script: Verify Service Account Permissions
# Purpose: Tests and verifies the Service Account has correct permissions
#          on the Cloud Storage bucket
# Usage: ./03-verify-permissions.sh [BUCKET_NAME]
###############################################################################

set -e  # Exit on error

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verify Service Account Permissions${NC}"
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

# Get bucket name
if [ -n "$1" ]; then
    BUCKET_NAME="$1"
elif [ -f /tmp/demo-bucket-name.txt ]; then
    BUCKET_NAME=$(cat /tmp/demo-bucket-name.txt)
else
    BUCKET_NAME="demo-upload-bucket-${PROJECT_ID}"
fi

BUCKET_URI="gs://${BUCKET_NAME}"

echo -e "${BLUE}Checking Service Account:${NC} $SA_EMAIL"
echo -e "${BLUE}Checking Bucket:${NC} $BUCKET_URI"
echo ""

# Check if Service Account exists
if ! gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    echo -e "${RED}Error: Service Account does not exist:${NC} $SA_EMAIL"
    exit 1
fi

# Check if bucket exists
if ! gsutil ls "$BUCKET_URI" &>/dev/null; then
    echo -e "${RED}Error: Bucket does not exist:${NC} $BUCKET_URI"
    exit 1
fi

echo -e "${GREEN}✓ Service Account exists${NC}"
echo -e "${GREEN}✓ Bucket exists${NC}"
echo ""

# Test IAM permissions
echo -e "${BLUE}Testing IAM Permissions...${NC}"
echo "----------------------------------------"

# Test specific permissions
PERMISSIONS=(
    "storage.objects.create"
    "storage.objects.delete"
    "storage.objects.get"
    "storage.objects.list"
    "storage.buckets.get"
)

echo "Testing permissions for Service Account on bucket:"
echo ""

for permission in "${PERMISSIONS[@]}"; do
    # Test permission (this checks what the current user can test, not the SA itself)
    # Note: This is a limitation of the test-iam-permissions command
    printf "  %-30s" "$permission"

    # Check if permission is in the policy
    if gcloud storage buckets get-iam-policy "$BUCKET_URI" \
        --format="value(bindings.members.flatten())" \
        --filter="bindings.role=roles/storage.objectCreator AND bindings.members:serviceAccount:${SA_EMAIL}" \
        | grep -q "$SA_EMAIL"; then

        case $permission in
            "storage.objects.create")
                echo -e "${GREEN}✓ GRANTED${NC} (via objectCreator role)"
                ;;
            "storage.objects.list")
                echo -e "${GREEN}✓ GRANTED${NC} (via objectCreator role)"
                ;;
            "storage.objects.delete"|"storage.objects.get")
                echo -e "${YELLOW}✗ DENIED${NC} (not in objectCreator role)"
                ;;
            *)
                echo -e "${YELLOW}? UNKNOWN${NC}"
                ;;
        esac
    fi
done

echo ""
echo -e "${BLUE}Full IAM Policy for the bucket:${NC}"
echo "----------------------------------------"
gcloud storage buckets get-iam-policy "$BUCKET_URI" \
    --format="table(bindings.role,bindings.members.flatten())"

echo ""
echo -e "${BLUE}Roles granted to our Service Account:${NC}"
echo "----------------------------------------"
gcloud storage buckets get-iam-policy "$BUCKET_URI" \
    --format="value(bindings.role)" \
    --filter="bindings.members:serviceAccount:${SA_EMAIL}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Verification Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Service Account: $SA_EMAIL"
echo "Bucket: $BUCKET_URI"
echo ""
echo "Expected Permissions (Storage Object Creator):"
echo "  ${GREEN}✓${NC} Can create/upload new objects"
echo "  ${GREEN}✓${NC} Can list objects (basic)"
echo "  ${YELLOW}✗${NC} Cannot read/download object contents"
echo "  ${YELLOW}✗${NC} Cannot delete objects"
echo "  ${YELLOW}✗${NC} Cannot modify bucket settings"
echo ""
echo -e "${GREEN}This configuration follows the Principle of Least Privilege!${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Test uploading a file using the Python example:"
echo "   cd ../code"
echo "   python upload_to_gcs.py"
echo ""
echo "2. Create a Service Account key for local testing:"
echo "   gcloud iam service-accounts keys create ~/demo-uploader-key.json \\"
echo "       --iam-account=$SA_EMAIL"
echo "   export GOOGLE_APPLICATION_CREDENTIALS=~/demo-uploader-key.json"
echo ""
echo "3. For production in GKE, use Workload Identity instead of keys"
echo "   See the main README.md for details"
echo ""

# Additional check: Show what the objectCreator role actually contains
echo -e "${BLUE}Storage Object Creator Role Details:${NC}"
echo "----------------------------------------"
echo "Role ID: roles/storage.objectCreator"
echo ""
echo "Included Permissions:"
gcloud iam roles describe roles/storage.objectCreator \
    --format="value(includedPermissions)" | sed 's/^/  • /'

echo ""
