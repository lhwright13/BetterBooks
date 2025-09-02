"""
User Model for OAuth-Compatible Authentication

Handles user CRUD operations with support for multiple authentication providers.
Compatible with Google Sign In, Apple Sign In, and traditional email/password auth.
"""

import logging
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
from uuid import UUID, uuid4
from pydantic import BaseModel, EmailStr
from enum import Enum

from ..connection import get_database_manager

logger = logging.getLogger(__name__)

class UserRole(Enum):
    ADMIN = "admin"
    USER = "user"
    GUEST = "guest"

class User(BaseModel):
    """User model compatible with OAuth providers"""
    id: UUID
    email: Optional[EmailStr] = None  # Nullable for Apple Sign In private relay
    username: Optional[str] = None    # May be auto-generated for OAuth users
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    role: UserRole = UserRole.USER
    is_active: bool = True
    email_verified: bool = False
    created_at: datetime
    updated_at: datetime
    last_login: Optional[datetime] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: str
        }

class CreateUserRequest(BaseModel):
    """Request model for creating new users"""
    email: Optional[EmailStr] = None
    username: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    role: UserRole = UserRole.USER
    email_verified: bool = False

class UpdateUserRequest(BaseModel):
    """Request model for updating users"""
    email: Optional[EmailStr] = None
    username: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    is_active: Optional[bool] = None
    email_verified: Optional[bool] = None

class UserModel:
    """Database operations for users"""
    
    def __init__(self):
        self.db = get_database_manager()
    
    def create_user(self, user_data: CreateUserRequest) -> User:
        """Create a new user"""
        user_id = uuid4()
        now = datetime.now(timezone.utc)
        
        # Auto-generate username if not provided
        username = user_data.username
        if not username and user_data.email:
            username = user_data.email.split('@')[0]
        elif not username:
            username = f"user_{str(user_id)[:8]}"
        
        query = """
            INSERT INTO users (
                id, email, username, display_name, avatar_url, 
                role, is_active, email_verified, created_at, updated_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            ) RETURNING *
        """
        
        params = (
            user_id,
            user_data.email,
            username,
            user_data.display_name,
            user_data.avatar_url,
            user_data.role.value,
            True,
            user_data.email_verified,
            now,
            now
        )
        
        try:
            result = self.db.execute_query(query, params, fetch_one=True)
            if result:
                return User(**dict(result))
            else:
                raise Exception("Failed to create user")
        except Exception as e:
            logger.error(f"Error creating user: {e}")
            raise
    
    def get_user_by_id(self, user_id: UUID) -> Optional[User]:
        """Get user by ID"""
        query = "SELECT * FROM users WHERE id = %s AND is_active = true"
        
        try:
            result = self.db.execute_query(query, (user_id,), fetch_one=True)
            if result:
                return User(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error fetching user by ID {user_id}: {e}")
            return None
    
    def get_user_by_email(self, email: str) -> Optional[User]:
        """Get user by email"""
        query = "SELECT * FROM users WHERE email = %s AND is_active = true"
        
        try:
            result = self.db.execute_query(query, (email,), fetch_one=True)
            if result:
                return User(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error fetching user by email {email}: {e}")
            return None
    
    def get_user_by_username(self, username: str) -> Optional[User]:
        """Get user by username"""
        query = "SELECT * FROM users WHERE username = %s AND is_active = true"
        
        try:
            result = self.db.execute_query(query, (username,), fetch_one=True)
            if result:
                return User(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error fetching user by username {username}: {e}")
            return None
    
    def update_user(self, user_id: UUID, updates: UpdateUserRequest) -> Optional[User]:
        """Update user information"""
        # Build dynamic update query
        update_fields = []
        params = []
        
        for field, value in updates.dict(exclude_unset=True).items():
            if field == 'role' and isinstance(value, UserRole):
                value = value.value
            update_fields.append(f"{field} = %s")
            params.append(value)
        
        if not update_fields:
            return self.get_user_by_id(user_id)
        
        # Add updated_at timestamp
        update_fields.append("updated_at = %s")
        params.append(datetime.now(timezone.utc))
        params.append(user_id)  # For WHERE clause
        
        query = f"""
            UPDATE users 
            SET {', '.join(update_fields)}
            WHERE id = %s AND is_active = true
            RETURNING *
        """
        
        try:
            result = self.db.execute_query(query, tuple(params), fetch_one=True)
            if result:
                return User(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error updating user {user_id}: {e}")
            return None
    
    def update_last_login(self, user_id: UUID) -> bool:
        """Update user's last login timestamp"""
        query = """
            UPDATE users 
            SET last_login = %s, updated_at = %s
            WHERE id = %s AND is_active = true
        """
        
        now = datetime.now(timezone.utc)
        params = (now, now, user_id)
        
        try:
            rows_affected = self.db.execute_query(query, params)
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error updating last login for user {user_id}: {e}")
            return False
    
    def deactivate_user(self, user_id: UUID) -> bool:
        """Deactivate user account"""
        query = """
            UPDATE users 
            SET is_active = false, updated_at = %s
            WHERE id = %s
        """
        
        params = (datetime.now(timezone.utc), user_id)
        
        try:
            rows_affected = self.db.execute_query(query, params)
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error deactivating user {user_id}: {e}")
            return False
    
    def verify_email(self, user_id: UUID) -> bool:
        """Mark user's email as verified"""
        query = """
            UPDATE users 
            SET email_verified = true, updated_at = %s
            WHERE id = %s AND is_active = true
        """
        
        params = (datetime.now(timezone.utc), user_id)
        
        try:
            rows_affected = self.db.execute_query(query, params)
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error verifying email for user {user_id}: {e}")
            return False
    
    def list_users(self, limit: int = 50, offset: int = 0, include_inactive: bool = False) -> List[User]:
        """List users with pagination"""
        where_clause = "" if include_inactive else "WHERE is_active = true"
        query = f"""
            SELECT * FROM users 
            {where_clause}
            ORDER BY created_at DESC 
            LIMIT %s OFFSET %s
        """
        
        try:
            results = self.db.execute_query(query, (limit, offset), fetch_all=True)
            return [User(**dict(row)) for row in results] if results else []
        except Exception as e:
            logger.error(f"Error listing users: {e}")
            return []
    
    def count_users(self, include_inactive: bool = False) -> int:
        """Count total users"""
        where_clause = "" if include_inactive else "WHERE is_active = true"
        query = f"SELECT COUNT(*) as count FROM users {where_clause}"
        
        try:
            result = self.db.execute_query(query, fetch_one=True)
            return result['count'] if result else 0
        except Exception as e:
            logger.error(f"Error counting users: {e}")
            return 0
    
    def ensure_admin_exists(self) -> bool:
        """Ensure at least one admin user exists"""
        query = "SELECT COUNT(*) as count FROM users WHERE role = 'admin' AND is_active = true"
        
        try:
            result = self.db.execute_query(query, fetch_one=True)
            admin_count = result['count'] if result else 0
            
            if admin_count == 0:
                # Create default admin user
                admin_data = CreateUserRequest(
                    email="admin@echowright.com",
                    username="admin",
                    display_name="Administrator",
                    role=UserRole.ADMIN,
                    email_verified=True
                )
                
                admin_user = self.create_user(admin_data)
                logger.info(f"Created default admin user: {admin_user.email}")
                logger.warning("⚠️ Set up proper admin authentication in production!")
                return True
            
            return admin_count > 0
        except Exception as e:
            logger.error(f"Error ensuring admin exists: {e}")
            return False