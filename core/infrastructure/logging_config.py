"""Minimal logging configuration for infrastructure."""
import logging
import uuid
from contextvars import ContextVar
from typing import Optional

request_id: ContextVar[Optional[str]] = ContextVar('request_id', default=None)

def setup_logging(service_name: str = None, log_level: str = "INFO") -> logging.Logger:
    """Set up basic logging configuration."""
    level = getattr(logging, log_level.upper())
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Return a logger for the service
    logger_name = service_name or __name__
    return logging.getLogger(logger_name)

def get_request_id() -> str:
    """Get or generate a request ID."""
    current_id = request_id.get()
    if current_id is None:
        current_id = str(uuid.uuid4())
        request_id.set(current_id)
    return current_id