"""
Authentication and Authorization Module

Contains authentication components for the BetterBooks platform:
- User authentication and JWT handling
- Role-based access control
- Rate limiting
- Auth middleware and routes
"""

from .auth import User, get_current_user, get_optional_user, require_role, UserRole, check_rate_limit
from .auth_routes import auth_router

__all__ = [
    'User', 
    'get_current_user', 
    'get_optional_user', 
    'require_role', 
    'UserRole', 
    'check_rate_limit',
    'auth_router'
]