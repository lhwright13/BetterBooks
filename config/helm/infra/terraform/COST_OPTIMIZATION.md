# Azure Cost Optimization Strategy for BetterBooks

## Current Implementation Status

### ✅ Implemented

1. **Cluster Autoscaling**
   - System pool: 1-3 nodes (auto-scales based on demand)
   - Application pool: 2-5 nodes (auto-scales based on demand)
   - Spot pool: 0-3 nodes (scales down to zero when not needed)

2. **Spot Instances for Non-Critical Workloads**
   - Dedicated spot node pool configured
   - 70% cost savings compared to on-demand instances
   - Automatic fallback to regular nodes if spot instances are evicted
   - Configured with taints to ensure only tolerant workloads are scheduled

3. **Right-Sized Resource Requests and Limits**
   - All services have defined resource requests and limits
   - Using B-series burstable VMs for cost efficiency
   - System nodes: Standard_B2s (2 vCPUs, 4GB RAM)
   - App nodes: Standard_B2ms (2 vCPUs, 8GB RAM)
   - Spot nodes: Standard_B2s (2 vCPUs, 4GB RAM)

4. **Storage Optimization**
   - Using managed-premium SSDs only for database
   - Standard storage for less critical data
   - 30-day log retention policy

### ⏳ Planned/Recommended

1. **Azure Reserved Instances**
   - Purchase 1-year or 3-year reserved instances for predictable base load
   - Estimated savings: 40-60% for steady-state workloads
   - Recommendation: Reserve 2 app nodes and 1 system node

2. **Azure Hybrid Benefit**
   - If you have existing Windows Server or SQL Server licenses
   - Can save up to 40% on Windows VMs

## Cost Breakdown Estimates (Monthly)

### Current Setup (without optimizations)
- AKS Cluster Management: Free
- System Node Pool (1x B2s): ~$30
- App Node Pool (2x B2ms): ~$120
- PostgreSQL Flexible Server: ~$50
- Redis Cache (Basic): ~$16
- Storage Account: ~$20
- Log Analytics: ~$30
- **Total: ~$266/month**

### With Optimizations
- AKS Cluster Management: Free
- System Node Pool (1x B2s): ~$30
- App Node Pool (2x B2ms with RI): ~$72 (40% savings)
- Spot Instances (1x B2s): ~$9 (70% savings)
- PostgreSQL Flexible Server: ~$50
- Redis Cache (Basic): ~$16
- Storage Account: ~$20
- Log Analytics: ~$30
- **Total: ~$227/month (15% savings)**

### Additional Savings with Reserved Instances
- 1-year commitment: Additional 20-30% savings
- 3-year commitment: Additional 40-50% savings

## Implementation Guide

### 1. Deploy Spot Instance Workloads

To deploy workloads on spot instances, add tolerations to your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
spec:
  template:
    spec:
      tolerations:
      - key: "kubernetes.azure.com/scalesetpriority"
        operator: "Equal"
        value: "spot"
        effect: "NoSchedule"
      nodeSelector:
        "kubernetes.azure.com/scalesetpriority": "spot"
```

### 2. Purchase Reserved Instances

```bash
# Via Azure Portal
# 1. Go to Reservations
# 2. Select "Add"
# 3. Choose Virtual Machines
# 4. Select Standard_B2ms for app nodes
# 5. Choose 1 or 3 year term
# 6. Complete purchase

# Via Azure CLI
az reservations reservation-order purchase \
  --reservation-order-id <order-id> \
  --location "East US" \
  --sku Standard_B2ms \
  --quantity 2 \
  --term P1Y  # or P3Y for 3 years
```

### 3. Monitor Costs

```bash
# Install cost analysis extension
az extension add --name costmanagement

# View current month costs
az costmanagement query \
  --type "ActualCost" \
  --dataset-filter '{"and":[{"dimensions":{"name":"ResourceGroup","operator":"In","values":["betterbooks-rg"]}}]}' \
  --timeframe MonthToDate

# Set up budget alerts
az consumption budget create \
  --budget-name "betterbooks-monthly" \
  --resource-group betterbooks-rg \
  --amount 250 \
  --time-grain Monthly \
  --category Cost
```

### 4. Implement Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 1
  maxReplicas: 5
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
```

## Best Practices

1. **Regular Review**
   - Monthly cost analysis reviews
   - Quarterly resource utilization assessment
   - Annual reserved instance evaluation

2. **Tagging Strategy**
   - Consistent tagging for cost allocation
   - Environment tags (dev/staging/prod)
   - Owner/team tags for chargeback

3. **Development Environment**
   - Use smaller VM sizes for dev/test
   - Implement auto-shutdown for non-production
   - Consider Azure Dev/Test subscriptions (savings on Windows VMs)

4. **Monitoring and Alerts**
   - Set up budget alerts at 80% and 100%
   - Monitor spot instance eviction rates
   - Track autoscaling metrics

## Cost Optimization Checklist

- [x] Enable cluster autoscaling
- [x] Configure spot instance node pool
- [x] Set resource requests/limits on all pods
- [x] Use appropriate VM sizes
- [x] Configure log retention policies
- [ ] Purchase reserved instances for base load
- [ ] Implement horizontal pod autoscaling
- [ ] Set up cost alerts and budgets
- [ ] Review and optimize storage tiers
- [ ] Implement auto-shutdown for dev environments

## Tools and Resources

- **Azure Advisor**: Provides personalized cost optimization recommendations
- **Azure Cost Management**: Track and analyze spending
- **kubecost**: Open-source Kubernetes cost monitoring
- **Azure Pricing Calculator**: Estimate costs before deployment

## Contact

For questions about cost optimization strategies, contact the platform team.