# Local Backend Startup & Validation Guide

This guide helps you start and validate your BetterBooks backend locally with all the new production-ready features.

## 🚀 Quick Start

### 1. Prerequisites
Make sure you have:
- Docker and Docker Compose installed
- At least 4GB RAM available for containers
- Ports 3000, 5432-5433, 6379, 6432-6433, 8000-8004, 9090, 16686 available

### 2. Environment Setup
The `.env` file is already configured for local development. Key settings:
```bash
GEMINI_API_KEY=test-api-key-for-testing  # Replace with real key for full functionality
POSTGRES_USER=betterbooks
POSTGRES_PASSWORD=betterbooks
ENABLE_TRACING=true
ENABLE_METRICS=true
LOG_LEVEL=INFO
```

### 3. Start the Backend
```bash
# Set your Gemini API key (or use test key for infrastructure testing)
export GEMINI_API_KEY=your-actual-gemini-api-key

# Start all services
docker-compose up --build
```

## 📋 Service Architecture

Your backend now includes these production-ready components:

### Core Services
- **API Gateway** (8000): Central entry point with logging & metrics
- **Context Service** (8001): Vector embeddings with connection pooling
- **LLM Gateway** (8002): AI persona management with tracing
- **TTS Service** (8004): Text-to-speech synthesis
- **Transcription Service** (8003): Audio transcription

### Database Infrastructure
- **PostgreSQL Primary** (5432): Main database with replication
- **PostgreSQL Replica** (5433): Read replica for scaling
- **PgBouncer Primary** (6432): Connection pooling for writes
- **PgBouncer Replica** (6433): Connection pooling for reads
- **Redis** (6379): Caching and session storage

### Monitoring & Observability
- **Prometheus** (9090): Metrics collection and alerting
- **Grafana** (3000): Dashboards and visualization (admin/admin)
- **Jaeger** (16686): Distributed tracing and performance monitoring

### Frontend
- **Web Demo** (8080): HTML/JS interface for testing

## ✅ Validation Checklist

### Step 1: Verify Container Status
```bash
docker-compose ps
```
All services should show "Up" status. If any show "Restarting", check logs:
```bash
docker-compose logs <service-name>
```

### Step 2: Test Database Infrastructure

#### Test PostgreSQL Primary
```bash
docker exec betterbooks-postgres_primary-1 psql -U betterbooks -d betterbooks -c "SELECT version();"
```

#### Test Vector Extension
```bash
docker exec betterbooks-postgres_primary-1 psql -U betterbooks -d betterbooks -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"
```

#### Test Read Replica
```bash
docker exec betterbooks-postgres_replica-1 psql -U betterbooks -d betterbooks -c "SELECT 'Replica connection successful';"
```

### Step 3: Test Monitoring Stack

#### Prometheus (Metrics)
```bash
curl http://localhost:9090/-/healthy
# Should return: "Prometheus Server is Healthy."
```

#### Grafana (Dashboards)
```bash
curl http://localhost:3000/api/health
# Should return JSON with database: "ok"
```

#### Jaeger (Tracing)
```bash
curl -s http://localhost:16686 | grep -q "Jaeger UI" && echo "Jaeger UI accessible"
```

### Step 4: Test Service Health Endpoints

Each service exposes multiple health endpoints:

```bash
# Basic health
curl http://localhost:8000/health  # API Gateway
curl http://localhost:8001/health  # Context Service
curl http://localhost:8002/health  # LLM Gateway

# Detailed health with metrics
curl http://localhost:8001/health/detailed | jq

# Readiness checks
curl http://localhost:8001/health/ready
```

### Step 5: Test Advanced Database Features

#### Database Migrations Status
```bash
curl http://localhost:8001/admin/migrations | jq
```

#### Database Indexes Information
```bash
curl http://localhost:8001/admin/indexes | jq
```

#### Embedding Statistics
```bash
curl http://localhost:8001/embeddings/stats | jq
```

### Step 6: Test Metrics Collection

#### Service Metrics
```bash
curl http://localhost:8001/metrics  # Context Service metrics
curl http://localhost:8002/metrics  # LLM Gateway metrics
```

#### Prometheus Targets
Visit: http://localhost:9090/targets
All services should show "UP" status.

## 🖥️ Web Interfaces

Once everything is running, access these web interfaces:

### Monitoring Dashboard
- **Grafana**: http://localhost:3000 (admin/admin)
  - Pre-configured dashboards for all services
  - Real-time metrics and alerts
  - Service performance monitoring

### Distributed Tracing
- **Jaeger UI**: http://localhost:16686
  - Request flow visualization  
  - Performance bottleneck identification
  - Cross-service trace correlation

### Metrics & Alerts
- **Prometheus**: http://localhost:9090
  - Metrics queries and exploration
  - Alerting rules configuration
  - Service health monitoring

### Application Demo
- **Web Demo**: http://localhost:8080
  - Interactive interface for testing
  - Book processing and AI features

## 🔧 Production Features Enabled

Your local backend now includes these production-ready features:

### 1. **Structured Logging**
- JSON-formatted logs for all services
- Request correlation IDs across services
- Contextual fields for debugging
- Configurable log levels

### 2. **Comprehensive Health Checks**
- Basic liveness probes (`/health`)
- Detailed health with metrics (`/health/detailed`)
- Readiness checks (`/health/ready`)
- Dependency health validation

### 3. **Prometheus Metrics**
- HTTP request metrics (rate, duration, status)
- Business metrics (embeddings, users)
- LLM performance metrics (tokens, latency)
- System resource monitoring (CPU, memory)

### 4. **Distributed Tracing**
- Automatic request tracing with Jaeger
- Cross-service trace correlation  
- Performance bottleneck identification
- Database query tracing

### 5. **Database Optimizations**
- **Connection Pooling**: PgBouncer for efficient connections
- **Read Replicas**: Separate read/write workloads
- **Advanced Indexing**: 20+ optimized indexes including HNSW vector indexes
- **Database Migrations**: Version-controlled schema changes with rollback

### 6. **High Availability**
- Primary-replica database architecture
- Connection pooling for scalability
- Health-based service discovery
- Graceful failure handling

## 🚨 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check container logs
docker-compose logs <service-name>

# Restart specific service
docker-compose restart <service-name>

# Full restart
docker-compose down && docker-compose up --build
```

#### Database Connection Issues
```bash
# Check PostgreSQL logs
docker-compose logs postgres_primary

# Test direct connection
docker exec betterbooks-postgres_primary-1 psql -U betterbooks -d betterbooks -c "SELECT 1;"
```

#### Import Module Errors
This indicates the shared modules aren't copied correctly. Services will auto-restart and fix this.

#### Port Conflicts
```bash
# Check what's using ports
lsof -i :8000-8004
lsof -i :5432,5433,6432,6433

# Stop conflicting processes or change ports in docker-compose.yml
```

### Performance Optimization

#### For Development
```bash
# Reduce resource usage
docker-compose up api_gateway context_service llm_gateway postgres_primary redis
```

#### For Full Testing
```bash
# Start everything including monitoring
docker-compose up --build
```

### Log Analysis

#### View Structured Logs
```bash
# Service logs with structured JSON
docker-compose logs context_service | jq

# Follow logs in real-time
docker-compose logs -f api_gateway
```

#### Trace Specific Requests
1. Make a request with a specific header
2. Search for the request ID in logs
3. View the trace in Jaeger UI

## 📈 Next Steps

Once your backend is running:

1. **Explore Monitoring**: Visit Grafana dashboards to see real-time metrics
2. **Test Tracing**: Make requests and view traces in Jaeger
3. **Database Admin**: Use the admin endpoints to manage migrations and indexes
4. **Load Testing**: Use the web demo to generate test data and observe metrics
5. **Production Prep**: Review the logging and monitoring documentation

## 🎯 Success Indicators

Your backend is fully operational when:

- ✅ All containers show "Up" status in `docker-compose ps`
- ✅ All services return 200 OK for `/health` endpoints
- ✅ Grafana dashboards show service metrics
- ✅ Jaeger UI shows request traces
- ✅ Prometheus shows all targets as "UP"
- ✅ Database migrations are applied successfully
- ✅ Web demo is accessible and functional

**Congratulations!** You now have a production-ready, fully monitored, and optimized BetterBooks backend running locally. 🎉