"""
Credit Manager

Manages the credit allocation system for EchoWright subscribers.
Handles monthly credit allocation, expiration, and integration with 
subscription lifecycle events.
"""

import logging
from typing import Dict, List, Optional, Any
from uuid import UUID, uuid4
from decimal import Decimal
from datetime import datetime, timezone, timedelta
from dateutil.relativedelta import relativedelta

from ..database.database_manager import DatabaseManager
from .models import (
    UserCredit, CreditTransaction, CreditTransactionType
)
from .purchase_service import PurchaseService

logger = logging.getLogger(__name__)


class CreditManager:
    """
    Manages credit allocation and lifecycle for subscription users
    """
    
    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager
    
    async def allocate_monthly_credits(self, user_id: UUID, subscription_id: UUID) -> Dict[str, Any]:
        """
        Allocate monthly subscription credits to a user
        
        Args:
            user_id: User receiving credits
            subscription_id: Associated subscription ID
            
        Returns:
            Allocation result details
        """
        try:
            # Get user's current credit settings
            user_credits = await self._get_or_create_user_credits(user_id)
            
            # Calculate credits to allocate based on subscription tier
            credits_to_allocate = user_credits.monthly_credits
            
            # Check if user is due for credits
            now = datetime.now(timezone.utc)
            if user_credits.next_credit_date and user_credits.next_credit_date > now.date():
                logger.warning(f"User {user_id} not yet due for credits")
                return {
                    'success': False,
                    'reason': 'not_due',
                    'next_credit_date': user_credits.next_credit_date.isoformat()
                }
            
            async with self.db.transaction():
                # Allocate credits
                new_balance = user_credits.credits_available + credits_to_allocate
                
                # Create credit transaction
                transaction_id = uuid4()
                transaction_query = """
                    INSERT INTO credit_transactions
                    (id, user_id, transaction_type, credits_change, balance_after,
                     subscription_id, description)
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                """
                
                await self.db.execute_query(transaction_query, [
                    str(transaction_id), str(user_id), CreditTransactionType.EARNED.value,
                    credits_to_allocate, new_balance, str(subscription_id),
                    f"Monthly subscription credit allocation"
                ])
                
                # Update next credit date
                next_credit_date = now.date() + relativedelta(months=1)
                
                update_query = """
                    UPDATE user_credits SET
                        credits_available = $1,
                        next_credit_date = $2,
                        updated_at = NOW()
                    WHERE user_id = $3
                """
                
                await self.db.execute_query(update_query, [
                    new_balance, next_credit_date, str(user_id)
                ])
            
            logger.info(f"Allocated {credits_to_allocate} credits to user {user_id}")
            
            return {
                'success': True,
                'credits_allocated': credits_to_allocate,
                'new_balance': new_balance,
                'next_credit_date': next_credit_date.isoformat(),
                'transaction_id': str(transaction_id)
            }
            
        except Exception as e:
            logger.error(f"Failed to allocate monthly credits for user {user_id}: {e}")
            raise
    
    async def handle_subscription_created(
        self, 
        user_id: UUID, 
        subscription_id: UUID,
        subscription_plan: str
    ) -> Dict[str, Any]:
        """
        Handle new subscription creation and initial credit allocation
        
        Args:
            user_id: New subscriber
            subscription_id: Subscription ID
            subscription_plan: Plan type (monthly, annual, family, etc.)
            
        Returns:
            Initial setup result
        """
        try:
            # Determine monthly credit allocation based on plan
            monthly_credits = self._get_credits_for_plan(subscription_plan)
            
            async with self.db.transaction():
                # Update or create user credits record
                upsert_query = """
                    INSERT INTO user_credits 
                    (id, user_id, credits_available, monthly_credits, next_credit_date)
                    VALUES ($1, $2, $3, $4, $5)
                    ON CONFLICT (user_id) DO UPDATE SET
                        monthly_credits = $4,
                        next_credit_date = COALESCE(user_credits.next_credit_date, $5),
                        updated_at = NOW()
                """
                
                # Give immediate credit allocation for new subscribers
                next_credit_date = datetime.now(timezone.utc).date() + relativedelta(months=1)
                
                await self.db.execute_query(upsert_query, [
                    str(uuid4()), str(user_id), monthly_credits, 
                    monthly_credits, next_credit_date
                ])
                
                # Create welcome credit transaction
                transaction_id = uuid4()
                transaction_query = """
                    INSERT INTO credit_transactions
                    (id, user_id, transaction_type, credits_change, balance_after,
                     subscription_id, description)
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                """
                
                await self.db.execute_query(transaction_query, [
                    str(transaction_id), str(user_id), CreditTransactionType.EARNED.value,
                    monthly_credits, monthly_credits, str(subscription_id),
                    f"Welcome credit for {subscription_plan} subscription"
                ])
            
            logger.info(f"Subscription created for user {user_id}: {monthly_credits} monthly credits")
            
            return {
                'success': True,
                'monthly_credits': monthly_credits,
                'initial_balance': monthly_credits,
                'next_credit_date': next_credit_date.isoformat()
            }
            
        except Exception as e:
            logger.error(f"Failed to handle subscription creation: {e}")
            raise
    
    async def handle_subscription_cancelled(
        self, 
        user_id: UUID, 
        subscription_id: UUID,
        immediate: bool = False
    ) -> Dict[str, Any]:
        """
        Handle subscription cancellation and credit policy
        
        Args:
            user_id: User whose subscription was cancelled
            subscription_id: Cancelled subscription ID
            immediate: Whether cancellation is immediate or at period end
            
        Returns:
            Cancellation handling result
        """
        try:
            async with self.db.transaction():
                if immediate:
                    # Immediate cancellation - reset monthly credits
                    update_query = """
                        UPDATE user_credits SET
                            monthly_credits = 0,
                            next_credit_date = NULL,
                            updated_at = NOW()
                        WHERE user_id = $1
                    """
                    
                    await self.db.execute_query(update_query, [str(user_id)])
                    
                    # Log cancellation transaction
                    transaction_id = uuid4()
                    transaction_query = """
                        INSERT INTO credit_transactions
                        (id, user_id, transaction_type, credits_change, balance_after,
                         subscription_id, description)
                        VALUES ($1, $2, 'cancelled', 0, (
                             SELECT credits_available FROM user_credits WHERE user_id = $2
                         ), $3, $4)
                    """
                    
                    await self.db.execute_query(transaction_query, [
                        str(transaction_id), str(user_id), str(subscription_id),
                        "Subscription cancelled - no more monthly credits"
                    ])
                    
                    logger.info(f"Immediate subscription cancellation for user {user_id}")
                    
                else:
                    # Cancellation at period end - let current credits expire naturally
                    logger.info(f"Subscription will cancel at period end for user {user_id}")
            
            return {
                'success': True,
                'immediate': immediate,
                'credits_retained': not immediate
            }
            
        except Exception as e:
            logger.error(f"Failed to handle subscription cancellation: {e}")
            raise
    
    async def expire_old_credits(self, days_old: int = 365) -> int:
        """
        Expire credits older than specified days (typically 1 year)
        
        Args:
            days_old: Credits older than this many days will expire
            
        Returns:
            Number of users affected
        """
        try:
            cutoff_date = datetime.now(timezone.utc) - timedelta(days=days_old)
            
            # Find users with expiring credits
            expiring_query = """
                SELECT DISTINCT ct.user_id, 
                       SUM(ct.credits_change) FILTER (WHERE ct.credits_change > 0 AND ct.created_at < $1) as expiring_credits
                FROM credit_transactions ct
                WHERE ct.transaction_type = 'earned'
                AND ct.created_at < $1
                AND NOT EXISTS (
                    SELECT 1 FROM credit_transactions ct2 
                    WHERE ct2.user_id = ct.user_id 
                    AND ct2.transaction_type = 'expired'
                    AND ct2.created_at >= $1
                )
                GROUP BY ct.user_id
                HAVING SUM(ct.credits_change) FILTER (WHERE ct.credits_change > 0 AND ct.created_at < $1) > 0
            """
            
            expiring_results = await self.db.fetch_all(expiring_query, [cutoff_date])
            
            users_affected = 0
            
            for row in expiring_results:
                user_id = UUID(row['user_id'])
                expiring_credits = row['expiring_credits']
                
                if expiring_credits > 0:
                    await self._expire_user_credits(user_id, expiring_credits)
                    users_affected += 1
            
            logger.info(f"Expired credits for {users_affected} users")
            return users_affected
            
        except Exception as e:
            logger.error(f"Failed to expire old credits: {e}")
            raise
    
    async def purchase_credits(
        self,
        user_id: UUID,
        credits: int,
        amount_paid: Decimal,
        payment_transaction_id: str
    ) -> Dict[str, Any]:
        """
        Process credit purchase with real money
        
        Args:
            user_id: User purchasing credits
            credits: Number of credits purchased
            amount_paid: Amount paid for credits
            payment_transaction_id: Payment processor transaction ID
            
        Returns:
            Purchase result
        """
        try:
            user_credits = await self._get_or_create_user_credits(user_id)
            
            async with self.db.transaction():
                new_balance = user_credits.credits_available + credits
                new_purchased_total = user_credits.credits_purchased + credits
                new_spent_total = user_credits.total_spent + amount_paid
                
                # Create purchase transaction
                transaction_id = uuid4()
                transaction_query = """
                    INSERT INTO credit_transactions
                    (id, user_id, transaction_type, credits_change, balance_after,
                     payment_transaction_id, description)
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                """
                
                await self.db.execute_query(transaction_query, [
                    str(transaction_id), str(user_id), CreditTransactionType.PURCHASED.value,
                    credits, new_balance, payment_transaction_id,
                    f"Purchased {credits} credits for ${amount_paid}"
                ])
                
                # Update user credits record
                update_query = """
                    UPDATE user_credits SET
                        credits_available = $1,
                        credits_purchased = $2,
                        total_spent = $3,
                        updated_at = NOW()
                    WHERE user_id = $4
                """
                
                await self.db.execute_query(update_query, [
                    new_balance, new_purchased_total, float(new_spent_total), str(user_id)
                ])
            
            logger.info(f"User {user_id} purchased {credits} credits for ${amount_paid}")
            
            return {
                'success': True,
                'credits_purchased': credits,
                'amount_paid': float(amount_paid),
                'new_balance': new_balance,
                'transaction_id': str(transaction_id)
            }
            
        except Exception as e:
            logger.error(f"Failed to process credit purchase: {e}")
            raise
    
    async def get_users_due_for_credits(self) -> List[Dict[str, Any]]:
        """
        Get list of users due for monthly credit allocation
        
        Returns:
            List of users with subscription info
        """
        try:
            query = """
                SELECT 
                    uc.user_id,
                    uc.monthly_credits,
                    uc.next_credit_date,
                    s.id as subscription_id,
                    s.status as subscription_status
                FROM user_credits uc
                JOIN subscriptions s ON uc.user_id = s.user_id
                WHERE uc.monthly_credits > 0
                AND uc.next_credit_date <= CURRENT_DATE
                AND s.status = 'active'
            """
            
            results = await self.db.fetch_all(query)
            
            users_due = []
            for row in results:
                users_due.append({
                    'user_id': UUID(row['user_id']),
                    'monthly_credits': row['monthly_credits'],
                    'next_credit_date': row['next_credit_date'],
                    'subscription_id': UUID(row['subscription_id']),
                    'subscription_status': row['subscription_status']
                })
            
            logger.info(f"Found {len(users_due)} users due for credit allocation")
            return users_due
            
        except Exception as e:
            logger.error(f"Failed to get users due for credits: {e}")
            raise
    
    async def bulk_allocate_monthly_credits(self) -> Dict[str, Any]:
        """
        Bulk process monthly credit allocation for all due users
        
        Returns:
            Allocation summary
        """
        try:
            users_due = await self.get_users_due_for_credits()
            
            successful = 0
            failed = 0
            
            for user_info in users_due:
                try:
                    await self.allocate_monthly_credits(
                        user_info['user_id'],
                        user_info['subscription_id']
                    )
                    successful += 1
                except Exception as e:
                    logger.error(f"Failed to allocate credits for user {user_info['user_id']}: {e}")
                    failed += 1
            
            logger.info(f"Bulk credit allocation: {successful} successful, {failed} failed")
            
            return {
                'success': True,
                'total_users': len(users_due),
                'successful': successful,
                'failed': failed
            }
            
        except Exception as e:
            logger.error(f"Failed bulk credit allocation: {e}")
            raise
    
    def _get_credits_for_plan(self, subscription_plan: str) -> int:
        """
        Determine monthly credit allocation based on subscription plan
        
        Args:
            subscription_plan: Plan identifier
            
        Returns:
            Number of monthly credits
        """
        plan_credits = {
            'monthly': 1,
            'annual': 1,  # Same as monthly but paid yearly
            'family': 2,  # Family plans get more credits
            'premium': 2,  # Premium tier
            'student': 1,  # Student discount but same credits
            'ios_monthly': 1,
            'ios_yearly': 1,
            'ios_family': 2,
        }
        
        return plan_credits.get(subscription_plan.lower(), 1)  # Default to 1 credit
    
    async def _get_or_create_user_credits(self, user_id: UUID) -> UserCredit:
        """Get or create user credits record"""
        try:
            query = """
                SELECT 
                    id, user_id, credits_available, credits_used, credits_gifted, credits_received,
                    next_credit_date, monthly_credits, credits_purchased, total_spent,
                    created_at, updated_at
                FROM user_credits
                WHERE user_id = $1
            """
            
            result = await self.db.fetch_one(query, [str(user_id)])
            
            if result:
                return UserCredit(
                    id=UUID(result['id']),
                    user_id=UUID(result['user_id']),
                    credits_available=result['credits_available'],
                    credits_used=result['credits_used'],
                    credits_gifted=result['credits_gifted'],
                    credits_received=result['credits_received'],
                    next_credit_date=result['next_credit_date'],
                    monthly_credits=result['monthly_credits'],
                    credits_purchased=result['credits_purchased'],
                    total_spent=Decimal(str(result['total_spent'])),
                    created_at=result['created_at'],
                    updated_at=result['updated_at']
                )
            else:
                # Create new record
                return await self._create_initial_credit_record(user_id)
                
        except Exception as e:
            logger.error(f"Failed to get user credits: {e}")
            raise
    
    async def _create_initial_credit_record(self, user_id: UUID) -> UserCredit:
        """Create initial credit record for new user"""
        try:
            credit_id = uuid4()
            
            query = """
                INSERT INTO user_credits
                (id, user_id, credits_available, credits_used, credits_gifted, credits_received,
                 monthly_credits, credits_purchased, total_spent)
                VALUES ($1, $2, 0, 0, 0, 0, 1, 0, 0.00)
                RETURNING id, user_id, credits_available, credits_used, credits_gifted, credits_received,
                         next_credit_date, monthly_credits, credits_purchased, total_spent,
                         created_at, updated_at
            """
            
            result = await self.db.fetch_one(query, [str(credit_id), str(user_id)])
            
            return UserCredit(
                id=UUID(result['id']),
                user_id=UUID(result['user_id']),
                credits_available=result['credits_available'],
                credits_used=result['credits_used'],
                credits_gifted=result['credits_gifted'],
                credits_received=result['credits_received'],
                next_credit_date=result['next_credit_date'],
                monthly_credits=result['monthly_credits'],
                credits_purchased=result['credits_purchased'],
                total_spent=Decimal(str(result['total_spent'])),
                created_at=result['created_at'],
                updated_at=result['updated_at']
            )
            
        except Exception as e:
            logger.error(f"Failed to create initial credit record: {e}")
            raise
    
    async def _expire_user_credits(self, user_id: UUID, expiring_credits: int):
        """Expire credits for a specific user"""
        try:
            user_credits = await self._get_or_create_user_credits(user_id)
            
            # Don't expire more credits than user has
            credits_to_expire = min(expiring_credits, user_credits.credits_available)
            
            if credits_to_expire <= 0:
                return
            
            new_balance = user_credits.credits_available - credits_to_expire
            
            # Create expiration transaction
            transaction_id = uuid4()
            transaction_query = """
                INSERT INTO credit_transactions
                (id, user_id, transaction_type, credits_change, balance_after,
                 description, expires_at)
                VALUES ($1, $2, $3, $4, $5, $6, NOW())
            """
            
            await self.db.execute_query(transaction_query, [
                str(transaction_id), str(user_id), CreditTransactionType.EXPIRED.value,
                -credits_to_expire, new_balance,
                f"Expired {credits_to_expire} old credits"
            ])
            
            logger.info(f"Expired {credits_to_expire} credits for user {user_id}")
            
        except Exception as e:
            logger.error(f"Failed to expire credits for user {user_id}: {e}")
            raise