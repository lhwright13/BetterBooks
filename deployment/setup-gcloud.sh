#!/bin/bash

# BetterBooks Google Cloud Setup Script

PROJECT_ID="betterbooks-prod"
REGION="us-central1"
CLUSTER_NAME="betterbooks-cluster"

echo "🚀 Setting up BetterBooks on Google Cloud..."

# 1. Create project (if it doesn't exist)
echo "📝 Creating/setting project..."
gcloud projects create $PROJECT_ID --name="BetterBooks Production" || true
gcloud config set project $PROJECT_ID

# 2. Enable required APIs
echo "🔧 Enabling APIs..."
gcloud services enable container.googleapis.com
gcloud services enable cloudsql.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable cloudkms.googleapis.com

# 3. Create GKE cluster
echo "🏗️ Creating Kubernetes cluster..."
gcloud container clusters create $CLUSTER_NAME \
    --region=$REGION \
    --num-nodes=2 \
    --machine-type=e2-standard-2 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5 \
    --enable-autorepair \
    --enable-autoupgrade

# 4. Get cluster credentials
echo "🔑 Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# 5. Create CloudSQL PostgreSQL instance
echo "🗄️ Creating PostgreSQL database..."
gcloud sql instances create betterbooks-db \
    --database-version=POSTGRES_15 \
    --tier=db-f1-micro \
    --region=$REGION \
    --storage-size=10GB \
    --storage-type=SSD

# 6. Create database and user
gcloud sql databases create betterbooks --instance=betterbooks-db
gcloud sql users create betterbooks --instance=betterbooks-db --password=securepassword123

# 7. Create storage bucket for audiobooks
echo "📦 Creating storage bucket..."
gsutil mb gs://$PROJECT_ID-audiobooks

# 8. Create secrets for sensitive data
echo "🔐 Creating secrets..."
kubectl create secret generic app-secrets \
    --from-literal=database-url="postgresql://betterbooks:securepassword123@localhost:5432/betterbooks" \
    --from-literal=gemini-api-key="YOUR_GEMINI_API_KEY_HERE"

echo "✅ Google Cloud setup complete!"
echo "Next steps:"
echo "1. Update GEMINI_API_KEY in the secret"
echo "2. Run the Helm deployment"