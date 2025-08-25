"""
Recommendation Engine for BetterBooks
Provides personalized book recommendations based on user behavior and preferences.
"""

from typing import List, Optional, Dict, Any
from uuid import UUID
import logging
from decimal import Decimal

from .models import BookCatalog, RecommendationResponse

logger = logging.getLogger(__name__)


class RecommendationEngine:
    """
    Handles personalized book recommendations for users.
    
    Future implementations will include:
    - Collaborative filtering based on similar user preferences
    - Content-based filtering using book metadata
    - Hybrid recommendations combining multiple approaches
    - ML model integration for advanced personalization
    """
    
    def __init__(self, db_manager):
        self.db_manager = db_manager
    
    async def get_personalized_recommendations(self, 
                                             user_id: UUID, 
                                             limit: int = 10) -> List[BookCatalog]:
        """
        Get personalized book recommendations for a user.
        
        Currently returns popular/featured books as a stub implementation.
        Future versions will use ML models and user behavior analysis.
        
        Args:
            user_id: User to get recommendations for
            limit: Maximum number of recommendations to return
            
        Returns:
            List of recommended books
        """
        try:
            # Stub implementation: return featured/popular books
            # TODO: Implement actual recommendation algorithm
            query = """
                SELECT b.*, 
                       COALESCE(AVG(br.rating), 0) as avg_rating,
                       COUNT(br.id) as review_count,
                       COUNT(up.id) as purchase_count
                FROM books b
                LEFT JOIN book_reviews br ON b.id = br.book_id
                LEFT JOIN user_purchases up ON b.id = up.book_id
                WHERE b.is_featured = true OR b.is_bestseller = true
                GROUP BY b.id
                ORDER BY purchase_count DESC, avg_rating DESC
                LIMIT %s
            """
            
            async with self.db_manager.get_connection() as conn:
                async with conn.cursor() as cursor:
                    await cursor.execute(query, (limit,))
                    rows = await cursor.fetchall()
                    
                    recommendations = []
                    for row in rows:
                        book = BookCatalog(
                            id=row[0],
                            title=row[1],
                            author=row[2],
                            narrator=row[3],
                            description=row[4],
                            duration_minutes=row[5],
                            language=row[6],
                            isbn=row[7],
                            cover_image_url=row[8],
                            sample_audio_url=row[9],
                            price_usd=Decimal(str(row[10])) if row[10] else Decimal('14.95'),
                            credit_price=row[11] or 1,
                            category_id=row[12],
                            is_featured=row[13] or False,
                            is_bestseller=row[14] or False,
                            is_new_release=row[15] or False,
                            publication_date=row[16],
                            created_at=row[17],
                            updated_at=row[18]
                        )
                        recommendations.append(book)
                    
                    return recommendations
                    
        except Exception as e:
            logger.error(f"Error getting personalized recommendations: {e}")
            return []
    
    async def get_similar_books(self, 
                               book_id: UUID, 
                               limit: int = 5) -> List[BookCatalog]:
        """
        Get books similar to a given book.
        
        Currently returns books from the same category as a stub implementation.
        Future versions will use content similarity algorithms.
        
        Args:
            book_id: Book to find similar books for
            limit: Maximum number of similar books to return
            
        Returns:
            List of similar books
        """
        try:
            query = """
                SELECT b2.*, 
                       COALESCE(AVG(br.rating), 0) as avg_rating,
                       COUNT(br.id) as review_count
                FROM books b1
                JOIN books b2 ON b1.category_id = b2.category_id
                LEFT JOIN book_reviews br ON b2.id = br.book_id
                WHERE b1.id = %s AND b2.id != %s
                GROUP BY b2.id
                ORDER BY avg_rating DESC, review_count DESC
                LIMIT %s
            """
            
            async with self.db_manager.get_connection() as conn:
                async with conn.cursor() as cursor:
                    await cursor.execute(query, (book_id, book_id, limit))
                    rows = await cursor.fetchall()
                    
                    similar_books = []
                    for row in rows:
                        book = BookCatalog(
                            id=row[0],
                            title=row[1],
                            author=row[2],
                            narrator=row[3],
                            description=row[4],
                            duration_minutes=row[5],
                            language=row[6],
                            isbn=row[7],
                            cover_image_url=row[8],
                            sample_audio_url=row[9],
                            price_usd=Decimal(str(row[10])) if row[10] else Decimal('14.95'),
                            credit_price=row[11] or 1,
                            category_id=row[12],
                            is_featured=row[13] or False,
                            is_bestseller=row[14] or False,
                            is_new_release=row[15] or False,
                            publication_date=row[16],
                            created_at=row[17],
                            updated_at=row[18]
                        )
                        similar_books.append(book)
                    
                    return similar_books
                    
        except Exception as e:
            logger.error(f"Error getting similar books: {e}")
            return []
    
    async def get_trending_books(self, limit: int = 10) -> List[BookCatalog]:
        """
        Get currently trending books based on recent purchase activity.
        
        Args:
            limit: Maximum number of trending books to return
            
        Returns:
            List of trending books
        """
        try:
            query = """
                SELECT b.*, 
                       COUNT(up.id) as recent_purchases,
                       COALESCE(AVG(br.rating), 0) as avg_rating
                FROM books b
                LEFT JOIN user_purchases up ON b.id = up.book_id 
                    AND up.purchase_date > NOW() - INTERVAL '7 days'
                LEFT JOIN book_reviews br ON b.id = br.book_id
                GROUP BY b.id
                HAVING COUNT(up.id) > 0
                ORDER BY recent_purchases DESC, avg_rating DESC
                LIMIT %s
            """
            
            async with self.db_manager.get_connection() as conn:
                async with conn.cursor() as cursor:
                    await cursor.execute(query, (limit,))
                    rows = await cursor.fetchall()
                    
                    trending_books = []
                    for row in rows:
                        book = BookCatalog(
                            id=row[0],
                            title=row[1],
                            author=row[2],
                            narrator=row[3],
                            description=row[4],
                            duration_minutes=row[5],
                            language=row[6],
                            isbn=row[7],
                            cover_image_url=row[8],
                            sample_audio_url=row[9],
                            price_usd=Decimal(str(row[10])) if row[10] else Decimal('14.95'),
                            credit_price=row[11] or 1,
                            category_id=row[12],
                            is_featured=row[13] or False,
                            is_bestseller=row[14] or False,
                            is_new_release=row[15] or False,
                            publication_date=row[16],
                            created_at=row[17],
                            updated_at=row[18]
                        )
                        trending_books.append(book)
                    
                    return trending_books
                    
        except Exception as e:
            logger.error(f"Error getting trending books: {e}")
            return []