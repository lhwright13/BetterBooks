"""
Session Model for JWT Token Management

Manages user sessions and JWT tokens with database persistence.
Provides token blacklisting and session validation.
"""

import logging
from typing import Optional, List
from datetime import datetime, timezone, timedelta
from uuid import UUID, uuid4
from pydantic import BaseModel

from ..connection import get_database_manager

logger = logging.getLogger(__name__)

class Session(BaseModel):
    """Session model for JWT token management"""
    id: UUID
    user_id: UUID
    token_hash: str  # Hash of the JWT token for security
    token_type: str  # 'access' or 'refresh'
    expires_at: datetime
    created_at: datetime
    last_used: Optional[datetime] = None
    user_agent: Optional[str] = None
    ip_address: Optional[str] = None
    is_revoked: bool = False
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            UUID: str
        }

class CreateSessionRequest(BaseModel):
    """Request model for creating new sessions"""
    user_id: UUID
    token_hash: str
    token_type: str = "access"
    expires_at: datetime
    user_agent: Optional[str] = None
    ip_address: Optional[str] = None

class SessionModel:
    """Database operations for user sessions"""
    
    def __init__(self):
        self.db = get_database_manager()
    
    def create_session(self, session_data: CreateSessionRequest) -> Session:
        """Create a new session"""
        session_id = uuid4()
        now = datetime.now(timezone.utc)
        
        query = """
            INSERT INTO sessions (
                id, user_id, token_hash, token_type, expires_at,
                created_at, user_agent, ip_address, is_revoked
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s
            ) RETURNING *
        """
        
        params = (
            session_id,
            session_data.user_id,
            session_data.token_hash,
            session_data.token_type,
            session_data.expires_at,
            now,
            session_data.user_agent,
            session_data.ip_address,
            False
        )
        
        try:
            result = self.db.execute_query(query, params, fetch_one=True)
            if result:
                return Session(**dict(result))
            else:
                raise Exception("Failed to create session")
        except Exception as e:
            logger.error(f"Error creating session: {e}")
            raise
    
    def get_session_by_token_hash(self, token_hash: str) -> Optional[Session]:
        """Get session by token hash"""
        query = """
            SELECT * FROM sessions 
            WHERE token_hash = %s AND is_revoked = false
        """
        
        try:
            result = self.db.execute_query(query, (token_hash,), fetch_one=True)
            if result:
                return Session(**dict(result))
            return None
        except Exception as e:
            logger.error(f"Error fetching session by token hash: {e}")
            return None
    
    def get_sessions_by_user(self, user_id: UUID, active_only: bool = True) -> List[Session]:
        """Get all sessions for a user"""
        where_clause = "WHERE user_id = %s"
        params = [user_id]
        
        if active_only:
            where_clause += " AND is_revoked = false AND expires_at > %s"
            params.append(datetime.now(timezone.utc))
        
        query = f"""
            SELECT * FROM sessions 
            {where_clause}
            ORDER BY created_at DESC
        """
        
        try:
            results = self.db.execute_query(query, tuple(params), fetch_all=True)
            return [Session(**dict(row)) for row in results] if results else []
        except Exception as e:
            logger.error(f"Error fetching sessions for user {user_id}: {e}")
            return []
    
    def validate_session(self, token_hash: str) -> Optional[Session]:
        """Validate a session and update last_used"""
        session = self.get_session_by_token_hash(token_hash)
        
        if not session:
            return None
        
        # Check if session is expired
        if session.expires_at <= datetime.now(timezone.utc):
            self.revoke_session(session.id)
            return None
        
        # Update last_used timestamp
        self.update_session_last_used(session.id)
        
        return session
    
    def update_session_last_used(self, session_id: UUID) -> bool:
        """Update session's last used timestamp"""
        query = """
            UPDATE sessions 
            SET last_used = %s
            WHERE id = %s AND is_revoked = false
        """
        
        params = (datetime.now(timezone.utc), session_id)
        
        try:
            rows_affected = self.db.execute_query(query, params)
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error updating session last used {session_id}: {e}")
            return False
    
    def revoke_session(self, session_id: UUID) -> bool:
        """Revoke a specific session"""
        query = """
            UPDATE sessions 
            SET is_revoked = true
            WHERE id = %s
        """
        
        try:
            rows_affected = self.db.execute_query(query, (session_id,))
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error revoking session {session_id}: {e}")
            return False
    
    def revoke_session_by_token_hash(self, token_hash: str) -> bool:
        """Revoke session by token hash (for logout)"""
        query = """
            UPDATE sessions 
            SET is_revoked = true
            WHERE token_hash = %s AND is_revoked = false
        """
        
        try:
            rows_affected = self.db.execute_query(query, (token_hash,))
            return rows_affected > 0
        except Exception as e:
            logger.error(f"Error revoking session by token hash: {e}")
            return False
    
    def revoke_user_sessions(self, user_id: UUID, except_session_id: Optional[UUID] = None) -> int:
        """Revoke all sessions for a user (except optionally one)"""
        query = """
            UPDATE sessions 
            SET is_revoked = true
            WHERE user_id = %s AND is_revoked = false
        """
        params = [user_id]
        
        if except_session_id:
            query += " AND id != %s"
            params.append(except_session_id)
        
        try:
            rows_affected = self.db.execute_query(query, tuple(params))
            return rows_affected or 0
        except Exception as e:
            logger.error(f"Error revoking user sessions for {user_id}: {e}")
            return 0
    
    def cleanup_expired_sessions(self) -> int:
        """Clean up expired sessions from database"""
        query = """
            DELETE FROM sessions 
            WHERE expires_at < %s OR is_revoked = true
        """
        
        cutoff = datetime.now(timezone.utc) - timedelta(days=30)  # Keep revoked sessions for 30 days
        
        try:
            rows_affected = self.db.execute_query(query, (cutoff,))
            logger.info(f"Cleaned up {rows_affected} expired sessions")
            return rows_affected or 0
        except Exception as e:
            logger.error(f"Error cleaning up expired sessions: {e}")
            return 0
    
    def get_active_session_count(self, user_id: UUID) -> int:
        """Get count of active sessions for a user"""
        query = """
            SELECT COUNT(*) as count FROM sessions 
            WHERE user_id = %s AND is_revoked = false AND expires_at > %s
        """
        
        params = (user_id, datetime.now(timezone.utc))
        
        try:
            result = self.db.execute_query(query, params, fetch_one=True)
            return result['count'] if result else 0
        except Exception as e:
            logger.error(f"Error counting active sessions for user {user_id}: {e}")
            return 0
    
    def create_access_and_refresh_sessions(
        self, 
        user_id: UUID, 
        access_token_hash: str, 
        refresh_token_hash: str,
        access_expires_at: datetime,
        refresh_expires_at: datetime,
        user_agent: Optional[str] = None,
        ip_address: Optional[str] = None
    ) -> tuple[Session, Session]:
        """Create both access and refresh token sessions atomically"""
        
        # Create access token session
        access_session_data = CreateSessionRequest(
            user_id=user_id,
            token_hash=access_token_hash,
            token_type="access",
            expires_at=access_expires_at,
            user_agent=user_agent,
            ip_address=ip_address
        )
        
        # Create refresh token session  
        refresh_session_data = CreateSessionRequest(
            user_id=user_id,
            token_hash=refresh_token_hash,
            token_type="refresh",
            expires_at=refresh_expires_at,
            user_agent=user_agent,
            ip_address=ip_address
        )
        
        try:
            access_session = self.create_session(access_session_data)
            refresh_session = self.create_session(refresh_session_data)
            
            return access_session, refresh_session
        except Exception as e:
            logger.error(f"Error creating access and refresh sessions: {e}")
            raise
    
    def refresh_access_token(
        self, 
        refresh_token_hash: str, 
        new_access_token_hash: str,
        new_access_expires_at: datetime
    ) -> Optional[Session]:
        """Create new access token session using refresh token"""
        
        # Validate refresh token
        refresh_session = self.validate_session(refresh_token_hash)
        if not refresh_session or refresh_session.token_type != "refresh":
            return None
        
        # Create new access token session
        access_session_data = CreateSessionRequest(
            user_id=refresh_session.user_id,
            token_hash=new_access_token_hash,
            token_type="access",
            expires_at=new_access_expires_at,
            user_agent=refresh_session.user_agent,
            ip_address=refresh_session.ip_address
        )
        
        try:
            return self.create_session(access_session_data)
        except Exception as e:
            logger.error(f"Error refreshing access token: {e}")
            return None