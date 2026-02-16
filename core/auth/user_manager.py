import logging
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict, Optional
from uuid import UUID, uuid4

from ..database.database_manager import DatabaseManager
from .auth import UserRole

logger = logging.getLogger(__name__)


class UserManager:
    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager

    async def create_user_from_oauth(
        self,
        email: str,
        display_name: str,
        provider: str,
        provider_id: str,
        avatar_url: str = None
    ) -> Dict[str, Any]:
        try:
            async with self.db.transaction():
                existing_user = await self.get_user_by_email(email)
                if existing_user:
                    return await self._link_oauth_to_existing_user(
                        existing_user['id'], provider, provider_id, avatar_url
                    )

                user_id = uuid4()
                username = email.split('@')[0] if email else f"{provider}user{int(datetime.now().timestamp())}"

                user_query = """
                    INSERT INTO users (id, email, display_name, avatar_url)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id, email, display_name, avatar_url, created_at
                """

                user_result = await self.db.execute_query(user_query, (
                    str(user_id), email, display_name, avatar_url
                ), fetch_one=True)

                identity_query = """
                    INSERT INTO identities (user_id, provider, provider_id, provider_email, is_verified)
                    VALUES (%s, %s, %s, %s, %s)
                """

                await self.db.execute_query(identity_query, (
                    str(user_id), provider, provider_id, email, True
                ), fetch_all=False)

                preferences_query = """
                    INSERT INTO user_preferences (user_id)
                    VALUES (%s)
                """

                await self.db.execute_query(preferences_query, (str(user_id),), fetch_all=False)

                logger.info(f"Created new user {user_id} via {provider} OAuth")

                return {
                    'id': str(user_id),
                    'email': email,
                    'display_name': display_name,
                    'username': username,
                    'avatar_url': avatar_url,
                    'role': 'user',
                    'email_verified': True,
                    'is_active': True,
                    'created_at': user_result['created_at'].isoformat(),
                    'oauth_provider': provider,
                    'oauth_provider_id': provider_id
                }

        except Exception as e:
            logger.error(f"Failed to create OAuth user: {e}")
            raise

    async def create_user_from_email(
        self,
        email: str,
        username: str,
        hashed_password: str,
        role: UserRole = UserRole.USER
    ) -> Dict[str, Any]:
        try:
            async with self.db.transaction():
                existing = await self._check_existing_user(email, username)
                if existing:
                    raise ValueError(f"User already exists: {existing}")

                user_id = uuid4()

                user_query = """
                    INSERT INTO users (id, email, display_name)
                    VALUES (%s, %s, %s)
                    RETURNING id, email, display_name, created_at
                """

                user_result = await self.db.execute_query(user_query, (
                    str(user_id), email, username
                ), fetch_one=True)

                identity_query = """
                    INSERT INTO identities (user_id, provider, provider_id, provider_email, is_verified)
                    VALUES (%s, %s, %s, %s, %s)
                """

                await self.db.execute_query(identity_query, (
                    str(user_id), 'email', email, email, True
                ), fetch_all=False)

                password_query = """
                    INSERT INTO password_credentials (user_id, password_hash, salt)
                    VALUES (%s, %s, %s)
                """

                await self.db.execute_query(password_query, (
                    str(user_id), hashed_password, 'bcrypt'
                ), fetch_all=False)

                preferences_query = """
                    INSERT INTO user_preferences (user_id)
                    VALUES (%s)
                """

                await self.db.execute_query(preferences_query, (str(user_id),), fetch_all=False)

                logger.info(f"Created new email user {user_id}")

                return {
                    'id': str(user_id),
                    'email': email,
                    'display_name': username,
                    'username': username,
                    'role': role.value,
                    'email_verified': True,
                    'is_active': True,
                    'created_at': user_result['created_at'].isoformat()
                }

        except Exception as e:
            logger.error(f"Failed to create email user: {e}")
            raise

    async def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        try:
            query = """
                SELECT
                    u.id, u.email, u.display_name, u.avatar_url, u.created_at, u.updated_at,
                    i.provider, i.provider_user_id, i.verified as provider_verified,
                    uc.credits_available, uc.credits_used, uc.monthly_credits,
                    COUNT(up.book_id) as books_owned
                FROM users u
                LEFT JOIN identities i ON u.id = i.user_id
                LEFT JOIN user_credits uc ON u.id = uc.user_id
                LEFT JOIN user_purchases up ON u.id = up.user_id
                WHERE u.id = %s AND u.deleted_at IS NULL
                GROUP BY u.id, i.provider, i.provider_user_id, i.verified,
                         uc.credits_available, uc.credits_used, uc.monthly_credits
            """

            result = await self.db.execute_query(query, (user_id,), fetch_one=True)

            if not result:
                return None

            return {
                'id': result['id'],
                'email': result['email'],
                'display_name': result['display_name'],
                'username': result['display_name'],
                'avatar_url': result['avatar_url'],
                'role': 'user',
                'email_verified': result.get('provider_verified', True),
                'is_active': True,
                'created_at': result['created_at'].isoformat() if result['created_at'] else None,
                'oauth_provider': result.get('provider'),
                'oauth_provider_id': result.get('provider_user_id'),
                'credits_available': result.get('credits_available', 0),
                'credits_used': result.get('credits_used', 0),
                'monthly_credits': result.get('monthly_credits', 0),
                'books_owned': result.get('books_owned', 0)
            }

        except Exception as e:
            logger.error(f"Failed to get user by ID {user_id}: {e}")
            raise

    async def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        try:
            query = """
                SELECT u.id FROM users u
                WHERE u.email = %s AND u.deleted_at IS NULL
                LIMIT 1
            """

            result = await self.db.execute_query(query, [email])

            if result:
                return await self.get_user_by_id(result['id'])

            return None

        except Exception as e:
            logger.error(f"Failed to get user by email {email}: {e}")
            raise

    async def authenticate_user(self, email: str, password: str) -> Optional[Dict[str, Any]]:
        try:
            query = """
                SELECT u.*, pc.password_hash
                FROM users u
                JOIN password_credentials pc ON u.id = pc.user_id
                WHERE u.email = %s AND u.deleted_at IS NULL
            """

            result = await self.db.execute_query(query, (email,), fetch_one=True)

            if not result:
                return None

            import bcrypt

            password_bytes = password.encode('utf-8')
            if isinstance(result['password_hash'], str):
                hash_bytes = result['password_hash'].encode('utf-8')
            else:
                hash_bytes = result['password_hash']

            if not bcrypt.checkpw(password_bytes, hash_bytes):
                return None

            await self._log_user_activity(
                result['id'],
                'sign_in',
                {'method': 'email', 'email': email}
            )

            return {
                'id': str(result['id']),
                'email': result['email'],
                'username': result.get('username') or result['email'],
                'display_name': result.get('display_name') or result['email'],
                'role': result.get('role', 'user'),
                'is_active': result['is_active'],
                'email_verified': result.get('email_verified', False),
                'created_at': result['created_at'].isoformat() if result['created_at'] else None
            }

        except Exception as e:
            logger.error(f"Failed to authenticate user {email}: {e}")
            raise

    async def get_user_credit_balance(self, user_id: str) -> Dict[str, Any]:
        try:
            query = """
                SELECT
                    credits_available,
                    credits_used,
                    credits_gifted,
                    credits_received,
                    monthly_credits,
                    next_credit_date,
                    credits_purchased,
                    total_spent,
                    updated_at
                FROM user_credits
                WHERE user_id = %s
            """

            result = await self.db.execute_query(query, (user_id,), fetch_one=True)

            if result:
                return {
                    'total_credits': result['credits_available'] + result['credits_used'],
                    'used_credits': result['credits_used'],
                    'available_credits': result['credits_available'],
                    'credits_gifted': result['credits_gifted'],
                    'credits_received': result['credits_received'],
                    'monthly_credits': result['monthly_credits'],
                    'next_credit_date': result['next_credit_date'].isoformat() if result['next_credit_date'] else None,
                    'credits_purchased': result['credits_purchased'],
                    'total_spent': float(result['total_spent']),
                    'last_updated': result['updated_at'].isoformat()
                }

            await self._initialize_user_credits(UUID(user_id))
            return {
                'total_credits': 0,
                'used_credits': 0,
                'available_credits': 0,
                'credits_gifted': 0,
                'credits_received': 0,
                'monthly_credits': 0,
                'next_credit_date': None,
                'credits_purchased': 0,
                'total_spent': 0.0,
                'last_updated': datetime.now(timezone.utc).isoformat()
            }

        except Exception as e:
            logger.error(f"Failed to get credit balance for user {user_id}: {e}")
            raise

    async def get_user_library(self, user_id: str, limit: int = 100, offset: int = 0) -> Dict[str, Any]:
        try:
            query = """
                SELECT
                    up.book_id,
                    up.purchase_date,
                    up.purchase_type,
                    up.credits_used,
                    b.title,
                    b.author,
                    b.narrator,
                    b.description,
                    b.cover_image_url,
                    b.duration_minutes,
                    ul.last_position_seconds,
                    ul.completed,
                    ul.last_played_at
                FROM user_purchases up
                LEFT JOIN books b ON up.book_id = b.id
                LEFT JOIN user_library ul ON up.user_id = ul.user_id AND up.book_id = ul.book_id
                WHERE up.user_id = %s
                ORDER BY up.purchase_date DESC
                LIMIT %s OFFSET %s
            """

            books = await self.db.fetch_all(query, [user_id, limit, offset])

            count_query = """
                SELECT COUNT(*) as total
                FROM user_purchases
                WHERE user_id = %s
            """

            count_result = await self.db.execute_query(count_query, [user_id])

            book_list = [
                {
                    'id': book['book_id'],
                    'title': book['title'],
                    'author': book['author'],
                    'narrator': book['narrator'],
                    'description': book['description'],
                    'cover_image_url': book['cover_image_url'],
                    'duration_minutes': book['duration_minutes'],
                    'purchase_date': book['purchase_date'].isoformat(),
                    'purchase_type': book['purchase_type'],
                    'credits_used': book['credits_used'],
                    'last_position_seconds': book['last_position_seconds'] or 0,
                    'completed': book['completed'] or False,
                    'last_played_at': book['last_played_at'].isoformat() if book['last_played_at'] else None
                }
                for book in books
            ]

            return {
                'books': book_list,
                'total_count': count_result['total'],
                'has_more': (offset + len(book_list)) < count_result['total']
            }

        except Exception as e:
            logger.error(f"Failed to get user library for {user_id}: {e}")
            raise

    async def purchase_book_for_user(
        self,
        user_id: str,
        book_id: str,
        purchase_type: str = 'credit'
    ) -> Dict[str, Any]:
        try:
            async with self.db.transaction():
                existing_query = """
                    SELECT id FROM user_purchases
                    WHERE user_id = %s AND book_id = %s
                """

                existing = await self.db.execute_query(existing_query, [user_id, book_id])
                if existing:
                    raise ValueError("User already owns this book")

                book_query = "SELECT title FROM books WHERE id = %s"
                book = await self.db.execute_query(book_query, [book_id])
                if not book:
                    raise ValueError("Book not found")

                purchase_query = """
                    INSERT INTO user_purchases (user_id, book_id, purchase_type, credits_used, price_paid)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id, purchase_date
                """

                purchase = await self.db.execute_query(purchase_query, (
                    user_id, book_id, purchase_type, 0, Decimal('0.00')
                ), fetch_one=True)

                library_query = """
                    INSERT INTO user_library (user_id, book_id, access_type)
                    VALUES (%s, %s, %s)
                """

                await self.db.execute_query(library_query, (user_id, book_id, purchase_type), fetch_all=False)

                await self._log_user_activity(
                    UUID(user_id),
                    'book_purchase',
                    {
                        'book_id': book_id,
                        'book_title': book['title'],
                        'purchase_type': purchase_type,
                        'credits_used': 0
                    }
                )

                logger.info(f"User {user_id} purchased book {book_id}")

                return {
                    'success': True,
                    'purchase_id': purchase['id'],
                    'book_id': book_id,
                    'book_title': book['title'],
                    'credits_used': 0,
                    'purchase_date': purchase['purchase_date'].isoformat(),
                    'message': 'Book added to your library!'
                }

        except Exception as e:
            logger.error(f"Failed to purchase book {book_id} for user {user_id}: {e}")
            raise

    async def check_user_owns_book(self, user_id: str, book_id: str) -> bool:
        try:
            query = """
                SELECT 1 FROM user_purchases
                WHERE user_id = %s AND book_id = %s
                LIMIT 1
            """

            result = await self.db.execute_query(query, [user_id, book_id])
            return result is not None

        except Exception as e:
            logger.error(f"Failed to check book ownership: {e}")
            return False

    async def list_all_users(
        self,
        limit: int = 50,
        offset: int = 0,
        search: str = None,
        active_only: bool = True
    ) -> Dict[str, Any]:
        try:
            where_conditions = ["u.deleted_at IS NULL"] if active_only else []
            params = []
            param_count = 0

            if search:
                param_count += 1
                where_conditions.append(f"(u.email ILIKE ${param_count} OR u.display_name ILIKE ${param_count})")
                params.append(f"%{search}%")

            where_clause = "WHERE " + " AND ".join(where_conditions) if where_conditions else ""

            query = f"""
                SELECT
                    u.id, u.email, u.display_name, u.avatar_url, u.created_at,
                    COUNT(up.book_id) as books_owned,
                    uc.credits_available, uc.credits_used,
                    MAX(ul.last_played_at) as last_activity
                FROM users u
                LEFT JOIN user_purchases up ON u.id = up.user_id
                LEFT JOIN user_credits uc ON u.id = uc.user_id
                LEFT JOIN user_library ul ON u.id = ul.user_id
                {where_clause}
                GROUP BY u.id, uc.credits_available, uc.credits_used
                ORDER BY u.created_at DESC
                LIMIT ${param_count + 1} OFFSET ${param_count + 2}
            """

            params.extend([limit, offset])

            users = await self.db.fetch_all(query, params)

            count_params = params[:-2]
            count_query = f"""
                SELECT COUNT(*) as total
                FROM users u
                {where_clause}
            """

            count_result = await self.db.execute_query(count_query, count_params)

            user_list = [
                {
                    'id': user['id'],
                    'email': user['email'],
                    'display_name': user['display_name'],
                    'avatar_url': user['avatar_url'],
                    'created_at': user['created_at'].isoformat(),
                    'books_owned': user['books_owned'],
                    'credits_available': user['credits_available'] or 0,
                    'credits_used': user['credits_used'] or 0,
                    'last_activity': user['last_activity'].isoformat() if user['last_activity'] else None
                }
                for user in users
            ]

            return {
                'users': user_list,
                'total_count': count_result['total'],
                'has_more': (offset + len(user_list)) < count_result['total'],
                'page_info': {
                    'limit': limit,
                    'offset': offset,
                    'search': search
                }
            }

        except Exception as e:
            logger.error(f"Failed to list users: {e}")
            raise

    async def _initialize_user_credits(self, user_id: UUID):
        try:
            query = """
                INSERT INTO user_credits (id, user_id, credits_available, credits_used, monthly_credits)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (user_id) DO NOTHING
            """

            await self.db.execute_query(query, [
                str(uuid4()), str(user_id), 5, 0, 0
            ])

        except Exception as e:
            logger.error(f"Failed to initialize credits for user {user_id}: {e}")
            raise

    async def _check_existing_user(self, email: str, username: str) -> Optional[str]:
        try:
            query = """
                SELECT 'email' as type FROM users WHERE email = %s AND deleted_at IS NULL
                UNION
                SELECT 'username' as type FROM users WHERE display_name = %s AND deleted_at IS NULL
                LIMIT 1
            """

            result = await self.db.execute_query(query, (email, username), fetch_one=True)
            return result['type'] if result else None

        except Exception as e:
            logger.error(f"Failed to check existing user: {e}")
            return None

    async def _link_oauth_to_existing_user(
        self,
        user_id: str,
        provider: str,
        provider_id: str,
        avatar_url: str = None
    ) -> Dict[str, Any]:
        try:
            if avatar_url:
                update_query = """
                    UPDATE users SET avatar_url = %s, updated_at = NOW()
                    WHERE id = %s
                """
                await self.db.execute_query(update_query, (avatar_url, user_id), fetch_all=False)

            identity_query = """
                INSERT INTO identities (user_id, provider, provider_id, is_verified)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id, provider)
                DO UPDATE SET
                    provider_id = %s,
                    is_verified = %s,
                    updated_at = NOW()
            """

            await self.db.execute_query(identity_query, (
                user_id, provider, provider_id, True, provider_id, True
            ), fetch_all=False)

            return await self.get_user_by_id(user_id)

        except Exception as e:
            logger.error(f"Failed to link OAuth to user {user_id}: {e}")
            raise

    async def _log_user_activity(self, user_id: UUID, activity_type: str, details: Dict[str, Any]):
        try:
            logger.info(f"User activity - {user_id}: {activity_type} - {details}")
        except Exception as e:
            logger.error(f"Failed to log user activity: {e}")
