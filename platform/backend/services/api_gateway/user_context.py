import logging
from typing import Optional
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)


def get_current_user_id(
    authorization: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    if authorization:
        try:
            from core.auth.auth import verify_token

            payload = verify_token(authorization.credentials)

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

    logger.warning("No authentication present - rejecting request")
    raise HTTPException(status_code=401, detail="Authentication required")


def get_current_user_id_optional(
    authorization: HTTPAuthorizationCredentials = Depends(security),
) -> Optional[str]:
    try:
        return get_current_user_id(authorization)
    except HTTPException:
        return None


def require_authenticated_user(
    authorization: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    return get_current_user_id(authorization)
