#!/bin/bash
# Script: 03-local-access.sh
# Purpose: Access secrets locally for development and testing
# Prerequisites:
#   - gcloud authenticated with user account
#   - User granted secretAccessor role for development secrets

set -euo pipefail

# Configuration
PROJECT_ID="my-project-dev"
SECRET_NAME="${1:-demo-app-sa-key}"  # Default to SA key, or use first argument
OUTPUT_DIR="/tmp/demo-app-secrets"

# Colors
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if user has access
check_access() {
    log_step "Checking your access to secret: ${SECRET_NAME}"

    if ! gcloud secrets describe "${SECRET_NAME}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        log_warn "Secret not found: ${SECRET_NAME}"
        log_info "Available secrets:"
        gcloud secrets list --project="${PROJECT_ID}" --format="value(name)"
        exit 1
    fi

    # Try to access
    if ! gcloud secrets versions access latest \
        --secret="${SECRET_NAME}" \
        --project="${PROJECT_ID}" >/dev/null 2>&1; then
        log_warn "You don't have access to this secret"
        log_info "Request access with:"
        echo "  gcloud secrets add-iam-policy-binding ${SECRET_NAME} \\"
        echo "    --project=${PROJECT_ID} \\"
        echo "    --member='user:YOUR_EMAIL' \\"
        echo "    --role='roles/secretmanager.secretAccessor'"
        exit 1
    fi

    log_info "Access verified for ${SECRET_NAME}"
}

# Method 1: Direct access and display
access_direct() {
    log_step "Method 1: Direct Access (print to console)"

    log_info "Fetching secret content..."
    local content=$(gcloud secrets versions access latest \
        --secret="${SECRET_NAME}" \
        --project="${PROJECT_ID}")

    # Check if it's JSON
    if echo "${content}" | jq . >/dev/null 2>&1; then
        log_info "Secret contains JSON data:"
        echo "${content}" | jq .
    else
        log_info "Secret content:"
        echo "${content}"
    fi
}

# Method 2: Save to temporary file
access_to_file() {
    log_step "Method 2: Save to Temporary File"

    # Create secure temporary directory
    mkdir -p "${OUTPUT_DIR}"
    chmod 700 "${OUTPUT_DIR}"

    local output_file="${OUTPUT_DIR}/${SECRET_NAME}.txt"

    log_info "Saving secret to: ${output_file}"
    gcloud secrets versions access latest \
        --secret="${SECRET_NAME}" \
        --project="${PROJECT_ID}" > "${output_file}"

    # Set restrictive permissions
    chmod 600 "${output_file}"

    log_info "Secret saved successfully"
    log_info "File permissions: $(ls -l ${output_file} | awk '{print $1}')"

    # If JSON, validate
    if jq . "${output_file}" >/dev/null 2>&1; then
        log_info "JSON validation: ✓ Valid"

        # For service account keys, extract useful info
        if jq -e '.type == "service_account"' "${output_file}" >/dev/null 2>&1; then
            log_info "Service Account Details:"
            echo "  Email: $(jq -r '.client_email' ${output_file})"
            echo "  Project: $(jq -r '.project_id' ${output_file})"
            echo "  Key ID: $(jq -r '.private_key_id' ${output_file})"
        fi
    fi

    echo
    log_info "Use in application:"
    echo "  export GOOGLE_APPLICATION_CREDENTIALS=${output_file}"
    echo "  python ../code/read_secret_from_file.py"
}

# Method 3: Use with environment variable
access_with_env() {
    log_step "Method 3: Export as Environment Variable"

    local output_file="${OUTPUT_DIR}/${SECRET_NAME}.txt"

    # Ensure file exists
    if [ ! -f "${output_file}" ]; then
        log_info "Creating temporary file..."
        mkdir -p "${OUTPUT_DIR}"
        chmod 700 "${OUTPUT_DIR}"
        gcloud secrets versions access latest \
            --secret="${SECRET_NAME}" \
            --project="${PROJECT_ID}" > "${output_file}"
        chmod 600 "${output_file}"
    fi

    log_info "Set environment variable:"
    echo
    echo "  export GOOGLE_APPLICATION_CREDENTIALS=${output_file}"
    echo
    log_info "Or run your application directly:"
    echo
    echo "  GOOGLE_APPLICATION_CREDENTIALS=${output_file} python your_app.py"
}

# Method 4: List all versions
list_versions() {
    log_step "Method 4: List All Secret Versions"

    log_info "Versions for ${SECRET_NAME}:"
    gcloud secrets versions list "${SECRET_NAME}" \
        --project="${PROJECT_ID}" \
        --format="table(name,state,createTime)"
}

# Method 5: Access specific version
access_specific_version() {
    local version="${1:-1}"

    log_step "Method 5: Access Specific Version (${version})"

    log_info "Fetching version ${version} of ${SECRET_NAME}..."
    local content=$(gcloud secrets versions access "${version}" \
        --secret="${SECRET_NAME}" \
        --project="${PROJECT_ID}")

    if echo "${content}" | jq . >/dev/null 2>&1; then
        echo "${content}" | jq .
    else
        echo "${content}"
    fi
}

# Method 6: Python-based access using SDK
create_python_script() {
    log_step "Method 6: Python SDK Access"

    local script_file="${OUTPUT_DIR}/access_secret.py"

    log_info "Creating Python script: ${script_file}"

    cat > "${script_file}" << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
Access secrets using Google Cloud Secret Manager Python client library.
This method is more efficient than shelling out to gcloud.
"""
from google.cloud import secretmanager
import os
import sys

def access_secret(project_id: str, secret_id: str, version: str = "latest"):
    """Access a secret from Secret Manager."""
    # Initialize client
    client = secretmanager.SecretManagerServiceClient()

    # Build resource name
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version}"

    # Access secret
    response = client.access_secret_version(request={"name": name})

    # Return payload
    return response.payload.data.decode("UTF-8")

if __name__ == "__main__":
    project = os.getenv("GCP_PROJECT", "my-project-dev")
    secret = os.getenv("SECRET_NAME", "demo-app-sa-key")

    if len(sys.argv) > 1:
        secret = sys.argv[1]

    print(f"Accessing secret: {secret} in project: {project}")
    content = access_secret(project, secret)
    print(content)
PYTHON_EOF

    chmod +x "${script_file}"

    log_info "Python script created"
    log_info "Usage:"
    echo "  python ${script_file}"
    echo "  python ${script_file} different-secret-name"
}

# Cleanup function
cleanup_secrets() {
    log_step "Cleanup Temporary Secrets"

    if [ -d "${OUTPUT_DIR}" ]; then
        log_warn "Removing temporary secrets from: ${OUTPUT_DIR}"
        read -p "Are you sure? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Securely wipe files before deletion (overwrite with random data)
            find "${OUTPUT_DIR}" -type f -exec shred -u {} \; 2>/dev/null || rm -rf "${OUTPUT_DIR}"
            log_info "Temporary secrets removed"
        else
            log_info "Cleanup cancelled"
        fi
    else
        log_info "No temporary secrets found"
    fi
}

# Main menu
show_menu() {
    echo
    echo "Secret Access Methods for Local Development"
    echo "============================================"
    echo "Project: ${PROJECT_ID}"
    echo "Secret: ${SECRET_NAME}"
    echo
    echo "1) Direct access (print to console)"
    echo "2) Save to temporary file"
    echo "3) Show export command"
    echo "4) List all versions"
    echo "5) Access specific version"
    echo "6) Create Python SDK script"
    echo "7) Cleanup temporary files"
    echo "8) Change secret name"
    echo "9) Exit"
    echo
}

# Main execution
main() {
    log_info "Local Secret Access Tool"
    echo

    # Check access first
    check_access

    # Interactive menu
    while true; do
        show_menu
        read -p "Select option (1-9): " choice

        case $choice in
            1) access_direct ;;
            2) access_to_file ;;
            3) access_with_env ;;
            4) list_versions ;;
            5)
                read -p "Enter version number: " version
                access_specific_version "${version}"
                ;;
            6) create_python_script ;;
            7) cleanup_secrets ;;
            8)
                read -p "Enter secret name: " SECRET_NAME
                check_access
                ;;
            9)
                log_info "Exiting"
                echo
                log_warn "Remember to cleanup temporary files!"
                echo "  Run with option 7 or: rm -rf ${OUTPUT_DIR}"
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

# Handle script arguments
if [ $# -gt 0 ]; then
    case "$1" in
        --cleanup)
            cleanup_secrets
            exit 0
            ;;
        --list)
            list_versions
            exit 0
            ;;
        --help)
            echo "Usage: $0 [SECRET_NAME|--cleanup|--list|--help]"
            echo
            echo "Arguments:"
            echo "  SECRET_NAME  Secret to access (default: demo-app-sa-key)"
            echo "  --cleanup    Remove temporary secret files"
            echo "  --list       List all versions of secret"
            echo "  --help       Show this help"
            exit 0
            ;;
    esac
fi

main "$@"
