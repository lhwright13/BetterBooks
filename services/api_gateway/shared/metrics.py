"""
Prometheus metrics collection for all services.
Provides automatic metrics collection and custom metric helpers.
"""

from typing import Optional, Callable, Dict, Any
from functools import wraps
import time
from prometheus_client import (
    Counter, Histogram, Gauge, Summary,
    generate_latest, CONTENT_TYPE_LATEST,
    CollectorRegistry, REGISTRY
)
from fastapi import Response, Request
from starlette.middleware.base import BaseHTTPMiddleware

# Default metrics that all services should have
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration in seconds',
    ['method', 'endpoint'],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10)
)

http_requests_in_progress = Gauge(
    'http_requests_in_progress',
    'Number of HTTP requests in progress'
)

# Service-specific metrics
llm_requests_total = Counter(
    'llm_requests_total',
    'Total LLM API requests',
    ['model', 'status']
)

llm_request_duration_seconds = Histogram(
    'llm_request_duration_seconds',
    'LLM request duration in seconds',
    ['model'],
    buckets=(0.1, 0.5, 1, 2.5, 5, 10, 30, 60)
)

llm_tokens_used = Counter(
    'llm_tokens_used',
    'Total tokens used in LLM requests',
    ['model', 'type']  # type: prompt or completion
)

tts_requests_total = Counter(
    'tts_requests_total',
    'Total TTS synthesis requests',
    ['voice', 'status']
)

tts_audio_duration_seconds = Summary(
    'tts_audio_duration_seconds',
    'Duration of synthesized audio in seconds'
)

database_queries_total = Counter(
    'database_queries_total',
    'Total database queries',
    ['operation', 'table', 'status']
)

database_query_duration_seconds = Histogram(
    'database_query_duration_seconds',
    'Database query duration in seconds',
    ['operation', 'table'],
    buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1)
)

cache_operations_total = Counter(
    'cache_operations_total',
    'Total cache operations',
    ['operation', 'status']  # operation: get, set, delete
)

cache_hit_ratio = Gauge(
    'cache_hit_ratio',
    'Cache hit ratio'
)

# Business metrics
active_users = Gauge(
    'active_users',
    'Number of active users'
)

books_processed_total = Counter(
    'books_processed_total',
    'Total books processed'
)

audio_minutes_generated = Counter(
    'audio_minutes_generated',
    'Total minutes of audio generated'
)

class PrometheusMiddleware(BaseHTTPMiddleware):
    """Middleware to collect HTTP metrics automatically."""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Start timing and increment in-progress gauge
        start_time = time.time()
        http_requests_in_progress.inc()
        
        # Extract path without parameters for grouping
        path = request.url.path
        method = request.method
        
        try:
            # Process request
            response = await call_next(request)
            
            # Record metrics
            duration = time.time() - start_time
            status = response.status_code
            
            # Update metrics
            http_requests_total.labels(
                method=method,
                endpoint=path,
                status=status
            ).inc()
            
            http_request_duration_seconds.labels(
                method=method,
                endpoint=path
            ).observe(duration)
            
            return response
            
        except Exception as e:
            # Record error metrics
            duration = time.time() - start_time
            
            http_requests_total.labels(
                method=method,
                endpoint=path,
                status=500
            ).inc()
            
            http_request_duration_seconds.labels(
                method=method,
                endpoint=path
            ).observe(duration)
            
            raise
            
        finally:
            # Decrement in-progress gauge
            http_requests_in_progress.dec()

def track_time(metric: Histogram, labels: Optional[Dict[str, str]] = None):
    """
    Decorator to track function execution time.
    
    Example:
        @track_time(database_query_duration_seconds, {"operation": "select", "table": "users"})
        async def get_user(user_id: str):
            # Database query here
            pass
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            start = time.time()
            try:
                result = await func(*args, **kwargs)
                return result
            finally:
                duration = time.time() - start
                if labels:
                    metric.labels(**labels).observe(duration)
                else:
                    metric.observe(duration)
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            start = time.time()
            try:
                result = func(*args, **kwargs)
                return result
            finally:
                duration = time.time() - start
                if labels:
                    metric.labels(**labels).observe(duration)
                else:
                    metric.observe(duration)
        
        # Return appropriate wrapper based on function type
        import asyncio
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator

def track_counter(metric: Counter, labels: Optional[Dict[str, str]] = None):
    """
    Decorator to increment a counter when function is called.
    
    Example:
        @track_counter(llm_requests_total, {"model": "gemini", "status": "success"})
        async def call_llm(prompt: str):
            # LLM call here
            pass
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            result = await func(*args, **kwargs)
            if labels:
                metric.labels(**labels).inc()
            else:
                metric.inc()
            return result
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            result = func(*args, **kwargs)
            if labels:
                metric.labels(**labels).inc()
            else:
                metric.inc()
            return result
        
        # Return appropriate wrapper based on function type
        import asyncio
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator

class MetricsCollector:
    """Helper class for collecting custom metrics."""
    
    def __init__(self, service_name: str):
        self.service_name = service_name
        self.custom_metrics = {}
    
    def create_counter(self, name: str, description: str, labels: list = None) -> Counter:
        """Create a custom counter metric."""
        metric_name = f"{self.service_name}_{name}"
        counter = Counter(metric_name, description, labels or [])
        self.custom_metrics[metric_name] = counter
        return counter
    
    def create_histogram(self, name: str, description: str, labels: list = None, buckets: tuple = None) -> Histogram:
        """Create a custom histogram metric."""
        metric_name = f"{self.service_name}_{name}"
        histogram = Histogram(metric_name, description, labels or [], buckets=buckets)
        self.custom_metrics[metric_name] = histogram
        return histogram
    
    def create_gauge(self, name: str, description: str, labels: list = None) -> Gauge:
        """Create a custom gauge metric."""
        metric_name = f"{self.service_name}_{name}"
        gauge = Gauge(metric_name, description, labels or [])
        self.custom_metrics[metric_name] = gauge
        return gauge
    
    def create_summary(self, name: str, description: str, labels: list = None) -> Summary:
        """Create a custom summary metric."""
        metric_name = f"{self.service_name}_{name}"
        summary = Summary(metric_name, description, labels or [])
        self.custom_metrics[metric_name] = summary
        return summary

def create_metrics_endpoint(app):
    """
    Create Prometheus metrics endpoint for a FastAPI app.
    
    Args:
        app: FastAPI application instance
    """
    
    @app.get("/metrics")
    async def metrics():
        """Prometheus metrics endpoint."""
        return Response(
            content=generate_latest(REGISTRY),
            media_type=CONTENT_TYPE_LATEST
        )

def setup_metrics(app, service_name: str) -> MetricsCollector:
    """
    Set up Prometheus metrics for a service.
    
    Args:
        app: FastAPI application instance
        service_name: Name of the service for metric prefixes
        
    Returns:
        MetricsCollector instance for creating custom metrics
    """
    # Add Prometheus middleware
    app.add_middleware(PrometheusMiddleware)
    
    # Create metrics endpoint
    create_metrics_endpoint(app)
    
    # Return collector for custom metrics
    return MetricsCollector(service_name)