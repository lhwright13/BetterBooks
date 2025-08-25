"""
Bookstore Service

Handles book catalog browsing, search, and discovery features for the EchoWright store.
Provides Audible-like functionality for browsing books by categories, recommendations,
bestsellers, and featured content.
"""

import logging
from typing import Dict, List, Optional, Tuple, Any
from uuid import UUID
from decimal import Decimal
from datetime import datetime, timezone

from ..database.database_manager import DatabaseManager
from .models import (
    BookCatalog, BookCategory, BookSearchFilter,
    InteractionType, UserPurchase
)

logger = logging.getLogger(__name__)


class BookstoreService:
    """
    Service for managing book catalog and store browsing functionality
    """
    
    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager
        
        # Cache for frequently accessed data
        self._category_cache = {}
        self._featured_books_cache = None
        self._cache_expiry = None
    
    async def browse_books(
        self, 
        category_id: Optional[UUID] = None,
        featured_only: bool = False,
        bestsellers_only: bool = False,
        new_releases_only: bool = False,
        limit: int = 20,
        offset: int = 0
    ) -> Tuple[List[BookCatalog], int]:
        """
        Browse books with various filtering options
        
        Returns:
            Tuple of (books, total_count)
        """
        try:
            # Build query conditions
            conditions = ["b.is_active = true"]
            params = []
            
            if category_id:
                conditions.append("$%d = ANY(b.categories::text[])")
                params.append(str(category_id))
            
            if featured_only:
                conditions.append("b.is_featured = true")
            
            if bestsellers_only:
                conditions.append("b.bestseller_rank IS NOT NULL")
                conditions.append("b.bestseller_rank <= 100")
            
            if new_releases_only:
                conditions.append("b.release_date >= NOW() - INTERVAL '30 days'")
            
            where_clause = " AND ".join(conditions)
            
            # Order by logic
            if bestsellers_only:
                order_by = "b.bestseller_rank ASC, b.average_rating DESC"
            elif new_releases_only:
                order_by = "b.release_date DESC, b.average_rating DESC"
            elif featured_only:
                order_by = "b.average_rating DESC, b.purchase_count DESC"
            else:
                order_by = "b.purchase_count DESC, b.average_rating DESC"
            
            # Count query
            count_query = f"""
                SELECT COUNT(*) as total
                FROM books b
                WHERE {where_clause}
            """
            
            count_result = await self.db.fetch_one(count_query, params)
            total_count = count_result['total'] if count_result else 0
            
            # Main query
            query = f"""
                SELECT 
                    b.id, b.title, b.author, b.isbn, b.description, b.cover_image_url,
                    b.audio_file_path, b.duration_seconds, b.language, b.genre, b.publication_date,
                    b.price_usd, b.credit_price, b.narrator, b.publisher, b.sample_audio_url,
                    b.sample_duration, b.release_date, b.bestseller_rank, b.categories, b.tags,
                    b.average_rating, b.rating_count, b.purchase_count, b.is_featured,
                    b.file_size_mb, b.content_rating, b.created_at, b.updated_at, b.is_active
                FROM books b
                WHERE {where_clause}
                ORDER BY {order_by}
                LIMIT ${len(params) + 1} OFFSET ${len(params) + 2}
            """
            
            params.extend([limit, offset])
            results = await self.db.fetch_all(query, params)
            
            books = [self._row_to_book_catalog(row) for row in results]
            
            logger.info(f"Browse books: found {len(books)} books (total: {total_count})")
            return books, total_count
            
        except Exception as e:
            logger.error(f"Failed to browse books: {e}")
            raise
    
    async def search_books(self, search_filter: BookSearchFilter) -> Tuple[List[BookCatalog], int]:
        """
        Search books with advanced filtering
        
        Returns:
            Tuple of (books, total_count)
        """
        try:
            conditions = ["b.is_active = true"]
            params = []
            param_count = 0
            
            # Text search
            if search_filter.query:
                param_count += 1
                conditions.append(f"""
                    to_tsvector('english', 
                        COALESCE(b.title, '') || ' ' || 
                        COALESCE(b.author, '') || ' ' || 
                        COALESCE(b.narrator, '') || ' ' ||
                        COALESCE(b.description, '')
                    ) @@ plainto_tsquery('english', ${param_count})
                """)
                params.append(search_filter.query)
            
            # Category filter
            if search_filter.categories:
                param_count += 1
                conditions.append(f"b.categories ?| ${param_count}")
                params.append(search_filter.categories)
            
            # Price range
            if search_filter.min_price is not None:
                param_count += 1
                conditions.append(f"b.price_usd >= ${param_count}")
                params.append(float(search_filter.min_price))
            
            if search_filter.max_price is not None:
                param_count += 1
                conditions.append(f"b.price_usd <= ${param_count}")
                params.append(float(search_filter.max_price))
            
            # Rating filter
            if search_filter.min_rating is not None:
                param_count += 1
                conditions.append(f"b.average_rating >= ${param_count}")
                params.append(search_filter.min_rating)
            
            # Content rating
            if search_filter.content_rating:
                param_count += 1
                conditions.append(f"b.content_rating = ANY(${param_count})")
                params.append(search_filter.content_rating)
            
            # Has sample filter
            if search_filter.has_sample is not None:
                if search_filter.has_sample:
                    conditions.append("b.sample_audio_url IS NOT NULL")
                else:
                    conditions.append("b.sample_audio_url IS NULL")
            
            # Narrator filter
            if search_filter.narrator:
                param_count += 1
                conditions.append(f"LOWER(b.narrator) LIKE LOWER('%' || ${param_count} || '%')")
                params.append(search_filter.narrator)
            
            # Language filter
            if search_filter.language != 'all':
                param_count += 1
                conditions.append(f"b.language = ${param_count}")
                params.append(search_filter.language)
            
            where_clause = " AND ".join(conditions)
            
            # Sorting
            sort_mapping = {
                'popularity': 'b.purchase_count DESC, b.average_rating DESC',
                'price_low': 'b.price_usd ASC, b.title ASC',
                'price_high': 'b.price_usd DESC, b.title ASC',
                'rating': 'b.average_rating DESC, b.rating_count DESC',
                'newest': 'b.release_date DESC, b.created_at DESC',
                'title': 'b.title ASC'
            }
            
            order_by = sort_mapping.get(search_filter.sort_by, sort_mapping['popularity'])
            
            # Count query
            count_query = f"""
                SELECT COUNT(*) as total
                FROM books b
                WHERE {where_clause}
            """
            
            count_result = await self.db.fetch_one(count_query, params)
            total_count = count_result['total'] if count_result else 0
            
            # Main query with pagination
            offset = (search_filter.page - 1) * search_filter.limit
            
            query = f"""
                SELECT 
                    b.id, b.title, b.author, b.isbn, b.description, b.cover_image_url,
                    b.audio_file_path, b.duration_seconds, b.language, b.genre, b.publication_date,
                    b.price_usd, b.credit_price, b.narrator, b.publisher, b.sample_audio_url,
                    b.sample_duration, b.release_date, b.bestseller_rank, b.categories, b.tags,
                    b.average_rating, b.rating_count, b.purchase_count, b.is_featured,
                    b.file_size_mb, b.content_rating, b.created_at, b.updated_at, b.is_active
                FROM books b
                WHERE {where_clause}
                ORDER BY {order_by}
                LIMIT ${param_count + 1} OFFSET ${param_count + 2}
            """
            
            params.extend([search_filter.limit, offset])
            results = await self.db.fetch_all(query, params)
            
            books = [self._row_to_book_catalog(row) for row in results]
            
            logger.info(f"Search books: '{search_filter.query}' found {len(books)} books")
            return books, total_count
            
        except Exception as e:
            logger.error(f"Failed to search books: {e}")
            raise
    
    async def get_book_details(self, book_id: UUID) -> Optional[BookCatalog]:
        """Get detailed information for a specific book"""
        try:
            query = """
                SELECT 
                    b.id, b.title, b.author, b.isbn, b.description, b.cover_image_url,
                    b.audio_file_path, b.duration_seconds, b.language, b.genre, b.publication_date,
                    b.price_usd, b.credit_price, b.narrator, b.publisher, b.sample_audio_url,
                    b.sample_duration, b.release_date, b.bestseller_rank, b.categories, b.tags,
                    b.average_rating, b.rating_count, b.purchase_count, b.is_featured,
                    b.file_size_mb, b.content_rating, b.created_at, b.updated_at, b.is_active
                FROM books b
                WHERE b.id = $1 AND b.is_active = true
            """
            
            result = await self.db.fetch_one(query, [str(book_id)])
            
            if result:
                book = self._row_to_book_catalog(result)
                logger.info(f"Retrieved book details: {book.title}")
                return book
            else:
                logger.warning(f"Book not found: {book_id}")
                return None
                
        except Exception as e:
            logger.error(f"Failed to get book details: {e}")
            raise
    
    async def get_categories(self, include_book_counts: bool = True) -> List[BookCategory]:
        """Get all book categories with hierarchy"""
        try:
            # Check cache first
            cache_key = f"categories_{include_book_counts}"
            if (cache_key in self._category_cache and 
                self._cache_expiry and 
                datetime.now(timezone.utc) < self._cache_expiry):
                return self._category_cache[cache_key]
            
            query = """
                SELECT 
                    c.id, c.name, c.parent_id, c.description, c.icon_name,
                    c.display_order, c.is_active, c.created_at, c.updated_at
                FROM book_categories c
                WHERE c.is_active = true
                ORDER BY c.display_order, c.name
            """
            
            results = await self.db.fetch_all(query)
            
            # Convert to category objects
            categories_dict = {}
            root_categories = []
            
            for row in results:
                category = BookCategory(
                    id=UUID(row['id']),
                    name=row['name'],
                    parent_id=UUID(row['parent_id']) if row['parent_id'] else None,
                    description=row['description'],
                    icon_name=row['icon_name'],
                    display_order=row['display_order'],
                    is_active=row['is_active'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    subcategories=[]
                )
                
                categories_dict[category.id] = category
                
                if category.parent_id is None:
                    root_categories.append(category)
            
            # Build hierarchy
            for category in categories_dict.values():
                if category.parent_id and category.parent_id in categories_dict:
                    parent = categories_dict[category.parent_id]
                    parent.subcategories.append(category)
            
            # Get book counts if requested
            if include_book_counts:
                await self._add_book_counts_to_categories(categories_dict)
            
            # Cache the result
            self._category_cache[cache_key] = root_categories
            self._cache_expiry = datetime.now(timezone.utc).replace(
                hour=datetime.now(timezone.utc).hour + 1
            )
            
            logger.info(f"Retrieved {len(root_categories)} root categories")
            return root_categories
            
        except Exception as e:
            logger.error(f"Failed to get categories: {e}")
            raise
    
    async def get_featured_books(self, limit: int = 10) -> List[BookCatalog]:
        """Get featured books for homepage"""
        try:
            books, _ = await self.browse_books(
                featured_only=True,
                limit=limit
            )
            return books
            
        except Exception as e:
            logger.error(f"Failed to get featured books: {e}")
            raise
    
    async def get_bestsellers(self, limit: int = 50) -> List[BookCatalog]:
        """Get current bestsellers"""
        try:
            books, _ = await self.browse_books(
                bestsellers_only=True,
                limit=limit
            )
            return books
            
        except Exception as e:
            logger.error(f"Failed to get bestsellers: {e}")
            raise
    
    async def get_new_releases(self, limit: int = 20) -> List[BookCatalog]:
        """Get new book releases"""
        try:
            books, _ = await self.browse_books(
                new_releases_only=True,
                limit=limit
            )
            return books
            
        except Exception as e:
            logger.error(f"Failed to get new releases: {e}")
            raise
    
    async def get_recommendations_for_user(
        self, 
        user_id: UUID, 
        limit: int = 20
    ) -> List[BookCatalog]:
        """
        Get personalized book recommendations based on user history
        This is a basic implementation - can be enhanced with ML
        """
        try:
            # Get user's purchase history and interactions
            user_books_query = """
                SELECT DISTINCT book_id
                FROM user_purchases
                WHERE user_id = $1
                UNION
                SELECT DISTINCT book_id
                FROM user_book_interactions
                WHERE user_id = $1 AND interaction_type = 'purchased'
            """
            
            user_books_result = await self.db.fetch_all(user_books_query, [str(user_id)])
            purchased_book_ids = [row['book_id'] for row in user_books_result]
            
            if not purchased_book_ids:
                # No purchase history - return popular books
                books, _ = await self.browse_books(limit=limit)
                return books
            
            # Get categories from purchased books
            categories_query = """
                SELECT DISTINCT unnest(categories::text[]) as category
                FROM books
                WHERE id = ANY($1)
            """
            
            categories_result = await self.db.fetch_all(categories_query, [purchased_book_ids])
            user_categories = [row['category'] for row in categories_result]
            
            if not user_categories:
                books, _ = await self.browse_books(limit=limit)
                return books
            
            # Find books in similar categories that user hasn't purchased
            recommendations_query = """
                SELECT 
                    b.id, b.title, b.author, b.isbn, b.description, b.cover_image_url,
                    b.audio_file_path, b.duration_seconds, b.language, b.genre, b.publication_date,
                    b.price_usd, b.credit_price, b.narrator, b.publisher, b.sample_audio_url,
                    b.sample_duration, b.release_date, b.bestseller_rank, b.categories, b.tags,
                    b.average_rating, b.rating_count, b.purchase_count, b.is_featured,
                    b.file_size_mb, b.content_rating, b.created_at, b.updated_at, b.is_active
                FROM books b
                WHERE b.is_active = true
                AND b.categories ?| $1
                AND b.id != ALL($2)
                AND b.average_rating >= 3.5
                ORDER BY b.average_rating DESC, b.purchase_count DESC
                LIMIT $3
            """
            
            results = await self.db.fetch_all(
                recommendations_query, 
                [user_categories, purchased_book_ids, limit]
            )
            
            books = [self._row_to_book_catalog(row) for row in results]
            
            logger.info(f"Generated {len(books)} recommendations for user {user_id}")
            return books
            
        except Exception as e:
            logger.error(f"Failed to get recommendations: {e}")
            raise
    
    async def track_user_interaction(
        self, 
        user_id: UUID, 
        book_id: UUID, 
        interaction_type: InteractionType,
        source: str = 'browse',
        duration_seconds: Optional[int] = None
    ):
        """Track user interaction with a book for recommendations"""
        try:
            query = """
                INSERT INTO user_book_interactions 
                (user_id, book_id, interaction_type, interaction_count, 
                 last_interaction_at, source, duration_seconds)
                VALUES ($1, $2, $3, 1, NOW(), $4, $5)
                ON CONFLICT (user_id, book_id, interaction_type)
                DO UPDATE SET
                    interaction_count = user_book_interactions.interaction_count + 1,
                    last_interaction_at = NOW(),
                    duration_seconds = COALESCE($5, user_book_interactions.duration_seconds)
            """
            
            await self.db.execute_query(query, [
                str(user_id), str(book_id), interaction_type.value, 
                source, duration_seconds
            ])
            
            logger.debug(f"Tracked {interaction_type.value} interaction: {user_id} -> {book_id}")
            
        except Exception as e:
            logger.error(f"Failed to track user interaction: {e}")
            # Don't raise - interaction tracking shouldn't break the main flow
    
    def _row_to_book_catalog(self, row: Dict[str, Any]) -> BookCatalog:
        """Convert database row to BookCatalog object"""
        return BookCatalog(
            id=UUID(row['id']),
            title=row['title'],
            author=row['author'],
            isbn=row['isbn'],
            description=row['description'],
            cover_image_url=row['cover_image_url'],
            audio_file_path=row['audio_file_path'],
            duration_seconds=row['duration_seconds'],
            language=row['language'] or 'en',
            genre=row['genre'],
            publication_date=row['publication_date'],
            price_usd=Decimal(str(row['price_usd'])) if row['price_usd'] else Decimal('14.95'),
            credit_price=row['credit_price'] or 1,
            narrator=row['narrator'],
            publisher=row['publisher'],
            sample_audio_url=row['sample_audio_url'],
            sample_duration=row['sample_duration'],
            release_date=row['release_date'],
            bestseller_rank=row['bestseller_rank'],
            categories=row['categories'] or [],
            tags=row['tags'] or [],
            average_rating=Decimal(str(row['average_rating'])) if row['average_rating'] else Decimal('0.00'),
            rating_count=row['rating_count'] or 0,
            purchase_count=row['purchase_count'] or 0,
            is_featured=row['is_featured'] or False,
            file_size_mb=Decimal(str(row['file_size_mb'])) if row['file_size_mb'] else None,
            content_rating=row['content_rating'] or 'G',
            is_active=row['is_active'],
            created_at=row['created_at'],
            updated_at=row['updated_at']
        )
    
    async def _add_book_counts_to_categories(self, categories_dict: Dict[UUID, BookCategory]):
        """Add book counts to each category"""
        try:
            # Get book counts per category
            count_query = """
                SELECT 
                    unnest(categories::text[])::uuid as category_id,
                    COUNT(*) as book_count
                FROM books
                WHERE is_active = true
                GROUP BY unnest(categories::text[])
            """
            
            count_results = await self.db.fetch_all(count_query)
            
            for row in count_results:
                category_id = UUID(row['category_id'])
                if category_id in categories_dict:
                    categories_dict[category_id].book_count = row['book_count']
            
        except Exception as e:
            logger.error(f"Failed to add book counts to categories: {e}")
            # Don't raise - counts are optional