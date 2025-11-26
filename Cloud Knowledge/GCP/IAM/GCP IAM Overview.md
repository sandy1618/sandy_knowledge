# GCP IAM Overview

## Overview

Google Cloud Platform Identity and Access Management (IAM) is a unified system for managing access control across all GCP services. IAM lets you grant granular access to specific GCP resources and helps prevent unwanted access to other resources. This section provides comprehensive guides to understanding and implementing IAM in your GCP projects.

## What is IAM?

IAM is built on three core concepts:

1. **Who** - Identity (User, Service Account, Group)
2. **Can do what** - Role (collection of permissions)
3. **On which resource** - Resource (project, bucket, VM, etc.)

These combine into a **Policy Binding**: "Identity X has Role Y on Resource Z"

## Key IAM Concepts

### Identities

**Google Account (User)**
- Individual person's account
- Format: `user@example.com`
- For human access

**Service Account**
- Non-human identity for applications/services
- Format: `service-name@project-id.iam.gserviceaccount.com`
- For programmatic access
- See: [[Service Account Tutorial/README|Service Accounts and Storage Roles Tutorial]]

**Google Group**
- Collection of users
- Manage permissions for multiple users at once
- Format: `group@example.com`

**Google Workspace Domain**
- All users in an organization
- Format: `example.com`

### Roles

IAM roles are collections of permissions. There are three types:

**Basic Roles (Legacy, avoid in production)**
- Owner (`roles/owner`) - Full access
- Editor (`roles/editor`) - Read/write
- Viewer (`roles/viewer`) - Read-only
- Too broad, not recommended

**Predefined Roles (Recommended)**
- Created and maintained by Google
- Follow least privilege principle
- Example: `roles/storage.objectCreator`
- See: [[GCP IAM Quick Reference]] for common roles

**Custom Roles**
- Create your own combination of permissions
- For very specific use cases
- More maintenance overhead

### Resources

Resources are organized hierarchically:

```
Organization
└── Folder
    └── Project
        └── Resource (Bucket, VM, etc.)
```

Permissions granted at a higher level are inherited by child resources.

## IAM for Cloud Storage

Cloud Storage is one of the most common use cases for IAM configuration. See these detailed guides:

- [[Service Account Tutorial/README|Service Accounts and Storage IAM Roles Tutorial]] - Comprehensive hands-on guide
- [[GCP IAM Quick Reference]] - Common commands and patterns

### Common Storage Roles

| Role | Typical Use Case |
|------|-----------------|
| `storage.objectViewer` | Read logs, download artifacts |
| `storage.objectCreator` | Upload logs, save recordings |
| `storage.objectUser` | Application with read/write needs |
| `storage.objectAdmin` | Manage bucket contents |
| `storage.admin` | Full bucket administration |

## IAM Best Practices

### 1. Principle of Least Privilege
Grant the minimum permissions needed to perform a task.

```bash
# ✓ GOOD: Specific role
--role=roles/storage.objectCreator

# ✗ BAD: Overly broad
--role=roles/owner
```

### 2. Use Resource-Level Bindings
Grant access at the most specific resource level possible.

```bash
# ✓ GOOD: Bucket-level
gcloud storage buckets add-iam-policy-binding gs://specific-bucket

# ✗ BAD: Project-level (affects all buckets)
gcloud projects add-iam-policy-binding project-id
```

### 3. Service Accounts for Applications
Never use user credentials for applications.

```bash
# ✓ GOOD: Dedicated service account
recording-agent@project.iam.gserviceaccount.com

# ✗ BAD: Personal account
john.doe@company.com
```

### 4. Prefer Workload Identity in GKE
Use Workload Identity instead of Service Account keys when running in Kubernetes.

See: [[GKE Workload Identity]]

### 5. Audit and Monitor
Enable audit logging to track who did what.

```bash
# Enable Data Access audit logs
gcloud projects get-iam-policy PROJECT_ID \
    --format=json > policy.json

# Edit policy.json to add audit config
gcloud projects set-iam-policy PROJECT_ID policy.json
```

### 6. Regular Access Reviews
Periodically review and remove unnecessary access.

```bash
# List all IAM bindings
gcloud projects get-iam-policy PROJECT_ID

# Review service accounts
gcloud iam service-accounts list
```

### 7. Use Groups for Users
Manage permissions for collections of users via groups, not individual accounts.

## Common IAM Patterns

### Pattern: Separation of Duties

```bash
# Development team can deploy (read artifacts)
gcloud storage buckets add-iam-policy-binding gs://artifacts \
    --member=group:developers@company.com \
    --role=roles/storage.objectViewer

# CI/CD can publish (write artifacts)
gcloud storage buckets add-iam-policy-binding gs://artifacts \
    --member=serviceAccount:ci@project.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator
```

### Pattern: Environment Isolation

```bash
# Prod SA only accesses prod resources
gcloud storage buckets add-iam-policy-binding gs://prod-data \
    --member=serviceAccount:prod-app@project.iam.gserviceaccount.com \
    --role=roles/storage.objectUser

# Dev SA only accesses dev resources
gcloud storage buckets add-iam-policy-binding gs://dev-data \
    --member=serviceAccount:dev-app@project.iam.gserviceaccount.com \
    --role=roles/storage.objectUser
```

### Pattern: Read-Write Separation

```bash
# Writer can only create
gcloud storage buckets add-iam-policy-binding gs://immutable-logs \
    --member=serviceAccount:log-writer@project.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator

# Reader can only read
gcloud storage buckets add-iam-policy-binding gs://immutable-logs \
    --member=serviceAccount:log-analyzer@project.iam.gserviceaccount.com \
    --role=roles/storage.objectViewer
```

## IAM in Different GCP Services

### Compute Engine
```bash
# Grant SA permission to create VMs
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member=serviceAccount:sa@project.iam.gserviceaccount.com \
    --role=roles/compute.instanceAdmin.v1
```

### Cloud Storage
```bash
# Grant SA permission to upload objects
gcloud storage buckets add-iam-policy-binding gs://bucket \
    --member=serviceAccount:sa@project.iam.gserviceaccount.com \
    --role=roles/storage.objectCreator
```

### BigQuery
```bash
# Grant SA permission to read datasets
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member=serviceAccount:sa@project.iam.gserviceaccount.com \
    --role=roles/bigquery.dataViewer
```

### Pub/Sub
```bash
# Grant SA permission to publish messages
gcloud pubsub topics add-iam-policy-binding TOPIC_NAME \
    --member=serviceAccount:sa@project.iam.gserviceaccount.com \
    --role=roles/pubsub.publisher
```

## IAM Policy Structure

An IAM policy is a JSON document:

```json
{
  "bindings": [
    {
      "role": "roles/storage.objectCreator",
      "members": [
        "serviceAccount:uploader@project.iam.gserviceaccount.com"
      ]
    },
    {
      "role": "roles/storage.objectViewer",
      "members": [
        "serviceAccount:reader@project.iam.gserviceaccount.com",
        "user:admin@example.com"
      ]
    }
  ],
  "etag": "BwXYZ123456=",
  "version": 3
}
```

### Conditional IAM Policies

Grant access based on conditions:

```bash
# Only allow access during business hours
gcloud storage buckets add-iam-policy-binding gs://bucket \
    --member=serviceAccount:sa@project.iam.gserviceaccount.com \
    --role=roles/storage.objectViewer \
    --condition='expression=request.time.getHours("America/New_York") >= 9 &&
                 request.time.getHours("America/New_York") <= 17,
                 title=business-hours'
```

## Troubleshooting IAM Issues

### Permission Denied (403)

1. **Check identity has the required role**
```bash
gcloud storage buckets get-iam-policy gs://bucket \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:SA_EMAIL"
```

2. **Check the role includes the required permission**
```bash
gcloud iam roles describe ROLE_NAME
```

3. **Verify credentials are being used correctly**
```bash
# Check which account is authenticated
gcloud auth list

# Check service account email
python -c "from google.cloud import storage; print(storage.Client().get_service_account_email())"
```

### Common Errors

| Error | Likely Cause | Solution |
|-------|--------------|----------|
| 403 Forbidden | Missing IAM permission | Add required role binding |
| 404 Not Found | Resource doesn't exist or no read access | Verify resource exists and check permissions |
| 401 Unauthorized | Not authenticated | Set credentials (GOOGLE_APPLICATION_CREDENTIALS) |
| "Default credentials not found" | No credentials configured | Set up Application Default Credentials |

## IAM Security Considerations

### Service Account Key Management

**Risks of Service Account Keys:**
- Long-lived credentials that can be leaked
- Must be rotated manually
- Can be accidentally committed to version control

**Alternatives to Keys:**
- Workload Identity (GKE) - [[GKE Workload Identity]]
- Application Default Credentials (local dev)
- Compute Engine default SA (GCE instances)
- Cloud Run/Functions default SA

**If You Must Use Keys:**
```bash
# Create key with notification for rotation
gcloud iam service-accounts keys create key.json \
    --iam-account=sa@project.iam.gserviceaccount.com

# Set 90-day reminder to rotate
# Store key securely (never commit to git!)
# Restrict file permissions
chmod 600 key.json
```

### Defense in Depth

Layer multiple security controls:

1. **IAM** - Who can access
2. **VPC Service Controls** - Network-level protection
3. **Bucket policies** - Additional constraints
4. **Encryption** - Data protection at rest/transit
5. **Audit logging** - Detection and monitoring

## Tools and Utilities

### IAM Policy Troubleshooter
```bash
# Test what permissions a principal has
gcloud projects get-iam-policy PROJECT_ID \
    --flatten="bindings[].members" \
    --format="table(bindings.role)" \
    --filter="bindings.members:serviceAccount:SA_EMAIL"
```

### IAM Recommender
Google's AI-powered recommendations for removing over-privileged access.

```bash
# List recommendations
gcloud recommender recommendations list \
    --project=PROJECT_ID \
    --recommender=google.iam.policy.Recommender \
    --location=global
```

### Policy Analyzer
Analyze IAM policies across your organization.

```bash
# Analyze who has access to a resource
gcloud asset analyze-iam-policy \
    --organization=ORG_ID \
    --full-resource-name="//storage.googleapis.com/bucket-name"
```

## Learning Path

1. **Start here**: [[GCP IAM Quick Reference]] - Essential commands
2. **Hands-on practice**: [[Service Account Tutorial/README|Service Accounts and Storage Roles Tutorial]]
3. **Production deployment**: [[GKE Workload Identity]]
4. **Advanced topics**: Conditional policies, Organization policies

## Related Topics

- [[Service Account Tutorial/README|GCP Service Accounts and Storage IAM Roles Tutorial]] - Comprehensive hands-on guide
- [[GCP IAM Quick Reference]] - Command cheat sheet
- [[GKE Overview]] - IAM in Kubernetes context
- [[GKE Workload Identity]] - Secure authentication in GKE
- [[Kubernetes ServiceAccounts]] - Kubernetes vs GCP service accounts

## Further Learning

### Official Documentation
- [IAM Overview](https://cloud.google.com/iam/docs/overview) - Google Cloud IAM documentation
- [Understanding Roles](https://cloud.google.com/iam/docs/understanding-roles) - Complete role reference
- [IAM Best Practices](https://cloud.google.com/iam/docs/best-practices-for-securing-service-accounts) - Security recommendations

### Interactive Learning
- [IAM Simulator](https://cloud.google.com/iam/docs/simulating-access) - Test permissions before applying
- [Qwiklabs IAM Labs](https://www.qwiklabs.com/catalog?keywords=iam) - Hands-on practice

## Tags

#gcp #iam #security #access-control #service-account #overview #guide

---

**Quick Links:**
- [[GCP IAM Quick Reference]] - Common commands
- [[Service Account Tutorial/README|Service Accounts Tutorial]] - Step-by-step guide
- [[GKE Workload Identity]] - Production authentication
