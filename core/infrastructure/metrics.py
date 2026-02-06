"""Minimal metrics collection for local development."""
import logging
from typing import Any, Optional, List

logger = logging.getLogger(__name__)


class NoOpMetric:
    """A no-op metric that does nothing (for local development)."""

    def inc(self, value: float = 1) -> None:
        """Increment counter (no-op)."""
        pass

    def observe(self, value: float) -> None:
        """Observe value for histogram (no-op)."""
        pass

    def labels(self, **kwargs) -> "NoOpMetric":
        """Return self for chaining (no-op)."""
        return self


class MetricsCollector:
    """A minimal metrics collector for local development."""

    def __init__(self, service_name: str = "unknown"):
        self.service_name = service_name
        logger.info(f"Metrics collector initialized for {service_name}")

    def create_counter(self, name: str, description: str, labels: Optional[List[str]] = None) -> NoOpMetric:
        """Create a no-op counter."""
        return NoOpMetric()

    def create_histogram(self, name: str, description: str, buckets: Optional[tuple] = None) -> NoOpMetric:
        """Create a no-op histogram."""
        return NoOpMetric()

    def create_gauge(self, name: str, description: str) -> NoOpMetric:
        """Create a no-op gauge."""
        return NoOpMetric()


def setup_metrics(app: Any = None, service_name: str = "unknown") -> MetricsCollector:
    """Set up basic metrics collection and return a collector."""
    logger.info(f"Metrics collection initialized for {service_name}")
    return MetricsCollector(service_name)


def llm_tokens_used(tokens: int, model: str = "unknown") -> None:
    """Log LLM token usage."""
    logger.info(f"LLM tokens used: {tokens} (model: {model})")
