# Kubernetes Services

## Overview
Kubernetes Services provide stable networking endpoints for accessing groups of pods. Since pods are ephemeral and can be created, destroyed, or rescheduled with different IP addresses, Services act as an abstraction layer that enables reliable service discovery and load balancing across pod replicas without clients needing to track individual pod IPs.

## Prerequisites
- Understanding of [[GKE Overview|Kubernetes pods and deployments]]
- Basic networking knowledge (IP addresses, ports, DNS)
- Familiarity with load balancing concepts
- Understanding of container networking basics

## Key Concepts

### The Service Abstraction
A Service is a Kubernetes resource that defines:
- A logical set of pods (selected by labels)
- A stable virtual IP address (ClusterIP)
- A DNS name for discovery
- Load balancing policy across selected pods
- Port mapping from service ports to container ports

### Label Selectors
Services use label selectors to determine which pods receive traffic:
```yaml
selector:
  app: demo-app
  version: v1
```
Any pod with matching labels automatically becomes a backend for the service. This dynamic discovery means new pods are automatically added and terminated pods are removed.

### Service Types

Kubernetes supports four service types, each providing different networking capabilities:

**ClusterIP** (Default):
- Exposes service on an internal cluster IP
- Only accessible from within the cluster
- Used for internal microservice communication
- Most common service type

**NodePort**:
- Exposes service on each node's IP at a static port (30000-32767 range)
- Accessible from outside the cluster via `<NodeIP>:<NodePort>`
- Automatically creates a ClusterIP service as well
- Useful for development or when you control node networking

**LoadBalancer**:
- Creates an external load balancer (cloud provider specific)
- Assigns an external IP address
- Automatically creates NodePort and ClusterIP services
- Used for exposing services to the internet

**ExternalName**:
- Maps service to an external DNS name
- No proxying or load balancing
- Used for integrating external services into cluster DNS

### Endpoints and EndpointSlices
When you create a Service, Kubernetes automatically creates an Endpoints object that tracks the IP addresses and ports of matching pods:
- **Endpoints**: Lists all pod IPs that match the service selector
- **EndpointSlices**: Newer, more scalable way to track endpoints (default in modern clusters)
- Automatically updated when pods are added/removed
- Used by kube-proxy to configure load balancing

### How Internal Networking Works

**DNS Resolution**:
- Every Service gets a DNS entry: `<service-name>.<namespace>.svc.cluster.local`
- Pods can simply use the service name: `http://api-service`
- CoreDNS handles cluster DNS resolution

**Traffic Flow**:
```
Pod → Service DNS Name → ClusterIP → iptables/IPVS rules → Pod IP
```

**kube-proxy**:
- Runs on every node
- Watches Services and Endpoints
- Configures iptables/IPVS rules for load balancing
- Distributes traffic across healthy backends

## How It Works

### Service Discovery Process
1. **Service Creation**: You create a Service with a label selector
2. **Endpoint Population**: Kubernetes finds all pods matching the selector and populates Endpoints
3. **DNS Registration**: CoreDNS registers the service name
4. **Proxy Configuration**: kube-proxy creates routing rules on each node
5. **Traffic Routing**: When a pod makes a request to the service, local iptables/IPVS rules route it to a healthy backend pod

### LoadBalancer Type in GKE
When you create a LoadBalancer service in [[GKE Overview|GKE]]:
1. GKE provisions a Google Cloud Load Balancer
2. Load balancer gets a public IP address
3. Backend service is created pointing to node pools
4. Health checks are configured based on pod probes
5. Traffic flows: Internet → Load Balancer → Node → kube-proxy → Pod

### Session Affinity
By default, Services distribute requests randomly across pods. Session affinity (stickiness) routes requests from the same client to the same pod:
- **ClientIP**: Based on client IP address
- **None**: Random distribution (default)

Useful for stateful applications or when you need connection persistence.

## Real-World Use Cases

### Use Case 1: Microservices Internal Communication
**Scenario**: An e-commerce application with separate frontend, cart, inventory, and payment services that need to communicate reliably.

**Implementation**:
```yaml
# Cart service (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: cart-service
  namespace: ecommerce
spec:
  type: ClusterIP
  selector:
    app: cart
  ports:
  - port: 8080
    targetPort: 8080
    name: http

---
# Frontend can call: http://cart-service.ecommerce:8080/api/cart
# Or simply: http://cart-service:8080 (from same namespace)
```

**Benefits**: Services auto-discover each other, no hardcoded IPs, automatic load balancing across replicas, zero-downtime during pod replacements

### Use Case 2: Exposing Web Application to Internet
**Scenario**: A web application needs a public IP address for users to access, with automatic load balancing across multiple pod replicas.

**Implementation**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-frontend
spec:
  type: LoadBalancer
  selector:
    app: frontend
    tier: web
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
  sessionAffinity: ClientIP  # Sticky sessions for this example
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
```

**Process**:
1. GKE provisions a regional or global load balancer
2. External IP is assigned (visible in `kubectl get svc`)
3. Configure DNS record to point to the external IP
4. Traffic routes through load balancer to healthy pods
5. Health checks automatically remove unhealthy backends

**Benefits**: High availability, automatic failover, handles traffic spikes with autoscaling

### Use Case 3: Headless Service for StatefulSet
**Scenario**: A database cluster (like MongoDB or Cassandra) where clients need to connect to specific pod instances, not a load-balanced endpoint.

**Implementation**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: database-cluster
spec:
  clusterIP: None  # Headless service
  selector:
    app: database
  ports:
  - port: 27017
    targetPort: 27017
```

**DNS Resolution**:
- Normal service: `database-cluster` → single ClusterIP
- Headless service: `database-cluster` → multiple pod IPs
- Individual pods: `pod-0.database-cluster`, `pod-1.database-cluster`

**Benefits**: Direct pod-to-pod communication, supports StatefulSet requirements, enables peer discovery

## Hands-On Examples

### Example 1: Basic ClusterIP Service
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: gcr.io/my-project/api-server:v1
        ports:
        - containerPort: 8080
---
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api  # Must match deployment pod labels
  ports:
  - port: 80       # Service port
    targetPort: 8080  # Container port
    protocol: TCP
  type: ClusterIP
```

```bash
# Apply the resources
kubectl apply -f deployment.yaml

# Check that endpoints are populated
kubectl get endpoints api-service

# Test internal connectivity from another pod
kubectl run test-pod --rm -i --tty --image=curlimages/curl -- sh
curl http://api-service/health
```
**Explanation**: This creates an internal service accessible only within the cluster. The service load-balances across all 3 pod replicas. The `selector` must match pod labels exactly for endpoints to populate.

### Example 2: LoadBalancer Service with Custom Ports
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
  annotations:
    cloud.google.com/load-balancer-type: "External"
spec:
  type: LoadBalancer
  selector:
    app: webapp
    tier: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8443
    protocol: TCP
  externalTrafficPolicy: Local  # Preserve client IP
```

```bash
# Apply the service
kubectl apply -f service.yaml

# Watch for external IP assignment (takes 1-2 minutes)
kubectl get service web-app --watch

# Get the external IP
EXTERNAL_IP=$(kubectl get service web-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test the service
curl http://$EXTERNAL_IP
```
**Explanation**: LoadBalancer type provisions a cloud load balancer with an external IP. `externalTrafficPolicy: Local` preserves the client's source IP address but only routes to pods on the same node receiving traffic. The service exposes both HTTP and HTTPS ports.

### Example 3: NodePort Service for Development
```yaml
apiVersion: v1
kind: Service
metadata:
  name: debug-service
spec:
  type: NodePort
  selector:
    app: debug-app
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080  # Optional: specify port (30000-32767)
    protocol: TCP
```

```bash
# Apply the service
kubectl apply -f service.yaml

# Get node external IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

# Access the service
curl http://$NODE_IP:30080
```
**Explanation**: NodePort opens the same port on all cluster nodes. This is useful for development or when you have direct access to node IPs. In production, LoadBalancer or [[GKE Gateway API|Gateway API]] are preferred.

### Example 4: Headless Service for StatefulSet
```yaml
# statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
spec:
  serviceName: database-cluster
  replicas: 3
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: db
        image: mongo:6.0
        ports:
        - containerPort: 27017
---
# headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: database-cluster
spec:
  clusterIP: None  # This makes it headless
  selector:
    app: database
  ports:
  - port: 27017
    targetPort: 27017
```

```bash
# Apply resources
kubectl apply -f statefulset.yaml

# Check individual pod DNS entries
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
nslookup database-cluster
nslookup database-0.database-cluster
nslookup database-1.database-cluster
```
**Explanation**: Headless services (clusterIP: None) don't get a virtual IP. DNS returns all pod IPs directly, enabling direct pod-to-pod communication. StatefulSets require headless services for stable network identities.

## Best Practices

- **Use ClusterIP for Internal Services**: Default to ClusterIP for all internal microservice communication. It's the most efficient and secure option
- **Avoid Unnecessary LoadBalancers**: Each LoadBalancer costs money. Use [[GKE Gateway API|Gateway API]] or Ingress to share a load balancer across multiple services
- **Set Resource Requests/Limits on Pods**: Ensure backing pods have proper resource configuration for predictable performance
- **Implement Readiness Probes**: Services only route to pods that pass [[Kubernetes Health and Scaling|readiness checks]]. This prevents traffic to unhealthy pods
- **Use Meaningful Service Names**: Service names become DNS entries, use descriptive names like `api-service`, `database-primary`
- **Namespace Your Services**: Use namespaces to organize services by environment or team. Access via `service.namespace.svc.cluster.local`
- **Configure Session Affinity Carefully**: Only use when necessary (stateful apps), as it can cause uneven load distribution
- **Use Annotations for Load Balancer Configuration**: Cloud provider annotations enable advanced features (internal load balancers, SSL policies)
- **Monitor Service Endpoints**: Empty endpoints means no pods match the selector - a common misconfiguration
- **Consider externalTrafficPolicy**: Use `Local` to preserve client IPs but understand it changes load balancing behavior

## Common Pitfalls & Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Service has no endpoints | Label selector doesn't match any pods | Verify `kubectl get pods -l app=myapp` returns pods. Check selector spelling and case |
| Connection refused | Target port doesn't match container port | Check pod's `containerPort` matches service's `targetPort` |
| Service not accessible | Wrong service type for access pattern | ClusterIP only works internally. Use LoadBalancer or NodePort for external access |
| Intermittent connection failures | Pods failing readiness probes | Implement proper [[Kubernetes Health and Scaling\|readiness probes]]. Check `kubectl get pods` for ready status |
| LoadBalancer stuck in "Pending" | Cloud provider can't provision LB | Check quotas, verify cluster has external connectivity. Check events: `kubectl describe svc` |
| Can't reach service by name | DNS issue or wrong namespace | Use FQDN: `service.namespace.svc.cluster.local`. Check CoreDNS is running |
| Uneven traffic distribution | Session affinity or unhealthy pods | Check `sessionAffinity` setting. Verify all pods are healthy and ready |
| External IP shows `<none>` | LoadBalancer provisioning in progress | Wait 1-2 minutes. If persists, check cloud provider integration and quotas |
| Service routes to wrong pods | Multiple services with overlapping selectors | Make selectors specific and unique. Review all services' selectors |
| Port already allocated error | NodePort conflicts with existing service | Remove `nodePort` specification to auto-assign, or choose different port |

## Related Topics
- [[GKE Overview]] - Understanding the cluster infrastructure services run on
- [[GKE Gateway API]] - Modern way to expose services externally with advanced routing
- [[Kubernetes Health and Scaling]] - Configure probes that services use for health checking
- [[Kustomize Configuration]] - Manage service configurations across environments

## Further Learning
- [Kubernetes Services Documentation](https://kubernetes.io/docs/concepts/services-networking/service/) - Official comprehensive guide
- [Service Types Explained](https://kubernetes.io/docs/tutorials/kubernetes-basics/expose/expose-intro/) - Tutorial on different service types
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) - Understanding service DNS
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) - Control traffic between services

## Tags
#kubernetes #networking #services #load-balancing #service-discovery #clusterip #loadbalancer
