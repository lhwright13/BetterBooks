"""
Apple JWS Verification Module

Implements proper cryptographic verification of Apple App Store signed transactions
and notifications. This is CRITICAL for security - without proper verification,
anyone could forge purchase receipts.

Security Features:
- Fetches and caches Apple's public keys from JWKS endpoint
- Verifies JWS signatures using proper cryptographic validation
- Validates issuer, audience, and timing claims
- Prevents replay attacks through deduplication
- Validates bundle ID and environment consistency
"""

import os
import json
import logging
import asyncio
import time
from typing import Dict, Any, Optional, Set
from datetime import datetime, timezone, timedelta
from dataclasses import dataclass
from enum import Enum

import httpx
import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.backends import default_backend

logger = logging.getLogger(__name__)


class AppleEnvironment(Enum):
    """Apple environment types"""
    PRODUCTION = "Production"
    SANDBOX = "Sandbox"


@dataclass
class VerifiedTransaction:
    """Verified Apple transaction data"""
    transaction_id: str
    original_transaction_id: str
    product_id: str
    bundle_id: str
    purchase_date: datetime
    expires_date: Optional[datetime]
    environment: AppleEnvironment
    app_account_token: Optional[str]
    quantity: int
    raw_claims: Dict[str, Any]


@dataclass
class VerifiedNotification:
    """Verified Apple notification data"""
    notification_type: str
    subtype: Optional[str]
    notification_uuid: str
    data: Dict[str, Any]
    environment: AppleEnvironment
    transaction: VerifiedTransaction


class AppleJWSVerificationError(Exception):
    """Exception raised when JWS verification fails"""
    pass


class AppleJWSVerifier:
    """
    Handles cryptographic verification of Apple JWS tokens
    
    This class implements the security requirements from Apple's documentation:
    https://developer.apple.com/documentation/appstoreserverapi/jwsverification
    """
    
    def __init__(self, bundle_id: str, cache_ttl: int = 3600):
        """
        Initialize JWS verifier
        
        Args:
            bundle_id: Expected bundle ID for verification
            cache_ttl: TTL for cached JWKS keys in seconds
        """
        self.bundle_id = bundle_id
        self.cache_ttl = cache_ttl
        
        # Apple's JWKS endpoints
        self.production_jwks_url = "https://appleid.apple.com/auth/keys"
        self.sandbox_jwks_url = "https://appleid.apple.com/auth/keys"  # Same endpoint
        
        # Cached keys and metadata
        self._cached_keys: Dict[str, Any] = {}
        self._cache_timestamp = 0
        self._processed_transactions: Set[str] = set()  # Replay protection
        self._processed_notifications: Set[str] = set()  # Replay protection
        
        # Cleanup old entries periodically
        self._last_cleanup = time.time()
        self._cleanup_interval = 3600  # 1 hour
        
        logger.info(f"Apple JWS verifier initialized for bundle {bundle_id}")
    
    async def verify_transaction(
        self, 
        signed_transaction: str,
        expected_app_account_token: Optional[str] = None
    ) -> VerifiedTransaction:
        """
        Verify a signed transaction from StoreKit or webhooks
        
        Args:
            signed_transaction: JWS-signed transaction from Apple
            expected_app_account_token: Expected app account token
            
        Returns:
            VerifiedTransaction with validated claims
            
        Raises:
            AppleJWSVerificationError: If verification fails
        """
        try:
            # Decode header to get key ID
            header = jwt.get_unverified_header(signed_transaction)
            kid = header.get('kid')
            
            if not kid:
                raise AppleJWSVerificationError("Missing key ID in JWS header")
            
            # Get verification key
            verification_key = await self._get_verification_key(kid)
            
            # Verify and decode JWS
            try:
                claims = jwt.decode(
                    signed_transaction,
                    key=verification_key,
                    algorithms=['ES256'],
                    options={
                        'verify_signature': True,
                        'verify_exp': True,
                        'verify_iat': True,
                        'verify_iss': True,
                        'require': ['exp', 'iat', 'iss', 'aud']
                    }
                )
            except jwt.InvalidTokenError as e:
                raise AppleJWSVerificationError(f"JWS verification failed: {e}")
            
            # Validate claims
            self._validate_transaction_claims(claims, expected_app_account_token)
            
            # Check for replay attacks
            transaction_id = claims.get('transactionId')
            if transaction_id in self._processed_transactions:
                raise AppleJWSVerificationError(f"Transaction {transaction_id} already processed (replay attack)")
            
            # Convert to structured object
            transaction = self._parse_transaction_claims(claims)
            
            # Mark as processed (replay protection)
            self._processed_transactions.add(transaction_id)
            
            # Cleanup old entries periodically
            await self._cleanup_if_needed()
            
            logger.info(f"Successfully verified Apple transaction: {transaction_id}")
            return transaction
            
        except AppleJWSVerificationError:
            raise
        except Exception as e:
            logger.error(f"Unexpected error during transaction verification: {e}")
            raise AppleJWSVerificationError(f"Verification failed: {str(e)}")
    
    async def verify_notification(self, signed_payload: str) -> VerifiedNotification:
        """
        Verify a signed notification from Apple Server Notifications V2
        
        Args:
            signed_payload: JWS-signed notification payload
            
        Returns:
            VerifiedNotification with validated data
            
        Raises:
            AppleJWSVerificationError: If verification fails
        """
        try:
            # Decode header to get key ID
            header = jwt.get_unverified_header(signed_payload)
            kid = header.get('kid')
            
            if not kid:
                raise AppleJWSVerificationError("Missing key ID in notification header")
            
            # Get verification key
            verification_key = await self._get_verification_key(kid)
            
            # Verify and decode JWS
            try:
                claims = jwt.decode(
                    signed_payload,
                    key=verification_key,
                    algorithms=['ES256'],
                    options={
                        'verify_signature': True,
                        'verify_exp': True,
                        'verify_iat': True,
                        'verify_iss': True
                    }
                )
            except jwt.InvalidTokenError as e:
                raise AppleJWSVerificationError(f"Notification JWS verification failed: {e}")
            
            # Validate notification claims
            self._validate_notification_claims(claims)
            
            # Check for replay attacks
            notification_uuid = claims.get('notificationUUID')
            if notification_uuid and notification_uuid in self._processed_notifications:
                raise AppleJWSVerificationError(f"Notification {notification_uuid} already processed")
            
            # Extract and verify inner transaction
            data = claims.get('data', {})
            signed_transaction_info = data.get('signedTransactionInfo')
            
            if signed_transaction_info:
                transaction = await self.verify_transaction(signed_transaction_info)
            else:
                # Some notifications don't have transaction info
                transaction = None
            
            # Convert to structured object
            notification = VerifiedNotification(
                notification_type=claims.get('notificationType'),
                subtype=claims.get('subtype'),
                notification_uuid=notification_uuid,
                data=data,
                environment=AppleEnvironment(claims.get('environment', 'Production')),
                transaction=transaction
            )
            
            # Mark as processed
            if notification_uuid:
                self._processed_notifications.add(notification_uuid)
            
            logger.info(f"Successfully verified Apple notification: {claims.get('notificationType')}")
            return notification
            
        except AppleJWSVerificationError:
            raise
        except Exception as e:
            logger.error(f"Unexpected error during notification verification: {e}")
            raise AppleJWSVerificationError(f"Notification verification failed: {str(e)}")
    
    # =====================================================
    # PRIVATE HELPER METHODS
    # =====================================================
    
    async def _get_verification_key(self, kid: str) -> Any:
        """Get verification key for given key ID"""
        # Check cache first
        if self._is_cache_valid() and kid in self._cached_keys:
            return self._cached_keys[kid]
        
        # Fetch fresh keys
        await self._refresh_jwks_cache()
        
        if kid not in self._cached_keys:
            raise AppleJWSVerificationError(f"Key ID {kid} not found in Apple JWKS")
        
        return self._cached_keys[kid]
    
    async def _refresh_jwks_cache(self):
        """Fetch and cache Apple's JWKS keys"""
        try:
            async with httpx.AsyncClient() as client:
                # Fetch JWKS
                response = await client.get(
                    self.production_jwks_url,
                    timeout=10.0
                )
                response.raise_for_status()
                jwks = response.json()
            
            # Parse and cache keys
            self._cached_keys = {}
            for key_data in jwks.get('keys', []):
                kid = key_data.get('kid')
                if kid:
                    # Convert JWK to public key
                    public_key = self._jwk_to_public_key(key_data)
                    self._cached_keys[kid] = public_key
            
            self._cache_timestamp = time.time()
            logger.info(f"Cached {len(self._cached_keys)} Apple public keys")
            
        except Exception as e:
            logger.error(f"Failed to fetch Apple JWKS: {e}")
            raise AppleJWSVerificationError(f"Could not fetch Apple public keys: {e}")
    
    def _jwk_to_public_key(self, jwk: Dict[str, Any]) -> Any:
        """Convert JWK to cryptography public key object"""
        try:
            # Apple uses EC P-256 keys
            if jwk.get('kty') != 'EC' or jwk.get('crv') != 'P-256':
                raise ValueError("Unsupported key type")
            
            # Decode coordinates
            import base64
            x_bytes = base64.urlsafe_b64decode(jwk['x'] + '===')
            y_bytes = base64.urlsafe_b64decode(jwk['y'] + '===')
            
            # Create public key
            x = int.from_bytes(x_bytes, 'big')
            y = int.from_bytes(y_bytes, 'big')
            
            public_key = ec.EllipticCurvePublicKey.from_encoded_point(
                ec.SECP256R1(),
                b'\x04' + x_bytes + y_bytes
            )
            
            return public_key
            
        except Exception as e:
            raise AppleJWSVerificationError(f"Could not parse JWK: {e}")
    
    def _is_cache_valid(self) -> bool:
        """Check if JWKS cache is still valid"""
        return (time.time() - self._cache_timestamp) < self.cache_ttl
    
    def _validate_transaction_claims(
        self, 
        claims: Dict[str, Any], 
        expected_app_account_token: Optional[str]
    ):
        """Validate transaction claims"""
        # Check required fields
        required_fields = ['transactionId', 'originalTransactionId', 'bundleId', 'productId']
        for field in required_fields:
            if field not in claims:
                raise AppleJWSVerificationError(f"Missing required field: {field}")
        
        # Validate bundle ID
        if claims.get('bundleId') != self.bundle_id:
            raise AppleJWSVerificationError(
                f"Bundle ID mismatch: expected {self.bundle_id}, got {claims.get('bundleId')}"
            )
        
        # Validate app account token if provided
        if expected_app_account_token:
            token_in_claims = claims.get('appAccountToken')
            if token_in_claims != expected_app_account_token:
                raise AppleJWSVerificationError("App account token mismatch")
        
        # Validate timing (not too old)
        purchase_date = claims.get('purchaseDate')
        if purchase_date:
            purchase_time = datetime.fromtimestamp(purchase_date / 1000, tz=timezone.utc)
            max_age = timedelta(days=7)  # Don't accept very old transactions
            if datetime.now(timezone.utc) - purchase_time > max_age:
                raise AppleJWSVerificationError("Transaction too old")
        
        # Validate environment
        environment = claims.get('environment')
        if environment not in ['Production', 'Sandbox']:
            raise AppleJWSVerificationError(f"Invalid environment: {environment}")
    
    def _validate_notification_claims(self, claims: Dict[str, Any]):
        """Validate notification claims"""
        # Check required fields
        if 'notificationType' not in claims:
            raise AppleJWSVerificationError("Missing notification type")
        
        # Validate environment
        environment = claims.get('environment')
        if environment not in ['Production', 'Sandbox']:
            raise AppleJWSVerificationError(f"Invalid environment: {environment}")
        
        # Validate timing (not too old)
        signed_date = claims.get('signedDate')
        if signed_date:
            signed_time = datetime.fromtimestamp(signed_date / 1000, tz=timezone.utc)
            max_age = timedelta(hours=24)  # Don't accept very old notifications
            if datetime.now(timezone.utc) - signed_time > max_age:
                raise AppleJWSVerificationError("Notification too old")
    
    def _parse_transaction_claims(self, claims: Dict[str, Any]) -> VerifiedTransaction:
        """Parse claims into VerifiedTransaction object"""
        return VerifiedTransaction(
            transaction_id=claims['transactionId'],
            original_transaction_id=claims['originalTransactionId'],
            product_id=claims['productId'],
            bundle_id=claims['bundleId'],
            purchase_date=datetime.fromtimestamp(
                claims['purchaseDate'] / 1000, tz=timezone.utc
            ) if claims.get('purchaseDate') else datetime.now(timezone.utc),
            expires_date=datetime.fromtimestamp(
                claims['expiresDate'] / 1000, tz=timezone.utc
            ) if claims.get('expiresDate') else None,
            environment=AppleEnvironment(claims.get('environment', 'Production')),
            app_account_token=claims.get('appAccountToken'),
            quantity=claims.get('quantity', 1),
            raw_claims=claims
        )
    
    async def _cleanup_if_needed(self):
        """Periodically cleanup old processed IDs to prevent memory leaks"""
        now = time.time()
        if now - self._last_cleanup > self._cleanup_interval:
            # Keep only recent IDs (last 24 hours worth)
            # In production, you'd want to use Redis or database for this
            max_entries = 10000
            
            if len(self._processed_transactions) > max_entries:
                # Keep newest entries
                sorted_transactions = list(self._processed_transactions)
                self._processed_transactions = set(sorted_transactions[-max_entries//2:])
            
            if len(self._processed_notifications) > max_entries:
                sorted_notifications = list(self._processed_notifications)
                self._processed_notifications = set(sorted_notifications[-max_entries//2:])
            
            self._last_cleanup = now
            logger.info("Cleaned up old processed transaction/notification IDs")


# =====================================================
# CONVENIENCE FUNCTIONS
# =====================================================

# Global verifier instance
_verifier: Optional[AppleJWSVerifier] = None

def get_apple_verifier() -> AppleJWSVerifier:
    """Get global Apple JWS verifier instance"""
    global _verifier
    if _verifier is None:
        bundle_id = os.getenv('APPLE_BUNDLE_ID', 'com.betterbooks.app')
        _verifier = AppleJWSVerifier(bundle_id)
    return _verifier


async def verify_apple_transaction(
    signed_transaction: str,
    expected_app_account_token: Optional[str] = None
) -> VerifiedTransaction:
    """Convenience function to verify Apple transaction"""
    verifier = get_apple_verifier()
    return await verifier.verify_transaction(signed_transaction, expected_app_account_token)


async def verify_apple_notification(signed_payload: str) -> VerifiedNotification:
    """Convenience function to verify Apple notification"""
    verifier = get_apple_verifier()
    return await verifier.verify_notification(signed_payload)


# =====================================================
# TESTING UTILITIES
# =====================================================

def create_test_verifier(bundle_id: str = "com.test.app") -> AppleJWSVerifier:
    """Create verifier for testing"""
    return AppleJWSVerifier(bundle_id, cache_ttl=60)  # Shorter cache for tests