#!/bin/bash

# Setup Authentication Secrets for EchoWright Deployment
# This script creates Kubernetes secrets for authentication services

set -e

echo "🔐 Setting up authentication secrets for EchoWright..."

# Check if required environment variables are set
REQUIRED_VARS=(
    "SENDGRID_API_KEY"
    "JWT_SECRET_KEY"
    "GOOGLE_OAUTH_CLIENT_ID"
    "GOOGLE_OAUTH_CLIENT_SECRET"
)

OPTIONAL_VARS=(
    "AWS_SES_ACCESS_KEY_ID"
    "AWS_SES_SECRET_ACCESS_KEY"
    "AWS_SES_REGION"
    "APPLE_OAUTH_TEAM_ID"
    "APPLE_OAUTH_KEY_ID"
)

# Check required variables
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "❌ Error: $var environment variable is not set"
        echo "Please set all required environment variables:"
        printf '%s\n' "${REQUIRED_VARS[@]}"
        exit 1
    fi
done

echo "✅ All required environment variables are set"

# Set defaults for optional variables
AWS_SES_ACCESS_KEY_ID=${AWS_SES_ACCESS_KEY_ID:-"not-configured"}
AWS_SES_SECRET_ACCESS_KEY=${AWS_SES_SECRET_ACCESS_KEY:-"not-configured"}
AWS_SES_REGION=${AWS_SES_REGION:-"us-east-1"}
APPLE_OAUTH_TEAM_ID=${APPLE_OAUTH_TEAM_ID:-"not-configured"}
APPLE_OAUTH_KEY_ID=${APPLE_OAUTH_KEY_ID:-"not-configured"}

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: kubectl is not configured or cluster is not accessible"
    echo "Please configure kubectl to connect to your AKS cluster:"
    echo "  az aks get-credentials --resource-group betterbooks-rg --name betterbooks-aks"
    exit 1
fi

echo "✅ kubectl is configured and cluster is accessible"

# Create namespace if it doesn't exist
kubectl create namespace betterbooks --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Namespace 'betterbooks' is ready"

# Delete existing auth-secrets if it exists (to update)
kubectl delete secret auth-secrets -n betterbooks --ignore-not-found

# Create the auth secrets
echo "🔑 Creating authentication secrets..."

kubectl create secret generic auth-secrets \
    --from-literal=sendgrid-api-key="$SENDGRID_API_KEY" \
    --from-literal=aws-ses-access-key-id="$AWS_SES_ACCESS_KEY_ID" \
    --from-literal=aws-ses-secret-access-key="$AWS_SES_SECRET_ACCESS_KEY" \
    --from-literal=aws-ses-region="$AWS_SES_REGION" \
    --from-literal=google-oauth-client-id="$GOOGLE_OAUTH_CLIENT_ID" \
    --from-literal=google-oauth-client-secret="$GOOGLE_OAUTH_CLIENT_SECRET" \
    --from-literal=apple-oauth-team-id="$APPLE_OAUTH_TEAM_ID" \
    --from-literal=apple-oauth-key-id="$APPLE_OAUTH_KEY_ID" \
    --namespace betterbooks

echo "✅ Authentication secrets created successfully"

# Update JWT secret in app-secrets if needed
echo "🔑 Updating JWT secret in app-secrets..."

# Check if app-secrets exists
if kubectl get secret app-secrets -n betterbooks &> /dev/null; then
    # Update existing secret
    kubectl patch secret app-secrets -n betterbooks --patch="{\"data\":{\"jwt-secret-key\":\"$(echo -n $JWT_SECRET_KEY | base64)\"}}"
    echo "✅ JWT secret updated in existing app-secrets"
else
    # Create new app-secrets with JWT secret
    kubectl create secret generic app-secrets \
        --from-literal=jwt-secret-key="$JWT_SECRET_KEY" \
        --from-literal=gemini-api-key="${GEMINI_API_KEY:-not-configured}" \
        --namespace betterbooks
    echo "✅ Created new app-secrets with JWT secret"
fi

# Verify secrets were created
echo "🔍 Verifying secrets..."

if kubectl get secret auth-secrets -n betterbooks &> /dev/null; then
    echo "✅ auth-secrets created successfully"
    kubectl describe secret auth-secrets -n betterbooks | grep "Data" -A 10
else
    echo "❌ Failed to create auth-secrets"
    exit 1
fi

if kubectl get secret app-secrets -n betterbooks &> /dev/null; then
    echo "✅ app-secrets verified successfully"
    kubectl describe secret app-secrets -n betterbooks | grep "Data" -A 10
else
    echo "❌ app-secrets not found"
    exit 1
fi

echo ""
echo "🎉 Authentication secrets setup complete!"
echo ""
echo "Next steps:"
echo "1. Build and push updated Docker images:"
echo "   ./deployment/build-and-push.sh"
echo ""
echo "2. Deploy updated API Gateway:"
echo "   helm upgrade api-gateway config/helm/infra/helm/api_gateway --namespace betterbooks"
echo ""
echo "3. Apply database migration for email verification:"
echo "   kubectl exec -it deployment/postgres -n betterbooks -- psql -U betterbooks -d betterbooks -f /path/to/migration.sql"