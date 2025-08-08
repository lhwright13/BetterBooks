#!/bin/bash
# Test script to verify metrics endpoints are working
# Run this after starting services with: docker-compose up --build

echo "=================================="
echo "TESTING METRICS ENDPOINTS"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test an endpoint
test_endpoint() {
    local service=$1
    local port=$2
    local endpoint=$3
    local description=$4
    
    echo -n "Testing $description ($service:$port$endpoint)... "
    
    if curl -s -f "http://localhost:$port$endpoint" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Function to test metrics content
test_metrics_content() {
    local service=$1
    local port=$2
    local metric_name=$3
    
    echo -n "Checking for $metric_name in $service metrics... "
    
    content=$(curl -s "http://localhost:$port/metrics" 2>/dev/null)
    if echo "$content" | grep -q "$metric_name"; then
        echo -e "${GREEN}✅ FOUND${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  NOT FOUND${NC}"
        return 1
    fi
}

# Wait for services to start
echo "Waiting 10 seconds for services to start..."
sleep 10

echo ""
echo "Testing basic health endpoints..."
test_endpoint "API Gateway" 8000 "/health" "API Gateway health"
test_endpoint "LLM Gateway" 8002 "/health" "LLM Gateway health"
test_endpoint "Context Service" 8001 "/health" "Context Service health"
test_endpoint "TTS Service" 8003 "/health" "TTS Service health"

echo ""
echo "Testing detailed health endpoints..."
test_endpoint "API Gateway" 8000 "/health/detailed" "API Gateway detailed health"

echo ""
echo "Testing metrics endpoints..."
test_endpoint "API Gateway" 8000 "/metrics" "API Gateway metrics"
test_endpoint "LLM Gateway" 8002 "/metrics" "LLM Gateway metrics"
test_endpoint "Context Service" 8001 "/metrics" "Context Service metrics"
test_endpoint "TTS Service" 8003 "/metrics" "TTS Service metrics"

echo ""
echo "Testing Prometheus and Grafana..."
test_endpoint "Prometheus" 9090 "/" "Prometheus web interface"
test_endpoint "Grafana" 3000 "/" "Grafana web interface"

echo ""
echo "Testing metrics content..."
test_metrics_content "API Gateway" 8000 "http_requests_total"
test_metrics_content "API Gateway" 8000 "llm_requests_total"
test_metrics_content "LLM Gateway" 8002 "http_requests_total"

echo ""
echo "Testing Prometheus targets..."
echo -n "Checking Prometheus targets... "
targets_response=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null)
if echo "$targets_response" | grep -q '"health":"up"'; then
    echo -e "${GREEN}✅ Some targets are UP${NC}"
else
    echo -e "${YELLOW}⚠️  No targets UP yet${NC}"
fi

echo ""
echo "=================================="
echo "GENERATING SAMPLE METRICS DATA"
echo "=================================="

echo "Making some API calls to generate metrics data..."

# Make some API calls to generate data
curl -s -X POST "http://localhost:8000/complete" \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Hello, world!", "config": null}' > /dev/null 2>&1
echo "✅ Made completion request"

curl -s -X POST "http://localhost:8000/tts" \
     -H "Content-Type: application/json" \
     -d '{"text": "Hello, world!"}' > /dev/null 2>&1
echo "✅ Made TTS request"

curl -s "http://localhost:8000/health" > /dev/null 2>&1
curl -s "http://localhost:8000/health/detailed" > /dev/null 2>&1
echo "✅ Made health check requests"

echo ""
echo "Waiting 5 seconds for metrics to update..."
sleep 5

echo ""
echo "Sample metrics data:"
echo "==================="
echo "HTTP requests from API Gateway:"
curl -s "http://localhost:8000/metrics" | grep "http_requests_total" | head -3
echo ""
echo "Request duration percentiles:"
curl -s "http://localhost:8000/metrics" | grep "http_request_duration_seconds" | head -2

echo ""
echo "=================================="
echo "TESTING COMPLETE!"
echo "=================================="
echo ""
echo "If all tests passed, you can access:"
echo "📊 Grafana Dashboard: http://localhost:3000 (admin/admin)"
echo "📈 Prometheus: http://localhost:9090"
echo "🔧 API Gateway Metrics: http://localhost:8000/metrics"
echo ""
echo "In Grafana, import the EchoWright Overview dashboard to see visualizations."