# Runbook: Deployment Rollback

## Overview
This runbook provides procedures for rolling back deployments when issues are detected after a release to production.

## When to Rollback
- Critical bugs affecting core functionality
- Performance regression > 50%
- Security vulnerabilities introduced
- Data corruption or loss
- Service availability < 95%

## Rollback Decision Matrix

| Severity | Impact | Time Since Deploy | Action |
|----------|--------|------------------|---------|
| Critical | High | < 1 hour | Immediate rollback |
| Major | Medium | < 4 hours | Rollback after assessment |
| Minor | Low | Any | Fix forward or scheduled rollback |

## Pre-Rollback Checklist

### 1. Assess Current State
```bash
# Check all service health
curl -s http://localhost:8000/health | jq '.status'
curl -s http://localhost:8001/health | jq '.status'
curl -s http://localhost:8002/health | jq '.status'

# Check error rates in logs
docker-compose logs --since=1h | grep -c ERROR

# Check system resources
docker stats --no-stream
```

### 2. Identify Rollback Target
```bash
# Show recent Docker images
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedSince}}"

# Show git commit history
git log --oneline -10

# Check deployment history
ls -la deployment-history/
```

### 3. Notify Stakeholders
- [ ] Engineering team
- [ ] Product team
- [ ] Customer support
- [ ] Update status page if applicable

## Rollback Procedures

### Docker Compose Rollback (Local/Staging)

#### Step 1: Stop Current Services
```bash
# Stop all services gracefully
docker-compose down

# Force stop if needed
docker-compose kill
```

#### Step 2: Rollback to Previous Version
```bash
# Checkout previous commit
git log --oneline -5
git checkout <previous_commit_hash>

# Or use previous tagged release
git tag --list --sort=-version:refname | head -5
git checkout <previous_tag>
```

#### Step 3: Restore Database (if needed)
```bash
# Check if schema changes were made
git diff HEAD~1 core/database/migrations/

# If schema changes exist, restore database
docker-compose exec postgres_primary pg_dump -U betterbooks betterbooks > pre_rollback_backup.sql

# Restore from backup before deployment
docker-compose exec -T postgres_primary psql -U betterbooks betterbooks < deployment_backup.sql
```

#### Step 4: Start Previous Version
```bash
# Rebuild images with previous code
docker-compose build --no-cache

# Start services
docker-compose up -d

# Wait for health checks
sleep 30
docker-compose ps
```

#### Step 5: Verify Rollback
```bash
# Check all services are healthy
./scripts/health_check.sh

# Run smoke tests
curl -X POST http://localhost:8000/complete \
  -H 'Content-Type: application/json' \
  -d '{"prompt": "test", "config": "default"}'

# Check database connectivity
docker-compose exec postgres_primary pg_isready
```

### Kubernetes Rollback (Production)

#### Step 1: Check Deployment History
```bash
# Show deployment history
kubectl rollout history deployment/api-gateway
kubectl rollout history deployment/context-service
kubectl rollout history deployment/llm-gateway

# Check current revision
kubectl get deployments -o wide
```

#### Step 2: Rollback Services
```bash
# Rollback to previous revision
kubectl rollout undo deployment/api-gateway
kubectl rollout undo deployment/context-service
kubectl rollout undo deployment/llm-gateway
kubectl rollout undo deployment/tts-service

# Or rollback to specific revision
kubectl rollout undo deployment/api-gateway --to-revision=3
```

#### Step 3: Monitor Rollback
```bash
# Watch rollback progress
kubectl rollout status deployment/api-gateway
kubectl rollout status deployment/context-service

# Check pod status
kubectl get pods -w

# Check service endpoints
kubectl get services
```

#### Step 4: Verify Production Health
```bash
# Check ingress endpoints
curl -s https://api.betterbooks.com/health

# Check metrics
kubectl port-forward svc/prometheus 9090:9090
# Browse to http://localhost:9090
```

### Database Rollback

#### Schema Rollback
```bash
# If database migrations were run, they need to be rolled back
# Check migration history
docker-compose exec postgres_primary psql -U betterbooks -c "
SELECT * FROM schema_migrations ORDER BY version DESC LIMIT 5;"

# Run down migrations (if available)
python -m alembic downgrade -1

# Or restore from backup
docker-compose exec -T postgres_primary psql -U betterbooks betterbooks < pre_deployment_backup.sql
```

#### Data Rollback (High Risk)
```bash
# Only if data corruption occurred
# STOP ALL SERVICES FIRST
docker-compose down

# Restore from point-in-time backup
# This will lose data created after backup time
docker-compose exec -T postgres_primary psql -U betterbooks betterbooks < known_good_backup.sql

# Restart services
docker-compose up -d
```

### File System Rollback

#### Restore Audio Files
```bash
# If audio files were corrupted or lost
# Stop services
docker-compose down

# Restore book files from backup
rsync -av backup/book_files/ ./book_files/

# Restart services
docker-compose up -d
```

#### Restore Configuration
```bash
# Restore configuration files
cp backup/config/ ./config/
cp backup/.env ./

# Rebuild with restored config
docker-compose build --no-cache
docker-compose up -d
```

## Post-Rollback Procedures

### 1. Verify System Health
```bash
# Run comprehensive health checks
./scripts/health_check_comprehensive.sh

# Check all endpoints
curl http://localhost:8000/health/detailed
curl http://localhost:8001/health/detailed
curl http://localhost:8002/health/detailed

# Check database integrity
docker-compose exec postgres_primary psql -U betterbooks -c "
SELECT count(*) FROM embeddings;
SELECT count(*) FROM users;
SELECT count(*) FROM books;"
```

### 2. Monitor Performance
```bash
# Watch logs for errors
docker-compose logs -f | grep -E 'ERROR|WARN'

# Monitor response times
watch -n 10 'curl -w "Time: %{time_total}s\n" -s -o /dev/null http://localhost:8000/health'

# Check resource usage
watch -n 5 'docker stats --no-stream'
```

### 3. Update Monitoring
- Reset alerts that may have fired
- Update dashboards to show rollback event
- Document any data loss or impacts

### 4. Communication
- [ ] Notify stakeholders rollback is complete
- [ ] Update status page
- [ ] Inform users if necessary
- [ ] Schedule post-mortem meeting

## Emergency Rollback Script

Create a quick rollback script for emergencies:

```bash
#!/bin/bash
# emergency_rollback.sh

set -e

echo "🚨 EMERGENCY ROLLBACK INITIATED"
echo "Current time: $(date)"

# Stop services
echo "Stopping services..."
docker-compose down

# Checkout previous commit
echo "Rolling back code..."
git checkout HEAD~1

# Restore database if backup exists
if [ -f "emergency_backup.sql" ]; then
    echo "Restoring database..."
    docker-compose up -d postgres_primary
    sleep 10
    docker-compose exec -T postgres_primary psql -U betterbooks betterbooks < emergency_backup.sql
    docker-compose down
fi

# Start previous version
echo "Starting services..."
docker-compose build --no-cache
docker-compose up -d

# Wait and verify
echo "Waiting for services to start..."
sleep 30

echo "Checking health..."
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ Rollback successful - API Gateway healthy"
else
    echo "❌ Rollback failed - API Gateway not responding"
    exit 1
fi

echo "🎉 Emergency rollback complete!"
echo "Remember to:"
echo "1. Check all service health endpoints"
echo "2. Notify stakeholders"
echo "3. Schedule post-mortem"
```

## Prevention Strategies

### 1. Pre-Deployment
- Always create database backup before deployment
- Test deployments in staging first
- Use feature flags for risky changes
- Have rollback plan ready before deploying

### 2. Monitoring
- Set up alerts for error rates
- Monitor response times
- Track business metrics
- Use health checks extensively

### 3. Safe Deployment Practices
- Blue-green deployments
- Canary releases
- Circuit breakers
- Gradual rollouts

## Troubleshooting Failed Rollbacks

### Rollback Stuck
```bash
# Force kill all containers
docker kill $(docker ps -q)

# Clean up everything
docker system prune -f

# Start from scratch
git checkout <stable_commit>
docker-compose up --build -d
```

### Database Issues
```bash
# If database won't start after rollback
docker-compose down
docker volume rm betterbooks_postgres_data
docker volume create betterbooks_postgres_data

# Restore from known good backup
docker-compose up -d postgres_primary
sleep 10
docker-compose exec -T postgres_primary psql -U betterbooks betterbooks < full_backup.sql
```

### Configuration Issues
```bash
# Reset to default configuration
cp config/defaults/* config/local/
cp .env.example .env

# Update with correct values
vim .env

# Restart with clean config
docker-compose up --build -d
```

## Related Documents
- [Service Health Issues](service-health-issues.md)
- [Database Performance Issues](database-performance.md)
- [Deployment Checklist](../DEPLOYMENT_CHECKLIST.md)