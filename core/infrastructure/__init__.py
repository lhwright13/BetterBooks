"""
Infrastructure Utilities Module

Contains comprehensive infrastructure and operational utilities for EchoWright:
- Health check implementations
- Structured logging and middleware
- Metrics collection and monitoring
- Distributed tracing
- Circuit breaker pattern for resilience
- Advanced rate limiting with subscription tiers
- Usage analytics with educational insights
- Audio processing pipeline with streaming
- Semantic caching for AI responses
- Compression middleware for performance
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
from .compression_middleware import CompressionMiddleware
from .pagination import (
    Paginator, PaginationParams, CursorPaginationParams,
    get_pagination_params, get_cursor_pagination_params,
    create_paginator, paginate_results
)
# Temporarily disabled - missing numpy dependency
# from .semantic_cache import (
#     SemanticCache, CacheType, CacheConfig, cache_response,
#     create_cache_instance, cache_llm_response, cache_embedding
# )
# New high-priority infrastructure components
from .rate_limiter import (
    setup_rate_limiting, RateLimiter, RateLimitMiddleware,
    OperationType, SubscriptionTier, rate_limit_decorator,
    create_rate_limiter
)
# Temporarily disabled - dataclass issue
# from .usage_analytics import (
#     setup_usage_analytics, AnalyticsCollector, AnalyticsMiddleware,
#     EventType, UserType, ContentType, AnalyticsConfig,
#     create_analytics_collector
# )
# Temporarily disabled - missing numpy dependency
# from .audio_pipeline import (
#     setup_audio_pipeline, AudioProcessor, AudioConfig,
#     AudioFormat, StreamingQuality, ProcessingMode,
#     ChapterMarker, AudioChunk, VoiceActivity,
#     create_audio_processor
# )

try:
    from .tracing import setup_tracing, get_development_tracing_config
    TRACING_AVAILABLE = True
except ImportError:
    setup_tracing = None
    get_development_tracing_config = None
    TRACING_AVAILABLE = False

__all__ = [
    # Core infrastructure
    'HealthCheck',
    'create_health_endpoint',
    'setup_logging',
    'LoggingMiddleware',
    'setup_metrics',
    'MetricsCollector',
    
    # Circuit breaker and resilience
    'CircuitBreaker',
    'CircuitBreakerError',
    'CircuitState',
    'ExponentialBackoff',
    'create_http_circuit_breaker',
    'create_database_circuit_breaker',
    'create_llm_circuit_breaker',
    
    # Error handling
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
    
    # Performance and optimization
    'CompressionMiddleware',
    'Paginator',
    'PaginationParams',
    'CursorPaginationParams',
    'get_pagination_params',
    'get_cursor_pagination_params',
    'create_paginator',
    'paginate_results',
    
    # Caching
    'SemanticCache',
    'CacheType',
    'CacheConfig',
    'cache_response',
    'create_cache_instance',
    'cache_llm_response',
    'cache_embedding',
    
    # Rate limiting (High Priority)
    'setup_rate_limiting',
    'RateLimiter',
    'RateLimitMiddleware',
    'OperationType',
    'SubscriptionTier',
    'rate_limit_decorator',
    'create_rate_limiter',
    
    # Usage analytics (High Priority)
    'setup_usage_analytics',
    'AnalyticsCollector',
    'AnalyticsMiddleware',
    'EventType',
    'UserType',
    'ContentType',
    'AnalyticsConfig',
    'create_analytics_collector',
    
    # Audio pipeline (High Priority)
    'setup_audio_pipeline',
    'AudioProcessor',
    'AudioConfig',
    'AudioFormat',
    'StreamingQuality',
    'ProcessingMode',
    'ChapterMarker',
    'AudioChunk',
    'VoiceActivity',
    'create_audio_processor',
    
    # Distributed tracing
    'setup_tracing',
    'get_development_tracing_config',
    'TRACING_AVAILABLE'
]