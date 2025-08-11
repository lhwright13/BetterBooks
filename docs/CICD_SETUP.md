# GitHub Actions CI/CD Pipeline Setup Guide

This document provides comprehensive instructions for setting up and managing the GitHub Actions CI/CD pipeline for the EchoWright audiobook platform.

## Overview

The GitHub Actions CI/CD pipeline provides:
- ✅ **Automated Testing** - Unit, integration, and performance tests
- 🔒 **Security Scanning** - Comprehensive vulnerability detection and analysis
- 🐳 **Multi-Service Builds** - Automated Docker image building with GitHub Container Registry
- 🚀 **Multi-Environment Deployment** - Staging and production deployments with approval gates
- 📊 **Quality Gates** - Code formatting, test coverage, and performance checks

## Prerequisites

### Local Development
- Docker and Docker Compose
- Python 3.11+
- Flutter SDK 3.1.0+ (for mobile builds)
- Git

### GitHub Setup
- GitHub repository with Actions enabled
- GitHub Container Registry (ghcr.io) access
- GitHub Environments configured for staging and production

### Infrastructure Requirements
- **Kubernetes Cluster** (staging and production)
- **GitHub Container Registry** (ghcr.io)
- **External Secrets Management** (Vault, AWS Secrets Manager)
- **Monitoring Stack** (Prometheus, Grafana, Jaeger)

## GitHub Actions Workflows

### 1. Main CI/CD Workflow (`.github/workflows/ci.yml`)
**Jobs:**
- **validate-code** - Code formatting and style checks (Black, isort, flake8)
- **validate-docker** - Docker Compose validation
- **validate-flutter** - Flutter analysis and testing
- **unit-tests** - Python unit tests with coverage reporting
- **integration-tests** - Full service integration testing
- **security-scan** - Dependency and static code analysis
- **container-security** - Docker image vulnerability scanning
- **build-services** - Multi-platform Docker builds (amd64, arm64)
- **build-mobile** - Flutter APK and App Bundle builds

### 2. Staging Deployment (`.github/workflows/deploy-staging.yml`)
**Triggered on:** Push to `develop` branch
- Automated deployment to staging environment
- Post-deployment smoke tests
- Integration test execution
- Performance testing with k6
- Slack notifications

### 3. Production Deployment (`.github/workflows/deploy-production.yml`)
**Triggered on:** Push to `main` branch (with manual approval)
- Pre-deployment validation checks
- Production deployment with rollback capability
- Comprehensive health monitoring
- Post-deployment critical path testing
- Performance baseline verification

### 4. Security Scanning (`.github/workflows/security.yml`)
**Comprehensive Security Analysis:**
- **Dependency Scanning** - Safety, pip-audit
- **Static Analysis** - Bandit, Semgrep with SARIF upload
- **Container Scanning** - Trivy for all service images
- **Secrets Scanning** - TruffleHog, GitLeaks
- **Mobile Security** - Flutter dependency analysis
- **Infrastructure Scanning** - Checkov for Terraform/K8s/Docker
- **Security Report** - Automated summary generation

## Setup Instructions

### 1. GitHub Repository Configuration

**Required Secrets:**
Navigate to **Settings > Secrets and Variables > Actions** and add:

```bash
# Database Credentials
POSTGRES_PASSWORD_STAGING      # Staging database password
POSTGRES_PASSWORD_PROD        # Production database password

# Redis Credentials  
REDIS_PASSWORD_STAGING        # Staging Redis password
REDIS_PASSWORD_PROD          # Production Redis password

# API Keys
GEMINI_API_KEY_STAGING       # Gemini API key for staging
GEMINI_API_KEY_PROD         # Gemini API key for production

# Security
JWT_SECRET_KEY_STAGING       # JWT signing key for staging
JWT_SECRET_KEY_PROD         # JWT signing key for production

# Kubernetes Configuration
KUBE_CONFIG_DATA_STAGING     # Base64 encoded kubeconfig for staging
KUBE_CONFIG_DATA_PRODUCTION  # Base64 encoded kubeconfig for production

# AWS Credentials (if using EKS)
AWS_ACCESS_KEY_ID           # AWS access key
AWS_SECRET_ACCESS_KEY       # AWS secret key  
AWS_REGION                 # AWS region

# Notifications
SLACK_WEBHOOK_URL          # Slack webhook for deployment notifications

# Security Scanning (optional)
GITLEAKS_LICENSE          # GitLeaks license key
```

**GitHub Container Registry Setup:**
1. Enable GitHub Container Registry for your repository
2. Registry URL: `ghcr.io/your-username/your-repo`
3. Authentication handled automatically via `GITHUB_TOKEN`

**GitHub Environments Setup:**
1. Go to **Settings > Environments**
2. Create `staging` environment (auto-deploy from `develop`)
3. Create `production` environment with required reviewers and deployment protection rules

### 2. Kubernetes Setup

**Staging Environment:**
```bash
# Create namespace
kubectl create namespace echowright-staging

# Set up RBAC
kubectl apply -f k8s/rbac-staging.yaml

# Configure secrets
kubectl create secret generic app-secrets \
  --from-literal=postgres-password=$POSTGRES_PASSWORD_STAGING \
  --from-literal=redis-password=$REDIS_PASSWORD_STAGING \
  --from-literal=jwt-secret=$JWT_SECRET_KEY_STAGING \
  --from-literal=gemini-api-key=$GEMINI_API_KEY_STAGING \
  --namespace=echowright-staging
```

**Production Environment:**
```bash
# Create namespace
kubectl create namespace echowright-prod

# Set up RBAC with stricter permissions
kubectl apply -f k8s/rbac-production.yaml

# Configure external secrets (Vault/AWS Secrets Manager)
kubectl apply -f k8s/external-secrets-production.yaml
```

### 3. Monitoring Setup

**Prometheus Configuration:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'echowright-staging'
    kubernetes_sd_configs:
      - role: endpoints
        namespaces:
          names:
          - echowright-staging
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

**Grafana Dashboards:**
- Service health and performance metrics
- Request rate, latency, and error tracking
- Resource utilization (CPU, memory, disk)
- Business metrics (active users, API calls)

### 4. Local Testing

**Test Pipeline Locally:**
```bash
# Validate Docker Compose
docker-compose config --quiet

# Run unit tests
./scripts/run_tests.sh

# Run integration tests
docker-compose -f docker-compose.test.yml up --build -d
./scripts/run_integration_tests.sh
docker-compose -f docker-compose.test.yml down -v

# Build all services
docker-compose build

# Security scans
pip install safety bandit
safety check
bandit -r platform/backend/services/
```

## Deployment Process

### Staging Deployment
1. **Automatic Trigger:** Push to `develop` branch
2. **Build:** All service images built and pushed
3. **Deploy:** Helm chart deployed to staging namespace
4. **Test:** Integration tests run against staging
5. **Manual Gate:** Review and approve for production

### Production Deployment
1. **Manual Trigger:** Push to `main` branch + manual approval
2. **Build:** Production images with `stable` tag
3. **Deploy:** Blue-green deployment with health checks
4. **Monitor:** Comprehensive monitoring and alerting
5. **Rollback:** Automatic rollback on health check failures

## Environment Management

### Staging Environment
- **Purpose:** Feature testing and integration validation
- **Resources:** Moderate (2-5 replicas per service)
- **Data:** Synthetic test data
- **Monitoring:** Full observability stack
- **Access:** Development team access

### Production Environment  
- **Purpose:** Live user-facing environment
- **Resources:** High availability (3+ replicas per service)
- **Data:** Real user data with encryption
- **Monitoring:** 24/7 monitoring with alerting
- **Access:** Restricted access with audit logs

## Troubleshooting

### Common Issues

**Pipeline Failures:**
```bash
# Check GitHub Actions workflow logs
# View in repository Actions tab

# Debug Docker build issues
docker build --no-cache platform/backend/services/api_gateway/

# Test Kubernetes connectivity
kubectl cluster-info
kubectl get nodes
```

**Deployment Issues:**
```bash
# Check pod status
kubectl get pods -n echowright-staging
kubectl describe pod <pod-name> -n echowright-staging

# View service logs  
kubectl logs -f deployment/api-gateway -n echowright-staging

# Check helm release
helm list -n echowright-staging
helm status echowright-staging -n echowright-staging
```

**Performance Issues:**
```bash
# Check resource usage
kubectl top pods -n echowright-staging
kubectl top nodes

# Review metrics
curl http://staging.echowright.com/metrics

# Load testing
k6 run tests/performance/load-test.js
```

### Rollback Procedures

**Staging Rollback:**
```bash
helm rollback echowright-staging -n echowright-staging
```

**Production Rollback:**
```bash
# Emergency rollback
helm rollback echowright-prod -n echowright-prod

# Gradual rollback with monitoring
helm rollback echowright-prod --wait --timeout=10m -n echowright-prod
kubectl rollout status deployment/api-gateway -n echowright-prod
```

## Security Best Practices

### Secrets Management
- ✅ Use external secrets management (Vault, AWS Secrets Manager)
- ✅ Rotate secrets regularly (90 days)
- ✅ Audit secret access
- ❌ Never commit secrets to version control

### Container Security
- ✅ Use distroless or minimal base images
- ✅ Run containers as non-root users
- ✅ Enable read-only root filesystem
- ✅ Scan images for vulnerabilities

### Network Security
- ✅ Enable network policies
- ✅ Use TLS for all communications
- ✅ Implement proper CORS policies
- ✅ Rate limiting and DDoS protection

## Performance Optimization

### Build Optimization
- Use multi-stage Docker builds
- Implement Docker layer caching
- Parallel service builds
- Optimize image sizes

### Deployment Optimization  
- Rolling updates with health checks
- Resource requests and limits
- Horizontal Pod Autoscaling (HPA)
- Cluster autoscaling

### Monitoring and Alerting
- Comprehensive metrics collection
- Distributed tracing
- Log aggregation and analysis
- Proactive alerting on key metrics

## Maintenance

### Regular Tasks
- **Weekly:** Review pipeline performance and success rates
- **Monthly:** Update dependencies and base images  
- **Quarterly:** Security audit and penetration testing
- **Annually:** Disaster recovery testing

### Monitoring Checklist
- [ ] Pipeline success rate > 95%
- [ ] Build time < 10 minutes
- [ ] Test coverage > 80%
- [ ] Security scan pass rate > 98%
- [ ] Deployment success rate > 99%

## Support and Documentation

### Additional Resources
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kubernetes Deployment Guide](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Helm Chart Documentation](https://helm.sh/docs/)
- [Prometheus Monitoring](https://prometheus.io/docs/)

### Getting Help
- **Slack Channel:** #echowright-devops
- **Documentation:** `docs/` directory
- **Issues:** GitHub Issues with `devops` label
- **On-call:** PagerDuty rotation for production issues

---

**Last Updated:** 2025-01-08  
**Version:** 1.0  
**Maintainer:** DevOps Team