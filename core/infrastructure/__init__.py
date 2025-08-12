"""
Infrastructure Utilities Module

Contains infrastructure and operational utilities:
- Health check implementations
- Structured logging and middleware
- Metrics collection and monitoring
- Distributed tracing
- Circuit breaker pattern for resilience
"""

from .health_checks import HealthCheck, create_health_endpoint
from .logging_config import setup_logging
from .logging_middleware import LoggingMiddleware
from .metrics import setup_metrics, MetricsCollector
from .circuit_breaker import (
    CircuitBreaker, CircuitBreakerError, CircuitState,
    ExponentialBackoff, create_http_circuit_breaker,
    create_database_circuit_breaker, create_llm_circuit_breaker
)
from .error_handling import (
    setup_error_handling, ErrorHandler, ApplicationError,
    ValidationError, AuthenticationError, AuthorizationError,
    NotFoundError, ConflictError, RateLimitError,
    ExternalServiceError, DatabaseError, TimeoutError,
    CircuitBreakerError as CBError, handle_external_service_error
)
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
    'CircuitBreaker',
    'CircuitBreakerError',
    'CircuitState',
    'ExponentialBackoff',
    'create_http_circuit_breaker',
    'create_database_circuit_breaker',
    'create_llm_circuit_breaker',
    'setup_error_handling',
    'ErrorHandler',
    'ApplicationError',
    'ValidationError',
    'AuthenticationError',
    'AuthorizationError',
    'NotFoundError',
    'ConflictError',
    'RateLimitError',
    'ExternalServiceError',
    'DatabaseError',
    'TimeoutError',
    'CBError',
    'handle_external_service_error',
    'setup_tracing',
    'get_development_tracing_config',
    'TRACING_AVAILABLE'
]