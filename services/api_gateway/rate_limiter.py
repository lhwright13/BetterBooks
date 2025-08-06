"""
Redis-based Rate Limiting for EchoWright API Gateway

Provides distributed rate limiting using Redis with sliding window algorithm.
Supports different rate limits for different endpoints and user types.

Features:
- Sliding window rate limiting
- Per-user and per-IP rate limits
- Different limits for different endpoints
- Burst handling
- Graceful degradation when Redis unavailable
"""

import redis
import time
import logging
from typing import Optional, Dict, Any
from fastapi import HTTPException, status, Request
from contextlib import asynccontextmanager

logger = logging.getLogger(__name__)

class RateLimiter:
    """Redis-based rate limiter with sliding window algorithm"""
    
    def __init__(self, redis_url: str = "redis://redis:6379/0"):
        try:
            self.redis_client = redis.Redis.from_url(redis_url)
            self.redis_client.ping()
            self.available = True
            logger.info("Rate limiter connected to Redis")
        except Exception as e:
            logger.warning(f"Rate limiter Redis connection failed: {e}")
            self.redis_client = None
            self.available = False
    
    async def check_rate_limit(
        self,
        key: str,
        limit: int,
        window: int,
        burst_limit: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Check rate limit using sliding window algorithm
        
        Args:
            key: Unique identifier (user_id, IP, etc.)
            limit: Maximum requests per window
            window: Time window in seconds
            burst_limit: Optional burst limit for short-term spikes
            
        Returns:
            Dict with limit info and whether request is allowed
            
        Raises:
            HTTPException: If rate limit exceeded
        """
        if not self.available:
            return {"allowed": True, "remaining": limit}
        
        try:
            current_time = time.time()
            window_start = current_time - window
            
            # Redis pipeline for atomic operations
            pipe = self.redis_client.pipeline()
            
            # Remove expired entries
            pipe.zremrangebyscore(key, 0, window_start)
            
            # Count current requests in window
            pipe.zcard(key)
            
            # Add current request
            pipe.zadd(key, {str(current_time): current_time})
            
            # Set expiry for cleanup
            pipe.expire(key, window + 1)
            
            # Execute pipeline
            results = pipe.execute()
            current_count = results[1] + 1  # +1 for the current request
            
            # Check burst limit first (if configured)
            if burst_limit and current_count > burst_limit:
                # Remove the request we just added since it's rejected
                self.redis_client.zrem(key, str(current_time))
                
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Burst limit exceeded. Max {burst_limit} requests.",
                    headers={"Retry-After": "10"}
                )
            
            # Check main rate limit
            if current_count > limit:
                # Remove the request we just added since it's rejected
                self.redis_client.zrem(key, str(current_time))
                
                retry_after = max(1, int(window - (current_time - window_start)))
                
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=f"Rate limit exceeded. Max {limit} requests per {window} seconds.",
                    headers={"Retry-After": str(retry_after)}
                )
            
            remaining = max(0, limit - current_count)
            
            return {
                "allowed": True,
                "limit": limit,
                "remaining": remaining,
                "window": window,
                "current_count": current_count
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Rate limiting error: {e}")
            # Allow request on error (fail open)
            return {"allowed": True, "remaining": limit}

# Global rate limiter instance
rate_limiter = RateLimiter()

# Rate limit configurations for different endpoints and user types
RATE_LIMITS = {
    # Authentication endpoints
    "auth_register": {"limit": 5, "window": 3600, "burst": 2},  # 5 per hour, max 2 burst
    "auth_login": {"limit": 10, "window": 900, "burst": 3},     # 10 per 15 min, max 3 burst
    "auth_refresh": {"limit": 50, "window": 3600, "burst": 10}, # 50 per hour
    
    # AI endpoints (authenticated users)
    "complete_user": {"limit": 100, "window": 3600, "burst": 20},   # 100 per hour
    "tts_user": {"limit": 50, "window": 3600, "burst": 10},         # 50 per hour
    "context_user": {"limit": 200, "window": 3600, "burst": 50},    # 200 per hour
    
    # AI endpoints (anonymous users)
    "complete_anon": {"limit": 10, "window": 3600, "burst": 3},     # 10 per hour
    "tts_anon": {"limit": 5, "window": 3600, "burst": 1},           # 5 per hour
    "context_anon": {"limit": 20, "window": 3600, "burst": 5},      # 20 per hour
    
    # File operations (admin only)
    "upload_admin": {"limit": 20, "window": 3600, "burst": 5},      # 20 per hour
    "delete_admin": {"limit": 10, "window": 3600, "burst": 2},      # 10 per hour
    
    # General API
    "api_general": {"limit": 1000, "window": 3600, "burst": 200},   # 1000 per hour
}

async def check_endpoint_rate_limit(
    request: Request,
    endpoint: str,
    user_id: Optional[str] = None,
    user_role: Optional[str] = None
) -> Dict[str, Any]:
    """
    Check rate limit for a specific endpoint
    
    Args:
        request: FastAPI Request object
        endpoint: Endpoint name (key in RATE_LIMITS)
        user_id: Optional user ID for authenticated requests
        user_role: Optional user role
        
    Returns:
        Rate limit check result
    """
    # Determine rate limit key and config
    if user_id:
        key = f"rate_limit:user:{user_id}:{endpoint}"
    else:
        # Use IP address for anonymous users
        client_ip = request.client.host if request.client else "unknown"
        key = f"rate_limit:ip:{client_ip}:{endpoint}"
    
    # Get rate limit config
    config = RATE_LIMITS.get(endpoint, RATE_LIMITS["api_general"])
    
    # Apply role-based modifiers
    if user_role == "admin":
        # Admins get 2x limits
        config = {
            "limit": config["limit"] * 2,
            "window": config["window"],
            "burst": config["burst"] * 2
        }
    
    # Check rate limit
    return await rate_limiter.check_rate_limit(
        key=key,
        limit=config["limit"],
        window=config["window"],
        burst_limit=config.get("burst")
    )

async def rate_limit_middleware(request: Request, call_next):
    """
    Middleware to apply rate limiting to all requests
    """
    # Skip rate limiting for health checks
    if request.url.path in ["/health", "/auth/health"]:
        response = await call_next(request)
        return response
    
    try:
        # Apply general API rate limit
        await check_endpoint_rate_limit(request, "api_general")
        
        # Continue with request
        response = await call_next(request)
        return response
        
    except HTTPException as e:
        # Rate limit exceeded
        logger.warning(f"Rate limit exceeded for {request.client.host if request.client else 'unknown'}: {request.url.path}")
        raise e

# Utility functions for manual rate limiting
async def check_user_rate_limit(user_id: str, endpoint: str, user_role: str = "user"):
    """Check rate limit for authenticated user"""
    key = f"rate_limit:user:{user_id}:{endpoint}"
    config = RATE_LIMITS.get(endpoint, RATE_LIMITS["api_general"])
    
    if user_role == "admin":
        config = {
            "limit": config["limit"] * 2,
            "window": config["window"],
            "burst": config["burst"] * 2
        }
    
    return await rate_limiter.check_rate_limit(
        key=key,
        limit=config["limit"],
        window=config["window"],
        burst_limit=config.get("burst")
    )

async def check_ip_rate_limit(ip_address: str, endpoint: str):
    """Check rate limit for IP address"""
    key = f"rate_limit:ip:{ip_address}:{endpoint}"
    config = RATE_LIMITS.get(endpoint, RATE_LIMITS["api_general"])
    
    return await rate_limiter.check_rate_limit(
        key=key,
        limit=config["limit"],
        window=config["window"],
        burst_limit=config.get("burst")
    )

def get_rate_limit_status() -> Dict[str, Any]:
    """Get rate limiter status for monitoring"""
    return {
        "available": rate_limiter.available,
        "redis_connected": rate_limiter.redis_client is not None,
        "configurations": list(RATE_LIMITS.keys())
    }