# GKE Gateway API

## Overview
The Gateway API is the next-generation Kubernetes API for managing ingress traffic and service networking. It provides a more expressive, extensible, and role-oriented model for configuring how external traffic reaches your services in GKE. Unlike the traditional Ingress API, Gateway API separates concerns between cluster operators and application developers through distinct resource types.

## Prerequisites
- Understanding of [[GKE Overview|GKE cluster architecture]]
- Familiarity with [[Kubernetes Services|Kubernetes Services]] and networking
- Knowledge of HTTP/HTTPS and DNS concepts
- Basic understanding of load balancers

## Key Concepts

### Gateway API vs Ingress
**Traditional Ingress**:
- Single resource type for all configuration
- Limited expressiveness for complex routing
- Vendor-specific annotations for advanced features
- Tight coupling between infrastructure and application concerns

**Gateway API**:
- Multiple resource types with clear separation of concerns
- Built-in support for advanced routing (header-based, weighted, mirroring)
- Standardized API across Kubernetes implementations
- Portable configurations without vendor lock-in

### Core Resource Types

**GatewayClass**:
- Defines a class of Gateways (cluster-scoped)
- Typically managed by cluster administrators
- Specifies the controller implementation (e.g., `gke-l7-global-external-managed`)

**Gateway**:
- Represents a load balancer instance
- Defines listeners (ports, protocols, hostnames)
- References a GatewayClass
- Managed by platform teams or cluster operators

**HTTPRoute**:
- Defines HTTP routing rules
- Maps hostnames and paths to backend services
- Configures traffic splitting, redirects, rewrites
- Managed by application developers

**Service**:
- Backend target for routes
- Standard [[Kubernetes Services|Kubernetes Service]] resource

### Traffic Flow Architecture
```
Internet → Cloud Load Balancer → Gateway → HTTPRoute → Service → Pods
           (GCP Infrastructure)   (K8s)     (K8s)       (K8s)     (K8s)
```

When a request arrives:
1. DNS resolves to the Gateway's external IP (Cloud Load Balancer)
2. Load balancer terminates TLS and routes based on hostname
3. Gateway listener matches the request to an HTTPRoute
4. HTTPRoute evaluates routing rules (path matching, headers, etc.)
5. Traffic forwards to the matching Service
6. Service load-balances across healthy pod endpoints

### Key Features

**Advanced Routing**:
- Path-based routing (exact, prefix, regex)
- Header-based routing
- Query parameter matching
- Method-based routing

**Traffic Management**:
- Weighted traffic splitting for canary deployments
- Request/response header manipulation
- URL rewriting and redirects
- Request mirroring for testing

**Multi-Tenancy**:
- Route delegation to different namespaces
- Clear ownership boundaries
- Fine-grained RBAC controls

## How It Works

### Gateway API Request Processing
When a request hits your Gateway:

1. **TLS Termination**: The Gateway listener handles HTTPS termination using certificates from Certificate Manager
2. **Hostname Matching**: Routes are evaluated based on the Host header
3. **Path Matching**: Within the matched hostname, HTTPRoute rules evaluate the URL path
4. **Rule Selection**: First matching rule wins (order matters)
5. **Backend Selection**: Traffic forwards to Service(s) defined in backendRefs
6. **Load Balancing**: Service distributes traffic to healthy pod endpoints

### Integration with Google Cloud Load Balancing
GKE Gateway API provisions and configures Google Cloud Load Balancers:

- **External Gateway**: Creates Global External HTTP(S) Load Balancer
- **Internal Gateway**: Creates Regional Internal HTTP(S) Load Balancer
- **Automatic Configuration**: Backend services, URL maps, health checks
- **Certificate Management**: Integrates with Google-managed SSL certificates

### Health Checking
Gateway API automatically configures health checks:
- Uses readiness probes from pod specs
- Creates Cloud Load Balancing health checks
- Removes unhealthy backends automatically
- Supports custom health check configurations

## Real-World Use Cases

### Use Case 1: Multi-Service Web Application
**Scenario**: A company runs a web application with separate frontend, API, and admin services that need different routing rules and TLS certificates.

**Implementation**:
```yaml
# Single Gateway handling all traffic
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: main-gateway
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    allowedRoutes:
      namespaces:
        from: All

# Frontend routes
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: frontend-route
  namespace: frontend
spec:
  parentRefs:
  - name: main-gateway
  hostnames:
  - "www.example.com"
  rules:
  - backendRefs:
    - name: frontend-service
      port: 80

# API routes with path-based routing
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: api-route
  namespace: backend
spec:
  parentRefs:
  - name: main-gateway
  hostnames:
  - "api.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /v1
    backendRefs:
    - name: api-v1-service
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /v2
    backendRefs:
    - name: api-v2-service
      port: 8080
```

**Benefits**: Clear separation of concerns, each team manages their own routes, shared infrastructure costs

### Use Case 2: Canary Deployment with Traffic Splitting
**Scenario**: Rolling out a new version of a critical service gradually to minimize risk, starting with 10% traffic to the new version.

**Implementation**:
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: canary-route
spec:
  parentRefs:
  - name: main-gateway
  hostnames:
  - "app.example.com"
  rules:
  - backendRefs:
    - name: app-stable
      port: 80
      weight: 90
    - name: app-canary
      port: 80
      weight: 10
```

**Process**:
1. Deploy new version as `app-canary` service
2. Start with 90/10 traffic split
3. Monitor error rates and latency
4. Gradually shift to 50/50, then 10/90
5. Eventually route 100% to new version
6. Decommission old version

**Benefits**: Zero-downtime deployments, gradual validation, easy rollback

### Use Case 3: Header-Based Routing for A/B Testing
**Scenario**: Testing a new feature with beta users identified by a custom header without affecting regular users.

**Implementation**:
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: ab-test-route
spec:
  parentRefs:
  - name: main-gateway
  hostnames:
  - "app.example.com"
  rules:
  # Beta users get new feature
  - matches:
    - headers:
      - name: X-Beta-User
        value: "true"
    backendRefs:
    - name: app-beta
      port: 80
  # Everyone else gets stable version
  - backendRefs:
    - name: app-stable
      port: 80
```

**Benefits**: Targeted feature testing, no infrastructure changes needed, instant switching

## Hands-On Examples

### Example 1: Basic Gateway Setup
```yaml
# gateway.yaml - Create the Gateway resource
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: demo-gateway
  namespace: default
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: http
    protocol: HTTP
    port: 80
```

```bash
# Apply the Gateway
kubectl apply -f gateway.yaml

# Watch the Gateway become ready (takes 2-3 minutes)
kubectl get gateway demo-gateway --watch

# Get the external IP address
kubectl get gateway demo-gateway -o jsonpath='{.status.addresses[0].value}'
```
**Explanation**: This creates a Google Cloud Global External HTTP(S) Load Balancer. The `gke-l7-global-external-managed` class tells GKE to provision the load balancer automatically. The status will show PROGRAMMED when ready.

### Example 2: Simple HTTPRoute with Path-Based Routing
```yaml
# httproute.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: demo-route
  namespace: default
spec:
  parentRefs:
  - name: demo-gateway
  hostnames:
  - "demo.example.com"
  rules:
  # Route /api/* to backend API service
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-service
      port: 8080
  # Route everything else to frontend
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: frontend-service
      port: 80
```

```bash
# Apply the route
kubectl apply -f httproute.yaml

# Verify the route is accepted
kubectl get httproute demo-route -o yaml | grep -A 5 status

# Test the routing (replace with your Gateway IP)
curl -H "Host: demo.example.com" http://<GATEWAY-IP>/api/health
curl -H "Host: demo.example.com" http://<GATEWAY-IP>/
```
**Explanation**: HTTPRoute defines how requests are routed based on hostname and path. Rules are evaluated in order, so put more specific rules first. The `PathPrefix` match type means `/api/users` and `/api/posts` both match the `/api` rule.

### Example 3: Advanced Routing with Header Modification
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: advanced-route
spec:
  parentRefs:
  - name: demo-gateway
  hostnames:
  - "api.example.com"
  rules:
  # Add security headers and route to backend
  - matches:
    - path:
        type: PathPrefix
        value: /api/v1
    filters:
    # Add custom headers to requests
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: X-API-Version
          value: "v1"
        - name: X-Request-ID
          value: "{request.id}"
        remove:
        - "X-Internal-Header"
    # Modify response headers
    - type: ResponseHeaderModifier
      responseHeaderModifier:
        add:
        - name: X-Cache-Control
          value: "no-cache"
        - name: Strict-Transport-Security
          value: "max-age=31536000"
    backendRefs:
    - name: api-v1-service
      port: 8080
  # Redirect old API version
  - matches:
    - path:
        type: PathPrefix
        value: /api/v0
    filters:
    - type: RequestRedirect
      requestRedirect:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /api/v1
        statusCode: 301
```
**Explanation**: Filters allow you to modify requests and responses. This example adds tracking headers, removes internal headers, sets security headers, and redirects old API paths. Filters are processed in order before reaching the backend.

### Example 4: HTTPS with Google-Managed Certificates
```yaml
# https-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: secure-gateway
  annotations:
    networking.gke.io/certmap: demo-cert-map
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    allowedRoutes:
      namespaces:
        from: All
```

```bash
# Create a Google-managed SSL certificate
gcloud certificate-manager certificates create demo-cert \
    --domains="demo.example.com,api.example.com"

# Create a certificate map
gcloud certificate-manager maps create demo-cert-map

# Add certificates to the map
gcloud certificate-manager maps entries create demo-entry \
    --map=demo-cert-map \
    --certificates=demo-cert \
    --hostname="demo.example.com"

# Apply the Gateway
kubectl apply -f https-gateway.yaml
```
**Explanation**: Google-managed certificates are provisioned and renewed automatically. The annotation links the Gateway to your certificate map. DNS validation is required, so ensure your domains point to the Gateway IP.

## Best Practices

- **Use HTTPRoute Per Service/Team**: Create separate HTTPRoute resources for each service or team to enable independent management and clear ownership boundaries
- **Implement Specific Path Matching First**: Order rules from most specific to least specific. More specific rules should appear earlier in the rules list
- **Set Reasonable Timeouts**: Configure request timeouts to prevent resource exhaustion from slow clients or backends
- **Use Weights for Gradual Rollouts**: Start with small weight values (5-10%) when testing new deployments, gradually increasing as confidence builds
- **Leverage Header Modification for Security**: Add security headers (CSP, HSTS, X-Frame-Options) using ResponseHeaderModifier filters
- **Monitor Gateway Metrics**: Use Cloud Monitoring to track request rates, error rates, and latency for your Gateway resources
- **Implement Health Checks Properly**: Define [[Kubernetes Health and Scaling|readiness probes]] that accurately reflect service health
- **Use Certificate Manager for TLS**: Let Google manage certificate provisioning and renewal instead of manual certificate management
- **Apply RBAC for Route Management**: Use Kubernetes RBAC to control which teams can create/modify HTTPRoutes
- **Version Your APIs in Paths**: Use path prefixes like `/v1` and `/v2` for API versioning to enable smooth migrations

## Common Pitfalls & Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Gateway stuck in "Pending" | GatewayClass not available or provisioning failure | Check `kubectl get gatewayclass` and verify the class exists. Check Gateway events with `kubectl describe gateway` |
| HTTPRoute not working | Route not attached to Gateway or namespace restrictions | Verify `parentRefs` matches Gateway name and namespace. Check Gateway `allowedRoutes` configuration |
| 404 errors | Path matching rules don't match request path | Review `matches` configuration. Remember `PathPrefix` requires exact prefix. Use `kubectl describe httproute` to check status |
| Traffic not splitting as expected | Weights don't sum to expected total | Weight values are relative, not percentages. 90/10 and 9/1 produce the same result |
| TLS certificate provisioning failed | DNS validation not completed | Verify DNS records point to Gateway IP. Check certificate status: `gcloud certificate-manager certificates describe` |
| Backend service not receiving traffic | Service selector doesn't match pods | Verify `kubectl get endpoints <service-name>` shows pod IPs. Check service port matches backend port |
| High latency | No health checks or unhealthy backends | Define readiness probes. Check backend health: `kubectl get endpointslices` |
| Header modifications not applied | Filter syntax error or unsupported header | Check HTTPRoute status conditions. Some headers (like Host) can't be modified |
| Can't route to services in other namespaces | ReferenceGrant missing | Create ReferenceGrant to allow cross-namespace references |

## Related Topics
- [[GKE Overview]] - Understanding the GKE cluster foundation that Gateway API runs on
- [[Kubernetes Services]] - Backend services that Gateway routes traffic to
- [[Kubernetes Health and Scaling]] - Configure health checks for proper load balancing
- [[Kustomize Configuration]] - Manage Gateway and HTTPRoute configurations across environments

## Further Learning
- [Gateway API Official Documentation](https://gateway-api.sigs.k8s.io/) - Kubernetes Gateway API specifications and guides
- [GKE Gateway API Guide](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api) - Google Cloud specific implementation details
- [Gateway API Examples](https://github.com/kubernetes-sigs/gateway-api/tree/main/examples) - Community examples and use cases
- [GKE Ingress for HTTP(S) Load Balancing](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress) - Understanding the underlying load balancing infrastructure

## Tags
#gcp #gke #gateway-api #kubernetes #load-balancing #ingress #networking
