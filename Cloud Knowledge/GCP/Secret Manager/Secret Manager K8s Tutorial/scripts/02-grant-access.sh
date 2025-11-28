#!/bin/bash
# Script: 02-grant-access.sh
# Purpose: Grant Secret Manager access to GKE service accounts
# Prerequisites:
#   - Secrets created (run 01-create-secret.sh)
#   - GKE cluster exists with Workload Identity enabled
#   - Kubernetes ServiceAccount created (kubectl apply -f ../k8s/service-account.yaml)

set -euo pipefail

# Configuration
PROJECT_ID="my-project-dev"
GCP_SA_NAME="demo-app-sa"
GCP_SA_EMAIL="${GCP_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
K8S_NAMESPACE="default"
K8S_SA_NAME="demo-app-ksa"

# Secrets to grant access to
SECRETS=(
    "demo-app-sa-key"
    "demo-app-api-key"
    "demo-app-db-url"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Verify GCP service account exists
verify_gcp_sa() {
    log_step "Verifying GCP service account exists..."

    if ! gcloud iam service-accounts describe "${GCP_SA_EMAIL}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_error "GCP service account not found: ${GCP_SA_EMAIL}"
        log_info "Run 01-create-secret.sh to create the service account"
        exit 1
    fi

    log_info "GCP service account verified: ${GCP_SA_EMAIL}"
}

# Setup Workload Identity binding
setup_workload_identity() {
    log_step "Setting up Workload Identity binding..."

    local member="serviceAccount:${PROJECT_ID}.svc.id.goog[${K8S_NAMESPACE}/${K8S_SA_NAME}]"

    log_info "Binding Kubernetes SA to GCP SA..."
    log_info "  K8s SA: ${K8S_NAMESPACE}/${K8S_SA_NAME}"
    log_info "  GCP SA: ${GCP_SA_EMAIL}"

    # Grant workloadIdentityUser role
    gcloud iam service-accounts add-iam-policy-binding "${GCP_SA_EMAIL}" \
        --project="${PROJECT_ID}" \
        --role="roles/iam.workloadIdentityUser" \
        --member="${member}"

    log_info "Workload Identity binding created"

    # Verify binding
    log_info "Verifying binding..."
    if gcloud iam service-accounts get-iam-policy "${GCP_SA_EMAIL}" \
        --project="${PROJECT_ID}" \
        --format=json | jq -e ".bindings[] | select(.role==\"roles/iam.workloadIdentityUser\")" >/dev/null; then
        log_info "Workload Identity binding verified"
    else
        log_warn "Could not verify Workload Identity binding"
    fi
}

# Grant secret access
grant_secret_access() {
    local secret_name="$1"

    log_info "Granting access to secret: ${secret_name}"

    # Check if secret exists
    if ! gcloud secrets describe "${secret_name}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_error "Secret not found: ${secret_name}"
        return 1
    fi

    # Grant secretAccessor role
    gcloud secrets add-iam-policy-binding "${secret_name}" \
        --project="${PROJECT_ID}" \
        --member="serviceAccount:${GCP_SA_EMAIL}" \
        --role="roles/secretmanager.secretAccessor"

    log_info "Access granted for ${secret_name}"
}

# Grant access to all secrets
grant_all_secrets_access() {
    log_step "Granting access to all secrets..."

    local failed_secrets=()

    for secret in "${SECRETS[@]}"; do
        if grant_secret_access "${secret}"; then
            echo "  ✓ ${secret}"
        else
            echo "  ✗ ${secret}"
            failed_secrets+=("${secret}")
        fi
    done

    if [ ${#failed_secrets[@]} -gt 0 ]; then
        log_warn "Failed to grant access to: ${failed_secrets[*]}"
        log_info "Run 01-create-secret.sh to create missing secrets"
    else
        log_info "All secrets access granted successfully"
    fi
}

# Verify access
verify_access() {
    log_step "Verifying secret access..."

    for secret in "${SECRETS[@]}"; do
        # Check if secret exists first
        if ! gcloud secrets describe "${secret}" \
            --project="${PROJECT_ID}" &>/dev/null; then
            log_warn "Secret ${secret} does not exist, skipping verification"
            continue
        fi

        # Get IAM policy
        local policy=$(gcloud secrets get-iam-policy "${secret}" \
            --project="${PROJECT_ID}" \
            --format=json)

        # Check if our SA has access
        if echo "${policy}" | jq -e ".bindings[] | select(.role==\"roles/secretmanager.secretAccessor\") | .members[] | select(.==\"serviceAccount:${GCP_SA_EMAIL}\")" >/dev/null; then
            echo "  ✓ ${secret} - Access verified"
        else
            echo "  ✗ ${secret} - Access NOT found"
        fi
    done
}

# Display summary
display_summary() {
    log_step "Access Configuration Summary"

    echo
    echo "GCP Service Account: ${GCP_SA_EMAIL}"
    echo "Kubernetes Service Account: ${K8S_NAMESPACE}/${K8S_SA_NAME}"
    echo "Project: ${PROJECT_ID}"
    echo
    echo "Workload Identity Member:"
    echo "  serviceAccount:${PROJECT_ID}.svc.id.goog[${K8S_NAMESPACE}/${K8S_SA_NAME}]"
    echo
    echo "Secrets with access:"
    for secret in "${SECRETS[@]}"; do
        echo "  - ${secret}"
    done
    echo
}

# Test access from kubectl (optional)
test_kubectl_access() {
    log_step "Testing access from Kubernetes..."

    if ! command -v kubectl &>/dev/null; then
        log_warn "kubectl not found, skipping Kubernetes test"
        return 0
    fi

    # Check if K8s SA exists
    if ! kubectl get serviceaccount "${K8S_SA_NAME}" \
        --namespace="${K8S_NAMESPACE}" &>/dev/null; then
        log_warn "Kubernetes ServiceAccount not found: ${K8S_NAMESPACE}/${K8S_SA_NAME}"
        log_info "Create it with: kubectl apply -f ../k8s/service-account.yaml"
        return 0
    fi

    # Verify annotation
    local annotation=$(kubectl get serviceaccount "${K8S_SA_NAME}" \
        --namespace="${K8S_NAMESPACE}" \
        -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}')

    if [ "${annotation}" = "${GCP_SA_EMAIL}" ]; then
        log_info "Kubernetes ServiceAccount annotation verified"
    else
        log_warn "Kubernetes ServiceAccount annotation mismatch"
        log_warn "  Expected: ${GCP_SA_EMAIL}"
        log_warn "  Found: ${annotation}"
    fi
}

# Main execution
main() {
    log_info "Starting IAM access configuration for project: ${PROJECT_ID}"
    echo

    # Verify prerequisites
    verify_gcp_sa
    echo

    # Setup Workload Identity
    setup_workload_identity
    echo

    # Grant secret access
    grant_all_secrets_access
    echo

    # Verify access
    verify_access
    echo

    # Test kubectl access
    test_kubectl_access
    echo

    # Display summary
    display_summary

    log_info "IAM configuration complete!"
    log_info "Next steps:"
    echo "  1. Verify Kubernetes ServiceAccount exists:"
    echo "     kubectl get sa ${K8S_SA_NAME} -n ${K8S_NAMESPACE}"
    echo
    echo "  2. If not, create it:"
    echo "     kubectl apply -f ../k8s/service-account.yaml"
    echo
    echo "  3. Deploy SecretProviderClass:"
    echo "     kubectl apply -f ../k8s/secret-provider-class.yaml"
    echo
    echo "  4. Deploy application:"
    echo "     kubectl apply -f ../k8s/deployment.yaml"
}

main "$@"
