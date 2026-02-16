import logging
from typing import Any, Optional, List

logger = logging.getLogger(__name__)


class NoOpMetric:

    def inc(self, value: float = 1) -> None:
        pass

    def observe(self, value: float) -> None:
        pass

    def labels(self, **kwargs) -> "NoOpMetric":
        return self


class MetricsCollector:

    def __init__(self, service_name: str = "unknown"):
        self.service_name = service_name
        logger.info(f"Metrics collector initialized for {service_name}")

    def create_counter(self, name: str, description: str, labels: Optional[List[str]] = None) -> NoOpMetric:
        return NoOpMetric()

    def create_histogram(self, name: str, description: str, buckets: Optional[tuple] = None) -> NoOpMetric:
        return NoOpMetric()

    def create_gauge(self, name: str, description: str) -> NoOpMetric:
        return NoOpMetric()


def setup_metrics(app: Any = None, service_name: str = "unknown") -> MetricsCollector:
    logger.info(f"Metrics collection initialized for {service_name}")
    return MetricsCollector(service_name)
