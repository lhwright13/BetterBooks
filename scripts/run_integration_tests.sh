#!/bin/bash
# Integration test runner for CI/CD pipeline
# Tests all service endpoints and basic functionality

set -e

API_BASE_URL=${API_BASE_URL:-"http://localhost:8000"}
MAX_RETRIES=30
RETRY_DELAY=2

echo "Starting integration tests against: $API_BASE_URL"

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local service_url=$2
    local retries=0
    
    echo "Waiting for $service_name to be ready..."
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -f -s "$service_url/health" > /dev/null 2>&1; then
            echo "$service_name is ready!"
            return 0
        fi
        
        echo "Waiting for $service_name... (attempt $((retries + 1))/$MAX_RETRIES)"
        sleep $RETRY_DELAY
        retries=$((retries + 1))
    done
    
    echo "ERROR: $service_name failed to start within expected time"
    return 1
}

# Function to test API endpoint
test_endpoint() {
    local endpoint=$1
    local expected_status=${2:-200}
    local method=${3:-GET}
    local data=${4:-}
    
    echo "Testing $method $endpoint..."
    
    local curl_cmd="curl -s -w '%{http_code}' -o /tmp/response.json"
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl_cmd="$curl_cmd -X POST -H 'Content-Type: application/json' -d '$data'"
    fi
    
    local status_code=$(eval "$curl_cmd $endpoint")
    
    if [ "$status_code" = "$expected_status" ]; then
        echo "✅ $endpoint returned $status_code (expected $expected_status)"
        return 0
    else
        echo "❌ $endpoint returned $status_code (expected $expected_status)"
        echo "Response:"
        cat /tmp/response.json
        return 1
    fi
}

# Wait for all services to be ready
wait_for_service "API Gateway" "$API_BASE_URL"
wait_for_service "Context Service" "http://localhost:8001"
wait_for_service "LLM Gateway" "http://localhost:8002"
wait_for_service "TTS Service" "http://localhost:8003"
wait_for_service "Transcription Service" "http://localhost:8004"

echo ""
echo "🧪 Running integration tests..."

# Test basic health endpoints
test_endpoint "$API_BASE_URL/health"
test_endpoint "http://localhost:8001/health"
test_endpoint "http://localhost:8002/health"
test_endpoint "http://localhost:8003/health"
test_endpoint "http://localhost:8004/health"

# Test detailed health endpoints
test_endpoint "$API_BASE_URL/health/detailed"
test_endpoint "http://localhost:8001/health/detailed"
test_endpoint "http://localhost:8002/health/detailed"

# Test readiness and liveness probes
test_endpoint "$API_BASE_URL/health/ready"
test_endpoint "$API_BASE_URL/health/live"

# Test API Gateway routing
echo ""
echo "🔄 Testing API Gateway routing..."
test_endpoint "$API_BASE_URL/api/v1/context/health"
test_endpoint "$API_BASE_URL/api/v1/llm/health"
test_endpoint "$API_BASE_URL/api/v1/tts/health"
test_endpoint "$API_BASE_URL/api/v1/transcription/health"

# Test LLM Gateway with test data
echo ""
echo "🤖 Testing LLM Gateway functionality..."
test_llm_data='{
    "messages": [{"role": "user", "content": "Hello, this is a test"}],
    "persona": "test"
}'
test_endpoint "http://localhost:8002/chat/completions" 200 POST "$test_llm_data"

# Test Context Service with test embedding
echo ""
echo "🔍 Testing Context Service functionality..."
test_embedding_data='{
    "text": "This is a test document for embedding",
    "metadata": {"test": true}
}'
test_endpoint "http://localhost:8001/embeddings" 200 POST "$test_embedding_data"

# Test TTS Service
echo ""
echo "🔊 Testing TTS Service functionality..."
test_tts_data='{
    "text": "Hello world test",
    "voice": "default"
}'
test_endpoint "http://localhost:8003/synthesize" 200 POST "$test_tts_data"

# Test Transcription Service
echo ""
echo "📝 Testing Transcription Service functionality..."
test_endpoint "http://localhost:8004/summary-styles"
test_endpoint "http://localhost:8004/question-types"
test_endpoint "http://localhost:8004/reading-modes"

# Test metrics endpoints
echo ""
echo "📊 Testing metrics endpoints..."
test_endpoint "$API_BASE_URL/metrics"
test_endpoint "http://localhost:8001/metrics"
test_endpoint "http://localhost:8002/metrics"

# Test error handling
echo ""
echo "🚫 Testing error handling..."
test_endpoint "$API_BASE_URL/nonexistent" 404
test_endpoint "http://localhost:8002/chat/completions" 422 POST '{"invalid": "data"}'

echo ""
echo "✅ All integration tests passed!"
echo "🎉 Services are ready for deployment!"

# Cleanup
rm -f /tmp/response.json

exit 0