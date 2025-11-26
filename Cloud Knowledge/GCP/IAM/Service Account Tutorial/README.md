# GCP Service Accounts and Storage IAM Roles Tutorial

## Overview

When someone says "Create a SA with Storage Object Creator on your bucket," they're asking you to create a Google Cloud **Service Account** (SA) and grant it the **Storage Object Creator** role on a specific Cloud Storage bucket. This tutorial explains what this means, why it's important, and how to implement it securely.

Service Accounts are non-human identities used by applications, services, and workloads to authenticate and interact with Google Cloud resources. The Storage Object Creator role is a tightly scoped IAM role that allows creating objects in Cloud Storage without granting unnecessary read or delete permissions.

## Prerequisites

Before starting this tutorial, you should understand:
- [[GCP Overview]] - Basic Google Cloud Platform concepts
- [[GKE Overview]] - If using from Kubernetes environments
- Basic command-line interface (CLI) usage
- Have `gcloud` CLI installed and configured

Required setup:
```bash
# Verify gcloud is installed
gcloud --version

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Authenticate
gcloud auth login
```

## Key Concepts

### What is a Service Account?

A Service Account (SA) is a special type of Google Cloud identity intended for non-human entities like applications, services, virtual machines, or containers. Unlike user accounts tied to specific people, Service Accounts are designed for programmatic access.

**Key Characteristics:**
- Has an email format: `service-account-name@project-id.iam.gserviceaccount.com`
- Used by applications and services (not humans)
- Can have IAM roles assigned to grant specific permissions
- Authentication uses keys or Workload Identity (preferred in Kubernetes)
- Each GCP project can have up to 100 Service Accounts

**Why Use Service Accounts?**
- **Security**: Separate identity for each application/service
- **Traceability**: Audit logs show which service performed actions
- **Least Privilege**: Grant only the permissions each service needs
- **Automation**: No human intervention needed for authentication

### What is Storage Object Creator Role?

The Storage Object Creator (`roles/storage.objectCreator`) is a predefined IAM role that grants minimal permissions needed to **create** objects in Cloud Storage buckets.

**Permissions Granted:**
```
storage.objects.create  # Upload/create new objects
storage.objects.list    # List objects (limited)
```

**Permissions NOT Granted:**
- Cannot read/download existing objects
- Cannot delete objects
- Cannot modify bucket configuration
- Cannot change bucket IAM policies

**Why This Matters:**
This follows the **Principle of Least Privilege** - the service account can only perform its intended function (uploading files) and nothing more. If the credentials are compromised, an attacker cannot read sensitive data or delete important files.

### Bucket-Level vs Project-Level IAM

IAM roles can be granted at different levels in the GCP resource hierarchy:

**Project-Level IAM:**
```bash
# This grants access to ALL buckets in the project
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:uploader@$PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator
```

**Bucket-Level IAM (Recommended):**
```bash
# This grants access to ONLY the specific bucket
gcloud storage buckets add-iam-policy-binding gs://my-specific-bucket \
    --member=serviceAccount:uploader@$PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator
```

**Why Bucket-Level is Better:**
- **Granular Security**: Different services can have access to different buckets
- **Limited Blast Radius**: If credentials leak, only one bucket is affected
- **Compliance**: Easier to meet regulatory requirements for data isolation
- **Cost Tracking**: Better visibility into which services access which data

## How It Works

### Service Account Authentication Flow

```
┌─────────────────┐
│  Application    │
│  (Your Code)    │
└────────┬────────┘
         │ 1. Uses Service Account credentials
         ↓
┌─────────────────┐
│ Service Account │ uploader@project.iam.gserviceaccount.com
└────────┬────────┘
         │ 2. Has Storage Object Creator role on bucket
         ↓
┌─────────────────┐
│  IAM Policy     │ Checks: Does SA have objectCreator on this bucket?
└────────┬────────┘
         │ 3. Authorization granted
         ↓
┌─────────────────┐
│  Cloud Storage  │ gs://my-bucket/
│     Bucket      │ ✓ Allows: upload new files
└─────────────────┘ ✗ Denies: read, delete, admin operations
```

### IAM Role Hierarchy

Understanding the different Storage roles and their capabilities:

| Role | Role ID | Create | Read | Delete | Manage Bucket |
|------|---------|--------|------|--------|---------------|
| **Storage Object Viewer** | `roles/storage.objectViewer` | ✗ | ✓ | ✗ | ✗ |
| **Storage Object Creator** | `roles/storage.objectCreator` | ✓ | ✗* | ✗ | ✗ |
| **Storage Object User** | `roles/storage.objectUser` | ✓ | ✓ | ✓ | ✗ |
| **Storage Object Admin** | `roles/storage.objectAdmin` | ✓ | ✓ | ✓ | Some |
| **Storage Admin** | `roles/storage.admin` | ✓ | ✓ | ✓ | ✓ |

*Object Creator can list objects but cannot read their contents.

## Real-World Use Cases

### Use Case 1: Recording Service for Voice/Video Calls

**Scenario:** You have a real-time communication application (like the interview-agent) that records audio/video conversations and needs to save them to Cloud Storage.

**Implementation:**
```python
# The recording agent needs to:
# 1. Record audio/video streams
# 2. Save recordings to GCS bucket
# 3. NOT access other recordings (privacy)

# Service Account: recording-agent@project.iam.gserviceaccount.com
# Role: Storage Object Creator on gs://interview-recordings/
# Why: Can upload new recordings but cannot read existing ones
```

**Benefits:**
- Recording service cannot access existing recordings (privacy)
- If credentials leak, attacker cannot download recordings
- Complies with data protection regulations

### Use Case 2: Application Log Aggregation

**Scenario:** Multiple application instances write logs to a centralized Cloud Storage bucket for long-term retention and analysis.

**Implementation:**
```bash
# Each application instance uses the same SA
# Service Account: log-writer@project.iam.gserviceaccount.com
# Role: Storage Object Creator on gs://application-logs/
```

**Benefits:**
- Applications can write logs but not read or delete them
- Prevents accidental or malicious log deletion
- Log analysis is done by a separate service with read permissions

### Use Case 3: CI/CD Pipeline Artifact Storage

**Scenario:** Your CI/CD pipeline builds artifacts (Docker images, compiled binaries, etc.) and uploads them to Cloud Storage for deployment.

**Implementation:**
```yaml
# In your CI/CD pipeline (e.g., GitHub Actions, Cloud Build)
# Service Account: ci-artifact-uploader@project.iam.gserviceaccount.com
# Role: Storage Object Creator on gs://build-artifacts/

# Deployment pipeline uses different SA with read access
# Service Account: deployment-reader@project.iam.gserviceaccount.com
# Role: Storage Object Viewer on gs://build-artifacts/
```

**Benefits:**
- Build pipeline cannot modify existing artifacts (immutability)
- Separation of duties between build and deployment
- Audit trail shows which pipeline uploaded which artifacts

### Use Case 4: Data Ingestion Pipeline

**Scenario:** IoT devices or external systems continuously upload sensor data, metrics, or events to Cloud Storage for batch processing.

**Implementation:**
```bash
# Service Account: data-ingestion@project.iam.gserviceaccount.com
# Role: Storage Object Creator on gs://raw-sensor-data/
# Data processing jobs use different SA with read access
```

**Benefits:**
- Ingestion services cannot interfere with existing data
- Raw data remains immutable once uploaded
- Clear separation between data producers and consumers

## Hands-On Examples

### Example 1: Create Service Account

First, let's create a Service Account for an application that needs to upload files to Cloud Storage.

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Create a service account
gcloud iam service-accounts create demo-uploader \
    --display-name="Demo File Uploader Service Account" \
    --description="Service account for uploading files to Cloud Storage"

# Verify the service account was created
gcloud iam service-accounts list --filter="email:demo-uploader@"

# Output will show:
# DISPLAY NAME                          EMAIL
# Demo File Uploader Service Account    demo-uploader@your-project-id.iam.gserviceaccount.com
```

**Explanation:** This creates a new Service Account identity. At this point, it has no permissions - it's just an identity that can be used by applications.

### Example 2: Grant Storage Object Creator Role on a Bucket

Now let's grant the Service Account permission to create objects in a specific bucket.

```bash
# Create a demo bucket (skip if you already have one)
gcloud storage buckets create gs://demo-upload-bucket-$PROJECT_ID \
    --location=us-central1 \
    --uniform-bucket-level-access

# Grant Storage Object Creator role on the bucket
gcloud storage buckets add-iam-policy-binding gs://demo-upload-bucket-$PROJECT_ID \
    --member=serviceAccount:demo-uploader@$PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator

# Alternative using gsutil (older tool)
gsutil iam ch serviceAccount:demo-uploader@$PROJECT_ID.iam.gserviceaccount.com:objectCreator \
    gs://demo-upload-bucket-$PROJECT_ID
```

**Explanation:** This adds an IAM policy binding that says "the demo-uploader Service Account has the Storage Object Creator role on this specific bucket." The Service Account can now upload files to this bucket, but nothing else.

### Example 3: Verify Permissions

Let's verify what permissions the Service Account has.

```bash
# View the bucket's IAM policy
gcloud storage buckets get-iam-policy gs://demo-upload-bucket-$PROJECT_ID

# You should see an entry like:
# - members:
#   - serviceAccount:demo-uploader@your-project-id.iam.gserviceaccount.com
#   role: roles/storage.objectCreator

# Test what permissions the SA has
gcloud storage buckets test-iam-permissions gs://demo-upload-bucket-$PROJECT_ID \
    --permissions=storage.objects.create,storage.objects.delete,storage.objects.get

# Output shows which permissions are granted:
# storage.objects.create: True   ✓ Can create
# storage.objects.delete: False  ✗ Cannot delete
# storage.objects.get: False     ✗ Cannot read
```

**Explanation:** This confirms that our Service Account has only the permissions we intended - it can create objects but cannot read or delete them.

### Example 4: Use Service Account from Application

Here's how to use the Service Account from a Python application to upload files to Cloud Storage.

See the full Python example in `code/upload_to_gcs.py`.

**Basic Usage:**
```python
from google.cloud import storage
import os

def upload_file_to_gcs(bucket_name, source_file_path, destination_blob_name):
    """
    Uploads a file to Google Cloud Storage using the Service Account
    credentials configured in the environment.
    """
    # Initialize storage client
    # It will automatically use the Service Account credentials
    # from the environment (GOOGLE_APPLICATION_CREDENTIALS)
    storage_client = storage.Client()

    # Get bucket reference
    bucket = storage_client.bucket(bucket_name)

    # Create blob (object) reference
    blob = bucket.blob(destination_blob_name)

    # Upload the file
    blob.upload_from_filename(source_file_path)

    print(f"File {source_file_path} uploaded to gs://{bucket_name}/{destination_blob_name}")

# Usage
if __name__ == "__main__":
    upload_file_to_gcs(
        bucket_name="demo-upload-bucket-your-project-id",
        source_file_path="./test-file.txt",
        destination_blob_name="uploads/test-file.txt"
    )
```

**To run this locally:**
```bash
# Download Service Account key (for local development only)
gcloud iam service-accounts keys create ~/demo-uploader-key.json \
    --iam-account=demo-uploader@$PROJECT_ID.iam.gserviceaccount.com

# Set environment variable to use the key
export GOOGLE_APPLICATION_CREDENTIALS=~/demo-uploader-key.json

# Run the Python script
python code/upload_to_gcs.py
```

**Explanation:** The application uses the Service Account credentials to authenticate with Google Cloud. When it tries to upload a file, Google Cloud checks the IAM policy and allows the operation because the Service Account has the `objectCreator` role on the bucket.

### Example 5: Use from GKE with Workload Identity (Recommended)

For production use in [[GKE Overview|Kubernetes clusters]], use Workload Identity instead of JSON keys.

```bash
# 1. Enable Workload Identity on your cluster (if not already enabled)
gcloud container clusters update CLUSTER_NAME \
    --workload-pool=$PROJECT_ID.svc.id.goog

# 2. Create Kubernetes Service Account
kubectl create serviceaccount demo-uploader-ksa \
    --namespace=default

# 3. Bind GCP Service Account to Kubernetes Service Account
gcloud iam service-accounts add-iam-policy-binding \
    demo-uploader@$PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/iam.workloadIdentityUser \
    --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/demo-uploader-ksa]"

# 4. Annotate the Kubernetes Service Account
kubectl annotate serviceaccount demo-uploader-ksa \
    --namespace=default \
    iam.gke.io/gcp-service-account=demo-uploader@$PROJECT_ID.iam.gserviceaccount.com

# 5. Use in your pod
kubectl run test-uploader \
    --image=your-app-image \
    --serviceaccount=demo-uploader-ksa
```

**Explanation:** Workload Identity allows your Kubernetes pods to authenticate as the GCP Service Account without needing to manage JSON key files. This is more secure and easier to manage. See [[GKE Workload Identity]] for more details.

## Best Practices

### 1. Use Bucket-Level IAM Bindings
**Why:** Limits the scope of access to only what's needed.

```bash
# ✓ GOOD: Grants access to one bucket
gcloud storage buckets add-iam-policy-binding gs://specific-bucket \
    --member=serviceAccount:sa@project.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator

# ✗ BAD: Grants access to all buckets in project
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member=serviceAccount:sa@project.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator
```

### 2. Use the Most Restrictive Role Needed
**Why:** Reduces risk if credentials are compromised.

```bash
# ✓ GOOD: Only can create objects
--role=roles/storage.objectCreator

# ✗ BAD: Can do everything (unless you really need it)
--role=roles/storage.admin
```

### 3. One Service Account Per Service/Application
**Why:** Better security isolation and audit trails.

```bash
# ✓ GOOD: Separate service accounts
gcloud iam service-accounts create recording-service
gcloud iam service-accounts create log-aggregator
gcloud iam service-accounts create artifact-uploader

# ✗ BAD: One SA shared by all services
gcloud iam service-accounts create shared-uploader
```

### 4. Prefer Workload Identity Over JSON Keys
**Why:** No key file management, automatic rotation, better security.

```bash
# ✓ GOOD: Use Workload Identity in GKE
# No key files, automatic credential management

# ✗ BAD: Download and distribute JSON keys
gcloud iam service-accounts keys create key.json --iam-account=sa@project.iam.gserviceaccount.com
# Now you have to manage, rotate, and secure this file
```

### 5. Enable Audit Logging
**Why:** Track who did what and when.

```bash
# Enable Data Access audit logs for Cloud Storage
# This logs all object creations with the Service Account identity
gcloud projects set-iam-policy $PROJECT_ID \
    --update-policy-bindings-from-file=audit-config.yaml
```

### 6. Use Descriptive Service Account Names
**Why:** Makes it clear what each SA is used for.

```bash
# ✓ GOOD: Clear purpose
recording-agent-uploader@project.iam.gserviceaccount.com
ci-artifact-publisher@project.iam.gserviceaccount.com
log-writer-prod@project.iam.gserviceaccount.com

# ✗ BAD: Unclear purpose
sa1@project.iam.gserviceaccount.com
test@project.iam.gserviceaccount.com
```

### 7. Set Expiration on Keys (If You Must Use Them)
**Why:** Limits the window of exposure if keys leak.

```bash
# Create key with 90-day expiration
gcloud iam service-accounts keys create key.json \
    --iam-account=demo-uploader@$PROJECT_ID.iam.gserviceaccount.com

# Set reminder to rotate in 90 days
# Better: Use Workload Identity and avoid keys entirely
```

### 8. Use Separate Buckets for Different Data Types
**Why:** Easier to manage permissions and comply with data retention policies.

```bash
# ✓ GOOD: Separate buckets
gs://prod-user-uploads/      # User-generated content
gs://prod-system-logs/        # System logs
gs://prod-recordings/         # Voice recordings
gs://prod-backups/           # Database backups

# ✗ BAD: Everything in one bucket
gs://prod-data/  # Mixed content types, hard to manage access
```

## Common Pitfalls & Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| **403 Forbidden when uploading** | Service Account doesn't have `objectCreator` role on the bucket | Verify IAM binding: `gcloud storage buckets get-iam-policy gs://bucket-name` and add missing role |
| **403 Forbidden when trying to read after upload** | `objectCreator` role doesn't grant read permissions | This is expected behavior. Grant `objectViewer` role if reading is needed, or use `objectUser` role |
| **Cannot list objects in bucket** | Service Account needs `storage.objects.list` permission | Grant `roles/storage.objectViewer` in addition to `objectCreator`, or use `roles/storage.objectUser` |
| **"Default credentials not found" error** | Application cannot find Service Account credentials | Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable to path of JSON key file |
| **Service Account key file not working in GKE** | JSON keys are not the recommended approach in Kubernetes | Use Workload Identity instead: [[GKE Workload Identity]] |
| **Can upload but cannot see files in Console** | This is expected - `objectCreator` can't read | Grant yourself (your user account) `objectViewer` role to see files in Console |
| **Accidental project-level role grant** | Used `gcloud projects add-iam-policy-binding` instead of bucket-level | Remove project-level binding and add bucket-level binding instead |
| **Cannot delete test uploads** | Service Account has `objectCreator` (create only) | Use your user account or a SA with `objectAdmin` to delete test files |
| **Service Account quota exceeded** | Trying to create more than 100 SAs in a project | Delete unused Service Accounts or request quota increase |
| **Workload Identity not working** | Missing annotation or IAM binding | Verify: 1) GKE cluster has WI enabled, 2) K8s SA is annotated, 3) IAM binding exists |

## Related Topics

- [[GKE Overview]] - Using Service Accounts in Google Kubernetes Engine
- [[GKE Workload Identity]] - Preferred method for SA authentication in Kubernetes
- [[Kubernetes ServiceAccounts]] - Understanding the relationship between K8s SA and GCP SA
- [[GCP IAM Overview]] - Broader context of Identity and Access Management in GCP
- [[Cloud Storage Best Practices]] - Comprehensive guide to GCS security and optimization

## Further Learning

### Official Documentation
- [Service Accounts Overview](https://cloud.google.com/iam/docs/service-accounts) - Google Cloud official documentation
- [Cloud Storage IAM Roles](https://cloud.google.com/storage/docs/access-control/iam-roles) - Complete list of Storage IAM roles
- [Workload Identity Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity) - Kubernetes authentication best practices

### Tutorials & Guides
- [IAM Best Practices](https://cloud.google.com/iam/docs/best-practices-service-accounts) - Google's recommended patterns
- [Securing Cloud Storage](https://cloud.google.com/storage/docs/best-practices) - Comprehensive security guide

### Tools & Scripts
- See the `scripts/` directory for ready-to-use bash scripts
- See the `code/` directory for Python implementation examples

## Quick Reference Commands

```bash
# Create Service Account
gcloud iam service-accounts create NAME --display-name="DISPLAY_NAME"

# Grant Storage Object Creator on bucket
gcloud storage buckets add-iam-policy-binding gs://BUCKET_NAME \
    --member=serviceAccount:SA_EMAIL \
    --role=roles/storage.objectCreator

# View bucket IAM policy
gcloud storage buckets get-iam-policy gs://BUCKET_NAME

# Test permissions
gcloud storage buckets test-iam-permissions gs://BUCKET_NAME \
    --permissions=storage.objects.create,storage.objects.get,storage.objects.delete

# Create key (local dev only)
gcloud iam service-accounts keys create key.json \
    --iam-account=SA_EMAIL

# List Service Accounts
gcloud iam service-accounts list

# Delete Service Account (cleanup)
gcloud iam service-accounts delete SA_EMAIL
```

## Tags
#gcp #iam #service-account #cloud-storage #security #tutorial #hands-on

---

**Next Steps:**
1. Try the hands-on examples in the `scripts/` directory
2. Review the Python code in `code/upload_to_gcs.py`
3. Implement in your own project following the best practices
4. Explore [[GKE Workload Identity]] for production deployments
