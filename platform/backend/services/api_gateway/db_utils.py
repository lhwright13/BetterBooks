import os
import psycopg2
import psycopg2.extras
import logging
from typing import Dict, List, Any, Optional
from storage_helper import get_storage

logger = logging.getLogger(__name__)

storage = get_storage()

AUDIO_FILES = {
    "Alice's Adventures in Wonderland": "alices_adventures_01_carroll_64kb.mp3",
    "Moby Dick": "mobydick_001_002_melville_64kb.mp3",
    "The Great Gatsby": "gatsby_chapter_01.mp3",
    "War and Peace": "warandpeace_001_tolstoy_64kb.mp3"
}

BOOK_DURATIONS = {
    "Alice's Adventures in Wonderland": 4800,
    "Moby Dick": 86400,
    "The Great Gatsby": 18000,
    "War and Peace": 216000
}

FALLBACK_CATEGORIES = [
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
]


def get_db_connection():
    db_url = os.getenv('DATABASE_URL')

    if not db_url:
        if os.path.exists('/.dockerenv') or os.getenv('DOCKER_ENV'):
            db_url = "postgresql://betterbooks:testpassword123@postgres_primary:5432/betterbooks"
        else:
            db_url = "postgresql://betterbooks:testpassword123@localhost:5432/betterbooks"

    log_url = db_url.split('@')[1] if '@' in db_url else 'local'
    logger.info(f"Connecting to database: {log_url}")

    try:
        return psycopg2.connect(db_url, connect_timeout=10)
    except psycopg2.Error as e:
        logger.error(f"Database connection failed: {e}")
        if 'postgres_primary' in db_url:
            fallback_url = db_url.replace('postgres_primary', 'localhost')
            logger.info("Trying localhost fallback...")
            return psycopg2.connect(fallback_url, connect_timeout=10)
        raise


def get_user_by_id(user_id: str) -> Optional[Dict[str, Any]]:
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
        return {
            'total_credits': 5,
            'used_credits': 0,
            'available_credits': 5
        }
    except Exception as e:
        logger.error(f"Unexpected error getting user credits: {e}")
        return None


def get_user_library(user_id: str, limit: int = 50, offset: int = 0) -> Dict[str, Any]:
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
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

                for book in books:
                    book['sample_audio_url'] = _generate_sample_audio_url(book['title'])
                    book['duration_seconds'] = _get_book_duration_seconds(book['title'])

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
    except Exception as e:
        logger.error(f"Database error getting user library: {e}")
        return {'books': [], 'total_books': 0}


def _generate_sample_audio_url(book_title: str) -> str:
    filename = AUDIO_FILES.get(book_title, "")
    if filename:
        return f"/books/{book_title}/{filename}"
    return None


def _get_book_duration_seconds(book_title: str) -> int:
    return BOOK_DURATIONS.get(book_title, 3600)


def create_user(email: str, name: str = "") -> Optional[str]:
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    INSERT INTO users (email, full_name, created_at)
                    VALUES (%s, %s, NOW())
                    RETURNING id
                """, (email, name))

                user_id = cursor.fetchone()['id']

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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("BEGIN")

                cursor.execute("""
                    SELECT id FROM user_purchases
                    WHERE user_id = %s AND book_id = %s
                """, (user_id, book_id))

                if cursor.fetchone():
                    cursor.execute("ROLLBACK")
                    logger.warning(f"User {user_id} already owns book {book_id}")
                    return False

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

                cursor.execute("""
                    SELECT price_usd FROM books WHERE id = %s
                """, (book_id,))

                book_result = cursor.fetchone()
                if not book_result:
                    cursor.execute("ROLLBACK")
                    logger.error(f"Book {book_id} not found")
                    return False

                cursor.execute("""
                    INSERT INTO user_purchases (user_id, book_id, purchase_type, credits_used, price_paid)
                    VALUES (%s, %s, %s, %s, %s)
                """, (user_id, book_id, purchase_type, credits_used, book_result['price_usd']))

                cursor.execute("""
                    UPDATE user_credits
                    SET used_credits = used_credits + %s,
                        last_updated = NOW()
                    WHERE user_id = %s
                """, (credits_used, user_id))

                access_type = "purchase" if purchase_type == "credit" else purchase_type
                cursor.execute("""
                    INSERT INTO user_library (user_id, book_id, acquired_at, access_type)
                    VALUES (%s, %s, NOW(), %s)
                    ON CONFLICT (user_id, book_id) DO NOTHING
                """, (user_id, book_id, access_type))

                cursor.execute("COMMIT")
                logger.info(f"Successfully created purchase: user {user_id}, book {book_id}, credits {credits_used}")
                return True

    except Exception as e:
        logger.error(f"Error creating purchase: {e}")
        return False


def check_user_owns_book(user_id: str, book_id: str) -> bool:
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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                where_clause = "WHERE 1=1"
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
        return {'books': [], 'total_books': 0}


def test_database_connection() -> bool:
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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT
                        id, title, author, description, cover_image_url,
                        price_usd, credit_price, is_featured, is_bestseller, is_new_release
                    FROM books
                    WHERE id = %s
                """, (book_id,))

                book_data = cursor.fetchone()
                if not book_data:
                    return None

                result = dict(book_data)

                cursor.execute("""
                    SELECT
                        id, title, chapter_number,
                        duration_seconds as duration, file_path
                    FROM book_chapters
                    WHERE book_id = %s
                    ORDER BY chapter_number
                """, (book_id,))

                chapters = []
                for chapter in cursor.fetchall():
                    if not chapter['file_path']:
                        continue

                    file_path = chapter['file_path']

                    if file_path.startswith(('http://', 'https://')):
                        audio_url = file_path
                    else:
                        audio_url = None
                        if '/' in file_path:
                            book_folder, filename = file_path.split('/', 1)
                            cloud_url = storage.generate_audio_url(book_folder, filename)
                            if cloud_url:
                                audio_url = cloud_url

                        if not audio_url:
                            audio_url = f"/books/{file_path}"

                    chapters.append({
                        'id': str(chapter['id']),
                        'title': chapter['title'],
                        'audio_url': audio_url,
                        'chapter_number': chapter['chapter_number'],
                        'duration': chapter.get('duration'),
                        'file_path': file_path
                    })

                result['chapters'] = chapters

                total_duration = sum(ch.get('duration', 0) for ch in chapters if ch.get('duration'))
                result['total_duration'] = total_duration if total_duration > 0 else None

                return result

    except Exception as e:
        logger.error(f"Database error getting book details for {book_id}: {e}")
        return None


def get_book_personas(book_id: str) -> Optional[Dict[str, Any]]:
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("SELECT title FROM books WHERE id = %s", (book_id,))
                book = cursor.fetchone()
                if not book:
                    return None

                cursor.execute("""
                    SELECT
                        bp.id, bp.persona_id,
                        p.name as persona_name,
                        p.display_name as persona_display_name,
                        p.description as persona_description,
                        bp.is_default, bp.custom_prompt, bp.sort_order
                    FROM book_personas bp
                    JOIN personas p ON bp.persona_id = p.id
                    WHERE bp.book_id = %s
                    ORDER BY bp.sort_order ASC, p.display_name ASC
                """, (book_id,))

                return {
                    'book_id': book_id,
                    'book_title': book['title'],
                    'personas': cursor.fetchall()
                }

    except Exception as e:
        logger.error(f"Database error getting personas for book {book_id}: {e}")
        return None


def get_persona_details(persona_id: str) -> Optional[Dict[str, Any]]:
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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                search_pattern = f"%{query}%"

                cursor.execute("""
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
                """, (
                    search_pattern, search_pattern, search_pattern,
                    search_pattern, search_pattern,
                    limit, offset
                ))

                books = cursor.fetchall()

                cursor.execute("""
                    SELECT COUNT(*) as total
                    FROM books
                    WHERE (
                        title ILIKE %s OR
                        author ILIKE %s OR
                        description ILIKE %s
                    )
                """, (search_pattern, search_pattern, search_pattern))

                total_count = cursor.fetchone()['total']

                return {
                    'books': [dict(book) for book in books],
                    'total_books': total_count
                }

    except Exception as e:
        logger.error(f"Database error searching books with query '{query}': {e}")
        return {'books': [], 'total_books': 0}


def get_bestselling_books(limit: int = 10, offset: int = 0) -> Dict[str, Any]:
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT b.id, b.title, b.author, b.description, b.cover_image_url,
                           b.price_usd, b.credit_price, b.is_featured, b.is_bestseller, b.is_new_release
                    FROM books b
                    WHERE b.is_bestseller = TRUE
                    ORDER BY b.title
                    LIMIT %s OFFSET %s
                """, (limit, offset))

                bestsellers = cursor.fetchall()

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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT total_credits, used_credits, (total_credits - used_credits) as available_credits
                    FROM user_credits
                    WHERE user_id = %s
                """, (user_id,))

                if cursor.fetchone():
                    raise ValueError("User already has credits initialized")

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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("SELECT id, title FROM books WHERE id = %s", (book_id,))
                book = cursor.fetchone()
                if not book:
                    raise ValueError("Book not found")

                cursor.execute("""
                    SELECT id FROM user_wishlists
                    WHERE user_id = %s AND book_id = %s
                """, (user_id, book_id))

                if cursor.fetchone():
                    raise ValueError("Book already in wishlist")

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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT uw.id, b.title
                    FROM user_wishlists uw
                    JOIN books b ON uw.book_id = b.id
                    WHERE uw.user_id = %s AND uw.book_id = %s
                """, (user_id, book_id))

                wishlist_item = cursor.fetchone()
                if not wishlist_item:
                    raise ValueError("Book not found in wishlist")

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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT
                        uw.id as wishlist_id, uw.book_id, uw.added_at,
                        b.title, b.author, b.description, b.cover_image_url,
                        b.price_usd, b.credit_price, b.is_featured, b.is_bestseller, b.is_new_release
                    FROM user_wishlists uw
                    JOIN books b ON uw.book_id = b.id
                    WHERE uw.user_id = %s
                    ORDER BY uw.added_at DESC
                    LIMIT %s OFFSET %s
                """, (user_id, limit, offset))

                wishlist_items = cursor.fetchall()

                cursor.execute("""
                    SELECT COUNT(*) as total
                    FROM user_wishlists
                    WHERE user_id = %s
                """, (user_id,))

                total_count = cursor.fetchone()['total']

                books = []
                for item in wishlist_items:
                    book_data = dict(item)
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
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT
                        id, name, description, image_url,
                        display_order, is_active, created_at, updated_at
                    FROM book_categories
                    WHERE is_active = true
                    ORDER BY display_order ASC, name ASC
                """)

                categories = cursor.fetchall()

                formatted_categories = []
                for category in categories:
                    category_data = dict(category)
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
        return {
            'categories': FALLBACK_CATEGORIES,
            'total_count': len(FALLBACK_CATEGORIES)
        }


def save_user_reading_progress(user_id: str, book_id: str, position: float) -> bool:
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute("SELECT duration_minutes FROM books WHERE id = %s", (book_id,))
        book_row = cur.fetchone()
        duration_minutes = book_row[0] if book_row and book_row[0] else 0

        completion_pct = 0.0
        is_completed = False
        if duration_minutes > 0:
            duration_seconds = duration_minutes * 60
            completion_pct = min(100.0, (position / duration_seconds) * 100)
            is_completed = completion_pct >= 95.0

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
        logger.info(f"Saved reading progress for user {user_id}, book {book_id}, position {position}, completion {completion_pct:.1f}%")
        return True

    except Exception as e:
        logger.error(f"Error saving reading progress: {e}")
        if conn:
            conn.rollback()
        return False
    finally:
        if conn:
            conn.close()


def get_user_reading_progress(user_id: str, book_id: str) -> Optional[Dict[str, Any]]:
    conn = None
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
        if progress:
            return dict(progress)
        return None

    except Exception as e:
        logger.error(f"Error getting reading progress: {e}")
        return None
    finally:
        if conn:
            conn.close()


def get_all_user_reading_progress(user_id: str) -> List[Dict[str, Any]]:
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute("""
            SELECT user_id, book_id, current_position_seconds, total_listening_time,
                   completion_percentage, last_accessed, is_completed, updated_at
            FROM user_reading_progress
            WHERE user_id = %s
        """, (user_id,))

        return [dict(row) for row in cur.fetchall()]

    except Exception as e:
        logger.error(f"Error getting all reading progress: {e}")
        return []
    finally:
        if conn:
            conn.close()


def save_user_bookmark(user_id: str, book_id: str, position: float, note: Optional[str] = None) -> Optional[str]:
    import uuid

    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        bookmark_id = str(uuid.uuid4())

        cur.execute("""
            INSERT INTO user_bookmarks (id, user_id, book_id, position_seconds, notes, created_at)
            VALUES (%s, %s, %s, %s, %s, NOW())
        """, (bookmark_id, user_id, book_id, position, note))

        conn.commit()
        logger.info(f"Saved bookmark for user {user_id}, book {book_id}, position {position}")
        return bookmark_id

    except Exception as e:
        logger.error(f"Error saving bookmark: {e}")
        if conn:
            conn.rollback()
        return None
    finally:
        if conn:
            conn.close()


def get_user_bookmarks(user_id: str, book_id: str) -> List[Dict[str, Any]]:
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

        cur.execute("""
            SELECT id, user_id, book_id, position_seconds, notes, created_at
            FROM user_bookmarks
            WHERE user_id = %s AND book_id = %s
            ORDER BY created_at DESC
        """, (user_id, book_id))

        return [dict(bookmark) for bookmark in cur.fetchall()]

    except Exception as e:
        logger.error(f"Error getting bookmarks: {e}")
        return []
    finally:
        if conn:
            conn.close()
