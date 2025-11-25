# Architecture Overview

## System Architecture

This tutorial demonstrates a production-ready architecture for deploying applications on GKE with external load balancing.

## Traffic Flow

```
Internet
    |
    | HTTP Request
    v
Google Cloud Load Balancer (Global)
    |
    | Routes based on HTTPRoute rules
    v
Gateway (gke-l7-global-external-managed)
    |
    | Forwards to ClusterIP Service
    v
Service (demo-app)
    |
    | Load balances across Pod IPs
    v
Pod (nginx) - Pod (nginx) - Pod (nginx)
    |
    | Managed by Deployment
    v
HorizontalPodAutoscaler
    |
    | Monitors CPU and scales Deployment
    v
2-10 Pods (auto-scaled)
```

## Component Breakdown

### 1. Gateway (External Load Balancer)

**Resource**: `gateway.yaml`

- Creates a Google Cloud Application Load Balancer
- Provides a public IP address
- Handles SSL/TLS termination (when configured)
- Global load balancing across regions
- Built-in DDoS protection
- Health checking
- Connection draining

**GatewayClass**: `gke-l7-global-external-managed`
- Fully managed by Google Cloud
- No manual backend service configuration
- Automatic SSL certificate provisioning (when configured)
- Integrated with Cloud Armor for security

### 2. HTTPRoute (Routing Rules)

**Resource**: `httproute.yaml`

- Defines how traffic is routed to backend services
- Supports path-based routing (`/api`, `/web`, etc.)
- Supports header-based routing
- Traffic splitting for canary deployments
- Automatic retries and timeouts

**Traffic Flow**:
```
HTTPRoute matches:
  / (all paths) → demo-app Service (100% weight)
```

### 3. Service (Internal Load Balancer)

**Resource**: `service.yaml`

- Type: ClusterIP (internal-only)
- Provides stable DNS name within cluster
- Load balances across Pod IPs
- Automatic endpoint management
- Health checking integration

**Service Discovery**:
- DNS: `demo-app.demo-app.svc.cluster.local`
- Port: 80 → Pod port 80

### 4. Deployment (Application Management)

**Resource**: `deployment.yaml`

- Manages Pod lifecycle
- Rolling updates with zero downtime
- Automatic Pod replacement on failure
- Resource management
- Health checking (liveness + readiness probes)

**Pod Specifications**:
- Image: `nginx:1.25-alpine`
- Resources:
  - Request: 100m CPU, 128Mi memory
  - Limit: 200m CPU, 256Mi memory
- Security: Non-root user, dropped capabilities

### 5. HorizontalPodAutoscaler (Auto-Scaling)

**Resource**: `hpa.yaml`

- Monitors CPU utilization
- Automatically scales Pods between 2-10 replicas
- Target: 70% CPU utilization
- Scaling policies:
  - Scale up: Fast (100% or 2 pods per minute)
  - Scale down: Conservative (50% or 1 pod per minute)

**Scaling Behavior**:
```
CPU < 70%: Gradually scale down (wait 5 minutes)
CPU > 70%: Quickly scale up (wait 1 minute)
```

## Network Path Details

### External Request Flow

1. **Client Request**
   - User sends HTTP request to Gateway IP
   - DNS resolution (if using custom domain)

2. **Google Cloud Load Balancer**
   - Receives request at edge location (global)
   - SSL termination (if HTTPS configured)
   - Applies Cloud Armor rules (if configured)
   - Routes to nearest healthy backend

3. **GKE Gateway**
   - Matches request against HTTPRoute rules
   - Selects backend Service based on rules
   - Forwards to Service ClusterIP

4. **Kubernetes Service**
   - Receives request at ClusterIP
   - Selects healthy Pod using kube-proxy
   - Forwards to Pod IP:Port

5. **Pod**
   - nginx receives request
   - Readiness probe confirms Pod is ready
   - Processes request and sends response

6. **Response Path**
   - Pod → Service → Gateway → Load Balancer → Client

## High Availability Features

### Load Balancer Level
- Global load balancing
- Automatic failover
- Health checking
- Connection draining

### Service Level
- Multiple Pod endpoints
- Automatic endpoint updates
- Session affinity (optional)

### Pod Level
- Multiple replicas (2-10)
- Liveness probes (restart unhealthy)
- Readiness probes (remove from service)
- Resource guarantees

### Auto-Scaling
- CPU-based scaling
- Fast scale-up for traffic spikes
- Conservative scale-down for stability

## Security Layers

### Network Security
- Private node IPs (GKE private cluster)
- Master authorized networks
- VPC firewall rules
- Cloud Armor (optional, for DDoS protection)

### Pod Security
- Non-root containers
- Dropped Linux capabilities
- Read-only root filesystem (optional)
- Security context constraints

### Access Control
- Kubernetes RBAC
- Service accounts
- Workload Identity (for GCP API access)

## Monitoring Points

### Gateway Metrics
- Request rate
- Latency (p50, p95, p99)
- Error rate (4xx, 5xx)
- Backend health

### Service Metrics
- Endpoint health
- Connection count
- Request distribution

### Pod Metrics
- CPU utilization
- Memory usage
- Container restarts
- Probe failures

### HPA Metrics
- Current replicas
- Desired replicas
- CPU utilization
- Scaling events

## Scalability Characteristics

### Vertical Scaling
- GKE Autopilot: Automatic node provisioning
- Pod resources: Request/limit adjustments

### Horizontal Scaling
- HPA: 2-10 Pods
- Load Balancer: Unlimited capacity
- Global distribution: Multi-region (optional)

### Capacity Planning
- Each Pod: 100m CPU baseline
- 10 Pods: ~1 CPU core total
- Autopilot: Provisions nodes automatically
- Load Balancer: Google-managed capacity

## Cost Optimization

### Resource Efficiency
- Autopilot: Pay per Pod resource request
- HPA: Scale down during low traffic
- Minimum replicas: 2 (high availability)

### Load Balancer Costs
- Forwarding rule: ~$18/month
- Data processing: $0.008-0.016/GB
- Total: $25-50/month for moderate traffic

See [[Cost Estimation]] for detailed breakdown.

## Related Topics

- [[GKE Gateway API]] - Gateway API concepts and configuration
- [[GKE Overview]] - GKE fundamentals
- [[Kubernetes Services]] - Service types and networking
- [[Kubernetes HPA]] - HorizontalPodAutoscaler deep dive

## Further Reading

- [GKE Gateway API Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api)
- [Google Cloud Load Balancing](https://cloud.google.com/load-balancing/docs)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)

#gke #architecture #load-balancing #kubernetes #networking
