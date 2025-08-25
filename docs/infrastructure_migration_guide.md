# Infrastructure Migration Guide

This guide covers migrating to the new EchoWright infrastructure components: rate limiting, usage analytics, and audio pipeline.

## Overview

The infrastructure upgrade adds three critical components:

```mermaid
graph TD
    A[Existing API Gateway] --> B[Rate Limiting System]
    A --> C[Usage Analytics System] 
    A --> D[Audio Pipeline System]
    
    B --> E[Redis DB 2]
    C --> F[Redis DB 1 + PostgreSQL]
    D --> G[Redis DB 3 + TTS Service]
    
    H[Mobile Apps] --> A
    I[Web Clients] --> A
    J[Admin Dashboard] --> A
    
    K[Teacher Insights] --> C
    L[Real-time Streaming] --> D
    M[Subscription Management] --> B
```

## Prerequisites

### System Requirements
- **Redis 6.0+** with multi-database support
- **PostgreSQL 13+** with JSONB support
- **Python 3.8+** with async support
- **Memory**: Additional 1GB RAM for Redis caching
- **Storage**: 10GB+ for analytics data retention

### Dependency Installation
```bash
pip install redis[hiredis] asyncpg fastapi[all] prometheus-client
pip install sentence-transformers webrtcvad librosa soundfile
```

## Step 1: Redis Multi-Database Setup

### Configure Redis Instances
```bash
# redis.conf additions
databases 16
maxmemory 2gb
maxmemory-policy allkeys-lru

# Enable persistence for analytics
save 900 1
save 300 10
save 60 10000
```

### Validate Redis Setup
```bash
redis-cli
> SELECT 1
OK
> SELECT 2  
OK
> SELECT 3
OK
```

## Step 2: Database Migration

### Run Analytics Migration
```bash
# Execute the analytics system migration
psql -d betterbooks -f core/database/migrations/V007_20250125_analytics_system.sql

# Verify tables were created
psql -d betterbooks -c "\\dt analytics_*"
```

### Expected Migration Output
```sql
analytics_events
analytics_user_engagement  
analytics_persona_effectiveness
analytics_content_consumption
analytics_realtime_cache
```

### Test Migration Success
```bash
# Insert test event
psql -d betterbooks -c "
INSERT INTO analytics_events (event_id, event_type, user_id, metadata) 
VALUES ('test-123', 'migration_test', 'test_user', '{\"version\": \"1.0\"}');
"

# Verify insertion
psql -d betterbooks -c "SELECT COUNT(*) FROM analytics_events WHERE event_type = 'migration_test';"
```

## Step 3: Environment Configuration

### New Environment Variables
Add to your environment or `.env` file:

```bash
# Rate Limiting Configuration
RATE_LIMITER_REDIS_URL=redis://localhost:6379/2
RATE_LIMITER_ENABLED=true
RATE_LIMITER_DEFAULT_TIER=FREE

# Usage Analytics Configuration
ANALYTICS_DATABASE_URL=postgresql://user:pass@localhost/betterbooks
ANALYTICS_REDIS_URL=redis://localhost:6379/1
ANALYTICS_BATCH_SIZE=100
ANALYTICS_BATCH_INTERVAL=30
ANALYTICS_RETENTION_DAYS=365
ANALYTICS_HASH_USER_IDS=true

# Audio Pipeline Configuration
AUDIO_PIPELINE_REDIS_URL=redis://localhost:6379/3
AUDIO_PIPELINE_ENABLED=true
AUDIO_PIPELINE_TTS_CACHE_TTL=3600
TTS_SERVICE_URL=http://localhost:8003
VOICE_ACTIVITY_DETECTION=webrtcvad
STT_MODEL_SIZE=base
AUDIO_DEFAULT_QUALITY=medium
```

### Service-Specific Variables
```bash
# For API Gateway
ENABLE_RATE_LIMITING=true
ENABLE_ANALYTICS=true  
ENABLE_AUDIO_PIPELINE=true

# For development/testing
RATE_LIMITER_BYPASS_PATHS="/health,/metrics"
ANALYTICS_DEBUG_MODE=false
AUDIO_PIPELINE_DEBUG=false
```

## Step 4: Code Integration

### Import New Components
Update your service imports:

```python
# Before
from core.infrastructure import (
    setup_logging, setup_metrics, setup_error_handling
)

# After  
from core.infrastructure import (
    setup_logging, setup_metrics, setup_error_handling,
    setup_rate_limiting, setup_usage_analytics, setup_audio_pipeline
)
```

### API Gateway Integration
Add to your `main.py`:

```python
# Rate limiting setup
if redis_client and os.getenv("ENABLE_RATE_LIMITING", "true").lower() == "true":
    rate_limiter = setup_rate_limiting(app, redis_client)
    logger.info("Rate limiting enabled")

# Usage analytics setup
if os.getenv("ENABLE_ANALYTICS", "true").lower() == "true":
    analytics_config = AnalyticsConfig(
        batch_size=int(os.getenv("ANALYTICS_BATCH_SIZE", "100")),
        batch_interval_seconds=int(os.getenv("ANALYTICS_BATCH_INTERVAL", "30")),
        enable_real_time=True
    )
    analytics_collector = setup_usage_analytics(
        app, redis_client, DATABASE_URL, config=analytics_config
    )
    logger.info("Usage analytics enabled")

# Audio pipeline setup
if os.getenv("ENABLE_AUDIO_PIPELINE", "true").lower() == "true":
    audio_config = AudioConfig(
        default_quality=StreamingQuality.MEDIUM,
        enable_caching=True,
        cache_ttl=int(os.getenv("AUDIO_PIPELINE_TTS_CACHE_TTL", "3600"))
    )
    audio_processor = setup_audio_pipeline(
        app, redis_client, cache=semantic_cache, config=audio_config
    )
    logger.info("Audio pipeline enabled")
```

## Step 5: Testing Migration

### Health Check Validation
```bash
# Test basic health endpoints
curl "http://localhost:8000/health/detailed"

# Test new infrastructure health checks
curl "http://localhost:8000/admin/rate-limiter/health"
curl "http://localhost:8000/admin/analytics/health"  
curl "http://localhost:8000/admin/audio/health"
```

### Functional Testing

#### Rate Limiting Test
```bash
# Test rate limiting with multiple requests
for i in {1..25}; do
  curl -X POST "http://localhost:8000/complete" \
    -H "Authorization: Bearer YOUR_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"prompt": "Test message"}'
  echo "Request $i completed"
done
```

#### Analytics Test
```bash
# Generate test analytics events
curl -X POST "http://localhost:8000/admin/test-analytics" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "AI_CONVERSATION_START",
    "user_id": "test_user_123",
    "persona_id": "shakespeare_tutor"
  }'

# Check events were recorded
curl "http://localhost:8000/analytics/users/test_user_123/engagement?period=1d"
```

#### Audio Pipeline Test  
```bash
# Test TTS generation
curl -X POST "http://localhost:8000/admin/test-audio-tts" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello from the new audio pipeline!",
    "voice": "neural_sarah"
  }'

# Test WebSocket streaming (using wscat)
wscat -c "ws://localhost:8000/audio/stream/test_session"
```

## Step 6: Monitoring Setup

### Prometheus Metrics
Add to your monitoring configuration:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'echowright-api-gateway'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

### Key Metrics to Monitor
```promql
# Rate limiting metrics
rate_limit_requests_total{operation_type="LLM_INTERACTION"}
rate_limit_exceeded_total{tier="FREE"}

# Analytics metrics  
analytics_events_total{event_type="AI_CONVERSATION_START"}
analytics_batch_processing_duration

# Audio pipeline metrics
audio_streams_active
audio_tts_requests_total{voice="neural_sarah"}
```

### Dashboard Queries
```promql
# User engagement rate
rate(analytics_events_total{event_type="SESSION_START"}[5m])

# Rate limit violations by tier
sum by (tier) (rate(rate_limit_exceeded_total[5m]))

# Active audio streams
audio_streams_active

# TTS cache hit rate
rate(audio_cache_hits_total[5m]) / rate(audio_cache_requests_total[5m])
```

## Step 7: Performance Optimization

### Redis Memory Optimization
```bash
# Monitor Redis memory usage
redis-cli INFO memory

# Optimize memory settings based on usage
redis-cli CONFIG SET maxmemory-samples 10
redis-cli CONFIG SET hash-max-ziplist-entries 512
```

### Database Query Optimization
```sql
-- Monitor analytics query performance
EXPLAIN ANALYZE SELECT * FROM analytics_events 
WHERE user_id = 'test_user' AND timestamp >= NOW() - INTERVAL '24 hours';

-- Verify index usage
SELECT schemaname, tablename, indexname, idx_tup_read, idx_tup_fetch 
FROM pg_stat_user_indexes WHERE schemaname = 'public';
```

### Connection Pool Tuning
```python
# Optimize PostgreSQL connection pool
DATABASE_POOL_SIZE = 20
DATABASE_MAX_OVERFLOW = 30
DATABASE_POOL_TIMEOUT = 30

# Redis connection pool optimization  
REDIS_POOL_SIZE = 50
REDIS_CONNECTION_TIMEOUT = 5
```

## Step 8: Rollback Plan

### Disable Components
If issues occur, disable components via environment variables:

```bash
# Disable problematic components
ENABLE_RATE_LIMITING=false
ENABLE_ANALYTICS=false
ENABLE_AUDIO_PIPELINE=false
```

### Database Rollback
```sql
-- Remove analytics tables if needed (CAUTION: DATA LOSS)
DROP TABLE IF EXISTS analytics_events CASCADE;
DROP TABLE IF EXISTS analytics_user_engagement CASCADE;
DROP TABLE IF EXISTS analytics_persona_effectiveness CASCADE;
DROP TABLE IF EXISTS analytics_content_consumption CASCADE;
DROP TABLE IF EXISTS analytics_realtime_cache CASCADE;
DROP MATERIALIZED VIEW IF EXISTS analytics_top_personas CASCADE;
```

### Redis Cleanup
```bash
# Clear specific Redis databases
redis-cli -n 1 FLUSHDB  # Analytics
redis-cli -n 2 FLUSHDB  # Rate limiting  
redis-cli -n 3 FLUSHDB  # Audio pipeline
```

## Common Migration Issues

### Issue 1: Redis Connection Errors
**Symptoms**: `ConnectionError: Error connecting to Redis`

**Solution**:
```bash
# Check Redis is running
redis-cli ping

# Verify database configuration
redis-cli CONFIG GET databases

# Test specific database connections
redis-cli -n 1 ping
redis-cli -n 2 ping  
redis-cli -n 3 ping
```

### Issue 2: Analytics Migration Fails
**Symptoms**: `relation "analytics_events" does not exist`

**Solution**:
```bash
# Check migration was applied
psql -d betterbooks -c "SELECT version FROM migrations WHERE version LIKE '%analytics%';"

# Re-run migration if needed
psql -d betterbooks -f core/database/migrations/V007_20250125_analytics_system.sql
```

### Issue 3: High Memory Usage
**Symptoms**: Redis or PostgreSQL memory exhaustion

**Solution**:
```bash
# Reduce batch sizes
export ANALYTICS_BATCH_SIZE=50
export RATE_LIMITER_WINDOW_SIZE=3600

# Enable Redis memory optimization
redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

### Issue 4: Audio Streaming Failures
**Symptoms**: WebSocket connections fail or audio quality is poor

**Solution**:
```bash
# Check TTS service connectivity
curl "http://localhost:8003/health"

# Reduce audio quality
export AUDIO_DEFAULT_QUALITY=low

# Increase buffer sizes
export AUDIO_PIPELINE_BUFFER_SIZE=65536
```

## Post-Migration Verification

### Data Validation Checklist
- [ ] Analytics events are being collected
- [ ] Rate limits are enforced correctly
- [ ] Audio streaming works via WebSocket
- [ ] Prometheus metrics are exposed
- [ ] Health checks return success
- [ ] Database migrations completed successfully
- [ ] Redis databases are accessible
- [ ] User subscriptions affect rate limits
- [ ] Teacher analytics are available
- [ ] Audio quality adapts to connection

### Performance Validation
```bash
# Load test rate limiting
./scripts/test_rate_limiting_load.py

# Test analytics under load  
./scripts/test_analytics_load.py

# Audio streaming stress test
./scripts/test_audio_streaming_load.py
```

## Support and Troubleshooting

### Debug Mode
Enable debug logging for troubleshooting:

```bash
export LOG_LEVEL=DEBUG
export RATE_LIMITER_DEBUG=true
export ANALYTICS_DEBUG_MODE=true
export AUDIO_PIPELINE_DEBUG=true
```

### Log Locations
Monitor these logs during migration:
- Application logs: `/var/log/echowright/api_gateway.log`
- Redis logs: `/var/log/redis/redis-server.log`
- PostgreSQL logs: `/var/log/postgresql/postgresql.log`

### Support Resources
- Infrastructure documentation: `core/infrastructure/README.md`
- Component-specific docs: `core/infrastructure/*/README.md`
- Testing scripts: `scripts/test_*.py`
- Monitoring dashboards: Grafana + Prometheus setup

This migration guide ensures a smooth transition to the enhanced EchoWright infrastructure with minimal downtime and maximum reliability.