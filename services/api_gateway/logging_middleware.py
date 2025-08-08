"""
FastAPI middleware for structured logging and request tracking.
"""

import time
import uuid
from typing import Callable
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from logging_config import set_request_id, clear_request_id, get_request_id

class LoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to add request ID and log all requests"""
    
    def __init__(self, app, logger):
        super().__init__(app)
        self.logger = logger
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Generate or extract request ID
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        
        # Set request ID in context
        set_request_id(request_id)
        
        # Track request timing
        start_time = time.time()
        
        # Log request
        self.logger.info(
            "Request started",
            method=request.method,
            path=request.url.path,
            client_host=request.client.host if request.client else None,
            request_id=request_id
        )
        
        try:
            # Process request
            response = await call_next(request)
            
            # Calculate duration
            duration = time.time() - start_time
            
            # Log response
            self.logger.info(
                "Request completed",
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                duration_seconds=duration,
                request_id=request_id
            )
            
            # Add request ID to response headers
            response.headers["X-Request-ID"] = request_id
            
            return response
            
        except Exception as e:
            # Calculate duration
            duration = time.time() - start_time
            
            # Log error
            self.logger.error(
                "Request failed",
                method=request.method,
                path=request.url.path,
                error=str(e),
                duration_seconds=duration,
                request_id=request_id
            )
            raise
        
        finally:
            # Clear request ID from context
            clear_request_id()