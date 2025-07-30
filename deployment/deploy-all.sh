#!/bin/bash

# BetterBooks Complete Deployment Script

echo "🚀 Starting BetterBooks complete deployment..."

# Set variables
PROJECT_ID="betterbooks-prod"
CLUSTER_NAME="betterbooks-cluster"
REGION="us-central1"

# Check prerequisites
echo "🔍 Checking prerequisites..."
command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud CLI required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm required"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ docker required"; exit 1; }

echo "✅ Prerequisites check passed"

# Step 1: Setup Google Cloud
echo ""
echo "📋 Step 1: Setting up Google Cloud..."
read -p "Run Google Cloud setup? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./deployment/setup-gcloud.sh
fi

# Step 2: Build and push Docker images
echo ""
echo "📋 Step 2: Building and pushing Docker images..."
read -p "Build and push Docker images? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./deployment/build-and-push.sh
fi

# Step 3: Deploy with Helm
echo ""
echo "📋 Step 3: Deploying with Helm..."
read -p "Deploy services with Helm? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Updating Helm dependencies..."
    cd infra/helm/betterbooks
    helm dependency update
    
    echo "Installing BetterBooks..."
    helm install betterbooks . --values values.yaml
    
    cd ../../..
fi

# Step 4: Check deployment status
echo ""
echo "📋 Step 4: Checking deployment status..."
kubectl get pods
kubectl get services
kubectl get ingress

# Step 5: Mobile app build
echo ""
echo "📋 Step 5: Building mobile app..."
read -p "Build mobile app for TestFlight? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./deployment/testflight-build.sh
fi

echo ""
echo "🎉 Deployment script complete!"
echo ""
echo "Next manual steps:"
echo "1. Update Gemini API key in Kubernetes secret"
echo "2. Configure domain DNS to point to load balancer IP"
echo "3. Upload IPA to App Store Connect"
echo "4. Submit for TestFlight review"
echo ""
echo "For detailed instructions, see: DEPLOYMENT_CHECKLIST.md"