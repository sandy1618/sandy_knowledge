# GKE Hands-On Tutorial

## Overview

This comprehensive hands-on tutorial guides you through deploying a complete production-ready application on Google Kubernetes Engine (GKE) using the Gateway API. You'll learn how to create a GKE cluster, configure the Gateway API, deploy a scalable application with health checks, and expose it to the internet. By the end of this tutorial, you'll have practical experience with GKE's core features and be ready to deploy your own applications.

## Prerequisites

- [[GKE Overview]] - Understanding of GKE architecture and cluster types
- [[GKE Gateway API]] - Familiarity with Gateway API concepts
- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- `kubectl` CLI installed (version 1.28 or later)
- Basic knowledge of Kubernetes concepts (Pods, Services, Deployments)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet Traffic                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                  ┌─────────────┐
                  │   Gateway   │  (External Load Balancer)
                  │  (GatewayClass: gke-l7-global-external-managed)
                  └──────┬──────┘
                         │
                         ▼
                  ┌─────────────┐
                  │  HTTPRoute  │  (Traffic Routing Rules)
                  └──────┬──────┘
                         │
                         ▼
          ┌──────────────┴──────────────┐
          │                             │
          ▼                             ▼
   ┌─────────────┐              ┌─────────────┐
   │   Service   │              │     HPA     │
   │  (ClusterIP)│              │ (Autoscaler)│
   └──────┬──────┘              └──────┬──────┘
          │                             │
          └──────────────┬──────────────┘
                         │
                         ▼
                  ┌─────────────┐
                  │ Deployment  │
                  │  (3 Pods)   │
                  └─────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
      ┌─────┐        ┌─────┐        ┌─────┐
      │ Pod │        │ Pod │        │ Pod │
      └─────┘        └─────┘        └─────┘
```

## Cost Estimation

**Autopilot Cluster (Recommended for Beginners):**
- Cluster management: Free
- Pod resources: ~$0.0445/vCPU/hour + ~$0.0049/GB RAM/hour
- Load Balancer: ~$18/month + bandwidth
- **Estimated cost for this tutorial:** $5-10 for a few hours

**Standard Cluster:**
- Cluster management: $0.10/hour (~$73/month)
- Node pool (e2-standard-2): ~$50/month per node
- Load Balancer: ~$18/month + bandwidth
- **Estimated cost for this tutorial:** $10-20 for a few hours

**Cost-saving tips:**
- Delete resources immediately after completion
- Use Autopilot for development/testing
- Enable cluster autoscaling
- Choose appropriate machine types

## Step 1: Set Up Your Environment

### 1.1 Configure gcloud CLI

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com

# Set default region and zone
export REGION="us-central1"
export ZONE="us-central1-a"
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
```

### 1.2 Verify Installation

```bash
# Check gcloud version
gcloud version

# Check kubectl version
kubectl version --client

# Expected output:
# Client Version: v1.28.x or later
```

## Step 2: Create a GKE Cluster

You have two options: **Autopilot** (recommended for beginners) or **Standard** (more control).

### Option A: Create an Autopilot Cluster (Recommended)

```bash
# Create Autopilot cluster with Gateway API enabled
gcloud container clusters create-auto demo-cluster \
    --region=$REGION \
    --gateway-api=standard \
    --release-channel=regular

# This takes 5-10 minutes
```

**Why Autopilot?**
- No node management required
- Automatic scaling and updates
- Pay only for running Pods
- Built-in security best practices
- Perfect for learning and development

### Option B: Create a Standard Cluster (Advanced)

```bash
# Create Standard cluster
gcloud container clusters create demo-cluster \
    --zone=$ZONE \
    --machine-type=e2-standard-2 \
    --num-nodes=3 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-autorepair \
    --enable-autoupgrade \
    --release-channel=regular \
    --gateway-api=standard \
    --enable-ip-alias \
    --network=default \
    --subnetwork=default

# This takes 3-5 minutes
```

**Standard cluster benefits:**
- Full control over node configuration
- Choice of machine types
- Custom node pools with different specs
- Spot/Preemptible VMs support

### 2.1 Get Cluster Credentials

```bash
# For Autopilot cluster
gcloud container clusters get-credentials demo-cluster --region=$REGION

# For Standard cluster
gcloud container clusters get-credentials demo-cluster --zone=$ZONE

# Verify connection
kubectl cluster-info
kubectl get nodes

# Expected output:
# NAME                                       STATUS   ROLES    AGE   VERSION
# gke-demo-cluster-default-pool-xxxxx-yyy   Ready    <none>   2m    v1.28.x
```

## Step 3: Enable Gateway API (If Not Already Enabled)

```bash
# Check if Gateway API is enabled
kubectl get gatewayclass

# Expected output should show:
# NAME                                    CONTROLLER                  ACCEPTED
# gke-l7-global-external-managed         networking.gke.io/gateway   True
# gke-l7-regional-external-managed       networking.gke.io/gateway   True
# gke-l7-rilb                            networking.gke.io/gateway   True

# If not enabled, update the cluster
gcloud container clusters update demo-cluster \
    --gateway-api=standard \
    --region=$REGION  # Use --zone=$ZONE for Standard clusters
```

## Step 4: Prepare Application Manifests

Create a directory for your manifests:

```bash
mkdir -p ~/gke-demo-app
cd ~/gke-demo-app
```

### 4.1 Create Namespace Manifest

Create `namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
  labels:
    name: demo-app
    environment: development
```

### 4.2 Create ServiceAccount Manifest

Create `serviceaccount.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-app-sa
  namespace: demo-app
  labels:
    app: demo-app
automountServiceAccountToken: true
```

### 4.3 Create Deployment Manifest

Create `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: demo-app
  labels:
    app: demo-app
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
        version: v1
    spec:
      serviceAccountName: demo-app-sa
      containers:
      - name: demo-app
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        env:
        - name: PORT
          value: "8080"
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 2
        startupProbe:
          httpGet:
            path: /
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 0
          periodSeconds: 2
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 30
      terminationGracePeriodSeconds: 30
```

**Key Features Explained:**
- **Health Probes**: Ensures pods are healthy before receiving traffic
  - `startupProbe`: Handles slow-starting containers (60 seconds max)
  - `livenessProbe`: Restarts unhealthy containers
  - `readinessProbe`: Removes unhealthy pods from service endpoints
- **Resource Limits**: Prevents resource exhaustion
- **Environment Variables**: Pod identity and configuration
- **ServiceAccount**: Enables workload identity and RBAC

### 4.4 Create Service Manifest

Create `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-app-service
  namespace: demo-app
  labels:
    app: demo-app
spec:
  type: ClusterIP
  selector:
    app: demo-app
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  sessionAffinity: None
```

### 4.5 Create Gateway Manifest

Create `gateway.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: demo-app-gateway
  namespace: demo-app
  labels:
    app: demo-app
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Same
```

**Gateway Configuration:**
- `gke-l7-global-external-managed`: Creates a global external load balancer
- Multi-region load balancing with automatic failover
- Integrated with Google Cloud Armor and Cloud CDN

### 4.6 Create HTTPRoute Manifest

Create `httproute.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: demo-app-route
  namespace: demo-app
  labels:
    app: demo-app
spec:
  parentRefs:
  - name: demo-app-gateway
    namespace: demo-app
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: demo-app-service
      port: 80
      weight: 100
```

**Routing Features:**
- Path-based routing (PathPrefix, Exact, RegularExpression)
- Header-based routing
- Query parameter matching
- Traffic splitting (blue-green, canary deployments)

### 4.7 Create HorizontalPodAutoscaler Manifest

Create `hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: demo-app-hpa
  namespace: demo-app
  labels:
    app: demo-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: demo-app
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
      - type: Pods
        value: 2
        periodSeconds: 60
      selectPolicy: Min
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 4
        periodSeconds: 30
      selectPolicy: Max
```

**HPA Configuration:**
- Scales based on CPU and memory utilization
- Gradual scale-down to prevent flapping
- Rapid scale-up for traffic spikes
- Stabilization windows for stable scaling

### 4.8 Create Kustomization File (Optional but Recommended)

Create `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: demo-app

resources:
  - namespace.yaml
  - serviceaccount.yaml
  - deployment.yaml
  - service.yaml
  - gateway.yaml
  - httproute.yaml
  - hpa.yaml

commonLabels:
  managed-by: kustomize
  project: demo-app

commonAnnotations:
  description: "Demo application for GKE Gateway API tutorial"
```

**Benefits of Kustomization:**
- Single command deployment
- Environment-specific configurations
- Consistent labeling and annotations
- Easy version control

## Step 5: Deploy the Application

### 5.1 Apply All Manifests

```bash
# Using kubectl
kubectl apply -f namespace.yaml
kubectl apply -f serviceaccount.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml
kubectl apply -f hpa.yaml

# OR using Kustomize (if you created kustomization.yaml)
kubectl apply -k .
```

### 5.2 Verify Deployment

```bash
# Check namespace
kubectl get namespace demo-app

# Check all resources in namespace
kubectl get all -n demo-app

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# pod/demo-app-xxxxxxxxx-xxxxx    1/1     Running   0          2m
# pod/demo-app-xxxxxxxxx-yyyyy    1/1     Running   0          2m
# pod/demo-app-xxxxxxxxx-zzzzz    1/1     Running   0          2m
#
# NAME                       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
# service/demo-app-service   ClusterIP   10.x.x.x       <none>        80/TCP    2m
#
# NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
# deployment.apps/demo-app   3/3     3            3           2m
#
# NAME                                  DESIRED   CURRENT   READY   AGE
# replicaset.apps/demo-app-xxxxxxxxx    3         3         3       2m

# Check Gateway (this takes 5-10 minutes to provision)
kubectl get gateway -n demo-app
kubectl describe gateway demo-app-gateway -n demo-app

# Check HTTPRoute
kubectl get httproute -n demo-app
kubectl describe httproute demo-app-route -n demo-app

# Check HPA
kubectl get hpa -n demo-app

# Watch Pod status in real-time
kubectl get pods -n demo-app -w
```

## Step 6: Get External IP and Test

### 6.1 Wait for Load Balancer Provisioning

The Gateway provisioning takes 5-10 minutes. Monitor progress:

```bash
# Watch Gateway status
kubectl get gateway demo-app-gateway -n demo-app -w

# Check for PROGRAMMED status
kubectl get gateway demo-app-gateway -n demo-app -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'

# Expected: True (once ready)
```

### 6.2 Get External IP

```bash
# Get the external IP address
kubectl get gateway demo-app-gateway -n demo-app -o jsonpath='{.status.addresses[0].value}'

# Save to variable
export GATEWAY_IP=$(kubectl get gateway demo-app-gateway -n demo-app -o jsonpath='{.status.addresses[0].value}')
echo "Gateway IP: $GATEWAY_IP"
```

### 6.3 Test the Application

```bash
# Test with curl
curl http://$GATEWAY_IP

# Expected output:
# Hello, world!
# Version: 1.0.0
# Hostname: demo-app-xxxxxxxxx-xxxxx

# Test multiple times to see load balancing
for i in {1..10}; do
  curl -s http://$GATEWAY_IP | grep Hostname
done

# You should see different pod hostnames
```

### 6.4 Test from Browser

```bash
# Print the URL
echo "Open in browser: http://$GATEWAY_IP"
```

Visit the URL in your browser. Refresh multiple times to see different pod hostnames.

## Step 7: Explore and Experiment

### 7.1 View Logs

```bash
# View logs from all pods
kubectl logs -n demo-app -l app=demo-app --tail=50

# Follow logs in real-time
kubectl logs -n demo-app -l app=demo-app -f

# View logs from specific pod
kubectl logs -n demo-app <pod-name>
```

### 7.2 Test Autoscaling

```bash
# Generate load to trigger HPA
# Open a new terminal and run:
while true; do curl -s http://$GATEWAY_IP > /dev/null; done

# Watch HPA scale up (in another terminal)
kubectl get hpa -n demo-app -w

# Expected output:
# NAME           REFERENCE             TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
# demo-app-hpa   Deployment/demo-app   45%/70%    3         10        3          5m
# demo-app-hpa   Deployment/demo-app   85%/70%    3         10        3          6m
# demo-app-hpa   Deployment/demo-app   85%/70%    3         10        5          6m

# Stop the load test (Ctrl+C) and watch scale down
```

### 7.3 Manual Scaling

```bash
# Scale deployment manually
kubectl scale deployment demo-app -n demo-app --replicas=5

# Watch pods being created
kubectl get pods -n demo-app -w

# Scale back down
kubectl scale deployment demo-app -n demo-app --replicas=3
```

### 7.4 Rolling Update

```bash
# Update to a new version
kubectl set image deployment/demo-app \
  demo-app=gcr.io/google-samples/hello-app:2.0 \
  -n demo-app

# Watch rolling update
kubectl rollout status deployment/demo-app -n demo-app

# Test the new version
curl http://$GATEWAY_IP
# Should show: Version: 2.0.0

# Rollback if needed
kubectl rollout undo deployment/demo-app -n demo-app
```

### 7.5 Inspect Gateway Details

```bash
# Get detailed Gateway information
kubectl describe gateway demo-app-gateway -n demo-app

# Get Gateway configuration in YAML
kubectl get gateway demo-app-gateway -n demo-app -o yaml

# Check Gateway events
kubectl get events -n demo-app --field-selector involvedObject.kind=Gateway
```

### 7.6 Test Health Probes

```bash
# Exec into a pod
kubectl exec -it -n demo-app <pod-name> -- /bin/sh

# Inside the pod, kill the process to test liveness probe
# The pod should restart automatically
kill 1

# Exit and watch pod restart
kubectl get pods -n demo-app -w
```

## Step 8: Monitor in Google Cloud Console

### 8.1 View GKE Cluster

1. Go to https://console.cloud.google.com/kubernetes/list
2. Click on `demo-cluster`
3. Explore:
   - Nodes tab
   - Storage tab
   - Observability tab
   - Security tab

### 8.2 View Load Balancer

1. Go to https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers
2. Find the load balancer created by Gateway API
3. Click to view:
   - Frontend configuration
   - Backend services
   - Health check status
   - Monitoring metrics

### 8.3 View Workloads

1. Go to https://console.cloud.google.com/kubernetes/workload
2. Select namespace: `demo-app`
3. Click on `demo-app` deployment
4. View:
   - Pod details and logs
   - YAML configuration
   - Events and monitoring

## Step 9: Advanced Configurations

### 9.1 Add Custom Domain (Optional)

Create `gateway-with-domain.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: demo-app-gateway
  namespace: demo-app
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "demo.example.com"  # Your domain
    allowedRoutes:
      namespaces:
        from: Same
```

Then update your DNS:
```bash
# Point your domain to the Gateway IP
# Create an A record: demo.example.com -> $GATEWAY_IP
```

### 9.2 Enable HTTPS (Optional)

First, create a Google-managed SSL certificate:

```bash
gcloud compute ssl-certificates create demo-app-cert \
    --domains=demo.example.com \
    --global
```

Then update Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: demo-app-gateway
  namespace: demo-app
  annotations:
    networking.gke.io/certmap: demo-app-cert
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "demo.example.com"
    allowedRoutes:
      namespaces:
        from: Same
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Same
```

### 9.3 Add Path-Based Routing

Create `advanced-httproute.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: demo-app-advanced-route
  namespace: demo-app
spec:
  parentRefs:
  - name: demo-app-gateway
  rules:
  # API traffic to v2
  - matches:
    - path:
        type: PathPrefix
        value: /api/v2
    backendRefs:
    - name: demo-app-v2-service
      port: 80
  # API traffic to v1
  - matches:
    - path:
        type: PathPrefix
        value: /api/v1
    backendRefs:
    - name: demo-app-v1-service
      port: 80
  # Default traffic
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: demo-app-service
      port: 80
```

### 9.4 Traffic Splitting (Canary Deployment)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: demo-app-canary-route
  namespace: demo-app
spec:
  parentRefs:
  - name: demo-app-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    # 90% traffic to stable version
    - name: demo-app-stable-service
      port: 80
      weight: 90
    # 10% traffic to canary version
    - name: demo-app-canary-service
      port: 80
      weight: 10
```

## Step 10: Clean Up

**Important**: Clean up resources to avoid ongoing charges!

### 10.1 Delete Application Resources

```bash
# Delete using Kustomize
kubectl delete -k .

# OR delete individual resources
kubectl delete namespace demo-app

# This deletes:
# - All pods, deployments, services
# - Gateway and HTTPRoute
# - HPA and ServiceAccount
```

### 10.2 Wait for Load Balancer Deletion

```bash
# Wait 5-10 minutes for GCP to clean up the load balancer
# Check in Cloud Console: https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers

# Verify Gateway is deleted
kubectl get gateway --all-namespaces
```

### 10.3 Delete GKE Cluster

```bash
# For Autopilot cluster
gcloud container clusters delete demo-cluster --region=$REGION

# For Standard cluster
gcloud container clusters delete demo-cluster --zone=$ZONE

# Confirm deletion when prompted
# This takes 2-3 minutes
```

### 10.4 Verify Cleanup

```bash
# Check clusters
gcloud container clusters list

# Check load balancers
gcloud compute forwarding-rules list
gcloud compute target-http-proxies list
gcloud compute url-maps list
gcloud compute backend-services list

# If any remain, delete manually
```

### 10.5 Final Cost Check

```bash
# View billing in Cloud Console
# https://console.cloud.google.com/billing
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Gateway stuck in "Not Ready" | Load balancer provisioning in progress | Wait 5-10 minutes. Check `kubectl describe gateway` for events |
| Pods in CrashLoopBackOff | Container failing startup probe | Check logs: `kubectl logs <pod-name> -n demo-app`. Increase startup probe timeout |
| Service has no endpoints | Label selector mismatch | Verify labels: `kubectl get pods --show-labels -n demo-app` |
| Gateway API not available | Not enabled on cluster | Run: `gcloud container clusters update demo-cluster --gateway-api=standard` |
| External IP not assigned | Gateway not fully provisioned | Wait longer, check Gateway conditions: `kubectl get gateway -o yaml` |
| 502/504 errors when accessing app | Backend pods unhealthy | Check: `kubectl get pods -n demo-app`, verify readiness probes |
| HPA not scaling | Metrics server issues or no load | Check metrics: `kubectl top pods -n demo-app`, verify HPA targets: `kubectl describe hpa -n demo-app` |
| "Insufficient CPU/memory" errors (Autopilot) | Pod resources too low | Increase resource requests in deployment.yaml |
| Cannot delete cluster | Resources still exist | Delete namespace first: `kubectl delete namespace demo-app`, wait for load balancer cleanup |
| Permission denied errors | Insufficient IAM permissions | Ensure you have `container.admin` or `editor` role on the project |
| Cluster creation fails | Quota exceeded | Check quotas in Cloud Console, request increase if needed |
| kubectl connection timeout | Credentials not configured | Run: `gcloud container clusters get-credentials demo-cluster` |

## Best Practices Applied in This Tutorial

- **Resource Requests/Limits**: Ensures predictable scheduling and prevents resource starvation
- **Health Probes**: Automatic recovery from failures and zero-downtime deployments
- **HPA**: Automatic scaling based on actual demand
- **ServiceAccount**: Enables workload identity and least-privilege access
- **Labels and Selectors**: Consistent organization and service discovery
- **Namespace Isolation**: Logical separation of resources
- **Gateway API**: Modern, extensible traffic management
- **Kustomize**: Declarative, version-controlled configuration
- **Graceful Termination**: 30-second grace period for clean shutdowns

## Real-World Use Cases

### Use Case 1: Microservices Architecture
Deploy multiple services behind a single Gateway with path-based routing. Each microservice gets its own Deployment, Service, and HTTPRoute pointing to different paths (`/api/users`, `/api/products`, `/api/orders`).

### Use Case 2: Blue-Green Deployment
Create two identical deployments (blue and green). Use HTTPRoute weight distribution to gradually shift traffic from blue to green. Zero downtime and instant rollback capability.

### Use Case 3: Multi-Region High Availability
Deploy identical applications in multiple GKE clusters across different regions. Use global load balancing to route traffic to the nearest healthy cluster. Automatic failover on regional outages.

### Use Case 4: Canary Release
Deploy new version alongside stable version. Route 5% of traffic to canary, monitor metrics. Gradually increase traffic split or rollback based on error rates and performance.

## Key Learnings

By completing this tutorial, you've learned:

1. **GKE Cluster Creation**: Autopilot vs Standard, when to use each
2. **Gateway API**: Modern Kubernetes ingress with advanced features
3. **Production-Ready Deployments**: Health probes, resource limits, HPA
4. **Traffic Management**: Load balancing, routing, and splitting
5. **Scaling**: Manual, automatic, and behavior configuration
6. **Monitoring**: Logs, metrics, and GCP Console integration
7. **Cost Management**: Understanding charges and cleanup procedures

## Related Topics

- [[GKE Overview]] - Understanding GKE architecture and concepts
- [[GKE Gateway API]] - Deep dive into Gateway API features
- [[Kubernetes Deployments]] - Deployment strategies and patterns
- [[Kubernetes Services]] - Service types and load balancing
- [[Kubernetes Autoscaling]] - HPA, VPA, and cluster autoscaling
- [[GCP Load Balancing]] - Google Cloud load balancer types
- [[Kubernetes Health Checks]] - Probe types and configuration
- [[Kustomize]] - Configuration management for Kubernetes

## Further Learning

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs) - Official GKE documentation
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/) - Gateway API specification and guides
- [Kubernetes Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices) - Google's recommended practices
- [GKE Gateway Controller](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api) - GKE-specific Gateway API implementation
- [Kubernetes Patterns](https://k8spatterns.io/) - Common Kubernetes design patterns
- [GCP Skills Boost](https://www.cloudskillsboost.google/) - Hands-on labs and courses

## Next Steps

1. **Add Monitoring**: Integrate with Google Cloud Monitoring and Logging
2. **Implement CI/CD**: Set up automated deployments with Cloud Build or GitHub Actions
3. **Security Hardening**: Add Network Policies, Pod Security Standards, Binary Authorization
4. **Service Mesh**: Explore Istio or Anthos Service Mesh for advanced traffic management
5. **Multi-Cluster**: Deploy across multiple clusters with Multi Cluster Ingress
6. **Workload Identity**: Configure GKE Workload Identity for secure GCP API access
7. **GitOps**: Implement GitOps with Config Sync or Flux

## Tags

#gke #kubernetes #gateway-api #gcp #hands-on #tutorial #deployment #autoscaling #load-balancing #cloud-native
