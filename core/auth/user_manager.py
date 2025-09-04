"""
User Management System for EchoWright

Production-ready user management with PostgreSQL integration.
Handles user accounts, credits, library ownership, and activity tracking.
"""

import logging
import asyncio
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from uuid import UUID, uuid4
from decimal import Decimal

from ..database.database_manager import DatabaseManager
from .auth import User, UserRole

logger = logging.getLogger(__name__)


class UserManager:
    """
    Comprehensive user management system for production use.
    
    Handles:
    - User account CRUD operations
    - Credit system integration
    - Book library ownership
    - User activity tracking
    - Admin tools for user inspection
    """
    
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
        """
        Create new user account from OAuth authentication
        
        Args:
            email: User's email address
            display_name: User's display name
            provider: OAuth provider (google, apple)
            provider_id: Provider's user ID
            avatar_url: Profile picture URL
            
        Returns:
            Complete user data with credits initialized
        """
        try:
            async with self.db.transaction():
                # Check if user already exists by email
                existing_user = await self.get_user_by_email(email)
                if existing_user:
                    # Update existing user with OAuth info
                    return await self._link_oauth_to_existing_user(
                        existing_user['id'], provider, provider_id, avatar_url
                    )
                
                # Create new user
                user_id = uuid4()
                username = email.split('@')[0] if email else f"{provider}user{int(datetime.now().timestamp())}"
                
                # Insert user
                user_query = """
                    INSERT INTO users (id, email, display_name, avatar_url)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id, email, display_name, avatar_url, created_at
                """
                
                user_result = await self.db.execute_query(user_query, (
                    str(user_id), email, display_name, avatar_url
                ), fetch_one=True)
                
                # Create identity record
                identity_query = """
                    INSERT INTO identities (user_id, provider, provider_id, provider_email, is_verified)
                    VALUES (%s, %s, %s, %s, %s)
                """
                
                await self.db.execute_query(identity_query, (
                    str(user_id), provider, provider_id, email, True
                ), fetch_all=False)
                
                # Initialize user preferences
                preferences_query = """
                    INSERT INTO user_preferences (user_id)
                    VALUES (%s)
                """
                
                await self.db.execute_query(preferences_query, (str(user_id),), fetch_all=False)
                
                # Initialize credits (starting with 0 as per requirement) - TODO: Implement when user_credits table is created
                # await self._initialize_user_credits(user_id)
                
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
        """
        Create new user account from email/password registration
        
        Args:
            email: User's email address
            username: User's chosen username
            hashed_password: Bcrypt hashed password
            role: User role (default: USER)
            
        Returns:
            Complete user data
        """
        try:
            async with self.db.transaction():
                # Check if email or username already exists
                existing = await self._check_existing_user(email, username)
                if existing:
                    raise ValueError(f"User already exists: {existing}")
                
                # Create user
                user_id = uuid4()
                
                user_query = """
                    INSERT INTO users (id, email, display_name)
                    VALUES (%s, %s, %s)
                    RETURNING id, email, display_name, created_at
                """
                
                user_result = await self.db.execute_query(user_query, (
                    str(user_id), email, username
                ), fetch_one=True)
                
                # Create email identity
                identity_query = """
                    INSERT INTO identities (user_id, provider, provider_id, provider_email, is_verified)
                    VALUES (%s, %s, %s, %s, %s)
                """
                
                await self.db.execute_query(identity_query, (
                    str(user_id), 'email', email, email, True
                ), fetch_all=False)
                
                # Store password credentials
                password_query = """
                    INSERT INTO password_credentials (user_id, password_hash, salt)
                    VALUES (%s, %s, %s)
                """
                
                # For bcrypt, salt is included in hash, so we store a placeholder
                await self.db.execute_query(password_query, (
                    str(user_id), hashed_password, 'bcrypt'
                ), fetch_all=False)
                
                # Initialize preferences
                preferences_query = """
                    INSERT INTO user_preferences (user_id)
                    VALUES (%s)
                """
                
                await self.db.execute_query(preferences_query, (str(user_id),), fetch_all=False)
                
                # Initialize credits - TODO: Implement when user_credits table is created
                # await self._initialize_user_credits(user_id)
                
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
        """Get complete user information by ID"""
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
            
            if result:
                return {
                    'id': result['id'],
                    'email': result['email'],
                    'display_name': result['display_name'],
                    'username': result['display_name'],  # Using display_name as username
                    'avatar_url': result['avatar_url'],
                    'role': 'user',  # Default role
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
            
            return None
            
        except Exception as e:
            logger.error(f"Failed to get user by ID {user_id}: {e}")
            raise
    
    async def get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Get user by email address"""
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
        """
        Authenticate user with email and password
        """
        try:
            # Get user and password credentials
            query = """
                SELECT u.*, pc.password_hash
                FROM users u
                JOIN password_credentials pc ON u.id = pc.user_id  
                WHERE u.email = %s AND u.deleted_at IS NULL
            """
            
            result = await self.db.execute_query(query, (email,), fetch_one=True)
            
            if not result:
                return None
                
            # Verify password using bcrypt
            import bcrypt
            
            # Handle password_hash encoding - it might already be bytes or string
            password_bytes = password.encode('utf-8')
            if isinstance(result['password_hash'], str):
                hash_bytes = result['password_hash'].encode('utf-8')
            else:
                hash_bytes = result['password_hash']
                
            if bcrypt.checkpw(password_bytes, hash_bytes):
                # Password is correct, log the sign-in
                await self._log_user_activity(
                    result['id'], 
                    'sign_in', 
                    {'method': 'email', 'email': email}
                )
                
                # Return user data (without password_hash)
                user_data = {
                    'id': str(result['id']),  # Convert UUID to string
                    'email': result['email'], 
                    'username': result.get('username') or result['email'],  # Use email as fallback for username
                    'display_name': result.get('display_name') or result['email'],  # Use email as fallback for display_name
                    'role': result.get('role', 'user'),
                    'is_active': result['is_active'],
                    'email_verified': result.get('email_verified', False),
                    'created_at': result['created_at'].isoformat() if result['created_at'] else None  # Convert datetime to ISO string
                }
                return user_data
            
            return None
            
        except Exception as e:
            logger.error(f"Failed to authenticate user {email}: {e}")
            raise
    
    async def get_user_credit_balance(self, user_id: str) -> Dict[str, Any]:
        """Get user's complete credit information"""
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
            else:
                # Initialize credits if not found
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
        """Get user's owned books"""
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
            
            # Get total count
            count_query = """
                SELECT COUNT(*) as total
                FROM user_purchases
                WHERE user_id = %s
            """
            
            count_result = await self.db.execute_query(count_query, [user_id])
            
            book_list = []
            for book in books:
                book_list.append({
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
                })
            
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
        """
        Purchase a book for a user (0 credits as per requirement)
        
        Args:
            user_id: User making the purchase
            book_id: Book being purchased
            purchase_type: Type of purchase (credit, gift, etc.)
            
        Returns:
            Purchase result
        """
        try:
            async with self.db.transaction():
                # Check if user already owns the book
                existing_query = """
                    SELECT id FROM user_purchases
                    WHERE user_id = %s AND book_id = %s
                """
                
                existing = await self.db.execute_query(existing_query, [user_id, book_id])
                if existing:
                    raise ValueError("User already owns this book")
                
                # Check if book exists
                book_query = "SELECT title FROM books WHERE id = %s"
                book = await self.db.execute_query(book_query, [book_id])
                if not book:
                    raise ValueError("Book not found")
                
                # Create purchase record (0 credits used)
                purchase_query = """
                    INSERT INTO user_purchases (user_id, book_id, purchase_type, credits_used, price_paid)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id, purchase_date
                """
                
                purchase = await self.db.execute_query(purchase_query, (
                    user_id, book_id, purchase_type, 0, Decimal('0.00')
                ), fetch_one=True)
                
                # Create library entry for progress tracking
                library_query = """
                    INSERT INTO user_library (user_id, book_id, access_type)
                    VALUES (%s, %s, %s)
                """
                
                await self.db.execute_query(library_query, (user_id, book_id, purchase_type), fetch_all=False)
                
                # Log the activity
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
        """Check if user owns a specific book"""
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
        """
        Admin function: List all users with pagination and search
        
        Args:
            limit: Number of users to return
            offset: Pagination offset
            search: Search by email or display name
            active_only: Only return active users
            
        Returns:
            User list with pagination info
        """
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
            
            # Get total count
            count_params = params[:-2]  # Remove limit and offset
            count_query = f"""
                SELECT COUNT(*) as total
                FROM users u
                {where_clause}
            """
            
            count_result = await self.db.execute_query(count_query, count_params)
            
            user_list = []
            for user in users:
                user_list.append({
                    'id': user['id'],
                    'email': user['email'],
                    'display_name': user['display_name'],
                    'avatar_url': user['avatar_url'],
                    'created_at': user['created_at'].isoformat(),
                    'books_owned': user['books_owned'],
                    'credits_available': user['credits_available'] or 0,
                    'credits_used': user['credits_used'] or 0,
                    'last_activity': user['last_activity'].isoformat() if user['last_activity'] else None
                })
            
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
        """Initialize credit record for new user (starts with 5 credits)"""
        try:
            query = """
                INSERT INTO user_credits (id, user_id, credits_available, credits_used, monthly_credits)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (user_id) DO NOTHING
            """
            
            await self.db.execute_query(query, [
                str(uuid4()), str(user_id), 5, 0, 0  # Start with 5 credits for new users
            ])
            
        except Exception as e:
            logger.error(f"Failed to initialize credits for user {user_id}: {e}")
            raise
    
    async def _check_existing_user(self, email: str, username: str) -> Optional[str]:
        """Check if user with email or username already exists"""
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
        """Link OAuth provider to existing user account"""
        try:
            # Update user avatar if provided
            if avatar_url:
                update_query = """
                    UPDATE users SET avatar_url = %s, updated_at = NOW()
                    WHERE id = %s
                """
                await self.db.execute_query(update_query, (avatar_url, user_id), fetch_all=False)
            
            # Add or update identity
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
        """Log user activity for analytics and debugging"""
        try:
            # This could be implemented with a user_activity table or analytics system
            logger.info(f"User activity - {user_id}: {activity_type} - {details}")
            # For now, just log. In production, you might want to store this.
            
        except Exception as e:
            logger.error(f"Failed to log user activity: {e}")