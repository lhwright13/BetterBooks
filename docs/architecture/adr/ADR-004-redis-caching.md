# ADR-004: Redis for Caching and Session Management

## Status
Accepted

## Date
2025-01-05

## Context
BetterBooks needs a high-performance caching solution for:
- LLM API response caching (expensive Gemini API calls)
- Session management across microservices
- Rate limiting counters
- Semantic similarity cache for embeddings
- Temporary data storage for audio processing
- Real-time feature support (future WebSocket state)

The caching solution must support:
- Sub-millisecond latency
- TTL (Time To Live) management
- Distributed access across services
- Various data structures (strings, hashes, sets, sorted sets)
- Pub/Sub for real-time features

## Decision Drivers
- **Performance**: Need sub-millisecond cache access
- **Data Structures**: Support for diverse caching patterns
- **Reliability**: Proven solution with high availability options
- **Ecosystem**: Strong Python support and client libraries
- **Operational Simplicity**: Easy to deploy and manage
- **Cost**: Open-source with reasonable resource requirements

## Considered Options
1. **Redis** - In-memory data structure store
2. **Memcached** - Simple distributed memory caching system
3. **Hazelcast** - In-memory computing platform
4. **Database caching** - PostgreSQL query result caching
5. **Local memory caching** - In-process caching per service

## Decision Outcome
Chosen option: **Redis**, because it provides the best combination of performance, features, and operational simplicity for our diverse caching needs.

### Positive Consequences
- Excellent performance (100k+ ops/second)
- Rich data structures (strings, hashes, lists, sets, sorted sets)
- Built-in TTL support for automatic expiration
- Pub/Sub for real-time features
- Persistence options for durability
- Mature ecosystem with excellent Python support (redis-py)
- Supports clustering for horizontal scaling
- Can serve multiple purposes (cache, session store, rate limiter)

### Negative Consequences
- Another service to operate and monitor
- Memory-intensive (all data in RAM)
- Single-threaded per shard (though rarely a bottleneck)
- Requires careful memory management

## Pros and Cons of the Options

### Option 1: Redis
- **Pros:**
  - Rich data structures
  - Excellent performance
  - TTL support
  - Pub/Sub capabilities
  - Persistence options
  - Great Python support
  - Can handle multiple use cases
  - Active community
- **Cons:**
  - Memory intensive
  - Another service to manage
  - Single-threaded per core

### Option 2: Memcached
- **Pros:**
  - Very simple and fast
  - Multi-threaded
  - Lower memory overhead
  - Battle-tested
- **Cons:**
  - Only key-value storage
  - No persistence
  - No data structures
  - No pub/sub
  - Limited TTL options

### Option 3: Hazelcast
- **Pros:**
  - Distributed computing features
  - Auto-discovery and clustering
  - Rich features
- **Cons:**
  - More complex than needed
  - Java-centric
  - Higher resource usage
  - Steeper learning curve

### Option 4: Database caching
- **Pros:**
  - No additional service
  - Integrated with main data
  - Transactional consistency
- **Cons:**
  - Much slower than in-memory
  - Increases database load
  - Not suitable for temporary data
  - Limited caching patterns

### Option 5: Local memory caching
- **Pros:**
  - Fastest possible access
  - No network overhead
  - No additional service
- **Cons:**
  - Not shared across services
  - Lost on service restart
  - Increases service memory usage
  - Cache inconsistency issues

## Implementation Details

### Redis Usage Patterns

#### 1. LLM Response Caching
```python
# Semantic caching with TTL
cache_key = f"llm:{hash(prompt)}"
cached = redis.get(cache_key)
if not cached:
    response = llm.generate(prompt)
    redis.setex(cache_key, 3600, response)  # 1 hour TTL
```

#### 2. Session Management
```python
# User session storage
session_key = f"session:{session_id}"
redis.hset(session_key, mapping={
    "user_id": user_id,
    "created_at": timestamp
})
redis.expire(session_key, 86400)  # 24 hour sessions
```

#### 3. Rate Limiting
```python
# API rate limiting with sliding window
rate_key = f"rate:{user_id}:{endpoint}"
redis.incr(rate_key)
redis.expire(rate_key, 60)  # 1 minute window
```

#### 4. Semantic Cache Index
```python
# Store similarity scores for cache hits
similarity_key = f"similarity:{content_hash}"
redis.zadd(similarity_key, {cache_id: similarity_score})
```

### Configuration
- **Docker Compose**: Redis service with persistence and memory limits
- **Connection Pooling**: Redis connection pool per service
- **Memory Policy**: allkeys-lru for automatic eviction
- **Persistence**: AOF (Append Only File) for durability
- **Max Memory**: 256MB for development, scaled for production

### Redis Service Configuration
```yaml
redis:
  image: redis:7-alpine
  ports:
    - "6379:6379"
  volumes:
    - redis_data:/data
  command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
```

## Links
- [ADR-003: PostgreSQL with pgvector](ADR-003-postgresql-pgvector.md)
- [Semantic Cache Implementation](/core/infrastructure/semantic_cache.py)
- [Redis Configuration](/docker-compose.yml)

## Notes
Redis has proven to be an excellent choice for our caching needs, handling millions of operations per day with minimal latency. The semantic caching implementation using Redis has reduced LLM API costs by approximately 40% through intelligent response caching.