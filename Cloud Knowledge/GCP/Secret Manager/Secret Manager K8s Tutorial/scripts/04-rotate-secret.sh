#!/bin/bash
# Script: 04-rotate-secret.sh
# Purpose: Rotate secrets by adding new versions and managing old ones
# Prerequisites: Existing secret in Secret Manager

set -euo pipefail

# Configuration
PROJECT_ID="my-project-dev"
K8S_NAMESPACE="default"
DEPLOYMENT_NAME="demo-app"

# Colors
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

# Rotate service account key
rotate_sa_key() {
    local secret_name="demo-app-sa-key"
    local sa_name="demo-app-sa"
    local sa_email="${sa_name}@${PROJECT_ID}.iam.gserviceaccount.com"

    log_step "Rotating service account key: ${secret_name}"

    # Get current version
    local current_version=$(gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --filter="state:ENABLED" \
        --format="value(name)" \
        --limit=1)

    log_info "Current enabled version: ${current_version}"

    # Get current key ID from secret (before creating new one)
    log_info "Fetching current key details..."
    local old_key_id=$(gcloud secrets versions access "${current_version}" \
        --secret="${secret_name}" \
        --project="${PROJECT_ID}" | jq -r '.private_key_id')

    log_info "Current key ID: ${old_key_id}"

    # Create new service account key and add as new version
    log_info "Creating new service account key..."
    gcloud iam service-accounts keys create /dev/stdout \
        --iam-account="${sa_email}" \
        --format=json | \
    gcloud secrets versions add "${secret_name}" \
        --project="${PROJECT_ID}" \
        --data-file=-

    local new_version=$(gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --filter="state:ENABLED" \
        --format="value(name)" \
        --limit=1)

    log_info "New version created: ${new_version}"
    log_info "New version is now the 'latest' version"

    # Get new key ID
    local new_key_id=$(gcloud secrets versions access "${new_version}" \
        --secret="${secret_name}" \
        --project="${PROJECT_ID}" | jq -r '.private_key_id')

    echo
    log_info "Rotation Summary:"
    echo "  Old Version: ${current_version} (Key ID: ${old_key_id})"
    echo "  New Version: ${new_version} (Key ID: ${new_key_id})"
    echo

    # Instructions for completing rotation
    log_warn "Manual steps required to complete rotation:"
    echo
    echo "1. Restart pods to pick up new version:"
    echo "   kubectl rollout restart deployment ${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE}"
    echo
    echo "2. Verify pods are running with new version:"
    echo "   kubectl rollout status deployment ${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE}"
    echo
    echo "3. After verification, disable old version:"
    echo "   gcloud secrets versions disable ${current_version} --secret=${secret_name} --project=${PROJECT_ID}"
    echo
    echo "4. Delete old service account key from GCP:"
    echo "   gcloud iam service-accounts keys delete ${old_key_id} --iam-account=${sa_email}"
    echo
}

# Rotate text secret (API key, password, etc.)
rotate_text_secret() {
    local secret_name="$1"
    local new_value="$2"

    log_step "Rotating text secret: ${secret_name}"

    # Verify secret exists
    if ! gcloud secrets describe "${secret_name}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_error "Secret not found: ${secret_name}"
        return 1
    fi

    # Get current version
    local current_version=$(gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --filter="state:ENABLED" \
        --format="value(name)" \
        --limit=1)

    log_info "Current version: ${current_version}"

    # Add new version
    echo -n "${new_value}" | \
    gcloud secrets versions add "${secret_name}" \
        --project="${PROJECT_ID}" \
        --data-file=-

    local new_version=$(gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --filter="state:ENABLED" \
        --format="value(name)" \
        --limit=1)

    log_info "New version created: ${new_version}"
    log_info "Rotation complete for ${secret_name}"
}

# Rotate API key
rotate_api_key() {
    local secret_name="demo-app-api-key"
    # Generate new API key
    local new_key="demo_$(openssl rand -hex 16)"

    log_step "Rotating API key"
    rotate_text_secret "${secret_name}" "${new_key}"

    echo
    log_warn "Don't forget to:"
    echo "  1. Update the API key in the third-party service"
    echo "  2. Restart pods: kubectl rollout restart deployment ${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE}"
    echo "  3. Disable old version after verification"
}

# Rotate database URL
rotate_database_url() {
    local secret_name="demo-app-db-url"

    log_step "Rotating database URL"
    log_warn "This requires a new database password"

    read -p "Enter new database password: " -s db_password
    echo

    local new_url="postgresql://demo_user:${db_password}@db.example.com:5432/demo_db"

    rotate_text_secret "${secret_name}" "${new_url}"

    echo
    log_warn "Don't forget to:"
    echo "  1. Update the password in the database"
    echo "  2. Restart pods: kubectl rollout restart deployment ${DEPLOYMENT_NAME} -n ${K8S_NAMESPACE}"
    echo "  3. Disable old version after verification"
}

# Complete rotation workflow
complete_rotation_workflow() {
    local secret_name="$1"

    log_step "Complete Rotation Workflow for ${secret_name}"

    # Step 1: Show current state
    log_info "Step 1: Current state"
    gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --format="table(name,state,createTime)"
    echo

    # Step 2: Create new version (already done by rotate functions)
    log_info "Step 2: New version created (see above)"
    echo

    # Step 3: Restart pods
    log_info "Step 3: Restarting pods..."
    if command -v kubectl &>/dev/null; then
        read -p "Restart deployment now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl rollout restart deployment "${DEPLOYMENT_NAME}" -n "${K8S_NAMESPACE}"
            log_info "Waiting for rollout to complete..."
            kubectl rollout status deployment "${DEPLOYMENT_NAME}" -n "${K8S_NAMESPACE}" --timeout=5m
            log_info "Rollout complete"
        else
            log_warn "Skipped pod restart - remember to restart manually"
        fi
    else
        log_warn "kubectl not found - restart pods manually"
    fi
    echo

    # Step 4: Verification period
    log_info "Step 4: Verification"
    log_warn "Monitor your application for issues"
    echo "  kubectl logs -l app=demo-app -n ${K8S_NAMESPACE} --tail=50"
    echo "  kubectl get pods -l app=demo-app -n ${K8S_NAMESPACE}"
    echo
    read -p "Press Enter after verifying the new version works correctly..."

    # Step 5: Disable old version
    log_info "Step 5: Disabling old version"
    local old_versions=$(gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --filter="state:ENABLED" \
        --format="value(name)" | tail -n +2)  # Skip the first (newest) version

    if [ -n "${old_versions}" ]; then
        echo "Old versions to disable:"
        echo "${old_versions}"
        echo
        read -p "Disable old versions? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for version in ${old_versions}; do
                gcloud secrets versions disable "${version}" \
                    --secret="${secret_name}" \
                    --project="${PROJECT_ID}"
                log_info "Disabled version ${version}"
            done
        else
            log_warn "Old versions not disabled - remember to disable manually later"
        fi
    else
        log_info "No old versions to disable"
    fi
    echo

    # Step 6: Final state
    log_info "Step 6: Final state"
    gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --format="table(name,state,createTime)"

    log_info "Rotation workflow complete!"
}

# Rollback to previous version
rollback_secret() {
    local secret_name="$1"

    log_step "Rolling back secret: ${secret_name}"

    # Get all versions
    local versions=$(gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --format="table(name,state,createTime)")

    echo "${versions}"
    echo

    read -p "Enter version number to rollback to: " target_version

    # Verify version exists
    if ! gcloud secrets versions describe "${target_version}" \
        --secret="${secret_name}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_error "Version ${target_version} not found"
        return 1
    fi

    # Enable target version if disabled
    local state=$(gcloud secrets versions describe "${target_version}" \
        --secret="${secret_name}" \
        --project="${PROJECT_ID}" \
        --format="value(state)")

    if [ "${state}" = "DISABLED" ]; then
        log_info "Enabling version ${target_version}..."
        gcloud secrets versions enable "${target_version}" \
            --secret="${secret_name}" \
            --project="${PROJECT_ID}"
    fi

    # Destroy current latest version
    local current_latest=$(gcloud secrets versions list "${secret_name}" \
        --project="${PROJECT_ID}" \
        --filter="state:ENABLED" \
        --format="value(name)" \
        --limit=1)

    log_warn "This will DESTROY (permanently delete) version ${current_latest}"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rollback cancelled"
        return 0
    fi

    gcloud secrets versions destroy "${current_latest}" \
        --secret="${secret_name}" \
        --project="${PROJECT_ID}"

    log_info "Rollback complete"
    log_info "Version ${target_version} is now the latest enabled version"
    log_warn "Restart pods to use the rolled-back version"
}

# Show rotation schedule/status
show_rotation_status() {
    log_step "Secret Rotation Status"

    local secrets=(
        "demo-app-sa-key"
        "demo-app-api-key"
        "demo-app-db-url"
    )

    for secret in "${secrets[@]}"; do
        if ! gcloud secrets describe "${secret}" \
            --project="${PROJECT_ID}" &>/dev/null; then
            continue
        fi

        echo
        echo "Secret: ${secret}"
        echo "----------------------------------------"

        # Show versions
        gcloud secrets versions list "${secret}" \
            --project="${PROJECT_ID}" \
            --format="table(name,state,createTime)" | head -5

        # Calculate age of current version
        local latest_create_time=$(gcloud secrets versions list "${secret}" \
            --project="${PROJECT_ID}" \
            --filter="state:ENABLED" \
            --format="value(createTime)" \
            --limit=1)

        if [ -n "${latest_create_time}" ]; then
            local create_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" \
                "${latest_create_time%.*}" "+%s" 2>/dev/null || echo "0")
            local now_epoch=$(date +%s)
            local age_days=$(( (now_epoch - create_epoch) / 86400 ))

            echo "Current version age: ${age_days} days"

            # Rotation recommendations
            if [ ${age_days} -gt 90 ]; then
                log_warn "⚠️  Rotation overdue! (> 90 days)"
            elif [ ${age_days} -gt 60 ]; then
                log_warn "⚠️  Consider rotating soon (> 60 days)"
            else
                log_info "✓ Rotation not needed yet"
            fi
        fi
    done
}

# Main menu
show_menu() {
    echo
    echo "Secret Rotation Tool"
    echo "===================="
    echo "Project: ${PROJECT_ID}"
    echo
    echo "1) Rotate service account key (demo-app-sa-key)"
    echo "2) Rotate API key (demo-app-api-key)"
    echo "3) Rotate database URL (demo-app-db-url)"
    echo "4) Complete rotation workflow (interactive)"
    echo "5) Rollback to previous version"
    echo "6) Show rotation status"
    echo "7) Exit"
    echo
}

# Main execution
main() {
    log_info "Secret Rotation Tool for Google Secret Manager"
    echo

    while true; do
        show_menu
        read -p "Select option (1-7): " choice

        case $choice in
            1) rotate_sa_key ;;
            2) rotate_api_key ;;
            3) rotate_database_url ;;
            4)
                read -p "Enter secret name: " secret_name
                complete_rotation_workflow "${secret_name}"
                ;;
            5)
                read -p "Enter secret name: " secret_name
                rollback_secret "${secret_name}"
                ;;
            6) show_rotation_status ;;
            7)
                log_info "Exiting"
                exit 0
                ;;
            *)
                log_warn "Invalid option"
                ;;
        esac

        echo
        read -p "Press Enter to continue..."
    done
}

main "$@"
