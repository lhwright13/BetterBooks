"""
User Context Helper for API Gateway
Handles extracting user information from JWT tokens and authentication context
"""

import logging
from typing import Optional
from fastapi import HTTPException, Depends, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

logger = logging.getLogger(__name__)

# Security scheme
security = HTTPBearer(auto_error=False)

# Demo/fallback user ID for development
DEMO_USER_ID = "550e8400-e29b-41d4-a716-446655440000"

def get_current_user_id(
    authorization: HTTPAuthorizationCredentials = Depends(security),
    x_user_id: Optional[str] = Header(None)  # Mobile app can send user ID in header
) -> str:
    """
    Extract user ID from JWT token or fallback to demo user for development
    
    Args:
        authorization: JWT bearer token
        x_user_id: Optional user ID header from mobile app
    
    Returns:
        str: User ID
        
    Raises:
        HTTPException: If authentication is required but token is invalid
    """
    
    # If we have an authorization header, try to extract user ID from JWT
    if authorization:
        try:
            from core.auth.auth import verify_token
            
            # Verify and decode the JWT token
            payload = verify_token(authorization.credentials)
            
            # Try user_id first (new format), then fall back to sub (old format)
            if payload and 'user_id' in payload:
                user_id = payload['user_id']
                logger.info(f"User authenticated via JWT user_id: {user_id}")
                return user_id
            elif payload and 'sub' in payload:
                user_id = payload['sub']
                logger.info(f"User authenticated via JWT sub (legacy): {user_id}")
                return user_id
            else:
                logger.warning("JWT token valid but no user_id or sub in payload")
                
        except Exception as e:
            logger.warning(f"JWT token validation failed: {e}")
    
    # Fallback: Check for user ID in header (for mobile app compatibility)
    if x_user_id:
        logger.info(f"User ID from header: {x_user_id}")
        return x_user_id
    
    # No authentication present - require proper authentication
    logger.warning("No authentication present - rejecting request")
    raise HTTPException(
        status_code=401,
        detail="Authentication required - no demo accounts allowed"
    )

def get_current_user_id_optional(
    authorization: HTTPAuthorizationCredentials = Depends(security),
    x_user_id: Optional[str] = Header(None)
) -> Optional[str]:
    """
    Same as get_current_user_id but returns None instead of demo user for optional auth
    """
    try:
        user_id = get_current_user_id(authorization, x_user_id)
        return user_id
    except HTTPException:
        return None

def require_authenticated_user(
    authorization: HTTPAuthorizationCredentials = Depends(security),
    x_user_id: Optional[str] = Header(None)
) -> str:
    """
    Require that the user is authenticated (not using demo/fallback)
    
    Raises:
        HTTPException: If no valid authentication is present
    """
    if not authorization and not x_user_id:
        raise HTTPException(
            status_code=401,
            detail="Authentication required"
        )
    
    user_id = get_current_user_id(authorization, x_user_id)
    
    # In production, we might want to reject demo user ID
    # For now, allow it for development
    return user_id