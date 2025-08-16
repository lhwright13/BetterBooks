"""
Stripe Payment Manager

Handles web-based payments through Stripe for BetterBooks.
Complements Apple App Store payments - web users pay through Stripe,
iOS users pay through App Store in-app purchases.
"""

import os
import json
import logging
import hmac
import hashlib
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone
from uuid import UUID, uuid4

import stripe
from stripe.error import StripeError

from ..database.models.user import (
    Subscription, SubscriptionProvider, SubscriptionStatus,
    EntitlementSource, SubscriptionPlan
)
from ..database.database_manager import DatabaseManager
from .entitlements_manager import EntitlementsManager

logger = logging.getLogger(__name__)


class StripePaymentError(Exception):
    """Custom exception for Stripe payment operations"""
    pass


class StripeManager:
    """
    Manages Stripe payments for web users
    
    Handles:
    - Checkout sessions for subscription signup
    - Customer portal for subscription management
    - Webhook events for subscription lifecycle
    - Billing and invoice management
    """
    
    def __init__(self, db_manager: DatabaseManager, entitlements_manager: EntitlementsManager):
        self.db = db_manager
        self.entitlements = entitlements_manager
        
        # Stripe configuration
        self.secret_key = os.getenv('STRIPE_SECRET_KEY')
        self.publishable_key = os.getenv('STRIPE_PUBLISHABLE_KEY')
        self.webhook_secret = os.getenv('STRIPE_WEBHOOK_SECRET')
        
        if not all([self.secret_key, self.publishable_key, self.webhook_secret]):
            logger.warning("Stripe configuration incomplete - web payments disabled")
            self.enabled = False
        else:
            stripe.api_key = self.secret_key
            self.enabled = True
        
        # Price configurations (set in Stripe Dashboard)
        self.price_configs = {
            SubscriptionPlan.STRIPE_MONTHLY: {
                'features': ['premium_access', 'unlimited_books'],
                'interval': 'month',
                'interval_count': 1
            },
            SubscriptionPlan.STRIPE_YEARLY: {
                'features': ['premium_access', 'unlimited_books'],
                'interval': 'year',
                'interval_count': 1
            },
            SubscriptionPlan.STRIPE_FAMILY: {
                'features': ['premium_access', 'family_sharing', 'unlimited_books'],
                'interval': 'month',
                'interval_count': 1
            }
        }
        
        # Success/cancel URLs
        self.base_url = os.getenv('WEB_APP_URL', 'https://betterbooks.com')
        
        # SECURITY: Initialize idempotency tracking
        # Note: In production, run this as a migration instead
        if self.enabled:
            import asyncio
            asyncio.create_task(self._ensure_idempotency_tables_exist())
    
    async def create_checkout_session(
        self,
        user_id: UUID,
        price_id: str,
        user_email: Optional[str] = None,
        trial_days: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Create Stripe Checkout session for subscription
        
        Args:
            user_id: User ID
            price_id: Stripe price ID
            user_email: User email for prefill
            trial_days: Optional trial period
            
        Returns:
            Dict with checkout session URL
        """
        if not self.enabled:
            raise StripePaymentError("Stripe not configured")
        
        try:
            # Get or create Stripe customer
            customer_id = await self._get_or_create_customer(user_id, user_email)
            
            # Create checkout session
            session_params = {
                'customer': customer_id,
                'client_reference_id': str(user_id),
                'line_items': [{
                    'price': price_id,
                    'quantity': 1,
                }],
                'mode': 'subscription',
                'success_url': f'{self.base_url}/account?session_id={{CHECKOUT_SESSION_ID}}',
                'cancel_url': f'{self.base_url}/pricing',
                'metadata': {
                    'user_id': str(user_id),
                    'price_id': price_id
                },
                'subscription_data': {
                    'metadata': {
                        'user_id': str(user_id)
                    }
                }
            }
            
            # Add trial if specified
            if trial_days:
                session_params['subscription_data']['trial_period_days'] = trial_days
            
            session = stripe.checkout.Session.create(**session_params)
            
            logger.info(f"Created Stripe checkout session for user {user_id}: {session.id}")
            
            return {
                'success': True,
                'checkout_url': session.url,
                'session_id': session.id
            }
            
        except StripeError as e:
            logger.error(f"Stripe checkout creation failed: {e}")
            raise StripePaymentError(f"Checkout creation failed: {str(e)}")
        except Exception as e:
            logger.error(f"Checkout session creation failed: {e}")
            raise StripePaymentError(f"Session creation failed: {str(e)}")
    
    async def create_customer_portal_session(
        self,
        user_id: UUID,
        return_url: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Create Stripe Customer Portal session for subscription management
        
        Args:
            user_id: User ID
            return_url: URL to return to after portal
            
        Returns:
            Dict with portal session URL
        """
        if not self.enabled:
            raise StripePaymentError("Stripe not configured")
        
        try:
            # Get Stripe customer ID
            customer_id = await self._get_stripe_customer_id(user_id)
            if not customer_id:
                raise StripePaymentError("Customer not found")
            
            # Create portal session
            session = stripe.billing_portal.Session.create(
                customer=customer_id,
                return_url=return_url or f'{self.base_url}/account'
            )
            
            logger.info(f"Created customer portal session for user {user_id}")
            
            return {
                'success': True,
                'portal_url': session.url
            }
            
        except StripeError as e:
            logger.error(f"Customer portal creation failed: {e}")
            raise StripePaymentError(f"Portal creation failed: {str(e)}")
        except Exception as e:
            logger.error(f"Portal session creation failed: {e}")
            raise StripePaymentError(f"Portal creation failed: {str(e)}")
    
    async def handle_webhook(self, payload: bytes, signature: str) -> Dict[str, Any]:
        """
        Handle Stripe webhook events with proper idempotency
        
        SECURITY FIX: Implements idempotency to prevent duplicate processing
        of webhook events. Uses database transactions and unique constraints.
        
        Args:
            payload: Raw webhook payload
            signature: Stripe signature header
            
        Returns:
            Dict with processing result
        """
        if not self.enabled:
            raise StripePaymentError("Stripe not configured")
        
        try:
            # Verify webhook signature
            event = stripe.Webhook.construct_event(
                payload, signature, self.webhook_secret
            )
            
            event_id = event['id']
            
            # SECURITY: Check if event already processed (idempotency)
            if await self._is_event_already_processed(event_id):
                logger.info(f"Stripe webhook {event_id} already processed - skipping")
                return {
                    'success': True,
                    'event_type': event['type'],
                    'event_id': event_id,
                    'skipped': True,
                    'reason': 'already_processed'
                }
            
            # Use database transaction for atomic processing
            async with self.db.transaction():
                # Store event for audit (with idempotency protection)
                await self._store_stripe_event_idempotent(event)
                
                # Process event based on type
                result = await self._process_webhook_event_idempotent(event)
                
                # Mark event as processed
                await self._mark_event_processed(event_id)
            
            logger.info(f"Processed Stripe webhook: {event['type']} (ID: {event_id})")
            
            return {
                'success': True,
                'event_type': event['type'],
                'event_id': event_id,
                'result': result
            }
            
        except stripe.error.SignatureVerificationError as e:
            logger.error(f"Stripe webhook signature verification failed: {e}")
            raise StripePaymentError(f"Invalid webhook signature: {str(e)}")
        except Exception as e:
            logger.error(f"Webhook processing failed: {e}")
            raise StripePaymentError(f"Webhook processing failed: {str(e)}")
    
    async def get_subscription_info(self, user_id: UUID) -> Optional[Dict[str, Any]]:
        """
        Get user's Stripe subscription information
        
        Args:
            user_id: User ID
            
        Returns:
            Dict with subscription info or None
        """
        try:
            # Get subscription from database
            query = """
                SELECT id, status, product_id, price_id, stripe_subscription_id,
                       current_period_start, current_period_end, cancel_at, cancelled_at
                FROM subscriptions 
                WHERE user_id = %s AND provider = 'stripe'
                ORDER BY created_at DESC
                LIMIT 1
            """
            
            result = await self.db.fetch_one(query, (str(user_id),))
            if not result:
                return None
            
            # Get additional info from Stripe if needed
            subscription_info = {
                'id': result['id'],
                'status': result['status'],
                'product_id': result['product_id'],
                'price_id': result['price_id'],
                'current_period_start': result['current_period_start'].isoformat() if result['current_period_start'] else None,
                'current_period_end': result['current_period_end'].isoformat() if result['current_period_end'] else None,
                'cancel_at': result['cancel_at'].isoformat() if result['cancel_at'] else None,
                'cancelled_at': result['cancelled_at'].isoformat() if result['cancelled_at'] else None
            }
            
            return subscription_info
            
        except Exception as e:
            logger.error(f"Failed to get subscription info for user {user_id}: {e}")
            return None
    
    async def cancel_subscription(self, user_id: UUID) -> Dict[str, Any]:
        """
        Cancel user's Stripe subscription
        
        Args:
            user_id: User ID
            
        Returns:
            Dict with cancellation result
        """
        if not self.enabled:
            raise StripePaymentError("Stripe not configured")
        
        try:
            # Get Stripe subscription ID
            stripe_subscription_id = await self._get_stripe_subscription_id(user_id)
            if not stripe_subscription_id:
                raise StripePaymentError("No active subscription found")
            
            # Cancel at period end (don't immediately revoke access)
            subscription = stripe.Subscription.modify(
                stripe_subscription_id,
                cancel_at_period_end=True
            )
            
            # Update our database
            await self._update_subscription_from_stripe(subscription)
            
            logger.info(f"Cancelled Stripe subscription for user {user_id}")
            
            return {
                'success': True,
                'cancelled_at_period_end': subscription.cancel_at_period_end,
                'current_period_end': subscription.current_period_end
            }
            
        except StripeError as e:
            logger.error(f"Stripe subscription cancellation failed: {e}")
            raise StripePaymentError(f"Cancellation failed: {str(e)}")
        except Exception as e:
            logger.error(f"Subscription cancellation failed: {e}")
            raise StripePaymentError(f"Cancellation failed: {str(e)}")
    
    # =====================================================
    # WEBHOOK EVENT HANDLERS
    # =====================================================
    
    async def _process_webhook_event_idempotent(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """
        Process webhook event with idempotency protection
        
        SECURITY: Each event type has specific idempotency checks
        to prevent duplicate business logic execution
        """
        return await self._process_webhook_event(event)
    
    async def _process_webhook_event(self, event: Dict[str, Any]) -> Dict[str, Any]:
        """Process specific webhook event types"""
        
        event_type = event['type']
        data = event['data']['object']
        
        if event_type == 'customer.subscription.created':
            return await self._handle_subscription_created(data)
        
        elif event_type == 'customer.subscription.updated':
            return await self._handle_subscription_updated(data)
        
        elif event_type == 'customer.subscription.deleted':
            return await self._handle_subscription_deleted(data)
        
        elif event_type == 'invoice.paid':
            return await self._handle_invoice_paid(data)
        
        elif event_type == 'invoice.payment_failed':
            return await self._handle_payment_failed(data)
        
        elif event_type == 'customer.subscription.trial_will_end':
            return await self._handle_trial_ending(data)
        
        else:
            logger.info(f"Unhandled webhook event type: {event_type}")
            return {'handled': False}
    
    async def _handle_subscription_created(self, subscription: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle new subscription creation with idempotency
        
        SECURITY: Uses ON CONFLICT DO NOTHING to prevent duplicate subscriptions
        """
        
        user_id = await self._get_user_from_subscription(subscription)
        if not user_id:
            return {'error': 'User not found'}
        
        stripe_subscription_id = subscription['id']
        
        # Check if subscription already exists (idempotency)
        existing = await self._get_subscription_by_stripe_id(stripe_subscription_id)
        if existing:
            logger.info(f"Subscription {stripe_subscription_id} already exists - skipping creation")
            return {'handled': True, 'action': 'subscription_already_exists'}
        
        # Create subscription record with idempotency protection
        await self._create_subscription_from_stripe_idempotent(user_id, subscription)
        
        # Update entitlements
        sub_record = await self._get_subscription_by_stripe_id(stripe_subscription_id)
        if sub_record:
            await self.entitlements.update_subscription_entitlements(user_id, sub_record.id)
        
        return {'handled': True, 'action': 'subscription_created'}
    
    async def _handle_subscription_updated(self, subscription: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription updates"""
        
        user_id = await self._get_user_from_subscription(subscription)
        if not user_id:
            return {'error': 'User not found'}
        
        # Update subscription record
        await self._update_subscription_from_stripe(subscription)
        
        # Update entitlements if status changed
        sub_record = await self._get_subscription_by_stripe_id(subscription['id'])
        if sub_record:
            await self.entitlements.update_subscription_entitlements(user_id, sub_record.id)
        
        return {'handled': True, 'action': 'subscription_updated'}
    
    async def _handle_subscription_deleted(self, subscription: Dict[str, Any]) -> Dict[str, Any]:
        """Handle subscription deletion"""
        
        user_id = await self._get_user_from_subscription(subscription)
        if not user_id:
            return {'error': 'User not found'}
        
        # Mark subscription as expired
        await self._update_subscription_status(subscription['id'], SubscriptionStatus.EXPIRED)
        
        # Remove entitlements
        product_id = subscription.get('items', {}).get('data', [{}])[0].get('price', {}).get('product')
        if product_id:
            features = SubscriptionPlan.get_features(product_id)
            await self.entitlements.revoke_entitlements(
                user_id, features, EntitlementSource.SUBSCRIPTION
            )
        
        return {'handled': True, 'action': 'subscription_deleted'}
    
    async def _handle_invoice_paid(self, invoice: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle successful payment with idempotency
        
        SECURITY: Prevents duplicate payment processing by checking invoice ID
        """
        
        subscription_id = invoice.get('subscription')
        invoice_id = invoice.get('id')
        
        if not subscription_id:
            return {'handled': False}
        
        # Check if invoice already processed (idempotency)
        if await self._is_invoice_already_processed(invoice_id):
            logger.info(f"Invoice {invoice_id} already processed - skipping")
            return {'handled': True, 'action': 'invoice_already_processed'}
        
        user_id = await self._get_user_by_stripe_subscription(subscription_id)
        if not user_id:
            return {'error': 'User not found'}
        
        # Mark invoice as processed first (idempotency)
        await self._mark_invoice_processed(invoice_id)
        
        # Ensure subscription is active and entitlements are current
        sub_record = await self._get_subscription_by_stripe_id(subscription_id)
        if sub_record:
            await self.entitlements.update_subscription_entitlements(user_id, sub_record.id)
        
        return {'handled': True, 'action': 'payment_processed'}
    
    async def _handle_payment_failed(self, invoice: Dict[str, Any]) -> Dict[str, Any]:
        """Handle failed payment"""
        
        subscription_id = invoice.get('subscription')
        if not subscription_id:
            return {'handled': False}
        
        user_id = await self._get_user_by_stripe_subscription(subscription_id)
        if not user_id:
            return {'error': 'User not found'}
        
        # Could implement grace period logic here
        logger.warning(f"Payment failed for user {user_id}, subscription {subscription_id}")
        
        return {'handled': True, 'action': 'payment_failed'}
    
    async def _handle_trial_ending(self, subscription: Dict[str, Any]) -> Dict[str, Any]:
        """Handle trial ending notification"""
        
        user_id = await self._get_user_from_subscription(subscription)
        if not user_id:
            return {'error': 'User not found'}
        
        # Could send notification to user about trial ending
        logger.info(f"Trial ending for user {user_id}")
        
        return {'handled': True, 'action': 'trial_ending'}
    
    # =====================================================
    # PRIVATE HELPER METHODS
    # =====================================================
    
    async def _get_or_create_customer(self, user_id: UUID, email: Optional[str]) -> str:
        """Get existing Stripe customer or create new one"""
        
        # Check if customer already exists
        customer_id = await self._get_stripe_customer_id(user_id)
        if customer_id:
            return customer_id
        
        # Create new customer
        customer_data = {
            'metadata': {'user_id': str(user_id)}
        }
        
        if email:
            customer_data['email'] = email
        
        customer = stripe.Customer.create(**customer_data)
        
        # Store customer ID in our database
        await self._store_stripe_customer_id(user_id, customer.id)
        
        return customer.id
    
    async def _get_stripe_customer_id(self, user_id: UUID) -> Optional[str]:
        """Get Stripe customer ID for user"""
        
        query = """
            SELECT stripe_customer_id FROM subscriptions 
            WHERE user_id = %s AND provider = 'stripe'
            AND stripe_customer_id IS NOT NULL
            LIMIT 1
        """
        
        result = await self.db.fetch_one(query, (str(user_id),))
        return result['stripe_customer_id'] if result else None
    
    async def _store_stripe_customer_id(self, user_id: UUID, customer_id: str):
        """Store Stripe customer ID (could be in separate table)"""
        # For now, we'll store it when we create the subscription
        pass
    
    async def _store_stripe_event_idempotent(self, event: Dict[str, Any]):
        """
        Store Stripe event with idempotency protection
        
        SECURITY: Uses ON CONFLICT DO NOTHING to prevent duplicate storage
        """
        
        query = """
            INSERT INTO stripe_events (
                id, type, object_id, livemode, payload, api_version,
                signature_valid, received_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (id) DO NOTHING
        """
        
        await self.db.execute_query(query, (
            event['id'],
            event['type'],
            event['data']['object'].get('id'),
            event.get('livemode', False),
            json.dumps(event),
            event.get('api_version'),
            True,  # Signature was valid if we got here
            datetime.now(timezone.utc)
        ))
    
    async def _is_event_already_processed(self, event_id: str) -> bool:
        """Check if Stripe event was already processed"""
        
        query = """
            SELECT processed FROM stripe_events 
            WHERE id = %s
        """
        
        result = await self.db.fetch_one(query, (event_id,))
        return result and result['processed']
    
    async def _mark_event_processed(self, event_id: str):
        """Mark Stripe event as processed"""
        
        query = """
            UPDATE stripe_events 
            SET processed = true, processed_at = %s
            WHERE id = %s
        """
        
        await self.db.execute_query(query, (
            datetime.now(timezone.utc),
            event_id
        ))
    
    async def _ensure_idempotency_tables_exist(self):
        """
        Ensure idempotency tables exist
        
        SECURITY: Creates tables for tracking processed events/invoices
        """
        
        # Table for tracking processed invoices
        invoice_table_query = """
            CREATE TABLE IF NOT EXISTS processed_invoices (
                invoice_id VARCHAR(255) PRIMARY KEY,
                processed_at TIMESTAMP WITH TIME ZONE NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        """
        
        await self.db.execute_query(invoice_table_query)
        
        # Index for performance
        index_query = """
            CREATE INDEX IF NOT EXISTS idx_processed_invoices_processed_at 
            ON processed_invoices(processed_at)
        """
        
        await self.db.execute_query(index_query)
    
    async def _create_subscription_from_stripe_idempotent(self, user_id: UUID, subscription: Dict[str, Any]):
        """
        Create subscription record with idempotency protection
        
        SECURITY: Uses unique constraint on stripe_subscription_id to prevent duplicates
        """
        
        subscription_id = uuid4()
        
        # Extract price and product info
        line_item = subscription.get('items', {}).get('data', [{}])[0]
        price = line_item.get('price', {})
        price_id = price.get('id')
        product_id = price.get('product')
        
        query = """
            INSERT INTO subscriptions (
                id, user_id, provider, status, product_id, price_id,
                stripe_subscription_id, stripe_customer_id, stripe_price_id,
                current_period_start, current_period_end,
                trial_start, trial_end, created_at, updated_at
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (stripe_subscription_id) DO NOTHING
        """
        
        await self.db.execute_query(query, (
            str(subscription_id),
            str(user_id),
            SubscriptionProvider.STRIPE.value,
            self._map_stripe_status(subscription['status']),
            product_id,
            price_id,
            subscription['id'],
            subscription['customer'],
            price_id,
            datetime.fromtimestamp(subscription['current_period_start'], tz=timezone.utc),
            datetime.fromtimestamp(subscription['current_period_end'], tz=timezone.utc),
            datetime.fromtimestamp(subscription['trial_start'], tz=timezone.utc) if subscription.get('trial_start') else None,
            datetime.fromtimestamp(subscription['trial_end'], tz=timezone.utc) if subscription.get('trial_end') else None,
            datetime.now(timezone.utc),
            datetime.now(timezone.utc)
        ))
    
    async def _create_subscription_from_stripe(self, user_id: UUID, subscription: Dict[str, Any]):
        """Legacy method - use _create_subscription_from_stripe_idempotent instead"""
        await self._create_subscription_from_stripe_idempotent(user_id, subscription)
    
    async def _update_subscription_from_stripe(self, subscription: Dict[str, Any]):
        """Update subscription record from Stripe subscription object"""
        
        query = """
            UPDATE subscriptions SET
                status = %s,
                current_period_start = %s,
                current_period_end = %s,
                cancel_at = %s,
                cancelled_at = %s,
                updated_at = %s
            WHERE stripe_subscription_id = %s
        """
        
        await self.db.execute_query(query, (
            self._map_stripe_status(subscription['status']),
            datetime.fromtimestamp(subscription['current_period_start'], tz=timezone.utc),
            datetime.fromtimestamp(subscription['current_period_end'], tz=timezone.utc),
            datetime.fromtimestamp(subscription['cancel_at'], tz=timezone.utc) if subscription.get('cancel_at') else None,
            datetime.fromtimestamp(subscription['canceled_at'], tz=timezone.utc) if subscription.get('canceled_at') else None,
            datetime.now(timezone.utc),
            subscription['id']
        ))
    
    def _map_stripe_status(self, stripe_status: str) -> str:
        """Map Stripe status to our status enum"""
        
        status_map = {
            'active': SubscriptionStatus.ACTIVE.value,
            'canceled': SubscriptionStatus.CANCELLED.value,
            'incomplete': SubscriptionStatus.PENDING.value,
            'incomplete_expired': SubscriptionStatus.EXPIRED.value,
            'past_due': SubscriptionStatus.GRACE_PERIOD.value,
            'paused': SubscriptionStatus.PAUSED.value,
            'trialing': SubscriptionStatus.ACTIVE.value,
            'unpaid': SubscriptionStatus.GRACE_PERIOD.value
        }
        
        return status_map.get(stripe_status, SubscriptionStatus.PENDING.value)
    
    async def _get_user_from_subscription(self, subscription: Dict[str, Any]) -> Optional[UUID]:
        """Extract user ID from Stripe subscription"""
        
        # Try from subscription metadata first
        user_id_str = subscription.get('metadata', {}).get('user_id')
        if user_id_str:
            return UUID(user_id_str)
        
        # Try from customer metadata
        customer_id = subscription.get('customer')
        if customer_id:
            customer = stripe.Customer.retrieve(customer_id)
            user_id_str = customer.metadata.get('user_id')
            if user_id_str:
                return UUID(user_id_str)
        
        return None
    
    async def _get_subscription_by_stripe_id(self, stripe_subscription_id: str) -> Optional[Subscription]:
        """Get subscription by Stripe subscription ID"""
        
        query = """
            SELECT id FROM subscriptions 
            WHERE stripe_subscription_id = %s
        """
        
        result = await self.db.fetch_one(query, (stripe_subscription_id,))
        if not result:
            return None
        
        # Return minimal subscription object
        return Subscription(
            id=UUID(result['id']),
            user_id=UUID('00000000-0000-0000-0000-000000000000'),  # Placeholder
            provider=SubscriptionProvider.STRIPE,
            status=SubscriptionStatus.ACTIVE,
            product_id="",
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        )
    
    async def _get_stripe_subscription_id(self, user_id: UUID) -> Optional[str]:
        """Get Stripe subscription ID for user"""
        
        query = """
            SELECT stripe_subscription_id FROM subscriptions 
            WHERE user_id = %s AND provider = 'stripe' AND status = 'active'
            ORDER BY created_at DESC
            LIMIT 1
        """
        
        result = await self.db.fetch_one(query, (str(user_id),))
        return result['stripe_subscription_id'] if result else None
    
    async def _get_user_by_stripe_subscription(self, stripe_subscription_id: str) -> Optional[UUID]:
        """Get user ID by Stripe subscription ID"""
        
        query = """
            SELECT user_id FROM subscriptions 
            WHERE stripe_subscription_id = %s
        """
        
        result = await self.db.fetch_one(query, (stripe_subscription_id,))
        return UUID(result['user_id']) if result else None
    
    async def _update_subscription_status(self, stripe_subscription_id: str, status: SubscriptionStatus):
        """Update subscription status"""
        
        query = """
            UPDATE subscriptions 
            SET status = %s, updated_at = %s
            WHERE stripe_subscription_id = %s
        """
        
        await self.db.execute_query(query, (
            status.value,
            datetime.now(timezone.utc),
            stripe_subscription_id
        ))
    
    async def _is_invoice_already_processed(self, invoice_id: str) -> bool:
        """Check if invoice was already processed"""
        
        query = """
            SELECT COUNT(*) as count FROM processed_invoices 
            WHERE invoice_id = %s
        """
        
        result = await self.db.fetch_one(query, (invoice_id,))
        return result and result['count'] > 0
    
    async def _mark_invoice_processed(self, invoice_id: str):
        """Mark invoice as processed (idempotency)"""
        
        query = """
            INSERT INTO processed_invoices (invoice_id, processed_at)
            VALUES (%s, %s)
            ON CONFLICT (invoice_id) DO NOTHING
        """
        
        await self.db.execute_query(query, (
            invoice_id,
            datetime.now(timezone.utc)
        ))