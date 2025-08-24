#!/bin/bash

# EchoWright Docker Build and Push Script for Azure Container Registry

# Azure Container Registry configuration
REGISTRY="betterbooksacr.azurecr.io"

echo "🏗️ Building and pushing EchoWright Docker images to Azure Container Registry..."

# Configure Docker for Azure Container Registry
az acr login --name betterbooksacr

# Services to build
SERVICES=("api_gateway" "context_service" "llm_gateway" "tts_service" "transcription_service")

for service in "${SERVICES[@]}"
do
    echo "📦 Building $service..."
    
    # Build image with platform specification for Azure compatibility
    docker buildx build --platform linux/amd64 \
        -f "./platform/backend/services/$service/Dockerfile" \
        -t "$REGISTRY/$service:latest" \
        "." --push
    
    echo "✅ $service complete"
done

echo "🎉 All images built and pushed successfully!"
echo ""
echo "Images available at:"
for service in "${SERVICES[@]}"
do
    echo "  - $REGISTRY/$service:latest"
done