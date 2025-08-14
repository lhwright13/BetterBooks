# Runbook: Database Performance Issues

## Overview
This runbook addresses PostgreSQL performance issues including slow queries, high connection usage, and pgvector search performance problems.

## Symptoms
- Slow API response times
- Database connection pool exhaustion
- High CPU usage on database server
- Timeout errors from services
- Slow vector similarity searches

## Initial Assessment

### 1. Check Database Status
```bash
# Check if PostgreSQL is responsive
docker-compose exec postgres_primary pg_isready

# Check current connections
docker-compose exec postgres_primary psql -U betterbooks -c "SELECT count(*) FROM pg_stat_activity;"

# Check database size
docker-compose exec postgres_primary psql -U betterbooks -c "SELECT pg_database_size('betterbooks')/1024/1024 as size_mb;"
```

### 2. Identify Slow Queries
```bash
# Show currently running queries
docker-compose exec postgres_primary psql -U betterbooks -c "
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';"

# Show slow queries from log
docker-compose exec postgres_primary psql -U betterbooks -c "
SELECT query, calls, mean_exec_time, max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;"
```

### 3. Check PgBouncer Pool Status
```bash
# Check pool statistics
docker-compose exec pgbouncer psql -h localhost -p 6432 -U betterbooks -d pgbouncer -c "SHOW POOLS;"

# Check client connections
docker-compose exec pgbouncer psql -h localhost -p 6432 -U betterbooks -d pgbouncer -c "SHOW CLIENTS;"

# Check server connections
docker-compose exec pgbouncer psql -h localhost -p 6432 -U betterbooks -d pgbouncer -c "SHOW SERVERS;"
```

## Common Issues and Solutions

### Issue 1: Connection Pool Exhaustion

#### Symptoms
- "too many connections" errors
- Services timing out waiting for connections
- PgBouncer showing all connections busy

#### Resolution Steps
1. **Check current connections:**
   ```bash
   # See what's using connections
   docker-compose exec postgres_primary psql -U betterbooks -c "
   SELECT application_name, count(*) 
   FROM pg_stat_activity 
   GROUP BY application_name;"
   ```

2. **Kill idle connections:**
   ```bash
   # Terminate idle connections older than 10 minutes
   docker-compose exec postgres_primary psql -U betterbooks -c "
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE state = 'idle' 
   AND state_change < now() - interval '10 minutes';"
   ```

3. **Increase pool size (temporary):**
   ```bash
   # Edit pgbouncer config
   docker-compose exec pgbouncer sh -c "echo 'max_client_conn = 200' >> /etc/pgbouncer/pgbouncer.ini"
   docker-compose restart pgbouncer
   ```

4. **Fix connection leaks in code:**
   - Check for missing connection.close() calls
   - Ensure proper connection pooling in services

### Issue 2: Slow Vector Similarity Searches

#### Symptoms
- Context retrieval taking > 1 second
- High CPU during embedding searches
- Timeout errors from context_service

#### Resolution Steps
1. **Check index usage:**
   ```bash
   # Verify pgvector indexes exist
   docker-compose exec postgres_primary psql -U betterbooks -c "
   SELECT indexname, indexdef 
   FROM pg_indexes 
   WHERE tablename = 'embeddings';"
   ```

2. **Analyze query plan:**
   ```bash
   # Check if index is being used
   docker-compose exec postgres_primary psql -U betterbooks -c "
   EXPLAIN ANALYZE 
   SELECT * FROM embeddings 
   ORDER BY embedding <-> '[0.1, 0.2, ...]'::vector 
   LIMIT 10;"
   ```

3. **Rebuild indexes if needed:**
   ```bash
   # Rebuild HNSW index with better parameters
   docker-compose exec postgres_primary psql -U betterbooks -c "
   DROP INDEX IF EXISTS idx_embeddings_vector_hnsw;
   CREATE INDEX idx_embeddings_vector_hnsw ON embeddings 
   USING hnsw (embedding vector_cosine_ops) 
   WITH (m = 32, ef_construction = 128);"
   ```

4. **Vacuum and analyze:**
   ```bash
   docker-compose exec postgres_primary psql -U betterbooks -c "
   VACUUM ANALYZE embeddings;"
   ```

### Issue 3: High Database CPU Usage

#### Symptoms
- Database container using > 80% CPU
- All queries running slowly
- System load average high

#### Resolution Steps
1. **Identify CPU-intensive queries:**
   ```bash
   docker-compose exec postgres_primary psql -U betterbooks -c "
   SELECT query, calls, total_exec_time, mean_exec_time
   FROM pg_stat_statements
   WHERE total_exec_time > 10000
   ORDER BY total_exec_time DESC
   LIMIT 5;"
   ```

2. **Check for missing indexes:**
   ```bash
   # Find tables with sequential scans
   docker-compose exec postgres_primary psql -U betterbooks -c "
   SELECT schemaname, tablename, seq_scan, seq_tup_read, idx_scan
   FROM pg_stat_user_tables
   WHERE seq_scan > idx_scan
   ORDER BY seq_tup_read DESC;"
   ```

3. **Add missing indexes:**
   ```bash
   # Example: Add index on frequently queried column
   docker-compose exec postgres_primary psql -U betterbooks -c "
   CREATE INDEX CONCURRENTLY idx_books_title ON books(title);"
   ```

4. **Tune PostgreSQL settings:**
   ```bash
   # Increase shared buffers and work memory
   docker-compose exec postgres_primary psql -U betterbooks -c "
   ALTER SYSTEM SET shared_buffers = '512MB';
   ALTER SYSTEM SET work_mem = '16MB';
   SELECT pg_reload_conf();"
   ```

### Issue 4: Database Disk Space Issues

#### Symptoms
- "could not extend file" errors
- Database writes failing
- Backup failures

#### Resolution Steps
1. **Check disk usage:**
   ```bash
   docker-compose exec postgres_primary df -h /var/lib/postgresql/data
   ```

2. **Find large tables:**
   ```bash
   docker-compose exec postgres_primary psql -U betterbooks -c "
   SELECT nspname || '.' || relname AS relation,
          pg_size_pretty(pg_total_relation_size(C.oid)) AS total_size
   FROM pg_class C
   LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
   WHERE nspname NOT IN ('pg_catalog', 'information_schema')
   ORDER BY pg_total_relation_size(C.oid) DESC
   LIMIT 10;"
   ```

3. **Clean up old data:**
   ```bash
   # Delete old audit logs
   docker-compose exec postgres_primary psql -U betterbooks -c "
   DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '90 days';"
   
   # Vacuum to reclaim space
   docker-compose exec postgres_primary psql -U betterbooks -c "VACUUM FULL;"
   ```

4. **Increase volume size:**
   ```bash
   # Stop services
   docker-compose down
   
   # Backup data
   docker run --rm -v betterbooks_postgres_data:/data -v $(pwd):/backup ubuntu tar czf /backup/postgres_backup.tar.gz /data
   
   # Recreate with larger volume
   docker volume rm betterbooks_postgres_data
   docker volume create --opt size=20G betterbooks_postgres_data
   
   # Restore and restart
   docker run --rm -v betterbooks_postgres_data:/data -v $(pwd):/backup ubuntu tar xzf /backup/postgres_backup.tar.gz -C /
   docker-compose up -d
   ```

## Performance Monitoring Queries

### Connection Monitoring
```sql
-- Active connections by state
SELECT state, count(*) 
FROM pg_stat_activity 
GROUP BY state;

-- Long-running queries
SELECT pid, now() - query_start as duration, query 
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY duration DESC;

-- Connection wait times
SELECT wait_event_type, wait_event, count(*) 
FROM pg_stat_activity 
WHERE wait_event IS NOT NULL 
GROUP BY wait_event_type, wait_event;
```

### Index Usage Analysis
```sql
-- Unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY schemaname, tablename;

-- Index hit ratio
SELECT 
  sum(idx_blks_hit) / sum(idx_blks_hit + idx_blks_read) AS index_hit_ratio
FROM pg_statio_user_indexes;

-- Table cache hit ratio
SELECT 
  sum(heap_blks_hit) / sum(heap_blks_hit + heap_blks_read) AS cache_hit_ratio
FROM pg_statio_user_tables;
```

### Vector Search Performance
```sql
-- Average embedding search time
SELECT 
  avg(mean_exec_time) as avg_time_ms,
  max(max_exec_time) as max_time_ms
FROM pg_stat_statements
WHERE query LIKE '%embedding <->%';

-- Embedding table statistics
SELECT 
  n_live_tup as live_rows,
  n_dead_tup as dead_rows,
  last_vacuum,
  last_analyze
FROM pg_stat_user_tables
WHERE tablename = 'embeddings';
```

## Optimization Procedures

### Emergency Performance Recovery
```bash
# 1. Kill all idle connections
docker-compose exec postgres_primary psql -U betterbooks -c "
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle';"

# 2. Reset PgBouncer
docker-compose restart pgbouncer

# 3. Clear query cache
docker-compose exec postgres_primary psql -U betterbooks -c "DISCARD ALL;"

# 4. Vacuum and analyze all tables
docker-compose exec postgres_primary psql -U betterbooks -c "VACUUM ANALYZE;"

# 5. Reset statistics
docker-compose exec postgres_primary psql -U betterbooks -c "
SELECT pg_stat_reset();
SELECT pg_stat_statements_reset();"
```

### Scheduled Maintenance
```bash
# Weekly maintenance script
#!/bin/bash

# Vacuum and analyze
docker-compose exec postgres_primary psql -U betterbooks -c "VACUUM ANALYZE;"

# Reindex for performance
docker-compose exec postgres_primary psql -U betterbooks -c "REINDEX DATABASE betterbooks;"

# Update statistics
docker-compose exec postgres_primary psql -U betterbooks -c "ANALYZE;"

# Clean old data
docker-compose exec postgres_primary psql -U betterbooks -c "
DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '90 days';
DELETE FROM sessions WHERE expires_at < NOW();"
```

## Prevention Strategies

1. **Regular Monitoring**
   - Set up alerts for slow queries
   - Monitor connection pool usage
   - Track index usage statistics

2. **Capacity Planning**
   - Review growth trends monthly
   - Plan index maintenance windows
   - Scale resources proactively

3. **Code Reviews**
   - Check for N+1 query problems
   - Ensure proper connection handling
   - Validate index usage in new queries

## Escalation Path

1. Try quick fixes from this runbook
2. Check application logs for query patterns
3. Review recent schema changes
4. Contact DBA or database expert
5. Consider scaling database resources

## Related Documents
- [Service Health Issues](service-health-issues.md)
- [High Memory Usage](high-memory-usage.md)
- [Deployment Rollback](deployment-rollback.md)