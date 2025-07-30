#!/bin/bash

# BetterBooks Docker Build and Push Script

PROJECT_ID="betterbooks-prod"
REGISTRY="gcr.io/$PROJECT_ID"

echo "🏗️ Building and pushing BetterBooks Docker images..."

# Configure Docker for GCR
gcloud auth configure-docker

# Services to build
SERVICES=("api_gateway" "context_service" "llm_gateway" "tts_service" "transcription_service")

for service in "${SERVICES[@]}"
do
    echo "📦 Building $service..."
    
    # Build image
    docker build -t "$REGISTRY/$service:latest" "./services/$service/"
    
    # Push to registry
    echo "⬆️ Pushing $service..."
    docker push "$REGISTRY/$service:latest"
    
    echo "✅ $service complete"
done

echo "🎉 All images built and pushed successfully!"
echo ""
echo "Images available at:"
for service in "${SERVICES[@]}"
do
    echo "  - $REGISTRY/$service:latest"
done