"""
Advanced Rate Limiting Middleware for EchoWright Platform

Provides tiered rate limiting based on user subscription levels and endpoint types.
Implements sliding window algorithm for smoother rate limiting and AI-specific
controls for expensive operations like LLM calls and TTS generation.

Features:
- Subscription-tiered limits (free/premium/educational/admin)
- AI operation-specific rate limiting (LLM, TTS, voice chat)
- Sliding window algorithm for accurate rate limiting
- Cost-based throttling for expensive operations
- Redis-backed storage with fallback
- Comprehensive metrics and monitoring
- Rate limit headers in responses
"""

import asyncio
import time
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Union, List, Callable
from enum import Enum
from dataclasses import dataclass, asdict
from functools import wraps

import redis
from fastapi import Request, Response, HTTPException, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

from core.auth.auth import User, UserRole
from core.infrastructure.metrics import Counter, Gauge, Histogram

logger = logging.getLogger(__name__)


class OperationType(Enum):
    """Types of operations with different rate limiting requirements."""
    API_GENERAL = "api_general"
    LLM_INTERACTION = "llm_interaction"
    TTS_GENERATION = "tts_generation"
    VOICE_CHAT = "voice_chat"
    BOOK_UPLOAD = "book_upload"
    ANALYTICS_QUERY = "analytics_query"
    PERSONA_CREATE = "persona_create"
    TRANSCRIPTION = "transcription"


class SubscriptionTier(Enum):
    """User subscription tiers with different limits."""
    FREE = "free"
    PREMIUM = "premium"
    EDUCATIONAL = "educational"
    ADMIN = "admin"
    GUEST = "guest"


@dataclass
class RateLimitRule:
    """Configuration for a specific rate limiting rule."""
    requests: int
    window_seconds: int
    cost_multiplier: float = 1.0  # For cost-based throttling
    burst_allowance: int = 0  # Extra requests allowed in short bursts


@dataclass
class RateLimitResult:
    """Result of rate limit check."""
    allowed: bool
    remaining: int
    reset_time: int
    retry_after: Optional[int] = None
    limit: int = 0
    window_seconds: int = 60


# Default rate limiting configuration
DEFAULT_RATE_LIMITS = {
    # General API access
    OperationType.API_GENERAL: {
        SubscriptionTier.GUEST: RateLimitRule(100, 3600),  # 100/hour
        SubscriptionTier.FREE: RateLimitRule(1000, 3600),  # 1000/hour
        SubscriptionTier.PREMIUM: RateLimitRule(10000, 3600),  # 10k/hour
        SubscriptionTier.EDUCATIONAL: RateLimitRule(5000, 3600),  # 5k/hour
        SubscriptionTier.ADMIN: RateLimitRule(50000, 3600),  # 50k/hour
    },
    
    # AI-powered interactions
    OperationType.LLM_INTERACTION: {
        SubscriptionTier.GUEST: RateLimitRule(5, 3600),  # 5/hour
        SubscriptionTier.FREE: RateLimitRule(20, 3600),  # 20/hour
        SubscriptionTier.PREMIUM: RateLimitRule(200, 3600),  # 200/hour
        SubscriptionTier.EDUCATIONAL: RateLimitRule(500, 3600),  # 500/hour
        SubscriptionTier.ADMIN: RateLimitRule(2000, 3600, cost_multiplier=0.5),
    },
    
    # Text-to-speech generation
    OperationType.TTS_GENERATION: {
        SubscriptionTier.GUEST: RateLimitRule(3, 3600),  # 3/hour
        SubscriptionTier.FREE: RateLimitRule(10, 3600),  # 10/hour
        SubscriptionTier.PREMIUM: RateLimitRule(100, 3600),  # 100/hour
        SubscriptionTier.EDUCATIONAL: RateLimitRule(200, 3600),  # 200/hour
        SubscriptionTier.ADMIN: RateLimitRule(1000, 3600, cost_multiplier=0.3),
    },
    
    # Voice chat interactions (most expensive)
    OperationType.VOICE_CHAT: {
        SubscriptionTier.GUEST: RateLimitRule(2, 3600),  # 2/hour
        SubscriptionTier.FREE: RateLimitRule(5, 3600),  # 5/hour
        SubscriptionTier.PREMIUM: RateLimitRule(50, 3600),  # 50/hour
        SubscriptionTier.EDUCATIONAL: RateLimitRule(100, 3600),  # 100/hour
        SubscriptionTier.ADMIN: RateLimitRule(500, 3600, cost_multiplier=0.2),
    },
    
    # Administrative operations
    OperationType.BOOK_UPLOAD: {
        SubscriptionTier.ADMIN: RateLimitRule(100, 86400),  # 100/day
        SubscriptionTier.EDUCATIONAL: RateLimitRule(20, 86400),  # 20/day
    },
    
    # Analytics and reporting
    OperationType.ANALYTICS_QUERY: {
        SubscriptionTier.FREE: RateLimitRule(10, 3600),  # 10/hour
        SubscriptionTier.PREMIUM: RateLimitRule(100, 3600),  # 100/hour
        SubscriptionTier.EDUCATIONAL: RateLimitRule(200, 3600),  # 200/hour
        SubscriptionTier.ADMIN: RateLimitRule(1000, 3600),  # 1000/hour
    },
    
    # Persona creation/modification
    OperationType.PERSONA_CREATE: {
        SubscriptionTier.FREE: RateLimitRule(3, 86400),  # 3/day
        SubscriptionTier.PREMIUM: RateLimitRule(20, 86400),  # 20/day
        SubscriptionTier.EDUCATIONAL: RateLimitRule(50, 86400),  # 50/day
        SubscriptionTier.ADMIN: RateLimitRule(200, 86400),  # 200/day
    },
    
    # Audio transcription
    OperationType.TRANSCRIPTION: {
        SubscriptionTier.GUEST: RateLimitRule(5, 3600),  # 5/hour
        SubscriptionTier.FREE: RateLimitRule(20, 3600),  # 20/hour
        SubscriptionTier.PREMIUM: RateLimitRule(200, 3600),  # 200/hour
        SubscriptionTier.EDUCATIONAL: RateLimitRule(500, 3600),  # 500/hour
        SubscriptionTier.ADMIN: RateLimitRule(2000, 3600),  # 2000/hour
    },
}

# Endpoint to operation type mapping
ENDPOINT_OPERATION_MAP = {
    "/complete": OperationType.LLM_INTERACTION,
    "/tts": OperationType.TTS_GENERATION,
    "/voice": OperationType.VOICE_CHAT,
    "/books/upload": OperationType.BOOK_UPLOAD,
    "/analytics": OperationType.ANALYTICS_QUERY,
    "/personas": OperationType.PERSONA_CREATE,
    "/transcription": OperationType.TRANSCRIPTION,
}


class RateLimiter:
    """
    Advanced rate limiter using sliding window algorithm with Redis backend.
    
    Implements cost-based throttling and subscription-tiered limits for
    the EchoWright AI-powered audiobook platform.
    """
    
    def __init__(
        self,
        redis_client: redis.Redis,
        rate_limits: Optional[Dict] = None,
        default_operation: OperationType = OperationType.API_GENERAL,
        enable_burst: bool = True
    ):
        """
        Initialize rate limiter.
        
        Args:
            redis_client: Configured Redis client
            rate_limits: Custom rate limiting configuration
            default_operation: Default operation type for unmatched endpoints
            enable_burst: Enable burst allowance for short-term spikes
        """
        self.redis = redis_client
        self.rate_limits = rate_limits or DEFAULT_RATE_LIMITS
        self.default_operation = default_operation
        self.enable_burst = enable_burst
        
        # Metrics for monitoring
        self.rate_limit_exceeded = Counter(
            'rate_limit_exceeded_total',
            'Total rate limit violations',
            ['operation_type', 'subscription_tier', 'user_type']
        )
        
        self.rate_limit_remaining = Gauge(
            'rate_limit_remaining',
            'Remaining requests for rate limit window',
            ['operation_type', 'subscription_tier']
        )
        
        self.rate_limit_check_duration = Histogram(
            'rate_limit_check_duration_seconds',
            'Time spent checking rate limits',
            buckets=(0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5)
        )
        
        logger.info("Rate limiter initialized", 
                   redis_available=self._test_redis_connection())
    
    def _test_redis_connection(self) -> bool:
        """Test Redis connection availability."""
        try:
            self.redis.ping()
            return True
        except Exception as e:
            logger.warning(f"Redis connection failed: {e}")
            return False
    
    def _get_user_tier(self, user: Optional[User]) -> SubscriptionTier:
        """Determine user's subscription tier."""
        if not user:
            return SubscriptionTier.GUEST
        
        # Map UserRole to SubscriptionTier
        role_to_tier = {
            UserRole.ADMIN: SubscriptionTier.ADMIN,
            UserRole.USER: SubscriptionTier.FREE,  # Default for regular users
            UserRole.GUEST: SubscriptionTier.GUEST,
        }
        
        base_tier = role_to_tier.get(user.role, SubscriptionTier.FREE)
        
        # TODO: Check user's actual subscription status from database
        # For now, we'll use the role-based mapping
        # In the future, this should query the user's subscription from the database
        
        return base_tier
    
    def _get_operation_type(self, request: Request) -> OperationType:
        """Determine operation type from request path."""
        path = request.url.path
        
        # Check for exact matches first
        for endpoint, operation in ENDPOINT_OPERATION_MAP.items():
            if path.startswith(endpoint):
                return operation
        
        # Check for pattern matches
        if "/books/" in path and request.method in ["POST", "PUT"]:
            return OperationType.BOOK_UPLOAD
        elif "/analytics/" in path or "/stats" in path:
            return OperationType.ANALYTICS_QUERY
        elif "/personas/" in path and request.method in ["POST", "PUT"]:
            return OperationType.PERSONA_CREATE
        
        return self.default_operation
    
    def _get_cache_key(self, user_id: str, operation: OperationType) -> str:
        """Generate Redis cache key for rate limiting."""
        return f"rate_limit:{operation.value}:{user_id}"
    
    def _calculate_cost(self, rule: RateLimitRule, request: Request) -> float:
        """Calculate cost multiplier for the request."""
        base_cost = 1.0
        
        # Apply rule-based cost multiplier
        cost = base_cost * rule.cost_multiplier
        
        # Additional cost factors based on request characteristics
        if hasattr(request.state, 'cost_factors'):
            cost *= request.state.cost_factors
        
        return max(0.1, cost)  # Minimum cost to prevent abuse
    
    async def check_rate_limit(
        self,
        request: Request,
        user: Optional[User] = None,
        operation: Optional[OperationType] = None
    ) -> RateLimitResult:
        """
        Check if request is within rate limits using sliding window.
        
        Args:
            request: FastAPI request object
            user: Authenticated user (if any)
            operation: Override operation type detection
            
        Returns:
            RateLimitResult with allow/deny decision and metadata
        """
        start_time = time.time()
        
        try:
            # Determine operation type and user tier
            op_type = operation or self._get_operation_type(request)
            user_tier = self._get_user_tier(user)
            user_id = user.id if user else f"guest:{request.client.host}"
            
            # Get rate limit rule for this combination
            rule = self._get_rate_limit_rule(op_type, user_tier)
            if not rule:
                # No rule defined, allow request
                return RateLimitResult(
                    allowed=True,
                    remaining=float('inf'),
                    reset_time=int(time.time() + 3600),
                    limit=0
                )
            
            # Calculate request cost
            cost = self._calculate_cost(rule, request)
            
            # Check rate limit using sliding window
            result = await self._sliding_window_check(
                user_id, op_type, rule, cost
            )
            
            # Update metrics
            if not result.allowed:
                self.rate_limit_exceeded.labels(
                    operation_type=op_type.value,
                    subscription_tier=user_tier.value,
                    user_type="authenticated" if user else "guest"
                ).inc()
            else:
                self.rate_limit_remaining.labels(
                    operation_type=op_type.value,
                    subscription_tier=user_tier.value
                ).set(result.remaining)
            
            return result
            
        except Exception as e:
            logger.error(f"Rate limit check failed: {e}")
            # Fail open - allow request if rate limiting fails
            return RateLimitResult(
                allowed=True,
                remaining=0,
                reset_time=int(time.time() + 3600)
            )
        finally:
            duration = time.time() - start_time
            self.rate_limit_check_duration.observe(duration)
    
    def _get_rate_limit_rule(
        self, 
        operation: OperationType, 
        tier: SubscriptionTier
    ) -> Optional[RateLimitRule]:
        """Get rate limit rule for operation and tier combination."""
        op_limits = self.rate_limits.get(operation, {})
        return op_limits.get(tier)
    
    async def _sliding_window_check(
        self,
        user_id: str,
        operation: OperationType,
        rule: RateLimitRule,
        cost: float = 1.0
    ) -> RateLimitResult:
        """
        Implement sliding window rate limiting algorithm.
        
        Uses Redis sorted sets to maintain a sliding window of timestamps
        for accurate rate limiting across distributed systems.
        """
        if not self._test_redis_connection():
            # Fallback: allow request if Redis is unavailable
            logger.warning("Redis unavailable, allowing request")
            return RateLimitResult(
                allowed=True,
                remaining=rule.requests,
                reset_time=int(time.time() + rule.window_seconds),
                limit=rule.requests,
                window_seconds=rule.window_seconds
            )
        
        cache_key = self._get_cache_key(user_id, operation)
        current_time = time.time()
        window_start = current_time - rule.window_seconds
        
        try:
            # Remove expired entries from sliding window
            self.redis.zremrangebyscore(cache_key, 0, window_start)
            
            # Count current requests in window
            current_requests = self.redis.zcard(cache_key)
            
            # Calculate effective limit (considering cost and burst)
            effective_limit = rule.requests
            if self.enable_burst and rule.burst_allowance > 0:
                # Allow burst if recent usage is low
                recent_window = current_time - (rule.window_seconds / 4)  # Last 25%
                recent_requests = self.redis.zcount(cache_key, recent_window, current_time)
                if recent_requests < (rule.requests * 0.5):  # Less than 50% of limit used
                    effective_limit += rule.burst_allowance
            
            # Check if adding this request (with cost) would exceed limit
            cost_adjusted_requests = current_requests + cost
            
            if cost_adjusted_requests > effective_limit:
                # Rate limit exceeded
                oldest_request = self.redis.zrange(cache_key, 0, 0, withscores=True)
                if oldest_request:
                    reset_time = int(oldest_request[0][1] + rule.window_seconds)
                else:
                    reset_time = int(current_time + rule.window_seconds)
                
                retry_after = max(1, reset_time - int(current_time))
                
                return RateLimitResult(
                    allowed=False,
                    remaining=max(0, int(effective_limit - current_requests)),
                    reset_time=reset_time,
                    retry_after=retry_after,
                    limit=rule.requests,
                    window_seconds=rule.window_seconds
                )
            
            # Add current request to sliding window
            self.redis.zadd(cache_key, {f"{current_time}:{cost}": current_time})
            
            # Set expiration for cleanup
            self.redis.expire(cache_key, rule.window_seconds + 60)
            
            remaining = max(0, int(effective_limit - cost_adjusted_requests))
            reset_time = int(current_time + rule.window_seconds)
            
            return RateLimitResult(
                allowed=True,
                remaining=remaining,
                reset_time=reset_time,
                limit=rule.requests,
                window_seconds=rule.window_seconds
            )
            
        except Exception as e:
            logger.error(f"Sliding window check failed: {e}")
            # Fail open
            return RateLimitResult(
                allowed=True,
                remaining=rule.requests,
                reset_time=int(time.time() + rule.window_seconds),
                limit=rule.requests,
                window_seconds=rule.window_seconds
            )


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    FastAPI middleware for automatic rate limiting based on user tiers and endpoints.
    
    Integrates with EchoWright's authentication system and provides
    automatic rate limiting for all API endpoints.
    """
    
    def __init__(
        self,
        app: ASGIApp,
        rate_limiter: RateLimiter,
        skip_paths: Optional[List[str]] = None,
        skip_auth_paths: bool = True
    ):
        """
        Initialize rate limiting middleware.
        
        Args:
            app: ASGI application
            rate_limiter: Configured RateLimiter instance
            skip_paths: Paths to skip rate limiting (e.g., health checks)
            skip_auth_paths: Skip rate limiting for auth endpoints
        """
        super().__init__(app)
        self.rate_limiter = rate_limiter
        self.skip_paths = skip_paths or ["/health", "/metrics", "/docs", "/openapi.json"]
        
        if skip_auth_paths:
            self.skip_paths.extend(["/auth/", "/login", "/register"])
        
        logger.info("Rate limiting middleware initialized")
    
    def _should_skip_path(self, path: str) -> bool:
        """Check if path should skip rate limiting."""
        return any(skip in path for skip in self.skip_paths)
    
    def _extract_user_from_request(self, request: Request) -> Optional[User]:
        """Extract user from request state if available."""
        # The auth middleware should have set this
        return getattr(request.state, 'user', None)
    
    def _add_rate_limit_headers(self, response: Response, result: RateLimitResult) -> None:
        """Add rate limiting headers to response."""
        if hasattr(response, 'headers'):
            response.headers["X-RateLimit-Limit"] = str(result.limit)
            response.headers["X-RateLimit-Remaining"] = str(result.remaining)
            response.headers["X-RateLimit-Reset"] = str(result.reset_time)
            response.headers["X-RateLimit-Window"] = str(result.window_seconds)
            
            if result.retry_after:
                response.headers["Retry-After"] = str(result.retry_after)
    
    async def dispatch(self, request: Request, call_next) -> Response:
        """Process request with rate limiting."""
        # Skip rate limiting for certain paths
        if self._should_skip_path(request.url.path):
            return await call_next(request)
        
        # Extract user from request (set by auth middleware)
        user = self._extract_user_from_request(request)
        
        # Check rate limit
        result = await self.rate_limiter.check_rate_limit(request, user)
        
        if not result.allowed:
            # Rate limit exceeded - return 429 response
            error_response = {
                "error": "RATE_LIMIT_EXCEEDED",
                "message": "Rate limit exceeded. Please try again later.",
                "details": {
                    "limit": result.limit,
                    "window_seconds": result.window_seconds,
                    "retry_after": result.retry_after
                }
            }
            
            response = JSONResponse(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                content=error_response
            )
            
            self._add_rate_limit_headers(response, result)
            return response
        
        # Process request normally
        response = await call_next(request)
        
        # Add rate limit headers to successful responses
        self._add_rate_limit_headers(response, result)
        
        return response


def rate_limit_decorator(
    operation: OperationType,
    rate_limiter: RateLimiter
):
    """
    Decorator for applying rate limiting to specific functions.
    
    Args:
        operation: Operation type for rate limiting rules
        rate_limiter: Configured RateLimiter instance
        
    Example:
        @rate_limit_decorator(OperationType.LLM_INTERACTION, rate_limiter)
        async def generate_response(prompt: str, user: User):
            # Function implementation
            pass
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            # Extract request and user from arguments
            request = None
            user = None
            
            for arg in args:
                if isinstance(arg, Request):
                    request = arg
                elif isinstance(arg, User):
                    user = arg
            
            # Check kwargs for request/user
            request = request or kwargs.get('request')
            user = user or kwargs.get('user') or kwargs.get('current_user')
            
            if request:
                result = await rate_limiter.check_rate_limit(
                    request, user, operation
                )
                
                if not result.allowed:
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail={
                            "error": "RATE_LIMIT_EXCEEDED",
                            "message": "Rate limit exceeded for this operation",
                            "retry_after": result.retry_after
                        },
                        headers={"Retry-After": str(result.retry_after)} if result.retry_after else {}
                    )
            
            return await func(*args, **kwargs)
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            # For sync functions, we can't easily check rate limits
            # This is mainly for backward compatibility
            return func(*args, **kwargs)
        
        # Return appropriate wrapper based on function type
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator


# Factory functions for easy setup

def create_rate_limiter(
    redis_client: redis.Redis,
    custom_limits: Optional[Dict] = None
) -> RateLimiter:
    """
    Create a rate limiter instance with EchoWright defaults.
    
    Args:
        redis_client: Configured Redis client
        custom_limits: Custom rate limiting rules to override defaults
        
    Returns:
        Configured RateLimiter instance
    """
    if custom_limits:
        # Merge custom limits with defaults
        merged_limits = DEFAULT_RATE_LIMITS.copy()
        for op_type, tier_limits in custom_limits.items():
            if op_type in merged_limits:
                merged_limits[op_type].update(tier_limits)
            else:
                merged_limits[op_type] = tier_limits
        return RateLimiter(redis_client, merged_limits)
    
    return RateLimiter(redis_client)


def setup_rate_limiting(
    app,
    redis_client: redis.Redis,
    custom_limits: Optional[Dict] = None,
    skip_paths: Optional[List[str]] = None
) -> RateLimiter:
    """
    Set up rate limiting for a FastAPI application.
    
    Args:
        app: FastAPI application instance
        redis_client: Configured Redis client
        custom_limits: Custom rate limiting configuration
        skip_paths: Additional paths to skip rate limiting
        
    Returns:
        Configured RateLimiter instance for manual use
    """
    # Create rate limiter
    rate_limiter = create_rate_limiter(redis_client, custom_limits)
    
    # Add middleware
    app.add_middleware(RateLimitMiddleware, rate_limiter=rate_limiter, skip_paths=skip_paths)
    
    # Add rate limiting status endpoint
    @app.get("/rate-limit/status")
    async def get_rate_limit_status():
        """Get rate limiting configuration and status."""
        return {
            "enabled": True,
            "operations": [op.value for op in OperationType],
            "tiers": [tier.value for tier in SubscriptionTier],
            "redis_available": rate_limiter._test_redis_connection()
        }
    
    logger.info("Rate limiting setup complete")
    return rate_limiter