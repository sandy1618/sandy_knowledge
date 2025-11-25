# Kubernetes Health Checks and Auto-Scaling

## Overview
Kubernetes provides built-in mechanisms to ensure application reliability and efficient resource utilization through health probes and auto-scaling. Health probes (liveness and readiness) enable Kubernetes to automatically detect and recover from application failures, while the Horizontal Pod Autoscaler (HPA) automatically adjusts the number of pod replicas based on resource utilization or custom metrics. Together, these features create self-healing, responsive applications that maintain availability under varying load conditions.

## Prerequisites
- Understanding of [[GKE Overview|Kubernetes pods and deployments]]
- Familiarity with [[Kubernetes Services|services and load balancing]]
- Basic knowledge of application health endpoints
- Understanding of CPU and memory metrics

## Key Concepts

### Health Probe Types

**Liveness Probe**:
- Determines if a container is running properly
- Failed liveness probes trigger container restarts
- Use for detecting deadlocks or hung processes
- Example: Application is running but stuck in infinite loop

**Readiness Probe**:
- Determines if a container is ready to accept traffic
- Failed readiness probes remove pod from [[Kubernetes Services|Service]] endpoints
- Use for startup delays or temporary unavailability
- Example: Application is starting up and loading data

**Startup Probe**:
- Provides additional time for slow-starting containers
- Disables liveness and readiness probes until it succeeds
- Use for legacy applications with long initialization
- Example: Application needs 2 minutes to warm up

### Probe Mechanisms

Kubernetes supports three ways to perform health checks:

**HTTP GET**:
- Makes HTTP request to specified path and port
- Success: HTTP status code 200-399
- Most common for web applications
```yaml
httpGet:
  path: /health
  port: 8080
```

**TCP Socket**:
- Attempts to open TCP connection
- Success: Connection established
- Useful for non-HTTP services (databases, message queues)
```yaml
tcpSocket:
  port: 5432
```

**Exec Command**:
- Executes command inside container
- Success: Exit code 0
- Useful for custom health check logic
```yaml
exec:
  command:
  - cat
  - /tmp/healthy
```

### Probe Configuration Parameters

**initialDelaySeconds**: Wait before first probe (default: 0)
**periodSeconds**: How often to probe (default: 10)
**timeoutSeconds**: Probe timeout (default: 1)
**successThreshold**: Consecutive successes to be considered healthy (default: 1)
**failureThreshold**: Consecutive failures before action taken (default: 3)

### Horizontal Pod Autoscaler (HPA)

HPA automatically scales the number of pod replicas based on observed metrics:

**Scaling Metrics**:
- Resource metrics: CPU, memory utilization
- Custom metrics: Application-specific metrics (queue depth, request rate)
- External metrics: Metrics from outside cluster (Cloud Monitoring)

**Scaling Behavior**:
- Scale-up: Responds quickly to increased load
- Scale-down: Gradual to avoid flapping
- Cooldown periods prevent rapid scaling oscillations

**Calculation**:
```
desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]
```

### Vertical Pod Autoscaler (VPA)

VPA automatically adjusts CPU and memory requests/limits:
- Recommends optimal resource values
- Can automatically apply recommendations
- Useful when resource requirements are unknown
- Requires pod restart to apply changes

## How It Works

### Liveness Probe Lifecycle
1. Container starts
2. Kubernetes waits `initialDelaySeconds`
3. Performs probe every `periodSeconds`
4. Waits up to `timeoutSeconds` for response
5. If probe fails `failureThreshold` consecutive times:
   - Container is killed
   - kubelet restarts container
   - Restart count increments
6. If restart count exceeds threshold, CrashLoopBackOff occurs

### Readiness Probe Lifecycle
1. Container starts (marked as not ready)
2. Kubernetes waits `initialDelaySeconds`
3. Performs probe every `periodSeconds`
4. After `successThreshold` consecutive successes:
   - Pod marked as ready
   - Added to Service endpoints
   - Starts receiving traffic
5. If probe fails `failureThreshold` times:
   - Pod removed from Service endpoints
   - No traffic routed to pod
   - Container continues running (not restarted)

### HPA Scaling Process
```
Metrics Server → HPA Controller → Deployment → ReplicaSet → Pods
```

1. Metrics Server collects pod resource metrics every 15 seconds
2. HPA controller queries metrics every 30 seconds (configurable)
3. Calculates desired replica count based on target utilization
4. Updates Deployment's replica count if change needed
5. ReplicaSet controller creates or deletes pods
6. Respects scaling policies (cooldown periods, rate limits)

### Scale-Up Decision Making
- HPA detects average CPU usage > target (e.g., 70% CPU, target is 50%)
- Calculates: `desiredReplicas = 5 * (70 / 50) = 7`
- Checks scale-up policy (max replicas, rate limits)
- Updates Deployment from 5 to 7 replicas
- Kubernetes Scheduler places new pods on nodes
- Takes 30-60 seconds for new pods to receive traffic

### Scale-Down Decision Making
- More conservative to prevent flapping
- Default 5-minute stabilization window
- Checks for all metrics below target
- Gradually reduces replicas
- Never scales below minReplicas

## Real-World Use Cases

### Use Case 1: Web API with Traffic Spikes
**Scenario**: An e-commerce API experiences 10x traffic during sales events. Normal load: 1000 req/s, peak: 10000 req/s.

**Implementation**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: api
        image: api-server:v1
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 2
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 3
  maxReplicas: 30
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Pods
        value: 1
        periodSeconds: 60
```

**Results**:
- During normal load: 3-5 replicas
- During sales event: Scales to 25-30 replicas within 2 minutes
- Gradual scale-down prevents premature resource reduction
- Failed pods automatically restart, removed from traffic during restarts

### Use Case 2: Long-Running Job Processor
**Scenario**: Background job processor handles tasks that take 30-60 seconds. Jobs are pulled from a queue.

**Implementation**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: job-processor
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: processor
        image: job-processor:v1
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -c
            - "ps aux | grep -v grep | grep processor"
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: job-processor-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: job-processor
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Pods
    pods:
      metric:
        name: queue_depth
      target:
        type: AverageValue
        averageValue: "30"
```

**How It Works**:
- Readiness probe checks if processor can accept new jobs
- Liveness probe verifies process is running
- HPA scales based on queue depth (custom metric)
- Target: 30 jobs per pod
- If queue has 600 jobs: scales to 20 pods
- Empty queue: scales down to 2 pods (minimum)

### Use Case 3: Database with Slow Startup
**Scenario**: PostgreSQL database takes 90 seconds to start, perform recovery, and accept connections.

**Implementation**:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  template:
    spec:
      containers:
      - name: postgres
        image: postgres:14
        ports:
        - containerPort: 5432
        startupProbe:
          tcpSocket:
            port: 5432
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 30  # 30 * 5s = 150s max startup time
        livenessProbe:
          tcpSocket:
            port: 5432
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - postgres
          periodSeconds: 5
          failureThreshold: 3
```

**Benefits**:
- Startup probe allows 150 seconds for initialization
- Liveness probe only activates after startup completes
- Readiness probe ensures database accepts connections before receiving traffic
- Prevents premature restarts during recovery

## Hands-On Examples

### Example 1: Basic Health Probes
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: app
        image: webapp:v1
        ports:
        - containerPort: 8080
        # Liveness: Restart if app is deadlocked
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            httpHeaders:
            - name: Custom-Header
              value: LivenessCheck
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        # Readiness: Remove from service if not ready
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          successThreshold: 1
          failureThreshold: 2
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

```bash
# Apply deployment
kubectl apply -f deployment.yaml

# Watch pod status
kubectl get pods -w

# Check probe events
kubectl describe pod <pod-name> | grep -A 10 Events

# Test readiness: pod should be removed from service
kubectl exec <pod-name> -- rm /tmp/ready
kubectl get endpoints webapp-service  # Pod IP disappears
```
**Explanation**: Liveness checks `/healthz` every 10 seconds after 30-second delay. Three consecutive failures trigger a restart. Readiness checks `/ready` more frequently (every 5 seconds) with shorter delay, removing pods from service rotation during startup or temporary issues.

### Example 2: HPA with CPU-Based Scaling
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  replicas: 2
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
        image: demo-app:v1
        resources:
          requests:
            cpu: 200m  # HPA uses this as 100% baseline
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: demo-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: demo-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Target 50% of requested CPU
```

```bash
# Apply resources
kubectl apply -f deployment.yaml
kubectl apply -f hpa.yaml

# Generate load to trigger scaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://demo-app-service; done"

# Watch HPA scale up
kubectl get hpa demo-app-hpa --watch

# View current metrics
kubectl top pods -l app=demo-app

# Check scaling events
kubectl describe hpa demo-app-hpa
```
**Explanation**: HPA targets 50% CPU utilization. If average CPU across all pods exceeds 50% of requested CPU (100m per pod), HPA scales up. With 2 pods at 80% CPU: `desiredReplicas = 2 * (80/50) = 3.2 → 4 pods`. Scales down gradually when CPU drops below target.

### Example 3: Multi-Metric HPA
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: advanced-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 3
  maxReplicas: 50
  metrics:
  # Scale based on CPU
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # Scale based on memory
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  # Scale based on custom metric (requests per second)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100  # Double pods count
        periodSeconds: 15
      - type: Pods
        value: 5  # Or add 5 pods
        periodSeconds: 15
      selectPolicy: Max  # Use policy that scales most
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 minutes
      policies:
      - type: Pods
        value: 1  # Remove 1 pod at a time
        periodSeconds: 60
```

```bash
# Apply HPA
kubectl apply -f advanced-hpa.yaml

# HPA evaluates ALL metrics and uses highest recommendation
# Example: CPU says 10 replicas, memory says 8, requests say 12
# Result: Scales to 12 replicas

# Monitor metrics
kubectl get hpa advanced-hpa -o yaml | grep -A 20 currentMetrics
```
**Explanation**: Multi-metric HPA evaluates all configured metrics and chooses the highest recommended replica count. This prevents under-provisioning. The behavior section defines scale-up (aggressive, choose fastest policy) and scale-down (conservative, 1 pod every 60 seconds) policies separately.

### Example 4: Startup Probe for Slow Applications
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: legacy-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: legacy-app
  template:
    metadata:
      labels:
        app: legacy-app
    spec:
      containers:
      - name: app
        image: legacy-app:v1
        ports:
        - containerPort: 8080
        # Startup probe: Allow up to 5 minutes for startup
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          initialDelaySeconds: 0
          periodSeconds: 10
          failureThreshold: 30  # 30 * 10s = 5 minutes
        # Liveness: Only checks after startup succeeds
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          periodSeconds: 10
          failureThreshold: 3
        # Readiness: Check frequently after startup
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          periodSeconds: 5
          failureThreshold: 2
```

```bash
# Deploy and watch startup
kubectl apply -f legacy-app.yaml
kubectl get pods -w

# Pod goes through states:
# 1. Running (0/1) - Container running, startup probe checking
# 2. Running (0/1) - Startup probe succeeds, readiness probe starts
# 3. Running (1/1) - Readiness probe succeeds, pod ready

# Check probe status
kubectl describe pod <pod-name> | grep -E "Startup|Liveness|Readiness"
```
**Explanation**: Startup probe gives 5 minutes for initialization. Liveness and readiness probes don't run until startup succeeds, preventing premature restarts. This is critical for applications with long initialization times (data loading, cache warming, compilation).

## Best Practices

- **Always Define Resource Requests**: HPA requires CPU/memory requests to calculate utilization percentages. Without requests, CPU-based HPA won't work
- **Implement Both Liveness and Readiness**: They serve different purposes. Liveness detects permanent failures, readiness handles temporary unavailability
- **Set Appropriate Thresholds**: Three failures (30 seconds with default settings) before restart is reasonable. Too sensitive causes restart storms
- **Use Longer Initial Delays**: Set `initialDelaySeconds` longer than your application's actual startup time to prevent premature probe failures
- **Health Endpoints Should Be Lightweight**: Probes run frequently. Health checks should complete in milliseconds, not seconds
- **Monitor Probe Failures**: Set up alerts for high probe failure rates - they indicate real application problems
- **Test Probe Configuration**: Intentionally make health checks fail in dev to verify Kubernetes responds correctly
- **Set Appropriate HPA Targets**: 70-80% CPU utilization is reasonable. Too low wastes resources, too high risks performance degradation
- **Use Stabilization Windows**: Prevent scaling flapping. Default 5-minute scale-down stabilization is usually good
- **Configure Scale-Down Policies**: Be conservative. Aggressive scale-down can cause service degradation if load increases again
- **Monitor Scaling Events**: Use `kubectl describe hpa` regularly to understand scaling behavior and tune thresholds
- **Don't Scale Below Minimum Requirements**: Set `minReplicas` high enough for baseline availability (at least 2 for redundancy)

## Common Pitfalls & Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Pods constantly restarting | Liveness probe failing immediately after start | Increase `initialDelaySeconds` or implement startup probe |
| CrashLoopBackOff | Application fails to start or liveness probe never succeeds | Check pod logs: `kubectl logs <pod>`. Verify health endpoint works |
| Pods not receiving traffic | Readiness probe failing | Check probe endpoint: `kubectl exec <pod> -- curl localhost:8080/ready` |
| HPA not scaling | Missing resource requests or Metrics Server not installed | Add CPU/memory requests. Check: `kubectl top nodes` |
| HPA shows "unknown" metrics | Metrics Server can't scrape pod metrics | Verify pod is running and metrics endpoint accessible |
| Scaling too aggressive | No stabilization window or loose thresholds | Add `behavior.scaleUp.stabilizationWindowSeconds`, increase target utilization |
| Scaling too slow | Conservative scaling policies or high stabilization window | Adjust `behavior.scaleUp.policies` to scale faster |
| Never scales down | CPU constantly above target | Lower target utilization or investigate why pods use so much CPU |
| Probe timeout errors | Health check takes too long | Optimize health endpoint. Increase `timeoutSeconds` temporarily |
| HPA scales to max immediately | One metric way above target | Check which metric is high: `kubectl describe hpa`. Tune that metric's target |

## Related Topics
- [[GKE Overview]] - Understanding the infrastructure that runs your auto-scaled pods
- [[Kubernetes Services]] - Services use readiness probes to determine which pods receive traffic
- [[GKE Gateway API]] - Gateway API integrates with readiness probes for health checking
- [[Kustomize Configuration]] - Manage different probe configurations and HPA settings across environments

## Further Learning
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/) - Official Kubernetes documentation
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) - Comprehensive HPA guide
- [HPA Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) - Step-by-step tutorial
- [Best Practices for Health Probes](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-setting-up-health-checks-with-readiness-and-liveness-probes) - Google Cloud blog post

## Tags
#kubernetes #health-checks #auto-scaling #hpa #liveness #readiness #reliability #sre
