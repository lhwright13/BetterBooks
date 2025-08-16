"""
Apple App Store Integration Manager

Handles iOS StoreKit 2 purchases and App Store Server Notifications V2.
Complies with Apple App Store guidelines for in-app purchases.
"""

import os
import json
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone
from uuid import UUID, uuid4

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

from ..database.models.user import (
    Subscription, SubscriptionProvider, SubscriptionStatus, 
    EntitlementSource, SubscriptionPlan
)
from ..database.database_manager import DatabaseManager
from .entitlements_manager import EntitlementsManager
from .apple_jws_verifier import get_apple_verifier, verify_apple_transaction, verify_apple_notification

logger = logging.getLogger(__name__)


class AppleStoreError(Exception):
    """Custom exception for Apple Store operations"""
    pass


class AppleStoreManager:
    """
    Manages Apple App Store purchases and notifications
    
    Handles:
    - StoreKit 2 purchase verification
    - App Store Server Notifications V2
    - Receipt validation
    - Subscription lifecycle management
    """
    
    def __init__(self, db_manager: DatabaseManager, entitlements_manager: EntitlementsManager):
        self.db = db_manager
        self.entitlements = entitlements_manager
        
        # Apple configuration (from environment)
        self.bundle_id = os.getenv('APPLE_BUNDLE_ID', 'com.betterbooks.app')
        self.key_id = os.getenv('APPLE_KEY_ID')
        self.issuer_id = os.getenv('APPLE_ISSUER_ID')
        self.private_key = os.getenv('APPLE_PRIVATE_KEY')
        
        if not all([self.key_id, self.issuer_id, self.private_key]):
            logger.warning("Apple configuration incomplete - App Store features disabled")
            self.enabled = False
        else:
            self.enabled = True
            self._load_private_key()
        
        # Product configurations
        self.product_configs = {
            SubscriptionPlan.IOS_MONTHLY: {
                'features': ['premium_access', 'unlimited_books'],
                'duration_months': 1
            },
            SubscriptionPlan.IOS_YEARLY: {
                'features': ['premium_access', 'unlimited_books'],
                'duration_months': 12
            },
            SubscriptionPlan.IOS_FAMILY: {
                'features': ['premium_access', 'family_sharing', 'unlimited_books'],
                'duration_months': 1
            }
        }
        
        # SECURITY: Initialize idempotency tracking
        # Note: In production, run this as a migration instead
        if self.enabled:
            import asyncio
            asyncio.create_task(self._ensure_idempotency_tables_exist())
    
    def _load_private_key(self):
        """Load and parse Apple private key"""
        try:
            # Remove headers and whitespace
            key_data = self.private_key.replace('-----BEGIN PRIVATE KEY-----', '')
            key_data = key_data.replace('-----END PRIVATE KEY-----', '')
            key_data = key_data.replace('\n', '').replace(' ', '')
            
            # Load the key
            self.private_key_obj = serialization.load_der_private_key(
                bytes.fromhex(key_data),
                password=None
            )
            
        except Exception as e:
            logger.error(f"Failed to load Apple private key: {e}")
            self.enabled = False
    
    async def verify_purchase(
        self, 
        signed_transaction: str,
        app_account_token: str,
        user_id: Optional[UUID] = None
    ) -> Dict[str, Any]:
        """
        Verify StoreKit 2 purchase from iOS app
        
        Args:
            signed_transaction: JWS from StoreKit Transaction
            app_account_token: Token linking purchase to user
            user_id: Optional user ID if known
            
        Returns:
            Dict with verification result and subscription info
        """
        if not self.enabled:
            raise AppleStoreError("Apple Store integration not configured")
        
        try:
            # SECURITY FIX: Use proper cryptographic JWS verification
            verified_transaction = await verify_apple_transaction(
                signed_transaction, 
                expected_app_account_token=app_account_token
            )
            
            # Extract verified transaction info
            transaction_id = verified_transaction.transaction_id
            original_transaction_id = verified_transaction.original_transaction_id
            product_id = verified_transaction.product_id
            purchase_date = verified_transaction.purchase_date
            expires_date = verified_transaction.expires_date
            environment = verified_transaction.environment.value
            
            # Check for replay attacks (idempotency)
            if await self._is_transaction_already_processed(transaction_id):
                logger.info(f"Transaction {transaction_id} already processed - skipping")
                existing_subscription = await self._get_subscription_by_original_transaction_id(original_transaction_id)
                if existing_subscription:
                    return {
                        'success': True,
                        'subscription_id': str(existing_subscription.id),
                        'product_id': product_id,
                        'expires_date': int(expires_date.timestamp() * 1000) if expires_date else None,
                        'skipped': True,
                        'reason': 'already_processed'
                    }
            
            # Mark transaction as processed (idempotency)
            await self._mark_transaction_processed(transaction_id)
            
            # Get or create user from app_account_token
            if not user_id:
                user_id = await self._get_user_by_app_token(app_account_token)
                if not user_id:
                    raise AppleStoreError("User not found for app account token")
            
            # Use database transaction for atomic processing
            async with self.db.transaction():
                # Store Apple receipt with idempotency protection
                receipt_id = await self._store_apple_receipt_idempotent(
                    user_id=user_id,
                    transaction_id=transaction_id,
                    original_transaction_id=original_transaction_id,
                    environment=environment,
                    signed_payload=signed_transaction,
                    notification_type='INITIAL_BUY',
                    product_id=product_id,
                    purchase_date=purchase_date,
                    expires_date=expires_date
                )
            
                # Create or update subscription with idempotency
                subscription = await self._create_or_update_subscription_idempotent(
                    user_id=user_id,
                    original_transaction_id=original_transaction_id,
                    product_id=product_id,
                    environment=environment,
                    expires_date=expires_date,
                    app_account_token=UUID(app_account_token) if app_account_token else None
                )
                
                # Update entitlements
                await self.entitlements.update_subscription_entitlements(user_id, subscription.id)
            
            
            logger.info(f"Apple purchase verified: user={user_id}, product={product_id}")
            
            return {
                'success': True,
                'subscription_id': str(subscription.id),
                'product_id': product_id,
                'expires_date': int(expires_date.timestamp() * 1000) if expires_date else None,
                'receipt_id': str(receipt_id)
            }
            
        except Exception as e:
            logger.error(f"Apple purchase verification failed: {e}")
            raise AppleStoreError(f"Purchase verification failed: {str(e)}")
    
    async def handle_server_notification(self, signed_payload: str) -> Dict[str, Any]:
        """
        Handle App Store Server Notification V2
        
        Args:
            signed_payload: Signed JWS from Apple
            
        Returns:
            Dict with processing result
        """
        if not self.enabled:
            raise AppleStoreError("Apple Store integration not configured")
        
        try:
            # SECURITY FIX: Use proper cryptographic JWS verification
            verified_notification = await verify_apple_notification(signed_payload)
            
            notification_type = verified_notification.notification_type
            subtype = verified_notification.subtype
            notification_uuid = verified_notification.notification_uuid
            
            # Check for duplicate notifications (idempotency)
            if await self._is_notification_already_processed(notification_uuid):
                logger.info(f"Notification {notification_uuid} already processed - skipping")
                return {
                    'success': True,
                    'notification_type': notification_type,
                    'skipped': True,
                    'reason': 'already_processed'
                }
            
            # Extract verified transaction info
            if not verified_notification.transaction:
                raise AppleStoreError("Missing transaction info in notification")
            
            transaction = verified_notification.transaction
            
            original_transaction_id = transaction.original_transaction_id
            product_id = transaction.product_id
            expires_date = transaction.expires_date
            environment = transaction.environment.value
            transaction_id = transaction.transaction_id
            
            # Find user by original transaction ID
            user_id = await self._get_user_by_transaction_id(original_transaction_id)
            if not user_id:
                logger.warning(f"User not found for transaction {original_transaction_id}")
                return {'success': False, 'reason': 'User not found'}
            
            # Mark notification as processed (idempotency)
            await self._mark_notification_processed(notification_uuid)
            
            # Use database transaction for atomic processing
            async with self.db.transaction():
                # Store notification with idempotency protection
                await self._store_apple_receipt_idempotent(
                    user_id=user_id,
                    transaction_id=transaction_id,
                    original_transaction_id=original_transaction_id,
                    environment=environment,
                    signed_payload=signed_payload,
                    notification_type=notification_type,
                    subtype=subtype,
                    product_id=product_id,
                    expires_date=expires_date
                )
            
                # Process notification based on type
                await self._process_notification_idempotent(
                    user_id=user_id,
                    notification_type=notification_type,
                    subtype=subtype,
                    original_transaction_id=original_transaction_id,
                    product_id=product_id,
                    expires_date=expires_date,
                    environment=environment
                )
            
            logger.info(f"Processed Apple notification: {notification_type} for user {user_id}")
            
            return {
                'success': True,
                'notification_type': notification_type,
                'user_id': str(user_id)
            }
            
        except Exception as e:
            logger.error(f"Apple notification processing failed: {e}")
            raise AppleStoreError(f"Notification processing failed: {str(e)}")
    
    async def restore_purchases(self, user_id: UUID, transactions: List[str]) -> Dict[str, Any]:
        """
        Restore purchases for user (required by Apple guidelines)
        
        Args:
            user_id: User ID
            transactions: List of signed transactions from Transaction.currentEntitlements
            
        Returns:
            Dict with restored subscriptions
        """
        try:
            restored_count = 0
            current_subscription = None
            
            for signed_transaction in transactions:
                try:
                    # Verify and process each transaction
                    result = await self.verify_purchase(
                        signed_transaction=signed_transaction,
                        app_account_token="",  # Not needed for restore
                        user_id=user_id
                    )
                    
                    if result['success']:
                        restored_count += 1
                        # Keep track of the most recent active subscription
                        # This would need more logic to determine the "current" one
                        current_subscription = result
                        
                except Exception as e:
                    logger.warning(f"Failed to restore transaction: {e}")
                    continue
            
            logger.info(f"Restored {restored_count} purchases for user {user_id}")
            
            return {
                'success': True,
                'restored_count': restored_count,
                'current_subscription': current_subscription
            }
            
        except Exception as e:
            logger.error(f"Purchase restoration failed: {e}")
            raise AppleStoreError(f"Purchase restoration failed: {str(e)}")
    
    # =====================================================
    # PRIVATE HELPER METHODS
    # =====================================================
    
    async def _store_apple_receipt(
        self,
        user_id: UUID,
        transaction_id: Optional[str],
        original_transaction_id: str,
        environment: str,
        signed_payload: str,
        notification_type: str,
        subtype: Optional[str] = None,
        product_id: Optional[str] = None,
        purchase_date: Optional[datetime] = None,
        expires_date: Optional[datetime] = None
    ) -> UUID:
        """Store Apple receipt for audit trail"""
        
        receipt_id = uuid4()
        
        query = """
            INSERT INTO apple_receipts (
                id, user_id, original_transaction_id, transaction_id, environment,
                notification_type, subtype, signed_payload, product_id,
                purchase_date, expires_date, received_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (transaction_id, notification_type) DO UPDATE SET
                received_at = EXCLUDED.received_at,
                processed = false
        """
        
        await self.db.execute_query(query, (
            str(receipt_id),
            str(user_id),
            original_transaction_id,
            transaction_id,
            environment,
            notification_type,
            subtype,
            signed_payload,
            product_id,
            purchase_date,
            expires_date,
            datetime.now(timezone.utc)
        ))
        
        return receipt_id
    
    async def _create_or_update_subscription(
        self,
        user_id: UUID,
        original_transaction_id: str,
        product_id: str,
        environment: str,
        expires_date: Optional[datetime],
        app_account_token: Optional[UUID] = None
    ) -> Subscription:
        """Create or update subscription record"""
        
        # Check if subscription already exists
        query = """
            SELECT id FROM subscriptions 
            WHERE original_transaction_id = %s
        """
        
        result = await self.db.fetch_one(query, (original_transaction_id,))
        
        if result:
            # Update existing subscription
            subscription_id = UUID(result['id'])
            
            update_query = """
                UPDATE subscriptions SET
                    status = %s,
                    current_period_end = %s,
                    updated_at = %s
                WHERE id = %s
            """
            
            await self.db.execute_query(update_query, (
                SubscriptionStatus.ACTIVE.value,
                expires_date,
                datetime.now(timezone.utc),
                str(subscription_id)
            ))
            
        else:
            # Create new subscription
            subscription_id = uuid4()
            
            insert_query = """
                INSERT INTO subscriptions (
                    id, user_id, provider, status, product_id,
                    original_transaction_id, app_account_token, environment,
                    current_period_end, created_at, updated_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """
            
            await self.db.execute_query(insert_query, (
                str(subscription_id),
                str(user_id),
                SubscriptionProvider.APP_STORE.value,
                SubscriptionStatus.ACTIVE.value,
                product_id,
                original_transaction_id,
                str(app_account_token) if app_account_token else None,
                environment,
                expires_date,
                datetime.now(timezone.utc),
                datetime.now(timezone.utc)
            ))
        
        # Return subscription object
        return Subscription(
            id=subscription_id,
            user_id=user_id,
            provider=SubscriptionProvider.APP_STORE,
            status=SubscriptionStatus.ACTIVE,
            product_id=product_id,
            original_transaction_id=original_transaction_id,
            app_account_token=app_account_token,
            environment=environment,
            current_period_end=expires_date,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
    
    async def _get_user_by_app_token(self, app_account_token: str) -> Optional[UUID]:
        """Get user ID by app account token"""
        query = """
            SELECT user_id FROM subscriptions 
            WHERE app_account_token = %s
            LIMIT 1
        """
        
        result = await self.db.fetch_one(query, (app_account_token,))
        return UUID(result['user_id']) if result else None
    
    async def _get_user_by_transaction_id(self, original_transaction_id: str) -> Optional[UUID]:
        """Get user ID by original transaction ID"""
        query = """
            SELECT user_id FROM subscriptions 
            WHERE original_transaction_id = %s
            LIMIT 1
        """
        
        result = await self.db.fetch_one(query, (original_transaction_id,))
        return UUID(result['user_id']) if result else None
    
    async def _process_notification(
        self,
        user_id: UUID,
        notification_type: str,
        subtype: Optional[str],
        original_transaction_id: str,
        product_id: str,
        expires_date: Optional[datetime],
        environment: str
    ):
        """Process specific notification types"""
        
        if notification_type in ['INITIAL_BUY', 'DID_RENEW']:
            # Activate or renew subscription
            await self._create_or_update_subscription(
                user_id=user_id,
                original_transaction_id=original_transaction_id,
                product_id=product_id,
                environment=environment,
                expires_date=expires_date
            )
            
            # Update entitlements
            subscription = await self._get_subscription_by_transaction_id(original_transaction_id)
            if subscription:
                await self.entitlements.update_subscription_entitlements(user_id, subscription.id)
        
        elif notification_type == 'DID_CANCEL':
            # Mark subscription as cancelled
            await self._update_subscription_status(
                original_transaction_id,
                SubscriptionStatus.CANCELLED
            )
            
            # Remove entitlements (unless in grace period)
            if subtype != 'BILLING_RETRY':
                await self.entitlements.revoke_entitlements(
                    user_id, 
                    SubscriptionPlan.get_features(product_id),
                    EntitlementSource.SUBSCRIPTION
                )
        
        elif notification_type == 'EXPIRED':
            # Mark subscription as expired
            await self._update_subscription_status(
                original_transaction_id,
                SubscriptionStatus.EXPIRED
            )
            
            # Remove entitlements
            await self.entitlements.revoke_entitlements(
                user_id,
                SubscriptionPlan.get_features(product_id),
                EntitlementSource.SUBSCRIPTION
            )
        
        elif notification_type == 'GRACE_PERIOD_EXPIRED':
            # Final expiration
            await self._update_subscription_status(
                original_transaction_id,
                SubscriptionStatus.EXPIRED
            )
            
            await self.entitlements.revoke_entitlements(
                user_id,
                SubscriptionPlan.get_features(product_id),
                EntitlementSource.SUBSCRIPTION
            )
        
        # Add more notification types as needed
    
    async def _update_subscription_status(
        self, 
        original_transaction_id: str, 
        status: SubscriptionStatus
    ):
        """Update subscription status"""
        query = """
            UPDATE subscriptions 
            SET status = %s, updated_at = %s
            WHERE original_transaction_id = %s
        """
        
        await self.db.execute_query(query, (
            status.value,
            datetime.now(timezone.utc),
            original_transaction_id
        ))
    
    async def _get_subscription_by_transaction_id(self, original_transaction_id: str) -> Optional[Subscription]:
        """Get subscription by original transaction ID"""
        query = """
            SELECT id FROM subscriptions 
            WHERE original_transaction_id = %s
        """
        
        result = await self.db.fetch_one(query, (original_transaction_id,))
        if not result:
            return None
        
        # Would need to implement full subscription loading
        # For now, return minimal object
        return Subscription(
            id=UUID(result['id']),
            user_id=UUID('00000000-0000-0000-0000-000000000000'),  # Placeholder
            provider=SubscriptionProvider.APP_STORE,
            status=SubscriptionStatus.ACTIVE,
            product_id="",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
    
    # =====================================================
    # IDEMPOTENCY METHODS (SECURITY)
    # =====================================================
    
    async def _is_transaction_already_processed(self, transaction_id: str) -> bool:
        """
        Check if Apple transaction was already processed
        
        SECURITY: Prevents replay attacks by tracking processed transaction IDs
        """
        query = """
            SELECT COUNT(*) as count FROM processed_apple_transactions 
            WHERE transaction_id = %s
        """
        
        result = await self.db.fetch_one(query, (transaction_id,))
        return result and result['count'] > 0
    
    async def _mark_transaction_processed(self, transaction_id: str):
        """
        Mark Apple transaction as processed
        
        SECURITY: Prevents duplicate processing of the same transaction
        """
        query = """
            INSERT INTO processed_apple_transactions (transaction_id, processed_at)
            VALUES (%s, %s)
            ON CONFLICT (transaction_id) DO NOTHING
        """
        
        await self.db.execute_query(query, (
            transaction_id,
            datetime.now(timezone.utc)
        ))
    
    async def _is_notification_already_processed(self, notification_uuid: str) -> bool:
        """
        Check if Apple notification was already processed
        
        SECURITY: Prevents duplicate processing of server notifications
        """
        if not notification_uuid:
            return False
            
        query = """
            SELECT COUNT(*) as count FROM processed_apple_notifications 
            WHERE notification_uuid = %s
        """
        
        result = await self.db.fetch_one(query, (notification_uuid,))
        return result and result['count'] > 0
    
    async def _mark_notification_processed(self, notification_uuid: str):
        """
        Mark Apple notification as processed
        
        SECURITY: Prevents duplicate processing of server notifications
        """
        if not notification_uuid:
            return
            
        query = """
            INSERT INTO processed_apple_notifications (notification_uuid, processed_at)
            VALUES (%s, %s)
            ON CONFLICT (notification_uuid) DO NOTHING
        """
        
        await self.db.execute_query(query, (
            notification_uuid,
            datetime.now(timezone.utc)
        ))
    
    async def _store_apple_receipt_idempotent(
        self,
        user_id: UUID,
        transaction_id: Optional[str],
        original_transaction_id: str,
        environment: str,
        signed_payload: str,
        notification_type: str,
        subtype: Optional[str] = None,
        product_id: Optional[str] = None,
        purchase_date: Optional[datetime] = None,
        expires_date: Optional[datetime] = None
    ) -> UUID:
        """
        Store Apple receipt with idempotency protection
        
        SECURITY: Uses ON CONFLICT DO NOTHING to prevent duplicate receipts
        """
        receipt_id = uuid4()
        
        query = """
            INSERT INTO apple_receipts (
                id, user_id, transaction_id, original_transaction_id,
                environment, signed_payload, notification_type, subtype,
                product_id, purchase_date, expires_date, received_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (transaction_id) DO NOTHING
            RETURNING id
        """
        
        result = await self.db.fetch_one(query, (
            str(receipt_id),
            str(user_id),
            transaction_id,
            original_transaction_id,
            environment,
            signed_payload,
            notification_type,
            subtype,
            product_id,
            purchase_date,
            expires_date,
            datetime.now(timezone.utc)
        ))
        
        # Return existing ID if conflict occurred
        if result:
            return UUID(result['id'])
        else:
            # Get existing receipt ID
            existing_query = """
                SELECT id FROM apple_receipts 
                WHERE transaction_id = %s
                LIMIT 1
            """
            existing = await self.db.fetch_one(existing_query, (transaction_id,))
            return UUID(existing['id']) if existing else receipt_id
    
    async def _create_or_update_subscription_idempotent(
        self,
        user_id: UUID,
        original_transaction_id: str,
        product_id: str,
        environment: str,
        expires_date: Optional[datetime] = None,
        app_account_token: Optional[UUID] = None
    ) -> Subscription:
        """
        Create or update subscription with idempotency protection
        
        SECURITY: Uses unique constraint on original_transaction_id to prevent duplicates
        """
        # Check if subscription already exists
        existing = await self._get_subscription_by_original_transaction_id(original_transaction_id)
        if existing:
            # Update existing subscription
            update_query = """
                UPDATE subscriptions SET
                    status = %s,
                    current_period_end = %s,
                    updated_at = %s
                WHERE original_transaction_id = %s
            """
            
            await self.db.execute_query(update_query, (
                SubscriptionStatus.ACTIVE.value,
                expires_date,
                datetime.now(timezone.utc),
                original_transaction_id
            ))
            
            return existing
        
        # Create new subscription with idempotency protection
        subscription_id = uuid4()
        
        insert_query = """
            INSERT INTO subscriptions (
                id, user_id, provider, status, product_id,
                original_transaction_id, app_account_token, environment,
                current_period_end, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (original_transaction_id) DO NOTHING
        """
        
        await self.db.execute_query(insert_query, (
            str(subscription_id),
            str(user_id),
            SubscriptionProvider.APP_STORE.value,
            SubscriptionStatus.ACTIVE.value,
            product_id,
            original_transaction_id,
            str(app_account_token) if app_account_token else None,
            environment,
            expires_date,
            datetime.now(timezone.utc),
            datetime.now(timezone.utc)
        ))
        
        return Subscription(
            id=subscription_id,
            user_id=user_id,
            provider=SubscriptionProvider.APP_STORE,
            status=SubscriptionStatus.ACTIVE,
            product_id=product_id,
            original_transaction_id=original_transaction_id,
            app_account_token=app_account_token,
            environment=environment,
            current_period_end=expires_date,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
    
    async def _get_subscription_by_original_transaction_id(self, original_transaction_id: str) -> Optional[Subscription]:
        """
        Get subscription by original transaction ID
        """
        query = """
            SELECT id, user_id, provider, status, product_id, 
                   original_transaction_id, app_account_token, environment,
                   current_period_end, created_at, updated_at
            FROM subscriptions 
            WHERE original_transaction_id = %s
        """
        
        result = await self.db.fetch_one(query, (original_transaction_id,))
        if not result:
            return None
        
        return Subscription(
            id=UUID(result['id']),
            user_id=UUID(result['user_id']),
            provider=SubscriptionProvider(result['provider']),
            status=SubscriptionStatus(result['status']),
            product_id=result['product_id'],
            original_transaction_id=result['original_transaction_id'],
            app_account_token=UUID(result['app_account_token']) if result['app_account_token'] else None,
            environment=result['environment'],
            current_period_end=result['current_period_end'],
            created_at=result['created_at'],
            updated_at=result['updated_at']
        )
    
    async def _process_notification_idempotent(
        self,
        user_id: UUID,
        notification_type: str,
        subtype: Optional[str],
        original_transaction_id: str,
        product_id: str,
        expires_date: Optional[datetime],
        environment: str
    ):
        """
        Process notification with idempotency protection
        
        SECURITY: Ensures notification processing is idempotent
        """
        # Use the original method but with idempotent subscription creation
        if notification_type in ['INITIAL_BUY', 'DID_RENEW']:
            # Activate or renew subscription
            await self._create_or_update_subscription_idempotent(
                user_id=user_id,
                original_transaction_id=original_transaction_id,
                product_id=product_id,
                environment=environment,
                expires_date=expires_date
            )
            
            # Update entitlements
            subscription = await self._get_subscription_by_original_transaction_id(original_transaction_id)
            if subscription:
                await self.entitlements.update_subscription_entitlements(user_id, subscription.id)
        
        elif notification_type == 'DID_CANCEL':
            # Mark subscription as cancelled
            await self._update_subscription_status(
                original_transaction_id,
                SubscriptionStatus.CANCELLED
            )
            
            # Remove entitlements (unless in grace period)
            if subtype != 'BILLING_RETRY':
                await self.entitlements.revoke_entitlements(
                    user_id, 
                    SubscriptionPlan.get_features(product_id),
                    EntitlementSource.SUBSCRIPTION
                )
        
        elif notification_type == 'EXPIRED':
            # Mark subscription as expired
            await self._update_subscription_status(
                original_transaction_id,
                SubscriptionStatus.EXPIRED
            )
            
            # Remove entitlements
            await self.entitlements.revoke_entitlements(
                user_id,
                SubscriptionPlan.get_features(product_id),
                EntitlementSource.SUBSCRIPTION
            )
        
        elif notification_type == 'GRACE_PERIOD_EXPIRED':
            # Final expiration
            await self._update_subscription_status(
                original_transaction_id,
                SubscriptionStatus.EXPIRED
            )
            
            await self.entitlements.revoke_entitlements(
                user_id,
                SubscriptionPlan.get_features(product_id),
                EntitlementSource.SUBSCRIPTION
            )
    
    async def _ensure_idempotency_tables_exist(self):
        """
        Ensure Apple-specific idempotency tables exist
        
        SECURITY: Creates tables for tracking processed transactions/notifications
        """
        
        # Table for tracking processed transactions
        transaction_table_query = """
            CREATE TABLE IF NOT EXISTS processed_apple_transactions (
                transaction_id VARCHAR(255) PRIMARY KEY,
                processed_at TIMESTAMP WITH TIME ZONE NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        """
        
        await self.db.execute_query(transaction_table_query)
        
        # Table for tracking processed notifications
        notification_table_query = """
            CREATE TABLE IF NOT EXISTS processed_apple_notifications (
                notification_uuid VARCHAR(255) PRIMARY KEY,
                processed_at TIMESTAMP WITH TIME ZONE NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        """
        
        await self.db.execute_query(notification_table_query)
        
        # Indices for performance
        await self.db.execute_query(
            "CREATE INDEX IF NOT EXISTS idx_processed_apple_transactions_processed_at ON processed_apple_transactions(processed_at)"
        )
        await self.db.execute_query(
            "CREATE INDEX IF NOT EXISTS idx_processed_apple_notifications_processed_at ON processed_apple_notifications(processed_at)"
        )