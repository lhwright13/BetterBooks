#!/usr/bin/env python3
"""
GraphQL Security Middleware for EchoWright Platform
Implements query complexity analysis, authentication, and rate limiting
"""

import strawberry
from strawberry.extensions import Extension
from strawberry.types import Info
from typing import Dict, Any, Optional
import jwt
import time
import hashlib
from functools import wraps
from fastapi import HTTPException, status
import redis
import logging

from core.auth.jwt_middleware import verify_token
from core.shared.utils.config_manager import get_config

logger = logging.getLogger(__name__)
config = get_config()

# Redis client for rate limiting
redis_client = redis.Redis(
    host=config.redis_host,
    port=config.redis_port,
    db=0,
    decode_responses=True
)

class QueryComplexityAnalyzer(Extension):
    """
    Analyzes and limits GraphQL query complexity to prevent DoS attacks.
    """
    
    def __init__(self, max_complexity: int = 1000):
        self.max_complexity = max_complexity
    
    def on_validate(self):
        """Validate query complexity before execution."""
        def complexity_validator(context, document, *args):
            complexity = self._calculate_complexity(document)
            
            if complexity > self.max_complexity:
                logger.warning(f"Query complexity {complexity} exceeds limit {self.max_complexity}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Query too complex. Complexity: {complexity}, Max: {self.max_complexity}"
                )
            
            logger.debug(f"Query complexity: {complexity}")
            return complexity
        
        return complexity_validator
    
    def _calculate_complexity(self, document) -> int:
        """Calculate complexity score based on query structure."""
        complexity = 0
        
        def visit_field(field, multiplier=1):
            nonlocal complexity
            complexity += multiplier
            
            # Penalty for nested fields
            if hasattr(field, 'selection_set') and field.selection_set:
                for selection in field.selection_set.selections:
                    visit_field(selection, multiplier * 2)
        
        for definition in document.definitions:
            if hasattr(definition, 'selection_set'):
                for selection in definition.selection_set.selections:
                    visit_field(selection)
        
        return complexity

class QueryDepthLimiter(Extension):
    """
    Limits query depth to prevent deeply nested attacks.
    """
    
    def __init__(self, max_depth: int = 10):
        self.max_depth = max_depth
    
    def on_validate(self):
        def depth_validator(context, document, *args):
            depth = self._calculate_depth(document)
            
            if depth > self.max_depth:
                logger.warning(f"Query depth {depth} exceeds limit {self.max_depth}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Query too deep. Depth: {depth}, Max: {self.max_depth}"
                )
            
            return depth
        
        return depth_validator
    
    def _calculate_depth(self, document) -> int:
        """Calculate maximum query depth."""
        def get_field_depth(field, current_depth=1):
            if not hasattr(field, 'selection_set') or not field.selection_set:
                return current_depth
            
            max_child_depth = current_depth
            for selection in field.selection_set.selections:
                child_depth = get_field_depth(selection, current_depth + 1)
                max_child_depth = max(max_child_depth, child_depth)
            
            return max_child_depth
        
        max_depth = 0
        for definition in document.definitions:
            if hasattr(definition, 'selection_set'):
                for selection in definition.selection_set.selections:
                    depth = get_field_depth(selection)
                    max_depth = max(max_depth, depth)
        
        return max_depth

class GraphQLRateLimiter:
    """
    Rate limiting for GraphQL queries based on user and query complexity.
    """
    
    def __init__(self, 
                 requests_per_minute: int = 60,
                 complexity_per_minute: int = 10000):
        self.requests_per_minute = requests_per_minute
        self.complexity_per_minute = complexity_per_minute
    
    def check_rate_limit(self, user_id: str, complexity: int = 1):
        """Check if request exceeds rate limits."""
        now = int(time.time())
        minute = now // 60
        
        # Keys for tracking
        request_key = f"graphql_requests:{user_id}:{minute}"
        complexity_key = f"graphql_complexity:{user_id}:{minute}"
        
        try:
            # Check request count
            current_requests = redis_client.get(request_key) or 0
            current_requests = int(current_requests)
            
            if current_requests >= self.requests_per_minute:
                logger.warning(f"Rate limit exceeded for user {user_id}: {current_requests} requests")
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many requests. Please try again later."
                )
            
            # Check complexity limit
            current_complexity = redis_client.get(complexity_key) or 0
            current_complexity = int(current_complexity)
            
            if current_complexity + complexity > self.complexity_per_minute:
                logger.warning(f"Complexity limit exceeded for user {user_id}: {current_complexity + complexity}")
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Query complexity limit exceeded. Please try simpler queries."
                )
            
            # Update counters
            pipe = redis_client.pipeline()
            pipe.incr(request_key)
            pipe.expire(request_key, 120)  # 2 minutes TTL
            pipe.incr(complexity_key, complexity)
            pipe.expire(complexity_key, 120)
            pipe.execute()
            
        except redis.RedisError as e:
            logger.error(f"Redis error in rate limiting: {e}")
            # Don't block requests if Redis is down
            pass

# Rate limiter instance
rate_limiter = GraphQLRateLimiter()

def require_auth(f):
    """Decorator to require authentication for GraphQL fields."""
    @wraps(f)
    async def wrapper(self, info: Info, *args, **kwargs):
        # Extract token from context
        request = info.context.get("request")
        if not request:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication required"
            )
        
        auth_header = request.headers.get("authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Bearer token required"
            )
        
        token = auth_header.split(" ")[1]
        
        try:
            # Verify JWT token
            payload = verify_token(token)
            user_id = payload.get("user_id")
            
            if not user_id:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token"
                )
            
            # Add user to context
            info.context["user_id"] = user_id
            info.context["user"] = payload
            
            # Check rate limits
            rate_limiter.check_rate_limit(user_id)
            
        except jwt.InvalidTokenError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token"
            )
        
        return await f(self, info, *args, **kwargs)
    
    return wrapper

def require_subscription(subscription_level: str):
    """Decorator to require specific subscription level."""
    def decorator(f):
        @wraps(f)
        async def wrapper(self, info: Info, *args, **kwargs):
            user = info.context.get("user", {})
            user_subscription = user.get("subscription_tier", "free")
            
            # Define subscription hierarchy
            levels = {"free": 0, "premium": 1, "enterprise": 2}
            
            required_level = levels.get(subscription_level, 0)
            user_level = levels.get(user_subscription, 0)
            
            if user_level < required_level:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Subscription level '{subscription_level}' required"
                )
            
            return await f(self, info, *args, **kwargs)
        
        return wrapper
    return decorator

class SecurityExtension(Extension):
    """
    Main security extension that coordinates all security measures.
    """
    
    def on_request_start(self):
        """Initialize security checks."""
        def security_handler(context):
            # Add basic security headers
            context["security_headers"] = {
                "X-Content-Type-Options": "nosniff",
                "X-Frame-Options": "DENY",
                "X-XSS-Protection": "1; mode=block"
            }
            
            # Log request for monitoring
            request = context.get("request")
            if request:
                client_ip = request.client.host
                user_agent = request.headers.get("user-agent", "unknown")
                logger.info(f"GraphQL request from {client_ip} - {user_agent}")
        
        return security_handler

# Security extensions list
security_extensions = [
    QueryComplexityAnalyzer(max_complexity=1000),
    QueryDepthLimiter(max_depth=10),
    SecurityExtension()
]