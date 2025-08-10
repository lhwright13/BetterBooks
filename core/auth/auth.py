"""
JWT Authentication Module for EchoWright API Gateway

Provides JWT token-based authentication and authorization middleware for the API Gateway.
Implements user registration, login, role-based access control (RBAC), and request validation.

Key Features:
- JWT token generation and validation
- User registration and authentication
- Role-based access control (Admin, User roles)
- Rate limiting integration
- Password hashing with bcrypt
- Token refresh mechanism
- Secure session management

Dependencies:
- PyJWT for token handling
- bcrypt for password hashing
- FastAPI security utilities
- Redis for session storage and rate limiting

Usage:
- Import and apply auth_middleware to protect endpoints
- Use get_current_user dependency for user context
- Use require_role decorator for RBAC
"""

import os
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, List
import jwt
import bcrypt
import redis
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from enum import Enum

try:
    from core.shared.utils.config_manager import get_config
except ImportError:
    # Fallback to basic config if shared config not available
    class BasicConfig:
        def get_required(self, key):
            value = os.getenv(key)
            if not value:
                raise ValueError(f"Required environment variable {key} is not set")
            return value
        
        def get_cache_config(self):
            class CacheConfig:
                redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
            return CacheConfig()
    
    def get_config():
        return BasicConfig()

logger = logging.getLogger(__name__)
config = get_config()

# JWT Configuration
JWT_SECRET_KEY = config.get_required("JWT_SECRET_KEY")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

# Redis connection for session management and rate limiting
try:
    redis_client = redis.Redis.from_url(config.get_cache_config().redis_url)
    redis_client.ping()
    logger.info("Connected to Redis for session management")
except Exception as e:
    logger.warning(f"Redis connection failed: {e}. Sessions will be stateless.")
    redis_client = None

# FastAPI Security
security = HTTPBearer()

class UserRole(Enum):
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"

class User(BaseModel):
    id: str
    email: EmailStr
    username: str
    role: UserRole
    is_active: bool = True
    created_at: datetime

class UserRegistration(BaseModel):
    email: EmailStr
    username: str
    password: str
    role: UserRole = UserRole.USER

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = ACCESS_TOKEN_EXPIRE_MINUTES * 60

class AuthError(HTTPException):
    def __init__(self, detail: str = "Authentication failed"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"}
        )

class PermissionError(HTTPException):
    def __init__(self, detail: str = "Insufficient permissions"):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=detail
        )

class RateLimitError(HTTPException):
    def __init__(self, detail: str = "Rate limit exceeded"):
        super().__init__(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=detail,
            headers={"Retry-After": "60"}
        )

def hash_password(password: str) -> str:
    """Hash password using bcrypt"""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')

def verify_password(password: str, hashed_password: str) -> bool:
    """Verify password against hash"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed_password.encode('utf-8'))

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire, "type": "access"})
    
    try:
        encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
        return encoded_jwt
    except Exception as e:
        logger.error(f"Token creation failed: {e}")
        raise AuthError("Token creation failed")

def create_refresh_token(data: dict) -> str:
    """Create JWT refresh token"""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    
    try:
        encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
        return encoded_jwt
    except Exception as e:
        logger.error(f"Refresh token creation failed: {e}")
        raise AuthError("Refresh token creation failed")

def verify_token(token: str, token_type: str = "access") -> Dict[str, Any]:
    """Verify and decode JWT token"""
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        
        if payload.get("type") != token_type:
            raise AuthError("Invalid token type")
            
        return payload
        
    except jwt.ExpiredSignatureError:
        raise AuthError("Token has expired")
    except jwt.InvalidTokenError:
        raise AuthError("Invalid token")
    except Exception as e:
        logger.error(f"Token verification failed: {e}")
        raise AuthError("Token verification failed")

# In-memory user store (replace with database in production)
USERS_DB: Dict[str, Dict[str, Any]] = {}

def create_user(user_data: UserRegistration) -> User:
    """Create new user account"""
    # Check if user already exists
    for existing_user in USERS_DB.values():
        if existing_user["email"] == user_data.email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        if existing_user["username"] == user_data.username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken"
            )
    
    # Create user ID
    user_id = f"user_{len(USERS_DB) + 1}"
    
    # Hash password
    hashed_password = hash_password(user_data.password)
    
    # Store user
    user_record = {
        "id": user_id,
        "email": user_data.email,
        "username": user_data.username,
        "hashed_password": hashed_password,
        "role": user_data.role.value,
        "is_active": True,
        "created_at": datetime.now(timezone.utc)
    }
    
    USERS_DB[user_id] = user_record
    
    # Return user (without password)
    return User(
        id=user_id,
        email=user_data.email,
        username=user_data.username,
        role=user_data.role,
        is_active=True,
        created_at=user_record["created_at"]
    )

def authenticate_user(email: str, password: str) -> Optional[User]:
    """Authenticate user with email and password"""
    for user_record in USERS_DB.values():
        if user_record["email"] == email:
            if verify_password(password, user_record["hashed_password"]):
                if not user_record["is_active"]:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Account is deactivated"
                    )
                return User(
                    id=user_record["id"],
                    email=user_record["email"],
                    username=user_record["username"],
                    role=UserRole(user_record["role"]),
                    is_active=user_record["is_active"],
                    created_at=user_record["created_at"]
                )
    return None

def get_user_by_id(user_id: str) -> Optional[User]:
    """Get user by ID"""
    user_record = USERS_DB.get(user_id)
    if user_record:
        return User(
            id=user_record["id"],
            email=user_record["email"],
            username=user_record["username"],
            role=UserRole(user_record["role"]),
            is_active=user_record["is_active"],
            created_at=user_record["created_at"]
        )
    return None

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    """Get current authenticated user from JWT token"""
    token = credentials.credentials
    
    # Verify token
    payload = verify_token(token, "access")
    user_id = payload.get("sub")
    
    if not user_id:
        raise AuthError("Invalid token payload")
    
    # Check if token is blacklisted (if Redis available)
    if redis_client:
        try:
            if redis_client.get(f"blacklist:{token}"):
                raise AuthError("Token has been revoked")
        except Exception as e:
            logger.warning(f"Redis blacklist check failed: {e}")
    
    # Get user
    user = get_user_by_id(user_id)
    if not user:
        raise AuthError("User not found")
    
    if not user.is_active:
        raise AuthError("User account is deactivated")
    
    return user

async def get_optional_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)) -> Optional[User]:
    """Get current user if token provided, otherwise return None"""
    if not credentials:
        return None
    
    try:
        return await get_current_user(credentials)
    except HTTPException:
        return None

def require_role(required_role: UserRole):
    """Decorator to require specific user role"""
    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role.value == UserRole.ADMIN.value:
            return current_user  # Admin can access everything
        
        if current_user.role != required_role:
            raise PermissionError(f"Access requires {required_role.value} role")
        
        return current_user
    
    return role_checker

def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """Require admin role"""
    if current_user.role != UserRole.ADMIN:
        raise PermissionError("Admin access required")
    return current_user

async def check_rate_limit(user_id: str, endpoint: str, limit: int = 60, window: int = 60) -> bool:
    """Check if user has exceeded rate limit for endpoint"""
    if not redis_client:
        return True  # Skip rate limiting if Redis unavailable
    
    try:
        key = f"rate_limit:{user_id}:{endpoint}"
        current = redis_client.incr(key)
        
        if current == 1:
            redis_client.expire(key, window)
        
        if current > limit:
            raise RateLimitError(f"Rate limit exceeded. Max {limit} requests per {window} seconds.")
        
        return True
        
    except RateLimitError:
        raise
    except Exception as e:
        logger.warning(f"Rate limit check failed: {e}")
        return True  # Allow request if rate limiting fails

def blacklist_token(token: str, expires_in: Optional[int] = None):
    """Add token to blacklist"""
    if not redis_client:
        logger.warning("Cannot blacklist token: Redis unavailable")
        return
    
    try:
        key = f"blacklist:{token}"
        redis_client.setex(key, expires_in or ACCESS_TOKEN_EXPIRE_MINUTES * 60, "1")
    except Exception as e:
        logger.error(f"Token blacklisting failed: {e}")

# Create default admin user if none exists
def ensure_admin_user():
    """Ensure at least one admin user exists"""
    admin_exists = any(
        user["role"] == UserRole.ADMIN.value 
        for user in USERS_DB.values()
    )
    
    if not admin_exists:
        admin_data = UserRegistration(
            email="admin@echowright.com",
            username="admin",
            password="admin123",  # Change in production!
            role=UserRole.ADMIN
        )
        admin_user = create_user(admin_data)
        logger.info(f"Created default admin user: {admin_user.email}")
        logger.warning("⚠️ Change the default admin password in production!")

# Initialize default admin
ensure_admin_user()