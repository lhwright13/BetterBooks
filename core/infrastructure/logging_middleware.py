"""Request/response logging middleware with request tracking."""
import logging
import time
import uuid
from typing import Optional
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

default_logger = logging.getLogger(__name__)


class LoggingMiddleware(BaseHTTPMiddleware):
    """Middleware that logs requests and responses with timing and request IDs."""

    def __init__(self, app, logger: Optional[logging.Logger] = None):
        super().__init__(app)
        self.logger = logger or default_logger

    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = str(uuid.uuid4())[:8]
        start_time = time.time()

        # Attach request_id to request state for use in handlers
        request.state.request_id = request_id

        # Log request
        query_string = str(request.query_params) if request.query_params else ""
        self.logger.info(
            f"[{request_id}] Request: {request.method} {request.url.path}"
            f"{' ?' + query_string if query_string else ''}"
        )

        try:
            response = await call_next(request)
            duration_ms = (time.time() - start_time) * 1000

            # Log response
            self.logger.info(
                f"[{request_id}] Response: {response.status_code} "
                f"({duration_ms:.1f}ms)"
            )

            # Add request ID to response headers for client tracking
            response.headers["X-Request-ID"] = request_id
            return response

        except Exception as exc:
            duration_ms = (time.time() - start_time) * 1000
            self.logger.error(
                f"[{request_id}] Error after {duration_ms:.1f}ms: "
                f"{type(exc).__name__}: {exc}"
            )
            raise
