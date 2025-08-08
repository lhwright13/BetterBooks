"""
Comprehensive health check utilities for all services.
Provides detailed health status including dependencies and metrics.
"""

import time
import psutil
import asyncio
from typing import Dict, Any, List, Optional, Callable
from datetime import datetime
from enum import Enum

class HealthStatus(Enum):
    """Health status levels for service monitoring.
    
    HEALTHY: All checks passing, service fully operational
    DEGRADED: Some non-critical checks failing, service partially operational
    UNHEALTHY: Critical checks failing, service not operational
    """
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"

class HealthCheck:
    """Comprehensive health check manager for a service.
    
    Manages multiple health checks and aggregates their results into
    a single health status. Supports both synchronous and asynchronous
    check functions.
    
    Example:
        health = HealthCheck("my_service", "1.0.0")
        health.add_check("database", check_db_connection)
        health.add_check("cache", check_redis)
        status = await health.get_health()
    """
    
    def __init__(self, service_name: str, version: str = "1.0.0"):
        self.service_name = service_name
        self.version = version
        self.start_time = time.time()
        self.checks: List[Callable] = []
    
    def add_check(self, name: str, check_func: Callable) -> None:
        """Add a custom health check.
        
        Args:
            name: Unique name for this health check
            check_func: Function that returns True/False or a dict with details.
                       Can be sync or async.
        """
        self.checks.append((name, check_func))
    
    async def get_health(self) -> Dict[str, Any]:
        """Get comprehensive health status.
        
        Runs all registered health checks and aggregates results.
        
        Returns:
            Dict containing:
            - service: Service name
            - version: Service version
            - status: Overall health status (healthy/degraded/unhealthy)
            - timestamp: Current UTC timestamp
            - uptime_seconds: Service uptime
            - checks: Results of individual health checks
            - metrics: System resource metrics
        """
        health_data = {
            "service": self.service_name,
            "version": self.version,
            "status": HealthStatus.HEALTHY.value,
            "timestamp": datetime.utcnow().isoformat(),
            "uptime_seconds": time.time() - self.start_time,
            "checks": {},
            "metrics": self._get_system_metrics()
        }
        
        # Run all custom health checks
        for name, check_func in self.checks:
            try:
                if asyncio.iscoroutinefunction(check_func):
                    result = await check_func()
                else:
                    result = check_func()
                
                health_data["checks"][name] = {
                    "status": "healthy" if result else "unhealthy",
                    "details": result if isinstance(result, dict) else None
                }
                
                # Update overall status
                if not result:
                    health_data["status"] = HealthStatus.UNHEALTHY.value
                    
            except Exception as e:
                health_data["checks"][name] = {
                    "status": "unhealthy",
                    "error": str(e)
                }
                health_data["status"] = HealthStatus.UNHEALTHY.value
        
        return health_data
    
    def _get_system_metrics(self) -> Dict[str, Any]:
        """Get system resource metrics"""
        try:
            return {
                "cpu_percent": psutil.cpu_percent(interval=0.1),
                "memory": {
                    "percent": psutil.virtual_memory().percent,
                    "available_mb": psutil.virtual_memory().available / 1024 / 1024,
                    "used_mb": psutil.virtual_memory().used / 1024 / 1024
                },
                "disk": {
                    "percent": psutil.disk_usage('/').percent,
                    "free_gb": psutil.disk_usage('/').free / 1024 / 1024 / 1024
                }
            }
        except Exception:
            return {}

async def check_database(connection_string: str) -> bool:
    """Check PostgreSQL database connectivity.
    
    Args:
        connection_string: PostgreSQL connection string
        
    Returns:
        True if database is reachable, False otherwise
    """
    try:
        import asyncpg
        conn = await asyncpg.connect(connection_string)
        await conn.fetchval('SELECT 1')
        await conn.close()
        return True
    except Exception:
        return False

async def check_redis(redis_url: str) -> bool:
    """Check Redis connectivity"""
    try:
        import aioredis
        redis = await aioredis.create_redis_pool(redis_url)
        await redis.ping()
        redis.close()
        await redis.wait_closed()
        return True
    except Exception:
        return False

async def check_service_endpoint(url: str, timeout: int = 5) -> Dict[str, Any]:
    """Check if another service endpoint is reachable.
    
    Args:
        url: Base URL of the service to check
        timeout: Request timeout in seconds
        
    Returns:
        Dict containing:
        - reachable: Whether the service responded successfully
        - status_code: HTTP status code if reachable
        - latency_ms: Response time in milliseconds
        - error: Error message if not reachable
    """
    try:
        import httpx
        async with httpx.AsyncClient() as client:
            start = time.time()
            response = await client.get(f"{url}/health", timeout=timeout)
            latency = (time.time() - start) * 1000  # Convert to ms
            
            return {
                "reachable": response.status_code == 200,
                "status_code": response.status_code,
                "latency_ms": round(latency, 2)
            }
    except Exception as e:
        return {
            "reachable": False,
            "error": str(e)
        }

def create_health_endpoint(app, health_check: HealthCheck):
    """Create comprehensive health endpoints for a FastAPI app.
    
    Creates four endpoints:
    - /health: Basic liveness check
    - /health/detailed: Full health status with metrics
    - /health/ready: Readiness probe for load balancers
    - /health/live: Liveness probe for orchestrators
    
    Args:
        app: FastAPI application instance
        health_check: HealthCheck instance with registered checks
    """
    
    @app.get("/health")
    async def health():
        """Basic health check for load balancers"""
        return {"status": "ok"}
    
    @app.get("/health/detailed")
    async def health_detailed():
        """Detailed health check with all metrics"""
        return await health_check.get_health()
    
    @app.get("/health/ready")
    async def readiness():
        """Readiness probe - checks if service is ready to handle requests"""
        health_data = await health_check.get_health()
        if health_data["status"] == HealthStatus.UNHEALTHY.value:
            from fastapi import HTTPException
            raise HTTPException(status_code=503, detail="Service not ready")
        return {"ready": True}
    
    @app.get("/health/live")
    async def liveness():
        """Liveness probe - basic check if service is alive"""
        return {"alive": True}