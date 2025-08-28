"""
JWT Authentication Module for BetterBooks API Gateway

Provides JWT token-based authentication and authorization middleware for the BetterBooks API Gateway.
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

# Set up logging first
logger = logging.getLogger(__name__)
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, List, Tuple
# Optional dependencies for full auth functionality
try:
    import jwt
    JWT_AVAILABLE = True
except ImportError:
    JWT_AVAILABLE = False
    
try:
    import bcrypt
    BCRYPT_AVAILABLE = True
except ImportError:
    BCRYPT_AVAILABLE = False
    
try:
    import redis
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False
import requests
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from enum import Enum
# Optional Google OAuth dependencies - graceful degradation if not available
try:
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token
    GOOGLE_AUTH_AVAILABLE = True
except ImportError:
    GOOGLE_AUTH_AVAILABLE = False
    logger.warning("Google Auth not available - OAuth will be disabled")

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
    display_name: Optional[str] = None
    role: UserRole
    is_active: bool = True
    email_verified: bool = True  # For now, auto-verify all emails since email service is not configured
    created_at: datetime

    class Config:
        json_encoders = {
            datetime: lambda dt: dt.isoformat()
        }
        
    def to_dict(self):
        """Convert user to dictionary for API responses"""
        return {
            "id": self.id,
            "email": str(self.email),
            "username": self.username,
            "display_name": self.display_name,
            "role": self.role.value,
            "is_active": self.is_active,
            "email_verified": self.email_verified,
            "created_at": self.created_at.isoformat()
        }

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

# Initialize user storage - always available as fallback
USERS_DB: Dict[str, Dict[str, Any]] = {}

# Database-backed user management
try:
    from ..database.database_manager import DatabaseManager
    from .user_manager import UserManager
    db_manager = DatabaseManager()
    user_manager = UserManager(db_manager)
    logger.info("Database user management initialized")
except Exception as e:
    logger.warning(f"Failed to initialize database user management: {e}")
    # Use in-memory fallback for development
    db_manager = None
    user_manager = None

def create_user(user_data: UserRegistration) -> User:
    """Create new user account"""
    if user_manager:
        # Use database-backed user management
        import asyncio
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # Hash password
            hashed_password = hash_password(user_data.password)
            
            user_dict = loop.run_until_complete(
                user_manager.create_user_from_email(
                    email=user_data.email,
                    username=user_data.username,
                    hashed_password=hashed_password,
                    role=user_data.role
                )
            )
            
            return User(
                id=user_dict['id'],
                email=user_dict['email'],
                username=user_dict['username'],
                display_name=user_dict.get('display_name'),
                role=user_data.role,
                is_active=user_dict['is_active'],
                email_verified=user_dict['email_verified'],
                created_at=datetime.fromisoformat(user_dict['created_at'].replace('Z', '+00:00'))
            )
            
        except Exception as e:
            if "already exists" in str(e):
                if "email" in str(e):
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Email already registered"
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Username already taken"
                    )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create user"
            )
        finally:
            loop.close()
    else:
        # Fallback to in-memory storage
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
            "email_verified": True,  # Auto-verify since email service is not configured
            "created_at": datetime.now(timezone.utc)
        }
        
        USERS_DB[user_id] = user_record
        
        # Return user (without password)
        return User(
            id=user_id,
            email=user_data.email,
            username=user_data.username,
            display_name=user_data.email.split('@')[0],
            role=user_data.role,
            is_active=True,
            email_verified=True,
            created_at=user_record["created_at"]
        )

def authenticate_user(email: str, password: str) -> Optional[User]:
    """Authenticate user with email and password"""
    if user_manager:
        # Use database-backed authentication
        import asyncio
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            user_dict = loop.run_until_complete(
                user_manager.authenticate_user(email, password)
            )
            
            if user_dict:
                return User(
                    id=user_dict['id'],
                    email=user_dict['email'],
                    username=user_dict['username'],
                    display_name=user_dict.get('display_name'),
                    role=UserRole(user_dict['role']),
                    is_active=user_dict['is_active'],
                    email_verified=user_dict['email_verified'],
                    created_at=datetime.fromisoformat(user_dict['created_at'].replace('Z', '+00:00'))
                )
            return None
            
        except Exception as e:
            logger.error(f"Database authentication failed: {e}")
            return None
        finally:
            loop.close()
    else:
        # Fallback to in-memory authentication
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
                        display_name=user_record.get("display_name", user_record["email"].split('@')[0]),
                        role=UserRole(user_record["role"]),
                        is_active=user_record["is_active"],
                        email_verified=user_record.get("email_verified", True),
                        created_at=user_record["created_at"]
                    )
        return None

def get_user_by_id(user_id: str) -> Optional[User]:
    """Get user by ID"""
    if user_manager:
        # Use database-backed user lookup
        import asyncio
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            user_dict = loop.run_until_complete(
                user_manager.get_user_by_id(user_id)
            )
            
            if user_dict:
                return User(
                    id=user_dict['id'],
                    email=user_dict['email'],
                    username=user_dict['username'],
                    display_name=user_dict.get('display_name'),
                    role=UserRole(user_dict['role']),
                    is_active=user_dict['is_active'],
                    email_verified=user_dict['email_verified'],
                    created_at=datetime.fromisoformat(user_dict['created_at'].replace('Z', '+00:00'))
                )
            return None
            
        except Exception as e:
            logger.error(f"Database user lookup failed: {e}")
            return None
        finally:
            loop.close()
    else:
        # Fallback to in-memory lookup
        user_record = USERS_DB.get(user_id)
        if user_record:
            return User(
                id=user_record["id"],
                email=user_record["email"],
                username=user_record["username"],
                role=UserRole(user_record["role"]),
                is_active=user_record["is_active"],
                email_verified=user_record.get("email_verified", True),
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
            email="admin@betterbooks.com",
            username="admin",
            password=os.getenv('DEFAULT_ADMIN_PASSWORD', 'TempPass123!'),  # MUST change in production!
            role=UserRole.ADMIN
        )
        admin_user = create_user(admin_data)
        logger.info(f"Created default admin user: {admin_user.email}")
        logger.warning("⚠️ Change the default admin password in production!")

# OAuth Support Functions

def create_or_update_oauth_user(email: str, display_name: str, provider: str, provider_id: str, avatar_url: str = None) -> User:
    """Create or update OAuth user account"""
    if user_manager:
        # Use database-backed OAuth user creation
        import asyncio
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            user_dict = loop.run_until_complete(
                user_manager.create_user_from_oauth(
                    email=email,
                    display_name=display_name,
                    provider=provider,
                    provider_id=provider_id,
                    avatar_url=avatar_url
                )
            )
            
            return User(
                id=user_dict['id'],
                email=user_dict['email'],
                username=user_dict['username'],
                role=UserRole(user_dict['role']),
                is_active=user_dict['is_active'],
                email_verified=user_dict['email_verified'],
                created_at=datetime.fromisoformat(user_dict['created_at'].replace('Z', '+00:00'))
            )
            
        except Exception as e:
            logger.error(f"Database OAuth user creation failed: {e}")
            # Fallback to creating a basic user
            return User(
                id=f"oauth_{provider}_{int(datetime.now().timestamp())}",
                email=email,
                username=email.split('@')[0] if email else f"{provider}user",
                role=UserRole.USER,
                is_active=True,
                email_verified=True,
                created_at=datetime.now(timezone.utc)
            )
        finally:
            loop.close()
    else:
        # Fallback to in-memory OAuth user creation
        # Check if user already exists by email
        existing_user_id = None
        for user_id, user_record in USERS_DB.items():
            if user_record["email"] == email:
                existing_user_id = user_id
                break
        
        if existing_user_id:
            # Update existing user
            user_record = USERS_DB[existing_user_id]
            user_record["display_name"] = display_name
            user_record["avatar_url"] = avatar_url
            user_record["oauth_provider"] = provider
            user_record["oauth_provider_id"] = provider_id
            
            return User(
                id=user_record["id"],
                email=user_record["email"],
                username=user_record["username"],
                role=UserRole(user_record["role"]),
                is_active=user_record["is_active"],
                email_verified=user_record.get("email_verified", True),
                created_at=user_record["created_at"]
            )
        else:
            # Create new OAuth user
            user_id = f"oauth_{provider}_{len(USERS_DB) + 1}"
            username = email.split('@')[0] if email else f"{provider}user{len(USERS_DB) + 1}"
            
            user_record = {
                "id": user_id,
                "email": email,
                "username": username,
                "display_name": display_name,
                "avatar_url": avatar_url,
                "hashed_password": None,  # OAuth users don't have passwords
                "role": UserRole.USER.value,
                "is_active": True,
                "email_verified": True,  # OAuth providers verify emails
                "oauth_provider": provider,
                "oauth_provider_id": provider_id,
                "created_at": datetime.now(timezone.utc)
            }
            
            USERS_DB[user_id] = user_record
            
            return User(
                id=user_id,
                email=email,
                username=username,
                role=UserRole.USER,
                is_active=True,
                email_verified=True,
                created_at=user_record["created_at"]
            )

def verify_google_token(id_token_str: str) -> Tuple[bool, Optional[Dict[str, Any]]]:
    """Verify Google ID token and return user info"""
    if not GOOGLE_AUTH_AVAILABLE:
        logger.error("Google Auth not available - cannot verify token")
        return False, None
        
    try:
        # Verify the token with Google
        # For production, you should specify your Google OAuth client ID
        google_client_id = os.getenv('GOOGLE_OAUTH_CLIENT_ID')
        if not google_client_id:
            logger.warning("GOOGLE_OAUTH_CLIENT_ID not set, skipping audience verification")
            idinfo = id_token.verify_oauth2_token(id_token_str, google_requests.Request())
        else:
            idinfo = id_token.verify_oauth2_token(id_token_str, google_requests.Request(), google_client_id)
        
        # Verify the issuer
        if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
            return False, None
            
        return True, {
            'email': idinfo.get('email'),
            'name': idinfo.get('name'),
            'picture': idinfo.get('picture'),
            'google_id': idinfo.get('sub'),
            'email_verified': idinfo.get('email_verified', False)
        }
        
    except ValueError as e:
        logger.error(f"Google token verification failed: {e}")
        return False, None
    except Exception as e:
        logger.error(f"Unexpected error verifying Google token: {e}")
        return False, None

# Cache for Apple's public keys
_apple_keys_cache = {"keys": None, "expires": 0}

def fetch_apple_public_keys() -> Dict[str, Any]:
    """Fetch Apple's public keys for JWT verification with caching"""
    current_time = datetime.now().timestamp()
    
    # Use cached keys if they're still valid (cache for 1 hour)
    if _apple_keys_cache["keys"] and current_time < _apple_keys_cache["expires"]:
        return _apple_keys_cache["keys"]
    
    try:
        response = requests.get("https://appleid.apple.com/auth/keys", timeout=10)
        response.raise_for_status()
        keys_data = response.json()
        
        # Cache the keys
        _apple_keys_cache["keys"] = keys_data
        _apple_keys_cache["expires"] = current_time + 3600  # 1 hour
        
        return keys_data
    except Exception as e:
        logger.error(f"Failed to fetch Apple public keys: {e}")
        # Return cached keys even if expired, as fallback
        if _apple_keys_cache["keys"]:
            return _apple_keys_cache["keys"]
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to verify Apple token: key service unavailable"
        )

def verify_apple_token(id_token_str: str, nonce: str = None) -> Tuple[bool, Optional[Dict[str, Any]]]:
    """Verify Apple ID token and return user info"""
    try:
        # Get Apple's public keys
        keys_data = fetch_apple_public_keys()
        
        # Decode token header to get key ID
        unverified_header = jwt.get_unverified_header(id_token_str)
        key_id = unverified_header.get('kid')
        
        if not key_id:
            logger.error("Apple token missing key ID")
            return False, None
        
        # Find the matching public key
        public_key = None
        for key in keys_data['keys']:
            if key['kid'] == key_id:
                public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key)
                break
        
        if not public_key:
            logger.error(f"Apple public key not found for key ID: {key_id}")
            return False, None
        
        # Verify and decode the token
        apple_client_id = os.getenv('APPLE_CLIENT_ID')
        if not apple_client_id:
            logger.warning("APPLE_CLIENT_ID not set, skipping audience verification")
            decoded_token = jwt.decode(
                id_token_str, 
                public_key, 
                algorithms=['RS256'],
                options={"verify_aud": False}
            )
        else:
            decoded_token = jwt.decode(
                id_token_str, 
                public_key, 
                algorithms=['RS256'],
                audience=apple_client_id
            )
        
        # Verify nonce if provided
        if nonce and decoded_token.get('nonce') != nonce:
            logger.error("Apple token nonce mismatch")
            return False, None
        
        # Verify issuer
        if decoded_token.get('iss') != 'https://appleid.apple.com':
            logger.error("Invalid Apple token issuer")
            return False, None
            
        return True, {
            'email': decoded_token.get('email'),
            'apple_id': decoded_token.get('sub'),
            'email_verified': decoded_token.get('email_verified', 'true') == 'true',
            'is_private_email': decoded_token.get('is_private_email', False)
        }
        
    except jwt.ExpiredSignatureError:
        logger.error("Apple token has expired")
        return False, None
    except jwt.InvalidTokenError as e:
        logger.error(f"Invalid Apple token: {e}")
        return False, None
    except Exception as e:
        logger.error(f"Unexpected error verifying Apple token: {e}")
        return False, None

# Initialize default admin - commented out to prevent import-time side effects
# ensure_admin_user() should be called explicitly when needed