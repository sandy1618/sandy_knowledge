# Kustomize Configuration Management

## Overview
Kustomize is a Kubernetes-native configuration management tool that lets you customize application configurations without using templates. It introduces a declarative approach to managing Kubernetes manifests across multiple environments (dev, staging, production) using a base-and-overlay pattern. Unlike templating tools like Helm, Kustomize works with standard YAML files and applies strategic merge patches, making configurations easier to read and maintain.

## Prerequisites
- Understanding of [[GKE Overview|Kubernetes resources]] (Deployments, Services, ConfigMaps)
- Familiarity with YAML syntax
- Basic knowledge of kubectl
- Understanding of multi-environment deployment patterns

## Key Concepts

### Base and Overlay Pattern
Kustomize organizes configurations into:

**Base**:
- Common configuration shared across all environments
- Contains core application manifests (Deployment, Service, etc.)
- Environment-agnostic settings
- Stored in a `base/` directory

**Overlays**:
- Environment-specific customizations (dev, staging, production)
- Patches that modify base resources
- Additional resources specific to an environment
- Stored in `overlays/<environment>/` directories

This separation enables DRY (Don't Repeat Yourself) principles while maintaining full visibility into what changes per environment.

### Kustomization File
Every Kustomize directory contains a `kustomization.yaml` file that declares:
- Resources to include (YAML files)
- Patches to apply
- ConfigMap and Secret generators
- Common labels, annotations, and name prefixes
- Image transformations

### Strategic Merge Patches
Kustomize uses strategic merge patches that understand Kubernetes resource semantics:
- Arrays can be merged or replaced based on strategy
- Doesn't require specifying the complete structure
- Null values remove fields
- More intuitive than JSON patches

### Transformers
Built-in transformations that Kustomize applies:
- **Name Prefix/Suffix**: Add prefixes/suffixes to resource names
- **Labels**: Add common labels to all resources
- **Annotations**: Add common annotations
- **Namespace**: Change the namespace of resources
- **Replicas**: Modify replica counts
- **Images**: Change container image names/tags

### ConfigMap and Secret Generators
Kustomize can generate ConfigMaps and Secrets from:
- Files
- Literal key-value pairs
- Environment files (.env)

Generated resources get a hash suffix in the name, enabling automatic rolling updates when content changes.

## How It Works

### Build and Apply Process
```bash
# Kustomize builds the final manifest
kustomize build overlays/production > final.yaml

# Or use kubectl directly (kubectl v1.14+)
kubectl apply -k overlays/production
```

**Process Flow**:
1. Kustomize reads `overlays/production/kustomization.yaml`
2. Loads base resources referenced in the overlay
3. Applies patches in order
4. Runs transformers (labels, namespaces, images)
5. Generates ConfigMaps/Secrets
6. Outputs final, merged YAML
7. kubectl applies the result to the cluster

### Patch Application Order
1. Strategic merge patches (`patchesStrategicMerge`)
2. JSON 6902 patches (`patchesJson6902`)
3. Built-in transformers (labels, replicas, etc.)

Understanding this order helps you predict the final configuration.

### How Kustomize Differs from Helm

**Kustomize**:
- Works with plain YAML (no templating syntax)
- Configuration is transparent and readable
- Built into kubectl
- Purely declarative
- No package management

**Helm**:
- Uses Go templates (adds syntax complexity)
- Package manager with charts repository
- Supports hooks and lifecycle management
- Can be harder to debug template logic
- Better for distributing applications

Kustomize excels when you own the manifests and need clear, maintainable configuration management across environments.

## Real-World Use Cases

### Use Case 1: Multi-Environment Web Application
**Scenario**: Deploy a web application to dev, staging, and production with different resource limits, replicas, and configurations.

**Directory Structure**:
```
app/
├── base/
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patches/
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patches/
    └── production/
        ├── kustomization.yaml
        └── patches/
```

**Benefits**: Single source of truth in base, clear visibility of environment differences, no duplication, easy to add new environments

### Use Case 2: Feature Branch Deployments
**Scenario**: Automatically deploy feature branches to temporary namespaces for testing without modifying existing configurations.

**Implementation**:
```yaml
# overlays/feature-branch/kustomization.yaml
namespace: feature-${BRANCH_NAME}
namePrefix: ${BRANCH_NAME}-
commonLabels:
  branch: ${BRANCH_NAME}
bases:
- ../../base
```

**CI/CD Pipeline**:
```bash
# Substitute environment variables and deploy
envsubst < overlays/feature-branch/kustomization.yaml | \
  kustomize build - | \
  kubectl apply -f -
```

**Benefits**: Isolated testing environments, automated cleanup, parallel feature testing

### Use Case 3: Configuration Drift Prevention
**Scenario**: Ensure all microservices follow consistent labeling, monitoring annotations, and security policies across the organization.

**Implementation**:
```yaml
# organization-standards/kustomization.yaml
commonLabels:
  managed-by: platform-team
  monitoring: enabled
commonAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"

# Each team imports these standards
# team-app/overlays/production/kustomization.yaml
bases:
- ../../../organization-standards
- ../../base
```

**Benefits**: Enforced standards, reduced configuration drift, centralized policy updates

## Hands-On Examples

### Example 1: Basic Base Configuration
```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

commonLabels:
  app: demo-app
```

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 1
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
        image: myapp:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
```

```yaml
# base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
spec:
  selector:
    app: demo-app
  ports:
  - port: 80
    targetPort: 8080
```

```bash
# View the generated configuration
kustomize build base/

# Apply to cluster
kubectl apply -k base/
```
**Explanation**: The base contains the minimal working configuration. `commonLabels` automatically adds the label to all resources and their selectors. This is the foundation that all overlays will build upon.

### Example 2: Production Overlay with Patches
```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

bases:
- ../../base

namePrefix: prod-

# Strategic merge patch
patchesStrategicMerge:
- patches/deployment-patch.yaml
- patches/service-patch.yaml

# Change image tag
images:
- name: myapp
  newTag: v1.2.3

# Add production-specific labels
commonLabels:
  environment: production
  team: backend

# Generate ConfigMap from file
configMapGenerator:
- name: app-config
  files:
  - config.properties
```

```yaml
# overlays/production/patches/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 5  # Override base replicas
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        env:
        - name: ENVIRONMENT
          value: "production"
```

```yaml
# overlays/production/patches/service-patch.yaml
apiVersion: v1
kind: Service
metadata:
  name: app-service
  annotations:
    cloud.google.com/load-balancer-type: "Internal"
spec:
  type: LoadBalancer
```

```bash
# Build and view final configuration
kustomize build overlays/production/

# Apply to production
kubectl apply -k overlays/production/
```
**Explanation**: The overlay references the base and applies modifications. The `namePrefix` makes all resources have `prod-` prefix. The `images` transformer changes the container image tag. Patches modify specific fields without duplicating the entire resource.

### Example 3: Development Overlay with Minimal Resources
```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: development

bases:
- ../../base

namePrefix: dev-

commonLabels:
  environment: dev

# Use latest image for dev
images:
- name: myapp
  newTag: latest

# JSON 6902 patch for precise modifications
patchesJson6902:
- target:
    group: apps
    version: v1
    kind: Deployment
    name: app
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/imagePullPolicy
      value: Always
    - op: add
      path: /spec/template/spec/containers/0/env/-
      value:
        name: DEBUG
        value: "true"

# Generate ConfigMap from literals
configMapGenerator:
- name: app-config
  literals:
  - LOG_LEVEL=debug
  - ENABLE_PROFILING=true
```

```bash
# Deploy to dev
kubectl apply -k overlays/dev/

# Quick iteration: modify and reapply
kubectl apply -k overlays/dev/
```
**Explanation**: Dev overlay keeps minimal replicas and resources for fast iteration. JSON 6902 patches provide precise control for complex modifications. ConfigMap literals are great for simple key-value pairs. The `latest` tag ensures dev always gets the newest code.

### Example 4: Components for Reusable Features
```yaml
# components/monitoring/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

commonAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"

patchesStrategicMerge:
- |-
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: not-important
  spec:
    template:
      spec:
        containers:
        - name: app
          ports:
          - name: metrics
            containerPort: 8080
```

```yaml
# overlays/production/kustomization.yaml
bases:
- ../../base

components:
- ../../components/monitoring  # Include monitoring setup

namespace: production
```

```bash
# Production gets monitoring, dev doesn't
kubectl apply -k overlays/production/
```
**Explanation**: Components are reusable pieces of configuration that can be optionally included in overlays. This example adds Prometheus monitoring annotations and a metrics port. Components help avoid duplication when some environments need certain features.

## Best Practices

- **Keep Base Minimal and Generic**: Base should contain only what's truly common across all environments. Don't include environment-specific defaults
- **One Resource Per File**: Makes patches easier to write and configurations easier to navigate. Name files descriptively: `deployment.yaml`, `service.yaml`
- **Use Strategic Merge for Simple Changes**: They're more readable than JSON patches. Reserve JSON 6902 for complex transformations
- **Leverage ConfigMap/Secret Generators**: Automatic hash suffixes trigger rolling updates when configuration changes, ensuring pods get updated configs
- **Document Patch Intent**: Add comments explaining why each patch exists, especially for non-obvious changes
- **Version Control Everything**: Commit both base and overlays. This creates an audit trail of configuration changes
- **Use Components for Optional Features**: Define reusable features (monitoring, security policies) as components that overlays can include
- **Validate Before Applying**: Always run `kustomize build` first to review generated output before `kubectl apply -k`
- **Organize by Environment**: Standard structure (`overlays/dev`, `overlays/staging`, `overlays/production`) makes navigation intuitive
- **Combine with GitOps**: Use with tools like ArgoCD or Flux for automated, Git-driven deployments
- **Use Image Transformers Over Patches**: `images:` transformer is cleaner than patching the entire container spec for image changes

## Common Pitfalls & Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| "no matches for Id" error | Resource referenced in patch doesn't exist | Verify resource name and kind match base exactly. Check `resources:` in kustomization.yaml |
| Strategic merge not working | Field uses replace instead of merge strategy | Use JSON 6902 patch for arrays like `containers` or fields with replace strategy |
| ConfigMap not updating | ConfigMap name hasn't changed | Use ConfigMap generator with hash suffix. Kustomize auto-generates unique names |
| Patches applying in wrong order | Multiple patches conflict | Combine patches into single file or use explicit JSON 6902 patches with precise paths |
| "invalid reference" error | Base path is incorrect | Use relative paths correctly. From overlay: `../../base` goes up two levels |
| Labels not applied everywhere | Resource not selected by label transformer | Ensure resource is listed in `resources:` and uses standard metadata structure |
| Can't patch arrays | Strategic merge doesn't support operation | Use `patchesJson6902` with explicit array operations (add, remove, replace) |
| Duplicate resources | Resource defined in both base and overlay | Remove from overlay if it's in base, or use patch to modify instead |
| Image tag not changing | Image name doesn't match | Ensure `images[].name` exactly matches `image:` in deployment (without tag) |
| Namespace not applied | Resource is cluster-scoped | Resources like ClusterRole can't have namespaces. Move to separate kustomization |

## Related Topics
- [[GKE Overview]] - Deploy Kustomize configurations to GKE clusters
- [[Kubernetes Services]] - Kustomize can patch service types and ports across environments
- [[GKE Gateway API]] - Manage Gateway and HTTPRoute configurations with Kustomize
- [[Kubernetes Health and Scaling]] - Customize replica counts and health check parameters per environment

## Further Learning
- [Kustomize Official Documentation](https://kustomize.io/) - Comprehensive guides and reference
- [Kubernetes Kustomize Guide](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) - Kubernetes official documentation
- [Kustomize Examples](https://github.com/kubernetes-sigs/kustomize/tree/master/examples) - Real-world examples and patterns
- [The Kustomize Book](https://kubectl.docs.kubernetes.io/guides/config_management/) - In-depth configuration management guide
- [GitOps with Kustomize](https://argoproj.github.io/argo-cd/user-guide/kustomize/) - Integrate Kustomize with ArgoCD

## Tags
#kubernetes #kustomize #configuration-management #gitops #infrastructure-as-code #devops
