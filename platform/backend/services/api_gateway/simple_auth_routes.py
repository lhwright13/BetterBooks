"""
Simple Authentication Routes for BetterBooks API Gateway

This module provides authentication endpoints that work with the existing
core.auth.auth module without complex dependencies like Supabase.

Supports:
- Email/password registration and login
- Google OAuth sign in
- Apple Sign In  
- JWT token management
- Email verification
- Password reset
"""

import os
import logging
from typing import Optional, Dict, Any
from datetime import datetime, timedelta

from fastapi import APIRouter, HTTPException, status, Depends, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr

# Import existing auth functionality
from core.auth.auth import (
    create_access_token, create_refresh_token, verify_token,
    create_user, authenticate_user, create_or_update_oauth_user,
    get_current_user, UserRole, User, UserRegistration, USERS_DB
)

# Import email service
from core.services.email_service import get_email_service

logger = logging.getLogger(__name__)

# Create router
router = APIRouter()

# Security
security = HTTPBearer()

# =====================================================
# HELPER FUNCTIONS
# =====================================================

def get_user_by_email(email: str) -> Optional[User]:
    """Get user by email from storage"""
    for user_id, user_record in USERS_DB.items():
        if user_record["email"] == email:
            return User(
                id=user_id,
                email=user_record["email"],
                username=user_record["username"],
                display_name=user_record.get("display_name", user_record["email"].split('@')[0]),
                role=UserRole(user_record["role"]),
                is_active=user_record.get("is_active", True),
                email_verified=user_record.get("email_verified", True),
                created_at=user_record["created_at"]
            )
    return None

# =====================================================
# REQUEST/RESPONSE MODELS
# =====================================================

class GoogleSignInRequest(BaseModel):
    id_token: str

class AppleSignInRequest(BaseModel):
    id_token: str
    nonce: str
    user_info: Optional[Dict[str, Any]] = None

class EmailSignUpRequest(BaseModel):
    email: EmailStr
    password: str
    display_name: Optional[str] = None

class EmailSignInRequest(BaseModel):
    email: EmailStr
    password: str

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class LogoutRequest(BaseModel):
    refresh_token: str

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_at: Optional[int] = None
    user: Dict[str, Any]

class EmailVerificationRequest(BaseModel):
    email: EmailStr

class PasswordResetRequest(BaseModel):
    email: EmailStr

# Note: OAuth implementations removed - features coming soon

# =====================================================
# AUTHENTICATION ENDPOINTS
# =====================================================

@router.post("/auth/google")
async def google_sign_in(request: GoogleSignInRequest):
    """Google OAuth sign in - Coming Soon"""
    logger.info("Google sign in attempted - feature not yet available")
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Google Sign In coming soon! Please use email registration for now."
    )

@router.post("/auth/apple")
async def apple_sign_in(request: AppleSignInRequest):
    """Apple Sign In - Coming Soon"""
    logger.info("Apple sign in attempted - feature not yet available")
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Apple Sign In coming soon! Please use email registration for now."
    )

@router.post("/auth/signup", response_model=AuthResponse)
async def email_sign_up(request: EmailSignUpRequest):
    """Email/password sign up"""
    try:
        # Check if user already exists
        if get_user_by_email(request.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User with this email already exists"
            )
            
        # Create new user
        user_registration = UserRegistration(
            email=request.email,
            username=request.email,
            password=request.password,
            role=UserRole.USER
        )
        user = create_user(user_registration)
        
        # Send verification email
        try:
            email_service = get_email_service()
            await email_service.send_verification_email(
                email=request.email,
                verification_token="dummy-token-for-now",  # TODO: Implement proper verification
                user_name=user.display_name
            )
        except Exception as e:
            logger.warning(f"Failed to send verification email: {e}")
            # Don't fail registration if email fails
            
        logger.info(f"Created new email user: {user.email}")
        
        # Generate tokens  
        access_token = create_access_token(data={"sub": user.email})
        refresh_token = create_refresh_token(data={"sub": user.email})
        
        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=int((datetime.utcnow() + timedelta(minutes=30)).timestamp()),
            user=user.to_dict()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Email sign up failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Sign up failed"
        )

@router.post("/auth/signin", response_model=AuthResponse)
async def email_sign_in(request: EmailSignInRequest):
    """Email/password sign in"""
    try:
        # Authenticate user
        user = authenticate_user(request.email, request.password)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
            
        logger.info(f"Email sign in successful: {user.email}")
        
        # Generate tokens
        access_token = create_access_token(data={"sub": user.email})
        refresh_token = create_refresh_token(data={"sub": user.email})
        
        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=int((datetime.utcnow() + timedelta(minutes=30)).timestamp()),
            user=user.to_dict()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Email sign in failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

@router.post("/auth/refresh", response_model=AuthResponse)
async def refresh_token_endpoint(request: RefreshTokenRequest):
    """Refresh access token"""
    try:
        # Verify refresh token
        payload = verify_token(request.refresh_token)
        email = payload.get("sub")
        
        if not email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token"
            )
            
        # Get user
        user = get_user_by_email(email)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )
            
        # Generate new tokens
        access_token = create_access_token(data={"sub": user.email})
        refresh_token = create_refresh_token(data={"sub": user.email})
        
        return AuthResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=int((datetime.utcnow() + timedelta(minutes=30)).timestamp()),
            user=user.to_dict()
        )
        
    except Exception as e:
        logger.error(f"Token refresh failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token refresh failed"
        )

@router.post("/auth/logout")
async def logout(
    request: LogoutRequest,
    current_user: User = Depends(get_current_user)
):
    """Logout user"""
    logger.info(f"User logged out: {current_user.email}")
    return {"message": "Successfully logged out"}

@router.get("/me")
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current user information"""
    return current_user.to_dict()

# =====================================================
# EMAIL VERIFICATION ENDPOINTS
# =====================================================

@router.post("/email/send-verification")
async def send_verification_email(request: EmailVerificationRequest):
    """Send email verification"""
    try:
        email_service = get_email_service()
        success = await email_service.send_verification_email(
            email=request.email,
            verification_token="dummy-token",  # TODO: Generate proper token
            user_name="User"
        )
        
        if success:
            return {"message": "Verification email sent successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send verification email"
            )
            
    except Exception as e:
        logger.error(f"Send verification email failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification email"
        )

@router.post("/password/reset")
async def request_password_reset(request: PasswordResetRequest):
    """Request password reset"""
    try:
        user = get_user_by_email(request.email)
        if not user:
            # For security, don't reveal if email exists
            return {"message": "If an account with this email exists, a password reset link has been sent"}
            
        email_service = get_email_service()
        success = await email_service.send_password_reset_email(
            email=request.email,
            reset_token="dummy-token",  # TODO: Generate proper token
            user_name=user.display_name
        )
        
        return {"message": "If an account with this email exists, a password reset link has been sent"}
        
    except Exception as e:
        logger.error(f"Password reset request failed: {e}")
        return {"message": "If an account with this email exists, a password reset link has been sent"}

# =====================================================
# USER PROFILE
# =====================================================

@router.get("/auth/me", response_model=dict)
async def get_current_user_info(authorization: str = Header(None)):
    """Get current user information"""
    try:
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(
                status_code=401,
                detail="Missing or invalid authorization header"
            )
        
        token = authorization.split(" ")[1]
        
        # Verify the token and get user info
        user_data = verify_token(token, "access")
        if not user_data:
            raise HTTPException(
                status_code=401,
                detail="Invalid or expired token"
            )
        
        # Look up the user in the USERS_DB (in-memory database)
        user_email = user_data.get("email") or user_data.get("sub")
        if not user_email:
            raise HTTPException(
                status_code=401,
                detail="Invalid token payload"
            )
        
        # Find user in the in-memory database
        user = None
        for stored_user in USERS_DB.values():
            if stored_user["email"] == user_email:
                user = stored_user
                break
        
        if not user:
            raise HTTPException(
                status_code=404,
                detail="User not found"
            )
        
        return {
            "id": user["id"],
            "email": user["email"],
            "display_name": user.get("display_name", user["email"].split('@')[0]),
            "is_verified": user.get('email_verified', True),
            "created_at": user["created_at"].isoformat() if user.get("created_at") else None,
            "role": user.get('role', 'user'),
            "subscription_status": user.get('subscription_status', 'free'),
            "avatar_url": user.get('avatar_url', None)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user info: {e}")
        raise HTTPException(
            status_code=500,
            detail="Internal server error"
        )

# =====================================================
# HEALTH CHECK
# =====================================================

@router.get("/auth/health")
async def health_check():
    """Authentication service health check"""
    return {
        "status": "ok",
        "service": "authentication",
        "timestamp": datetime.utcnow().isoformat()
    }