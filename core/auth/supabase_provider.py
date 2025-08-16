"""
Supabase Authentication Provider

Handles authentication with Supabase (replacement for Azure AD B2C)
Supports Apple Sign In, Google OAuth, and email/password authentication.
Users never see or configure Supabase - it's completely abstracted.
"""

import os
import logging
import json
import time
from typing import Optional, Dict, Any, List
from datetime import datetime, timezone
from uuid import UUID, uuid4

import jwt
import httpx
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions
from postgrest.exceptions import APIError

from .models.user import (
    User, Identity, IdentityProvider, UserCreate, IdentityCreate
)

logger = logging.getLogger(__name__)


class SupabaseAuthError(Exception):
    """Custom exception for Supabase authentication errors"""
    pass


class SupabaseAuthProvider:
    """
    Supabase authentication provider - completely hidden from users
    
    Users only see:
    - "Sign in with Apple" 
    - "Sign in with Google"
    - "Sign up with email"
    
    We handle all Supabase configuration internally.
    """
    
    def __init__(self):
        """Initialize Supabase client with environment configuration"""
        self.url = os.getenv('SUPABASE_URL')
        self.anon_key = os.getenv('SUPABASE_ANON_KEY')  
        self.service_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
        
        if not all([self.url, self.anon_key, self.service_key]):
            raise SupabaseAuthError(
                "Missing Supabase configuration. Set SUPABASE_URL, "
                "SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY"
            )
        
        # Client for user operations (respects RLS)
        self.client: Client = create_client(
            self.url, 
            self.anon_key,
            options=ClientOptions(
                auto_refresh_token=True,
                persist_session=True
            )
        )
        
        # Admin client for service operations (bypasses RLS)
        self.admin_client: Client = create_client(
            self.url,
            self.service_key,
            options=ClientOptions(
                auto_refresh_token=False,
                persist_session=False
            )
        )
        
        # JWT verification setup
        self._jwks_cache = {}
        self._jwks_cache_time = 0
        self._jwks_cache_ttl = 3600  # 1 hour
        
        logger.info("Supabase auth provider initialized with proper JWT verification")
    
    async def sign_in_with_apple(
        self, 
        id_token: str, 
        nonce: str,
        user_info: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Handle Apple Sign In from iOS app
        
        Args:
            id_token: Apple ID token from iOS
            nonce: Nonce used in Apple sign in
            user_info: Optional user info from Apple (name, email)
        
        Returns:
            Dict with access_token, refresh_token, and user info
        """
        try:
            # Sign in with Supabase using Apple ID token
            response = await self.client.auth.sign_in_with_id_token({
                'provider': 'apple',
                'token': id_token,
                'nonce': nonce
            })
            
            if not response.user:
                raise SupabaseAuthError("Apple sign in failed")
            
            # Get or create user in our database
            user = await self._ensure_user_exists(
                provider=IdentityProvider.APPLE,
                provider_user_id=response.user.id,
                email=response.user.email,
                user_metadata=response.user.user_metadata or {},
                apple_user_info=user_info
            )
            
            logger.info(f"Apple sign in successful for user {user.id}")
            
            return {
                'access_token': response.session.access_token,
                'refresh_token': response.session.refresh_token,
                'expires_at': response.session.expires_at,
                'user': user.to_dict()
            }
            
        except Exception as e:
            logger.error(f"Apple sign in failed: {e}")
            raise SupabaseAuthError(f"Apple authentication failed: {str(e)}")
    
    async def sign_in_with_google(self, id_token: str) -> Dict[str, Any]:
        """
        Handle Google Sign In from web or mobile
        
        Args:
            id_token: Google ID token
            
        Returns:
            Dict with access_token, refresh_token, and user info
        """
        try:
            response = await self.client.auth.sign_in_with_id_token({
                'provider': 'google',
                'token': id_token
            })
            
            if not response.user:
                raise SupabaseAuthError("Google sign in failed")
            
            # Get or create user in our database
            user = await self._ensure_user_exists(
                provider=IdentityProvider.GOOGLE,
                provider_user_id=response.user.id,
                email=response.user.email,
                user_metadata=response.user.user_metadata or {}
            )
            
            logger.info(f"Google sign in successful for user {user.id}")
            
            return {
                'access_token': response.session.access_token,
                'refresh_token': response.session.refresh_token,
                'expires_at': response.session.expires_at,
                'user': user.to_dict()
            }
            
        except Exception as e:
            logger.error(f"Google sign in failed: {e}")
            raise SupabaseAuthError(f"Google authentication failed: {str(e)}")
    
    async def sign_up_with_email(
        self, 
        email: str, 
        password: str, 
        display_name: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Handle email/password sign up (web only)
        
        Args:
            email: User email
            password: User password (handled by Supabase, never stored by us)
            display_name: Optional display name
            
        Returns:
            Dict with access_token, refresh_token, and user info
        """
        try:
            response = await self.client.auth.sign_up({
                'email': email,
                'password': password,
                'options': {
                    'data': {
                        'display_name': display_name
                    }
                }
            })
            
            if not response.user:
                raise SupabaseAuthError("Email sign up failed")
            
            # Get or create user in our database
            user = await self._ensure_user_exists(
                provider=IdentityProvider.EMAIL,
                provider_user_id=response.user.id,
                email=email,
                user_metadata={'display_name': display_name}
            )
            
            logger.info(f"Email sign up successful for user {user.id}")
            
            return {
                'access_token': response.session.access_token if response.session else None,
                'refresh_token': response.session.refresh_token if response.session else None,
                'expires_at': response.session.expires_at if response.session else None,
                'user': user.to_dict(),
                'email_confirmation_sent': not response.session  # True if email confirmation needed
            }
            
        except Exception as e:
            logger.error(f"Email sign up failed: {e}")
            raise SupabaseAuthError(f"Email signup failed: {str(e)}")
    
    async def sign_in_with_email(self, email: str, password: str) -> Dict[str, Any]:
        """
        Handle email/password sign in (web only)
        
        Args:
            email: User email  
            password: User password
            
        Returns:
            Dict with access_token, refresh_token, and user info
        """
        try:
            response = await self.client.auth.sign_in_with_password({
                'email': email,
                'password': password
            })
            
            if not response.user or not response.session:
                raise SupabaseAuthError("Invalid email or password")
            
            # Get user from our database
            user = await self._get_user_by_provider_id(
                IdentityProvider.EMAIL,
                response.user.id
            )
            
            if not user:
                # Create user if doesn't exist (shouldn't happen normally)
                user = await self._ensure_user_exists(
                    provider=IdentityProvider.EMAIL,
                    provider_user_id=response.user.id,
                    email=email,
                    user_metadata=response.user.user_metadata or {}
                )
            
            logger.info(f"Email sign in successful for user {user.id}")
            
            return {
                'access_token': response.session.access_token,
                'refresh_token': response.session.refresh_token,
                'expires_at': response.session.expires_at,
                'user': user.to_dict()
            }
            
        except Exception as e:
            logger.error(f"Email sign in failed: {e}")
            raise SupabaseAuthError(f"Email authentication failed: {str(e)}")
    
    async def refresh_token(self, refresh_token: str) -> Dict[str, Any]:
        """
        Refresh access token using refresh token
        
        Args:
            refresh_token: Valid refresh token
            
        Returns:
            Dict with new access_token and refresh_token
        """
        try:
            response = await self.client.auth.refresh_session(refresh_token)
            
            if not response.session:
                raise SupabaseAuthError("Token refresh failed")
            
            logger.info("Token refresh successful")
            
            return {
                'access_token': response.session.access_token,
                'refresh_token': response.session.refresh_token,
                'expires_at': response.session.expires_at
            }
            
        except Exception as e:
            logger.error(f"Token refresh failed: {e}")
            raise SupabaseAuthError(f"Token refresh failed: {str(e)}")
    
    async def verify_token(self, access_token: str) -> Dict[str, Any]:
        """
        Verify and decode access token using proper JWT verification
        
        SECURITY: This now properly verifies Supabase JWTs using JWKS
        instead of trusting opaque tokens.
        
        Args:
            access_token: JWT access token
            
        Returns:
            Dict with user info and token claims
        """
        try:
            # Verify JWT using Supabase's JWKS (proper cryptographic verification)
            jwt_payload = await self._verify_supabase_jwt(access_token)
            
            if not jwt_payload or not jwt_payload.get('sub'):
                raise SupabaseAuthError("Invalid token payload")
            
            supabase_user_id = jwt_payload['sub']
            
            # Get user from our database using service role key
            # Try to find by any provider
            user = None
            for provider in IdentityProvider:
                user = await self._get_user_by_provider_id(provider, supabase_user_id)
                if user:
                    break
            
            if not user:
                raise SupabaseAuthError("User not found")
            
            return {
                'user': user.to_dict(),
                'supabase_user_id': supabase_user_id,
                'email': jwt_payload.get('email'),
                'provider': jwt_payload.get('app_metadata', {}).get('provider', 'email'),
                'jwt_claims': jwt_payload
            }
            
        except Exception as e:
            logger.error(f"Token verification failed: {e}")
            raise SupabaseAuthError(f"Token verification failed: {str(e)}")
    
    async def link_identity(
        self, 
        user_id: UUID, 
        provider: IdentityProvider,
        id_token: str
    ) -> Identity:
        """
        Link additional identity provider to existing user
        
        Args:
            user_id: Existing user ID
            provider: Identity provider to link
            id_token: Provider ID token
            
        Returns:
            New Identity record
        """
        try:
            # This would need implementation based on provider
            # For now, raise not implemented
            raise NotImplementedError("Identity linking not yet implemented")
            
        except Exception as e:
            logger.error(f"Identity linking failed: {e}")
            raise SupabaseAuthError(f"Identity linking failed: {str(e)}")
    
    async def delete_user(self, user_id: UUID) -> bool:
        """
        Delete user account (GDPR compliance)
        
        Args:
            user_id: User ID to delete
            
        Returns:
            True if successful
        """
        try:
            # Soft delete in our database
            await self.admin_client.table('users').update({
                'deleted_at': datetime.now(timezone.utc).isoformat()
            }).eq('id', str(user_id)).execute()
            
            # Note: Supabase user deletion would need admin API
            # For now, we just soft delete our user record
            
            logger.info(f"User {user_id} deleted successfully")
            return True
            
        except Exception as e:
            logger.error(f"User deletion failed: {e}")
            raise SupabaseAuthError(f"User deletion failed: {str(e)}")
    
    # =====================================================
    # PRIVATE HELPER METHODS
    # =====================================================
    
    async def _ensure_user_exists(
        self,
        provider: IdentityProvider,
        provider_user_id: str,
        email: Optional[str],
        user_metadata: Dict[str, Any],
        apple_user_info: Optional[Dict[str, Any]] = None
    ) -> User:
        """
        Get existing user or create new one
        
        This is called after successful authentication with provider.
        Users never see this process.
        """
        try:
            # Check if identity already exists
            existing_user = await self._get_user_by_provider_id(provider, provider_user_id)
            if existing_user:
                return existing_user
            
            # Extract display name from various sources
            display_name = None
            if apple_user_info and 'name' in apple_user_info:
                # Apple provides name in separate user_info
                name_parts = apple_user_info['name']
                if isinstance(name_parts, dict):
                    first_name = name_parts.get('firstName', '')
                    last_name = name_parts.get('lastName', '')
                    display_name = f"{first_name} {last_name}".strip()
            elif 'display_name' in user_metadata:
                display_name = user_metadata['display_name']
            elif 'full_name' in user_metadata:
                display_name = user_metadata['full_name']
            elif 'name' in user_metadata:
                display_name = user_metadata['name']
            
            # Create new user
            user_data = {
                'id': str(uuid4()),
                'email': email,
                'display_name': display_name,
                'created_at': datetime.now(timezone.utc).isoformat(),
                'updated_at': datetime.now(timezone.utc).isoformat()
            }
            
            user_result = await self.admin_client.table('users').insert(user_data).execute()
            
            if not user_result.data:
                raise SupabaseAuthError("Failed to create user")
            
            user_record = user_result.data[0]
            
            # Create identity link
            identity_data = {
                'id': str(uuid4()),
                'user_id': user_record['id'],
                'provider': provider.value,
                'provider_user_id': provider_user_id,
                'email_at_auth': email,
                'verified': True,  # Assume verified since they authenticated
                'created_at': datetime.now(timezone.utc).isoformat(),
                'updated_at': datetime.now(timezone.utc).isoformat()
            }
            
            await self.admin_client.table('identities').insert(identity_data).execute()
            
            # Create default user preferences
            prefs_data = {
                'user_id': user_record['id'],
                'created_at': datetime.now(timezone.utc).isoformat(),
                'updated_at': datetime.now(timezone.utc).isoformat()
            }
            
            await self.admin_client.table('user_preferences').insert(prefs_data).execute()
            
            logger.info(f"Created new user {user_record['id']} with {provider.value} identity")
            
            return User(
                id=UUID(user_record['id']),
                email=user_record['email'],
                display_name=user_record['display_name'],
                avatar_url=user_record['avatar_url'],
                created_at=datetime.fromisoformat(user_record['created_at'].replace('Z', '+00:00')),
                updated_at=datetime.fromisoformat(user_record['updated_at'].replace('Z', '+00:00'))
            )
            
        except Exception as e:
            logger.error(f"Failed to ensure user exists: {e}")
            raise SupabaseAuthError(f"User creation failed: {str(e)}")
    
    async def _get_user_by_provider_id(
        self, 
        provider: IdentityProvider, 
        provider_user_id: str
    ) -> Optional[User]:
        """Get user by provider and provider user ID"""
        try:
            # Get identity
            identity_result = await self.admin_client.table('identities').select(
                'user_id'
            ).eq('provider', provider.value).eq('provider_user_id', provider_user_id).execute()
            
            if not identity_result.data:
                return None
            
            user_id = identity_result.data[0]['user_id']
            
            # Get user
            user_result = await self.admin_client.table('users').select('*').eq(
                'id', user_id
            ).is_('deleted_at', 'null').execute()
            
            if not user_result.data:
                return None
            
            user_data = user_result.data[0]
            
            return User(
                id=UUID(user_data['id']),
                email=user_data['email'],
                display_name=user_data['display_name'],
                avatar_url=user_data['avatar_url'],
                created_at=datetime.fromisoformat(user_data['created_at'].replace('Z', '+00:00')),
                updated_at=datetime.fromisoformat(user_data['updated_at'].replace('Z', '+00:00'))
            )
            
        except Exception as e:
            logger.error(f"Failed to get user by provider ID: {e}")
            return None
    
    async def _verify_supabase_jwt(self, token: str) -> Dict[str, Any]:
        """
        Verify Supabase JWT using proper JWKS verification
        
        SECURITY FIX: This implements proper JWT verification instead of 
        trusting opaque tokens. Uses Supabase's public keys to verify signatures.
        """
        try:
            # Get unverified header to extract kid
            header = jwt.get_unverified_header(token)
            kid = header.get('kid')
            
            if not kid:
                raise SupabaseAuthError("Missing key ID in JWT header")
            
            # Get verification key from JWKS
            verification_key = await self._get_supabase_public_key(kid)
            
            # Verify JWT with proper checks
            payload = jwt.decode(
                token,
                key=verification_key,
                algorithms=['RS256'],
                audience='authenticated',  # Supabase audience
                issuer=f'{self.url}/auth/v1',  # Supabase issuer
                options={
                    'verify_signature': True,
                    'verify_exp': True,
                    'verify_iat': True,
                    'verify_iss': True,
                    'verify_aud': True,
                    'require': ['exp', 'iat', 'iss', 'aud', 'sub']
                }
            )
            
            return payload
            
        except jwt.InvalidTokenError as e:
            logger.error(f"JWT verification failed: {e}")
            raise SupabaseAuthError(f"Invalid JWT: {str(e)}")
        except Exception as e:
            logger.error(f"JWT verification error: {e}")
            raise SupabaseAuthError(f"JWT verification failed: {str(e)}")
    
    async def _get_supabase_public_key(self, kid: str) -> Any:
        """
        Get Supabase public key for JWT verification
        
        SECURITY: Fetches and caches Supabase's public keys from JWKS endpoint
        """
        # Check cache first
        if self._is_jwks_cache_valid() and kid in self._jwks_cache:
            return self._jwks_cache[kid]
        
        # Fetch fresh JWKS
        await self._refresh_supabase_jwks()
        
        if kid not in self._jwks_cache:
            raise SupabaseAuthError(f"Key ID {kid} not found in Supabase JWKS")
        
        return self._jwks_cache[kid]
    
    async def _refresh_supabase_jwks(self):
        """Fetch and cache Supabase JWKS keys"""
        try:
            jwks_url = f'{self.url}/auth/v1/jwks'
            
            async with httpx.AsyncClient() as client:
                response = await client.get(jwks_url, timeout=10.0)
                response.raise_for_status()
                jwks = response.json()
            
            # Parse and cache keys
            self._jwks_cache = {}
            for key_data in jwks.get('keys', []):
                kid = key_data.get('kid')
                if kid:
                    # Convert JWK to public key
                    public_key = self._jwk_to_public_key(key_data)
                    self._jwks_cache[kid] = public_key
            
            self._jwks_cache_time = time.time()
            logger.info(f"Cached {len(self._jwks_cache)} Supabase public keys")
            
        except Exception as e:
            logger.error(f"Failed to fetch Supabase JWKS: {e}")
            raise SupabaseAuthError(f"Could not fetch Supabase public keys: {e}")
    
    def _jwk_to_public_key(self, jwk: Dict[str, Any]) -> Any:
        """Convert JWK to cryptography public key object"""
        try:
            # Supabase typically uses RSA keys
            if jwk.get('kty') != 'RSA':
                raise ValueError(f"Unsupported key type: {jwk.get('kty')}")
            
            # Decode RSA components
            import base64
            n_bytes = base64.urlsafe_b64decode(jwk['n'] + '===')
            e_bytes = base64.urlsafe_b64decode(jwk['e'] + '===')
            
            # Create RSA public key
            n = int.from_bytes(n_bytes, 'big')
            e = int.from_bytes(e_bytes, 'big')
            
            public_key = rsa.RSAPublicNumbers(e, n).public_key()
            
            return public_key
            
        except Exception as e:
            logger.error(f"Failed to parse JWK: {e}")
            raise SupabaseAuthError(f"Could not parse JWK: {e}")
    
    def _is_jwks_cache_valid(self) -> bool:
        """Check if JWKS cache is still valid"""
        return (time.time() - self._jwks_cache_time) < self._jwks_cache_ttl
    
    async def revoke_token(self, refresh_token: str) -> bool:
        """
        Revoke refresh token (for logout)
        
        SECURITY: Implements proper token revocation for logout
        
        Args:
            refresh_token: Refresh token to revoke
            
        Returns:
            True if successful
        """
        try:
            # Use admin client to revoke token
            await self.admin_client.auth.sign_out(refresh_token)
            logger.info("Token revoked successfully")
            return True
            
        except Exception as e:
            logger.error(f"Token revocation failed: {e}")
            return False


# =====================================================
# CONVENIENCE FUNCTIONS
# =====================================================

# Global provider instance
_provider = None

def get_auth_provider() -> SupabaseAuthProvider:
    """Get global auth provider instance"""
    global _provider
    if _provider is None:
        _provider = SupabaseAuthProvider()
    return _provider


async def authenticate_apple_user(id_token: str, nonce: str, user_info: Optional[Dict] = None) -> Dict[str, Any]:
    """Convenience function for Apple authentication"""
    provider = get_auth_provider()
    return await provider.sign_in_with_apple(id_token, nonce, user_info)


async def authenticate_google_user(id_token: str) -> Dict[str, Any]:
    """Convenience function for Google authentication"""
    provider = get_auth_provider()
    return await provider.sign_in_with_google(id_token)


async def authenticate_email_user(email: str, password: str) -> Dict[str, Any]:
    """Convenience function for email authentication"""
    provider = get_auth_provider()
    return await provider.sign_in_with_email(email, password)


async def verify_user_token(access_token: str) -> Dict[str, Any]:
    """Convenience function for token verification"""
    provider = get_auth_provider()
    return await provider.verify_token(access_token)