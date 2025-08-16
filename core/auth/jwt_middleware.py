"""
JWT Verification Middleware

SECURITY CRITICAL: This middleware implements proper JWT verification
for all authenticated API endpoints. Addresses the critical security
vulnerability of using anon keys for server operations.

Key Security Features:
- Verifies Supabase JWTs using JWKS public key cryptography
- Maps Supabase sub to our internal user_id 
- Rejects expired, tampered, or invalid tokens
- Uses service role key for database operations
- Implements proper issuer/audience validation
"""

import logging
from typing import Optional, Dict, Any
from fastapi import Request, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .supabase_provider import get_auth_provider, SupabaseAuthError
from ..database.models.user import User

logger = logging.getLogger(__name__)

# Security bearer for extracting tokens
security = HTTPBearer()


class JWTMiddleware:
    """
    JWT verification middleware for FastAPI
    
    SECURITY: This ensures every authenticated request has a valid,
    cryptographically verified JWT from Supabase. No more trusting
    client-provided tokens without verification.
    """
    
    def __init__(self):
        self.auth_provider = get_auth_provider()
        logger.info("JWT middleware initialized with proper verification")
    
    async def verify_request_token(self, request: Request) -> Optional[Dict[str, Any]]:
        """
        Verify JWT token from request headers
        
        Args:
            request: FastAPI request object
            
        Returns:
            Dict with verified user info or None if no token
            
        Raises:
            HTTPException: If token is invalid
        """
        try:
            # Extract Authorization header
            auth_header = request.headers.get('Authorization')
            if not auth_header:
                return None
            
            if not auth_header.startswith('Bearer '):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid authorization header format",
                    headers={"WWW-Authenticate": "Bearer"}
                )
            
            token = auth_header[7:]  # Remove "Bearer " prefix
            
            # Verify token with proper cryptographic validation
            verified_data = await self.auth_provider.verify_token(token)
            
            return verified_data
            
        except SupabaseAuthError as e:
            logger.warning(f"JWT verification failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired token",
                headers={"WWW-Authenticate": "Bearer"}
            )
        except Exception as e:
            logger.error(f"Token verification error: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Authentication service error"
            )


# Global middleware instance
_middleware = None

def get_jwt_middleware() -> JWTMiddleware:
    """Get global JWT middleware instance"""
    global _middleware
    if _middleware is None:
        _middleware = JWTMiddleware()
    return _middleware


# =====================================================
# FASTAPI DEPENDENCY FUNCTIONS
# =====================================================

async def get_current_user_verified(
    credentials: HTTPAuthorizationCredentials = security
) -> User:
    """
    FastAPI dependency for getting current authenticated user
    
    SECURITY CRITICAL: This replaces the old dependency that used
    anon keys. Now uses proper JWT verification with service role key.
    
    Args:
        credentials: Bearer token credentials
        
    Returns:
        Verified User object
        
    Raises:
        HTTPException: If authentication fails
    """
    try:
        # Use service role key for verification (not anon key)
        auth_provider = get_auth_provider()
        result = await auth_provider.verify_token(credentials.credentials)
        
        # Return the verified user
        user_data = result['user']
        return User(
            id=user_data['id'],
            email=user_data.get('email'),
            display_name=user_data.get('display_name'),
            avatar_url=user_data.get('avatar_url'),
            created_at=user_data['created_at'],
            updated_at=user_data['updated_at']
        )
        
    except SupabaseAuthError as e:
        logger.warning(f"Authentication failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
            headers={"WWW-Authenticate": "Bearer"}
        )
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication service error"
        )


async def get_optional_user_verified(
    credentials: Optional[HTTPAuthorizationCredentials] = security
) -> Optional[User]:
    """
    FastAPI dependency for optionally getting current user
    
    Returns None if no token provided, otherwise verifies token.
    
    Args:
        credentials: Optional bearer token credentials
        
    Returns:
        Verified User object or None
    """
    if not credentials:
        return None
    
    try:
        return await get_current_user_verified(credentials)
    except HTTPException:
        # Don't raise exception for optional auth
        return None


# =====================================================
# REQUEST CONTEXT UTILITIES
# =====================================================

def extract_user_id_from_token(token: str) -> Optional[str]:
    """
    Extract user ID from JWT without full verification
    
    CAUTION: Only use for logging/metrics. Always use full verification
    for authorization decisions.
    
    Args:
        token: JWT token string
        
    Returns:
        User ID string or None
    """
    try:
        import jwt
        # Decode without verification (for logging only)
        payload = jwt.decode(token, options={"verify_signature": False})
        return payload.get('sub')
    except Exception:
        return None


def is_token_expired(token: str) -> bool:
    """
    Check if JWT token is expired without full verification
    
    CAUTION: Only use for client-side optimization. Server must
    always do full verification.
    
    Args:
        token: JWT token string
        
    Returns:
        True if expired
    """
    try:
        import jwt
        import time
        
        payload = jwt.decode(token, options={"verify_signature": False})
        exp = payload.get('exp')
        
        if not exp:
            return True
        
        return time.time() > exp
        
    except Exception:
        return True


# =====================================================
# MIDDLEWARE INTEGRATION HELPERS
# =====================================================

def create_auth_middleware():
    """
    Create FastAPI middleware for request-level JWT verification
    
    This can be added to FastAPI app to verify all requests globally.
    """
    from fastapi import FastAPI
    from starlette.middleware.base import BaseHTTPMiddleware
    from starlette.requests import Request
    from starlette.responses import Response
    
    class AuthMiddleware(BaseHTTPMiddleware):
        def __init__(self, app, exclude_paths: list = None):
            super().__init__(app)
            self.exclude_paths = exclude_paths or [
                "/health",
                "/docs",
                "/openapi.json",
                "/auth/",  # Auth endpoints don't need verification
                "/webhooks/"  # Webhooks have their own verification
            ]
            self.jwt_middleware = get_jwt_middleware()
        
        async def dispatch(self, request: Request, call_next):
            # Skip verification for excluded paths
            if any(request.url.path.startswith(path) for path in self.exclude_paths):
                return await call_next(request)
            
            # Verify token if present
            try:
                verified_data = await self.jwt_middleware.verify_request_token(request)
                if verified_data:
                    # Add verified user data to request state
                    request.state.user = verified_data['user']
                    request.state.supabase_user_id = verified_data['supabase_user_id']
            except HTTPException:
                # Let endpoint handle auth requirements
                pass
            
            response = await call_next(request)
            return response
    
    return AuthMiddleware


# =====================================================
# SECURITY VALIDATION UTILITIES
# =====================================================

def validate_bearer_token_format(auth_header: str) -> str:
    """
    Validate and extract token from Authorization header
    
    Args:
        auth_header: Raw Authorization header value
        
    Returns:
        Extracted JWT token
        
    Raises:
        ValueError: If format is invalid
    """
    if not auth_header:
        raise ValueError("Missing Authorization header")
    
    if not auth_header.startswith('Bearer '):
        raise ValueError("Invalid Authorization header format")
    
    token = auth_header[7:]  # Remove "Bearer " prefix
    
    if not token:
        raise ValueError("Empty token")
    
    return token


def get_token_claims_safely(token: str) -> Dict[str, Any]:
    """
    Get JWT claims without verification (for debugging only)
    
    SECURITY WARNING: Never use for authorization decisions!
    Only for logging, debugging, or client-side optimizations.
    
    Args:
        token: JWT token string
        
    Returns:
        Token claims dict
    """
    try:
        import jwt
        return jwt.decode(token, options={"verify_signature": False})
    except Exception:
        return {}