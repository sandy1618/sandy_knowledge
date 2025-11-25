# GKE Hands-On Tutorial

A complete, reproducible tutorial for deploying applications on Google Kubernetes Engine (GKE) with external load balancing using the Gateway API.

## Quick Start

```bash
# 1. Set your project ID
export PROJECT_ID=your-project-id

# 2. Create GKE Autopilot cluster
./scripts/01-create-cluster.sh

# 3. Enable Gateway API
./scripts/02-enable-gateway-api.sh

# 4. Deploy the application
./scripts/03-deploy.sh

# 5. Verify deployment
./scripts/04-verify.sh

# 6. Get external IP and test
./scripts/05-get-external-ip.sh

# Clean up when done
./scripts/99-cleanup.sh
```

## What You'll Build

This tutorial creates a production-ready architecture with:

- **GKE Autopilot Cluster**: Fully managed Kubernetes
- **Nginx Application**: Simple web server (2-10 auto-scaled Pods)
- **Gateway API**: External HTTP(S) Load Balancer
- **Horizontal Pod Autoscaler**: CPU-based auto-scaling
- **Health Checks**: Liveness and readiness probes
- **Resource Management**: Requests and limits

**Traffic Flow**: Internet → Load Balancer → Gateway → Service → Pods

## Prerequisites

### Required Tools

```bash
# Google Cloud SDK
gcloud version

# kubectl
kubectl version --client

# Verify authentication
gcloud auth list
```

### Required Permissions

- `roles/container.admin` - Create and manage GKE clusters
- `roles/compute.admin` - Create load balancers
- `roles/iam.serviceAccountUser` - Use service accounts

### Required APIs

The script will enable these automatically:
- Kubernetes Engine API (`container.googleapis.com`)
- Compute Engine API (`compute.googleapis.com`)

## Project Structure

```
GKE Hands-On Tutorial/
├── README.md                    # This file
├── k8s/                         # Kubernetes manifests
│   ├── namespace.yaml          # demo-app namespace
│   ├── service-account.yaml    # Service account
│   ├── deployment.yaml         # Nginx deployment
│   ├── service.yaml            # ClusterIP service
│   ├── gateway.yaml            # External load balancer
│   ├── httproute.yaml          # Routing rules
│   ├── hpa.yaml                # Auto-scaling config
│   └── kustomization.yaml      # Kustomize config
├── scripts/                     # Automation scripts
│   ├── 01-create-cluster.sh    # Create GKE cluster
│   ├── 02-enable-gateway-api.sh # Enable Gateway API
│   ├── 03-deploy.sh            # Deploy application
│   ├── 04-verify.sh            # Verify deployment
│   ├── 05-get-external-ip.sh   # Get external IP
│   └── 99-cleanup.sh           # Delete all resources
└── docs/                        # Documentation
    ├── architecture.md          # System architecture
    └── cost-estimation.md       # Cost breakdown
```

## Step-by-Step Guide

### Step 1: Create GKE Cluster

**Script**: [01-create-cluster.sh](./scripts/01-create-cluster.sh)

```bash
export PROJECT_ID=your-project-id
./scripts/01-create-cluster.sh
```

This creates:
- GKE Autopilot cluster named `demo-cluster`
- Region: `us-central1`
- Private nodes with public endpoint
- Enables required APIs

**Duration**: 5-10 minutes

**What is GKE Autopilot?**
See [[GKE Overview]] for details on Autopilot vs. Standard GKE.

### Step 2: Enable Gateway API

**Script**: [02-enable-gateway-api.sh](./scripts/02-enable-gateway-api.sh)

```bash
./scripts/02-enable-gateway-api.sh
```

This enables:
- Gateway API on the cluster
- GatewayClass: `gke-l7-global-external-managed`
- Custom Resource Definitions (CRDs)

**Duration**: 1-2 minutes

**What is Gateway API?**
See [[GKE Gateway API]] for concepts and configuration options.

### Step 3: Deploy Application

**Script**: [03-deploy.sh](./scripts/03-deploy.sh)

```bash
./scripts/03-deploy.sh
```

This deploys all resources from the [k8s/](./k8s/) directory:

1. **Namespace** ([namespace.yaml](./k8s/namespace.yaml))
   - Logical isolation: `demo-app`

2. **Service Account** ([service-account.yaml](./k8s/service-account.yaml))
   - Pod identity: `demo-app`

3. **Deployment** ([deployment.yaml](./k8s/deployment.yaml))
   - Image: nginx:1.25-alpine
   - Replicas: 2 (initial)
   - Resources: 100m CPU, 128Mi memory
   - Health checks: Liveness + Readiness

4. **Service** ([service.yaml](./k8s/service.yaml))
   - Type: ClusterIP (internal)
   - Port: 80

5. **Gateway** ([gateway.yaml](./k8s/gateway.yaml))
   - Creates Google Cloud Load Balancer
   - Provisions external IP address
   - Global load balancing

6. **HTTPRoute** ([httproute.yaml](./k8s/httproute.yaml))
   - Routes: `/` → `demo-app` service
   - Weight: 100%

7. **HorizontalPodAutoscaler** ([hpa.yaml](./k8s/hpa.yaml))
   - Min: 2 Pods
   - Max: 10 Pods
   - Target: 70% CPU

**Duration**: 5-10 minutes (Gateway provisioning)

**Kustomize**: Uses [kustomization.yaml](./k8s/kustomization.yaml) to deploy all resources together.

### Step 4: Verify Deployment

**Script**: [04-verify.sh](./scripts/04-verify.sh)

```bash
./scripts/04-verify.sh
```

This checks:
- Namespace creation
- Pod status and logs
- Service endpoints
- Gateway status
- HTTPRoute configuration
- HPA metrics
- Google Cloud Load Balancer

**Expected Output**:
```
Namespace: demo-app (Active)
Pods: 2/2 Running
Service: demo-app (endpoints: 2)
Gateway: demo-gateway (IP: pending/assigned)
HPA: 2 Pods (70% CPU target)
```

### Step 5: Get External IP

**Script**: [05-get-external-ip.sh](./scripts/05-get-external-ip.sh)

```bash
./scripts/05-get-external-ip.sh
```

This retrieves:
- Gateway external IP address
- Tests connectivity
- Displays access URL

**Expected Output**:
```
External IP: 34.120.xx.xx
URL: http://34.120.xx.xx

Testing connectivity...
SUCCESS! Gateway is responding.
```

**Access your application**:
```bash
curl http://34.120.xx.xx
```

### Step 6: Explore and Experiment

#### Watch Auto-Scaling

```bash
# Watch HPA in action
kubectl get hpa -n demo-app -w

# Generate load (requires 'hey' tool)
hey -z 60s -c 50 http://34.120.xx.xx

# Watch Pods scale up
kubectl get pods -n demo-app -w
```

#### Check Pod Logs

```bash
# View logs from all Pods
kubectl logs -l app=demo-app -n demo-app --tail=20

# Follow logs in real-time
kubectl logs -l app=demo-app -n demo-app -f
```

#### Inspect Gateway

```bash
# Gateway status
kubectl describe gateway demo-gateway -n demo-app

# HTTPRoute details
kubectl describe httproute demo-app-route -n demo-app

# Google Cloud Load Balancer
gcloud compute forwarding-rules list --filter="description~demo-gateway"
```

#### Port Forward (Bypass Load Balancer)

```bash
# Direct access to a Pod
kubectl port-forward -n demo-app deployment/demo-app 8080:80

# Access at http://localhost:8080
```

### Step 7: Clean Up

**Script**: [99-cleanup.sh](./scripts/99-cleanup.sh)

```bash
./scripts/99-cleanup.sh
```

This deletes:
1. All Kubernetes resources in `demo-app` namespace
2. Gateway and Load Balancer
3. GKE cluster `demo-cluster`

**Duration**: 2-5 minutes

**Important**: Always clean up to avoid charges!

## Understanding the Architecture

### Component Interaction

```
User Request
    ↓
[Gateway] (External IP)
    ↓
[HTTPRoute] (Routing rules)
    ↓
[Service] (Load balancer)
    ↓
[Pods] (Application)
```

**Detailed architecture**: See [docs/architecture.md](./docs/architecture.md)

### Gateway API Benefits

Compared to Ingress:
- **More expressive**: Advanced routing (headers, query params)
- **Better multi-tenancy**: Namespace-scoped routes
- **Traffic splitting**: Canary deployments
- **Automatic SSL**: Managed certificates
- **Future-proof**: Kubernetes SIG standard

Learn more: [[GKE Gateway API]]

### Auto-Scaling Behavior

The HPA monitors CPU usage and scales Pods:

```
CPU < 70%: Scale down (wait 5 minutes)
CPU > 70%: Scale up (wait 1 minute)
```

**Example Scaling Event**:
1. Traffic increases → CPU > 70%
2. HPA scales: 2 → 3 Pods (1 minute)
3. Still high → 3 → 5 Pods (1 minute)
4. Traffic decreases → CPU < 70%
5. HPA scales: 5 → 4 Pods (5 minutes)

## Customization Guide

### Change Application Image

Edit [k8s/deployment.yaml](./k8s/deployment.yaml):

```yaml
containers:
- name: app
  image: your-image:tag  # Change this
  ports:
  - containerPort: 8080  # Match your app port
```

Update [k8s/service.yaml](./k8s/service.yaml):

```yaml
ports:
- port: 80
  targetPort: 8080  # Match container port
```

### Adjust Resource Limits

Edit [k8s/deployment.yaml](./k8s/deployment.yaml):

```yaml
resources:
  requests:
    cpu: 200m        # Increase for more CPU
    memory: 256Mi    # Increase for more memory
  limits:
    cpu: 500m
    memory: 512Mi
```

### Modify Scaling Behavior

Edit [k8s/hpa.yaml](./k8s/hpa.yaml):

```yaml
minReplicas: 1      # Single Pod for dev
maxReplicas: 20     # Higher ceiling
targetCPU: 80%      # Less aggressive scaling
```

### Add HTTPS Support

Edit [k8s/gateway.yaml](./k8s/gateway.yaml):

```yaml
listeners:
- name: https
  protocol: HTTPS
  port: 443
  tls:
    mode: Terminate
    certificateRefs:
    - name: demo-app-cert
      kind: Secret
```

Create certificate Secret:
```bash
kubectl create secret tls demo-app-cert \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n demo-app
```

Or use Google-managed certificates (recommended).

### Add Path-Based Routing

Edit [k8s/httproute.yaml](./k8s/httproute.yaml):

```yaml
rules:
- matches:
  - path:
      type: PathPrefix
      value: /api
  backendRefs:
  - name: api-service
    port: 80

- matches:
  - path:
      type: PathPrefix
      value: /web
  backendRefs:
  - name: web-service
    port: 80
```

### Change Region

Edit all scripts, replace:
```bash
REGION="us-central1"
```

With your preferred region:
```bash
REGION="us-west1"  # or europe-west1, asia-northeast1, etc.
```

## Troubleshooting

### Gateway Not Getting External IP

**Symptom**: Gateway status shows no IP address after 10+ minutes

**Check**:
```bash
kubectl describe gateway demo-gateway -n demo-app
```

**Common Causes**:
1. Gateway API not enabled → Run `./scripts/02-enable-gateway-api.sh`
2. Quota exhausted → Check Cloud Console quotas
3. API not enabled → Enable Load Balancing API

**Fix**:
```bash
# Delete and recreate Gateway
kubectl delete gateway demo-gateway -n demo-app
kubectl apply -f k8s/gateway.yaml
```

### Pods Not Starting

**Symptom**: Pods in `Pending` or `CrashLoopBackOff`

**Check**:
```bash
kubectl get pods -n demo-app
kubectl describe pod <pod-name> -n demo-app
kubectl logs <pod-name> -n demo-app
```

**Common Causes**:
1. Image pull error → Check image name
2. Resource quota → Increase requests
3. Health probe failing → Check probe configuration

**Fix**:
```bash
# View events
kubectl get events -n demo-app --sort-by='.lastTimestamp'

# Delete and recreate
kubectl rollout restart deployment/demo-app -n demo-app
```

### 502 Bad Gateway Error

**Symptom**: Gateway returns 502 when accessing external IP

**Check**:
```bash
# Check Pod health
kubectl get pods -n demo-app

# Check Service endpoints
kubectl describe service demo-app -n demo-app

# Check HTTPRoute
kubectl describe httproute demo-app-route -n demo-app
```

**Common Causes**:
1. No healthy Pods → Check readiness probe
2. Service selector mismatch → Check labels
3. Wrong port mapping → Check service/container ports

**Fix**:
```bash
# Test service directly (port-forward)
kubectl port-forward -n demo-app service/demo-app 8080:80

# If works, issue is with Gateway/HTTPRoute
```

### HPA Not Scaling

**Symptom**: HPA shows `<unknown>` for CPU metrics

**Check**:
```bash
kubectl get hpa -n demo-app
kubectl describe hpa demo-app-hpa -n demo-app
kubectl top pods -n demo-app
```

**Common Causes**:
1. Metrics server not ready → Wait a few minutes
2. No resource requests → Check deployment.yaml
3. Metrics not available yet → Wait 1-2 minutes

**Fix**:
```bash
# Verify metrics-server (Autopilot should have this)
kubectl get deployment metrics-server -n kube-system

# Generate load to trigger scaling
hey -z 60s -c 50 http://<gateway-ip>
```

### Permission Denied

**Symptom**: `gcloud` or `kubectl` commands fail with permission errors

**Check**:
```bash
gcloud auth list
gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:user:$(gcloud config get-value account)"
```

**Fix**:
```bash
# Re-authenticate
gcloud auth login

# Set project
gcloud config set project $PROJECT_ID

# Verify permissions with project owner/admin
```

## Cost Information

**Estimated Monthly Cost**: $25-50

Breakdown:
- GKE Autopilot: $4-7/month (2-4 Pods)
- Load Balancer: $18-30/month
- Network egress: $1-5/month

**Development**: ~$25/month (minimal usage)
**Testing**: ~$35/month (moderate usage)

**Detailed cost analysis**: See [docs/cost-estimation.md](./docs/cost-estimation.md)

**Save money**:
- Always run cleanup when done: `./scripts/99-cleanup.sh`
- Use free trial credits ($300 for new accounts)
- Scale down during off-hours

## Learning Resources

### Conceptual Knowledge

In this vault:
- [[GKE Overview]] - GKE fundamentals and cluster types
- [[GKE Gateway API]] - Gateway API concepts and configuration
- [[Kubernetes Services]] - Service types and networking
- [[Kubernetes Deployments]] - Application management
- [[Kubernetes HPA]] - Horizontal Pod Autoscaler

### Official Documentation

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Gateway API Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Hands-On Practice

- [Google Cloud Skills Boost](https://www.cloudskillsboost.google/) - Free labs
- [Kubernetes by Example](https://kubernetesbyexample.com/)
- [GKE Best Practices](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke)

## Next Steps

### Extend This Tutorial

1. **Add Persistence**
   - Add Persistent Volume for data
   - Use Cloud SQL for database

2. **Implement CI/CD**
   - Cloud Build for image builds
   - GitHub Actions for deployment

3. **Enable Monitoring**
   - Cloud Monitoring dashboards
   - Cloud Logging integration
   - Set up alerts

4. **Improve Security**
   - Network policies
   - Pod security policies
   - Workload Identity for GCP APIs

5. **Multi-Environment Setup**
   - dev, staging, prod namespaces
   - Separate clusters per environment

### Advanced Topics

- **Multi-Region Deployment**: Global load balancing
- **Service Mesh**: Istio or Anthos Service Mesh
- **GitOps**: ArgoCD or Flux
- **Serverless**: Cloud Run on GKE
- **Batch Workloads**: Kubernetes Jobs and CronJobs

## Contributing

Found an issue or improvement? This is a personal knowledge vault, but you can suggest improvements by:

1. Testing the tutorial
2. Documenting issues
3. Proposing enhancements

## Related Topics

- [[GKE Overview]] - GKE cluster types and features
- [[GKE Gateway API]] - Advanced Gateway API configuration
- [[Kubernetes Networking]] - Service mesh and network policies
- [[Cloud Load Balancing]] - GCP load balancer types
- [[GKE Autopilot]] - Autopilot vs. Standard comparison

## Further Reading

- [GKE Release Notes](https://cloud.google.com/kubernetes-engine/docs/release-notes)
- [Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

## Tags

#gke #kubernetes #tutorial #hands-on #gateway-api #load-balancing #autopilot #cloud-native

---

**Last Updated**: 2025-11
**Tested With**: GKE 1.28+, Gateway API v1
**Vault Location**: `/Users/gam0153/Documents/LocalRepo/sandy_knowledge/Cloud Knowledge/GCP/GKE/GKE Hands-On Tutorial/`
