"""
Distributed tracing configuration using OpenTelemetry and Jaeger.
"""

import os
from typing import Optional
from opentelemetry import trace, metrics
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.propagators.b3 import B3MultiFormat
from opentelemetry.propagate import set_global_textmap
import logging

# Configure logger
logger = logging.getLogger(__name__)

class TracingConfig:
    """Configuration for distributed tracing."""
    
    def __init__(
        self,
        service_name: str,
        jaeger_endpoint: Optional[str] = None,
        sampling_rate: float = 1.0,
        enable_console_exporter: bool = False
    ):
        self.service_name = service_name
        self.jaeger_endpoint = jaeger_endpoint or os.getenv(
            "JAEGER_ENDPOINT", 
            "http://localhost:14268/api/traces"
        )
        self.sampling_rate = sampling_rate
        self.enable_console_exporter = enable_console_exporter


def setup_tracing(config: TracingConfig) -> trace.Tracer:
    """
    Set up OpenTelemetry tracing with Jaeger exporter.
    
    Args:
        config: Tracing configuration
        
    Returns:
        Configured tracer instance
    """
    # Configure resource with service information
    resource = Resource.create({
        SERVICE_NAME: config.service_name,
        "service.version": os.getenv("SERVICE_VERSION", "1.0.0"),
        "service.environment": os.getenv("ENVIRONMENT", "development"),
    })
    
    # Set up tracer provider
    tracer_provider = TracerProvider(
        resource=resource,
        sampler=trace.sampling.TraceIdRatioBased(config.sampling_rate)
    )
    trace.set_tracer_provider(tracer_provider)
    
    # Configure Jaeger exporter
    jaeger_exporter = JaegerExporter(
        endpoint=config.jaeger_endpoint,
        service_name=config.service_name,
    )
    
    # Add batch span processor
    span_processor = BatchSpanProcessor(jaeger_exporter)
    tracer_provider.add_span_processor(span_processor)
    
    # Optional: Add console exporter for debugging
    if config.enable_console_exporter:
        from opentelemetry.exporter.console import ConsoleSpanExporter
        console_exporter = ConsoleSpanExporter()
        console_processor = BatchSpanProcessor(console_exporter)
        tracer_provider.add_span_processor(console_processor)
    
    # Set up propagation format (B3 for compatibility)
    set_global_textmap(B3MultiFormat())
    
    # Get tracer
    tracer = trace.get_tracer(config.service_name)
    
    logger.info(
        "Tracing configured",
        service_name=config.service_name,
        jaeger_endpoint=config.jaeger_endpoint,
        sampling_rate=config.sampling_rate
    )
    
    return tracer


def instrument_fastapi(app, service_name: str):
    """
    Instrument FastAPI application with automatic tracing.
    
    Args:
        app: FastAPI application instance
        service_name: Name of the service for tracing
    """
    FastAPIInstrumentor.instrument_app(
        app,
        excluded_urls="health,metrics",  # Don't trace health checks and metrics
        tracer_provider=trace.get_tracer_provider(),
    )
    
    logger.info("FastAPI instrumentation enabled", service=service_name)


def instrument_external_libraries():
    """Instrument external libraries for automatic tracing."""
    
    # Instrument HTTP requests
    RequestsInstrumentor().instrument()
    
    # Instrument PostgreSQL connections
    Psycopg2Instrumentor().instrument()
    
    # Instrument Redis connections (if available)
    try:
        RedisInstrumentor().instrument()
    except Exception as e:
        logger.warning("Redis instrumentation failed", error=str(e))
    
    logger.info("External libraries instrumented for tracing")


def create_span_with_context(tracer: trace.Tracer, operation_name: str, **attributes):
    """
    Create a new span with context attributes.
    
    Args:
        tracer: OpenTelemetry tracer
        operation_name: Name of the operation being traced
        **attributes: Additional span attributes
        
    Returns:
        Span context manager
    """
    span = tracer.start_span(operation_name)
    
    # Add attributes
    for key, value in attributes.items():
        span.set_attribute(key, str(value))
    
    return span


def add_span_attributes(span: trace.Span, **attributes):
    """
    Add attributes to an existing span.
    
    Args:
        span: OpenTelemetry span
        **attributes: Key-value pairs to add as span attributes
    """
    for key, value in attributes.items():
        span.set_attribute(key, str(value))


def record_exception_in_span(span: trace.Span, exception: Exception):
    """
    Record an exception in a span.
    
    Args:
        span: OpenTelemetry span
        exception: Exception to record
    """
    span.record_exception(exception)
    span.set_status(trace.Status(trace.StatusCode.ERROR, str(exception)))


class TracingMiddleware:
    """Custom middleware to enhance tracing with business context."""
    
    def __init__(self, tracer: trace.Tracer):
        self.tracer = tracer
    
    def trace_operation(self, operation_name: str, **context):
        """
        Decorator to trace a function or method.
        
        Args:
            operation_name: Name of the operation
            **context: Additional context to add to span
        """
        def decorator(func):
            def wrapper(*args, **kwargs):
                with self.tracer.start_as_current_span(operation_name) as span:
                    # Add context attributes
                    add_span_attributes(span, **context)
                    
                    try:
                        result = func(*args, **kwargs)
                        span.set_status(trace.Status(trace.StatusCode.OK))
                        return result
                    except Exception as e:
                        record_exception_in_span(span, e)
                        raise
            return wrapper
        return decorator


# Utility functions for manual instrumentation

def get_current_span() -> Optional[trace.Span]:
    """Get the current active span."""
    return trace.get_current_span()


def add_event_to_current_span(name: str, **attributes):
    """Add an event to the current span."""
    span = get_current_span()
    if span:
        span.add_event(name, attributes)


def set_span_attribute(key: str, value: str):
    """Set an attribute on the current span."""
    span = get_current_span()
    if span:
        span.set_attribute(key, value)


# Service-specific tracing helpers

class LLMTracingHelper:
    """Helper class for tracing LLM operations."""
    
    @staticmethod
    def trace_llm_request(tracer: trace.Tracer, model: str, prompt_length: int):
        """Create a span for LLM request."""
        return create_span_with_context(
            tracer,
            "llm.request",
            model=model,
            prompt_length=prompt_length,
            operation="text_completion"
        )
    
    @staticmethod
    def add_llm_response_attributes(span: trace.Span, **kwargs):
        """Add LLM response attributes to span."""
        add_span_attributes(
            span,
            response_length=kwargs.get('response_length', 0),
            tokens_used=kwargs.get('tokens_used', 0),
            processing_time=kwargs.get('processing_time', 0)
        )


class DatabaseTracingHelper:
    """Helper class for tracing database operations."""
    
    @staticmethod
    def trace_db_query(tracer: trace.Tracer, operation: str, table: str = None):
        """Create a span for database query."""
        attributes = {"db.operation": operation}
        if table:
            attributes["db.collection.name"] = table
            
        return create_span_with_context(
            tracer,
            f"db.{operation}",
            **attributes
        )
    
    @staticmethod
    def add_db_query_attributes(span: trace.Span, query: str = None, rows_affected: int = None):
        """Add database query attributes to span."""
        if query:
            # Sanitize query (remove potential sensitive data)
            sanitized_query = query[:200] + "..." if len(query) > 200 else query
            span.set_attribute("db.statement", sanitized_query)
        
        if rows_affected is not None:
            span.set_attribute("db.rows_affected", rows_affected)


class HTTPTracingHelper:
    """Helper class for tracing HTTP operations."""
    
    @staticmethod
    def trace_http_client_request(tracer: trace.Tracer, method: str, url: str):
        """Create a span for HTTP client request."""
        return create_span_with_context(
            tracer,
            f"http.client.{method.lower()}",
            http_method=method,
            http_url=url,
            operation="http_client_request"
        )
    
    @staticmethod
    def add_http_response_attributes(span: trace.Span, status_code: int, response_size: int = None):
        """Add HTTP response attributes to span."""
        span.set_attribute("http.status_code", status_code)
        if response_size:
            span.set_attribute("http.response_size", response_size)


# Configuration for different environments

def get_production_tracing_config(service_name: str) -> TracingConfig:
    """Get production tracing configuration."""
    return TracingConfig(
        service_name=service_name,
        jaeger_endpoint=os.getenv("JAEGER_ENDPOINT", "http://jaeger:14268/api/traces"),
        sampling_rate=0.1,  # Sample 10% in production
        enable_console_exporter=False
    )


def get_development_tracing_config(service_name: str) -> TracingConfig:
    """Get development tracing configuration."""
    return TracingConfig(
        service_name=service_name,
        jaeger_endpoint="http://localhost:14268/api/traces",
        sampling_rate=1.0,  # Sample 100% in development
        enable_console_exporter=True
    )