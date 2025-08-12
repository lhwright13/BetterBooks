"""
Comprehensive Error Handling System

Provides standardized error handling across all services with:
- Consistent error response formats
- Error categorization and codes
- Automatic error logging and tracking
- Integration with monitoring systems
"""

import asyncio
import logging
import traceback
from datetime import datetime
from enum import Enum
from typing import Any, Dict, Optional, Type, Union, List
from fastapi import HTTPException, Request, Response
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from pydantic import BaseModel, Field
import httpx

logger = logging.getLogger(__name__)


class ErrorCategory(Enum):
    """Categorization of errors for better handling and monitoring"""
    VALIDATION = "validation"          # Input validation errors
    AUTHENTICATION = "authentication"  # Auth failures
    AUTHORIZATION = "authorization"    # Permission denied
    NOT_FOUND = "not_found"           # Resource not found
    CONFLICT = "conflict"              # Resource conflicts
    RATE_LIMIT = "rate_limit"         # Rate limiting
    EXTERNAL_SERVICE = "external_service"  # External API failures
    DATABASE = "database"              # Database errors
    INTERNAL = "internal"              # Internal server errors
    TIMEOUT = "timeout"                # Operation timeouts
    CIRCUIT_BREAKER = "circuit_breaker"  # Circuit breaker activated


class ErrorSeverity(Enum):
    """Error severity levels for monitoring and alerting"""
    LOW = "low"        # Informational, no action needed
    MEDIUM = "medium"  # Should be investigated
    HIGH = "high"      # Requires immediate attention
    CRITICAL = "critical"  # System-wide impact


class ErrorResponse(BaseModel):
    """Standardized error response format"""
    error: str = Field(..., description="Error type/code")
    message: str = Field(..., description="Human-readable error message")
    details: Optional[Dict[str, Any]] = Field(None, description="Additional error details")
    category: ErrorCategory = Field(..., description="Error category")
    severity: ErrorSeverity = Field(ErrorSeverity.MEDIUM, description="Error severity")
    timestamp: datetime = Field(default_factory=datetime.now, description="Error timestamp")
    request_id: Optional[str] = Field(None, description="Request correlation ID")
    documentation_url: Optional[str] = Field(None, description="Link to error documentation")
    retry_after: Optional[int] = Field(None, description="Seconds to wait before retry")


class ApplicationError(Exception):
    """Base application error with structured information"""
    
    def __init__(
        self,
        message: str,
        error_code: str = "APP_ERROR",
        category: ErrorCategory = ErrorCategory.INTERNAL,
        severity: ErrorSeverity = ErrorSeverity.MEDIUM,
        details: Optional[Dict[str, Any]] = None,
        status_code: int = 500,
        retry_after: Optional[int] = None
    ):
        self.message = message
        self.error_code = error_code
        self.category = category
        self.severity = severity
        self.details = details or {}
        self.status_code = status_code
        self.retry_after = retry_after
        super().__init__(message)
    
    def to_response(self, request_id: Optional[str] = None) -> ErrorResponse:
        """Convert to error response"""
        return ErrorResponse(
            error=self.error_code,
            message=self.message,
            details=self.details,
            category=self.category,
            severity=self.severity,
            request_id=request_id,
            retry_after=self.retry_after
        )


# Specific error types

class ValidationError(ApplicationError):
    """Input validation error"""
    def __init__(self, message: str, field: Optional[str] = None, **kwargs):
        details = kwargs.pop('details', {})
        if field:
            details['field'] = field
        super().__init__(
            message=message,
            error_code="VALIDATION_ERROR",
            category=ErrorCategory.VALIDATION,
            severity=ErrorSeverity.LOW,
            status_code=400,
            details=details,
            **kwargs
        )


class AuthenticationError(ApplicationError):
    """Authentication failure"""
    def __init__(self, message: str = "Authentication required", **kwargs):
        super().__init__(
            message=message,
            error_code="AUTH_REQUIRED",
            category=ErrorCategory.AUTHENTICATION,
            severity=ErrorSeverity.MEDIUM,
            status_code=401,
            **kwargs
        )


class AuthorizationError(ApplicationError):
    """Authorization failure"""
    def __init__(self, message: str = "Insufficient permissions", **kwargs):
        super().__init__(
            message=message,
            error_code="PERMISSION_DENIED",
            category=ErrorCategory.AUTHORIZATION,
            severity=ErrorSeverity.MEDIUM,
            status_code=403,
            **kwargs
        )


class NotFoundError(ApplicationError):
    """Resource not found"""
    def __init__(self, resource: str, identifier: Optional[str] = None, **kwargs):
        message = f"{resource} not found"
        if identifier:
            message = f"{resource} '{identifier}' not found"
        details = kwargs.pop('details', {})
        details.update({'resource': resource, 'identifier': identifier})
        super().__init__(
            message=message,
            error_code="NOT_FOUND",
            category=ErrorCategory.NOT_FOUND,
            severity=ErrorSeverity.LOW,
            status_code=404,
            details=details,
            **kwargs
        )


class ConflictError(ApplicationError):
    """Resource conflict"""
    def __init__(self, message: str, **kwargs):
        super().__init__(
            message=message,
            error_code="CONFLICT",
            category=ErrorCategory.CONFLICT,
            severity=ErrorSeverity.MEDIUM,
            status_code=409,
            **kwargs
        )


class RateLimitError(ApplicationError):
    """Rate limit exceeded"""
    def __init__(self, retry_after: int = 60, **kwargs):
        super().__init__(
            message="Rate limit exceeded. Please try again later.",
            error_code="RATE_LIMIT_EXCEEDED",
            category=ErrorCategory.RATE_LIMIT,
            severity=ErrorSeverity.LOW,
            status_code=429,
            retry_after=retry_after,
            **kwargs
        )


class ExternalServiceError(ApplicationError):
    """External service failure"""
    def __init__(self, service: str, message: Optional[str] = None, **kwargs):
        msg = f"External service '{service}' error"
        if message:
            msg = f"{msg}: {message}"
        details = kwargs.pop('details', {})
        details['service'] = service
        super().__init__(
            message=msg,
            error_code="EXTERNAL_SERVICE_ERROR",
            category=ErrorCategory.EXTERNAL_SERVICE,
            severity=ErrorSeverity.HIGH,
            status_code=502,
            details=details,
            **kwargs
        )


class DatabaseError(ApplicationError):
    """Database operation error"""
    def __init__(self, operation: str, message: Optional[str] = None, **kwargs):
        msg = f"Database {operation} failed"
        if message:
            msg = f"{msg}: {message}"
        details = kwargs.pop('details', {})
        details['operation'] = operation
        super().__init__(
            message=msg,
            error_code="DATABASE_ERROR",
            category=ErrorCategory.DATABASE,
            severity=ErrorSeverity.HIGH,
            status_code=500,
            details=details,
            **kwargs
        )


class TimeoutError(ApplicationError):
    """Operation timeout"""
    def __init__(self, operation: str, timeout: float, **kwargs):
        details = kwargs.pop('details', {})
        details.update({'operation': operation, 'timeout_seconds': timeout})
        super().__init__(
            message=f"Operation '{operation}' timed out after {timeout} seconds",
            error_code="TIMEOUT",
            category=ErrorCategory.TIMEOUT,
            severity=ErrorSeverity.MEDIUM,
            status_code=504,
            details=details,
            **kwargs
        )


class CircuitBreakerError(ApplicationError):
    """Circuit breaker activated"""
    def __init__(self, service: str, retry_after: int = 30, **kwargs):
        details = kwargs.pop('details', {})
        details['service'] = service
        super().__init__(
            message=f"Service '{service}' is temporarily unavailable",
            error_code="CIRCUIT_BREAKER_OPEN",
            category=ErrorCategory.CIRCUIT_BREAKER,
            severity=ErrorSeverity.MEDIUM,
            status_code=503,
            retry_after=retry_after,
            details=details,
            **kwargs
        )


class ErrorHandler:
    """Centralized error handler for FastAPI applications"""
    
    def __init__(
        self,
        service_name: str,
        include_stack_trace: bool = False,
        error_callbacks: Optional[List] = None
    ):
        self.service_name = service_name
        self.include_stack_trace = include_stack_trace
        self.error_callbacks = error_callbacks or []
        self.error_counts = {}
    
    def get_request_id(self, request: Request) -> Optional[str]:
        """Extract request ID from request"""
        return request.headers.get("X-Request-ID") or \
               request.state.__dict__.get("request_id")
    
    async def handle_application_error(
        self,
        request: Request,
        exc: ApplicationError
    ) -> JSONResponse:
        """Handle application-specific errors"""
        request_id = self.get_request_id(request)
        error_response = exc.to_response(request_id)
        
        # Log the error
        logger.error(
            f"Application error in {self.service_name}",
            extra={
                "error_code": exc.error_code,
                "category": exc.category.value,
                "severity": exc.severity.value,
                "request_id": request_id,
                "path": request.url.path,
                "method": request.method,
                "details": exc.details
            }
        )
        
        # Track error count
        self._track_error(exc.error_code, exc.category)
        
        # Execute callbacks
        await self._execute_callbacks(request, exc, error_response)
        
        return JSONResponse(
            status_code=exc.status_code,
            content=error_response.model_dump(exclude_none=True)
        )
    
    async def handle_http_exception(
        self,
        request: Request,
        exc: Union[HTTPException, StarletteHTTPException]
    ) -> JSONResponse:
        """Handle FastAPI/Starlette HTTP exceptions"""
        request_id = self.get_request_id(request)
        
        # Map status codes to categories
        category_map = {
            400: ErrorCategory.VALIDATION,
            401: ErrorCategory.AUTHENTICATION,
            403: ErrorCategory.AUTHORIZATION,
            404: ErrorCategory.NOT_FOUND,
            409: ErrorCategory.CONFLICT,
            429: ErrorCategory.RATE_LIMIT,
            500: ErrorCategory.INTERNAL,
            502: ErrorCategory.EXTERNAL_SERVICE,
            503: ErrorCategory.CIRCUIT_BREAKER,
            504: ErrorCategory.TIMEOUT
        }
        
        category = category_map.get(exc.status_code, ErrorCategory.INTERNAL)
        severity = ErrorSeverity.HIGH if exc.status_code >= 500 else ErrorSeverity.MEDIUM
        
        error_response = ErrorResponse(
            error=f"HTTP_{exc.status_code}",
            message=str(exc.detail),
            category=category,
            severity=severity,
            request_id=request_id
        )
        
        # Log the error
        log_level = logging.ERROR if exc.status_code >= 500 else logging.WARNING
        logger.log(
            log_level,
            f"HTTP exception in {self.service_name}",
            extra={
                "status_code": exc.status_code,
                "category": category.value,
                "request_id": request_id,
                "path": request.url.path,
                "method": request.method
            }
        )
        
        return JSONResponse(
            status_code=exc.status_code,
            content=error_response.model_dump(exclude_none=True)
        )
    
    async def handle_validation_error(
        self,
        request: Request,
        exc: RequestValidationError
    ) -> JSONResponse:
        """Handle Pydantic validation errors"""
        request_id = self.get_request_id(request)
        
        # Format validation errors
        errors = []
        for error in exc.errors():
            field = ".".join(str(loc) for loc in error["loc"])
            errors.append({
                "field": field,
                "message": error["msg"],
                "type": error["type"]
            })
        
        error_response = ErrorResponse(
            error="VALIDATION_ERROR",
            message="Request validation failed",
            details={"validation_errors": errors},
            category=ErrorCategory.VALIDATION,
            severity=ErrorSeverity.LOW,
            request_id=request_id
        )
        
        logger.warning(
            f"Validation error in {self.service_name}",
            extra={
                "request_id": request_id,
                "path": request.url.path,
                "method": request.method,
                "errors": errors
            }
        )
        
        return JSONResponse(
            status_code=422,
            content=error_response.model_dump(exclude_none=True)
        )
    
    async def handle_generic_exception(
        self,
        request: Request,
        exc: Exception
    ) -> JSONResponse:
        """Handle unexpected exceptions"""
        request_id = self.get_request_id(request)
        
        # Create error response
        error_response = ErrorResponse(
            error="INTERNAL_SERVER_ERROR",
            message="An unexpected error occurred",
            category=ErrorCategory.INTERNAL,
            severity=ErrorSeverity.CRITICAL,
            request_id=request_id
        )
        
        if self.include_stack_trace:
            error_response.details = {
                "exception": str(exc),
                "traceback": traceback.format_exc()
            }
        
        # Log the error with full stack trace
        logger.exception(
            f"Unexpected error in {self.service_name}",
            extra={
                "request_id": request_id,
                "path": request.url.path,
                "method": request.method,
                "exception_type": type(exc).__name__
            }
        )
        
        # Track critical error
        self._track_error("INTERNAL_SERVER_ERROR", ErrorCategory.INTERNAL)
        
        return JSONResponse(
            status_code=500,
            content=error_response.model_dump(exclude_none=True)
        )
    
    def _track_error(self, error_code: str, category: ErrorCategory):
        """Track error occurrences for monitoring"""
        key = f"{category.value}:{error_code}"
        self.error_counts[key] = self.error_counts.get(key, 0) + 1
    
    async def _execute_callbacks(
        self,
        request: Request,
        exc: Exception,
        error_response: ErrorResponse
    ):
        """Execute registered error callbacks"""
        for callback in self.error_callbacks:
            try:
                if asyncio.iscoroutinefunction(callback):
                    await callback(request, exc, error_response)
                else:
                    callback(request, exc, error_response)
            except Exception as e:
                logger.error(f"Error callback failed: {e}")
    
    def get_error_stats(self) -> Dict[str, int]:
        """Get error statistics"""
        return self.error_counts.copy()
    
    def reset_error_stats(self):
        """Reset error statistics"""
        self.error_counts.clear()


def setup_error_handling(app, service_name: str, include_stack_trace: bool = False):
    """
    Set up comprehensive error handling for a FastAPI application
    
    Args:
        app: FastAPI application instance
        service_name: Name of the service for logging
        include_stack_trace: Include stack traces in error responses (dev only)
    """
    error_handler = ErrorHandler(
        service_name=service_name,
        include_stack_trace=include_stack_trace
    )
    
    # Register exception handlers
    app.add_exception_handler(ApplicationError, error_handler.handle_application_error)
    app.add_exception_handler(HTTPException, error_handler.handle_http_exception)
    app.add_exception_handler(StarletteHTTPException, error_handler.handle_http_exception)
    app.add_exception_handler(RequestValidationError, error_handler.handle_validation_error)
    app.add_exception_handler(Exception, error_handler.handle_generic_exception)
    
    # Add error stats endpoint
    @app.get("/errors/stats", include_in_schema=False)
    async def get_error_stats():
        """Get error statistics for monitoring"""
        return {
            "service": service_name,
            "errors": error_handler.get_error_stats(),
            "timestamp": datetime.now().isoformat()
        }
    
    return error_handler


# Utility functions for error handling

def handle_external_service_error(service_name: str, error: Exception) -> ApplicationError:
    """Convert external service errors to application errors"""
    if isinstance(error, httpx.HTTPStatusError):
        return ExternalServiceError(
            service=service_name,
            message=f"HTTP {error.response.status_code}",
            details={
                "status_code": error.response.status_code,
                "response": error.response.text[:500]  # Truncate long responses
            }
        )
    elif isinstance(error, httpx.TimeoutException):
        return TimeoutError(
            operation=f"{service_name} request",
            timeout=30  # Default timeout
        )
    elif isinstance(error, ConnectionError):
        return ExternalServiceError(
            service=service_name,
            message="Connection failed",
            details={"error": str(error)}
        )
    else:
        return ExternalServiceError(
            service=service_name,
            message=str(error)
        )


def validate_required_fields(data: dict, required_fields: List[str]):
    """Validate required fields in a dictionary"""
    missing_fields = [field for field in required_fields if field not in data]
    if missing_fields:
        raise ValidationError(
            message=f"Missing required fields: {', '.join(missing_fields)}",
            details={"missing_fields": missing_fields}
        )