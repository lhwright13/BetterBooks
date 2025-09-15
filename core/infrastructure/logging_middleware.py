"""Minimal logging middleware."""
import logging
from typing import Callable
from fastapi import Request, Response

logger = logging.getLogger(__name__)

class LoggingMiddleware:
    """Basic logging middleware for FastAPI."""
    
    def __init__(self, app):
        self.app = app
    
    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            request = Request(scope, receive)
            logger.info(f"Request: {request.method} {request.url}")
        
        await self.app(scope, receive, send)