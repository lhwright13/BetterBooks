"""
JWT Authentication Module for EchoWright API Gateway

Provides PostgreSQL-backed JWT token-based authentication with OAuth support.
Supports email/password, Google Sign In, and Apple Sign In authentication.

This module serves as a compatibility layer that imports PostgreSQL-based
authentication functions while maintaining backward compatibility.

Key Features:
- JWT token generation and validation with PostgreSQL session storage
- Multi-provider authentication (email, Google, Apple)
- User registration and authentication with database persistence
- Role-based access control (Admin, User roles)
- OAuth provider linking and unlinking
- Session management with token blacklisting

Dependencies:
- PostgreSQL database backend
- PyJWT for token handling
- bcrypt for password hashing
- FastAPI security utilities

Usage:
- Use get_current_user dependency for user context
- Use require_role decorator for RBAC
- Use register_user_with_email() for email/password registration
- Use authenticate_user_with_email() for email/password login
- Use authenticate_or_register_oauth_user() for OAuth flows
"""

import logging

# Import PostgreSQL-based authentication
from .auth_postgresql import (
    # Models and types
    User, UserRole, UserRegistration, UserLogin, TokenResponse,
    OAuthUserData, ProviderType, AuthError, PermissionError,
    
    # Authentication functions
    register_user_with_email,
    authenticate_user_with_email,
    authenticate_or_register_oauth_user,
    refresh_access_token,
    logout_user,
    link_oauth_provider,
    
    # Dependencies and decorators
    get_current_user,
    get_optional_user,
    require_role,
    require_admin,
    
    # Utility functions
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_token,
    
    # Security
    security
)

logger = logging.getLogger(__name__)

# Legacy compatibility functions - these now use PostgreSQL backend
def create_user(user_data: UserRegistration) -> User:
    """Create new user account (legacy compatibility)"""
    logger.warning("Using legacy create_user function. Consider using register_user_with_email instead.")
    token_response = register_user_with_email(user_data)
    return token_response.user

def authenticate_user(email: str, password: str) -> Optional[User]:
    """Authenticate user with email and password (legacy compatibility)"""
    logger.warning("Using legacy authenticate_user function. Consider using authenticate_user_with_email instead.")
    try:
        login_data = UserLogin(email=email, password=password)
        token_response = authenticate_user_with_email(login_data)
        return token_response.user
    except (AuthError, HTTPException):
        return None

def get_user_by_id(user_id: str) -> Optional[User]:
    """Get user by ID (legacy compatibility)"""
    logger.warning("Using legacy get_user_by_id function. Consider using UserModel directly.")
    try:
        from uuid import UUID
        from .auth_postgresql import user_model
        return user_model.get_user_by_id(UUID(user_id))
    except Exception:
        return None

# Note: All other authentication functions (get_current_user, require_role, etc.)
# are now imported from auth_postgresql.py which provides PostgreSQL-backed authentication
# with full OAuth support for Google Sign In and Apple Sign In.

logger.info("PostgreSQL-backed authentication system loaded with OAuth support")