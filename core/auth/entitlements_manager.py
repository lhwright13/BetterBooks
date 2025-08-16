"""
Entitlements Management System

Manages user entitlements based on active subscriptions from both 
App Store and Stripe. Provides single source of truth for feature gating.
"""

import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone, timedelta
from uuid import UUID

from .models.user import (
    User, Entitlement, Subscription, EntitlementSource, 
    SubscriptionStatus, SubscriptionProvider, SubscriptionPlan,
    EntitlementResponse, UserEntitlementsResponse
)
from ..database.database_manager import DatabaseManager

logger = logging.getLogger(__name__)


class EntitlementsManager:
    """
    Manages user entitlements based on subscriptions and promotions
    
    Key Features:
    - Single source of truth for "can user access X?"
    - Automatically computed from active subscriptions
    - Supports both App Store and Stripe subscriptions
    - Handles trials, promotions, and gifts
    """
    
    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager
    
    async def get_user_entitlements(self, user_id: UUID) -> UserEntitlementsResponse:
        """
        Get all current entitlements for a user
        
        This is the primary API endpoint that apps call to check permissions.
        """
        try:
            # Get all active entitlements
            entitlements = await self._get_active_entitlements(user_id)
            
            # Get current subscription info
            subscription = await self._get_primary_subscription(user_id)
            
            # Format response
            entitlement_responses = [
                EntitlementResponse(
                    feature=ent.feature,
                    expires_at=ent.expires_at,
                    source=ent.source,
                    is_valid=ent.is_valid
                )
                for ent in entitlements
            ]
            
            subscription_data = None
            if subscription:
                subscription_data = {
                    "provider": subscription.provider.value,
                    "status": subscription.status.value,
                    "product_id": subscription.product_id,
                    "current_period_end": subscription.current_period_end.isoformat() if subscription.current_period_end else None,
                    "is_trial": subscription.is_trial,
                    "is_active": subscription.is_active
                }
            
            return UserEntitlementsResponse(
                user_id=user_id,
                entitlements=entitlement_responses,
                subscription=subscription_data
            )
            
        except Exception as e:
            logger.error(f"Failed to get entitlements for user {user_id}: {e}")
            # Return empty entitlements on error (fail safe)
            return UserEntitlementsResponse(
                user_id=user_id,
                entitlements=[],
                subscription=None
            )
    
    async def user_has_feature(self, user_id: UUID, feature: str) -> bool:
        """
        Check if user has access to specific feature
        
        Args:
            user_id: User ID
            feature: Feature name (e.g., 'premium_access', 'family_sharing')
            
        Returns:
            True if user has active entitlement for feature
        """
        try:
            entitlements = await self._get_active_entitlements(user_id)
            return any(
                ent.feature == feature and ent.is_valid 
                for ent in entitlements
            )
        except Exception as e:
            logger.error(f"Failed to check feature {feature} for user {user_id}: {e}")
            return False  # Fail safe: deny access on error
    
    async def update_subscription_entitlements(
        self, 
        user_id: UUID,
        subscription_id: UUID
    ) -> List[Entitlement]:
        """
        Update entitlements based on subscription change
        
        Called when subscription status changes (renewal, cancellation, etc.)
        """
        try:
            # Get the subscription
            subscription = await self._get_subscription_by_id(subscription_id)
            if not subscription:
                logger.warning(f"Subscription {subscription_id} not found")
                return []
            
            # Remove existing subscription-based entitlements for this user
            await self._remove_subscription_entitlements(user_id)
            
            # Add new entitlements if subscription is active
            new_entitlements = []
            if subscription.is_active:
                features = SubscriptionPlan.get_features(subscription.product_id)
                
                for feature in features:
                    entitlement = Entitlement(
                        user_id=user_id,
                        feature=feature,
                        granted_at=datetime.now(timezone.utc),
                        expires_at=subscription.current_period_end,
                        source=EntitlementSource.SUBSCRIPTION,
                        source_id=subscription.id,
                        active=True
                    )
                    
                    await self._save_entitlement(entitlement)
                    new_entitlements.append(entitlement)
            
            logger.info(f"Updated entitlements for user {user_id}: {len(new_entitlements)} features")
            return new_entitlements
            
        except Exception as e:
            logger.error(f"Failed to update subscription entitlements: {e}")
            return []
    
    async def grant_trial_entitlements(
        self, 
        user_id: UUID, 
        features: List[str],
        trial_days: int = 7
    ) -> List[Entitlement]:
        """
        Grant trial entitlements to user
        
        Args:
            user_id: User ID
            features: List of features to grant trial access
            trial_days: Number of trial days
            
        Returns:
            List of created entitlements
        """
        try:
            trial_end = datetime.now(timezone.utc) + timedelta(days=trial_days)
            trial_end = trial_end.replace(hour=23, minute=59, second=59)  # End of day
            
            entitlements = []
            for feature in features:
                # Check if user already has this feature
                has_feature = await self.user_has_feature(user_id, feature)
                if has_feature:
                    continue
                
                entitlement = Entitlement(
                    user_id=user_id,
                    feature=feature,
                    granted_at=datetime.now(timezone.utc),
                    expires_at=trial_end,
                    source=EntitlementSource.TRIAL,
                    active=True
                )
                
                await self._save_entitlement(entitlement)
                entitlements.append(entitlement)
            
            logger.info(f"Granted {len(entitlements)} trial entitlements to user {user_id}")
            return entitlements
            
        except Exception as e:
            logger.error(f"Failed to grant trial entitlements: {e}")
            return []
    
    async def grant_promotional_entitlements(
        self,
        user_id: UUID,
        features: List[str],
        expires_at: Optional[datetime] = None,
        promotion_id: Optional[str] = None
    ) -> List[Entitlement]:
        """
        Grant promotional entitlements (admin action)
        
        Args:
            user_id: User ID
            features: Features to grant
            expires_at: When promotion expires (None = permanent)
            promotion_id: Reference to promotion campaign
            
        Returns:
            List of created entitlements
        """
        try:
            entitlements = []
            for feature in features:
                entitlement = Entitlement(
                    user_id=user_id,
                    feature=feature,
                    granted_at=datetime.now(timezone.utc),
                    expires_at=expires_at,
                    source=EntitlementSource.PROMOTION,
                    active=True
                )
                
                await self._save_entitlement(entitlement)
                entitlements.append(entitlement)
            
            logger.info(f"Granted {len(entitlements)} promotional entitlements to user {user_id}")
            return entitlements
            
        except Exception as e:
            logger.error(f"Failed to grant promotional entitlements: {e}")
            return []
    
    async def revoke_entitlements(
        self, 
        user_id: UUID, 
        features: List[str],
        source: Optional[EntitlementSource] = None
    ) -> bool:
        """
        Revoke specific entitlements
        
        Args:
            user_id: User ID
            features: Features to revoke
            source: Optional source filter
            
        Returns:
            True if successful
        """
        try:
            for feature in features:
                await self._revoke_entitlement(user_id, feature, source)
            
            logger.info(f"Revoked entitlements for user {user_id}: {features}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to revoke entitlements: {e}")
            return False
    
    async def cleanup_expired_entitlements(self) -> int:
        """
        Clean up expired entitlements (background job)
        
        Returns:
            Number of entitlements cleaned up
        """
        try:
            now = datetime.now(timezone.utc)
            
            # Mark expired entitlements as inactive
            query = """
                UPDATE entitlements 
                SET active = false, updated_at = NOW()
                WHERE active = true 
                AND expires_at IS NOT NULL 
                AND expires_at < %s
            """
            
            result = await self.db.execute_query(query, (now,))
            count = result.rowcount if result else 0
            
            logger.info(f"Cleaned up {count} expired entitlements")
            return count
            
        except Exception as e:
            logger.error(f"Failed to cleanup expired entitlements: {e}")
            return 0
    
    # =====================================================
    # PRIVATE HELPER METHODS
    # =====================================================
    
    async def _get_active_entitlements(self, user_id: UUID) -> List[Entitlement]:
        """Get all active entitlements for user"""
        query = """
            SELECT user_id, feature, granted_at, expires_at, source, source_id, active
            FROM entitlements 
            WHERE user_id = %s 
            AND active = true
            AND (expires_at IS NULL OR expires_at > NOW())
            ORDER BY granted_at DESC
        """
        
        rows = await self.db.fetch_all(query, (str(user_id),))
        
        entitlements = []
        for row in rows:
            entitlement = Entitlement(
                user_id=UUID(row['user_id']),
                feature=row['feature'],
                granted_at=row['granted_at'],
                expires_at=row['expires_at'],
                source=EntitlementSource(row['source']),
                source_id=UUID(row['source_id']) if row['source_id'] else None,
                active=row['active']
            )
            entitlements.append(entitlement)
        
        return entitlements
    
    async def _get_primary_subscription(self, user_id: UUID) -> Optional[Subscription]:
        """Get user's primary active subscription"""
        query = """
            SELECT id, user_id, provider, status, product_id, price_id,
                   current_period_start, current_period_end, cancel_at, cancelled_at,
                   original_transaction_id, app_account_token, environment,
                   stripe_subscription_id, stripe_customer_id, stripe_price_id,
                   trial_start, trial_end, created_at, updated_at
            FROM subscriptions 
            WHERE user_id = %s 
            AND status = 'active'
            AND (current_period_end IS NULL OR current_period_end > NOW())
            ORDER BY created_at DESC
            LIMIT 1
        """
        
        row = await self.db.fetch_one(query, (str(user_id),))
        if not row:
            return None
        
        return Subscription(
            id=UUID(row['id']),
            user_id=UUID(row['user_id']),
            provider=SubscriptionProvider(row['provider']),
            status=SubscriptionStatus(row['status']),
            product_id=row['product_id'],
            price_id=row['price_id'],
            current_period_start=row['current_period_start'],
            current_period_end=row['current_period_end'],
            cancel_at=row['cancel_at'],
            cancelled_at=row['cancelled_at'],
            original_transaction_id=row['original_transaction_id'],
            app_account_token=UUID(row['app_account_token']) if row['app_account_token'] else None,
            environment=row['environment'],
            stripe_subscription_id=row['stripe_subscription_id'],
            stripe_customer_id=row['stripe_customer_id'],
            stripe_price_id=row['stripe_price_id'],
            trial_start=row['trial_start'],
            trial_end=row['trial_end'],
            created_at=row['created_at'],
            updated_at=row['updated_at']
        )
    
    async def _get_subscription_by_id(self, subscription_id: UUID) -> Optional[Subscription]:
        """Get subscription by ID"""
        query = """
            SELECT id, user_id, provider, status, product_id, price_id,
                   current_period_start, current_period_end, cancel_at, cancelled_at,
                   original_transaction_id, app_account_token, environment,
                   stripe_subscription_id, stripe_customer_id, stripe_price_id,
                   trial_start, trial_end, created_at, updated_at
            FROM subscriptions 
            WHERE id = %s
        """
        
        row = await self.db.fetch_one(query, (str(subscription_id),))
        if not row:
            return None
        
        return Subscription(
            id=UUID(row['id']),
            user_id=UUID(row['user_id']),
            provider=SubscriptionProvider(row['provider']),
            status=SubscriptionStatus(row['status']),
            product_id=row['product_id'],
            price_id=row['price_id'],
            current_period_start=row['current_period_start'],
            current_period_end=row['current_period_end'],
            cancel_at=row['cancel_at'],
            cancelled_at=row['cancelled_at'],
            original_transaction_id=row['original_transaction_id'],
            app_account_token=UUID(row['app_account_token']) if row['app_account_token'] else None,
            environment=row['environment'],
            stripe_subscription_id=row['stripe_subscription_id'],
            stripe_customer_id=row['stripe_customer_id'],
            stripe_price_id=row['stripe_price_id'],
            trial_start=row['trial_start'],
            trial_end=row['trial_end'],
            created_at=row['created_at'],
            updated_at=row['updated_at']
        )
    
    async def _save_entitlement(self, entitlement: Entitlement) -> bool:
        """Save entitlement to database"""
        query = """
            INSERT INTO entitlements (user_id, feature, granted_at, expires_at, source, source_id, active)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (user_id, feature) DO UPDATE SET
                granted_at = EXCLUDED.granted_at,
                expires_at = EXCLUDED.expires_at,
                source = EXCLUDED.source,
                source_id = EXCLUDED.source_id,
                active = EXCLUDED.active
        """
        
        await self.db.execute_query(query, (
            str(entitlement.user_id),
            entitlement.feature,
            entitlement.granted_at,
            entitlement.expires_at,
            entitlement.source.value,
            str(entitlement.source_id) if entitlement.source_id else None,
            entitlement.active
        ))
        
        return True
    
    async def _remove_subscription_entitlements(self, user_id: UUID) -> bool:
        """Remove all subscription-based entitlements for user"""
        query = """
            DELETE FROM entitlements 
            WHERE user_id = %s AND source = 'subscription'
        """
        
        await self.db.execute_query(query, (str(user_id),))
        return True
    
    async def _revoke_entitlement(
        self, 
        user_id: UUID, 
        feature: str,
        source: Optional[EntitlementSource] = None
    ) -> bool:
        """Revoke specific entitlement"""
        query = """
            UPDATE entitlements 
            SET active = false 
            WHERE user_id = %s AND feature = %s
        """
        params = [str(user_id), feature]
        
        if source:
            query += " AND source = %s"
            params.append(source.value)
        
        await self.db.execute_query(query, params)
        return True


# =====================================================
# CONVENIENCE FUNCTIONS
# =====================================================

async def check_user_access(user_id: UUID, feature: str) -> bool:
    """
    Quick check if user has access to feature
    
    This is the main function apps should call for feature gating.
    """
    # This would need to be initialized with a database manager
    # For now, return a placeholder
    return False


async def get_user_subscription_status(user_id: UUID) -> Dict[str, Any]:
    """Get user's subscription status for display"""
    # Placeholder implementation
    return {
        "has_subscription": False,
        "provider": None,
        "status": "none",
        "expires_at": None
    }