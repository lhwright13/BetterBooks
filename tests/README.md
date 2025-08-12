# EchoWright Testing Suite

This directory contains comprehensive tests for the EchoWright audiobook platform, implementing **Phase 3.1 Comprehensive Testing Suite** from the project roadmap.

## 🏗️ Test Architecture

```
tests/
├── conftest.py              # Shared fixtures and configuration
├── pytest.ini              # Pytest configuration
├── requirements.txt         # Testing dependencies
├── README.md               # This file
├── unit/                   # Unit tests
│   └── services/
│       ├── test_api_gateway.py
│       ├── test_context_service.py
│       ├── test_llm_gateway.py
│       └── test_tts_service.py
├── integration/            # Integration tests
│   └── test_api_endpoints.py
├── performance/            # Performance tests
│   └── locustfile.py
├── coverage/              # Coverage reports (generated)
│   ├── html/
│   └── coverage.xml
└── reports/               # Test reports (generated)
    ├── unit-tests.xml
    ├── integration-tests.xml
    └── performance-report.html
```

## 🧪 Test Types

### Unit Tests
- **Location**: `tests/unit/`
- **Purpose**: Test individual components in isolation
- **Coverage**: All backend services (API Gateway, Context Service, LLM Gateway, TTS Service)
- **Mocking**: External dependencies (databases, APIs, Redis) are mocked
- **Execution**: Fast, no external dependencies required

### Integration Tests
- **Location**: `tests/integration/`
- **Purpose**: Test complete workflows across services
- **Coverage**: End-to-end API functionality, service interactions
- **Requirements**: Running services (via Docker Compose)
- **Execution**: Slower, requires full environment

### Performance Tests
- **Location**: `tests/performance/`
- **Purpose**: Load testing and performance benchmarking
- **Tool**: Locust for distributed load testing
- **Scenarios**: Multiple user types (regular, power users, read-only)
- **Execution**: Configurable load patterns

## 🚀 Running Tests

### Quick Start
```bash
# Run unit tests only (default)
./scripts/run_tests.sh

# Run all tests
./scripts/run_tests.sh --all

# Run with verbose output and parallel execution
./scripts/run_tests.sh --all --verbose --parallel
```

### Individual Test Types
```bash
# Unit tests only
./scripts/run_tests.sh --unit

# Integration tests (requires running services)
docker-compose up -d
./scripts/run_tests.sh --integration

# Performance tests
./scripts/run_tests.sh --performance
```

### Advanced Options
```bash
# Clean previous artifacts and run tests
./scripts/run_tests.sh --clean --all

# Set custom coverage threshold
./scripts/run_tests.sh --coverage 85

# Run specific test files
pytest tests/unit/services/test_api_gateway.py -v

# Run tests with specific markers
pytest -m "unit and not slow" -v
```

## 📊 Coverage Requirements

- **Minimum Coverage**: 80% (configurable)
- **Branch Coverage**: Enabled
- **Reports**: HTML, XML, and terminal output
- **Exclusions**: Test files, migrations, virtual environments

### Viewing Coverage Reports
```bash
# Generate coverage report
python -m coverage report --show-missing

# View HTML report
open tests/coverage/html/index.html
```

## 🏷️ Test Markers

Tests are organized using pytest markers:

- `@pytest.mark.unit` - Unit tests
- `@pytest.mark.integration` - Integration tests  
- `@pytest.mark.performance` - Performance tests
- `@pytest.mark.slow` - Slow-running tests
- `@pytest.mark.requires_redis` - Tests requiring Redis
- `@pytest.mark.requires_database` - Tests requiring database
- `@pytest.mark.requires_external_api` - Tests requiring external APIs

### Running by Markers
```bash
# Run only fast unit tests
pytest -m "unit and not slow"

# Run tests that don't require external services
pytest -m "not (requires_redis or requires_database)"
```

## 🛠️ Test Configuration

### Environment Variables
```bash
export ENVIRONMENT="test"
export LOG_LEVEL="WARNING"
export GEMINI_API_KEY="test-key-for-testing"
export REDIS_URL="redis://localhost:6379/1"
export DATABASE_URL="postgresql://test:test@localhost:5432/test_db"
export API_BASE_URL="http://localhost:8000"
```

### Mock Configuration
Tests use extensive mocking to:
- Avoid external API calls
- Simulate different response scenarios
- Ensure deterministic test results
- Speed up test execution

Key mocked components:
- Google Gemini API
- Redis connections
- Database operations
- TTS synthesis
- File system operations

## 🔧 Fixtures

### Available Fixtures
- `mock_redis` - Fake Redis client using FakeRedis
- `mock_database` - Mocked database connection
- `mock_gemini` - Mocked Google Gemini API
- `mock_tts` - Mocked TTS service
- `sample_embeddings` - Test embedding data
- `sample_llm_request` - Test LLM request data
- `sample_tts_request` - Test TTS request data
- `api_headers` - Common API headers
- `test_audio_file` - Temporary test audio file
- `performance_timer` - Timer for performance measurements

### Custom Fixtures
Create service-specific fixtures in `conftest.py` for reusable test data and mock configurations.

## 🚀 Performance Testing

### Load Test Scenarios
1. **Regular Users**: Typical usage patterns
2. **Power Users**: Intensive operations and batch processing
3. **Read-Only Users**: Search and retrieval focused
4. **Context Heavy Users**: Frequent context storage/retrieval
5. **LLM Heavy Users**: Intensive text generation

### Performance Metrics
- **Response Time**: 95th percentile < 2 seconds
- **Throughput**: Requests per second
- **Error Rate**: < 1% for normal load
- **Resource Usage**: CPU, memory, disk
- **Concurrent Users**: Up to 100 simultaneous users

### Running Performance Tests
```bash
# Basic performance test
export API_BASE_URL="http://localhost:8000"
export PERF_USERS=20
export PERF_SPAWN_RATE=2
export PERF_RUN_TIME=120s

./scripts/run_tests.sh --performance
```

## 🔄 Continuous Integration

### GitHub Actions Workflow
The `.github/workflows/testing.yml` workflow provides:

1. **Unit Tests**: Run on multiple Python versions with coverage
2. **Integration Tests**: Full service testing with Docker
3. **Performance Tests**: Load testing on main branch
4. **Code Quality**: Linting, formatting, security checks
5. **Test Summary**: Comprehensive reporting and PR comments

### Workflow Triggers
- **Push**: to main/develop branches
- **Pull Request**: to main/develop branches  
- **Schedule**: Daily at 6 AM UTC
- **Manual**: workflow_dispatch

### Artifact Collection
- Unit test results and coverage reports
- Integration test results and service logs
- Performance test reports and metrics
- Code quality reports
- Test summary documentation

## 📝 Writing Tests

### Unit Test Example
```python
@pytest.mark.unit
class TestAPIGateway:
    def test_health_endpoint(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
```

### Integration Test Example
```python
@pytest.mark.integration
class TestAPIIntegration:
    def test_complete_workflow(self, api_client):
        # Store context
        context_response = api_client.post("/api/v1/context/store", json=data)
        assert context_response.status_code == 200
        
        # Generate completion
        llm_response = api_client.post("/api/v1/llm/complete", json=prompt)
        assert llm_response.status_code == 200
```

### Performance Test Example
```python
class EchoWrightUser(HttpUser):
    wait_time = between(1, 3)
    
    @task(10)
    def health_check(self):
        self.client.get("/health")
    
    @task(5)
    def llm_completion(self):
        self.client.post("/api/v1/llm/complete", json=payload)
```

## 🐛 Debugging Tests

### Common Issues
1. **Import Errors**: Ensure PYTHONPATH includes project root
2. **Service Dependencies**: Start required services with Docker Compose
3. **Environment Variables**: Set test-specific environment variables
4. **Fixture Conflicts**: Check fixture scope and dependencies
5. **Mock Configuration**: Verify mock setup in fixtures

### Debugging Commands
```bash
# Run specific test with detailed output
pytest tests/unit/services/test_api_gateway.py::TestAPIGateway::test_health_endpoint -v -s

# Run with debugger
pytest --pdb tests/unit/services/test_api_gateway.py

# Show fixture setup
pytest --fixtures tests/unit/

# Debug test collection
pytest --collect-only tests/
```

## 📈 Test Metrics

### Key Performance Indicators
- **Test Coverage**: > 80%
- **Test Execution Time**: < 5 minutes for unit tests
- **Test Reliability**: > 99% pass rate
- **Performance Benchmarks**: Response times within SLA
- **Code Quality**: All quality checks passing

### Monitoring
- CI/CD pipeline status
- Coverage trends over time
- Performance regression detection
- Test failure analysis
- Quality gate compliance

## 🔧 Maintenance

### Regular Tasks
1. **Update Dependencies**: Keep testing libraries current
2. **Review Coverage**: Identify uncovered code paths
3. **Performance Baselines**: Update performance expectations
4. **Mock Updates**: Sync mocks with API changes
5. **Test Cleanup**: Remove obsolete tests

### Best Practices
- Write tests before implementing features (TDD)
- Keep tests focused and independent
- Use descriptive test names
- Mock external dependencies
- Test both success and failure scenarios
- Maintain test data and fixtures
- Document complex test scenarios

---

For questions or contributions to the testing suite, please refer to the main project documentation or create an issue in the repository.