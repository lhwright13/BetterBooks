"""Minimal metrics collection."""
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

def setup_metrics() -> None:
    """Set up basic metrics collection."""
    logger.info("Metrics collection initialized")

def llm_tokens_used(tokens: int, model: str = "unknown") -> None:
    """Log LLM token usage."""
    logger.info(f"LLM tokens used: {tokens} (model: {model})")