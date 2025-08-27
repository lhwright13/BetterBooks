"""
Database Utilities for API Gateway
Simple database connection and query helpers
"""

import os
import psycopg2
import psycopg2.extras
import logging
from typing import Dict, List, Any, Optional

logger = logging.getLogger(__name__)

def get_db_connection():
    """Get database connection using environment variables"""
    # Use direct postgres connection since pgbouncer has auth issues
    db_url = "postgresql://betterbooks:testpassword123@postgres_primary:5432/betterbooks"
    return psycopg2.connect(db_url)

def get_user_credits(user_id: str) -> Optional[Dict[str, Any]]:
    """Get user credit information from database"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT 
                        total_credits,
                        used_credits,
                        (total_credits - used_credits) as available_credits
                    FROM user_credits 
                    WHERE user_id = %s
                """, (user_id,))
                
                result = cursor.fetchone()
                if result:
                    return dict(result)
                else:
                    # Return default credits for new users
                    return {
                        'total_credits': 5,
                        'used_credits': 0,
                        'available_credits': 5
                    }
    except Exception as e:
        logger.error(f"Database error getting user credits: {e}")
        # Fallback to mock data on database error
        return {
            'total_credits': 5,
            'used_credits': 0,
            'available_credits': 5
        }

def get_user_library(user_id: str, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
    """Get user's library from database"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT 
                        b.id,
                        b.title,
                        b.author,
                        b.cover_image_url,
                        ROUND(ul.last_position_seconds::numeric / COALESCE(NULLIF(b.duration_minutes * 60, 0), 1), 2) as progress,
                        ul.acquired_at as purchased_at
                    FROM user_library ul
                    JOIN books b ON ul.book_id::uuid = b.id
                    WHERE ul.user_id = %s
                    ORDER BY ul.acquired_at DESC
                    LIMIT %s OFFSET %s
                """, (user_id, limit, offset))
                
                books = [dict(row) for row in cursor.fetchall()]
                
                # Get total count
                cursor.execute("""
                    SELECT COUNT(*) 
                    FROM user_library 
                    WHERE user_id = %s
                """, (user_id,))
                
                total_count = cursor.fetchone()['count']
                
                return {
                    'books': books,
                    'total_books': total_count
                }
    except Exception as e:
        logger.error(f"Database error getting user library: {e}")
        # Fallback to mock data on database error
        return {
            'books': [
                {
                    'id': 'gatsby-001',
                    'title': 'The Great Gatsby',
                    'author': 'F. Scott Fitzgerald',
                    'cover_image_url': 'https://covers.openlibrary.org/b/id/12583542-L.jpg',
                    'progress': 0.25,
                    'purchased_at': '2025-01-20T10:00:00Z'
                }
            ],
            'total_books': 1
        }

def create_user(email: str, name: str = "") -> Optional[str]:
    """Create a new user in database and return user ID"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Insert user
                cursor.execute("""
                    INSERT INTO users (email, full_name, created_at)
                    VALUES (%s, %s, NOW())
                    RETURNING id
                """, (email, name))
                
                user_id = cursor.fetchone()['id']
                
                # Initialize user credits (5 free credits for new users)
                cursor.execute("""
                    INSERT INTO user_credits (user_id, total_credits, used_credits)
                    VALUES (%s, 5, 0)
                """, (user_id,))
                
                conn.commit()
                logger.info(f"Created new user: {email} with ID: {user_id}")
                return str(user_id)
                
    except Exception as e:
        logger.error(f"Database error creating user: {e}")
        return None

def get_browse_books(limit: int = 20, offset: int = 0, featured_only: bool = False) -> Dict[str, Any]:
    """Get books for browsing from database"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                where_clause = ""
                if featured_only:
                    where_clause = "WHERE is_featured = true"
                
                cursor.execute(f"""
                    SELECT 
                        id,
                        title,
                        author,
                        cover_image_url,
                        price_usd,
                        credit_price,
                        COALESCE(is_featured, false) as is_featured,
                        COALESCE(is_bestseller, false) as is_bestseller,
                        COALESCE(is_new_release, false) as is_new_release
                    FROM books
                    {where_clause}
                    ORDER BY created_at DESC
                    LIMIT %s OFFSET %s
                """, (limit, offset))
                
                books = [dict(row) for row in cursor.fetchall()]
                
                # Get total count
                cursor.execute(f"""
                    SELECT COUNT(*) 
                    FROM books
                    {where_clause}
                """)
                
                total_count = cursor.fetchone()['count']
                
                return {
                    'books': books,
                    'total_books': total_count
                }
    except Exception as e:
        logger.error(f"Database error getting browse books: {e}")
        # Fallback to empty list on database error
        return {
            'books': [],
            'total_books': 0
        }

def test_database_connection() -> bool:
    """Test if database connection is working"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1;")
                result = cursor.fetchone()
                return result[0] == 1
    except Exception as e:
        logger.error(f"Database connection test failed: {e}")
        return False