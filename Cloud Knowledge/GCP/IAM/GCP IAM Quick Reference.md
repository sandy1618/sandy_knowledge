# GCP IAM Quick Reference

## Overview

A quick reference guide for common Google Cloud IAM operations, especially focused on Service Accounts and Cloud Storage permissions. For detailed tutorials, see [[Service Account Tutorial/README|GCP Service Accounts and Storage IAM Roles Tutorial]].

## Common Commands

### Service Account Management

```bash
# Create a Service Account
gcloud iam service-accounts create SA_NAME \
    --display-name="DISPLAY_NAME" \
    --description="DESCRIPTION"

# List all Service Accounts
gcloud iam service-accounts list

# Describe a specific Service Account
gcloud iam service-accounts describe SA_EMAIL

# Delete a Service Account
gcloud iam service-accounts delete SA_EMAIL
```

### Cloud Storage IAM

```bash
# Grant role on bucket (recommended - bucket-level)
gcloud storage buckets add-iam-policy-binding gs://BUCKET_NAME \
    --member=serviceAccount:SA_EMAIL \
    --role=ROLE

# Remove role from bucket
gcloud storage buckets remove-iam-policy-binding gs://BUCKET_NAME \
    --member=serviceAccount:SA_EMAIL \
    --role=ROLE

# View bucket IAM policy
gcloud storage buckets get-iam-policy gs://BUCKET_NAME

# Test permissions
gcloud storage buckets test-iam-permissions gs://BUCKET_NAME \
    --permissions=storage.objects.create,storage.objects.get
```

### Service Account Keys (Local Development Only)

```bash
# Create key file
gcloud iam service-accounts keys create KEY_FILE.json \
    --iam-account=SA_EMAIL

# List keys
gcloud iam service-accounts keys list \
    --iam-account=SA_EMAIL

# Delete key
gcloud iam service-accounts keys delete KEY_ID \
    --iam-account=SA_EMAIL

# Use key in application
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/KEY_FILE.json
```

## Common Storage Roles

| Role | Use Case | Can Create | Can Read | Can Delete |
|------|----------|------------|----------|------------|
| `roles/storage.objectViewer` | Read-only access | ✗ | ✓ | ✗ |
| `roles/storage.objectCreator` | Upload only (logs, recordings) | ✓ | ✗ | ✗ |
| `roles/storage.objectUser` | Read and write | ✓ | ✓ | ✓ |
| `roles/storage.objectAdmin` | Full object control | ✓ | ✓ | ✓ |
| `roles/storage.admin` | Full bucket + object control | ✓ | ✓ | ✓ |

## Storage Object Creator Permissions

The `roles/storage.objectCreator` role includes:

```
storage.objects.create   # Upload new objects
storage.objects.list     # List objects (basic)
```

It does NOT include:
- `storage.objects.get` (read/download)
- `storage.objects.delete` (delete)
- `storage.buckets.*` (bucket management)

## Quick Decision Tree

**Need to upload files only?**
→ Use `roles/storage.objectCreator`

**Need to read files only?**
→ Use `roles/storage.objectViewer`

**Need to upload AND read files?**
→ Use `roles/storage.objectUser` or combine `objectCreator` + `objectViewer`

**Need full control over objects?**
→ Use `roles/storage.objectAdmin`

**Need to manage bucket configuration?**
→ Use `roles/storage.admin`

## Best Practices Summary

1. **Bucket-level IAM** over project-level (more granular)
2. **Most restrictive role** needed (least privilege)
3. **Workload Identity** over JSON keys (in GKE)
4. **One SA per service** (better isolation and auditing)
5. **Descriptive SA names** (clear purpose)

## Common Patterns

### Pattern: Upload-Only Service (Recording Agent)

```bash
# Service needs to upload recordings but not read existing ones
gcloud iam service-accounts create recording-uploader
gcloud storage buckets add-iam-policy-binding gs://recordings \
    --member=serviceAccount:recording-uploader@project.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator
```

### Pattern: Read-Only Consumer (Analytics Service)

```bash
# Service needs to read data but not modify it
gcloud iam service-accounts create data-reader
gcloud storage buckets add-iam-policy-binding gs://analytics-data \
    --member=serviceAccount:data-reader@project.iam.gserviceaccount.com \
    --role=roles/storage.objectViewer
```

### Pattern: Separate Upload and Download SAs

```bash
# CI uploads artifacts
gcloud storage buckets add-iam-policy-binding gs://artifacts \
    --member=serviceAccount:ci-uploader@project.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator

# Deployment reads artifacts
gcloud storage buckets add-iam-policy-binding gs://artifacts \
    --member=serviceAccount:deploy-reader@project.iam.gserviceaccount.com \
    --role=roles/storage.objectViewer
```

## Troubleshooting

### 403 Forbidden when uploading
- Check SA has `objectCreator` role on bucket
- Verify correct bucket name
- Confirm credentials are set (`GOOGLE_APPLICATION_CREDENTIALS`)

### 403 Forbidden when reading
- `objectCreator` does NOT grant read access
- Need `objectViewer` or `objectUser` role

### Cannot see files in Console
- Grant your user account `objectViewer` role
- SA with `objectCreator` cannot read files

### Workload Identity not working in GKE
- Check cluster has Workload Identity enabled
- Verify Kubernetes SA annotation
- Confirm IAM binding exists

## Related Topics

- [[Service Account Tutorial/README|GCP Service Accounts and Storage IAM Roles Tutorial]] - Comprehensive hands-on tutorial
- [[GKE Overview]] - Using Service Accounts in Kubernetes
- [[GKE Workload Identity]] - Secure SA authentication in GKE

## Tags

#gcp #iam #service-account #cloud-storage #quick-reference #cheatsheet
