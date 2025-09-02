"""
OAuth-Compatible JWT Authentication Module for EchoWright API Gateway

Provides JWT token-based authentication with PostgreSQL backend storage.
Supports multiple authentication providers: email/password, Google Sign In, Apple Sign In.

Key Features:
- JWT token generation and validation with PostgreSQL session storage
- Multi-provider authentication (email, Google, Apple)
- User registration and authentication with database persistence
- Role-based access control (Admin, User roles)
- OAuth provider linking and unlinking
- Password credential management separate from user accounts
- Session management with token blacklisting
- Comprehensive audit logging

Dependencies:
- PyJWT for token handling
- bcrypt for password hashing
- FastAPI security utilities
- PostgreSQL with psycopg2 for data persistence

Usage:
- Import and use database-backed authentication functions
- Use get_current_user dependency for user context
- Use require_role decorator for RBAC
"""

import os
import logging
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, List, Tuple
from uuid import UUID, uuid4
import jwt
import bcrypt
from fastapi import HTTPException, Depends, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr

# Import our database models
import sys
from pathlib import Path
sys.path.append(str(Path(__file__).parents[4] / "core"))

from database.connection import get_database_manager, initialize_database
from database.models.user_model import UserModel, User, CreateUserRequest, UpdateUserRequest, UserRole
from database.models.identity_model import IdentityModel, Identity, CreateIdentityRequest, ProviderType
from database.models.session_model import SessionModel, Session, CreateSessionRequest

logger = logging.getLogger(__name__)

# JWT Configuration
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "test-secret-key-for-testing")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

# FastAPI Security
security = HTTPBearer()

# Initialize database models
user_model = UserModel()
identity_model = IdentityModel()
session_model = SessionModel()

class UserRegistration(BaseModel):
    """User registration request"""
    email: Optional[EmailStr] = None
    username: Optional[str] = None
    display_name: Optional[str] = None
    password: Optional[str] = None  # Required for email registration
    role: UserRole = UserRole.USER

class UserLogin(BaseModel):
    """User login request"""
    email: EmailStr
    password: str

class OAuthUserData(BaseModel):
    """OAuth user data from provider"""
    provider: ProviderType
    provider_id: str
    provider_email: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    provider_data: Dict[str, Any] = {}

class TokenResponse(BaseModel):
    """Authentication token response"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = ACCESS_TOKEN_EXPIRE_MINUTES * 60
    user: User

class AuthError(HTTPException):
    """Authentication error"""
    def __init__(self, detail: str = "Authentication failed"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail,
            headers={"WWW-Authenticate": "Bearer"}
        )

class PermissionError(HTTPException):
    """Permission error"""
    def __init__(self, detail: str = "Insufficient permissions"):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=detail
        )

def hash_password(password: str) -> Tuple[str, str]:
    """Hash password using bcrypt and return (hash, salt)"""
    salt = bcrypt.gensalt()
    password_hash = bcrypt.hashpw(password.encode('utf-8'), salt)
    return password_hash.decode('utf-8'), salt.decode('utf-8')

def verify_password(password: str, password_hash: str) -> bool:
    """Verify password against hash"""
    return bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))

def create_token_hash(token: str) -> str:
    """Create SHA256 hash of token for database storage"""
    return hashlib.sha256(token.encode()).hexdigest()

def create_access_token(user_id: UUID, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode = {
        "sub": str(user_id),
        "exp": expire,
        "type": "access",
        "iat": datetime.now(timezone.utc)
    }
    
    try:
        encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
        return encoded_jwt
    except Exception as e:
        logger.error(f"Access token creation failed: {e}")
        raise AuthError("Token creation failed")

def create_refresh_token(user_id: UUID) -> str:
    """Create JWT refresh token"""
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode = {
        "sub": str(user_id),
        "exp": expire,
        "type": "refresh",
        "iat": datetime.now(timezone.utc)
    }
    
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

def register_user_with_email(user_data: UserRegistration) -> TokenResponse:
    """Register a new user with email/password authentication"""
    if not user_data.email or not user_data.password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email and password are required for email registration"
        )
    
    # Check if user already exists
    existing_user = user_model.get_user_by_email(user_data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Check if identity already exists
    existing_identity = identity_model.get_identity_by_provider(ProviderType.EMAIL, user_data.email)
    if existing_identity:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    try:
        # Create user
        create_user_data = CreateUserRequest(
            email=user_data.email,
            username=user_data.username,
            display_name=user_data.display_name or user_data.username,
            role=user_data.role,
            email_verified=False  # Will be verified later
        )
        
        user = user_model.create_user(create_user_data)
        
        # Create email identity
        identity_data = CreateIdentityRequest(
            user_id=user.id,
            provider=ProviderType.EMAIL,
            provider_id=user_data.email,
            provider_email=user_data.email,
            is_verified=False,
            is_primary=True
        )
        
        identity = identity_model.create_identity(identity_data)
        
        # Create password credentials
        password_hash, salt = hash_password(user_data.password)
        identity_model.create_password_credential(user.id, password_hash, salt)
        
        # Create tokens and sessions
        access_token = create_access_token(user.id)
        refresh_token = create_refresh_token(user.id)
        
        access_expires = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        
        session_model.create_access_and_refresh_sessions(
            user.id,
            create_token_hash(access_token),
            create_token_hash(refresh_token),
            access_expires,
            refresh_expires
        )
        
        logger.info(f"User registered successfully: {user.email}")
        
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=user
        )
        
    except Exception as e:
        logger.error(f"User registration failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed"
        )

def authenticate_user_with_email(login_data: UserLogin) -> TokenResponse:
    """Authenticate user with email/password"""
    # Get identity
    identity = identity_model.get_identity_by_provider(ProviderType.EMAIL, login_data.email)
    if not identity:
        raise AuthError("Invalid email or password")
    
    # Get user
    user = user_model.get_user_by_id(identity.user_id)
    if not user or not user.is_active:
        raise AuthError("Account not found or deactivated")
    
    # Get and verify password
    password_credential = identity_model.get_password_credential(user.id)
    if not password_credential:
        raise AuthError("Invalid email or password")
    
    if not verify_password(login_data.password, password_credential.password_hash):
        raise AuthError("Invalid email or password")
    
    try:
        # Update password last used
        identity_model.update_password_last_used(user.id)
        
        # Update user last login
        user_model.update_last_login(user.id)
        
        # Create tokens and sessions
        access_token = create_access_token(user.id)
        refresh_token = create_refresh_token(user.id)
        
        access_expires = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        
        session_model.create_access_and_refresh_sessions(
            user.id,
            create_token_hash(access_token),
            create_token_hash(refresh_token),
            access_expires,
            refresh_expires
        )
        
        logger.info(f"User authenticated successfully: {user.email}")
        
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=user
        )
        
    except Exception as e:
        logger.error(f"Authentication failed: {e}")
        raise AuthError("Authentication failed")

def authenticate_or_register_oauth_user(oauth_data: OAuthUserData) -> TokenResponse:
    """Authenticate or register user with OAuth provider (Google, Apple)"""
    # Check if identity already exists
    identity = identity_model.get_identity_by_provider(oauth_data.provider, oauth_data.provider_id)
    
    if identity:
        # Existing user - authenticate
        user = user_model.get_user_by_id(identity.user_id)
        if not user or not user.is_active:
            raise AuthError("Account not found or deactivated")
        
        # Update user last login
        user_model.update_last_login(user.id)
        
    else:
        # New user - register
        try:
            # Create user account
            create_user_data = CreateUserRequest(
                email=oauth_data.provider_email,  # May be None for Apple private relay
                display_name=oauth_data.display_name,
                avatar_url=oauth_data.avatar_url,
                role=UserRole.USER,
                email_verified=True  # OAuth providers are pre-verified
            )
            
            user = user_model.create_user(create_user_data)
            
            # Create OAuth identity
            identity_data = CreateIdentityRequest(
                user_id=user.id,
                provider=oauth_data.provider,
                provider_id=oauth_data.provider_id,
                provider_email=oauth_data.provider_email,
                provider_data=oauth_data.provider_data,
                is_verified=True,
                is_primary=True
            )
            
            identity = identity_model.create_identity(identity_data)
            
            logger.info(f"OAuth user registered: {oauth_data.provider.value}:{oauth_data.provider_id}")
            
        except Exception as e:
            logger.error(f"OAuth registration failed: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="OAuth registration failed"
            )
    
    try:
        # Create tokens and sessions
        access_token = create_access_token(user.id)
        refresh_token = create_refresh_token(user.id)
        
        access_expires = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        
        session_model.create_access_and_refresh_sessions(
            user.id,
            create_token_hash(access_token),
            create_token_hash(refresh_token),
            access_expires,
            refresh_expires
        )
        
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=user
        )
        
    except Exception as e:
        logger.error(f"OAuth token creation failed: {e}")
        raise AuthError("Authentication failed")

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> User:
    """Get current authenticated user from JWT token"""
    token = credentials.credentials
    
    # Verify token
    payload = verify_token(token, "access")
    user_id_str = payload.get("sub")
    
    if not user_id_str:
        raise AuthError("Invalid token payload")
    
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise AuthError("Invalid user ID in token")
    
    # Validate session
    token_hash = create_token_hash(token)
    session = session_model.validate_session(token_hash)
    
    if not session:
        raise AuthError("Session expired or revoked")
    
    # Get user
    user = user_model.get_user_by_id(user_id)
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
        if current_user.role == UserRole.ADMIN:
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

def logout_user(token: str) -> bool:
    """Logout user by revoking session"""
    try:
        token_hash = create_token_hash(token)
        return session_model.revoke_session_by_token_hash(token_hash)
    except Exception as e:
        logger.error(f"Logout failed: {e}")
        return False

def refresh_access_token(refresh_token: str) -> TokenResponse:
    """Create new access token using refresh token"""
    # Verify refresh token
    payload = verify_token(refresh_token, "refresh")
    user_id_str = payload.get("sub")
    
    if not user_id_str:
        raise AuthError("Invalid refresh token payload")
    
    try:
        user_id = UUID(user_id_str)
    except ValueError:
        raise AuthError("Invalid user ID in refresh token")
    
    # Validate refresh session
    refresh_token_hash = create_token_hash(refresh_token)
    refresh_session = session_model.validate_session(refresh_token_hash)
    
    if not refresh_session or refresh_session.token_type != "refresh":
        raise AuthError("Invalid or expired refresh token")
    
    # Get user
    user = user_model.get_user_by_id(user_id)
    if not user or not user.is_active:
        raise AuthError("User not found or deactivated")
    
    try:
        # Create new access token
        new_access_token = create_access_token(user.id)
        new_access_expires = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        
        # Create new access session
        new_session = session_model.refresh_access_token(
            refresh_token_hash,
            create_token_hash(new_access_token),
            new_access_expires
        )
        
        if not new_session:
            raise AuthError("Failed to refresh token")
        
        return TokenResponse(
            access_token=new_access_token,
            refresh_token=refresh_token,  # Keep same refresh token
            user=user
        )
        
    except Exception as e:
        logger.error(f"Token refresh failed: {e}")
        raise AuthError("Token refresh failed")

def link_oauth_provider(user_id: UUID, oauth_data: OAuthUserData) -> Identity:
    """Link additional OAuth provider to existing user account"""
    user = user_model.get_user_by_id(user_id)
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    try:
        return identity_model.link_providers(
            user_id,
            oauth_data.provider,
            oauth_data.provider_id,
            oauth_data.provider_email
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Provider linking failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to link provider"
        )

# Initialize database connection on module load
try:
    initialize_database()
    # Ensure admin user exists
    user_model.ensure_admin_exists()
    logger.info("PostgreSQL authentication system initialized")
except Exception as e:
    logger.error(f"Failed to initialize PostgreSQL authentication: {e}")
    # In development, we might continue with limited functionality
    # In production, this should probably be a fatal error