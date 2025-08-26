"""
Database Manager for Bookstore Service
Handles database connections and basic operations
"""

import asyncio
import asyncpg
import os
from typing import List, Dict, Optional, Any
from datetime import datetime, timezone
import uuid
from decimal import Decimal
import logging

logger = logging.getLogger(__name__)

class DatabaseManager:
    def __init__(self):
        self.pool = None
        self.database_url = os.getenv(
            "DATABASE_URL", 
            "postgresql://postgres:password@localhost:5432/betterbooks"
        )
    
    async def initialize(self):
        """Initialize database connection pool"""
        try:
            self.pool = await asyncpg.create_pool(
                self.database_url,
                min_size=2,
                max_size=20,
                command_timeout=60,
                server_settings={
                    'jit': 'off'  # Disable JIT for better performance on smaller queries
                }
            )
            logger.info("Database connection pool initialized")
        except Exception as e:
            logger.error(f"Failed to initialize database pool: {e}")
            raise
    
    async def close(self):
        """Close database connection pool"""
        if self.pool:
            await self.pool.close()
            logger.info("Database connection pool closed")
    
    async def health_check(self) -> Dict[str, Any]:
        """Check database health"""
        try:
            async with self.pool.acquire() as conn:
                result = await conn.fetchval("SELECT 1")
                return {"status": "healthy", "connection": "ok"}
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return {"status": "unhealthy", "error": str(e)}
    
    async def execute(self, query: str, *args) -> str:
        """Execute a query and return status"""
        async with self.pool.acquire() as conn:
            result = await conn.execute(query, *args)
            return result
    
    async def fetch_one(self, query: str, *args) -> Optional[Dict[str, Any]]:
        """Fetch single row as dictionary"""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(query, *args)
            return dict(row) if row else None
    
    async def fetch_all(self, query: str, *args) -> List[Dict[str, Any]]:
        """Fetch all rows as list of dictionaries"""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch(query, *args)
            return [dict(row) for row in rows]
    
    async def fetch_val(self, query: str, *args) -> Any:
        """Fetch single value"""
        async with self.pool.acquire() as conn:
            return await conn.fetchval(query, *args)
    
    async def transaction(self):
        """Get transaction context"""
        return self.pool.acquire()
    
    # Book-specific queries
    async def get_books_with_filters(
        self,
        category_id: Optional[str] = None,
        featured: Optional[bool] = None,
        bestseller: Optional[bool] = None,
        new_release: Optional[bool] = None,
        limit: int = 20,
        offset: int = 0
    ) -> tuple[List[Dict[str, Any]], int]:
        """Get books with optional filters and count"""
        
        # Build WHERE conditions
        conditions = []
        params = []
        param_count = 0
        
        if category_id:
            param_count += 1
            conditions.append(f"b.category_id = ${param_count}")
            params.append(category_id)
        
        if featured is not None:
            param_count += 1
            conditions.append(f"b.is_featured = ${param_count}")
            params.append(featured)
        
        if bestseller is not None:
            param_count += 1
            conditions.append(f"b.is_bestseller = ${param_count}")
            params.append(bestseller)
        
        if new_release is not None:
            param_count += 1
            conditions.append(f"b.is_new_release = ${param_count}")
            params.append(new_release)
        
        where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""
        
        # Count query
        count_query = f"""
            SELECT COUNT(*) FROM books b
            {where_clause}
        """
        
        # Main query
        param_count += 1
        limit_param = f"${param_count}"
        param_count += 1
        offset_param = f"${param_count}"
        
        query = f"""
            SELECT 
                b.*,
                c.name as category_name,
                c.description as category_description,
                c.display_order as category_display_order
            FROM books b
            LEFT JOIN book_categories c ON b.category_id = c.id
            {where_clause}
            ORDER BY 
                CASE WHEN b.is_featured THEN 0 ELSE 1 END,
                b.purchase_count DESC,
                b.created_at DESC
            LIMIT {limit_param} OFFSET {offset_param}
        """
        
        params.extend([limit, offset])
        
        # Execute both queries
        total_count = await self.fetch_val(count_query, *params[:-2])
        books = await self.fetch_all(query, *params)
        
        return books, total_count
    
    async def search_books(
        self,
        search_text: str,
        category_id: Optional[str] = None,
        limit: int = 20,
        offset: int = 0
    ) -> tuple[List[Dict[str, Any]], int]:
        """Search books using full-text search"""
        
        conditions = ["b.search_vector @@ plainto_tsquery('english', $1)"]
        params = [search_text]
        param_count = 1
        
        if category_id:
            param_count += 1
            conditions.append(f"b.category_id = ${param_count}")
            params.append(category_id)
        
        where_clause = "WHERE " + " AND ".join(conditions)
        
        # Count query
        count_query = f"""
            SELECT COUNT(*) FROM books b
            {where_clause}
        """
        
        # Main query with ranking
        param_count += 1
        limit_param = f"${param_count}"
        param_count += 1
        offset_param = f"${param_count}"
        
        query = f"""
            SELECT 
                b.*,
                c.name as category_name,
                c.description as category_description,
                c.display_order as category_display_order,
                ts_rank(b.search_vector, plainto_tsquery('english', $1)) as rank
            FROM books b
            LEFT JOIN book_categories c ON b.category_id = c.id
            {where_clause}
            ORDER BY rank DESC, b.purchase_count DESC
            LIMIT {limit_param} OFFSET {offset_param}
        """
        
        params.extend([limit, offset])
        
        total_count = await self.fetch_val(count_query, *params[:-2])
        books = await self.fetch_all(query, *params)
        
        return books, total_count
    
    async def get_user_purchases(self, user_id: str) -> List[Dict[str, Any]]:
        """Get user's purchased books with purchase details"""
        query = """
            SELECT 
                b.*,
                c.name as category_name,
                c.description as category_description,
                up.purchase_date,
                up.purchase_type,
                up.price_paid,
                up.credits_used,
                up.id as purchase_id
            FROM user_purchases up
            JOIN books b ON up.book_id = b.id
            LEFT JOIN book_categories c ON b.category_id = c.id
            WHERE up.user_id = $1
            ORDER BY up.purchase_date DESC
        """
        return await self.fetch_all(query, user_id)
    
    async def get_user_credits(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user's credit balance"""
        query = """
            SELECT * FROM user_credits 
            WHERE user_id = $1
        """
        return await self.fetch_one(query, user_id)
    
    async def check_user_owns_book(self, user_id: str, book_id: str) -> bool:
        """Check if user owns a specific book"""
        query = """
            SELECT EXISTS(
                SELECT 1 FROM user_purchases 
                WHERE user_id = $1 AND book_id = $2
            )
        """
        return await self.fetch_val(query, user_id, book_id)
    
    async def create_purchase(
        self,
        user_id: str,
        book_id: str,
        purchase_type: str,
        credits_used: int = 0,
        price_paid: Decimal = Decimal("0.0")
    ) -> str:
        """Create a new purchase record"""
        purchase_id = str(uuid.uuid4())
        
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                # Insert purchase
                await conn.execute("""
                    INSERT INTO user_purchases 
                    (id, user_id, book_id, purchase_type, credits_used, price_paid)
                    VALUES ($1, $2, $3, $4, $5, $6)
                """, purchase_id, user_id, book_id, purchase_type, credits_used, price_paid)
                
                # Update user credits if credits were used
                if credits_used > 0:
                    await conn.execute("""
                        UPDATE user_credits 
                        SET used_credits = used_credits + $2, 
                            last_updated = NOW()
                        WHERE user_id = $1
                    """, user_id, credits_used)
                
                # Update book purchase count
                await conn.execute("""
                    UPDATE books 
                    SET purchase_count = purchase_count + 1
                    WHERE id = $1
                """, book_id)
        
        return purchase_id