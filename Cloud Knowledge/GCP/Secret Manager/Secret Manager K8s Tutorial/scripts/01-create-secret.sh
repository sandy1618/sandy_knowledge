#!/bin/bash
# Script: 01-create-secret.sh
# Purpose: Create secrets in Google Secret Manager
# Prerequisites: gcloud CLI authenticated with appropriate permissions

set -euo pipefail  # Exit on error, undefined variable, or pipe failure

# Configuration
PROJECT_ID="my-project-dev"
REGION="us-central1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verify gcloud authentication
check_authentication() {
    log_info "Checking gcloud authentication..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "."; then
        log_error "No active gcloud authentication found"
        log_info "Run: gcloud auth login"
        exit 1
    fi
    log_info "Authentication verified"
}

# Create service account
create_service_account() {
    local sa_name="demo-app-sa"
    local sa_email="${sa_name}@${PROJECT_ID}.iam.gserviceaccount.com"

    log_info "Creating service account: ${sa_name}..."

    # Check if SA already exists
    if gcloud iam service-accounts describe "${sa_email}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_warn "Service account ${sa_name} already exists, skipping creation"
        return 0
    fi

    # Create service account
    gcloud iam service-accounts create "${sa_name}" \
        --project="${PROJECT_ID}" \
        --display-name="Demo Application Service Account" \
        --description="Service account for demo-app with Storage access"

    log_info "Service account created: ${sa_email}"

    # Grant Cloud Storage permissions
    log_info "Granting Cloud Storage Object Creator role..."
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
        --member="serviceAccount:${sa_email}" \
        --role="roles/storage.objectCreator" \
        --condition=None

    log_info "Service account configuration complete"
}

# Create secret from text
create_text_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"

    log_info "Creating secret: ${secret_name}..."

    # Check if secret already exists
    if gcloud secrets describe "${secret_name}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_warn "Secret ${secret_name} already exists"
        read -p "Add new version? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -n "${secret_value}" | \
            gcloud secrets versions add "${secret_name}" \
                --project="${PROJECT_ID}" \
                --data-file=-
            log_info "New version added to ${secret_name}"
        fi
        return 0
    fi

    # Create new secret
    echo -n "${secret_value}" | \
    gcloud secrets create "${secret_name}" \
        --project="${PROJECT_ID}" \
        --replication-policy="automatic" \
        --data-file=- \
        --labels=env=development,managed-by=script

    # Add description (via update, as create doesn't support it directly)
    gcloud secrets update "${secret_name}" \
        --project="${PROJECT_ID}" \
        --update-labels=description="${description}" \
        >/dev/null 2>&1 || true

    log_info "Secret created: ${secret_name}"
}

# Create secret from service account key
create_sa_key_secret() {
    local secret_name="demo-app-sa-key"
    local sa_name="demo-app-sa"
    local sa_email="${sa_name}@${PROJECT_ID}.iam.gserviceaccount.com"

    log_info "Creating service account key and storing in Secret Manager..."

    # Check if secret already exists
    if gcloud secrets describe "${secret_name}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_warn "Secret ${secret_name} already exists"
        log_info "Use 04-rotate-secret.sh to create a new key version"
        return 0
    fi

    # Create key and pipe directly to Secret Manager (never touches disk!)
    gcloud iam service-accounts keys create /dev/stdout \
        --iam-account="${sa_email}" \
        --format=json | \
    gcloud secrets create "${secret_name}" \
        --project="${PROJECT_ID}" \
        --replication-policy="automatic" \
        --data-file=- \
        --labels=env=development,type=service-account-key

    log_info "Service account key created and stored securely"
    log_warn "The key was never written to disk - it went directly to Secret Manager"

    # Verify the secret contains valid JSON
    log_info "Verifying secret content..."
    if gcloud secrets versions access latest \
        --secret="${secret_name}" \
        --project="${PROJECT_ID}" | jq . >/dev/null 2>&1; then
        log_info "Secret verification successful - valid JSON key"
    else
        log_error "Secret verification failed - invalid JSON"
        return 1
    fi
}

# Create API key secret
create_api_key_secret() {
    local secret_name="demo-app-api-key"
    # Generate a sample API key (in real scenario, this would be from a service)
    local api_key="demo_$(openssl rand -hex 16)"

    log_info "Creating API key secret..."
    create_text_secret "${secret_name}" "${api_key}" "Third-party API key for demo application"
}

# Create database URL secret
create_database_secret() {
    local secret_name="demo-app-db-url"
    local db_url="postgresql://demo_user:$(openssl rand -hex 12)@db.example.com:5432/demo_db"

    log_info "Creating database URL secret..."
    create_text_secret "${secret_name}" "${db_url}" "Database connection string"
}

# List created secrets
list_secrets() {
    log_info "Listing all secrets in project ${PROJECT_ID}..."
    gcloud secrets list \
        --project="${PROJECT_ID}" \
        --filter="labels.env=development" \
        --format="table(name,createTime,labels)"
}

# Main execution
main() {
    log_info "Starting secret creation process for project: ${PROJECT_ID}"
    echo

    # Check prerequisites
    check_authentication

    # Step 1: Create service account
    log_info "Step 1: Creating service account"
    create_service_account
    echo

    # Step 2: Create service account key secret
    log_info "Step 2: Creating service account key secret"
    create_sa_key_secret
    echo

    # Step 3: Create API key secret
    log_info "Step 3: Creating API key secret"
    create_api_key_secret
    echo

    # Step 4: Create database URL secret
    log_info "Step 4: Creating database URL secret"
    create_database_secret
    echo

    # List all created secrets
    list_secrets
    echo

    log_info "Secret creation complete!"
    log_info "Next steps:"
    echo "  1. Run 02-grant-access.sh to grant access to GKE service accounts"
    echo "  2. Deploy SecretProviderClass: kubectl apply -f ../k8s/secret-provider-class.yaml"
    echo "  3. Deploy application: kubectl apply -f ../k8s/deployment.yaml"
}

# Run main function
main "$@"
