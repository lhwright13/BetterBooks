# Logging and Monitoring Guide

This document describes the comprehensive logging and monitoring infrastructure implemented in the EchoWright platform, including structured logging, health checks, and Prometheus metrics collection.

## Table of Contents
- [Overview](#overview)
- [Structured Logging](#structured-logging)
- [Health Checks](#health-checks)
- [Prometheus Metrics](#prometheus-metrics)
- [Integration Guide](#integration-guide)
- [API Reference](#api-reference)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Production Deployment](#production-deployment)

## Overview

The EchoWright platform implements comprehensive logging and monitoring capabilities to ensure observability across all microservices. This includes:

- **Structured JSON Logging**: All logs are output in JSON format for easy parsing and analysis
- **Request Correlation**: Unique request IDs track requests across services
- **Health Monitoring**: Multiple health check endpoints for different monitoring needs
- **System Metrics**: Real-time CPU, memory, and disk usage tracking
- **Prometheus Metrics**: Production-grade metrics collection and alerting
- **Grafana Dashboards**: Visual monitoring and analytics interface

## Structured Logging

### Features

- JSON-formatted log output for machine readability
- Request correlation IDs for distributed tracing
- Contextual fields for rich debugging information
- Exception tracking with full stack traces
- Multiple log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)

### Usage Example

```python
from logging_config import setup_logging, set_request_id

# Initialize logger for your service
logger = setup_logging(
    service_name="my_service",
    log_level="INFO"  # Can be DEBUG, INFO, WARNING, ERROR, CRITICAL
)

# Basic logging
logger.info("Service started", version="1.0.0", port=8000)

# Log with request context
set_request_id("req-123-456")
logger.info("Processing request", endpoint="/api/data", method="GET")

# Log warnings
logger.warning("High memory usage", memory_percent=85.5, threshold=80)

# Log errors with exception details
try:
    result = risky_operation()
except Exception as e:
    logger.error("Operation failed", exc_info=True, operation="risky_operation")
```

### Log Output Format

```json
{
  "timestamp": "2025-01-08T12:34:56.789123",
  "level": "INFO",
  "logger": "api_gateway",
  "message": "Request completed",
  "module": "main",
  "function": "complete",
  "line": 145,
  "request_id": "req-123-456",
  "method": "POST",
  "path": "/complete",
  "status_code": 200,
  "duration_seconds": 1.234
}
```

### Middleware Integration

The logging middleware automatically logs all HTTP requests and responses:

```python
from fastapi import FastAPI
from logging_middleware import LoggingMiddleware

app = FastAPI()
app.add_middleware(LoggingMiddleware, logger=logger)
```

This automatically:
- Generates request IDs if not provided
- Logs request start with method, path, and client info
- Logs request completion with status code and duration
- Tracks errors and exceptions
- Adds X-Request-ID header to responses

## Production Deployment

### Prometheus Production Configuration

When deploying to production, consider these essential configurations:

#### Security Considerations
```yaml
# prometheus.yml - Production settings
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  
rule_files:
  - "alert_rules.yml"
  
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Secure scraping with authentication
  - job_name: 'api_gateway'
    static_configs:
      - targets: ['api_gateway:8000']
    basic_auth:
      username: 'prometheus'
      password: 'secure_password'
    tls_config:
      insecure_skip_verify: false
```

#### Essential Alerting Rules
Create `alert_rules.yml` for production monitoring:

```yaml
groups:
- name: echowright_alerts
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate on {{ $labels.instance }}"
      description: "Error rate is {{ $value }} errors per second"
      
  - alert: HighResponseTime
    expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High response time on {{ $labels.instance }}"
      
  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service {{ $labels.instance }} is down"
```

#### Resource Monitoring
```yaml
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
      
  - alert: HighMemoryUsage
    expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
    for: 5m
    labels:
      severity: warning
      
  - alert: LowDiskSpace
    expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 90
    for: 5m
    labels:
      severity: critical
```

#### Grafana Production Setup
```yaml
# docker-compose.yml - Production Grafana
grafana:
  image: grafana/grafana:latest
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    - GF_SERVER_ROOT_URL=https://monitoring.yourdomain.com
    - GF_SECURITY_COOKIE_SECURE=true
    - GF_AUTH_ANONYMOUS_ENABLED=false
  volumes:
    - grafana_data:/var/lib/grafana
    - ./grafana/provisioning:/etc/grafana/provisioning
  networks:
    - monitoring
  labels:
    - traefik.enable=true
    - traefik.http.routers.grafana.tls=true
```

#### Kubernetes Deployment
For Kubernetes environments, use ServiceMonitor resources:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: echowright-metrics
spec:
  selector:
    matchLabels:
      app: echowright
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

### Troubleshooting Production Issues

#### Common Monitoring Problems

1. **Missing Metrics**
   - Check service `/metrics` endpoints are accessible
   - Verify Prometheus can reach target services
   - Check network policies and firewall rules

2. **High Cardinality Issues**
   - Avoid high-cardinality labels (user IDs, request IDs)
   - Use recording rules for expensive queries
   - Implement metric retention policies

3. **Performance Impact**
   - Monitor metrics collection overhead
   - Use appropriate scrape intervals (15-60s)
   - Implement metric sampling for high-volume endpoints

#### Service-Specific Debugging

```bash
# Check service metrics endpoint
curl http://localhost:8000/metrics

# Verify Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check alert manager status
curl http://localhost:9093/api/v1/status
```

### Cost Optimization

#### Metrics Retention
Configure appropriate retention policies:

```yaml
# prometheus.yml
global:
  # Reduce retention for cost optimization
  retention: 30d
  retention_size: 50GB
```

#### Query Optimization
Use recording rules for expensive queries:

```yaml
# recording_rules.yml
groups:
- name: performance
  interval: 30s
  rules:
  - record: echowright:request_rate
    expr: sum(rate(http_requests_total[5m])) by (service)
    
  - record: echowright:error_rate
    expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
```

## Distributed Tracing

### Overview

EchoWright implements distributed tracing using OpenTelemetry and Jaeger to track requests across all microservices. This provides complete visibility into request flows, performance bottlenecks, and service dependencies.

### Key Features

- **End-to-End Request Tracing**: Track requests from API Gateway through all backend services
- **Service Dependency Mapping**: Visualize how services interact with each other
- **Performance Analysis**: Identify slow operations and bottlenecks
- **Error Tracking**: Trace errors back to their source across service boundaries
- **Context Propagation**: Automatic correlation of related operations

### Jaeger UI

Access the Jaeger web interface at http://localhost:16686

#### Features Available:
- **Trace Search**: Find traces by service, operation, or tags
- **Service Map**: Visual representation of service dependencies
- **Performance Analysis**: Latency percentiles and error rates
- **Trace Timeline**: Detailed breakdown of request execution

### Automatic Instrumentation

The tracing system automatically instruments:

- **FastAPI Applications**: All HTTP endpoints and middleware
- **HTTP Requests**: External API calls using `requests` or `httpx`
- **Database Queries**: PostgreSQL operations via `psycopg2`
- **Redis Operations**: Cache operations and session storage

### Manual Tracing

Add custom tracing to your business logic:

```python
from tracing import setup_tracing, get_development_tracing_config

# Initialize tracing
tracer = setup_tracing(get_development_tracing_config("my_service"))

# Create custom spans
with tracer.start_as_current_span("business_operation") as span:
    span.set_attribute("user_id", user_id)
    span.set_attribute("operation_type", "book_processing")
    
    # Your business logic here
    result = process_audiobook(book_id)
    
    span.set_attribute("processed_chapters", len(result.chapters))
    span.set_status(trace.Status(trace.StatusCode.OK))
```

### Service-Specific Helpers

#### LLM Operations
```python
from tracing import LLMTracingHelper

# Trace LLM requests with specific attributes
with LLMTracingHelper.trace_llm_request(tracer, "gemini", len(prompt)) as span:
    response = await llm_client.complete(prompt)
    LLMTracingHelper.add_llm_response_attributes(
        span,
        response_length=len(response.text),
        tokens_used=response.usage.total_tokens,
        processing_time=response.processing_time
    )
```

#### Database Operations
```python
from tracing import DatabaseTracingHelper

# Trace database operations
with DatabaseTracingHelper.trace_db_query(tracer, "SELECT", "embeddings") as span:
    results = await db.execute(query)
    DatabaseTracingHelper.add_db_query_attributes(
        span,
        query=query,
        rows_affected=len(results)
    )
```

### Trace Context Correlation

Traces are automatically correlated with:
- **Request IDs**: Link traces to structured logs
- **User Context**: Track user-specific request flows
- **Business Operations**: Connect technical spans to business processes

### Production Configuration

#### Sampling Configuration
```python
# Production sampling (10% of requests)
tracing_config = TracingConfig(
    service_name="my_service",
    jaeger_endpoint="http://jaeger:14268/api/traces",
    sampling_rate=0.1
)
```

#### Security Considerations
- Sensitive data is automatically sanitized from span attributes
- Database queries are truncated to prevent data leakage
- User IDs are hashed in production traces

### Integration with Logging

Traces are correlated with structured logs through request IDs:

```python
# Logs automatically include trace context
logger.info("Processing request", 
    user_id=user_id,
    trace_id=get_current_span().get_span_context().trace_id
)
```

### Performance Impact

- **Overhead**: < 5ms per traced request
- **Memory**: Minimal impact with proper sampling
- **Storage**: Configurable retention periods

## Prometheus Metrics

### Overview

EchoWright uses Prometheus for metrics collection and monitoring. The system automatically collects:

- **HTTP Request Metrics**: Request rate, duration, and status codes
- **Business Metrics**: Active users, books processed, audio generated
- **LLM Performance**: Token usage, request duration, model selection
- **TTS Metrics**: Synthesis requests and audio duration
- **Database Metrics**: Query performance and connection health
- **System Resources**: CPU, memory, and disk utilization

### Metrics Infrastructure

The metrics stack includes:

- **Prometheus Server** (port 9090): Metrics collection and storage
- **Grafana Dashboard** (port 3000): Visualization and alerting
- **Service Endpoints**: Each service exposes `/metrics` for scraping

### Available Metrics

#### HTTP Metrics
```
# Request rate and status
http_requests_total{method="POST", endpoint="/complete", status="200"}

# Request duration percentiles
http_request_duration_seconds_bucket{method="POST", endpoint="/complete"}

# Active requests
http_requests_in_progress
```

#### LLM Metrics
```
# LLM request tracking
llm_requests_total{model="gemini", status="success"}

# Token consumption
llm_tokens_used{model="gemini", type="prompt"}

# Response time tracking
llm_request_duration_seconds{model="gemini"}
```

#### Business Metrics
```
# User activity
active_users

# Content processing
books_processed_total
audio_minutes_generated

# Cache performance
cache_hit_ratio
cache_operations_total{operation="get", status="hit"}
```

### Accessing Metrics

#### Grafana Dashboard
1. **URL**: http://localhost:3000
2. **Login**: admin / admin
3. **Pre-built Dashboard**: EchoWright Overview
4. **Data Source**: Prometheus (auto-configured)

#### Prometheus Web UI
1. **URL**: http://localhost:9090
2. **Query Interface**: PromQL queries
3. **Targets**: View service health
4. **Rules**: Alerting configuration

#### Raw Metrics Endpoints
- API Gateway: http://localhost:8000/metrics
- LLM Gateway: http://localhost:8002/metrics
- Context Service: http://localhost:8001/metrics
- TTS Service: http://localhost:8003/metrics

### Custom Metrics

Create service-specific metrics using the MetricsCollector:

```python
from metrics import setup_metrics

# Initialize metrics for your service
metrics_collector = setup_metrics(app, "my_service")

# Create custom metrics
request_counter = metrics_collector.create_counter(
    "requests_total",
    "Total requests processed",
    ["endpoint", "status"]
)

response_time = metrics_collector.create_histogram(
    "response_time_seconds",
    "Response time distribution",
    ["endpoint"],
    buckets=(0.1, 0.5, 1, 2.5, 5, 10)
)

# Use the metrics
request_counter.labels(endpoint="/api", status="success").inc()
response_time.labels(endpoint="/api").observe(1.2)
```

### Metric Types

#### Counter
Monotonically increasing values (requests, errors, processed items):
```python
requests_total = metrics_collector.create_counter(
    "requests_total", 
    "Total requests",
    ["method", "status"]
)
requests_total.labels(method="POST", status="200").inc()
```

#### Histogram
Distributions and percentiles (response times, request sizes):
```python
request_duration = metrics_collector.create_histogram(
    "request_duration_seconds",
    "Request duration",
    buckets=(0.1, 0.5, 1, 2.5, 5)
)
request_duration.observe(1.23)
```

#### Gauge
Current values that can go up/down (active connections, memory usage):
```python
active_connections = metrics_collector.create_gauge(
    "active_connections",
    "Currently active connections"
)
active_connections.set(42)
active_connections.inc()  # Increment by 1
active_connections.dec(5)  # Decrement by 5
```

### Docker Configuration

The metrics stack is configured in `docker-compose.yml`:

```yaml
prometheus:
  image: prom/prometheus:latest
  ports:
    - "9090:9090"
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
    
grafana:
  image: grafana/grafana:latest
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
```

Prometheus scraping is configured in `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'api_gateway'
    static_configs:
      - targets: ['api_gateway:8000']
    metrics_path: '/metrics'
    scrape_interval: 10s
```

## Health Checks

### Endpoints

Each service exposes four health check endpoints:

#### 1. Basic Health Check - `/health`
- **Purpose**: Simple liveness probe for load balancers
- **Response**: `{"status": "ok"}`
- **Use Case**: Kubernetes liveness probes, load balancer health checks

#### 2. Detailed Health Check - `/health/detailed`
- **Purpose**: Comprehensive health status with metrics
- **Response**: 
```json
{
  "service": "api_gateway",
  "version": "1.0.0",
  "status": "healthy",
  "timestamp": "2025-01-08T12:34:56.789Z",
  "uptime_seconds": 3600,
  "checks": {
    "database": {
      "status": "healthy",
      "details": {"connected": true, "latency_ms": 5}
    },
    "redis": {
      "status": "healthy",
      "details": {"connected": true}
    },
    "llm_gateway": {
      "status": "healthy",
      "details": {"reachable": true, "latency_ms": 45}
    }
  },
  "metrics": {
    "cpu_percent": 45.2,
    "memory": {
      "percent": 62.3,
      "available_mb": 4096,
      "used_mb": 8192
    },
    "disk": {
      "percent": 71.5,
      "free_gb": 50.2
    }
  }
}
```

#### 3. Readiness Check - `/health/ready`
- **Purpose**: Indicates if service is ready to handle requests
- **Response**: `{"ready": true}` or 503 status if not ready
- **Use Case**: Kubernetes readiness probes, deployment verification

#### 4. Liveness Check - `/health/live`
- **Purpose**: Basic check if service process is alive
- **Response**: `{"alive": true}`
- **Use Case**: Process monitoring, restart triggers

### Custom Health Checks

Add custom health checks for your service dependencies:

```python
from health_checks import HealthCheck, create_health_endpoint

# Create health check instance
health_check = HealthCheck("my_service", "1.0.0")

# Add database check
async def check_database():
    try:
        # Your database connectivity test
        await db.execute("SELECT 1")
        return {"connected": True, "pool_size": db.pool.size}
    except Exception as e:
        return False

# Add external API check
async def check_external_api():
    result = await check_service_endpoint("https://api.example.com")
    return result

# Register checks
health_check.add_check("database", check_database)
health_check.add_check("external_api", check_external_api)

# Create endpoints in FastAPI
create_health_endpoint(app, health_check)
```

## Integration Guide

### Step 1: Add Dependencies

Add to your service's `requirements.txt`:
```
psutil==5.9.6  # For system metrics
```

### Step 2: Set Up Logging

In your service's `main.py`:

```python
import os
import sys
from pathlib import Path

# Add shared module to path
sys.path.append(str(Path(__file__).parent.parent / "shared"))

from logging_config import setup_logging, get_request_id
from logging_middleware import LoggingMiddleware
from health_checks import HealthCheck, create_health_endpoint

# Initialize logging
logger = setup_logging(
    service_name="your_service",
    log_level=os.getenv("LOG_LEVEL", "INFO")
)

# Create FastAPI app
app = FastAPI()

# Add logging middleware
app.add_middleware(LoggingMiddleware, logger=logger)
```

### Step 3: Set Up Health Checks

```python
# Initialize health checks
health_check = HealthCheck("your_service", "1.0.0")

# Add dependency checks
async def check_dependencies():
    # Check your service dependencies
    return True

health_check.add_check("dependencies", check_dependencies)

# Create health endpoints
create_health_endpoint(app, health_check)
```

### Step 4: Use Logging in Your Code

```python
@app.post("/your-endpoint")
async def your_endpoint(request: YourRequest):
    logger.info("Processing request", endpoint="your-endpoint", request_id=get_request_id())
    
    try:
        result = await process_request(request)
        logger.info("Request successful", result_count=len(result))
        return result
    except Exception as e:
        logger.error("Request failed", exc_info=True, error_type=type(e).__name__)
        raise HTTPException(status_code=500, detail=str(e))
```

## API Reference

### logging_config module

#### `setup_logging(service_name: str, log_level: str = "INFO") -> StructuredLogger`
Creates and configures a structured logger for a service.

#### `set_request_id(request_id: str) -> None`
Sets the request ID for the current async context.

#### `get_request_id() -> Optional[str]`
Gets the current request ID from context.

#### `StructuredLogger`
Wrapper class providing structured logging methods:
- `debug(msg: str, **fields)`
- `info(msg: str, **fields)`
- `warning(msg: str, **fields)`
- `error(msg: str, exc_info: bool = False, **fields)`
- `critical(msg: str, exc_info: bool = False, **fields)`

### health_checks module

#### `HealthCheck(service_name: str, version: str)`
Main health check manager class.

#### `add_check(name: str, check_func: Callable) -> None`
Registers a health check function (can be sync or async).

#### `get_health() -> Dict[str, Any]`
Returns comprehensive health status.

#### `create_health_endpoint(app: FastAPI, health_check: HealthCheck)`
Creates all health endpoints for a FastAPI application.

#### Helper Functions

- `check_database(connection_string: str) -> bool`: Check PostgreSQL connectivity
- `check_redis(redis_url: str) -> bool`: Check Redis connectivity
- `check_service_endpoint(url: str, timeout: int = 5) -> Dict`: Check HTTP endpoint

## Best Practices

### 1. Logging Guidelines

- **Use appropriate log levels**:
  - DEBUG: Detailed diagnostic information
  - INFO: General informational messages
  - WARNING: Warning messages for potentially harmful situations
  - ERROR: Error events that might still allow the application to continue
  - CRITICAL: Very serious error events that might cause the application to abort

- **Include contextual information**: Always add relevant fields to help with debugging
  ```python
  logger.info("User action", user_id=user.id, action="login", ip=request.client.host)
  ```

- **Avoid logging sensitive data**: Never log passwords, tokens, or personal information
  ```python
  # Bad
  logger.info("User login", password=password)
  
  # Good
  logger.info("User login", user_id=user_id, method="password")
  ```

### 2. Health Check Guidelines

- **Keep checks fast**: Health checks should complete quickly (< 5 seconds)
- **Check actual functionality**: Don't just return true, actually test the dependency
- **Use appropriate granularity**: Balance between too many and too few checks
- **Handle failures gracefully**: Don't let a health check crash your service

### 3. Request Correlation

- **Propagate request IDs**: Pass request IDs to downstream services
  ```python
  headers = {"X-Request-ID": get_request_id()}
  response = await httpx.post(url, headers=headers)
  ```

- **Log at boundaries**: Always log when entering/exiting service boundaries
- **Include in error responses**: Add request ID to error messages for easier debugging

## Troubleshooting

### Common Issues

#### 1. Logs not appearing
- Check log level configuration
- Verify logger initialization
- Ensure middleware is properly attached

#### 2. Health checks timing out
- Reduce timeout for external service checks
- Make checks async where possible
- Cache health check results if appropriate

#### 3. High memory usage from logging
- Reduce log verbosity in production
- Implement log rotation
- Use appropriate log levels

### Debugging Tips

1. **Enable DEBUG logging** for detailed diagnostics:
   ```python
   logger = setup_logging("service", "DEBUG")
   ```

2. **Test health checks manually**:
   ```bash
   curl http://localhost:8000/health/detailed | jq
   ```

3. **Follow request flow** using request IDs:
   ```bash
   grep "req-123-456" /var/log/service.log
   ```

## Environment Variables

Configure logging and monitoring behavior with these environment variables:

- `LOG_LEVEL`: Set logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
- `LOG_TO_FILE`: Enable file logging (true/false)
- `LOG_FILE_PATH`: Path for log file output
- `HEALTH_CHECK_TIMEOUT`: Timeout for dependency health checks (seconds)

## Performance Considerations

- **Logging overhead**: Structured logging has minimal performance impact (~1-2ms per log)
- **Health check caching**: Consider caching expensive health checks for 10-30 seconds
- **Async operations**: Use async health checks to avoid blocking
- **Metric collection**: System metrics collection adds ~10ms to health check response

## Future Enhancements

Planned improvements to the logging and monitoring system:

1. **Prometheus Metrics** (Next Phase)
   - Custom business metrics
   - Service performance metrics
   - Automatic metric collection

2. **Distributed Tracing** (Next Phase)
   - Jaeger integration
   - Automatic span creation
   - Cross-service trace correlation

3. **Log Aggregation**
   - Integration with ELK stack
   - Centralized log storage
   - Advanced log analytics

## Support

For issues or questions about logging and monitoring:
1. Check this documentation
2. Review the example implementations in services
3. Check the test files for usage examples
4. Consult the team lead for architectural decisions