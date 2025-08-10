"""
Infrastructure Utilities Module

Contains infrastructure and operational utilities:
- Health check implementations
- Structured logging and middleware
- Metrics collection and monitoring
- Distributed tracing
"""

from .health_checks import HealthCheck, create_health_endpoint
from .logging_config import setup_logging
from .logging_middleware import LoggingMiddleware
from .metrics import setup_metrics, MetricsCollector
try:
    from .tracing import setup_tracing, get_development_tracing_config
    TRACING_AVAILABLE = True
except ImportError:
    setup_tracing = None
    get_development_tracing_config = None
    TRACING_AVAILABLE = False

__all__ = [
    'HealthCheck',
    'create_health_endpoint',
    'setup_logging',
    'LoggingMiddleware',
    'setup_metrics',
    'MetricsCollector', 
    'setup_tracing',
    'get_development_tracing_config',
    'TRACING_AVAILABLE'
]