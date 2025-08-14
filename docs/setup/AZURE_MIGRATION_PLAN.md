# Azure Migration Plan for BetterBooks

## Executive Summary
This document outlines the complete migration strategy for moving BetterBooks from local/GCP to Microsoft Azure, utilizing $1000 in Azure credits efficiently.

## Current Architecture Analysis

### Microservices (5 total)
1. **API Gateway** (Port 8000)
   - FastAPI service
   - Routes requests to backend services
   - Handles authentication and rate limiting
   
2. **LLM Gateway** (Port 8002)
   - Wraps Google Gemini API
   - Manages AI personas
   - Includes semantic caching with Redis
   
3. **Context Service** (Port 8001)
   - Manages embeddings in PostgreSQL
   - Uses pgvector extension
   - Handles book context queries
   
4. **TTS Service** (Port 8004)
   - Text-to-speech using Coqui TTS
   - CPU-intensive workload
   
5. **Transcription Service** (Port 8003)
   - Chapter detection
   - Audio transcription
   - Integration with AssemblyAI/OpenAI APIs

### Data Layer
- **PostgreSQL with pgvector**: Vector embeddings storage
- **Redis**: Caching layer for LLM responses
- **PgBouncer**: Connection pooling
- **File Storage**: MP3 audiobooks and book covers

### Client Applications
- **Flutter Mobile App**: iOS and Android
- **Web App**: Static HTML/JS demo

## Azure Service Mapping

### Compute Strategy
**Option 1: Azure Container Instances (ACI)** - Recommended for initial migration
- Serverless containers
- Pay per second billing
- No cluster management
- Estimated: $100-150/month for all services

**Option 2: Azure Kubernetes Service (AKS)**
- Better for scale
- More complex setup
- Estimated: $150-200/month

### Database Strategy
**Azure Database for PostgreSQL - Flexible Server**
- Supports pgvector extension (verified)
- Built-in connection pooling (replaces PgBouncer)
- Configuration:
  - Burstable B2ms (2 vCores, 4GB RAM)
  - 32GB storage
  - Backup retention: 7 days
  - Estimated: $50-70/month

### Caching Strategy
**Azure Cache for Redis**
- Basic C1 tier (1GB cache)
- Sufficient for semantic caching
- Estimated: $30/month

### Storage Strategy
**Azure Blob Storage**
- Hot tier for audiobook files
- CDN integration for global delivery
- Estimated: $10-20/month for 50GB

### Networking & Security
**Azure Application Gateway**
- Layer 7 load balancer
- SSL termination
- WAF capabilities
- Path-based routing to containers
- Estimated: $20/month

**Azure Virtual Network**
- Private networking for services
- Network Security Groups
- Service endpoints for database

### Monitoring & Observability
**Azure Monitor + Application Insights**
- Distributed tracing
- Custom metrics
- Log aggregation
- Alerts
- Estimated: $10-20/month

## Implementation Plan

### Phase 1: Azure Setup (Day 1)
```bash
# 1. Create Resource Group
az group create --name betterbooks-rg --location eastus

# 2. Create Virtual Network
az network vnet create \
  --resource-group betterbooks-rg \
  --name betterbooks-vnet \
  --address-prefix 10.0.0.0/16 \
  --subnet-name default \
  --subnet-prefix 10.0.1.0/24

# 3. Create Azure Container Registry
az acr create \
  --resource-group betterbooks-rg \
  --name betterbooksacr \
  --sku Basic
```

### Phase 2: Database Migration (Day 2)
```bash
# 1. Create PostgreSQL Flexible Server
az postgres flexible-server create \
  --resource-group betterbooks-rg \
  --name betterbooks-db \
  --location eastus \
  --tier Burstable \
  --sku-name B2ms \
  --storage-size 32 \
  --version 15

# 2. Enable pgvector extension
az postgres flexible-server parameter set \
  --resource-group betterbooks-rg \
  --server-name betterbooks-db \
  --name azure.extensions \
  --value pgvector

# 3. Create Redis Cache
az redis create \
  --resource-group betterbooks-rg \
  --name betterbooks-cache \
  --location eastus \
  --sku Basic \
  --vm-size c1
```

### Phase 3: Container Deployment (Day 3)

#### Build and Push Images
```bash
# Login to ACR
az acr login --name betterbooksacr

# Build and push each service
docker build -t betterbooksacr.azurecr.io/api-gateway:v1 \
  -f platform/backend/services/api_gateway/Dockerfile .
docker push betterbooksacr.azurecr.io/api-gateway:v1

# Repeat for other services...
```

#### Deploy to Container Instances
```yaml
# azure-container-instances.yaml
apiVersion: 2021-10-01
location: eastus
name: betterbooks-services
properties:
  containers:
  - name: api-gateway
    properties:
      image: betterbooksacr.azurecr.io/api-gateway:v1
      ports:
      - port: 8000
      resources:
        requests:
          cpu: 0.5
          memoryInGB: 1
      environmentVariables:
      - name: DATABASE_URL
        value: postgresql://...
      - name: REDIS_URL
        value: redis://...
  
  - name: llm-gateway
    properties:
      image: betterbooksacr.azurecr.io/llm-gateway:v1
      ports:
      - port: 8002
      resources:
        requests:
          cpu: 0.5
          memoryInGB: 1
      environmentVariables:
      - name: GEMINI_API_KEY
        secureValue: ${GEMINI_API_KEY}
```

### Phase 4: Networking Setup (Day 4)

#### Application Gateway Configuration
```bash
# Create Application Gateway
az network application-gateway create \
  --resource-group betterbooks-rg \
  --name betterbooks-gateway \
  --location eastus \
  --sku Standard_v2 \
  --capacity 1 \
  --vnet-name betterbooks-vnet \
  --subnet gateway-subnet

# Configure routing rules
# /api/* -> API Gateway container
# /llm/* -> LLM Gateway container
# /context/* -> Context Service container
```

### Phase 5: Storage Migration (Day 5)
```bash
# Create Storage Account
az storage account create \
  --name betterbookstorage \
  --resource-group betterbooks-rg \
  --location eastus \
  --sku Standard_LRS

# Create container for audiobooks
az storage container create \
  --name audiobooks \
  --account-name betterbookstorage \
  --public-access blob

# Upload audiobook files
az storage blob upload-batch \
  --account-name betterbookstorage \
  --destination audiobooks \
  --source ./book_files
```

### Phase 6: Application Updates (Day 6)

#### Update Service Configurations
```python
# platform/backend/services/api_gateway/config.py
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://betterbooks:password@betterbooks-db.postgres.database.azure.com/betterbooks"
)

REDIS_URL = os.getenv(
    "REDIS_URL", 
    "redis://betterbooks-cache.redis.cache.windows.net:6379"
)

# Service URLs for internal communication
CONTEXT_SERVICE_URL = os.getenv("CONTEXT_SERVICE_URL", "http://localhost:8001")
LLM_GATEWAY_URL = os.getenv("LLM_GATEWAY_URL", "http://localhost:8002")
```

#### Update Mobile App Configuration
```dart
// platform/mobile/mobile_app/lib/api_config_prod.dart
class ApiConfig {
  static const String baseUrl = 'https://betterbooks.azurewebsites.net';
  static const String cdnUrl = 'https://betterbookstorage.blob.core.windows.net';
  
  static String getAudiobookUrl(String filename) {
    return '$cdnUrl/audiobooks/$filename';
  }
}
```

### Phase 7: CI/CD Pipeline (Day 7)

#### GitHub Actions Workflow
```yaml
# .github/workflows/azure-deploy.yml
name: Deploy to Azure

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Login to Azure
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Login to ACR
      uses: azure/docker-login@v1
      with:
        login-server: betterbooksacr.azurecr.io
        username: ${{ secrets.ACR_USERNAME }}
        password: ${{ secrets.ACR_PASSWORD }}
    
    - name: Build and Push Images
      run: |
        docker build -t betterbooksacr.azurecr.io/api-gateway:${{ github.sha }} \
          -f platform/backend/services/api_gateway/Dockerfile .
        docker push betterbooksacr.azurecr.io/api-gateway:${{ github.sha }}
    
    - name: Deploy to Container Instances
      uses: azure/aci-deploy@v1
      with:
        resource-group: betterbooks-rg
        dns-name-label: betterbooks
        image: betterbooksacr.azurecr.io/api-gateway:${{ github.sha }}
        location: eastus
```

## Cost Optimization Strategies

### Immediate Optimizations
1. **Use Spot Instances** for non-critical services (30-90% discount)
2. **Auto-shutdown** development environments during off-hours
3. **Right-size** containers based on actual usage metrics
4. **Enable autoscaling** with minimum instances

### Monthly Cost Breakdown (Estimated)
- Container Instances: $100-150
- PostgreSQL Database: $50-70
- Redis Cache: $30
- Application Gateway: $20
- Storage: $10-20
- Monitoring: $10-20
- **Total: $220-310/month**

### Cost Monitoring
```bash
# Set up cost alerts
az consumption budget create \
  --resource-group betterbooks-rg \
  --name monthly-budget \
  --amount 300 \
  --time-grain Monthly \
  --category Cost
```

## Security Considerations

### Network Security
- All services in private VNet
- Application Gateway as single entry point
- Network Security Groups on subnets
- Service endpoints for database access

### Secrets Management
```bash
# Create Key Vault
az keyvault create \
  --name betterbooks-kv \
  --resource-group betterbooks-rg \
  --location eastus

# Store secrets
az keyvault secret set \
  --vault-name betterbooks-kv \
  --name gemini-api-key \
  --value $GEMINI_API_KEY
```

### Authentication
- Managed identities for service-to-service auth
- Azure AD integration for admin access
- API key management through Key Vault

## Monitoring & Alerting

### Application Insights Setup
```bash
# Create Application Insights
az monitor app-insights component create \
  --app betterbooks-insights \
  --location eastus \
  --resource-group betterbooks-rg

# Configure in services
APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=..."
```

### Key Metrics to Monitor
1. **Service Health**
   - Container CPU/Memory usage
   - Response times
   - Error rates

2. **Database Performance**
   - Connection pool usage
   - Query performance
   - Storage usage

3. **Cost Tracking**
   - Daily spend
   - Service-wise breakdown
   - Forecast vs budget

## Rollback Strategy

### Database Rollback
1. PostgreSQL point-in-time restore
2. Maintain database snapshots before major changes

### Application Rollback
1. Container image versioning
2. Blue-green deployment support
3. Quick rollback via image swap

### Data Rollback
1. Blob storage versioning enabled
2. Soft delete for 7 days
3. Regular backups to secondary region

## Testing Strategy

### Pre-Migration Testing
```bash
# Local testing with Azure services
export DATABASE_URL="postgresql://betterbooks@betterbooks-db.postgres.database.azure.com/betterbooks"
export REDIS_URL="redis://betterbooks-cache.redis.cache.windows.net:6379"
docker-compose up
```

### Post-Migration Testing
1. Health check endpoints
2. End-to-end user flows
3. Performance benchmarks
4. Failover testing

## Migration Timeline

| Day | Phase | Tasks |
|-----|-------|-------|
| 1 | Setup | Create Azure resources, networking |
| 2 | Database | Migrate PostgreSQL, setup Redis |
| 3 | Containers | Build and deploy services |
| 4 | Networking | Configure Application Gateway |
| 5 | Storage | Migrate audiobook files |
| 6 | Applications | Update configurations |
| 7 | CI/CD | Setup deployment pipeline |
| 8 | Testing | End-to-end validation |
| 9 | DNS | Update DNS records |
| 10 | Monitoring | Configure alerts |

## Success Criteria

### Technical Metrics
- [ ] All services healthy (health checks passing)
- [ ] Response time < 200ms for API calls
- [ ] Database queries < 100ms
- [ ] 99.9% uptime achieved

### Business Metrics
- [ ] Mobile app connects successfully
- [ ] Web app loads properly
- [ ] Audio streaming works
- [ ] Chat functionality operational

### Cost Metrics
- [ ] Monthly spend < $300
- [ ] Cost alerts configured
- [ ] Optimization opportunities identified

## Next Steps

1. **Immediate Actions**
   - Create Azure account and redeem credits
   - Set up resource group and basic networking
   - Start database migration

2. **Week 1 Goals**
   - Complete infrastructure setup
   - Migrate all services
   - Basic testing complete

3. **Week 2 Goals**
   - Production cutover
   - Monitoring established
   - Documentation updated

## Appendix

### Azure CLI Installation
```bash
# macOS
brew install azure-cli

# Login
az login

# Set subscription
az account set --subscription "Your-Subscription-ID"
```

### Useful Commands
```bash
# View all resources
az resource list --resource-group betterbooks-rg

# Get container logs
az container logs --resource-group betterbooks-rg --name api-gateway

# Database connection string
az postgres flexible-server show-connection-string \
  --server-name betterbooks-db

# Monitor costs
az consumption usage list \
  --start-date 2025-01-01 \
  --end-date 2025-01-31
```

### Support Resources
- [Azure Container Instances Documentation](https://docs.microsoft.com/azure/container-instances/)
- [PostgreSQL Flexible Server](https://docs.microsoft.com/azure/postgresql/flexible-server/)
- [Azure Application Gateway](https://docs.microsoft.com/azure/application-gateway/)
- [Azure Cost Management](https://docs.microsoft.com/azure/cost-management-billing/)