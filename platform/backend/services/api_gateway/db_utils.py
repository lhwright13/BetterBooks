"""
Database Utilities for API Gateway
Simple database connection and query helpers
Updated: Fixed fallback data for Gatsby and Moby Dick books
"""

import os
import psycopg2
import psycopg2.extras
import logging
from typing import Dict, List, Any, Optional

logger = logging.getLogger(__name__)

def get_db_connection():
    """Get database connection using environment variables"""
    # Try to get database URL from environment first
    db_url = os.getenv('DATABASE_URL')
    if not db_url:
        # Fallback to local Docker connection for development
        db_url = "postgresql://betterbooks:testpassword123@postgres_primary:5432/betterbooks"
    
    logger.info(f"Connecting to database: {db_url.split('@')[1] if '@' in db_url else 'local'}")
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
        # Start with empty library - user needs to purchase books
        return {
            'books': [],
            'total_books': 0
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
        # Fallback to hardcoded book data when database is unavailable
        fallback_books = [
            {
                'id': 'gatsby-001',
                'title': 'The Great Gatsby',
                'author': 'F. Scott Fitzgerald',
                'cover_image_url': '/books/cover/The Great Gatsby/GatsbyCover.jpg',
                'price_usd': 14.95,
                'credit_price': 1,
                'is_featured': True,
                'is_bestseller': True,
                'is_new_release': False
            },
            {
                'id': 'mobydick-001', 
                'title': 'Moby Dick',
                'author': 'Herman Melville',
                'cover_image_url': '/books/cover/Moby Dick/Moby_Dick_1002.jpg',
                'price_usd': 14.95,
                'credit_price': 1,
                'is_featured': True,
                'is_bestseller': False,
                'is_new_release': False
            }
        ]
        
        # Apply filters if any
        filtered_books = fallback_books
        if featured_only:
            filtered_books = [book for book in fallback_books if book['is_featured']]
            
        return {
            'books': filtered_books,
            'total_books': len(filtered_books)
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

def get_book_details(book_id: str) -> Optional[Dict[str, Any]]:
    """Get detailed book information including chapters"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Get basic book info
                cursor.execute("""
                    SELECT 
                        id,
                        title,
                        author,
                        description,
                        cover_image_url,
                        price_usd,
                        credit_price,
                        is_featured,
                        is_bestseller,
                        is_new_release
                    FROM books 
                    WHERE id = %s
                """, (book_id,))
                
                book_data = cursor.fetchone()
                if not book_data:
                    return None
                
                # Convert to dict
                result = dict(book_data)
                
                # Get chapters for this book
                cursor.execute("""
                    SELECT 
                        id,
                        title,
                        chapter_number,
                        duration_seconds as duration,
                        file_path
                    FROM book_chapters 
                    WHERE book_id = %s 
                    ORDER BY chapter_number
                """, (book_id,))
                
                chapters_data = cursor.fetchall()
                chapters = []
                
                for chapter in chapters_data:
                    # Extract folder and filename from file_path
                    if chapter['file_path']:
                        # file_path format: "The Great Gatsby/Chapter 1.mp3"
                        file_path = chapter['file_path']
                        # Create proper audio URL using the existing file serving endpoint
                        audio_url = f"/books/{file_path}"
                        
                        chapters.append({
                            'id': str(chapter['id']),
                            'title': chapter['title'],
                            'audio_url': audio_url,
                            'chapter_number': chapter['chapter_number'],
                            'duration': chapter.get('duration')
                        })
                
                result['chapters'] = chapters
                
                # Calculate total duration
                total_duration = sum(ch.get('duration', 0) for ch in chapters if ch.get('duration'))
                result['total_duration'] = total_duration if total_duration > 0 else None
                
                return result
                
    except Exception as e:
        logger.error(f"Database error getting book details for {book_id}: {e}")
        
        # Fallback data for both books
        if book_id == "gatsby-001":
            chapters = []
            for i in range(1, 10):  # 9 chapters
                chapters.append({
                    'id': f'gatsby-ch-{i}',
                    'title': f'Chapter {i}',
                    'audio_url': f'/books/The Great Gatsby/Chapter {i}.mp3',
                    'chapter_number': i,
                    'duration': 1800  # 30 minutes estimate
                })
            
            return {
                'id': book_id,
                'title': 'The Great Gatsby',
                'author': 'F. Scott Fitzgerald',
                'description': 'A classic American novel set in the Jazz Age, exploring themes of wealth, love, idealism and moral decay.',
                'cover_image_url': '/books/cover/The Great Gatsby/GatsbyCover.jpg',
                'price_usd': 14.95,
                'credit_price': 1,
                'is_featured': True,
                'is_bestseller': True,
                'is_new_release': False,
                'chapters': chapters,
                'total_duration': 16200  # 4.5 hours estimate
            }
        elif book_id == "mobydick-001":
            # Moby Dick chapters based on actual files
            moby_chapters = [
                {'file': 'mobydick_000_melville_64kb.mp3', 'title': 'Introduction'},
                {'file': 'mobydick_001_002_melville_64kb.mp3', 'title': 'Chapters 1-2'},
                {'file': 'mobydick_003_melville_64kb.mp3', 'title': 'Chapter 3'},
                {'file': 'mobydick_004_007_melville_64kb.mp3', 'title': 'Chapters 4-7'},
                {'file': 'mobydick_008_009_melville_64kb.mp3', 'title': 'Chapters 8-9'},
                {'file': 'mobydick_010_012_melville_64kb.mp3', 'title': 'Chapters 10-12'},
                {'file': 'mobydick_013_015_melville_64kb.mp3', 'title': 'Chapters 13-15'},
                {'file': 'mobydick_016_melville_64kb.mp3', 'title': 'Chapter 16'},
                {'file': 'mobydick_017_021_melville_64kb.mp3', 'title': 'Chapters 17-21'},
                {'file': 'mobydick_022_025_melville_64kb.mp3', 'title': 'Chapters 22-25'},
                {'file': 'mobydick_026_027_melville_64kb.mp3', 'title': 'Chapters 26-27'},
                {'file': 'mobydick_028_031_melville_64kb.mp3', 'title': 'Chapters 28-31'},
                {'file': 'mobydick_032_melville_64kb.mp3', 'title': 'Chapter 32'},
                {'file': 'mobydick_033_035_melville_64kb.mp3', 'title': 'Chapters 33-35'},
                {'file': 'mobydick_036_040_melville_64kb.mp3', 'title': 'Chapters 36-40'},
                {'file': 'mobydick_041_melville_64kb.mp3', 'title': 'Chapter 41'},
                {'file': 'mobydick_042_044_melville_64kb.mp3', 'title': 'Chapters 42-44'},
                {'file': 'mobydick_045_047_melville_64kb.mp3', 'title': 'Chapters 45-47'},
                {'file': 'mobydick_048_050_melville_64kb.mp3', 'title': 'Chapters 48-50'},
                {'file': 'mobydick_051_053_melville_64kb.mp3', 'title': 'Chapters 51-53'},
            ]
            
            chapters = []
            for i, chapter_info in enumerate(moby_chapters[:20], 1):  # First 20 parts
                chapters.append({
                    'id': f'moby-ch-{i}',
                    'title': chapter_info['title'],
                    'audio_url': f'/books/Moby Dick/{chapter_info["file"]}',
                    'chapter_number': i,
                    'duration': 1200  # 20 minutes estimate per part
                })
            
            return {
                'id': book_id,
                'title': 'Moby Dick',
                'author': 'Herman Melville',
                'description': 'The epic tale of Captain Ahab\'s obsessive quest to kill the white whale that took his leg. A masterpiece of American literature exploring themes of fate, nature, and the human condition.',
                'cover_image_url': '/books/cover/Moby Dick/Moby_Dick_1002.jpg',
                'price_usd': 14.95,
                'credit_price': 1,
                'is_featured': True,
                'is_bestseller': False,
                'is_new_release': False,
                'chapters': chapters,
                'total_duration': 24000  # 400 minutes estimate
            }
        
        return None