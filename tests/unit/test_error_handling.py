"""
Test Comprehensive Error Handling System
"""

import pytest
from datetime import datetime
from fastapi import FastAPI, HTTPException, Request
from fastapi.testclient import TestClient
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel, Field
import httpx

from core.infrastructure.error_handling import (
    ApplicationError, ValidationError, AuthenticationError,
    AuthorizationError, NotFoundError, ConflictError,
    RateLimitError, ExternalServiceError, DatabaseError,
    TimeoutError, CircuitBreakerError, ErrorHandler,
    ErrorCategory, ErrorSeverity, ErrorResponse,
    setup_error_handling, handle_external_service_error
)


def test_application_error_creation():
    """Test creating application errors"""
    error = ApplicationError(
        message="Test error",
        error_code="TEST_ERROR",
        category=ErrorCategory.INTERNAL,
        severity=ErrorSeverity.HIGH,
        details={"key": "value"},
        status_code=500
    )
    
    assert error.message == "Test error"
    assert error.error_code == "TEST_ERROR"
    assert error.category == ErrorCategory.INTERNAL
    assert error.severity == ErrorSeverity.HIGH
    assert error.details == {"key": "value"}
    assert error.status_code == 500


def test_validation_error():
    """Test validation error creation"""
    error = ValidationError(
        message="Invalid input",
        field="username"
    )
    
    assert error.error_code == "VALIDATION_ERROR"
    assert error.category == ErrorCategory.VALIDATION
    assert error.status_code == 400
    assert error.details["field"] == "username"


def test_not_found_error():
    """Test not found error creation"""
    error = NotFoundError(
        resource="User",
        identifier="123"
    )
    
    assert error.message == "User '123' not found"
    assert error.error_code == "NOT_FOUND"
    assert error.category == ErrorCategory.NOT_FOUND
    assert error.status_code == 404
    assert error.details["resource"] == "User"
    assert error.details["identifier"] == "123"


def test_external_service_error():
    """Test external service error creation"""
    error = ExternalServiceError(
        service="Payment Gateway",
        message="Connection timeout"
    )
    
    assert "Payment Gateway" in error.message
    assert "Connection timeout" in error.message
    assert error.error_code == "EXTERNAL_SERVICE_ERROR"
    assert error.category == ErrorCategory.EXTERNAL_SERVICE
    assert error.status_code == 502


def test_error_response_model():
    """Test error response model"""
    response = ErrorResponse(
        error="TEST_ERROR",
        message="Test message",
        category=ErrorCategory.INTERNAL,
        severity=ErrorSeverity.MEDIUM,
        request_id="req-123",
        retry_after=60
    )
    
    assert response.error == "TEST_ERROR"
    assert response.message == "Test message"
    assert response.category == ErrorCategory.INTERNAL
    assert response.severity == ErrorSeverity.MEDIUM
    assert response.request_id == "req-123"
    assert response.retry_after == 60
    assert isinstance(response.timestamp, datetime)


def test_error_to_response_conversion():
    """Test converting error to response"""
    error = RateLimitError(retry_after=30)
    response = error.to_response(request_id="req-456")
    
    assert response.error == "RATE_LIMIT_EXCEEDED"
    assert response.category == ErrorCategory.RATE_LIMIT
    assert response.request_id == "req-456"
    assert response.retry_after == 30


def test_handle_external_service_error_http():
    """Test handling HTTP status errors"""
    # Create mock HTTP error
    response = httpx.Response(
        status_code=503,
        content=b"Service unavailable",
        request=httpx.Request("GET", "http://test.com")
    )
    http_error = httpx.HTTPStatusError(
        "HTTP error",
        request=response.request,
        response=response
    )
    
    app_error = handle_external_service_error("TestService", http_error)
    
    assert isinstance(app_error, ExternalServiceError)
    assert "TestService" in app_error.message
    assert "HTTP 503" in app_error.message
    assert app_error.details["status_code"] == 503


def test_handle_external_service_error_timeout():
    """Test handling timeout errors"""
    timeout_error = httpx.TimeoutException("Request timeout")
    
    app_error = handle_external_service_error("TestService", timeout_error)
    
    assert isinstance(app_error, TimeoutError)
    assert "TestService" in app_error.message
    assert app_error.category == ErrorCategory.TIMEOUT


def test_handle_external_service_error_connection():
    """Test handling connection errors"""
    conn_error = ConnectionError("Connection refused")
    
    app_error = handle_external_service_error("TestService", conn_error)
    
    assert isinstance(app_error, ExternalServiceError)
    assert "TestService" in app_error.message
    assert "Connection failed" in app_error.message


@pytest.fixture
def test_app():
    """Create test FastAPI app with error handling"""
    app = FastAPI()
    
    # Set up error handling
    error_handler = setup_error_handling(
        app,
        service_name="test_service",
        include_stack_trace=True
    )
    
    # Add test endpoints
    @app.get("/test/application-error")
    async def raise_application_error():
        raise ValidationError("Test validation error", field="test_field")
    
    @app.get("/test/http-error")
    async def raise_http_error():
        raise HTTPException(status_code=404, detail="Resource not found")
    
    @app.post("/test/validation")
    async def test_validation(data: dict):
        # This will trigger validation error if dict is invalid
        return data
    
    @app.get("/test/generic-error")
    async def raise_generic_error():
        raise ValueError("Unexpected error")
    
    @app.get("/test/auth-error")
    async def raise_auth_error():
        raise AuthenticationError("Invalid token")
    
    @app.get("/test/not-found")
    async def raise_not_found():
        raise NotFoundError("Book", "book-123")
    
    return TestClient(app), error_handler


def test_application_error_handler(test_app):
    """Test handling application errors"""
    client, handler = test_app
    
    response = client.get("/test/application-error")
    assert response.status_code == 400
    
    data = response.json()
    assert data["error"] == "VALIDATION_ERROR"
    assert data["message"] == "Test validation error"
    assert data["category"] == "validation"
    assert data["details"]["field"] == "test_field"


def test_http_exception_handler(test_app):
    """Test handling HTTP exceptions"""
    client, handler = test_app
    
    response = client.get("/test/http-error")
    assert response.status_code == 404
    
    data = response.json()
    assert data["error"] == "HTTP_404"
    assert data["message"] == "Resource not found"
    assert data["category"] == "not_found"


def test_validation_error_handler(test_app):
    """Test handling validation errors"""
    client, handler = test_app
    
    # Send invalid JSON to trigger validation error
    response = client.post(
        "/test/validation",
        content="invalid json"
    )
    assert response.status_code == 422
    
    data = response.json()
    assert data["error"] == "VALIDATION_ERROR"
    assert data["message"] == "Request validation failed"
    assert "validation_errors" in data["details"]


def test_generic_exception_handler(test_app):
    """Test handling unexpected exceptions"""
    client, handler = test_app
    
    response = client.get("/test/generic-error")
    assert response.status_code == 500
    
    data = response.json()
    assert data["error"] == "INTERNAL_SERVER_ERROR"
    assert data["message"] == "An unexpected error occurred"
    assert data["category"] == "internal"
    assert data["severity"] == "critical"
    # Since include_stack_trace=True, we should have traceback
    assert "traceback" in data["details"]


def test_auth_error_handler(test_app):
    """Test handling authentication errors"""
    client, handler = test_app
    
    response = client.get("/test/auth-error")
    assert response.status_code == 401
    
    data = response.json()
    assert data["error"] == "AUTH_REQUIRED"
    assert data["message"] == "Invalid token"
    assert data["category"] == "authentication"


def test_not_found_error_handler(test_app):
    """Test handling not found errors"""
    client, handler = test_app
    
    response = client.get("/test/not-found")
    assert response.status_code == 404
    
    data = response.json()
    assert data["error"] == "NOT_FOUND"
    assert data["message"] == "Book 'book-123' not found"
    assert data["details"]["resource"] == "Book"
    assert data["details"]["identifier"] == "book-123"


def test_error_stats_tracking(test_app):
    """Test error statistics tracking"""
    client, handler = test_app
    
    # Generate some errors
    client.get("/test/application-error")
    client.get("/test/application-error")
    client.get("/test/http-error")
    client.get("/test/generic-error")
    
    # Check error stats
    response = client.get("/errors/stats")
    assert response.status_code == 200
    
    data = response.json()
    assert data["service"] == "test_service"
    assert "errors" in data
    
    # Verify error counts
    errors = data["errors"]
    assert errors.get("validation:VALIDATION_ERROR", 0) >= 2
    assert errors.get("internal:INTERNAL_SERVER_ERROR", 0) >= 1


def test_error_handler_callbacks():
    """Test error handler callbacks"""
    callback_called = False
    callback_error = None
    
    def error_callback(request, exc, error_response):
        nonlocal callback_called, callback_error
        callback_called = True
        callback_error = exc
    
    handler = ErrorHandler(
        service_name="test",
        error_callbacks=[error_callback]
    )
    
    # Create a test request
    class MockRequest:
        def __init__(self):
            self.headers = {}
            self.state = type('', (), {})()
            self.url = type('', (), {'path': '/test'})()
            self.method = "GET"
    
    request = MockRequest()
    error = ValidationError("Test error")
    
    # This would normally be async, but we can test the callback registration
    assert len(handler.error_callbacks) == 1
    assert handler.error_callbacks[0] == error_callback


def test_circuit_breaker_error():
    """Test circuit breaker error creation"""
    error = CircuitBreakerError(
        service="TestService",
        retry_after=60
    )
    
    assert "TestService" in error.message
    assert "temporarily unavailable" in error.message
    assert error.error_code == "CIRCUIT_BREAKER_OPEN"
    assert error.category == ErrorCategory.CIRCUIT_BREAKER
    assert error.status_code == 503
    assert error.retry_after == 60


def test_database_error():
    """Test database error creation"""
    error = DatabaseError(
        operation="insert",
        message="Unique constraint violation"
    )
    
    assert "insert" in error.message
    assert "Unique constraint violation" in error.message
    assert error.error_code == "DATABASE_ERROR"
    assert error.category == ErrorCategory.DATABASE
    assert error.status_code == 500
    assert error.details["operation"] == "insert"


def test_timeout_error():
    """Test timeout error creation"""
    error = TimeoutError(
        operation="API call",
        timeout=30.0
    )
    
    assert "API call" in error.message
    assert "30" in error.message
    assert error.error_code == "TIMEOUT"
    assert error.category == ErrorCategory.TIMEOUT
    assert error.status_code == 504
    assert error.details["timeout_seconds"] == 30.0