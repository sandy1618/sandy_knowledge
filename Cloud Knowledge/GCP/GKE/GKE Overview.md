# Google Kubernetes Engine (GKE) Overview

## Overview
Google Kubernetes Engine (GKE) is Google Cloud's managed Kubernetes service that provides a production-ready platform for deploying, managing, and scaling containerized applications. GKE automates the operational complexity of Kubernetes by managing the control plane, providing automatic upgrades, built-in security, and seamless integration with Google Cloud services.

## Prerequisites
- Basic understanding of [[Kubernetes Services|Kubernetes concepts]]
- Familiarity with containerization and Docker
- Google Cloud Platform account with billing enabled
- Understanding of cloud networking fundamentals

## Key Concepts

### GKE Cluster Architecture
A GKE cluster consists of two main components:
- **Control Plane**: Managed by Google, includes the Kubernetes API server, scheduler, and controller manager. This is fully automated and maintained by GKE, removing operational overhead from your team.
- **Node Pools**: Groups of worker nodes (Compute Engine VMs) that run your containerized applications. These are the machines where your pods actually execute.

### Nodes and Pods
**Nodes** are the worker machines (VM instances) in your cluster. Each node runs:
- Container runtime (containerd)
- kubelet (agent that manages pods)
- kube-proxy (network proxy)

**Pods** are the smallest deployable units in Kubernetes. A pod represents a single instance of your application and can contain one or more containers that share resources like network and storage.

### Autopilot vs Standard Mode

**Standard Mode**:
- You manage the node infrastructure
- Full control over node configuration, machine types, and scaling
- You're responsible for node upgrades and maintenance
- Pay for all provisioned nodes, regardless of utilization

**Autopilot Mode**:
- Google manages the entire infrastructure
- Automatically provisions and configures nodes based on workload requirements
- Automatic node upgrades and security patches
- Pay only for the resources your pods use (pod-level billing)
- Enforces best practices and security policies

### Namespaces
Namespaces provide virtual clusters within a physical cluster, enabling resource isolation and organization. Common uses:
- Separating development, staging, and production environments
- Multi-tenancy (different teams sharing a cluster)
- Resource quotas and access control boundaries

## How It Works

### Cluster Creation Flow
1. **Cluster Provisioning**: When you create a GKE cluster, Google provisions the control plane in their managed infrastructure
2. **Node Pool Setup**: GKE creates Compute Engine VMs based on your specifications (machine type, disk size, etc.)
3. **Networking Configuration**: Assigns IP ranges for pods and services, configures VPC integration
4. **Security Setup**: Configures Workload Identity, sets up service accounts, applies security policies
5. **Ready State**: Control plane becomes accessible via kubectl, and nodes join the cluster

### Pod Deployment Process
```
Developer → kubectl apply → API Server → Scheduler → Node
                                      ↓
                              Controller Manager
```

1. You submit a deployment manifest via kubectl
2. API server validates and stores it in etcd
3. Controller manager creates the desired number of replica pods
4. Scheduler assigns pods to nodes based on resource requirements
5. kubelet on selected nodes pulls container images and starts containers
6. kube-proxy configures networking for the pods

### Networking Layers
- **Pod Network**: Each pod gets its own IP address within the cluster
- **Service Network**: Stable IP addresses for accessing groups of pods
- **Node Network**: VPC network connecting all nodes
- **External Access**: Load balancers or [[GKE Gateway API|Gateway API]] for internet traffic

## Real-World Use Cases

### Use Case 1: Microservices Platform for E-commerce
**Scenario**: An online retailer needs to deploy 20+ microservices with independent scaling and deployment cycles.

**Implementation**:
- Create an Autopilot cluster for hands-off management
- Deploy each microservice as a separate deployment with 3-5 replicas
- Use [[Kubernetes Services|ClusterIP services]] for internal communication
- Configure [[Kubernetes Health and Scaling|HPA]] to auto-scale based on traffic
- Implement [[GKE Gateway API|Gateway API]] for external traffic routing
- Use namespaces: `production`, `staging`, `development`

**Benefits**: Independent scaling, zero-downtime deployments, automatic infrastructure management

### Use Case 2: Batch Data Processing Pipeline
**Scenario**: A data analytics company processes large datasets nightly, requiring significant compute resources for 2-3 hours.

**Implementation**:
- Standard mode cluster with multiple node pools
- Spot VMs node pool for cost optimization (up to 80% savings)
- Kubernetes Jobs for batch processing tasks
- Cluster autoscaler scales nodes from 5 to 50 during peak processing
- [[Kubernetes Health and Scaling|Horizontal Pod Autoscaler]] based on queue depth
- Scales back down to minimal nodes after processing completes

**Benefits**: Cost efficiency through spot instances and autoscaling, reliable job execution

### Use Case 3: Multi-Region Global Application
**Scenario**: A SaaS application requires low-latency access from users across US, Europe, and Asia.

**Implementation**:
- Three GKE clusters (us-central1, europe-west1, asia-southeast1)
- Multi Cluster Ingress for global load balancing
- Cloud SQL with read replicas in each region
- Identical deployments using [[Kustomize Configuration|Kustomize overlays]]
- ConfigMaps with region-specific settings

**Benefits**: Sub-100ms latency for users worldwide, regional failover capability

## Hands-On Examples

### Example 1: Creating a Basic GKE Cluster
```bash
# Create an Autopilot cluster (recommended for most use cases)
gcloud container clusters create-auto my-cluster \
    --region=us-central1 \
    --project=my-project

# Get cluster credentials for kubectl
gcloud container clusters get-credentials my-cluster \
    --region=us-central1 \
    --project=my-project

# Verify cluster access
kubectl get nodes
kubectl cluster-info
```
**Explanation**: This creates a fully managed Autopilot cluster where Google handles all infrastructure management. The cluster will automatically scale nodes based on your workload demands.

### Example 2: Deploying a Simple Application
```yaml
# deployment.yaml
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
      containers:
      - name: app
        image: gcr.io/google-samples/hello-app:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app-service
spec:
  type: LoadBalancer
  selector:
    app: demo-app
  ports:
  - port: 80
    targetPort: 8080
```

```bash
# Deploy the application
kubectl apply -f deployment.yaml

# Watch the service get an external IP
kubectl get service demo-app-service --watch

# Test the application
curl http://<EXTERNAL-IP>
```
**Explanation**: This deployment creates 3 replicas of a simple web application with specified resource requests/limits. The LoadBalancer service exposes it to the internet with a stable external IP address. GKE provisions a Google Cloud Load Balancer automatically.

### Example 3: Standard Cluster with Custom Node Pool
```bash
# Create a standard cluster with minimal initial resources
gcloud container clusters create my-standard-cluster \
    --zone=us-central1-a \
    --num-nodes=2 \
    --machine-type=e2-medium \
    --disk-size=50 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=10 \
    --enable-autorepair \
    --enable-autoupgrade

# Add a spot VM node pool for cost savings on fault-tolerant workloads
gcloud container node-pools create spot-pool \
    --cluster=my-standard-cluster \
    --zone=us-central1-a \
    --spot \
    --machine-type=e2-standard-4 \
    --num-nodes=0 \
    --enable-autoscaling \
    --min-nodes=0 \
    --max-nodes=20
```
**Explanation**: Standard mode gives you full control over node configuration. This example creates a cluster with a default pool for critical workloads and a spot VM pool for batch jobs that can tolerate interruptions, providing up to 80% cost savings.

## Best Practices

- **Choose Autopilot for Most Workloads**: Unless you need specific node customizations or access to alpha/beta Kubernetes features, Autopilot provides better management and cost efficiency
- **Set Resource Requests and Limits**: Always define CPU and memory requests/limits for predictable scheduling and cost management. In Autopilot, this is mandatory.
- **Use Multiple Node Pools Strategically**: In Standard mode, separate workloads into different node pools (e.g., frontend, backend, batch jobs) with appropriate machine types and autoscaling policies
- **Enable Binary Authorization**: Enforce that only trusted container images can be deployed to your cluster, preventing security vulnerabilities
- **Implement Workload Identity**: Use Workload Identity instead of service account keys to give pods access to Google Cloud services with fine-grained IAM permissions
- **Configure Pod Security Policies**: Enforce security constraints at the pod level (privileged containers, host networking, etc.)
- **Use Regional Clusters for Production**: Regional clusters replicate the control plane across multiple zones for high availability (99.95% SLA vs 99.5% for zonal)
- **Implement Network Policies**: Control traffic flow between pods using NetworkPolicy resources for defense in depth
- **Tag Resources Properly**: Use labels and annotations consistently for cost tracking, resource organization, and automation

## Common Pitfalls & Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Pods stuck in "Pending" state | Insufficient cluster resources or unschedulable resource requests | Check `kubectl describe pod <name>` for scheduling errors. Scale cluster or adjust resource requests |
| High costs | Over-provisioned nodes or missing autoscaling | Enable cluster autoscaling, right-size node pools, use Autopilot for automatic optimization |
| Pods can't reach external services | Missing egress firewall rules or NAT configuration | Verify VPC firewall rules allow egress, configure Cloud NAT if using private nodes |
| Can't pull container images | GCR/Artifact Registry permissions missing | Configure Workload Identity or ensure node service account has storage.objectViewer role |
| Connection refused errors | Service selector doesn't match pod labels | Verify `kubectl get endpoints <service-name>` shows pod IPs. Check label matching |
| Control plane version mismatch | Cluster hasn't been upgraded | Enable auto-upgrade or manually upgrade cluster: `gcloud container clusters upgrade` |
| Nodes not joining cluster | Network connectivity issues or quota exhausted | Check Compute Engine quota, verify VPC networking, check node logs in Cloud Logging |
| StatefulSet pods not starting | PersistentVolumeClaim can't be provisioned | Check storage quota, verify StorageClass exists, check PVC status with `kubectl describe pvc` |

## Related Topics
- [[GKE Gateway API]] - Modern ingress and traffic management for exposing applications to the internet
- [[Kubernetes Services]] - Service discovery and load balancing for internal cluster networking
- [[Kustomize Configuration]] - Configuration management for deploying across multiple environments
- [[Kubernetes Health and Scaling]] - Implement health checks and auto-scaling for production reliability

## Further Learning
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs) - Official comprehensive documentation
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices) - Google's production recommendations
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) - Understand Kubernetes internals
- [Google Cloud Skills Boost - GKE](https://www.cloudskillsboost.google/paths/23) - Hands-on labs and courses

## Tags
#gcp #gke #kubernetes #container-orchestration #cloud-infrastructure
