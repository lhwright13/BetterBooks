# GitHub Actions CI/CD Pipeline Setup Guide

Complete setup guide for implementing GitHub Actions CI/CD for the EchoWright audiobook platform.

## Quick Start

### 1. Repository Setup
```bash
# Clone your repository
git clone https://github.com/your-username/echowright.git
cd echowright

# Ensure workflows are in place
ls .github/workflows/
# Should show: ci.yml, deploy-staging.yml, deploy-production.yml, security.yml
```

### 2. Configure GitHub Secrets
Go to **Settings > Secrets and Variables > Actions** and add these secrets:

#### Required Secrets
```bash
# Database
POSTGRES_PASSWORD_STAGING=your_staging_db_password
POSTGRES_PASSWORD_PROD=your_production_db_password

# Redis  
REDIS_PASSWORD_STAGING=your_staging_redis_password
REDIS_PASSWORD_PROD=your_production_redis_password

# API Keys
GEMINI_API_KEY_STAGING=your_staging_gemini_key
GEMINI_API_KEY_PROD=your_production_gemini_key

# Security
JWT_SECRET_KEY_STAGING=your_staging_jwt_secret
JWT_SECRET_KEY_PROD=your_production_jwt_secret

# Kubernetes (Base64 encoded kubeconfig files)
KUBE_CONFIG_DATA_STAGING=base64_encoded_staging_kubeconfig
KUBE_CONFIG_DATA_PRODUCTION=base64_encoded_production_kubeconfig

# AWS (if using EKS)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-west-2

# Notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your/webhook/url
```

### 3. Set Up GitHub Environments
1. Go to **Settings > Environments**
2. Create `staging` environment
3. Create `production` environment with:
   - Required reviewers (at least 1)
   - Deployment protection rules
   - Environment-specific secrets if needed

### 4. Test Local Pipeline
```bash
# Test Docker builds locally
docker-compose build

# Run tests locally
./scripts/run_tests.sh

# Test integration locally
docker-compose -f docker-compose.test.yml up --build -d
./scripts/run_integration_tests.sh
docker-compose -f docker-compose.test.yml down -v
```

## Workflow Details

### Main CI Workflow (`.github/workflows/ci.yml`)
**Triggers:** Push to `main`/`develop`, Pull Requests

**Jobs:**
1. **validate-code** - Code formatting checks
2. **validate-docker** - Docker Compose validation  
3. **validate-flutter** - Flutter analysis
4. **unit-tests** - Python unit tests with PostgreSQL/Redis
5. **integration-tests** - Full service integration testing
6. **security-scan** - Dependency and code analysis
7. **container-security** - Docker vulnerability scanning
8. **build-services** - Multi-platform Docker builds (if push event)
9. **build-mobile** - Flutter APK/App Bundle builds (if push event)

### Staging Deployment (`.github/workflows/deploy-staging.yml`)
**Triggers:** Push to `develop` branch

**Process:**
1. Deploy to staging Kubernetes namespace
2. Run smoke tests
3. Execute integration tests against staging
4. Optional performance testing
5. Slack notification

### Production Deployment (`.github/workflows/deploy-production.yml`)
**Triggers:** Push to `main` branch + manual approval

**Process:**
1. Pre-deployment validation checks
2. Manual approval gate (GitHub Environment protection)
3. Production deployment with health checks
4. Automatic rollback on failure
5. Post-deployment testing
6. Performance baseline verification

### Security Scanning (`.github/workflows/security.yml`)
**Triggers:** Push, PR, Weekly schedule (Mondays 2 AM)

**Scans:**
- Dependency vulnerabilities (Safety, pip-audit)
- Static code analysis (Bandit, Semgrep)
- Container security (Trivy)
- Secrets detection (TruffleHog, GitLeaks)
- Infrastructure analysis (Checkov)
- Mobile security analysis

## Deployment Process

### Staging Deployment Flow
```
develop branch push → GitHub Actions triggers → 
Build & Test → Deploy to Staging → 
Integration Tests → Performance Tests → 
Slack Notification
```

### Production Deployment Flow  
```
main branch push → GitHub Actions triggers →
Pre-deployment Checks → Manual Approval → 
Deploy to Production → Health Checks → 
Post-deployment Tests → Monitoring
```

## Security Features

### SARIF Integration
All security scans upload results to GitHub's Security tab in SARIF format:
- Dependency vulnerabilities
- Code quality issues  
- Container vulnerabilities
- Infrastructure misconfigurations

### Secrets Management
- GitHub Secrets for sensitive values
- External secrets integration for production
- Automatic secret rotation recommendations

### Supply Chain Security
- Container image signing
- Dependency vulnerability tracking
- Software Bill of Materials (SBOM) generation

## Monitoring and Observability

### Built-in Monitoring
- GitHub Actions workflow insights
- Build time tracking
- Success/failure rates
- Resource usage metrics

### Integration Points
- Slack notifications for deployments
- GitHub Security tab for vulnerability management
- Prometheus metrics collection
- Jaeger distributed tracing

## Best Practices

### Branch Strategy
```
main (production) ← merge from develop
develop (staging) ← feature branches
feature/* → PR to develop
hotfix/* → PR to main (emergency fixes)
```

### PR Guidelines
1. All PRs trigger full CI pipeline
2. Security scans must pass
3. Code coverage must maintain minimum threshold
4. Manual review required for production deployments

### Secret Management
- Use GitHub Environments for environment-specific secrets
- Rotate secrets regularly (quarterly)
- Never commit secrets to repository
- Use external secret management for production (Vault, AWS Secrets Manager)

## Troubleshooting

### Common Issues

**Failed Builds:**
```bash
# Check workflow logs in GitHub Actions tab
# View individual step outputs
# Check resource limits and timeouts
```

**Docker Registry Issues:**
```bash
# Verify GITHUB_TOKEN permissions
# Check image manifest exists:
docker manifest inspect ghcr.io/your-username/repo/service:tag
```

**Kubernetes Deployment Failures:**
```bash
# Verify kubeconfig is correct
kubectl config current-context

# Check pod status
kubectl get pods -n echowright-staging

# View deployment logs
kubectl logs -f deployment/api-gateway -n echowright-staging
```

**Security Scan Failures:**
```bash
# Review Security tab in GitHub repository
# Check SARIF uploads in workflow logs
# Run scans locally to debug issues
```

### Emergency Procedures

**Production Rollback:**
1. Go to GitHub Actions → Production Deployment workflow
2. Find last successful deployment
3. Click "Re-run jobs" on successful version
4. Or manually: `helm rollback echowright-prod -n echowright-prod`

**Disable Deployments:**
1. Go to **Settings > Environments > Production**
2. Add "Prevent deployments" protection rule
3. Or pause workflows in Actions tab

## Maintenance

### Regular Tasks
- **Weekly:** Review security scan results
- **Monthly:** Update base images and dependencies
- **Quarterly:** Rotate secrets and certificates
- **Annually:** Security audit and penetration testing

### Monitoring Checklist
- [ ] All workflows passing (>95% success rate)
- [ ] Build times under 10 minutes
- [ ] Security scans passing
- [ ] No high/critical vulnerabilities
- [ ] Staging and production environments healthy

## Support

### Resources
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes Deployment Guide](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

### Getting Help
- **GitHub Issues:** Use repository issues with `devops` label
- **Security Issues:** Use GitHub Security tab for vulnerability reports
- **Slack Channel:** #echowright-devops
- **Documentation:** `docs/` directory

---

**Setup Complete!** 
Your GitHub Actions CI/CD pipeline is now ready. Push to `develop` to test staging deployment, and push to `main` to deploy to production (with approval).

*Last Updated: 2025-01-08*