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
from azure_storage_helper import AzureStorageHelper

logger = logging.getLogger(__name__)

# Initialize Azure Storage helper
azure_storage = AzureStorageHelper()

def get_db_connection():
    """Get database connection using environment variables with smart fallbacks"""
    # Try to get database URL from environment first
    db_url = os.getenv('DATABASE_URL')
    
    if not db_url:
        # Determine if we're running in Docker or local development
        # In Docker, use postgres_primary, locally use localhost
        if os.path.exists('/.dockerenv') or os.getenv('DOCKER_ENV'):
            # Running in Docker container
            db_url = "postgresql://betterbooks:testpassword123@postgres_primary:5432/betterbooks"
        else:
            # Running locally - use localhost
            db_url = "postgresql://betterbooks:testpassword123@localhost:5432/betterbooks"
    
    # Mask password in logs
    log_url = db_url.split('@')[1] if '@' in db_url else 'local'
    logger.info(f"Connecting to database: {log_url}")
    
    try:
        return psycopg2.connect(db_url)
    except psycopg2.Error as e:
        logger.error(f"Database connection failed: {e}")
        # Try fallback to localhost if Docker connection fails
        if 'postgres_primary' in db_url:
            fallback_url = db_url.replace('postgres_primary', 'localhost')
            logger.info("Trying localhost fallback...")
            return psycopg2.connect(fallback_url)
        raise

def get_user_credits(user_id: str) -> Optional[Dict[str, Any]]:
    """Get user credit information from database"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # First try to get existing credits
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
                    # Initialize new user with 2 free credits
                    cursor.execute("""
                        INSERT INTO user_credits (user_id, total_credits, used_credits)
                        VALUES (%s, 2, 0)
                        RETURNING total_credits, used_credits, (total_credits - used_credits) as available_credits
                    """, (user_id,))
                    
                    new_result = cursor.fetchone()
                    conn.commit()
                    logger.info(f"Initialized new user {user_id} with 2 credits")
                    return dict(new_result) if new_result else None
                    
    except psycopg2.Error as e:
        logger.error(f"Database error getting user credits: {e}")
        # Return fallback for database connection issues
        return {
            'total_credits': 2,
            'used_credits': 0,
            'available_credits': 2
        }
    except Exception as e:
        logger.error(f"Unexpected error getting user credits: {e}")
        # Return None for other errors (like programming errors)
        return None

def get_user_library(user_id: str, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
    """Get user's library from database based on actual purchases"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Get library from user_purchases joined with books
                cursor.execute("""
                    SELECT 
                        b.id,
                        b.title,
                        b.author,
                        b.cover_image_url,
                        COALESCE(ul.last_position_seconds::numeric / NULLIF(b.duration_minutes * 60, 0), 0.0) as progress,
                        up.purchase_date as purchased_at
                    FROM user_purchases up
                    JOIN books b ON up.book_id::uuid = b.id
                    LEFT JOIN user_library ul ON ul.user_id = up.user_id AND ul.book_id = b.id::text
                    WHERE up.user_id = %s
                    ORDER BY up.purchase_date DESC
                    LIMIT %s OFFSET %s
                """, (user_id, limit, offset))
                
                books = [dict(row) for row in cursor.fetchall()]
                
                # Add sample audio URLs for iOS compatibility
                for book in books:
                    book['sample_audio_url'] = _generate_sample_audio_url(book['title'])
                    book['duration_seconds'] = _get_book_duration_seconds(book['title'])
                
                # Get total count
                cursor.execute("""
                    SELECT COUNT(*) 
                    FROM user_purchases 
                    WHERE user_id = %s
                """, (user_id,))
                
                total_count = cursor.fetchone()['count']
                
                return {
                    'books': books,
                    'total_books': total_count
                }
    except psycopg2.Error as e:
        logger.error(f"Database error getting user library: {e}")
        # Return empty library for database errors
        return {
            'books': [],
            'total_books': 0
        }
    except Exception as e:
        logger.error(f"Unexpected error getting user library: {e}")
        return {
            'books': [],
            'total_books': 0
        }

def _generate_sample_audio_url(book_title: str) -> str:
    """Generate sample audio URL based on book title and available files"""
    # Map book titles to first audio file names
    audio_files = {
        "Alice's Adventures in Wonderland": "alices_adventures_01_carroll_64kb.mp3",
        "Moby Dick": "mobydick_001_002_melville_64kb.mp3", 
        "The Great Gatsby": "gatsby_chapter_01.mp3",
        "War and Peace": "warandpeace_001_tolstoy_64kb.mp3"
    }
    
    # Get first audio file for this book
    filename = audio_files.get(book_title, "")
    if filename:
        # Return the API endpoint that serves from Azure Storage
        return f"/books/{book_title}/{filename}"
    
    return None

def _get_book_duration_seconds(book_title: str) -> int:
    """Get estimated book duration in seconds"""
    # Approximate durations based on typical audiobook lengths
    durations = {
        "Alice's Adventures in Wonderland": 4800,  # ~1.3 hours
        "Moby Dick": 86400,  # ~24 hours
        "The Great Gatsby": 18000,  # ~5 hours  
        "War and Peace": 216000  # ~60 hours
    }
    
    return durations.get(book_title, 3600)  # Default 1 hour

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

def create_purchase(user_id: str, book_id: str, credits_used: int = 1, purchase_type: str = "credit") -> bool:
    """Create a book purchase record and update user credits"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Start transaction
                cursor.execute("BEGIN")
                
                # Check if user already owns the book
                cursor.execute("""
                    SELECT id FROM user_purchases 
                    WHERE user_id = %s AND book_id = %s
                """, (user_id, book_id))
                
                if cursor.fetchone():
                    cursor.execute("ROLLBACK")
                    logger.warning(f"User {user_id} already owns book {book_id}")
                    return False
                
                # Verify user has enough credits
                cursor.execute("""
                    SELECT total_credits - used_credits as available_credits
                    FROM user_credits 
                    WHERE user_id = %s
                """, (user_id,))
                
                credit_result = cursor.fetchone()
                if not credit_result or credit_result['available_credits'] < credits_used:
                    cursor.execute("ROLLBACK")
                    logger.warning(f"User {user_id} has insufficient credits")
                    return False
                
                # Get book price for record keeping
                cursor.execute("""
                    SELECT price_usd FROM books WHERE id = %s
                """, (book_id,))
                
                book_result = cursor.fetchone()
                if not book_result:
                    cursor.execute("ROLLBACK")
                    logger.error(f"Book {book_id} not found")
                    return False
                
                # Create purchase record
                cursor.execute("""
                    INSERT INTO user_purchases (user_id, book_id, purchase_type, credits_used, price_paid)
                    VALUES (%s, %s, %s, %s, %s)
                """, (user_id, book_id, purchase_type, credits_used, book_result['price_usd']))
                
                # Update user credits
                cursor.execute("""
                    UPDATE user_credits 
                    SET used_credits = used_credits + %s, 
                        last_updated = NOW()
                    WHERE user_id = %s
                """, (credits_used, user_id))
                
                # Add book to user library (map credit purchase to purchase access type)
                access_type = "purchase" if purchase_type == "credit" else purchase_type
                cursor.execute("""
                    INSERT INTO user_library (user_id, book_id, acquired_at, access_type)
                    VALUES (%s, %s, NOW(), %s)
                    ON CONFLICT (user_id, book_id) DO NOTHING
                """, (user_id, book_id, access_type))
                
                # Commit transaction
                cursor.execute("COMMIT")
                logger.info(f"Successfully created purchase: user {user_id}, book {book_id}, credits {credits_used}")
                return True
                
    except Exception as e:
        logger.error(f"Error creating purchase: {e}")
        return False

def check_user_owns_book(user_id: str, book_id: str) -> bool:
    """Check if user owns a specific book"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT 1 FROM user_purchases 
                    WHERE user_id = %s AND book_id = %s
                    LIMIT 1
                """, (user_id, book_id))
                
                return cursor.fetchone() is not None
    except Exception as e:
        logger.error(f"Error checking book ownership: {e}")
        return False

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
                    ORDER BY 
                        CASE WHEN is_featured THEN 0 ELSE 1 END,
                        CASE WHEN is_bestseller THEN 0 ELSE 1 END,
                        created_at DESC
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
        # Return empty result on database error - no hardcoded fallback
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
                    # Handle different file_path formats
                    if chapter['file_path']:
                        file_path = chapter['file_path']
                        
                        # Check if it's already a full URL (LibriVox, etc.)
                        if file_path.startswith(('http://', 'https://')):
                            # Use LibriVox or other external URL directly
                            audio_url = file_path
                        else:
                            # Legacy local file path - try Azure storage first
                            audio_url = None
                            if '/' in file_path:
                                book_folder, filename = file_path.split('/', 1)
                                azure_url = azure_storage.generate_audio_url(book_folder, filename)
                                if azure_url:
                                    audio_url = azure_url
                            
                            # Fallback to local file serving endpoint if Azure not available
                            if not audio_url:
                                audio_url = f"/books/{file_path}"
                        
                        chapters.append({
                            'id': str(chapter['id']),
                            'title': chapter['title'],
                            'audio_url': audio_url,
                            'chapter_number': chapter['chapter_number'],
                            'duration': chapter.get('duration'),
                            'file_path': file_path  # Keep for download functionality
                        })
                
                result['chapters'] = chapters
                
                # Calculate total duration
                total_duration = sum(ch.get('duration', 0) for ch in chapters if ch.get('duration'))
                result['total_duration'] = total_duration if total_duration > 0 else None
                
                return result
                
    except Exception as e:
        logger.error(f"Database error getting book details for {book_id}: {e}")
        return None


def get_book_personas(book_id: str) -> Optional[Dict[str, Any]]:
    """Get all personas associated with a book"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Get book title
                cursor.execute("SELECT title FROM books WHERE id = %s", (book_id,))
                book = cursor.fetchone()
                if not book:
                    return None
                
                # Get personas for this book
                cursor.execute("""
                    SELECT 
                        bp.id,
                        bp.persona_id,
                        p.name as persona_name,
                        p.display_name as persona_display_name,
                        p.description as persona_description,
                        bp.is_default,
                        bp.custom_prompt,
                        bp.sort_order
                    FROM book_personas bp
                    JOIN personas p ON bp.persona_id = p.id
                    WHERE bp.book_id = %s
                    ORDER BY bp.sort_order ASC, p.display_name ASC
                """, (book_id,))
                
                personas = cursor.fetchall()
                
                return {
                    'book_id': book_id,
                    'book_title': book['title'],
                    'personas': personas
                }
                
    except Exception as e:
        logger.error(f"Database error getting personas for book {book_id}: {e}")
        return None


def get_persona_details(persona_id: str) -> Optional[Dict[str, Any]]:
    """Get detailed persona information"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT 
                        id, name, display_name, description, base_prompt,
                        voice_config, generation_config, tts_config, is_global,
                        created_at, updated_at
                    FROM personas 
                    WHERE id = %s
                """, (persona_id,))
                
                return cursor.fetchone()
                
    except Exception as e:
        logger.error(f"Database error getting persona {persona_id}: {e}")
        return None


def get_all_personas() -> List[Dict[str, Any]]:
    """Get all available personas"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT 
                        id, name, display_name, description, 
                        is_global, created_at, updated_at
                    FROM personas 
                    ORDER BY is_global DESC, display_name ASC
                """)
                
                return cursor.fetchall()
                
    except Exception as e:
        logger.error(f"Database error getting all personas: {e}")
        return []


def create_persona(persona_data: Dict[str, Any]) -> Optional[str]:
    """Create a new persona and return its ID"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    INSERT INTO personas 
                    (name, display_name, description, base_prompt, voice_config, 
                     generation_config, tts_config, is_global)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (
                    persona_data['name'],
                    persona_data['display_name'],
                    persona_data.get('description', ''),
                    persona_data['base_prompt'],
                    persona_data.get('voice_config', {}),
                    persona_data.get('generation_config', {}),
                    persona_data.get('tts_config', {}),
                    persona_data.get('is_global', False)
                ))
                
                result = cursor.fetchone()
                conn.commit()
                return str(result['id'])
                
    except Exception as e:
        logger.error(f"Database error creating persona: {e}")
        return None


def update_persona(persona_id: str, persona_data: Dict[str, Any]) -> bool:
    """Update an existing persona"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    UPDATE personas SET
                        display_name = %s,
                        description = %s,
                        base_prompt = %s,
                        voice_config = %s,
                        generation_config = %s,
                        tts_config = %s,
                        is_global = %s,
                        updated_at = NOW()
                    WHERE id = %s
                """, (
                    persona_data['display_name'],
                    persona_data.get('description', ''),
                    persona_data['base_prompt'],
                    persona_data.get('voice_config', {}),
                    persona_data.get('generation_config', {}),
                    persona_data.get('tts_config', {}),
                    persona_data.get('is_global', False),
                    persona_id
                ))
                
                conn.commit()
                return cursor.rowcount > 0
                
    except Exception as e:
        logger.error(f"Database error updating persona {persona_id}: {e}")
        return False


def delete_persona(persona_id: str) -> bool:
    """Delete a persona (also removes book-persona relationships)"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("DELETE FROM personas WHERE id = %s", (persona_id,))
                conn.commit()
                return cursor.rowcount > 0
                
    except Exception as e:
        logger.error(f"Database error deleting persona {persona_id}: {e}")
        return False


def add_persona_to_book(book_id: str, persona_id: str, is_default: bool = False, sort_order: int = 0) -> bool:
    """Add a persona to a book"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO book_personas (book_id, persona_id, is_default, sort_order)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (book_id, persona_id) DO UPDATE SET
                        is_default = EXCLUDED.is_default,
                        sort_order = EXCLUDED.sort_order
                """, (book_id, persona_id, is_default, sort_order))
                
                conn.commit()
                return True
                
    except Exception as e:
        logger.error(f"Database error adding persona {persona_id} to book {book_id}: {e}")
        return False


def remove_persona_from_book(book_id: str, persona_id: str) -> bool:
    """Remove a persona from a book"""
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM book_personas 
                    WHERE book_id = %s AND persona_id = %s
                """, (book_id, persona_id))
                
                conn.commit()
                return cursor.rowcount > 0
                
    except Exception as e:
        logger.error(f"Database error removing persona {persona_id} from book {book_id}: {e}")
        return False