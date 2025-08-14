#!/bin/bash

# Azure Setup Script for BetterBooks
# This script provisions all required Azure resources for the BetterBooks platform

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="betterbooks-rg"
LOCATION="eastus"
ACR_NAME="betterbooksacr"
DB_NAME="betterbooks-db"
CACHE_NAME="betterbooks-cache"
STORAGE_NAME="betterbookstorage"
VNET_NAME="betterbooks-vnet"
KEYVAULT_NAME="betterbooks-kv"
APPINSIGHTS_NAME="betterbooks-insights"

echo -e "${GREEN}Starting Azure setup for BetterBooks...${NC}"

# Check if logged in to Azure
echo -e "${YELLOW}Checking Azure login status...${NC}"
if ! az account show &>/dev/null; then
    echo -e "${RED}Not logged in to Azure. Please run 'az login' first.${NC}"
    exit 1
fi

# Get current subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN}Using subscription: $SUBSCRIPTION${NC}"

# Create Resource Group
echo -e "${YELLOW}Creating resource group...${NC}"
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --output table

# Create Virtual Network
echo -e "${YELLOW}Creating virtual network...${NC}"
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix 10.0.0.0/16 \
    --subnet-name default \
    --subnet-prefix 10.0.1.0/24 \
    --output table

# Create subnet for Application Gateway
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name gateway-subnet \
    --address-prefix 10.0.2.0/24 \
    --output table

# Create Azure Container Registry
echo -e "${YELLOW}Creating container registry...${NC}"
az acr create \
    --resource-group $RESOURCE_GROUP \
    --name $ACR_NAME \
    --sku Basic \
    --admin-enabled true \
    --output table

# Create PostgreSQL Flexible Server
echo -e "${YELLOW}Creating PostgreSQL database...${NC}"
echo -e "${YELLOW}Note: You'll be prompted to set an admin password${NC}"
az postgres flexible-server create \
    --resource-group $RESOURCE_GROUP \
    --name $DB_NAME \
    --location $LOCATION \
    --tier Burstable \
    --sku-name B2ms \
    --storage-size 32 \
    --version 15 \
    --public-access 0.0.0.0 \
    --output table

# Wait for database to be ready
echo -e "${YELLOW}Waiting for database to be ready...${NC}"
sleep 30

# Enable pgvector extension
echo -e "${YELLOW}Enabling pgvector extension...${NC}"
az postgres flexible-server parameter set \
    --resource-group $RESOURCE_GROUP \
    --server-name $DB_NAME \
    --name azure.extensions \
    --value pgvector \
    --output table

# Create database
az postgres flexible-server db create \
    --resource-group $RESOURCE_GROUP \
    --server-name $DB_NAME \
    --database-name betterbooks \
    --output table

# Create Redis Cache
echo -e "${YELLOW}Creating Redis cache...${NC}"
az redis create \
    --resource-group $RESOURCE_GROUP \
    --name $CACHE_NAME \
    --location $LOCATION \
    --sku Basic \
    --vm-size c1 \
    --output table

# Create Storage Account
echo -e "${YELLOW}Creating storage account...${NC}"
az storage account create \
    --name $STORAGE_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --kind StorageV2 \
    --output table

# Get storage key
STORAGE_KEY=$(az storage account keys list \
    --resource-group $RESOURCE_GROUP \
    --account-name $STORAGE_NAME \
    --query '[0].value' \
    --output tsv)

# Create blob container for audiobooks
echo -e "${YELLOW}Creating blob container for audiobooks...${NC}"
az storage container create \
    --name audiobooks \
    --account-name $STORAGE_NAME \
    --account-key $STORAGE_KEY \
    --public-access blob \
    --output table

# Create Key Vault
echo -e "${YELLOW}Creating Key Vault...${NC}"
az keyvault create \
    --name $KEYVAULT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --enable-rbac-authorization false \
    --output table

# Create Application Insights
echo -e "${YELLOW}Creating Application Insights...${NC}"
az monitor app-insights component create \
    --app $APPINSIGHTS_NAME \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP \
    --application-type web \
    --output table

# Get connection strings and keys
echo -e "${GREEN}Retrieving connection information...${NC}"

# Get ACR credentials
ACR_USERNAME=$(az acr credential show \
    --name $ACR_NAME \
    --query username \
    --output tsv)

ACR_PASSWORD=$(az acr credential show \
    --name $ACR_NAME \
    --query passwords[0].value \
    --output tsv)

# Get PostgreSQL connection string
DB_HOST=$(az postgres flexible-server show \
    --resource-group $RESOURCE_GROUP \
    --name $DB_NAME \
    --query fullyQualifiedDomainName \
    --output tsv)

# Get Redis connection info
REDIS_HOST=$(az redis show \
    --resource-group $RESOURCE_GROUP \
    --name $CACHE_NAME \
    --query hostName \
    --output tsv)

REDIS_KEY=$(az redis list-keys \
    --resource-group $RESOURCE_GROUP \
    --name $CACHE_NAME \
    --query primaryKey \
    --output tsv)

# Get Application Insights key
APPINSIGHTS_KEY=$(az monitor app-insights component show \
    --app $APPINSIGHTS_NAME \
    --resource-group $RESOURCE_GROUP \
    --query instrumentationKey \
    --output tsv)

# Create .env.azure file
echo -e "${YELLOW}Creating .env.azure configuration file...${NC}"
cat > .env.azure << EOF
# Azure Configuration for BetterBooks
# Generated on $(date)

# Resource Group
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
AZURE_LOCATION=$LOCATION

# Container Registry
ACR_LOGIN_SERVER=$ACR_NAME.azurecr.io
ACR_USERNAME=$ACR_USERNAME
ACR_PASSWORD=$ACR_PASSWORD

# Database
DATABASE_HOST=$DB_HOST
DATABASE_PORT=5432
DATABASE_NAME=betterbooks
DATABASE_USER=betterbooks
# Set DATABASE_PASSWORD to the password you created

# Redis Cache
REDIS_HOST=$REDIS_HOST
REDIS_PORT=6379
REDIS_KEY=$REDIS_KEY
REDIS_URL=redis://:${REDIS_KEY}@${REDIS_HOST}:6379/0

# Storage
STORAGE_ACCOUNT=$STORAGE_NAME
STORAGE_KEY=$STORAGE_KEY
STORAGE_CONTAINER=audiobooks
BLOB_URL=https://${STORAGE_NAME}.blob.core.windows.net

# Key Vault
KEYVAULT_NAME=$KEYVAULT_NAME

# Application Insights
APPINSIGHTS_KEY=$APPINSIGHTS_KEY
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=$APPINSIGHTS_KEY

# Service URLs (update after container deployment)
API_GATEWAY_URL=http://localhost:8000
CONTEXT_SERVICE_URL=http://localhost:8001
LLM_GATEWAY_URL=http://localhost:8002
TTS_SERVICE_URL=http://localhost:8004
EOF

echo -e "${GREEN}Azure resources created successfully!${NC}"
echo ""
echo -e "${YELLOW}Important next steps:${NC}"
echo "1. Update DATABASE_PASSWORD in .env.azure with the password you set"
echo "2. Add your GEMINI_API_KEY to Azure Key Vault:"
echo "   az keyvault secret set --vault-name $KEYVAULT_NAME --name gemini-api-key --value YOUR_KEY"
echo "3. Review the generated .env.azure file"
echo "4. Run the build and deploy script: ./scripts/deployment/azure-deploy.sh"
echo ""
echo -e "${GREEN}Resource Summary:${NC}"
echo "- Resource Group: $RESOURCE_GROUP"
echo "- Container Registry: $ACR_NAME.azurecr.io"
echo "- Database: $DB_HOST"
echo "- Redis Cache: $REDIS_HOST"
echo "- Storage: $STORAGE_NAME.blob.core.windows.net"
echo "- Key Vault: $KEYVAULT_NAME"
echo "- App Insights: $APPINSIGHTS_NAME"