# Operational Runbooks

This directory contains operational runbooks for the BetterBooks platform. Runbooks provide step-by-step procedures for diagnosing and resolving common operational issues.

## Available Runbooks

| Runbook | Purpose | Severity | Estimated Time |
|---------|---------|----------|----------------|
| [Service Health Issues](service-health-issues.md) | Diagnose and fix service health problems | High | 15-30 min |
| [Database Performance](database-performance.md) | Resolve PostgreSQL performance issues | High | 30-60 min |
| [Deployment Rollback](deployment-rollback.md) | Rollback failed deployments | Critical | 10-20 min |

## How to Use Runbooks

1. **Identify the Issue**: Match symptoms to the appropriate runbook
2. **Follow Initial Assessment**: Run diagnostic commands to understand scope
3. **Apply Solutions**: Follow resolution steps in order
4. **Verify Fix**: Confirm issue is resolved
5. **Document**: Record any deviations or additional steps needed

## General Troubleshooting Steps

Before diving into specific runbooks, try these general steps:

### 1. Quick Health Check
```bash
# Check all service status
./scripts/health_check.sh

# Check container status
docker-compose ps

# Check recent logs
docker-compose logs --tail=50
```

### 2. System Status
```bash
# Check system resources
top -n 1
df -h
free -m

# Check Docker resources
docker system df
docker stats --no-stream
```

### 3. Network Connectivity
```bash
# Test internal service connectivity
curl -s http://localhost:8000/health
curl -s http://localhost:8001/health
curl -s http://localhost:8002/health

# Test database connectivity
docker-compose exec postgres_primary pg_isready
docker-compose exec redis redis-cli ping
```

## Emergency Procedures

### Critical System Down
If the entire system is down:

1. **Stop all services**: `docker-compose down`
2. **Check system resources**: Ensure sufficient CPU, memory, disk
3. **Start core services first**: `docker-compose up -d postgres_primary redis`
4. **Start application services**: `docker-compose up -d`
5. **Verify health**: Check all endpoints

### Data Loss Prevention
Before making any destructive changes:

1. **Create backup**: `./scripts/backup.sh`
2. **Document current state**: Save logs, configs, database dumps
3. **Test in staging**: If possible, reproduce issue in non-prod
4. **Have rollback plan**: Know how to undo changes

## Escalation Guidelines

### Level 1: Self-Service (0-30 minutes)
- Follow relevant runbook procedures
- Check service logs and metrics
- Apply standard fixes

### Level 2: Team Support (30-60 minutes)
- Consult with team members
- Check recent deployments or changes
- Review monitoring dashboards

### Level 3: Expert Assistance (1+ hours)
- Contact service owners
- Engage database or infrastructure experts
- Consider rolling back recent changes

### Level 4: Crisis Mode
- Page on-call engineer
- Activate incident response team
- Consider service degradation/outage communication

## Runbook Maintenance

### Regular Updates
- Review and update procedures quarterly
- Test runbooks in staging environments
- Incorporate lessons learned from incidents
- Update contact information and escalation paths

### New Runbook Creation
When creating new runbooks, include:
- Clear problem description and symptoms
- Step-by-step diagnostic procedures
- Multiple resolution options
- Verification steps
- Prevention strategies

### Template Structure
```markdown
# Runbook: [Issue Type]

## Overview
Brief description of the issue and when to use this runbook.

## Symptoms
- Observable signs of the problem
- Error messages or metrics to look for

## Initial Assessment
Diagnostic commands to understand the scope and impact.

## Common Issues and Solutions
Specific problems with step-by-step resolution procedures.

## Prevention
How to avoid this issue in the future.

## Escalation Path
When and how to escalate.
```

## Tools and Scripts

### Diagnostic Scripts
- `./scripts/health_check.sh` - Comprehensive health check
- `./scripts/performance_check.sh` - Performance diagnostics
- `./scripts/log_analysis.sh` - Log parsing and analysis

### Recovery Scripts  
- `./scripts/backup.sh` - Create system backup
- `./scripts/restore.sh` - Restore from backup
- `./scripts/emergency_rollback.sh` - Quick rollback procedure

### Monitoring Commands
```bash
# Watch service logs in real-time
docker-compose logs -f | grep -E 'ERROR|WARN'

# Monitor system resources
watch -n 5 'docker stats --no-stream'

# Check service response times
watch -n 10 'curl -w "Time: %{time_total}s\n" -s -o /dev/null http://localhost:8000/health'
```

## Post-Incident Procedures

After resolving any issue using these runbooks:

1. **Document the incident**: What happened, how it was fixed
2. **Update monitoring**: Add alerts to catch this issue early
3. **Improve automation**: Create scripts to automate the fix
4. **Update runbooks**: Incorporate any new procedures discovered
5. **Share learnings**: Brief team on the incident and resolution

## Contact Information

- **On-Call Engineer**: [Slack channel or pager]
- **Database Expert**: [Contact info]
- **Infrastructure Team**: [Contact info]
- **Product Team**: [For user impact assessment]

## Related Documentation

- [Architecture Documentation](../architecture/)
- [Deployment Guides](../setup/)
- [Monitoring Setup](../architecture/LOGGING_AND_MONITORING.md)
- [Security Procedures](../setup/SECURITY_SETUP.md)