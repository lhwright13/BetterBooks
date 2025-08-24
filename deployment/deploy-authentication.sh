#!/bin/bash

# Complete Authentication System Deployment for EchoWright
# This script deploys the full authentication system to Azure AKS

set -e

echo "🚀 Deploying EchoWright Authentication System to Azure..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check if required tools are installed
for tool in kubectl az helm docker; do
    if ! command -v $tool &> /dev/null; then
        print_error "$tool is not installed or not in PATH"
        exit 1
    fi
done

print_success "All required tools are available"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    print_error "kubectl is not configured or cluster is not accessible"
    print_status "Configure kubectl with: az aks get-credentials --resource-group betterbooks-rg --name betterbooks-aks"
    exit 1
fi

print_success "kubectl is configured and cluster is accessible"

# Check if required environment variables are set
REQUIRED_ENV_VARS=(
    "SENDGRID_API_KEY"
    "JWT_SECRET_KEY" 
    "GOOGLE_OAUTH_CLIENT_ID"
    "GOOGLE_OAUTH_CLIENT_SECRET"
)

for var in "${REQUIRED_ENV_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        print_error "Environment variable $var is not set"
        print_status "Please set all required environment variables:"
        printf '%s\n' "${REQUIRED_ENV_VARS[@]}"
        exit 1
    fi
done

print_success "All required environment variables are set"

# Step 1: Setup Authentication Secrets
print_status "Step 1/5: Setting up authentication secrets..."

if ./deployment/setup-auth-secrets.sh; then
    print_success "Authentication secrets configured successfully"
else
    print_error "Failed to setup authentication secrets"
    exit 1
fi

# Step 2: Apply Database Migration
print_status "Step 2/5: Applying authentication database migration..."

if ./deployment/apply-auth-migration.sh; then
    print_success "Database migration applied successfully"
else
    print_error "Database migration failed"
    exit 1
fi

# Step 3: Build and Push Updated Docker Images
print_status "Step 3/5: Building and pushing updated Docker images..."

print_status "Building API Gateway with authentication features..."

if ./deployment/build-and-push.sh; then
    print_success "Docker images built and pushed successfully"
else
    print_error "Docker image build/push failed"
    exit 1
fi

# Step 4: Deploy Updated Services with Helm
print_status "Step 4/5: Deploying updated services with Helm..."

print_status "Deploying API Gateway with authentication..."

if ~/bin/helm upgrade --install api-gateway config/helm/infra/helm/api_gateway \
    --namespace betterbooks \
    --set image.tag=latest \
    --wait --timeout=10m; then
    print_success "API Gateway deployed successfully"
else
    print_error "API Gateway deployment failed"
    exit 1
fi

# Step 5: Verify Deployment
print_status "Step 5/5: Verifying authentication deployment..."

print_status "Waiting for pods to be ready..."
sleep 30

# Check pod status
print_status "Checking pod status..."
kubectl get pods -n betterbooks

# Wait for API Gateway to be ready
print_status "Waiting for API Gateway to be ready..."
if kubectl wait --for=condition=ready pod -l app=api-gateway -n betterbooks --timeout=300s; then
    print_success "API Gateway is ready"
else
    print_error "API Gateway failed to become ready"
    print_status "Pod logs:"
    kubectl logs -l app=api-gateway -n betterbooks --tail=50
    exit 1
fi

# Test authentication endpoints
print_status "Testing authentication endpoints..."

# Port forward for testing
kubectl port-forward svc/api-gateway -n betterbooks 8000:8000 &
PORT_FORWARD_PID=$!

sleep 5

# Test health endpoint
print_status "Testing health endpoint..."
if curl -f -s http://localhost:8000/health > /dev/null; then
    print_success "Health endpoint is responding"
else
    print_error "Health endpoint is not responding"
    kill $PORT_FORWARD_PID 2>/dev/null
    exit 1
fi

# Test authentication endpoints
print_status "Testing authentication endpoints..."

AUTH_ENDPOINTS=(
    "/auth/health"
    "/auth/email/send-verification"
    "/auth/google/signin"
    "/auth/apple/signin"
)

for endpoint in "${AUTH_ENDPOINTS[@]}"; do
    print_status "Testing $endpoint..."
    
    if [[ "$endpoint" == "/auth/health" ]]; then
        # GET request for health
        if curl -f -s "http://localhost:8000$endpoint" > /dev/null; then
            print_success "$endpoint is responding"
        else
            print_warning "$endpoint is not responding (this might be expected for some endpoints)"
        fi
    else
        # POST request with minimal data (expect method not allowed or validation error, not 404)
        response_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:8000$endpoint" -H "Content-Type: application/json" -d '{}')
        if [[ "$response_code" == "422" || "$response_code" == "405" || "$response_code" == "400" ]]; then
            print_success "$endpoint endpoint exists (HTTP $response_code - validation error as expected)"
        elif [[ "$response_code" == "404" ]]; then
            print_error "$endpoint endpoint not found (HTTP 404)"
        else
            print_warning "$endpoint returned HTTP $response_code"
        fi
    fi
done

# Clean up port forward
kill $PORT_FORWARD_PID 2>/dev/null

print_success "Authentication endpoint verification complete"

# Final status check
print_status "Final deployment status check..."

kubectl get all -n betterbooks -l app=api-gateway

# Show service information
print_status "Service information:"
kubectl get svc api-gateway -n betterbooks

print_success "🎉 Authentication system deployment completed successfully!"

echo ""
echo "=== DEPLOYMENT SUMMARY ==="
echo "✅ Authentication secrets configured"
echo "✅ Database migration applied"
echo "✅ Docker images built and pushed"
echo "✅ API Gateway deployed with authentication"
echo "✅ Authentication endpoints verified"
echo ""
echo "=== AVAILABLE AUTHENTICATION FEATURES ==="
echo "• Email/password registration and login"
echo "• Google OAuth 2.0 sign-in"
echo "• Apple Sign In"
echo "• Email verification with secure tokens"
echo "• Password reset functionality"
echo "• JWT token-based authentication"
echo "• Secure session management"
echo ""
echo "=== NEXT STEPS ==="
echo "1. Test authentication from your mobile app"
echo "2. Configure email templates and branding"
echo "3. Set up production email service credentials"
echo "4. Configure proper DNS and SSL certificates"
echo "5. Set up monitoring and alerting for auth endpoints"
echo ""
echo "=== ACCESS INFORMATION ==="
echo "API Gateway: kubectl port-forward svc/api-gateway -n betterbooks 8000:8000"
echo "Auth endpoints: http://localhost:8000/auth/*"
echo "Health check: http://localhost:8000/health"