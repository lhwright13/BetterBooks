"""
Temporary Authentication Routes - Minimal Implementation

This provides basic auth endpoints with mock responses until full
authentication dependencies are resolved.
"""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
import logging
from typing import Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)

# Simple models for API compatibility
class UserRegistration(BaseModel):
    email: EmailStr
    password: str
    first_name: str = ""
    last_name: str = ""

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = 1800

class User(BaseModel):
    id: str
    email: str
    first_name: str
    last_name: str
    role: str = "user"
    created_at: str

# Create router
auth_router = APIRouter(prefix="/auth", tags=["authentication"])

@auth_router.post("/register", response_model=Dict[str, Any])
async def register_user(user_data: UserRegistration):
    """Register a new user account (temporary implementation)"""
    logger.info(f"Temporary registration for: {user_data.email}")
    
    user_id = f"temp_user_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    return {
        "message": "User registered successfully (temporary)",
        "user": User(
            id=user_id,
            email=user_data.email,
            first_name=user_data.first_name,
            last_name=user_data.last_name,
            role="user",
            created_at=datetime.now().isoformat()
        ),
        "tokens": TokenResponse(
            access_token=f"temp_access_{user_id}",
            refresh_token=f"temp_refresh_{user_id}",
            expires_in=1800
        )
    }

@auth_router.post("/login", response_model=TokenResponse)
async def login_user(user_data: UserLogin):
    """Login user (temporary implementation)"""
    logger.info(f"Temporary login for: {user_data.email}")
    
    user_id = f"temp_user_{user_data.email.replace('@', '_at_').replace('.', '_')}"
    
    return TokenResponse(
        access_token=f"temp_access_{user_id}",
        refresh_token=f"temp_refresh_{user_id}",
        expires_in=1800
    )

@auth_router.get("/me", response_model=User)
async def get_current_user():
    """Get current user info (temporary implementation)"""
    logger.info("Temporary user info request")
    
    return User(
        id="temp_user_current",
        email="demo@example.com",
        first_name="Demo",
        last_name="User",
        role="user",
        created_at=datetime.now().isoformat()
    )

@auth_router.post("/refresh", response_model=TokenResponse)
async def refresh_token():
    """Refresh access token (temporary implementation)"""
    logger.info("Temporary token refresh")
    
    return TokenResponse(
        access_token="temp_access_refreshed",
        refresh_token="temp_refresh_refreshed",
        expires_in=1800
    )

@auth_router.get("/health")
async def auth_health_check():
    """Health check for auth service"""
    return {
        "status": "ok",
        "service": "auth",
        "mode": "temporary",
        "timestamp": datetime.now().isoformat()
    }