# CI/CD Pipeline Setup Guide

This document provides comprehensive instructions for setting up and managing the GitLab CI/CD pipeline for the EchoWright audiobook platform.

## Overview

The CI/CD pipeline provides:
- ✅ **Automated Testing** - Unit, integration, and performance tests
- 🔒 **Security Scanning** - Dependency and container vulnerability scans  
- 🐳 **Multi-Service Builds** - Automated Docker image building
- 🚀 **Multi-Environment Deployment** - Staging and production deployments
- 📊 **Quality Gates** - Code formatting, test coverage, and performance checks

## Prerequisites

### Local Development
- Docker and Docker Compose
- Python 3.11+
- Flutter SDK 3.1.0+ (for mobile builds)
- Git

### GitLab Setup
- GitLab project with CI/CD enabled
- Container Registry enabled
- GitLab Runners (shared or dedicated)

### Infrastructure Requirements
- **Kubernetes Cluster** (staging and production)
- **Container Registry** (GitLab Registry or external)
- **External Secrets Management** (Vault, AWS Secrets Manager)
- **Monitoring Stack** (Prometheus, Grafana, Jaeger)

## Pipeline Stages

### 1. Validate Stage
```yaml
stages: [validate, test, security, build, deploy-staging, integration-test, deploy-production]
```

**Code Quality Checks:**
- Python code formatting (Black, isort, flake8)
- Docker Compose validation
- Flutter analysis and tests

### 2. Test Stage
**Unit Tests:**
- Python services with pytest
- Coverage reporting (minimum 80%)
- Mocked external dependencies

**Integration Tests:**
- Docker Compose test environment
- Real service communication testing
- Health check validation

### 3. Security Stage
**Dependency Scanning:**
- Python package vulnerability check (Safety)
- Static code analysis (Bandit, Semgrep)
- Docker image scanning (Trivy)

### 4. Build Stage
**Multi-Service Building:**
- Parallel Docker image builds for all services
- Image tagging with commit SHA and `latest`
- Push to GitLab Container Registry

**Mobile Builds:**
- Flutter APK and App Bundle generation
- Artifact storage for distribution

### 5. Deploy Stages
**Staging Deployment:**
- Automatic deployment to staging environment
- Smoke tests and health checks
- Manual promotion gate

**Production Deployment:**
- Manual deployment approval required
- Blue-green or rolling deployment strategy
- Comprehensive health monitoring

## Setup Instructions

### 1. GitLab Configuration

**Required CI/CD Variables:**
```bash
# Database
POSTGRES_PASSWORD              # Staging/production DB passwords
POSTGRES_PASSWORD_STAGING
POSTGRES_PASSWORD_PROD

# Redis
REDIS_PASSWORD_STAGING
REDIS_PASSWORD_PROD

# API Keys
GEMINI_API_KEY_STAGING        # Gemini API key for staging
GEMINI_API_KEY_PROD          # Gemini API key for production

# Security
JWT_SECRET_KEY_STAGING       # JWT signing key for staging
JWT_SECRET_KEY_PROD         # JWT signing key for production

# Kubernetes
KUBE_CONTEXT_STAGING        # Kubernetes context for staging
KUBE_CONTEXT_PRODUCTION     # Kubernetes context for production

# Monitoring (optional)
ALERT_EMAIL                 # Email for alerts
SLACK_WEBHOOK              # Slack webhook for notifications
```

**Container Registry Setup:**
1. Enable Container Registry in GitLab project settings
2. Configure registry URL: `registry.gitlab.com/your-group/echowright`
3. Set up registry authentication for deployment environments

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
# Check GitLab Runner logs
gitlab-runner logs

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
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Kubernetes Deployment Guide](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Helm Chart Documentation](https://helm.sh/docs/)
- [Prometheus Monitoring](https://prometheus.io/docs/)

### Getting Help
- **Slack Channel:** #echowright-devops
- **Documentation:** `docs/` directory
- **Issues:** GitLab Issues with `devops` label
- **On-call:** PagerDuty rotation for production issues

---

**Last Updated:** 2025-01-08  
**Version:** 1.0  
**Maintainer:** DevOps Team