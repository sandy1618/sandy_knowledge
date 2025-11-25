# Cost Estimation

## Monthly Cost Breakdown

This document provides estimated costs for running the tutorial infrastructure on Google Cloud Platform.

**Region**: us-central1
**Cluster Type**: GKE Autopilot
**Estimated Total**: $50-100/month (varies with usage)

## Cost Components

### 1. GKE Autopilot Cluster

**Base Costs**:
- Pod vCPU: $0.00004456/vCPU-second ($1.16/vCPU-month)
- Pod Memory: $0.00000491/GB-second ($0.13/GB-month)

**Demo Application (2 Pods minimum)**:
```
Per Pod:
- CPU: 100m (0.1 vCPU) = $0.116/month
- Memory: 128Mi (0.125 GB) = $0.016/month
- Total per Pod: $0.132/month

Minimum (2 Pods): $0.264/month
Maximum (10 Pods): $1.32/month
Average (4 Pods): $0.528/month
```

**System Pods** (Autopilot managed):
- Estimated: $3-5/month
- Includes: kube-dns, metrics-server, etc.

**Total GKE Autopilot**: $4-7/month

### 2. Google Cloud Load Balancer

**Forwarding Rule**:
- 1 rule: $18/month (fixed cost)

**Data Processing** (per GB):
- Inbound: Free
- Outbound: $0.008-0.016/GB (depends on destination)

**Usage Examples**:
```
Light traffic (10 GB/month outbound):
  $18 + (10 × $0.008) = $18.08/month

Moderate traffic (100 GB/month outbound):
  $18 + (100 × $0.008) = $18.80/month

Heavy traffic (1000 GB/month outbound):
  $18 + (1000 × $0.008) = $26/month
```

**Total Load Balancer**: $18-30/month

### 3. Network Egress

**Pricing Tiers**:
- First 1 GB: Free
- 1 GB - 10 TB: $0.12/GB (to internet)
- Same zone: Free
- Same region: $0.01/GB

**Typical Demo Usage**: $1-5/month

### 4. Storage (Persistent Disks)

**Not used in this tutorial**, but if you add persistent storage:
- Standard PD: $0.04/GB-month
- SSD PD: $0.17/GB-month

### 5. Cloud Logging

**Free Tier**: 50 GB/month per project

**Overage Pricing**:
- $0.50/GB for logs ingestion

**Typical Demo Usage**: Within free tier ($0/month)

## Total Cost Summary

| Scenario | GKE Autopilot | Load Balancer | Egress | Total/Month |
|----------|---------------|---------------|--------|-------------|
| Idle (2 Pods) | $4 | $18 | $1 | **$23** |
| Light Traffic (2-4 Pods) | $5 | $20 | $2 | **$27** |
| Moderate Traffic (4-6 Pods) | $6 | $25 | $5 | **$36** |
| Heavy Traffic (6-10 Pods) | $7 | $30 | $10 | **$47** |

## Cost Optimization Strategies

### 1. Right-Size Resources

**Current Settings**:
```yaml
resources:
  requests:
    cpu: 100m      # Minimum guaranteed
    memory: 128Mi
  limits:
    cpu: 200m      # Maximum allowed
    memory: 256Mi
```

**Optimization**:
- Monitor actual usage: `kubectl top pods -n demo-app`
- Reduce requests if consistently underutilized
- Adjust limits to prevent waste

**Potential Savings**: 30-50% on GKE costs

### 2. Adjust HPA Settings

**Current Settings**:
```yaml
minReplicas: 2
maxReplicas: 10
targetCPU: 70%
```

**For Development**:
```yaml
minReplicas: 1      # Single Pod for dev
maxReplicas: 3      # Lower ceiling
targetCPU: 80%      # Higher threshold
```

**Potential Savings**: $1-3/month

### 3. Use Preemptible Nodes (Standard GKE only)

**Not applicable to Autopilot**, but for Standard GKE:
- 60-80% cost reduction on compute
- Pods may be evicted with 30-second notice
- Good for fault-tolerant workloads

### 4. Regional vs. Global Load Balancer

**Current**: Global Load Balancer
- Higher cost
- Multi-region support
- Global anycast IP

**Alternative**: Regional Load Balancer
- Lower cost (~30% cheaper)
- Single region only
- Good for regional applications

**Potential Savings**: $5-10/month

### 5. Scheduled Scaling

**Development/Testing**: Scale down outside business hours

**Script Example**:
```bash
# Scale down at night (save ~50% of compute)
0 22 * * * kubectl scale deployment demo-app --replicas=1 -n demo-app

# Scale up in morning
0 8 * * * kubectl scale deployment demo-app --replicas=2 -n demo-app
```

**Potential Savings**: $2-3/month

### 6. Clean Up Unused Resources

**Important**: Delete resources when not in use!

```bash
# Delete entire cluster when done
./scripts/99-cleanup.sh
```

**Savings**: 100% of costs!

## Cost Monitoring

### 1. Enable Billing Alerts

**Setup**:
1. Cloud Console → Billing → Budgets & alerts
2. Create budget: $50/month
3. Set alerts: 50%, 90%, 100%

### 2. Use Cost Breakdown

**Cloud Console**:
- Billing → Reports
- Filter by: GKE, Load Balancing, Network

### 3. GKE Cost Breakdown

**View in GKE Console**:
```
Kubernetes Engine → Clusters → demo-cluster → Cost breakdown
```

Shows:
- Per-namespace costs
- Per-workload costs
- Resource utilization

### 4. Command-Line Monitoring

**View resource usage**:
```bash
# Pod resource usage
kubectl top pods -n demo-app

# Node resource usage (Autopilot)
kubectl top nodes

# HPA status
kubectl get hpa -n demo-app
```

## Cost Comparison: GKE Autopilot vs. Standard

| Feature | Autopilot | Standard GKE |
|---------|-----------|--------------|
| Pricing Model | Per-Pod resources | Per-node (VM) |
| Minimum Cost | ~$4/month | ~$70/month (1 node) |
| Management | Fully managed | Manual node management |
| Scaling | Automatic | Manual node pools |
| Best For | Small/medium workloads | Large/specialized workloads |

**For this tutorial**: Autopilot is more cost-effective

## Free Tier / Credits

### Google Cloud Free Trial
- $300 credit for new accounts
- 90 days duration
- **Covers this tutorial for 3+ months**

### Always Free Tier
- Not applicable to GKE or Load Balancer
- Applies to: Cloud Storage, BigQuery, Cloud Functions

### Educational Grants
- Google Cloud for Students: $50-300 credits
- Check: [Google Cloud for Education](https://cloud.google.com/edu)

## Cost Estimation Tools

### 1. Google Cloud Pricing Calculator
**URL**: https://cloud.google.com/products/calculator

**Input for this tutorial**:
- GKE Autopilot: 4 Pods, 0.1 vCPU, 128Mi memory
- Load Balancing: 1 forwarding rule, 100 GB egress
- Region: us-central1

### 2. In-Console Estimator
- GKE Console → Create cluster → Cost estimate

### 3. GKE Cost Optimization Insights
- Automatically suggests cost savings
- Available in GKE Console

## Production Cost Considerations

### Scaling Up
If you scale this to production:

**Small Production** (10-20 Pods):
- GKE: $10-15/month
- Load Balancer: $25-35/month
- Total: **$35-50/month**

**Medium Production** (50-100 Pods):
- GKE: $50-80/month
- Load Balancer: $35-50/month
- Total: **$85-130/month**

**Large Production** (100+ Pods):
- Consider Standard GKE with committed use discounts
- Multi-region setup: 2-3x cost
- Add: Cloud Armor, Cloud CDN, etc.
- Total: **$500-5000+/month**

## Related Topics

- [[GKE Overview]] - GKE pricing models
- [[Architecture]] - System design affecting costs
- [[GKE Gateway API]] - Load balancer alternatives

## Further Reading

- [GKE Autopilot Pricing](https://cloud.google.com/kubernetes-engine/pricing#autopilot_mode)
- [Cloud Load Balancing Pricing](https://cloud.google.com/vpc/network-pricing#lb)
- [GKE Cost Optimization Guide](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke)

#gke #cost-optimization #pricing #budget

---

**Last Updated**: 2025-11
**Pricing Subject to Change**: Check official GCP pricing for current rates
