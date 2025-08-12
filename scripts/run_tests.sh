#!/bin/bash

# Comprehensive test runner for EchoWright platform
# This script runs all types of tests with proper configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${PROJECT_ROOT}/tests"
COVERAGE_DIR="${TEST_DIR}/coverage"
REPORTS_DIR="${TEST_DIR}/reports"

# Default values
RUN_UNIT=true
RUN_INTEGRATION=false
RUN_PERFORMANCE=false
COVERAGE_THRESHOLD=80
PARALLEL=false
VERBOSE=false
CLEAN=false

# Function to print colored output
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

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run comprehensive tests for EchoWright platform.

OPTIONS:
    -u, --unit              Run unit tests (default: true)
    -i, --integration       Run integration tests (default: false)
    -p, --performance       Run performance tests (default: false)
    -a, --all              Run all test types
    -c, --coverage THRESH   Coverage threshold (default: 80)
    -j, --parallel         Run tests in parallel
    -v, --verbose          Verbose output
    --clean                Clean previous test artifacts
    -h, --help             Show this help message

EXAMPLES:
    $0                     # Run unit tests only
    $0 -a                  # Run all tests
    $0 -u -i               # Run unit and integration tests
    $0 -p                  # Run performance tests only
    $0 --clean -a          # Clean and run all tests
    $0 -j -v               # Run with parallel execution and verbose output

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--unit)
            RUN_UNIT=true
            shift
            ;;
        -i|--integration)
            RUN_INTEGRATION=true
            shift
            ;;
        -p|--performance)
            RUN_PERFORMANCE=true
            shift
            ;;
        -a|--all)
            RUN_UNIT=true
            RUN_INTEGRATION=true
            RUN_PERFORMANCE=true
            shift
            ;;
        -c|--coverage)
            COVERAGE_THRESHOLD="$2"
            shift 2
            ;;
        -j|--parallel)
            PARALLEL=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Setup environment
setup_environment() {
    print_status "Setting up test environment..."
    
    cd "$PROJECT_ROOT"
    
    # Create necessary directories
    mkdir -p "$COVERAGE_DIR"/{html,xml}
    mkdir -p "$REPORTS_DIR"
    
    # Set environment variables for testing
    export PYTHONPATH="${PROJECT_ROOT}:${PYTHONPATH:-}"
    export ENVIRONMENT="test"
    export LOG_LEVEL="WARNING"
    export GEMINI_API_KEY="test-key-for-testing"
    export REDIS_URL="redis://localhost:6379/1"
    export DATABASE_URL="postgresql://test:test@localhost:5432/test_db"
    
    # Install test dependencies if needed
    if [[ ! -f "${TEST_DIR}/.deps_installed" ]] || [[ "${CLEAN}" == "true" ]]; then
        print_status "Installing test dependencies..."
        if [[ -f "${TEST_DIR}/requirements.txt" ]]; then
            pip install -r "${TEST_DIR}/requirements.txt" > /dev/null 2>&1
        else
            # Fallback to basic dependencies
            pip install -r platform/backend/services/api_gateway/requirements.txt \
                        -r platform/backend/services/context_service/requirements.txt \
                        -r platform/backend/services/llm_gateway/requirements.txt \
                        pgvector pytest pytest-cov coverage > /dev/null 2>&1
        fi
        touch "${TEST_DIR}/.deps_installed"
    fi
}

# Clean previous test artifacts
clean_artifacts() {
    if [[ "${CLEAN}" == "true" ]]; then
        print_status "Cleaning previous test artifacts..."
        rm -rf "${COVERAGE_DIR}"/*
        rm -rf "${REPORTS_DIR}"/*
        rm -rf "${PROJECT_ROOT}"/.pytest_cache
        find "${PROJECT_ROOT}" -name "*.pyc" -delete 2>/dev/null || true
    fi
}

# Check if services are running (for integration tests)
check_services() {
    if [[ "${RUN_INTEGRATION}" == "true" ]]; then
        print_status "Checking if services are available for integration tests..."
        
        local api_url="${API_BASE_URL:-http://localhost:8000}"
        
        if ! curl -s -f "${api_url}/health" > /dev/null 2>&1; then
            print_warning "API Gateway not available at ${api_url}"
            print_warning "Integration tests may fail. Start services with: docker-compose up -d"
        else
            print_success "Services are running and accessible"
        fi
    fi
}

# Run unit tests
run_unit_tests() {
    if [[ "${RUN_UNIT}" != "true" ]]; then
        return 0
    fi
    
    print_status "Running unit tests..."
    
    local pytest_args=(
        "--cov=platform/backend/services"
        "--cov=core" 
        "--cov-report=html:${COVERAGE_DIR}/html"
        "--cov-report=xml:${COVERAGE_DIR}/coverage.xml"
        "--cov-report=term-missing"
        "--cov-branch"
        "--cov-fail-under=${COVERAGE_THRESHOLD}"
        "--junitxml=${REPORTS_DIR}/unit-tests.xml"
    )
    
    # Add test directories if they exist
    if [[ -d "${TEST_DIR}/unit" ]]; then
        pytest_args+=("${TEST_DIR}/unit")
    fi
    
    if [[ "${PARALLEL}" == "true" ]] && command -v pytest-xdist &> /dev/null; then
        pytest_args+=("-n" "auto")
    fi
    
    if [[ "${VERBOSE}" == "true" ]]; then
        pytest_args+=("-v" "-s")
    else
        pytest_args+=("-q")
    fi
    
    if pytest "${pytest_args[@]}"; then
        print_success "Unit tests passed"
        return 0
    else
        print_error "Unit tests failed"
        return 1
    fi
}

# Run integration tests
run_integration_tests() {
    if [[ "${RUN_INTEGRATION}" != "true" ]]; then
        return 0
    fi
    
    print_status "Running integration tests..."
    
    local pytest_args=(
        "--junitxml=${REPORTS_DIR}/integration-tests.xml"
    )
    
    # Add integration test directory if it exists
    if [[ -d "${TEST_DIR}/integration" ]]; then
        pytest_args+=("${TEST_DIR}/integration")
    else
        print_warning "Integration test directory not found, skipping"
        return 0
    fi
    
    if [[ "${VERBOSE}" == "true" ]]; then
        pytest_args+=("-v" "-s")
    else
        pytest_args+=("-q")
    fi
    
    # Set longer timeout for integration tests
    pytest_args+=("--timeout=120")
    
    if pytest "${pytest_args[@]}"; then
        print_success "Integration tests passed"
        return 0
    else
        print_error "Integration tests failed"
        return 1
    fi
}

# Run performance tests
run_performance_tests() {
    if [[ "${RUN_PERFORMANCE}" != "true" ]]; then
        return 0
    fi
    
    print_status "Running performance tests..."
    
    # Check if Locust is available
    if ! command -v locust &> /dev/null; then
        print_warning "Locust not found. Install with: pip install locust"
        print_warning "Skipping performance tests"
        return 0
    fi
    
    local api_url="${API_BASE_URL:-http://localhost:8000}"
    local users="${PERF_USERS:-10}"
    local spawn_rate="${PERF_SPAWN_RATE:-2}"
    local run_time="${PERF_RUN_TIME:-60s}"
    
    print_status "Performance test configuration:"
    print_status "  Target URL: ${api_url}"
    print_status "  Users: ${users}"
    print_status "  Spawn rate: ${spawn_rate}/sec"
    print_status "  Duration: ${run_time}"
    
    # Check if locustfile exists
    if [[ ! -f "${TEST_DIR}/performance/locustfile.py" ]]; then
        print_warning "Locustfile not found, skipping performance tests"
        return 0
    fi
    
    # Run Locust in headless mode
    if locust \
        -f "${TEST_DIR}/performance/locustfile.py" \
        --host="${api_url}" \
        --users="${users}" \
        --spawn-rate="${spawn_rate}" \
        --run-time="${run_time}" \
        --html="${REPORTS_DIR}/performance-report.html" \
        --csv="${REPORTS_DIR}/performance" \
        --headless; then
        print_success "Performance tests completed"
        return 0
    else
        print_error "Performance tests failed"
        return 1
    fi
}

# Generate test report
generate_report() {
    print_status "Generating test report..."
    
    local report_file="${REPORTS_DIR}/test-summary.md"
    
    cat > "${report_file}" << EOF
# EchoWright Test Summary

**Date:** $(date)
**Environment:** ${ENVIRONMENT:-development}

## Test Results

EOF

    if [[ "${RUN_UNIT}" == "true" ]]; then
        echo "### Unit Tests" >> "${report_file}"
        if [[ -f "${REPORTS_DIR}/unit-tests.xml" ]]; then
            echo "✅ Unit tests completed - See JUnit XML report" >> "${report_file}"
        else
            echo "❌ Unit tests failed or not run" >> "${report_file}"
        fi
        echo "" >> "${report_file}"
    fi
    
    if [[ "${RUN_INTEGRATION}" == "true" ]]; then
        echo "### Integration Tests" >> "${report_file}"
        if [[ -f "${REPORTS_DIR}/integration-tests.xml" ]]; then
            echo "✅ Integration tests completed - See JUnit XML report" >> "${report_file}"
        else
            echo "❌ Integration tests failed or not run" >> "${report_file}"
        fi
        echo "" >> "${report_file}"
    fi
    
    if [[ "${RUN_PERFORMANCE}" == "true" ]]; then
        echo "### Performance Tests" >> "${report_file}"
        if [[ -f "${REPORTS_DIR}/performance-report.html" ]]; then
            echo "✅ Performance tests completed - See HTML report" >> "${report_file}"
        else
            echo "❌ Performance tests failed or not run" >> "${report_file}"
        fi
        echo "" >> "${report_file}"
    fi
    
    cat >> "${report_file}" << EOF

## Coverage Report

Coverage reports are available in:
- HTML: \`tests/coverage/html/index.html\`
- XML: \`tests/coverage/coverage.xml\`

## Test Reports

Test reports are available in:
- Unit Tests: \`tests/reports/unit-tests.xml\`
- Integration Tests: \`tests/reports/integration-tests.xml\`
- Performance Tests: \`tests/reports/performance-report.html\`

---
Generated by EchoWright test runner
EOF

    print_success "Test report generated: ${report_file}"
}

# Main execution
main() {
    local exit_code=0
    
    print_status "Starting EchoWright test suite..."
    print_status "Project root: ${PROJECT_ROOT}"
    
    setup_environment
    clean_artifacts
    check_services
    
    # Run tests in order
    if ! run_unit_tests; then
        exit_code=1
    fi
    
    if ! run_integration_tests; then
        exit_code=1
    fi
    
    if ! run_performance_tests; then
        exit_code=1
    fi
    
    generate_report
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "All tests completed successfully!"
        
        # Display coverage summary if available
        if [[ -f "${COVERAGE_DIR}/coverage.xml" ]]; then
            print_status "Coverage summary:"
            python -m coverage report --show-missing 2>/dev/null || true
        fi
        
        print_status "View detailed reports:"
        print_status "  Coverage: file://${COVERAGE_DIR}/html/index.html"
        if [[ -f "${REPORTS_DIR}/performance-report.html" ]]; then
            print_status "  Performance: file://${REPORTS_DIR}/performance-report.html"
        fi
    else
        print_error "Some tests failed. Check the output above for details."
    fi
    
    return $exit_code
}

# Run main function
main "$@"
