# Azure Kubernetes Service (AKS) Configuration

This directory contains Kubernetes manifests configured for deployment to Azure Kubernetes Service (AKS).

## Files Overview

### api-gateway-simple.yaml
- **Purpose**: Deploys the API Gateway service
- **Azure Changes**:
  - Image registry changed from GCR to Azure Container Registry (ACR): `betterbooks.azurecr.io`
  - Added resource limits and requests for better resource management
  - Service type: LoadBalancer (can be changed to ClusterIP if using Ingress)

### ingress.yaml
- **Purpose**: Configures ingress routing via Azure Application Gateway
- **Azure Changes**:
  - Ingress class: `azure/application-gateway`
  - Added Application Gateway specific annotations for health probes and timeouts
  - Backend protocol set to HTTP

### postgres.yaml
- **Purpose**: Deploys PostgreSQL with pgvector extension
- **Azure Changes**:
  - Changed from `emptyDir` to `PersistentVolumeClaim` for data persistence
  - Uses Azure `managed-premium` storage class (SSD)
  - Added 10Gi persistent volume
  - Added resource limits and requests
  - Added `subPath` to prevent permission issues

## Deployment Steps

### Prerequisites
1. Azure Kubernetes Service (AKS) cluster
2. Azure Container Registry (ACR)
3. Application Gateway Ingress Controller (AGIC) installed

### Deploy to AKS

1. **Create namespace** (if needed):
```bash
kubectl create namespace betterbooks
```

2. **Deploy PostgreSQL**:
```bash
kubectl apply -f postgres.yaml -n betterbooks
```

3. **Deploy API Gateway**:
```bash
kubectl apply -f api-gateway-simple.yaml -n betterbooks
```

4. **Configure Ingress** (if using Application Gateway):
```bash
kubectl apply -f ingress.yaml -n betterbooks
```

## Storage Classes

Azure provides several storage classes:
- `managed-premium`: Premium SSD (recommended for production databases)
- `managed`: Standard SSD
- `azurefile`: Azure Files (for shared storage)
- `azurefile-premium`: Premium Azure Files

## Monitoring

Use Azure Monitor and Container Insights to monitor:
- Pod metrics (CPU, memory)
- Application logs
- Health probe status
- Ingress metrics

## Security Considerations

1. **Secrets Management**: Use Azure Key Vault with CSI driver for secrets
2. **Network Policies**: Implement Kubernetes NetworkPolicies
3. **Pod Security**: Use Pod Security Standards
4. **RBAC**: Configure proper role-based access control

## Troubleshooting

### Check Application Gateway health probes:
```bash
kubectl describe ingress betterbooks-ingress -n betterbooks
```

### View pod logs:
```bash
kubectl logs -l app=api-gateway -n betterbooks
```

### Check PVC status:
```bash
kubectl get pvc -n betterbooks
```

## Cost Optimization

1. Use spot instances for non-critical workloads
2. Enable cluster autoscaler
3. Right-size resource requests and limits
4. Use Azure Reserved Instances for predictable workloads