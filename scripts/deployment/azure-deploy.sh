#!/bin/bash

# Azure Deployment Script for BetterBooks
# This script builds and deploys all services to Azure Container Instances

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load Azure configuration
if [ ! -f .env.azure ]; then
    echo -e "${RED}Error: .env.azure file not found. Run azure-setup.sh first.${NC}"
    exit 1
fi

source .env.azure

echo -e "${GREEN}Starting deployment to Azure...${NC}"

# Login to ACR
echo -e "${YELLOW}Logging in to Azure Container Registry...${NC}"
az acr login --name ${ACR_LOGIN_SERVER%%.*}

# Build and push images
echo -e "${YELLOW}Building and pushing Docker images...${NC}"

# API Gateway
echo "Building API Gateway..."
docker build -t $ACR_LOGIN_SERVER/api-gateway:latest \
    -f platform/backend/services/api_gateway/Dockerfile \
    platform/backend/

docker push $ACR_LOGIN_SERVER/api-gateway:latest

# Context Service
echo "Building Context Service..."
docker build -t $ACR_LOGIN_SERVER/context-service:latest \
    -f platform/backend/services/context_service/Dockerfile \
    platform/backend/

docker push $ACR_LOGIN_SERVER/context-service:latest

# LLM Gateway
echo "Building LLM Gateway..."
docker build -t $ACR_LOGIN_SERVER/llm-gateway:latest \
    -f platform/backend/services/llm_gateway/Dockerfile \
    platform/backend/

docker push $ACR_LOGIN_SERVER/llm-gateway:latest

# TTS Service
echo "Building TTS Service..."
docker build -t $ACR_LOGIN_SERVER/tts-service:latest \
    -f platform/backend/services/tts_service/Dockerfile \
    platform/backend/

docker push $ACR_LOGIN_SERVER/tts-service:latest

# Transcription Service
echo "Building Transcription Service..."
docker build -t $ACR_LOGIN_SERVER/transcription-service:latest \
    -f platform/backend/services/transcription_service/Dockerfile \
    platform/backend/

docker push $ACR_LOGIN_SERVER/transcription-service:latest

# Get secrets from Key Vault
echo -e "${YELLOW}Retrieving secrets from Key Vault...${NC}"
GEMINI_API_KEY=$(az keyvault secret show \
    --vault-name $KEYVAULT_NAME \
    --name gemini-api-key \
    --query value \
    --output tsv 2>/dev/null || echo "")

if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}Warning: GEMINI_API_KEY not found in Key Vault${NC}"
    echo "Please add it with: az keyvault secret set --vault-name $KEYVAULT_NAME --name gemini-api-key --value YOUR_KEY"
fi

# Create container instances YAML
echo -e "${YELLOW}Creating container deployment configuration...${NC}"
cat > azure-container-instances.yaml << EOF
apiVersion: 2021-10-01
location: $AZURE_LOCATION
name: betterbooks-services
properties:
  osType: Linux
  restartPolicy: Always
  imageRegistryCredentials:
  - server: $ACR_LOGIN_SERVER
    username: $ACR_USERNAME
    password: $ACR_PASSWORD
  ipAddress:
    type: Public
    ports:
    - port: 8000
      protocol: TCP
    - port: 8001
      protocol: TCP
    - port: 8002
      protocol: TCP
    - port: 8003
      protocol: TCP
    - port: 8004
      protocol: TCP
    dnsNameLabel: betterbooks
  containers:
  - name: api-gateway
    properties:
      image: $ACR_LOGIN_SERVER/api-gateway:latest
      ports:
      - port: 8000
      resources:
        requests:
          cpu: 0.5
          memoryInGB: 1
      environmentVariables:
      - name: DATABASE_URL
        value: postgresql://${DATABASE_USER}:${DATABASE_PASSWORD}@${DATABASE_HOST}/${DATABASE_NAME}?sslmode=require
      - name: REDIS_URL
        value: $REDIS_URL
      - name: CONTEXT_SERVICE_URL
        value: http://localhost:8001
      - name: LLM_GATEWAY_URL
        value: http://localhost:8002
      - name: TTS_SERVICE_URL
        value: http://localhost:8004
      - name: TRANSCRIPTION_SERVICE_URL
        value: http://localhost:8003
      - name: APPLICATIONINSIGHTS_CONNECTION_STRING
        value: $APPLICATIONINSIGHTS_CONNECTION_STRING
  
  - name: context-service
    properties:
      image: $ACR_LOGIN_SERVER/context-service:latest
      ports:
      - port: 8001
      resources:
        requests:
          cpu: 0.5
          memoryInGB: 1
      environmentVariables:
      - name: DATABASE_URL
        value: postgresql://${DATABASE_USER}:${DATABASE_PASSWORD}@${DATABASE_HOST}/${DATABASE_NAME}?sslmode=require
      - name: REDIS_URL
        value: $REDIS_URL
      - name: APPLICATIONINSIGHTS_CONNECTION_STRING
        value: $APPLICATIONINSIGHTS_CONNECTION_STRING
  
  - name: llm-gateway
    properties:
      image: $ACR_LOGIN_SERVER/llm-gateway:latest
      ports:
      - port: 8002
      resources:
        requests:
          cpu: 0.5
          memoryInGB: 1
      environmentVariables:
      - name: GEMINI_API_KEY
        secureValue: $GEMINI_API_KEY
      - name: REDIS_URL
        value: $REDIS_URL
      - name: APPLICATIONINSIGHTS_CONNECTION_STRING
        value: $APPLICATIONINSIGHTS_CONNECTION_STRING
  
  - name: tts-service
    properties:
      image: $ACR_LOGIN_SERVER/tts-service:latest
      ports:
      - port: 8004
      resources:
        requests:
          cpu: 1
          memoryInGB: 2
      environmentVariables:
      - name: APPLICATIONINSIGHTS_CONNECTION_STRING
        value: $APPLICATIONINSIGHTS_CONNECTION_STRING
  
  - name: transcription-service
    properties:
      image: $ACR_LOGIN_SERVER/transcription-service:latest
      ports:
      - port: 8003
      resources:
        requests:
          cpu: 0.5
          memoryInGB: 1
      environmentVariables:
      - name: DATABASE_URL
        value: postgresql://${DATABASE_USER}:${DATABASE_PASSWORD}@${DATABASE_HOST}/${DATABASE_NAME}?sslmode=require
      - name: GEMINI_API_KEY
        secureValue: $GEMINI_API_KEY
      - name: APPLICATIONINSIGHTS_CONNECTION_STRING
        value: $APPLICATIONINSIGHTS_CONNECTION_STRING
EOF

# Deploy container instances
echo -e "${YELLOW}Deploying container instances...${NC}"
az container create \
    --resource-group $AZURE_RESOURCE_GROUP \
    --file azure-container-instances.yaml \
    --output table

# Wait for deployment
echo -e "${YELLOW}Waiting for deployment to complete...${NC}"
sleep 60

# Get container group details
CONTAINER_IP=$(az container show \
    --resource-group $AZURE_RESOURCE_GROUP \
    --name betterbooks-services \
    --query ipAddress.ip \
    --output tsv)

CONTAINER_FQDN=$(az container show \
    --resource-group $AZURE_RESOURCE_GROUP \
    --name betterbooks-services \
    --query ipAddress.fqdn \
    --output tsv)

# Upload audiobook files to blob storage
echo -e "${YELLOW}Uploading audiobook files to blob storage...${NC}"
if [ -d "book_files" ]; then
    az storage blob upload-batch \
        --account-name $STORAGE_ACCOUNT \
        --account-key $STORAGE_KEY \
        --destination audiobooks \
        --source book_files \
        --output table
fi

# Test services
echo -e "${YELLOW}Testing deployed services...${NC}"
echo "Testing API Gateway health..."
curl -s http://$CONTAINER_IP:8000/health || echo "API Gateway not ready yet"

echo "Testing Context Service health..."
curl -s http://$CONTAINER_IP:8001/health || echo "Context Service not ready yet"

echo "Testing LLM Gateway health..."
curl -s http://$CONTAINER_IP:8002/health || echo "LLM Gateway not ready yet"

# Update configuration files
echo -e "${YELLOW}Updating configuration files...${NC}"

# Update mobile app production config
cat > platform/mobile/mobile_app/lib/api_config_azure.dart << EOF
/// Azure Production Configuration for BetterBooks Mobile App
class ApiConfig {
  static const String baseUrl = 'http://$CONTAINER_FQDN:8000';
  static const String cdnUrl = '$BLOB_URL';
  
  static String getAudiobookUrl(String filename) {
    return '\$cdnUrl/audiobooks/\$filename';
  }
}
EOF

# Create deployment summary
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo ""
echo -e "${GREEN}Service URLs:${NC}"
echo "- API Gateway: http://$CONTAINER_FQDN:8000"
echo "- Context Service: http://$CONTAINER_FQDN:8001"
echo "- LLM Gateway: http://$CONTAINER_FQDN:8002"
echo "- TTS Service: http://$CONTAINER_FQDN:8004"
echo "- Transcription Service: http://$CONTAINER_FQDN:8003"
echo ""
echo -e "${GREEN}Storage URLs:${NC}"
echo "- Blob Storage: $BLOB_URL"
echo "- Audiobooks: $BLOB_URL/audiobooks"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update your mobile app to use: http://$CONTAINER_FQDN:8000"
echo "2. Configure custom domain if needed"
echo "3. Set up SSL/TLS with Application Gateway"
echo "4. Monitor services in Azure Portal"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "View logs: az container logs --resource-group $AZURE_RESOURCE_GROUP --name betterbooks-services --container-name api-gateway"
echo "Restart: az container restart --resource-group $AZURE_RESOURCE_GROUP --name betterbooks-services"
echo "Delete: az container delete --resource-group $AZURE_RESOURCE_GROUP --name betterbooks-services"