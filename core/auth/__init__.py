"""
Authentication and Authorization Module

Contains authentication components for the BetterBooks platform:
- User authentication and JWT handling
- Role-based access control
- Rate limiting
"""

from .auth import User, get_current_user, get_optional_user, require_role, UserRole, check_rate_limit

__all__ = [
    'User',
    'get_current_user',
    'get_optional_user',
    'require_role',
    'UserRole',
    'check_rate_limit',
]