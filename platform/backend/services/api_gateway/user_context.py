"""
User Context Helper for API Gateway
Handles extracting user information from JWT tokens and authentication context
"""

import logging
from typing import Optional
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

logger = logging.getLogger(__name__)

# Security scheme
security = HTTPBearer(auto_error=False)


def get_current_user_id(
    authorization: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    """
    Extract user ID from JWT token.

    Args:
        authorization: JWT bearer token

    Returns:
        str: User ID

    Raises:
        HTTPException: If authentication is required but token is invalid
    """

    # Require a valid JWT token
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

    # No valid authentication present
    logger.warning("No authentication present - rejecting request")
    raise HTTPException(
        status_code=401,
        detail="Authentication required"
    )

def get_current_user_id_optional(
    authorization: HTTPAuthorizationCredentials = Depends(security),
) -> Optional[str]:
    """
    Same as get_current_user_id but returns None instead of raising for optional auth.
    """
    try:
        user_id = get_current_user_id(authorization)
        return user_id
    except HTTPException:
        return None


def require_authenticated_user(
    authorization: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    """
    Require that the user is authenticated with a valid JWT token.

    Raises:
        HTTPException: If no valid authentication is present
    """
    return get_current_user_id(authorization)