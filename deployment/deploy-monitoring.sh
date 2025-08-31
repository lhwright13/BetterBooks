#!/bin/bash

# EchoWright Monitoring Stack Deployment Script
# Deploys Prometheus and Grafana to Azure Kubernetes Cluster

set -e

echo "🔍 Deploying EchoWright Monitoring Stack to Azure..."

# Configuration
NAMESPACE="betterbooks"
PROMETHEUS_CHART_PATH="config/helm/infra/helm/prometheus"
GRAFANA_CHART_PATH="config/helm/infra/helm/grafana"

# Colors for output
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
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create namespace if it doesn't exist
create_namespace() {
    print_status "Ensuring namespace '$NAMESPACE' exists..."
    
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        kubectl create namespace $NAMESPACE
        print_success "Created namespace '$NAMESPACE'"
    else
        print_status "Namespace '$NAMESPACE' already exists"
    fi
}

# Deploy Prometheus
deploy_prometheus() {
    print_status "Deploying Prometheus..."
    
    helm upgrade --install prometheus \
        --namespace $NAMESPACE \
        --create-namespace \
        $PROMETHEUS_CHART_PATH \
        --timeout=5m
    
    if [ $? -eq 0 ]; then
        print_success "Prometheus deployed successfully"
    else
        print_error "Failed to deploy Prometheus"
        exit 1
    fi
}

# Deploy Grafana
deploy_grafana() {
    print_status "Deploying Grafana..."
    
    helm upgrade --install grafana \
        --namespace $NAMESPACE \
        --create-namespace \
        $GRAFANA_CHART_PATH \
        --timeout=5m
    
    if [ $? -eq 0 ]; then
        print_success "Grafana deployed successfully"
    else
        print_error "Failed to deploy Grafana"
        exit 1
    fi
}

# Wait for deployments to be ready
wait_for_deployments() {
    print_status "Waiting for deployments to be ready..."
    
    print_status "Waiting for Prometheus..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $NAMESPACE
    
    print_status "Waiting for Grafana..."
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n $NAMESPACE
    
    print_success "All deployments are ready"
}

# Get service information
get_service_info() {
    print_status "Getting service information..."
    
    echo
    echo "=== Monitoring Services ==="
    kubectl get services -n $NAMESPACE | grep -E "prometheus|grafana"
    
    echo
    print_status "Getting external IPs (may take a few minutes for LoadBalancer)..."
    
    # Get Prometheus external IP
    PROMETHEUS_IP=$(kubectl get service prometheus -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    PROMETHEUS_PORT=$(kubectl get service prometheus -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
    
    # Get Grafana external IP
    GRAFANA_IP=$(kubectl get service grafana -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    GRAFANA_PORT=$(kubectl get service grafana -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
    
    echo
    echo "=== Access Information ==="
    if [ "$PROMETHEUS_IP" != "pending" ] && [ ! -z "$PROMETHEUS_IP" ]; then
        print_success "Prometheus: http://$PROMETHEUS_IP:$PROMETHEUS_PORT"
    else
        print_warning "Prometheus IP pending - use port forwarding: kubectl port-forward -n $NAMESPACE svc/prometheus 9090:9090"
    fi
    
    if [ "$GRAFANA_IP" != "pending" ] && [ ! -z "$GRAFANA_IP" ]; then
        print_success "Grafana: http://$GRAFANA_IP:$GRAFANA_PORT"
        echo "           Username: admin"
        echo "           Password: echowright2025"
    else
        print_warning "Grafana IP pending - use port forwarding: kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
    fi
}

# Create port forwarding script
create_port_forward_script() {
    print_status "Creating port forwarding script..."
    
    cat > deployment/port-forward-monitoring.sh << 'EOF'
#!/bin/bash

# Port forward monitoring services for local access
echo "🚀 Starting port forwarding for monitoring services..."
echo "Prometheus will be available at: http://localhost:9090"
echo "Grafana will be available at: http://localhost:3000"
echo "  Username: admin"
echo "  Password: echowright2025"
echo
echo "Press Ctrl+C to stop port forwarding"

# Start port forwarding in background
kubectl port-forward -n betterbooks svc/prometheus 9090:9090 &
PROMETHEUS_PID=$!

kubectl port-forward -n betterbooks svc/grafana 3000:3000 &
GRAFANA_PID=$!

# Wait for interrupt
trap "kill $PROMETHEUS_PID $GRAFANA_PID; exit" INT
wait
EOF

    chmod +x deployment/port-forward-monitoring.sh
    print_success "Port forwarding script created at deployment/port-forward-monitoring.sh"
}

# Test connectivity
test_connectivity() {
    print_status "Testing service connectivity..."
    
    # Test if services are responding
    print_status "Testing Prometheus health endpoint..."
    if kubectl exec -n $NAMESPACE deployment/prometheus -- wget -q --spider http://localhost:9090/-/healthy; then
        print_success "Prometheus is healthy"
    else
        print_warning "Prometheus health check failed"
    fi
    
    print_status "Testing Grafana health endpoint..."
    if kubectl exec -n $NAMESPACE deployment/grafana -- wget -q --spider http://localhost:3000/api/health; then
        print_success "Grafana is healthy"
    else
        print_warning "Grafana health check failed"
    fi
}

# Show metrics endpoints
show_metrics_endpoints() {
    echo
    echo "=== Metrics Endpoints ==="
    echo "Your services should expose metrics at these endpoints:"
    echo "• API Gateway: http://api-gateway:8000/metrics"
    echo "• LLM Gateway: http://llm-gateway:8002/metrics"
    echo "• Context Service: http://context-service:8001/metrics"
    echo "• TTS Service: http://tts-service:8003/metrics"
    echo
    echo "Test an endpoint manually:"
    echo "kubectl exec -n $NAMESPACE -it deployment/api-gateway -- curl http://localhost:8000/metrics"
}

# Main deployment function
main() {
    echo "🔍 EchoWright Monitoring Stack Deployment"
    echo "========================================"
    
    check_prerequisites
    create_namespace
    deploy_prometheus
    deploy_grafana
    wait_for_deployments
    get_service_info
    create_port_forward_script
    test_connectivity
    show_metrics_endpoints
    
    echo
    print_success "🎉 Monitoring stack deployment completed!"
    echo
    echo "Next steps:"
    echo "1. Wait for external IPs to be assigned (check with: kubectl get svc -n $NAMESPACE)"
    echo "2. Or use port forwarding: ./deployment/port-forward-monitoring.sh"
    echo "3. Access Grafana and verify dashboards are loaded"
    echo "4. Check that Prometheus is scraping your service metrics"
    echo
    echo "Troubleshooting:"
    echo "• Check pods: kubectl get pods -n $NAMESPACE"
    echo "• Check logs: kubectl logs -n $NAMESPACE deployment/prometheus"
    echo "• Check logs: kubectl logs -n $NAMESPACE deployment/grafana"
}

# Run the main function
main "$@"