# EchoWright Monitoring Guide

Complete guide for setting up and using Prometheus and Grafana monitoring on Azure.

## Quick Start

### 1. Deploy Monitoring Stack
```bash
# Deploy Prometheus and Grafana to your Azure cluster
cd /Users/lhwri/BetterBooks
./deployment/deploy-monitoring.sh
```

### 2. Access Dashboards
Choose one of these methods:

**Option A: External LoadBalancer (Production)**
- Wait for external IPs to be assigned (5-10 minutes)
- Check status: `kubectl get svc -n betterbooks`
- Access via external IPs shown in deployment output

**Option B: Port Forwarding (Development)**
```bash
# Start port forwarding
./deployment/port-forward-monitoring.sh

# Access services locally
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000 (admin/echowright2025)
```

## What You Can Monitor

### Service Metrics
- **Request Rates**: Requests per second for each service
- **Response Times**: Latency percentiles (50th, 95th, 99th)
- **Error Rates**: 4xx and 5xx error rates
- **Throughput**: Total requests processed

### LLM Gateway Specific
- **Token Usage**: Prompt and completion tokens consumed
- **Model Performance**: Response times by model (Gemini)
- **Request Success Rate**: LLM API success/failure rates
- **Cache Hit Ratio**: Semantic cache effectiveness

### Business Metrics
- **Active Users**: Current user sessions
- **Books Processed**: Total books processed
- **Audio Generated**: Minutes of audio synthesized
- **Chat Messages**: AI conversations per hour

### System Resources
- **CPU Usage**: Per-service CPU utilization
- **Memory Usage**: RAM consumption and limits
- **Disk Space**: Storage utilization
- **Network I/O**: Request/response data transfer

## Using Grafana

### Initial Setup
1. Access Grafana at http://localhost:3000 (or external IP)
2. Login with admin/echowright2025
3. The EchoWright Overview dashboard should load automatically

### Key Dashboards

#### EchoWright Overview
- Service health summary
- Request rates across all services  
- Error rate alerts
- Resource utilization overview

#### Drill-Down Views
- Click on any metric to drill down
- Filter by service, time range, or status code
- Compare performance across different time periods

### Creating Alerts
1. Go to Alerting → Alert Rules
2. Create new rule based on metrics
3. Set thresholds (e.g., error rate > 5%)
4. Configure notification channels

## Using Prometheus

### Accessing Prometheus
- Web UI: http://localhost:9090 (or external IP)
- Use PromQL to query metrics directly

### Useful Queries

#### Service Health
```promql
# Check if services are up
up{job="api_gateway"}
up{job="llm_gateway"} 
up{job="context_service"}
up{job="tts_service"}
```

#### Request Rates
```promql
# Requests per second by service
rate(http_requests_total[5m])

# Error rate percentage
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100
```

#### Response Times
```promql
# 95th percentile response time
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Average response time
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```

#### LLM Metrics
```promql
# Token usage per model
rate(llm_tokens_used[5m])

# LLM request success rate
rate(llm_requests_total{status="success"}[5m]) / rate(llm_requests_total[5m])
```

#### Business Metrics
```promql
# Active users
active_users

# Books processed per hour
increase(books_processed_total[1h])

# Cache hit ratio
cache_hit_ratio
```

## Troubleshooting

### Common Issues

#### 1. Services Not Showing Metrics
**Symptoms**: Empty dashboards, "No data" messages

**Solutions**:
```bash
# Check if services are exposing /metrics endpoints
kubectl exec -n betterbooks -it deployment/api-gateway -- curl http://localhost:8000/metrics
kubectl exec -n betterbooks -it deployment/llm-gateway -- curl http://localhost:8002/metrics

# Check Prometheus targets
kubectl port-forward -n betterbooks svc/prometheus 9090:9090
# Visit http://localhost:9090/targets
```

#### 2. Prometheus Can't Scrape Services
**Symptoms**: Targets showing as "DOWN" in Prometheus

**Solutions**:
```bash
# Check service names and ports
kubectl get svc -n betterbooks

# Verify network connectivity
kubectl exec -n betterbooks -it deployment/prometheus -- nc -zv api-gateway 8000
```

#### 3. Grafana Can't Connect to Prometheus
**Symptoms**: "Unable to connect to datasource" errors

**Solutions**:
```bash
# Check if Prometheus service is accessible from Grafana
kubectl exec -n betterbooks -it deployment/grafana -- nc -zv prometheus 9090

# Verify datasource configuration in Grafana
# Go to Configuration → Data Sources → Prometheus
```

### Service-Specific Debugging

#### API Gateway Metrics
```bash
# Check if metrics endpoint is working
kubectl exec -n betterbooks -it deployment/api-gateway -- curl -s http://localhost:8000/metrics | head -20

# Check for specific metrics
kubectl exec -n betterbooks -it deployment/api-gateway -- curl -s http://localhost:8000/metrics | grep "http_requests_total"
```

#### LLM Gateway Metrics
```bash
# Test LLM metrics endpoint
kubectl exec -n betterbooks -it deployment/llm-gateway -- curl -s http://localhost:8002/metrics | grep "llm_"
```

### Pod Health Checks
```bash
# Check all monitoring pods
kubectl get pods -n betterbooks | grep -E "prometheus|grafana"

# Check logs for errors
kubectl logs -n betterbooks deployment/prometheus --tail=50
kubectl logs -n betterbooks deployment/grafana --tail=50

# Check resource usage
kubectl top pods -n betterbooks
```

## Advanced Configuration

### Custom Metrics
Add custom metrics to your services using the existing metrics infrastructure:

```python
from core.infrastructure.metrics import setup_metrics

# Initialize metrics collector
metrics = setup_metrics(app, "my_service")

# Create custom counter
my_counter = metrics.create_counter(
    "my_custom_total",
    "Description of my metric", 
    ["label1", "label2"]
)

# Use the metric
my_counter.labels(label1="value1", label2="value2").inc()
```

### Alerting Rules
Add custom alerting rules to Prometheus:

```yaml
# Edit prometheus ConfigMap
kubectl edit configmap prometheus-config -n betterbooks

# Add alerting rules
rule_files:
  - "alert_rules.yml"
  
# Example rules
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
```

### Resource Scaling
Monitor resource usage and scale when needed:

```bash
# Check resource usage
kubectl top pods -n betterbooks

# Scale Prometheus if needed
kubectl scale deployment prometheus -n betterbooks --replicas=2

# Adjust resource limits
kubectl edit deployment prometheus -n betterbooks
```

## Production Considerations

### Security
- Change default Grafana admin password
- Enable HTTPS for external access
- Configure proper RBAC permissions
- Use secrets for sensitive configuration

### Performance
- Configure appropriate retention policies
- Use recording rules for expensive queries
- Monitor Prometheus storage usage
- Set up log rotation

### Backup
- Back up Grafana dashboards
- Export Prometheus configuration
- Document custom queries and alerts

### Cost Optimization
- Set appropriate data retention periods
- Use recording rules to pre-aggregate data
- Monitor storage growth
- Clean up old metrics regularly

## Metrics Reference

### HTTP Metrics
| Metric | Description | Labels |
|--------|-------------|---------|
| `http_requests_total` | Total HTTP requests | method, endpoint, status |
| `http_request_duration_seconds` | Request duration histogram | method, endpoint |
| `http_requests_in_progress` | Requests currently being processed | - |

### LLM Metrics  
| Metric | Description | Labels |
|--------|-------------|---------|
| `llm_requests_total` | Total LLM API requests | model, status |
| `llm_request_duration_seconds` | LLM request duration | model |
| `llm_tokens_used` | Tokens consumed | model, type |

### Business Metrics
| Metric | Description | Labels |
|--------|-------------|---------|
| `active_users` | Current active users | - |
| `books_processed_total` | Total books processed | - |
| `audio_minutes_generated` | Audio generated (minutes) | - |
| `cache_hit_ratio` | Cache effectiveness | - |

## Support Commands

### Quick Health Check
```bash
# Check entire monitoring stack
kubectl get all -n betterbooks | grep -E "prometheus|grafana"

# Test all metrics endpoints
for service in api-gateway llm-gateway context-service tts-service; do
  echo "Testing $service..."
  kubectl exec -n betterbooks -it deployment/$service -- curl -s http://localhost:8000/metrics | head -1 || echo "Failed"
done
```

### Emergency Restart
```bash
# Restart monitoring stack
kubectl rollout restart deployment/prometheus -n betterbooks
kubectl rollout restart deployment/grafana -n betterbooks

# Wait for rollout to complete
kubectl rollout status deployment/prometheus -n betterbooks
kubectl rollout status deployment/grafana -n betterbooks
```

### Clean Reinstall
```bash
# Remove monitoring stack
helm uninstall prometheus -n betterbooks
helm uninstall grafana -n betterbooks

# Clean up persistent volumes if needed
kubectl delete pvc prometheus-prometheus -n betterbooks
kubectl delete pvc grafana-grafana -n betterbooks

# Redeploy
./deployment/deploy-monitoring.sh
```

## Next Steps

1. **Deploy the stack**: Run `./deployment/deploy-monitoring.sh`
2. **Access Grafana**: Use port forwarding or external IP
3. **Verify metrics**: Check that all services are being scraped
4. **Set up alerts**: Configure notifications for critical metrics
5. **Customize dashboards**: Add service-specific visualizations

For issues or questions, check the troubleshooting section or examine the monitoring stack logs.