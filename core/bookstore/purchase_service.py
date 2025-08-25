"""
Purchase Service

Handles book purchases, credit transactions, gift functionality, and purchase validation
for the EchoWright bookstore. Integrates with payment providers and subscription system.
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from uuid import UUID, uuid4
from decimal import Decimal
from datetime import datetime, timezone

from ..database.database_manager import DatabaseManager
from .models import (
    BookCatalog, UserPurchase, PurchaseType, PaymentProvider,
    UserCredit, CreditTransaction, CreditTransactionType,
    PurchaseRequest, PromoCode
)
from .bookstore_service import BookstoreService

logger = logging.getLogger(__name__)


class PurchaseError(Exception):
    """Purchase-related errors"""
    pass


class InsufficientCreditsError(PurchaseError):
    """User doesn't have enough credits"""
    pass


class AlreadyOwnedError(PurchaseError):
    """User already owns this book"""
    pass


class PurchaseService:
    """
    Service for handling book purchases and credit transactions
    """
    
    def __init__(self, db_manager: DatabaseManager, bookstore_service: BookstoreService):
        self.db = db_manager
        self.bookstore = bookstore_service
    
    async def purchase_book(
        self, 
        user_id: UUID, 
        purchase_request: PurchaseRequest
    ) -> Dict[str, Any]:
        """
        Purchase a book with credits or money
        
        Returns:
            Purchase confirmation details
        """
        try:
            book_id = UUID(purchase_request.book_id)
            
            # Get book details
            book = await self.bookstore.get_book_details(book_id)
            if not book:
                raise PurchaseError("Book not found")
            
            # Check if user already owns this book
            if await self.user_owns_book(user_id, book_id):
                raise AlreadyOwnedError("You already own this book")
            
            # Get user's credit balance
            user_credits = await self.get_user_credits(user_id)
            
            # Determine purchase method
            if purchase_request.use_credits and user_credits.credits_available >= book.credit_price:
                # Purchase with credits
                return await self._purchase_with_credits(
                    user_id, book, user_credits, purchase_request
                )
            else:
                # Purchase with money (requires external payment processing)
                return await self._purchase_with_money(
                    user_id, book, purchase_request
                )
                
        except Exception as e:
            logger.error(f"Purchase failed for user {user_id}, book {purchase_request.book_id}: {e}")
            raise
    
    async def gift_book(
        self,
        from_user_id: UUID,
        to_user_id: UUID,
        book_id: UUID,
        gift_message: Optional[str] = None,
        use_credits: bool = True
    ) -> Dict[str, Any]:
        """
        Gift a book to another user
        
        Returns:
            Gift confirmation details
        """
        try:
            # Get book details
            book = await self.bookstore.get_book_details(book_id)
            if not book:
                raise PurchaseError("Book not found")
            
            # Check if recipient already owns this book
            if await self.user_owns_book(to_user_id, book_id):
                raise AlreadyOwnedError("Recipient already owns this book")
            
            # Create gift purchase request
            gift_request = PurchaseRequest(
                book_id=str(book_id),
                use_credits=use_credits,
                gift_to_user_id=str(to_user_id),
                gift_message=gift_message
            )
            
            # Process as regular purchase with gift metadata
            result = await self.purchase_book(from_user_id, gift_request)
            
            # TODO: Send gift notification to recipient
            logger.info(f"Book gifted: {from_user_id} -> {to_user_id}, book: {book_id}")
            
            return result
            
        except Exception as e:
            logger.error(f"Gift failed: {from_user_id} -> {to_user_id}, book: {book_id}: {e}")
            raise
    
    async def user_owns_book(self, user_id: UUID, book_id: UUID) -> bool:
        """Check if user already owns a book"""
        try:
            query = """
                SELECT COUNT(*) as count
                FROM user_purchases
                WHERE user_id = $1 AND book_id = $2 AND refund_date IS NULL
            """
            
            result = await self.db.fetch_one(query, [str(user_id), str(book_id)])
            return result and result['count'] > 0
            
        except Exception as e:
            logger.error(f"Failed to check book ownership: {e}")
            return False
    
    async def get_user_purchases(
        self, 
        user_id: UUID, 
        include_gifts: bool = True,
        limit: int = 50,
        offset: int = 0
    ) -> Tuple[List[UserPurchase], int]:
        """Get user's purchase history"""
        try:
            conditions = ["up.user_id = $1", "up.refund_date IS NULL"]
            params = [str(user_id)]
            
            if not include_gifts:
                conditions.append("up.gift_from_user_id IS NULL")
            
            where_clause = " AND ".join(conditions)
            
            # Count query
            count_query = f"""
                SELECT COUNT(*) as total
                FROM user_purchases up
                WHERE {where_clause}
            """
            
            count_result = await self.db.fetch_one(count_query, params)
            total_count = count_result['total'] if count_result else 0
            
            # Main query with book details
            query = f"""
                SELECT 
                    up.id, up.user_id, up.book_id, up.purchase_date, up.purchase_type,
                    up.price_paid, up.credits_used, up.transaction_id, up.gift_from_user_id,
                    up.gift_message, up.payment_provider, up.refund_date, up.refund_reason,
                    up.created_at, up.updated_at,
                    b.title, b.author, b.narrator, b.cover_image_url, b.duration_seconds,
                    gift_user.display_name as gift_from_name
                FROM user_purchases up
                JOIN books b ON up.book_id = b.id
                LEFT JOIN users gift_user ON up.gift_from_user_id = gift_user.id
                WHERE {where_clause}
                ORDER BY up.purchase_date DESC
                LIMIT ${len(params) + 1} OFFSET ${len(params) + 2}
            """
            
            params.extend([limit, offset])
            results = await self.db.fetch_all(query, params)
            
            purchases = []
            for row in results:
                # Create simplified book object for purchase
                book = BookCatalog(
                    id=UUID(row['book_id']),
                    title=row['title'],
                    author=row['author'],
                    narrator=row['narrator'],
                    cover_image_url=row['cover_image_url'],
                    duration_seconds=row['duration_seconds'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at']
                )
                
                purchase = UserPurchase(
                    id=UUID(row['id']),
                    user_id=UUID(row['user_id']),
                    book_id=UUID(row['book_id']),
                    purchase_date=row['purchase_date'],
                    purchase_type=PurchaseType(row['purchase_type']),
                    price_paid=Decimal(str(row['price_paid'])) if row['price_paid'] else None,
                    credits_used=row['credits_used'],
                    transaction_id=row['transaction_id'],
                    gift_from_user_id=UUID(row['gift_from_user_id']) if row['gift_from_user_id'] else None,
                    gift_message=row['gift_message'],
                    payment_provider=PaymentProvider(row['payment_provider']) if row['payment_provider'] else None,
                    refund_date=row['refund_date'],
                    refund_reason=row['refund_reason'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    book=book,
                    gift_from_user=row['gift_from_name']
                )
                
                purchases.append(purchase)
            
            logger.info(f"Retrieved {len(purchases)} purchases for user {user_id}")
            return purchases, total_count
            
        except Exception as e:
            logger.error(f"Failed to get user purchases: {e}")
            raise
    
    async def get_user_credits(self, user_id: UUID) -> UserCredit:
        """Get user's current credit balance and history"""
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
                # Create initial credit record
                return await self._create_initial_credit_record(user_id)
                
        except Exception as e:
            logger.error(f"Failed to get user credits: {e}")
            raise
    
    async def add_credits_to_user(
        self,
        user_id: UUID,
        credits: int,
        transaction_type: CreditTransactionType,
        description: Optional[str] = None,
        subscription_id: Optional[UUID] = None,
        expires_at: Optional[datetime] = None
    ):
        """Add credits to user's account"""
        try:
            async with self.db.transaction():
                # Get current balance
                current_credits = await self.get_user_credits(user_id)
                new_balance = current_credits.credits_available + credits
                
                # Create credit transaction
                transaction_id = uuid4()
                transaction_query = """
                    INSERT INTO credit_transactions
                    (id, user_id, transaction_type, credits_change, balance_after,
                     subscription_id, description, expires_at)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                """
                
                await self.db.execute_query(transaction_query, [
                    str(transaction_id), str(user_id), transaction_type.value,
                    credits, new_balance, str(subscription_id) if subscription_id else None,
                    description, expires_at
                ])
                
                logger.info(f"Added {credits} credits to user {user_id}")
                
        except Exception as e:
            logger.error(f"Failed to add credits: {e}")
            raise
    
    async def get_credit_transaction_history(
        self,
        user_id: UUID,
        limit: int = 50,
        offset: int = 0
    ) -> Tuple[List[CreditTransaction], int]:
        """Get user's credit transaction history"""
        try:
            # Count query
            count_query = """
                SELECT COUNT(*) as total
                FROM credit_transactions
                WHERE user_id = $1
            """
            
            count_result = await self.db.fetch_one(count_query, [str(user_id)])
            total_count = count_result['total'] if count_result else 0
            
            # Main query
            query = """
                SELECT 
                    ct.id, ct.user_id, ct.transaction_type, ct.credits_change, ct.balance_after,
                    ct.book_id, ct.subscription_id, ct.gift_to_user_id, ct.payment_transaction_id,
                    ct.description, ct.expires_at, ct.created_at,
                    b.title as book_title,
                    gift_user.display_name as gift_to_user_name
                FROM credit_transactions ct
                LEFT JOIN books b ON ct.book_id = b.id
                LEFT JOIN users gift_user ON ct.gift_to_user_id = gift_user.id
                WHERE ct.user_id = $1
                ORDER BY ct.created_at DESC
                LIMIT $2 OFFSET $3
            """
            
            results = await self.db.fetch_all(query, [str(user_id), limit, offset])
            
            transactions = []
            for row in results:
                transaction = CreditTransaction(
                    id=UUID(row['id']),
                    user_id=UUID(row['user_id']),
                    transaction_type=CreditTransactionType(row['transaction_type']),
                    credits_change=row['credits_change'],
                    balance_after=row['balance_after'],
                    book_id=UUID(row['book_id']) if row['book_id'] else None,
                    subscription_id=UUID(row['subscription_id']) if row['subscription_id'] else None,
                    gift_to_user_id=UUID(row['gift_to_user_id']) if row['gift_to_user_id'] else None,
                    payment_transaction_id=row['payment_transaction_id'],
                    description=row['description'],
                    expires_at=row['expires_at'],
                    created_at=row['created_at'],
                    book_title=row['book_title'],
                    gift_to_user_name=row['gift_to_user_name']
                )
                transactions.append(transaction)
            
            return transactions, total_count
            
        except Exception as e:
            logger.error(f"Failed to get credit history: {e}")
            raise
    
    async def validate_promo_code(
        self,
        code: str,
        user_id: UUID,
        purchase_amount: Decimal
    ) -> Optional[PromoCode]:
        """Validate and return promo code if applicable"""
        try:
            query = """
                SELECT 
                    id, code, discount_type, discount_value, max_uses, current_uses,
                    max_uses_per_user, is_active, starts_at, expires_at, minimum_purchase,
                    applicable_categories, description, created_at
                FROM promo_codes
                WHERE code = $1 AND is_active = true
                AND starts_at <= NOW()
                AND (expires_at IS NULL OR expires_at > NOW())
                AND (max_uses IS NULL OR current_uses < max_uses)
            """
            
            result = await self.db.fetch_one(query, [code])
            
            if not result:
                return None
            
            # Check minimum purchase requirement
            if result['minimum_purchase'] and purchase_amount < result['minimum_purchase']:
                return None
            
            # Check user usage limit
            usage_query = """
                SELECT COUNT(*) as count
                FROM promo_code_usage
                WHERE promo_code_id = $1 AND user_id = $2
            """
            
            usage_result = await self.db.fetch_one(usage_query, [
                result['id'], str(user_id)
            ])
            
            if usage_result and usage_result['count'] >= result['max_uses_per_user']:
                return None
            
            # Return valid promo code
            return PromoCode(
                id=UUID(result['id']),
                code=result['code'],
                discount_type=result['discount_type'],
                discount_value=Decimal(str(result['discount_value'])),
                max_uses=result['max_uses'],
                current_uses=result['current_uses'],
                max_uses_per_user=result['max_uses_per_user'],
                is_active=result['is_active'],
                starts_at=result['starts_at'],
                expires_at=result['expires_at'],
                minimum_purchase=Decimal(str(result['minimum_purchase'])) if result['minimum_purchase'] else Decimal('0.00'),
                applicable_categories=result['applicable_categories'] or [],
                description=result['description'],
                created_at=result['created_at']
            )
            
        except Exception as e:
            logger.error(f"Failed to validate promo code: {e}")
            return None
    
    async def _purchase_with_credits(
        self,
        user_id: UUID,
        book: BookCatalog,
        user_credits: UserCredit,
        purchase_request: PurchaseRequest
    ) -> Dict[str, Any]:
        """Process credit-based purchase"""
        try:
            if user_credits.credits_available < book.credit_price:
                raise InsufficientCreditsError(
                    f"Need {book.credit_price} credits, have {user_credits.credits_available}"
                )
            
            async with self.db.transaction():
                # Create purchase record
                purchase_id = uuid4()
                purchase_query = """
                    INSERT INTO user_purchases
                    (id, user_id, book_id, purchase_date, purchase_type, credits_used,
                     gift_from_user_id, gift_message, payment_provider)
                    VALUES ($1, $2, $3, NOW(), $4, $5, $6, $7, $8)
                """
                
                await self.db.execute_query(purchase_query, [
                    str(purchase_id), str(user_id), str(book.id),
                    PurchaseType.CREDIT.value, book.credit_price,
                    purchase_request.gift_to_user_id,
                    purchase_request.gift_message,
                    PaymentProvider.SUBSCRIPTION.value
                ])
                
                # Deduct credits
                new_balance = user_credits.credits_available - book.credit_price
                credit_transaction_id = uuid4()
                
                credit_query = """
                    INSERT INTO credit_transactions
                    (id, user_id, transaction_type, credits_change, balance_after,
                     book_id, description)
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                """
                
                await self.db.execute_query(credit_query, [
                    str(credit_transaction_id), str(user_id),
                    CreditTransactionType.SPENT.value, -book.credit_price, new_balance,
                    str(book.id), f"Purchased '{book.title}'"
                ])
            
            logger.info(f"Credit purchase completed: user {user_id}, book {book.id}")
            
            return {
                'success': True,
                'purchase_id': str(purchase_id),
                'book_id': str(book.id),
                'book_title': book.title,
                'credits_used': book.credit_price,
                'credits_remaining': new_balance,
                'purchase_type': 'credit',
                'is_gift': purchase_request.gift_to_user_id is not None
            }
            
        except Exception as e:
            logger.error(f"Credit purchase failed: {e}")
            raise
    
    async def _purchase_with_money(
        self,
        user_id: UUID,
        book: BookCatalog,
        purchase_request: PurchaseRequest
    ) -> Dict[str, Any]:
        """Process money-based purchase (placeholder for payment integration)"""
        try:
            # This is where Stripe/Apple Pay integration would go
            # For now, create a pending purchase that needs payment processing
            
            purchase_id = uuid4()
            
            # Create pending purchase record
            purchase_query = """
                INSERT INTO user_purchases
                (id, user_id, book_id, purchase_date, purchase_type, price_paid,
                 gift_from_user_id, gift_message, transaction_id)
                VALUES ($1, $2, $3, NOW(), $4, $5, $6, $7, $8)
            """
            
            await self.db.execute_query(purchase_query, [
                str(purchase_id), str(user_id), str(book.id),
                PurchaseType.CASH.value, float(book.price_usd),
                purchase_request.gift_to_user_id,
                purchase_request.gift_message,
                f"pending_{purchase_id}"  # Placeholder transaction ID
            ])
            
            logger.info(f"Money purchase created (pending): user {user_id}, book {book.id}")
            
            return {
                'success': True,
                'purchase_id': str(purchase_id),
                'book_id': str(book.id),
                'book_title': book.title,
                'amount_paid': float(book.price_usd),
                'purchase_type': 'cash',
                'status': 'pending_payment',
                'is_gift': purchase_request.gift_to_user_id is not None
            }
            
        except Exception as e:
            logger.error(f"Money purchase failed: {e}")
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