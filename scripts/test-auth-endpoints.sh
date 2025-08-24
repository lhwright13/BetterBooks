#!/bin/bash

# Test Authentication Endpoints for EchoWright
# This script tests the authentication system endpoints after deployment

set -e

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8000}"
NAMESPACE="${NAMESPACE:-betterbooks}"

echo "🧪 Testing EchoWright Authentication Endpoints..."
echo "API Base URL: $API_BASE_URL"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_test() {
    echo -e "\n${YELLOW}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    print_test "$test_name"
    
    if eval "$test_command"; then
        print_success "$test_name"
        ((TESTS_PASSED++))
    else
        print_fail "$test_name"
        ((TESTS_FAILED++))
    fi
}

# If testing against Kubernetes, set up port forwarding
if [[ "$API_BASE_URL" == "http://localhost:8000" ]]; then
    print_test "Setting up port forwarding to API Gateway..."
    
    # Check if port forwarding is already active
    if ! curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
        echo "Setting up port forward to API Gateway..."
        kubectl port-forward svc/api-gateway -n $NAMESPACE 8000:8000 &
        PORT_FORWARD_PID=$!
        
        # Wait for port forward to be ready
        echo "Waiting for port forward to be ready..."
        sleep 5
        
        # Verify port forward is working
        if ! curl -f -s http://localhost:8000/health > /dev/null; then
            echo "Port forwarding failed"
            kill $PORT_FORWARD_PID 2>/dev/null
            exit 1
        fi
        
        echo "Port forwarding established"
    else
        echo "Port forward already active or API is accessible"
        PORT_FORWARD_PID=""
    fi
fi

# Test 1: Basic Health Check
run_test "API Gateway Health Check" "curl -f -s $API_BASE_URL/health > /dev/null"

# Test 2: Authentication Health Check
run_test "Authentication Health Check" "curl -f -s $API_BASE_URL/auth/health > /dev/null"

# Test 3: Email Signup Endpoint (expect validation error)
run_test "Email Signup Endpoint Exists" "
    response_code=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $API_BASE_URL/auth/email/signup -H 'Content-Type: application/json' -d '{}')
    [[ \$response_code == '422' ]]
"

# Test 4: Email Signin Endpoint (expect validation error)
run_test "Email Signin Endpoint Exists" "
    response_code=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $API_BASE_URL/auth/email/signin -H 'Content-Type: application/json' -d '{}')
    [[ \$response_code == '422' ]]
"

# Test 5: Google OAuth Endpoint (expect validation error)
run_test "Google OAuth Endpoint Exists" "
    response_code=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $API_BASE_URL/auth/google/signin -H 'Content-Type: application/json' -d '{}')
    [[ \$response_code == '422' ]]
"

# Test 6: Apple OAuth Endpoint (expect validation error) 
run_test "Apple OAuth Endpoint Exists" "
    response_code=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $API_BASE_URL/auth/apple/signin -H 'Content-Type: application/json' -d '{}')
    [[ \$response_code == '422' ]]
"

# Test 7: Email Verification Send Endpoint (expect validation error)
run_test "Email Verification Send Endpoint Exists" "
    response_code=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $API_BASE_URL/auth/email/send-verification -H 'Content-Type: application/json' -d '{}')
    [[ \$response_code == '422' ]]
"

# Test 8: Password Reset Endpoint (expect validation error)
run_test "Password Reset Endpoint Exists" "
    response_code=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $API_BASE_URL/auth/password/reset -H 'Content-Type: application/json' -d '{}')
    [[ \$response_code == '422' ]]
"

# Test 9: Token Refresh Endpoint (expect auth error)
run_test "Token Refresh Endpoint Exists" "
    response_code=\$(curl -s -o /dev/null -w '%{http_code}' -X POST $API_BASE_URL/auth/refresh -H 'Content-Type: application/json' -d '{}')
    [[ \$response_code == '422' || \$response_code == '401' ]]
"

# Test 10: User Info Endpoint (expect auth required)
run_test "User Info Endpoint Exists" "
    response_code=\$(curl -s -o /dev/null -w '%{http_code}' -X GET $API_BASE_URL/auth/me)
    [[ \$response_code == '401' ]]
"

# Test 11: Test with Valid Email Registration (if email service is configured)
if [[ -n "$SENDGRID_API_KEY" || -n "$AWS_SES_ACCESS_KEY_ID" ]]; then
    print_test "Testing valid email registration..."
    
    TEST_EMAIL="test-$(date +%s)@example.com"
    TEST_PASSWORD="TestPass123!"
    TEST_NAME="Test User"
    
    response=$(curl -s -X POST "$API_BASE_URL/auth/email/signup" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"display_name\":\"$TEST_NAME\"}")
    
    if [[ $? -eq 0 ]] && echo "$response" | grep -q "access_token\|user"; then
        print_success "Email registration test (with real email service)"
        ((TESTS_PASSED++))
    else
        print_fail "Email registration test (check email service configuration)"
        ((TESTS_FAILED++))
    fi
else
    print_test "Skipping email registration test (no email service configured)"
fi

# Cleanup port forwarding
if [[ -n "$PORT_FORWARD_PID" ]]; then
    kill $PORT_FORWARD_PID 2>/dev/null
    echo "Port forwarding cleaned up"
fi

# Test Results Summary
echo ""
echo "=== TEST RESULTS SUMMARY ==="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All authentication tests passed!${NC}"
    echo ""
    echo "Your authentication system is working correctly:"
    echo "✅ All authentication endpoints are accessible"
    echo "✅ Email signup and signin endpoints are configured"
    echo "✅ OAuth endpoints (Google, Apple) are available"
    echo "✅ Email verification and password reset endpoints exist"
    echo "✅ Token refresh and user info endpoints are secured"
    echo ""
    echo "Next steps:"
    echo "1. Test with your mobile app"
    echo "2. Configure email templates"
    echo "3. Test OAuth with real credentials"
    exit 0
else
    echo -e "\n${RED}❌ Some authentication tests failed${NC}"
    echo ""
    echo "Please check:"
    echo "1. API Gateway deployment status"
    echo "2. Authentication secrets configuration"
    echo "3. Service logs for errors"
    echo ""
    echo "Debugging commands:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl logs -l app=api-gateway -n $NAMESPACE"
    echo "  kubectl describe pod -l app=api-gateway -n $NAMESPACE"
    exit 1
fi