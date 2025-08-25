"""
Authentication Routes for EchoWright API Gateway

Provides HTTP endpoints for user authentication, registration, and session management.
Integrates with the auth module to handle JWT tokens and user operations.

Routes:
- POST /auth/register: User registration
- POST /auth/login: User login with JWT tokens
- POST /auth/refresh: Token refresh
- POST /auth/logout: User logout (token blacklisting)
- GET /auth/me: Get current user info
- GET /auth/users: List users (admin only)
- PUT /auth/users/{user_id}/role: Change user role (admin only)
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
import logging
from typing import List, Dict, Any

from core.auth.auth import (
    User, UserRegistration, UserLogin, TokenResponse, UserRole,
    create_user, authenticate_user, get_current_user, get_optional_user,
    require_role, require_admin, check_rate_limit,
    create_access_token, create_refresh_token, verify_token,
    blacklist_token, USERS_DB,
    ACCESS_TOKEN_EXPIRE_MINUTES, security
)

logger = logging.getLogger(__name__)

# Create router for auth endpoints
auth_router = APIRouter(prefix="/auth", tags=["authentication"])

@auth_router.post("/register", response_model=Dict[str, Any])
async def register_user(user_data: UserRegistration):
    """Register a new user account"""
    try:
        # Rate limiting for registration (prevent spam)
        await check_rate_limit(user_data.email, "register", limit=5, window=3600)  # 5 per hour
        
        # Create user
        user = create_user(user_data)
        
        # Generate tokens
        token_data = {"sub": user.id, "email": user.email, "role": user.role.value}
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token(token_data)
        
        logger.info(f"User registered successfully: {user.email}")
        
        return {
            "message": "User registered successfully",
            "user": {
                "id": user.id,
                "email": user.email,
                "username": user.username,
                "role": user.role.value,
                "email_verified": True,  # Auto-verify emails since email service is not configured
                "is_active": user.is_active,
                "created_at": user.created_at.isoformat()
            },
            "tokens": TokenResponse(
                access_token=access_token,
                refresh_token=refresh_token,
                expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60
            )
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"User registration failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed"
        )

@auth_router.post("/login", response_model=TokenResponse)
async def login_user(user_credentials: UserLogin):
    """Authenticate user and return JWT tokens"""
    try:
        # Rate limiting for login attempts
        await check_rate_limit(user_credentials.email, "login", limit=10, window=900)  # 10 per 15 min
        
        # Authenticate user
        user = authenticate_user(user_credentials.email, user_credentials.password)
        
        if not user:
            # Log failed attempt
            logger.warning(f"Failed login attempt for email: {user_credentials.email}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        # Generate tokens
        token_data = {"sub": user.id, "email": user.email, "role": user.role.value}
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token(token_data)
        
        logger.info(f"User logged in successfully: {user.email}")
        
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"User login failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Login failed"
        )

@auth_router.post("/refresh", response_model=TokenResponse)
async def refresh_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Refresh access token using refresh token"""
    try:
        token = credentials.credentials
        
        # Verify refresh token
        payload = verify_token(token, "refresh")
        user_id = payload.get("sub")
        
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token"
            )
        
        # Get user to ensure they still exist and are active
        from core.auth.auth import get_user_by_id
        user = get_user_by_id(user_id)
        if not user or not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found or inactive"
            )
        
        # Generate new tokens
        token_data = {"sub": user.id, "email": user.email, "role": user.role.value}
        new_access_token = create_access_token(token_data)
        new_refresh_token = create_refresh_token(token_data)
        
        # Blacklist old refresh token
        blacklist_token(token, expires_in=7*24*3600)  # 7 days
        
        logger.info(f"Token refreshed for user: {user.email}")
        
        return TokenResponse(
            access_token=new_access_token,
            refresh_token=new_refresh_token,
            expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token refresh failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Token refresh failed"
        )

@auth_router.post("/logout")
async def logout_user(
    current_user: User = Depends(get_current_user),
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """Logout user by blacklisting their token"""
    try:
        token = credentials.credentials
        
        # Blacklist the current access token
        blacklist_token(token, expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60)
        
        logger.info(f"User logged out: {current_user.email}")
        
        return {"message": "Successfully logged out"}
        
    except Exception as e:
        logger.error(f"Logout failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Logout failed"
        )

@auth_router.get("/me", response_model=Dict[str, Any])
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current user information"""
    return {
        "id": current_user.id,
        "email": current_user.email,
        "username": current_user.username,
        "role": current_user.role.value,
        "is_active": current_user.is_active,
        "created_at": current_user.created_at.isoformat()
    }

@auth_router.get("/users", response_model=List[Dict[str, Any]])
async def list_users(current_user: User = Depends(require_admin)):
    """List all users (admin only)"""
    users = []
    for user_record in USERS_DB.values():
        users.append({
            "id": user_record["id"],
            "email": user_record["email"],
            "username": user_record["username"],
            "role": user_record["role"],
            "is_active": user_record["is_active"],
            "created_at": user_record["created_at"].isoformat()
        })
    
    return users

@auth_router.put("/users/{user_id}/role")
async def change_user_role(
    user_id: str,
    new_role: Dict[str, str],
    current_user: User = Depends(require_admin)
):
    """Change user role (admin only)"""
    if user_id not in USERS_DB:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    role_value = new_role.get("role")
    if role_value not in [role.value for role in UserRole]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid role. Must be one of: {[role.value for role in UserRole]}"
        )
    
    # Prevent admin from changing their own role
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot change your own role"
        )
    
    # Update user role
    USERS_DB[user_id]["role"] = role_value
    
    logger.info(f"User role changed by {current_user.email}: {user_id} -> {role_value}")
    
    return {
        "message": f"User role updated to {role_value}",
        "user_id": user_id,
        "new_role": role_value
    }

@auth_router.put("/users/{user_id}/status")
async def change_user_status(
    user_id: str,
    status_data: Dict[str, bool],
    current_user: User = Depends(require_admin)
):
    """Activate/deactivate user (admin only)"""
    if user_id not in USERS_DB:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    is_active = status_data.get("is_active")
    if is_active is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="is_active field is required"
        )
    
    # Prevent admin from deactivating themselves
    if user_id == current_user.id and not is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot deactivate your own account"
        )
    
    # Update user status
    USERS_DB[user_id]["is_active"] = is_active
    
    action = "activated" if is_active else "deactivated"
    logger.info(f"User {action} by {current_user.email}: {user_id}")
    
    return {
        "message": f"User {action} successfully",
        "user_id": user_id,
        "is_active": is_active
    }

@auth_router.post("/google/signin")
async def google_signin(request: Dict[str, Any]):
    """Google OAuth sign-in endpoint (stub for mobile testing)"""
    logger.info("Google sign-in attempt (stub)")
    raise HTTPException(
        status_code=501,
        detail="Google OAuth integration not yet implemented. Please use email/password authentication."
    )

@auth_router.post("/apple/signin") 
async def apple_signin(request: Dict[str, Any]):
    """Apple Sign In endpoint (stub for mobile testing)"""
    logger.info("Apple sign-in attempt (stub)")
    raise HTTPException(
        status_code=501,
        detail="Apple Sign In integration not yet implemented. Please use email/password authentication."
    )

@auth_router.get("/health")
async def auth_health():
    """Authentication service health check"""
    return {
        "status": "ok",
        "service": "authentication",
        "users_count": len(USERS_DB),
        "redis_connected": bool(
            hasattr(auth_router, 'redis_client') and 
            getattr(auth_router, 'redis_client') is not None
        )
    }