"""
Identity Model for Multi-Provider Authentication

Manages authentication identities from multiple providers (Google, Apple, email/password).
Allows users to link multiple authentication methods to a single account.
"""

import logging
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
from uuid import UUID, uuid4
from pydantic import BaseModel
from enum import Enum

from ..connection import get_database_manager

logger = logging.getLogger(__name__)

class ProviderType(Enum):
    """Authentication provider types"""
    EMAIL = "email"
    GOOGLE = "google"
    APPLE = "apple"

class Identity(BaseModel):
    """Identity model for authentication providers"""
    id: UUID
    user_id: UUID
    provider: ProviderType
    provider_id: str  # Provider-specific user ID
    provider_email: Optional[str] = None  # Email from provider
    provider_data: Dict[str, Any] = {}  # Additional provider data
    is_verified: bool = False
    is_primary: bool = False  # Primary authentication method
    created_at: datetime
    updated_at: datetime
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: str
        }

class CreateIdentityRequest(BaseModel):
    """Request model for creating new identities"""
    user_id: UUID
    provider: ProviderType
    provider_id: str
    provider_email: Optional[str] = None
    provider_data: Dict[str, Any] = {}
    is_verified: bool = False
    is_primary: bool = False

class UpdateIdentityRequest(BaseModel):
    """Request model for updating identities"""
    provider_email: Optional[str] = None
    provider_data: Optional[Dict[str, Any]] = None
    is_verified: Optional[bool] = None
    is_primary: Optional[bool] = None

class PasswordCredential(BaseModel):
    """Password credential for email authentication"""
    id: UUID
    user_id: UUID
    password_hash: str
    salt: str
    created_at: datetime
    updated_at: datetime
    last_used: Optional[datetime] = None

class IdentityModel:
    """Database operations for authentication identities"""
    
    def __init__(self):
        self.db = get_database_manager()
    
    def create_identity(self, identity_data: CreateIdentityRequest) -> Identity:
        """Create a new authentication identity"""
        identity_id = uuid4()
        now = datetime.now(timezone.utc)
        
        # If this is being set as primary, unset other primary identities for this user
        if identity_data.is_primary:
            self._unset_primary_identities(identity_data.user_id)
        
        query = """
            INSERT INTO identities (
                id, user_id, provider, provider_id, provider_email,
                provider_data, is_verified, is_primary, created_at, updated_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            ) RETURNING *
        """
        
        params = (
            identity_id,
            identity_data.user_id,
            identity_data.provider.value,
            identity_data.provider_id,
            identity_data.provider_email,
            identity_data.provider_data,
            identity_data.is_verified,
            identity_data.is_primary,
            now,
            now
        )
        
        try:
            result = self.db.execute_query(query, params, fetch_one=True)
            if result:
                return Identity(**dict(result))
            else:
                raise Exception("Failed to create identity")
        except Exception as e:
            logger.error(f"Error creating identity: {e}")
            raise
    
    def get_identity_by_provider(self, provider: ProviderType, provider_id: str) -> Optional[Identity]:
        """Get identity by provider and provider ID"""
        query = """
            SELECT * FROM identities 
            WHERE provider = %s AND provider_id = %s
        """
        
        try:
            result = self.db.execute_query(query, (provider.value, provider_id), fetch_one=True)
            if result:
                return Identity(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error fetching identity for {provider.value}:{provider_id}: {e}")
            return None
    
    def get_identities_by_user(self, user_id: UUID) -> List[Identity]:
        """Get all identities for a user"""
        query = """
            SELECT * FROM identities 
            WHERE user_id = %s 
            ORDER BY is_primary DESC, created_at ASC
        """
        
        try:
            results = self.db.execute_query(query, (user_id,), fetch_all=True)
            return [Identity(**dict(row)) for row in results] if results else []
        except Exception as e:
            logger.error(f"Error fetching identities for user {user_id}: {e}")
            return []
    
    def get_primary_identity(self, user_id: UUID) -> Optional[Identity]:
        """Get the primary identity for a user"""
        query = """
            SELECT * FROM identities 
            WHERE user_id = %s AND is_primary = true
        """
        
        try:
            result = self.db.execute_query(query, (user_id,), fetch_one=True)
            if result:
                return Identity(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error fetching primary identity for user {user_id}: {e}")
            return None
    
    def update_identity(self, identity_id: UUID, updates: UpdateIdentityRequest) -> Optional[Identity]:
        """Update identity information"""
        # Build dynamic update query
        update_fields = []
        params = []
        
        for field, value in updates.dict(exclude_unset=True).items():
            if field == 'provider_data' and value is not None:
                update_fields.append("provider_data = provider_data || %s::jsonb")
            else:
                update_fields.append(f"{field} = %s")
            params.append(value)
        
        if not update_fields:
            query = "SELECT * FROM identities WHERE id = %s"
            result = self.db.execute_query(query, (identity_id,), fetch_one=True)
            return Identity(**dict(result)) if result else None
        
        # If setting as primary, unset other primary identities
        if updates.is_primary:
            identity = self.get_identity_by_id(identity_id)
            if identity:
                self._unset_primary_identities(identity.user_id)
        
        # Add updated_at timestamp
        update_fields.append("updated_at = %s")
        params.append(datetime.now(timezone.utc))
        params.append(identity_id)  # For WHERE clause
        
        query = f"""
            UPDATE identities 
            SET {', '.join(update_fields)}
            WHERE id = %s
            RETURNING *
        """
        
        try:
            result = self.db.execute_query(query, tuple(params), fetch_one=True)
            if result:
                return Identity(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error updating identity {identity_id}: {e}")
            return None
    
    def get_identity_by_id(self, identity_id: UUID) -> Optional[Identity]:
        """Get identity by ID"""
        query = "SELECT * FROM identities WHERE id = %s"
        
        try:
            result = self.db.execute_query(query, (identity_id,), fetch_one=True)
            if result:
                return Identity(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error fetching identity {identity_id}: {e}")
            return None
    
    def delete_identity(self, identity_id: UUID) -> bool:
        """Delete an identity"""
        query = "DELETE FROM identities WHERE id = %s"
        
        try:
            rows_affected = self.db.execute_query(query, (identity_id,))
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error deleting identity {identity_id}: {e}")
            return False
    
    def verify_identity(self, identity_id: UUID) -> bool:
        """Mark identity as verified"""
        query = """
            UPDATE identities 
            SET is_verified = true, updated_at = %s
            WHERE id = %s
        """
        
        params = (datetime.now(timezone.utc), identity_id)
        
        try:
            rows_affected = self.db.execute_query(query, params)
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error verifying identity {identity_id}: {e}")
            return False
    
    def set_primary_identity(self, identity_id: UUID) -> bool:
        """Set an identity as the primary authentication method"""
        # First get the identity to find the user
        identity = self.get_identity_by_id(identity_id)
        if not identity:
            return False
        
        # Unset all other primary identities for this user
        self._unset_primary_identities(identity.user_id)
        
        # Set this identity as primary
        query = """
            UPDATE identities 
            SET is_primary = true, updated_at = %s
            WHERE id = %s
        """
        
        params = (datetime.now(timezone.utc), identity_id)
        
        try:
            rows_affected = self.db.execute_query(query, params)
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error setting primary identity {identity_id}: {e}")
            return False
    
    def _unset_primary_identities(self, user_id: UUID) -> None:
        """Unset all primary identities for a user"""
        query = """
            UPDATE identities 
            SET is_primary = false, updated_at = %s
            WHERE user_id = %s AND is_primary = true
        """
        
        params = (datetime.now(timezone.utc), user_id)
        
        try:
            self.db.execute_query(query, params)
        except Exception as e:
            logger.error(f"Error unsetting primary identities for user {user_id}: {e}")
    
    def link_providers(self, user_id: UUID, provider: ProviderType, provider_id: str, provider_email: Optional[str] = None) -> Identity:
        """Link a new authentication provider to an existing user"""
        # Check if this provider is already linked
        existing = self.get_identity_by_provider(provider, provider_id)
        if existing:
            if existing.user_id != user_id:
                raise ValueError(f"Provider {provider.value}:{provider_id} is already linked to a different user")
            return existing
        
        # Create new identity
        identity_data = CreateIdentityRequest(
            user_id=user_id,
            provider=provider,
            provider_id=provider_id,
            provider_email=provider_email,
            is_verified=True,  # OAuth providers are typically pre-verified
            is_primary=False   # Don't override existing primary
        )
        
        return self.create_identity(identity_data)
    
    # Password credential management for email authentication
    def create_password_credential(self, user_id: UUID, password_hash: str, salt: str) -> PasswordCredential:
        """Create password credentials for email authentication"""
        credential_id = uuid4()
        now = datetime.now(timezone.utc)
        
        query = """
            INSERT INTO password_credentials (
                id, user_id, password_hash, salt, created_at, updated_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s
            ) RETURNING *
        """
        
        params = (credential_id, user_id, password_hash, salt, now, now)
        
        try:
            result = self.db.execute_query(query, params, fetch_one=True)
            if result:
                return PasswordCredential(**dict(result))
            else:
                raise Exception("Failed to create password credential")
        except Exception as e:
            logger.error(f"Error creating password credential: {e}")
            raise
    
    def get_password_credential(self, user_id: UUID) -> Optional[PasswordCredential]:
        """Get password credentials for a user"""
        query = """
            SELECT * FROM password_credentials 
            WHERE user_id = %s
            ORDER BY created_at DESC
            LIMIT 1
        """
        
        try:
            result = self.db.execute_query(query, (user_id,), fetch_one=True)
            if result:
                return PasswordCredential(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error fetching password credential for user {user_id}: {e}")
            return None
    
    def update_password_credential(self, user_id: UUID, password_hash: str, salt: str) -> bool:
        """Update password credentials for a user"""
        query = """
            UPDATE password_credentials 
            SET password_hash = %s, salt = %s, updated_at = %s
            WHERE user_id = %s
        """
        
        params = (password_hash, salt, datetime.now(timezone.utc), user_id)
        
        try:
            rows_affected = self.db.execute_query(query, params)
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error updating password credential for user {user_id}: {e}")
            return False
    
    def update_password_last_used(self, user_id: UUID) -> bool:
        """Update last used timestamp for password credential"""
        query = """
            UPDATE password_credentials 
            SET last_used = %s, updated_at = %s
            WHERE user_id = %s
        """
        
        params = (datetime.now(timezone.utc), datetime.now(timezone.utc), user_id)
        
        try:
            rows_affected = self.db.execute_query(query, params)
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error updating password last used for user {user_id}: {e}")
            return False