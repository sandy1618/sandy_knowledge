# Google Secret Manager with GKE Integration Tutorial

## Overview
This comprehensive tutorial demonstrates how to securely manage secrets in Google Cloud Platform using Secret Manager and integrate them with Google Kubernetes Engine (GKE) workloads. You'll learn to create, manage, and rotate secrets, grant appropriate IAM permissions, and mount secrets into Kubernetes pods using the Secrets Store CSI driver. By the end, you'll be able to implement production-ready secret management for your containerized applications.

## Prerequisites
- [[GKE Overview]] - Understanding of Google Kubernetes Engine basics
- [[GCP IAM Overview]] - Familiarity with GCP Identity and Access Management
- [[GKE Workload Identity]] - Knowledge of Workload Identity Federation
- [[GCP Service Accounts and Storage Roles]] - Service account fundamentals
- Active GCP project with billing enabled
- `gcloud` CLI installed and authenticated
- `kubectl` configured to access your GKE cluster
- Basic understanding of Kubernetes concepts (pods, volumes, service accounts)

## Key Concepts

### What is Google Secret Manager?
Google Secret Manager is a fully managed service for storing and managing sensitive data such as API keys, passwords, certificates, and service account keys. Unlike storing secrets in environment variables or configuration files, Secret Manager provides:

- **Centralized Storage**: Single source of truth for all secrets across your organization
- **Encryption at Rest**: Automatic encryption using Google-managed or customer-managed keys
- **Version Control**: Maintain multiple versions of secrets with automatic versioning
- **IAM Integration**: Fine-grained access control using GCP IAM policies
- **Audit Logging**: Complete audit trail of secret access and modifications
- **Automatic Replication**: Optional multi-region replication for high availability

### Secret Manager IAM Roles
Understanding the permission model is crucial for secure secret management:

| Role | Description | Use Case |
|------|-------------|----------|
| `roles/secretmanager.secretAccessor` | Read secret payload data | Grant to service accounts that need to consume secrets |
| `roles/secretmanager.viewer` | View secret metadata only (no payload access) | Audit and monitoring purposes |
| `roles/secretmanager.admin` | Full management of secrets | DevOps teams managing secret lifecycle |
| `roles/secretmanager.secretVersionManager` | Add new versions, disable/enable versions | Secret rotation automation |

### Secret Versioning
Every secret in Secret Manager supports multiple versions:

- **versions/latest**: Always points to the newest enabled version
- **versions/1, versions/2, etc.**: Specific version numbers
- **Enabled/Disabled**: Control which versions are accessible
- **Immutable**: Once created, version content cannot be changed

This allows for:
- Zero-downtime secret rotation
- Rollback capability if new secrets cause issues
- Gradual rollout of new credentials

### GKE Secrets Store CSI Driver
The Container Storage Interface (CSI) driver provides a standard way to mount secrets from external systems into Kubernetes pods:

- **Declarative Configuration**: Define secrets using `SecretProviderClass` resources
- **Automatic Fetching**: Driver fetches secrets at pod creation time
- **File-based Access**: Secrets appear as files in the pod filesystem
- **No Code Changes**: Applications read secrets as files, no SDK required
- **Kubernetes Secret Sync**: Optionally sync to native Kubernetes Secrets for env vars

## How It Works

### End-to-End Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Google Secret Manager                   │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Secret: my-app-credentials                      │      │
│  │  ├─ versions/1 (disabled)                        │      │
│  │  ├─ versions/2 (enabled)                         │      │
│  │  └─ versions/latest → versions/2                 │      │
│  └──────────────────────────────────────────────────┘      │
└────────────────────┬────────────────────────────────────────┘
                     │
                IAM Policy
        (secretAccessor role granted to)
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              GCP Service Account                            │
│         demo-app@my-project.iam.gserviceaccount.com        │
└────────────────────┬────────────────────────────────────────┘
                     │
        Workload Identity Binding
     (K8s SA ↔ GCP SA association)
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│          Kubernetes Service Account                         │
│              namespace: default                             │
│              name: demo-app-ksa                            │
└────────────────────┬────────────────────────────────────────┘
                     │
              Pod uses this KSA
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  Secrets Store CSI Driver                   │
│  1. Detects SecretProviderClass mounted in pod              │
│  2. Uses pod's KSA to authenticate as GCP SA (via WI)      │
│  3. Fetches secret payload from Secret Manager             │
│  4. Mounts secret as file in pod                           │
└────────────────────┬────────────────────────────────────────┘
                     │
               Mounts to volume
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    Application Pod                          │
│  Volume Mount: /var/secrets/                               │
│  ├─ credentials.json                                       │
│  └─ api-key.txt                                            │
│                                                             │
│  Application reads files and uses credentials              │
└─────────────────────────────────────────────────────────────┘
```

### Authentication Flow Details

1. **Pod Creation**: Kubernetes scheduler creates pod with specified service account
2. **Workload Identity**: Pod's service account has annotation pointing to GCP service account
3. **Token Exchange**: CSI driver exchanges Kubernetes token for GCP access token
4. **IAM Authorization**: GCP verifies the service account has `secretAccessor` role
5. **Secret Retrieval**: Driver fetches secret payload from Secret Manager
6. **File Creation**: Secret content written to volume mounted in pod
7. **Application Access**: Application reads secret from file path

## Real-World Use Cases

### Use Case 1: Database Credentials for Microservices
**Scenario**: A microservices application needs to connect to Cloud SQL database with rotating credentials.

**Implementation**:
- Store database password in Secret Manager
- Mount as file in application pods via CSI driver
- Application reads credentials at startup
- Rotate password monthly by adding new secret version
- Old version automatically disabled after rotation period

**Benefits**:
- No credentials in source code or container images
- Zero-downtime rotation (new pods get new password)
- Centralized credential management across services
- Audit trail of which services accessed credentials

### Use Case 2: Service Account Key for Cloud Storage Access
**Scenario**: Application needs to upload files to Cloud Storage using a service account key.

**Implementation**:
- Create service account with Storage Object Creator role
- Generate JSON key and store in Secret Manager
- Mount key file in application pods
- Application uses GOOGLE_APPLICATION_CREDENTIALS environment variable pointing to mounted file

**Benefits**:
- Key never stored in git repository or CI/CD pipeline
- Same deployment manifest works across dev/staging/prod (different secrets)
- Key rotation without rebuilding containers
- Revoke access by disabling secret version

### Use Case 3: API Keys for Third-Party Services
**Scenario**: Application integrates with external APIs (Stripe, SendGrid, etc.) requiring API keys.

**Implementation**:
- Store each API key as separate secret in Secret Manager
- Use SecretProviderClass to mount multiple secrets
- Optionally sync to Kubernetes Secret for environment variable access
- Rotate keys according to security policy

**Benefits**:
- Different teams can manage different API keys (IAM separation)
- Version history for compliance auditing
- Separate secrets per environment without code changes

## Hands-On Examples

### Example 1: Creating Your First Secret

```bash
# Create a simple text secret
echo -n "my-super-secret-password" | \
  gcloud secrets create my-first-secret \
  --project=my-project-dev \
  --replication-policy="automatic" \
  --data-file=-

# Verify creation
gcloud secrets describe my-first-secret \
  --project=my-project-dev

# View versions
gcloud secrets versions list my-first-secret \
  --project=my-project-dev
```

**Explanation**: This creates a secret with automatic replication across GCP regions. The `--data-file=-` reads from stdin, keeping the secret out of shell history. The secret is created with version 1 in enabled state.

### Example 2: Creating Secret from Service Account Key

```bash
# Create service account
gcloud iam service-accounts create demo-app-sa \
  --project=my-project-dev \
  --display-name="Demo Application Service Account"

# Grant Cloud Storage permissions
gcloud projects add-iam-policy-binding my-project-dev \
  --member="serviceAccount:demo-app-sa@my-project-dev.iam.gserviceaccount.com" \
  --role="roles/storage.objectCreator"

# Create key and store directly in Secret Manager (one command!)
gcloud iam service-accounts keys create /dev/stdout \
  --iam-account=demo-app-sa@my-project-dev.iam.gserviceaccount.com \
  --format=json | \
gcloud secrets create demo-app-sa-key \
  --project=my-project-dev \
  --replication-policy="automatic" \
  --data-file=-

# Verify secret contains valid JSON
gcloud secrets versions access latest \
  --secret=demo-app-sa-key \
  --project=my-project-dev | jq .
```

**Explanation**: This pipeline pattern creates a service account key and stores it directly in Secret Manager without ever writing to disk. The key never touches your local filesystem, reducing exposure risk.

### Example 3: Granting Access to GKE Service Account

```bash
# Grant secret access to the GCP service account used by your GKE workload
gcloud secrets add-iam-policy-binding demo-app-sa-key \
  --project=my-project-dev \
  --member="serviceAccount:demo-app-sa@my-project-dev.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Verify permissions
gcloud secrets get-iam-policy demo-app-sa-key \
  --project=my-project-dev
```

**Explanation**: This grants the `secretAccessor` role specifically for this secret. The service account can only read this secret's payload, not list all secrets or modify versions. This follows the principle of least privilege.

### Example 4: Complete SecretProviderClass Configuration

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: demo-app-secrets
  namespace: default
spec:
  provider: gcp
  parameters:
    # Secrets to fetch from Secret Manager
    secrets: |
      - resourceName: "projects/123456789/secrets/demo-app-sa-key/versions/latest"
        path: "credentials.json"
      - resourceName: "projects/123456789/secrets/api-key/versions/latest"
        path: "api-key.txt"

  # Optional: Sync to Kubernetes Secret for environment variables
  secretObjects:
  - secretName: demo-app-secret
    type: Opaque
    data:
    - key: sa-key
      objectName: "credentials.json"
    - key: api-key
      objectName: "api-key.txt"
```

**Explanation**: The `resourceName` uses the full resource path including project number (not ID) and version. Files are created at `/var/secrets/{path}`. The optional `secretObjects` section syncs the same data to a Kubernetes Secret, allowing access via environment variables.

### Example 5: Deployment with Secret Mount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-app-ksa
  namespace: default
  annotations:
    # Link to GCP service account via Workload Identity
    iam.gke.io/gcp-service-account: demo-app-sa@my-project-dev.iam.gserviceaccount.com
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      serviceAccountName: demo-app-ksa

      containers:
      - name: app
        image: gcr.io/my-project-dev/demo-app:latest

        # Environment variable pointing to mounted secret
        env:
        - name: GOOGLE_APPLICATION_CREDENTIALS
          value: /var/secrets/credentials.json
        - name: API_KEY_FILE
          value: /var/secrets/api-key.txt

        # Mount secrets as files
        volumeMounts:
        - name: secrets
          mountPath: /var/secrets
          readOnly: true

      volumes:
      - name: secrets
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: demo-app-secrets
```

**Explanation**: The CSI driver volume type references the SecretProviderClass. When the pod starts, the driver fetches secrets and mounts them before the container starts. The `readOnly: true` ensures the application cannot modify secrets.

### Example 6: Rotating a Secret

```bash
# Generate new service account key
NEW_KEY=$(gcloud iam service-accounts keys create /dev/stdout \
  --iam-account=demo-app-sa@my-project-dev.iam.gserviceaccount.com \
  --format=json)

# Add as new version to existing secret
echo -n "$NEW_KEY" | \
gcloud secrets versions add demo-app-sa-key \
  --project=my-project-dev \
  --data-file=-

# List versions (new version is now "latest")
gcloud secrets versions list demo-app-sa-key \
  --project=my-project-dev

# Restart pods to pick up new version
kubectl rollout restart deployment demo-app -n default

# After verifying new version works, disable old version
gcloud secrets versions disable 1 \
  --secret=demo-app-sa-key \
  --project=my-project-dev

# Delete old key from service account
gcloud iam service-accounts keys delete OLD_KEY_ID \
  --iam-account=demo-app-sa@my-project-dev.iam.gserviceaccount.com
```

**Explanation**: Adding a new version automatically makes it the "latest" version. Existing pods continue using the old version until restarted. This allows gradual rollout and easy rollback if issues occur.

### Example 7: Local Development Access

```bash
# Access secret for local testing
gcloud secrets versions access latest \
  --secret=demo-app-sa-key \
  --project=my-project-dev > /tmp/credentials.json

# Use in application
export GOOGLE_APPLICATION_CREDENTIALS=/tmp/credentials.json
python app.py

# Clean up after testing
rm /tmp/credentials.json
```

**Explanation**: Local developers can access secrets using their own `gcloud` credentials (if granted `secretAccessor` role). This provides the same secret content as production without hardcoding credentials.

### Example 8: Python Application Reading Mounted Secret

```python
import json
import os
from google.cloud import storage

def initialize_storage_client():
    """Initialize Cloud Storage client using mounted service account key."""

    # Path where CSI driver mounts the secret
    credentials_path = os.getenv(
        'GOOGLE_APPLICATION_CREDENTIALS',
        '/var/secrets/credentials.json'
    )

    # Verify file exists (helps catch configuration issues)
    if not os.path.exists(credentials_path):
        raise FileNotFoundError(
            f"Service account key not found at {credentials_path}. "
            "Verify SecretProviderClass and volume mount configuration."
        )

    # Validate JSON structure
    with open(credentials_path, 'r') as f:
        key_data = json.load(f)
        required_fields = ['type', 'project_id', 'private_key', 'client_email']
        missing = [field for field in required_fields if field not in key_data]
        if missing:
            raise ValueError(f"Service account key missing fields: {missing}")

    # Initialize client (automatically uses GOOGLE_APPLICATION_CREDENTIALS)
    client = storage.Client()

    return client

def upload_file(bucket_name, source_file, destination_blob):
    """Upload file to Cloud Storage using authenticated client."""
    client = initialize_storage_client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(destination_blob)
    blob.upload_from_filename(source_file)
    print(f"Uploaded {source_file} to gs://{bucket_name}/{destination_blob}")

if __name__ == "__main__":
    # Example usage
    upload_file(
        bucket_name="demo-bucket",
        source_file="/app/data/report.pdf",
        destination_blob="reports/2024/report.pdf"
    )
```

**Explanation**: The application reads credentials from a file path set via environment variable. The Google Cloud client libraries automatically detect and use these credentials. Error handling helps diagnose configuration issues.

## Best Practices

### 1. Use Workload Identity Instead of Key-Based Authentication
**Rationale**: Workload Identity allows GKE pods to authenticate as GCP service accounts without managing keys. This eliminates key rotation overhead and reduces credential exposure risk. Use service account keys only when Workload Identity is not available (legacy systems, external Kubernetes clusters).

**Implementation**: Always configure Workload Identity bindings and use the annotation `iam.gke.io/gcp-service-account` on Kubernetes ServiceAccounts.

### 2. Grant Least Privilege Access
**Rationale**: Following the principle of least privilege minimizes blast radius if credentials are compromised.

**Implementation**:
- Grant `secretAccessor` role per-secret, not at project level
- Create separate service accounts for different applications
- Use separate secrets for dev/staging/prod environments
- Regularly audit IAM policies with `gcloud secrets get-iam-policy`

### 3. Enable Automatic Replication with User-Managed Keys
**Rationale**: Automatic replication ensures high availability across regions. Customer-managed encryption keys (CMEK) provide additional control and compliance benefits.

**Implementation**:
```bash
# Create secret with CMEK
gcloud secrets create my-secret \
  --replication-policy="automatic" \
  --kms-key-name="projects/my-project/locations/us/keyRings/my-ring/cryptoKeys/my-key"
```

### 4. Implement Regular Secret Rotation
**Rationale**: Regular rotation limits the window of opportunity if credentials are leaked. Automated rotation reduces human error.

**Implementation**:
- Add new secret version monthly/quarterly
- Deploy applications to pick up new version
- Verify functionality before disabling old version
- Automate with Cloud Scheduler + Cloud Functions
- Document rotation procedures for on-call teams

### 5. Use Secret Versioning for Rollback Capability
**Rationale**: Maintaining multiple enabled versions allows instant rollback without re-deploying applications.

**Implementation**:
- Keep at least 2 recent versions enabled
- Test new versions in staging before production
- Use specific version numbers in non-production environments for testing
- Use `versions/latest` in production for automatic updates

### 6. Monitor Secret Access with Cloud Audit Logs
**Rationale**: Audit logs provide visibility into who accessed secrets and when, critical for security investigations and compliance.

**Implementation**:
```bash
# Query audit logs for secret access
gcloud logging read "protoPayload.serviceName=\"secretmanager.googleapis.com\"" \
  --project=my-project-dev \
  --limit=50 \
  --format=json
```

### 7. Sync to Kubernetes Secrets Only When Necessary
**Rationale**: Kubernetes Secrets are base64-encoded (not encrypted) and stored in etcd. Only sync when environment variable access is required.

**Implementation**: Prefer file-based access via CSI driver volumes. Use `secretObjects` in SecretProviderClass only when applications cannot read from files.

### 8. Tag Secrets for Organization and Cost Tracking
**Rationale**: Labels help organize secrets by team, environment, or application, and enable cost allocation.

**Implementation**:
```bash
gcloud secrets create my-secret \
  --labels=env=production,team=backend,app=demo-app
```

## Common Pitfalls & Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| **Pod fails with "permission denied" on secret access** | GCP service account lacks `secretAccessor` role | Verify IAM binding: `gcloud secrets get-iam-policy SECRET_NAME`. Grant role: `gcloud secrets add-iam-policy-binding SECRET_NAME --member=serviceAccount:SA@PROJECT.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor` |
| **SecretProviderClass not mounting secrets** | Secrets Store CSI driver not installed on cluster | Install driver: `kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/main/deploy/rbac-secretproviderclass.yaml` and GCP provider |
| **"Secret not found" error** | Using project ID instead of project number in `resourceName` | Get project number: `gcloud projects describe PROJECT_ID --format="value(projectNumber)"`. Update SecretProviderClass to use number |
| **Workload Identity authentication fails** | Kubernetes ServiceAccount not properly annotated or WI not configured | Verify annotation exists: `kubectl get sa SA_NAME -o yaml`. Check WI binding: `gcloud iam service-accounts get-iam-policy GCP_SA@PROJECT.iam.gserviceaccount.com` |
| **Application gets old secret version after rotation** | Pod not restarted after new version created | Restart deployment: `kubectl rollout restart deployment DEPLOYMENT_NAME`. Consider implementing watch mechanism for automatic detection |
| **"Invalid resource name" in logs** | Incorrect format for `resourceName` in SecretProviderClass | Use format: `projects/PROJECT_NUMBER/secrets/SECRET_NAME/versions/VERSION`. Ensure no typos in secret name |
| **Secret file empty or not created** | CSI driver failed to fetch secret | Check pod events: `kubectl describe pod POD_NAME`. Review CSI driver logs: `kubectl logs -n kube-system -l app=secrets-store-csi-driver` |
| **High latency on pod startup** | Fetching many large secrets sequentially | Reduce number of secrets per SecretProviderClass. Consider caching secrets in application startup |
| **Secrets visible in pod environment** | Using `secretObjects` with env vars | Remove `secretObjects` section and use file-based access only. Set environment variables to point to file paths instead of secret values |
| **Cannot access secret locally with `gcloud`** | User lacks IAM permissions | Grant yourself `secretAccessor` role: `gcloud secrets add-iam-policy-binding SECRET_NAME --member=user:YOUR_EMAIL --role=roles/secretmanager.secretAccessor` |

## Related Topics

- [[GKE Workload Identity]] - Deep dive into Workload Identity configuration and authentication flow
- [[GCP Service Accounts and Storage Roles]] - Understanding service accounts and role assignments for Cloud Storage
- [[GCP IAM Overview]] - Comprehensive guide to GCP's IAM system and permission model
- [[Kubernetes ServiceAccounts]] - How Kubernetes ServiceAccounts work and their role in authentication
- [[GKE Overview]] - Introduction to Google Kubernetes Engine architecture and features
- [[GCP Cloud KMS]] - Customer-managed encryption keys for additional secret security
- [[Kubernetes CSI Drivers]] - Container Storage Interface and how CSI drivers work
- [[GKE Security Best Practices]] - Comprehensive security hardening for GKE clusters

## Further Learning

### Official Documentation
- [Secret Manager Documentation](https://cloud.google.com/secret-manager/docs) - Comprehensive official guide
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) - CSI driver documentation
- [GCP Secret Manager Provider](https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp) - GCP-specific CSI provider

### Tutorials and Guides
- [Best Practices for Secret Manager](https://cloud.google.com/secret-manager/docs/best-practices) - Official security recommendations
- [Workload Identity Setup Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) - Complete WI configuration tutorial
- [Secret Rotation Automation](https://cloud.google.com/secret-manager/docs/secret-rotation) - Automated rotation with Cloud Functions

### Community Resources
- [GCP Secrets Manager Examples](https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/tree/main/examples) - Complete example configurations
- [Kubernetes Secrets Management Comparison](https://www.youtube.com/watch?v=f4Ru6CPG1z4) - Comparison of secret management approaches
- [GKE Security Webinar Series](https://cloudonair.withgoogle.com/events/security-gke) - In-depth security topics including secrets

### Related Tools
- **Sealed Secrets**: GitOps-friendly encrypted Kubernetes Secrets
- **External Secrets Operator**: Synchronize secrets from Secret Manager to Kubernetes
- **Berglas**: CLI tool for Secret Manager with enhanced developer experience
- **Vault**: Alternative secret management with dynamic secrets

## Tutorial Files

This tutorial includes working examples in the following directories:

- `k8s/` - Complete Kubernetes manifests for SecretProviderClass, ServiceAccount, and Deployment
- `scripts/` - Shell scripts for creating, rotating, and accessing secrets
- `code/` - Python examples for reading secrets in applications

Start with `scripts/01-create-secret.sh` to create your first secret, then work through the other scripts in order to complete the tutorial.

## Tags
#gcp #secret-manager #gke #kubernetes #security #iam #workload-identity #csi-driver #secrets-management
