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
from storage_helper import get_storage

logger = logging.getLogger(__name__)

# Initialize storage helper (auto-selects S3, Azure, or local based on config)
storage = get_storage()

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
        return psycopg2.connect(db_url, connect_timeout=10)
    except psycopg2.Error as e:
        logger.error(f"Database connection failed: {e}")
        # Try fallback to localhost if Docker connection fails
        if 'postgres_primary' in db_url:
            fallback_url = db_url.replace('postgres_primary', 'localhost')
            logger.info("Trying localhost fallback...")
            return psycopg2.connect(fallback_url, connect_timeout=10)
        raise

def get_user_by_id(user_id: str) -> Optional[Dict[str, Any]]:
    """Get user information from database by user ID"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT id, email, username, display_name, role, is_active, 
                           email_verified, created_at, updated_at
                    FROM users 
                    WHERE id = %s
                """, (user_id,))
                
                user = cursor.fetchone()
                if user:
                    return dict(user)
                
    except Exception as e:
        logger.error(f"Error getting user by ID {user_id}: {e}")
    
    return None

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
                    # Initialize new user with 5 free credits
                    cursor.execute("""
                        INSERT INTO user_credits (user_id, total_credits, used_credits)
                        VALUES (%s, 5, 0)
                        RETURNING total_credits, used_credits, (total_credits - used_credits) as available_credits
                    """, (user_id,))
                    
                    new_result = cursor.fetchone()
                    conn.commit()
                    logger.info(f"Initialized new user {user_id} with 5 credits")
                    return dict(new_result) if new_result else None
                    
    except psycopg2.Error as e:
        logger.error(f"Database error getting user credits: {e}")
        # Return fallback for database connection issues
        return {
            'total_credits': 5,
            'used_credits': 0,
            'available_credits': 5
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
                # Get library from user_purchases joined with books and reading progress
                cursor.execute("""
                    SELECT
                        b.id,
                        b.title,
                        b.author,
                        b.cover_image_url,
                        COALESCE(urp.completion_percentage, 0.0) as progress,
                        up.purchase_date as purchased_at
                    FROM user_purchases up
                    JOIN books b ON up.book_id = b.id
                    LEFT JOIN user_reading_progress urp ON urp.user_id = up.user_id AND urp.book_id = b.id
                    WHERE up.user_id = %s::uuid
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
                where_clause = "WHERE title != 'Pride and Prejudice'"
                if featured_only:
                    where_clause = "WHERE title != 'Pride and Prejudice' AND is_featured = true"
                
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
                                cloud_url = storage.generate_audio_url(book_folder, filename)
                                if cloud_url:
                                    audio_url = cloud_url
                            
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


def search_books(query: str, limit: int = 20, offset: int = 0) -> Dict[str, Any]:
    """Search for books by title, author, or description"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Search in title, author, and description
                search_query = """
                    SELECT id, title, author, description, cover_image_url, 
                           price_usd, credit_price, is_featured, is_bestseller, is_new_release
                    FROM books 
                    WHERE (
                        title ILIKE %s OR 
                        author ILIKE %s OR 
                        description ILIKE %s
                    )
                    ORDER BY 
                        CASE 
                            WHEN title ILIKE %s THEN 1
                            WHEN author ILIKE %s THEN 2
                            ELSE 3
                        END,
                        title
                    LIMIT %s OFFSET %s
                """
                
                search_pattern = f"%{query}%"
                cursor.execute(search_query, (
                    search_pattern, search_pattern, search_pattern,  # WHERE conditions
                    search_pattern, search_pattern,                   # ORDER BY conditions
                    limit, offset
                ))
                
                books = cursor.fetchall()
                
                # Get total count for pagination
                count_query = """
                    SELECT COUNT(*) as total
                    FROM books 
                    WHERE (
                        title ILIKE %s OR 
                        author ILIKE %s OR 
                        description ILIKE %s
                    )
                """
                
                cursor.execute(count_query, (search_pattern, search_pattern, search_pattern))
                total_count = cursor.fetchone()['total']
                
                return {
                    'books': [dict(book) for book in books],
                    'total_books': total_count
                }
                
    except Exception as e:
        logger.error(f"Database error searching books with query '{query}': {e}")
        return {'books': [], 'total_books': 0}


def get_bestselling_books(limit: int = 10, offset: int = 0) -> Dict[str, Any]:
    """Get bestselling books (based on purchase count or is_bestseller flag)"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # First try to get books marked as bestsellers
                cursor.execute("""
                    SELECT b.id, b.title, b.author, b.description, b.cover_image_url,
                           b.price_usd, b.credit_price, b.is_featured, b.is_bestseller, b.is_new_release
                    FROM books b
                    WHERE b.is_bestseller = TRUE
                    ORDER BY b.title
                    LIMIT %s OFFSET %s
                """, (limit, offset))
                
                bestsellers = cursor.fetchall()
                
                # If no bestsellers found, fall back to most purchased books
                if not bestsellers:
                    cursor.execute("""
                        SELECT b.id, b.title, b.author, b.description, b.cover_image_url,
                               b.price_usd, b.credit_price, b.is_featured, b.is_bestseller, b.is_new_release,
                               COUNT(up.id) as purchase_count
                        FROM books b
                        LEFT JOIN user_purchases up ON b.id = up.book_id
                        GROUP BY b.id, b.title, b.author, b.description, b.cover_image_url,
                                 b.price_usd, b.credit_price, b.is_featured, b.is_bestseller, b.is_new_release
                        ORDER BY purchase_count DESC, b.title
                        LIMIT %s OFFSET %s
                    """, (limit, offset))
                    
                    bestsellers = cursor.fetchall()
                
                # Get total count
                cursor.execute("SELECT COUNT(*) as total FROM books WHERE is_bestseller = TRUE")
                total_count = cursor.fetchone()['total']
                
                return {
                    'books': [dict(book) for book in bestsellers],
                    'total_books': total_count
                }
                
    except Exception as e:
        logger.error(f"Database error getting bestselling books: {e}")
        return {'books': [], 'total_books': 0}


def initialize_user_credits(user_id: str, initial_credits: int = 5) -> Dict[str, Any]:
    """Initialize credits for a new user (only if they don't have credits already)"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Check if user already has credits
                cursor.execute("""
                    SELECT total_credits, used_credits, (total_credits - used_credits) as available_credits
                    FROM user_credits 
                    WHERE user_id = %s
                """, (user_id,))
                
                existing_credits = cursor.fetchone()
                if existing_credits:
                    raise ValueError("User already has credits initialized")
                
                # Initialize credits for new user
                cursor.execute("""
                    INSERT INTO user_credits (user_id, total_credits, used_credits)
                    VALUES (%s, %s, 0)
                    RETURNING total_credits, used_credits, (total_credits - used_credits) as available_credits
                """, (user_id, initial_credits))
                
                credits_data = cursor.fetchone()
                conn.commit()
                
                logger.info(f"Initialized {initial_credits} credits for user {user_id}")
                return dict(credits_data)
                
    except Exception as e:
        logger.error(f"Database error initializing credits for user {user_id}: {e}")
        raise


def add_to_user_wishlist(user_id: str, book_id: str) -> Dict[str, Any]:
    """Add a book to user's wishlist"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Check if book exists
                cursor.execute("SELECT id, title FROM books WHERE id = %s", (book_id,))
                book = cursor.fetchone()
                if not book:
                    raise ValueError("Book not found")
                
                # Check if already in wishlist
                cursor.execute("""
                    SELECT id FROM user_wishlists
                    WHERE user_id = %s AND book_id = %s
                """, (user_id, book_id))
                
                if cursor.fetchone():
                    raise ValueError("Book already in wishlist")
                
                # Add to wishlist
                cursor.execute("""
                    INSERT INTO user_wishlists (user_id, book_id, added_at)
                    VALUES (%s, %s, NOW())
                    RETURNING id, added_at
                """, (user_id, book_id))
                
                result = cursor.fetchone()
                conn.commit()
                
                logger.info(f"Added book {book_id} to user {user_id}'s wishlist")
                return {
                    'wishlist_id': result['id'],
                    'user_id': user_id,
                    'book_id': book_id,
                    'book_title': book['title'],
                    'added_at': result['added_at'].isoformat() if result['added_at'] else None,
                    'message': 'Book added to wishlist successfully'
                }
                
    except Exception as e:
        logger.error(f"Database error adding book {book_id} to user {user_id}'s wishlist: {e}")
        raise


def remove_from_user_wishlist(user_id: str, book_id: str) -> Dict[str, Any]:
    """Remove a book from user's wishlist"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Check if book is in wishlist
                cursor.execute("""
                    SELECT uw.id, b.title
                    FROM user_wishlists uw
                    JOIN books b ON uw.book_id = b.id
                    WHERE uw.user_id = %s AND uw.book_id = %s
                """, (user_id, book_id))
                
                wishlist_item = cursor.fetchone()
                if not wishlist_item:
                    raise ValueError("Book not found in wishlist")
                
                # Remove from wishlist
                cursor.execute("""
                    DELETE FROM user_wishlists
                    WHERE user_id = %s AND book_id = %s
                """, (user_id, book_id))
                
                conn.commit()
                
                logger.info(f"Removed book {book_id} from user {user_id}'s wishlist")
                return {
                    'user_id': user_id,
                    'book_id': book_id,
                    'book_title': wishlist_item['title'],
                    'message': 'Book removed from wishlist successfully'
                }
                
    except Exception as e:
        logger.error(f"Database error removing book {book_id} from user {user_id}'s wishlist: {e}")
        raise


def get_user_wishlist(user_id: str, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
    """Get user's wishlist with book details"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Get wishlist with book details
                cursor.execute("""
                    SELECT
                        uw.id as wishlist_id,
                        uw.book_id,
                        uw.added_at,
                        b.title,
                        b.author,
                        b.description,
                        b.cover_image_url,
                        b.price_usd,
                        b.credit_price,
                        b.is_featured,
                        b.is_bestseller,
                        b.is_new_release
                    FROM user_wishlists uw
                    JOIN books b ON uw.book_id = b.id
                    WHERE uw.user_id = %s
                    ORDER BY uw.added_at DESC
                    LIMIT %s OFFSET %s
                """, (user_id, limit, offset))
                
                wishlist_items = cursor.fetchall()
                
                # Get total count
                cursor.execute("""
                    SELECT COUNT(*) as total
                    FROM user_wishlists
                    WHERE user_id = %s
                """, (user_id,))
                
                total_count = cursor.fetchone()['total']
                
                # Format the response
                books = []
                for item in wishlist_items:
                    book_data = dict(item)
                    # Convert datetime to ISO format
                    if book_data.get('added_at'):
                        book_data['added_at'] = book_data['added_at'].isoformat()
                    books.append(book_data)
                
                return {
                    'books': books,
                    'total_books': total_count,
                    'user_id': user_id
                }
                
    except Exception as e:
        logger.error(f"Database error getting wishlist for user {user_id}: {e}")
        return {'books': [], 'total_books': 0, 'user_id': user_id}

def get_categories() -> Dict[str, Any]:
    """Get all active book categories from database"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT 
                        id,
                        name,
                        description,
                        image_url,
                        display_order,
                        is_active,
                        created_at,
                        updated_at
                    FROM book_categories
                    WHERE is_active = true
                    ORDER BY display_order ASC, name ASC
                """)
                
                categories = cursor.fetchall()
                
                # Format the response
                formatted_categories = []
                for category in categories:
                    category_data = dict(category)
                    # Convert UUIDs and timestamps to strings
                    if category_data.get('id'):
                        category_data['id'] = str(category_data['id'])
                    if category_data.get('created_at'):
                        category_data['created_at'] = category_data['created_at'].isoformat()
                    if category_data.get('updated_at'):
                        category_data['updated_at'] = category_data['updated_at'].isoformat()
                    formatted_categories.append(category_data)
                
                return {
                    'categories': formatted_categories,
                    'total_count': len(formatted_categories)
                }
                
    except Exception as e:
        logger.error(f"Database error getting categories: {e}")
        # Return fallback hardcoded categories on database failure
        return {
            'categories': [
                {
                    'id': 'classics',
                    'name': 'Classics',
                    'description': 'Timeless literary works that have shaped culture and thought',
                    'image_url': None,
                    'display_order': 1,
                    'is_active': True,
                    'created_at': '2025-01-01T00:00:00Z',
                    'updated_at': '2025-01-01T00:00:00Z'
                },
                {
                    'id': 'fiction',
                    'name': 'Fiction',
                    'description': 'Imaginative literature that tells compelling stories',
                    'image_url': None,
                    'display_order': 2,
                    'is_active': True,
                    'created_at': '2025-01-01T00:00:00Z',
                    'updated_at': '2025-01-01T00:00:00Z'
                },
                {
                    'id': 'adventure',
                    'name': 'Adventure',
                    'description': 'Thrilling tales of exploration, danger, and discovery',
                    'image_url': None,
                    'display_order': 3,
                    'is_active': True,
                    'created_at': '2025-01-01T00:00:00Z',
                    'updated_at': '2025-01-01T00:00:00Z'
                }
            ],
            'total_count': 3
        }

# =====================================================
# USER PROGRESS TRACKING FUNCTIONS
# =====================================================

def save_user_reading_progress(user_id: str, book_id: str, position: float) -> bool:
    """Save or update user's reading progress for a book"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # Get book duration to calculate completion percentage
        cur.execute("SELECT duration_minutes FROM books WHERE id = %s", (book_id,))
        book_row = cur.fetchone()
        duration_minutes = book_row[0] if book_row and book_row[0] else 0

        # Calculate completion percentage
        completion_pct = 0.0
        is_completed = False
        if duration_minutes > 0:
            duration_seconds = duration_minutes * 60
            completion_pct = min(100.0, (position / duration_seconds) * 100)
            is_completed = completion_pct >= 95.0

        # Use UPSERT (INSERT ... ON CONFLICT) to update or insert progress
        cur.execute("""
            INSERT INTO user_reading_progress
                (user_id, book_id, current_position_seconds, completion_percentage, is_completed, last_accessed, updated_at)
            VALUES (%s, %s, %s, %s, %s, NOW(), NOW())
            ON CONFLICT (user_id, book_id)
            DO UPDATE SET
                current_position_seconds = EXCLUDED.current_position_seconds,
                completion_percentage = EXCLUDED.completion_percentage,
                is_completed = EXCLUDED.is_completed,
                last_accessed = NOW(),
                updated_at = NOW()
        """, (user_id, book_id, int(position), completion_pct, is_completed))

        conn.commit()
        conn.close()
        logger.info(f"Saved reading progress for user {user_id}, book {book_id}, position {position}, completion {completion_pct:.1f}%")
        return True

    except Exception as e:
        logger.error(f"Error saving reading progress: {e}")
        if conn:
            conn.rollback()
            conn.close()
        return False

def get_user_reading_progress(user_id: str, book_id: str) -> Optional[Dict[str, Any]]:
    """Get user's reading progress for a specific book"""
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute("""
            SELECT user_id, book_id, current_position_seconds, total_listening_time,
                   completion_percentage, last_accessed, is_completed, updated_at
            FROM user_reading_progress
            WHERE user_id = %s AND book_id = %s
        """, (user_id, book_id))

        progress = cur.fetchone()
        conn.close()

        if progress:
            return dict(progress)
        return None

    except Exception as e:
        logger.error(f"Error getting reading progress: {e}")
        if conn:
            conn.close()
        return None

def get_all_user_reading_progress(user_id: str) -> List[Dict[str, Any]]:
    """Get all reading progress records for a user"""
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute("""
            SELECT user_id, book_id, current_position_seconds, total_listening_time,
                   completion_percentage, last_accessed, is_completed, updated_at
            FROM user_reading_progress
            WHERE user_id = %s
        """, (user_id,))

        rows = cur.fetchall()
        conn.close()

        return [dict(row) for row in rows]

    except Exception as e:
        logger.error(f"Error getting all reading progress: {e}")
        if conn:
            conn.close()
        return []

def save_user_bookmark(user_id: str, book_id: str, position: float, note: Optional[str] = None) -> Optional[str]:
    """Save a bookmark for a user and return the bookmark ID"""
    try:
        import uuid
        
        conn = get_db_connection()
        cur = conn.cursor()
        
        bookmark_id = str(uuid.uuid4())
        
        cur.execute("""
            INSERT INTO user_bookmarks (id, user_id, book_id, position_seconds, notes, created_at)
            VALUES (%s, %s, %s, %s, %s, NOW())
        """, (bookmark_id, user_id, book_id, position, note))
        
        conn.commit()
        conn.close()
        logger.info(f"Saved bookmark for user {user_id}, book {book_id}, position {position}")
        return bookmark_id
        
    except Exception as e:
        logger.error(f"Error saving bookmark: {e}")
        if conn:
            conn.rollback()
            conn.close()
        return None

def get_user_bookmarks(user_id: str, book_id: str) -> List[Dict[str, Any]]:
    """Get all bookmarks for a user's book"""
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        
        cur.execute("""
            SELECT id, user_id, book_id, position_seconds, notes, created_at
            FROM user_bookmarks
            WHERE user_id = %s AND book_id = %s
            ORDER BY created_at DESC
        """, (user_id, book_id))
        
        bookmarks = cur.fetchall()
        conn.close()
        
        return [dict(bookmark) for bookmark in bookmarks]
        
    except Exception as e:
        logger.error(f"Error getting bookmarks: {e}")
        if conn:
            conn.close()
        return []