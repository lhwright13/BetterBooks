#!/bin/bash
"""
Local Test Runner for EchoWright Platform
Validates all tests locally before pushing to CI/CD
"""

set -e  # Exit on any error

echo "🧪 EchoWright Local Test Suite"
echo "================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Set up environment
export PYTHONPATH="$(pwd)/core:$(pwd):$PYTHONPATH"
export ENVIRONMENT="test"
export LOG_LEVEL="WARNING"
export GEMINI_API_KEY="test-key-for-testing"
export REDIS_URL="redis://localhost:6379/1"
export DATABASE_URL="postgresql://test:test@localhost:5432/test_db"

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        exit 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "🔍 Checking Python environment..."
if ! command -v python3 &> /dev/null; then
    print_warning "Python 3 not found. Please install Python 3.11+"
    exit 1
fi

echo "📦 Installing test dependencies..."
if [ ! -f "tests/requirements.txt" ]; then
    print_warning "tests/requirements.txt not found"
    exit 1
fi

pip install -r tests/requirements.txt > /dev/null 2>&1
print_status $? "Test dependencies installed"

echo "🧹 Code Quality Checks"
echo "----------------------"

echo "Checking code formatting with black..."
if command -v black &> /dev/null; then
    black --check --diff platform/backend/services/ > /dev/null 2>&1
    print_status $? "Code formatting (black)"
else
    print_warning "Black not installed, skipping formatting check"
fi

echo "Checking import sorting with isort..."
if command -v isort &> /dev/null; then
    isort --check-only --diff platform/backend/services/ > /dev/null 2>&1
    print_status $? "Import sorting (isort)"
else
    print_warning "isort not installed, skipping import check"
fi

echo "Running linting with flake8..."
if command -v flake8 &> /dev/null; then
    flake8 platform/backend/services/ --max-line-length=100 --ignore=E203,W503 > /dev/null 2>&1
    print_status $? "Linting (flake8)"
else
    print_warning "flake8 not installed, skipping linting check"
fi

echo ""
echo "🧪 Unit Tests"
echo "-------------"

echo "Running core unit tests..."
if [ -d "tests/unit" ]; then
    python3 -m pytest tests/unit/ -v --tb=short -q
    print_status $? "Core unit tests"
else
    print_warning "tests/unit directory not found"
fi

echo ""
echo "🔒 GraphQL Tests"
echo "---------------"

echo "Running GraphQL schema tests..."
if [ -f "tests/unit/test_graphql.py" ]; then
    python3 -m pytest tests/unit/test_graphql.py -v --tb=short -q -m graphql
    print_status $? "GraphQL schema tests"
else
    print_warning "GraphQL tests not found"
fi

echo "Running GraphQL security tests..."
if [ -f "tests/unit/test_graphql_security.py" ]; then
    python3 -m pytest tests/unit/test_graphql_security.py -v --tb=short -q -m graphql
    print_status $? "GraphQL security tests"
else
    print_warning "GraphQL security tests not found"
fi

echo ""
echo "📊 Test Coverage"
echo "---------------"

echo "Generating test coverage report..."
if command -v pytest &> /dev/null; then
    python3 -m pytest tests/unit/ --cov=platform/backend/services --cov=core \
                      --cov-report=term-missing \
                      --cov-report=html:tests/coverage/html \
                      -q > /dev/null 2>&1
    print_status $? "Test coverage generated"
    echo "📄 Coverage report: tests/coverage/html/index.html"
else
    print_warning "pytest not available for coverage"
fi

echo ""
echo "🎉 All Tests Passed!"
echo "===================="
echo "✅ Code quality checks passed"
echo "✅ Unit tests passed"  
echo "✅ GraphQL tests passed"
echo "✅ Test coverage generated"
echo ""
echo "💡 Ready to push to CI/CD pipeline!"
echo "    Run: git add . && git commit -m 'fix: unit tests and pipelines' && git push"