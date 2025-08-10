"""
Shared logging configuration for all services.
Provides structured JSON logging with correlation IDs and proper log levels.
"""

import logging
import json
import sys
from datetime import datetime
from typing import Any, Dict, Optional
import traceback
from contextvars import ContextVar

# Context variable for tracking request IDs across async calls
request_id_var: ContextVar[Optional[str]] = ContextVar('request_id', default=None)

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging.
    
    Formats log records as JSON objects with consistent structure including:
    - timestamp: ISO format timestamp
    - level: Log level name (INFO, ERROR, etc.)
    - logger: Logger name
    - message: Log message
    - module/function/line: Code location
    - request_id: Correlation ID if available
    - exception: Exception details if present
    - Additional custom fields passed to log methods
    """
    
    def format(self, record: logging.LogRecord) -> str:
        log_obj = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # Add request ID if available
        request_id = request_id_var.get()
        if request_id:
            log_obj["request_id"] = request_id
        
        # Add exception info if present
        if record.exc_info and record.exc_info[0] is not None:
            log_obj["exception"] = {
                "type": record.exc_info[0].__name__,
                "message": str(record.exc_info[1]),
                "traceback": traceback.format_exception(*record.exc_info)
            }
        
        # Add any extra fields
        if hasattr(record, "extra_fields"):
            log_obj.update(record.extra_fields)
        
        return json.dumps(log_obj, default=str)

class StructuredLogger:
    """Wrapper for structured logging with extra fields.
    
    Provides convenient methods for logging with automatic inclusion
    of extra fields as structured data in the JSON output.
    
    Example:
        logger = StructuredLogger(python_logger)
        logger.info("User logged in", user_id="123", ip="10.0.0.1")
    """
    
    def __init__(self, logger: logging.Logger):
        self.logger = logger
    
    def _log(self, level: int, msg: str, extra_fields: Optional[Dict[str, Any]] = None, **kwargs):
        if extra_fields:
            kwargs["extra"] = {"extra_fields": extra_fields}
        self.logger.log(level, msg, **kwargs)
    
    def debug(self, msg: str, **extra_fields):
        self._log(logging.DEBUG, msg, extra_fields)
    
    def info(self, msg: str, **extra_fields):
        self._log(logging.INFO, msg, extra_fields)
    
    def warning(self, msg: str, **extra_fields):
        self._log(logging.WARNING, msg, extra_fields)
    
    def error(self, msg: str, exc_info: bool = False, **extra_fields):
        self._log(logging.ERROR, msg, extra_fields, exc_info=exc_info)
    
    def critical(self, msg: str, exc_info: bool = False, **extra_fields):
        self._log(logging.CRITICAL, msg, extra_fields, exc_info=exc_info)

def setup_logging(
    service_name: str,
    log_level: str = "INFO",
    log_to_file: bool = False,
    log_file_path: Optional[str] = None
) -> StructuredLogger:
    """
    Set up structured JSON logging for a service.
    
    Args:
        service_name: Name of the service for identification
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_to_file: Whether to also log to a file
        log_file_path: Path to log file if log_to_file is True
    
    Returns:
        StructuredLogger instance
    """
    logger = logging.getLogger(service_name)
    logger.setLevel(getattr(logging, log_level.upper()))
    
    # Remove any existing handlers
    logger.handlers = []
    
    # Create JSON formatter
    formatter = JSONFormatter()
    
    # Console handler (stdout)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # File handler if requested
    if log_to_file:
        if not log_file_path:
            log_file_path = f"/var/log/{service_name}.log"
        file_handler = logging.FileHandler(log_file_path)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    # Prevent propagation to root logger
    logger.propagate = False
    
    return StructuredLogger(logger)

def set_request_id(request_id: str):
    """Set the request ID for the current context.
    
    The request ID will be automatically included in all log messages
    within this async context until cleared.
    
    Args:
        request_id: Unique identifier for the current request
    """
    request_id_var.set(request_id)

def get_request_id() -> Optional[str]:
    """Get the request ID from the current context.
    
    Returns:
        The current request ID or None if not set
    """
    return request_id_var.get()

def clear_request_id():
    """Clear the request ID from the current context.
    
    Should be called at the end of request processing to prevent
    request ID leakage between requests.
    """
    request_id_var.set(None)