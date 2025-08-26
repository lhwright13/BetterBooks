"""
Bookstore Service Business Logic
Handles book catalog, purchases, and user library operations
"""

import asyncio
from typing import List, Optional, Tuple, Dict, Any
from datetime import datetime, timezone, timedelta
from decimal import Decimal
import uuid
import logging

from .models import (
    Book, BookCategory, PurchaseRequest, PurchaseResponse, PurchaseType,
    UserLibrary, UserPurchase, CreditBalance, DownloadResponse
)
from .database import DatabaseManager

logger = logging.getLogger(__name__)

class BookstoreService:
    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager
    
    def _convert_book_row(self, row: Dict[str, Any]) -> Book:
        """Convert database row to Book model"""
        # Handle category
        category = None
        if row.get('category_name'):
            category = BookCategory(
                id=str(row['category_id']),
                name=row['category_name'],
                description=row.get('category_description'),
                display_order=row.get('category_display_order', 0)
            )
        
        return Book(
            id=str(row['id']),
            title=row['title'],
            author=row.get('author'),
            narrator=row.get('narrator'),
            publisher=row.get('publisher'),
            description=row.get('description'),
            duration_minutes=row.get('duration_minutes'),
            language=row.get('language', 'en'),
            isbn=row.get('isbn'),
            cover_image_url=row.get('cover_image_url'),
            sample_audio_url=row.get('sample_audio_url'),
            sample_duration=row.get('sample_duration', 180),
            price_usd=row.get('price_usd', Decimal('14.95')),
            credit_price=row.get('credit_price', 1),
            category=category,
            is_featured=row.get('is_featured', False),
            is_bestseller=row.get('is_bestseller', False),
            is_new_release=row.get('is_new_release', False),
            publication_date=row.get('publication_date'),
            blob_container=row.get('blob_container'),
            blob_path=row.get('blob_path'),
            cdn_url=row.get('cdn_url'),
            total_chapters=row.get('total_chapters', 1),
            file_size_bytes=row.get('file_size_bytes'),
            average_rating=row.get('average_rating', Decimal('0.0')),
            review_count=row.get('review_count', 0),
            purchase_count=row.get('purchase_count', 0),
            purchase_date=row.get('purchase_date'),
        )
    
    async def get_catalog(
        self,
        category_id: Optional[str] = None,
        featured: Optional[bool] = None,
        bestseller: Optional[bool] = None,
        new_release: Optional[bool] = None,
        limit: int = 20,
        offset: int = 0
    ) -> Tuple[List[Book], int]:
        """Get book catalog with optional filtering"""
        try:
            books_data, total_count = await self.db.get_books_with_filters(
                category_id=category_id,
                featured=featured,
                bestseller=bestseller,
                new_release=new_release,
                limit=limit,
                offset=offset
            )
            
            books = [self._convert_book_row(row) for row in books_data]
            return books, total_count
        
        except Exception as e:
            logger.error(f"Error getting catalog: {e}")
            raise
    
    async def get_book_by_id(self, book_id: str) -> Optional[Book]:
        """Get a specific book by ID"""
        try:
            query = """
                SELECT 
                    b.*,
                    c.name as category_name,
                    c.description as category_description,
                    c.display_order as category_display_order
                FROM books b
                LEFT JOIN book_categories c ON b.category_id = c.id
                WHERE b.id = $1
            """
            row = await self.db.fetch_one(query, book_id)
            
            if row:
                return self._convert_book_row(row)
            return None
        
        except Exception as e:
            logger.error(f"Error getting book {book_id}: {e}")
            raise
    
    async def search_books(
        self,
        search_text: str,
        category_id: Optional[str] = None,
        limit: int = 20,
        offset: int = 0
    ) -> Tuple[List[Book], int]:
        """Search books using full-text search"""
        try:
            books_data, total_count = await self.db.search_books(
                search_text=search_text,
                category_id=category_id,
                limit=limit,
                offset=offset
            )
            
            books = [self._convert_book_row(row) for row in books_data]
            return books, total_count
        
        except Exception as e:
            logger.error(f"Error searching books: {e}")
            raise
    
    async def get_categories(self) -> List[BookCategory]:
        """Get all book categories"""
        try:
            query = """
                SELECT 
                    c.*,
                    COUNT(b.id) as book_count
                FROM book_categories c
                LEFT JOIN books b ON c.id = b.category_id
                WHERE c.is_active = true
                GROUP BY c.id
                ORDER BY c.display_order, c.name
            """
            rows = await self.db.fetch_all(query)
            
            return [
                BookCategory(
                    id=str(row['id']),
                    name=row['name'],
                    description=row.get('description'),
                    image_url=row.get('image_url'),
                    display_order=row.get('display_order', 0),
                    is_active=row.get('is_active', True),
                    book_count=row.get('book_count', 0)
                )
                for row in rows
            ]
        
        except Exception as e:
            logger.error(f"Error getting categories: {e}")
            raise
    
    async def purchase_book(
        self,
        user_id: str,
        book_id: str,
        purchase_type: PurchaseType,
        credits_to_use: Optional[int] = None
    ) -> PurchaseResponse:
        """Purchase a book for a user"""
        try:
            # Check if user already owns the book
            owns_book = await self.db.check_user_owns_book(user_id, book_id)
            if owns_book:
                raise ValueError("User already owns this book")
            
            # Get book details
            book = await self.get_book_by_id(book_id)
            if not book:
                raise ValueError("Book not found")
            
            # Get user's credit balance
            credit_data = await self.db.get_user_credits(user_id)
            if not credit_data:
                # Initialize credits for new user
                await self.add_credits(user_id, 2)  # Give 2 free credits
                credit_data = await self.db.get_user_credits(user_id)
            
            available_credits = credit_data['total_credits'] - credit_data['used_credits']
            
            # Determine purchase details
            credits_used = 0
            price_paid = Decimal("0.0")
            
            if purchase_type == PurchaseType.CREDIT:
                if credits_to_use is None:
                    credits_to_use = book.credit_price
                
                if credits_to_use > available_credits:
                    raise ValueError(f"Insufficient credits. Available: {available_credits}, Required: {credits_to_use}")
                
                if credits_to_use < book.credit_price:
                    raise ValueError(f"Insufficient credits for this book. Required: {book.credit_price}")
                
                credits_used = credits_to_use
            
            elif purchase_type == PurchaseType.CASH:
                price_paid = book.price_usd
            
            # Create the purchase
            purchase_id = await self.db.create_purchase(
                user_id=user_id,
                book_id=book_id,
                purchase_type=purchase_type.value,
                credits_used=credits_used,
                price_paid=price_paid
            )
            
            # Get updated credit balance
            updated_credit_data = await self.db.get_user_credits(user_id)
            remaining_credits = updated_credit_data['total_credits'] - updated_credit_data['used_credits']
            
            # Generate download URL (this would integrate with storage service)
            download_url = f"/download/{book_id}?user={user_id}&token=temp_token"
            download_expires = datetime.now(timezone.utc) + timedelta(hours=24)
            
            return PurchaseResponse(
                success=True,
                message="Book purchased successfully",
                purchase_id=purchase_id,
                book=book,
                credits_used=credits_used,
                price_paid=price_paid,
                remaining_credits=remaining_credits,
                download_url=download_url,
                download_expires=download_expires
            )
        
        except ValueError:
            raise
        except Exception as e:
            logger.error(f"Error purchasing book: {e}")
            raise
    
    async def get_user_library(self, user_id: str) -> UserLibrary:
        """Get user's purchased books"""
        try:
            purchases_data = await self.db.get_user_purchases(user_id)
            
            books = []
            recent_purchases = []
            
            for row in purchases_data:
                book = self._convert_book_row(row)
                book.purchase_date = row['purchase_date']
                
                # Add download URL for owned books
                book.download_url = f"/download/{book.id}?user={user_id}&token=temp_token"
                book.download_expires = datetime.now(timezone.utc) + timedelta(hours=24)
                
                books.append(book)
                
                # Add to recent purchases
                purchase = UserPurchase(
                    id=str(row['purchase_id']),
                    book=book,
                    purchase_date=row['purchase_date'],
                    purchase_type=PurchaseType(row['purchase_type']),
                    price_paid=row['price_paid'] or Decimal("0.0"),
                    credits_used=row['credits_used'] or 0
                )
                recent_purchases.append(purchase)
            
            # Sort recent purchases by date (most recent first)
            recent_purchases.sort(key=lambda x: x.purchase_date, reverse=True)
            
            return UserLibrary(
                user_id=user_id,
                books=books,
                total_books=len(books),
                recent_purchases=recent_purchases[:10]  # Last 10 purchases
            )
        
        except Exception as e:
            logger.error(f"Error getting user library: {e}")
            raise
    
    async def get_credit_balance(self, user_id: str) -> CreditBalance:
        """Get user's credit balance"""
        try:
            credit_data = await self.db.get_user_credits(user_id)
            if not credit_data:
                # Initialize credits for new user
                await self.add_credits(user_id, 2)
                credit_data = await self.db.get_user_credits(user_id)
            
            return CreditBalance(
                user_id=user_id,
                total_credits=credit_data['total_credits'],
                used_credits=credit_data['used_credits'],
                available_credits=credit_data['total_credits'] - credit_data['used_credits'],
                last_updated=credit_data['last_updated']
            )
        
        except Exception as e:
            logger.error(f"Error getting credit balance: {e}")
            raise
    
    async def add_credits(self, user_id: str, credits: int):
        """Add credits to user account"""
        try:
            query = """
                INSERT INTO user_credits (user_id, total_credits, used_credits)
                VALUES ($1, $2, 0)
                ON CONFLICT (user_id) 
                DO UPDATE SET 
                    total_credits = user_credits.total_credits + $2,
                    last_updated = NOW()
            """
            await self.db.execute(query, user_id, credits)
        
        except Exception as e:
            logger.error(f"Error adding credits: {e}")
            raise
    
    # Wishlist methods
    async def add_to_wishlist(self, user_id: str, book_id: str):
        """Add book to user's wishlist"""
        try:
            query = """
                INSERT INTO user_wishlist (user_id, book_id)
                VALUES ($1, $2)
                ON CONFLICT (user_id, book_id) DO NOTHING
            """
            await self.db.execute(query, user_id, book_id)
        
        except Exception as e:
            logger.error(f"Error adding to wishlist: {e}")
            raise
    
    async def remove_from_wishlist(self, user_id: str, book_id: str):
        """Remove book from user's wishlist"""
        try:
            query = """
                DELETE FROM user_wishlist 
                WHERE user_id = $1 AND book_id = $2
            """
            await self.db.execute(query, user_id, book_id)
        
        except Exception as e:
            logger.error(f"Error removing from wishlist: {e}")
            raise
    
    async def get_wishlist(self, user_id: str) -> List[Book]:
        """Get user's wishlist"""
        try:
            query = """
                SELECT 
                    b.*,
                    c.name as category_name,
                    c.description as category_description,
                    c.display_order as category_display_order,
                    w.added_at
                FROM user_wishlist w
                JOIN books b ON w.book_id = b.id
                LEFT JOIN book_categories c ON b.category_id = c.id
                WHERE w.user_id = $1
                ORDER BY w.added_at DESC
            """
            rows = await self.db.fetch_all(query, user_id)
            
            return [self._convert_book_row(row) for row in rows]
        
        except Exception as e:
            logger.error(f"Error getting wishlist: {e}")
            raise