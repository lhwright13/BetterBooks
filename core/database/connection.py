"""
Database Connection Management

Provides connection pooling and database session management for PostgreSQL.
Supports both synchronous and asynchronous operations.
"""

import os
import logging
from typing import Optional, Any
from contextlib import contextmanager
import psycopg2
from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)

class DatabaseConfig:
    """Database configuration management"""

    def __init__(self):
        # Environment-based database URL detection
        # Priority: DATABASE_URL env var > RDS endpoint > Docker > Local
        self.database_url = os.getenv('DATABASE_URL')

        if not self.database_url:
            # Check for AWS RDS configuration
            rds_host = os.getenv('RDS_HOSTNAME')
            rds_db = os.getenv('RDS_DB_NAME', 'betterbooks')
            rds_user = os.getenv('RDS_USERNAME', 'betterbooks')
            rds_password = os.getenv('RDS_PASSWORD')

            if rds_host and rds_password:
                # AWS RDS connection
                self.database_url = f"postgresql://{rds_user}:{rds_password}@{rds_host}:5432/{rds_db}"
            elif os.path.exists('/.dockerenv') or os.getenv('DOCKER_ENV'):
                # Docker environment
                self.database_url = 'postgresql://betterbooks:betterbooks@postgres_primary:5432/betterbooks'
            else:
                # Local development
                self.database_url = 'postgresql://betterbooks:testpassword123@localhost:5432/betterbooks'

        # Connection pool settings - higher defaults for production
        # RDS connections benefit from larger pools
        is_production = os.getenv('ENVIRONMENT', 'development') == 'production'
        default_min = '5' if is_production else '1'
        default_max = '25' if is_production else '10'

        self.min_connections = int(os.getenv('DB_MIN_CONNECTIONS', default_min))
        self.max_connections = int(os.getenv('DB_MAX_CONNECTIONS', default_max))
        self.connection_timeout = int(os.getenv('DB_CONNECTION_TIMEOUT', '30'))

        # SSL mode for RDS (required in production)
        self.ssl_mode = os.getenv('DB_SSL_MODE', 'prefer')  # prefer, require, verify-full

class DatabaseConnectionManager:
    """Manages PostgreSQL connections with connection pooling"""
    
    def __init__(self, config: Optional[DatabaseConfig] = None):
        self.config = config or DatabaseConfig()
        self._pool: Optional[psycopg2.pool.ThreadedConnectionPool] = None
        self._initialized = False
    
    def initialize_pool(self) -> None:
        """Initialize the connection pool"""
        if self._initialized:
            return

        try:
            # Build connection string with SSL if configured
            dsn = self.config.database_url
            ssl_mode = getattr(self.config, 'ssl_mode', 'prefer')

            # Add sslmode to connection if not already in URL
            if 'sslmode=' not in dsn:
                separator = '&' if '?' in dsn else '?'
                dsn = f"{dsn}{separator}sslmode={ssl_mode}"

            self._pool = psycopg2.pool.ThreadedConnectionPool(
                self.config.min_connections,
                self.config.max_connections,
                dsn,
                cursor_factory=RealDictCursor
            )
            self._initialized = True
            logger.info(
                f"Database connection pool initialized "
                f"(min={self.config.min_connections}, max={self.config.max_connections}, ssl={ssl_mode})"
            )
        except Exception as e:
            logger.error(f"Failed to initialize database pool: {e}")
            raise
    
    def close_pool(self) -> None:
        """Close all connections in the pool"""
        if self._pool:
            self._pool.closeall()
            self._initialized = False
            logger.info("Database connection pool closed")
    
    @contextmanager
    def get_connection(self):
        """Get a database connection from the pool"""
        if not self._initialized:
            self.initialize_pool()
        
        connection = None
        try:
            connection = self._pool.getconn()
            if connection:
                yield connection
        except Exception as e:
            if connection:
                connection.rollback()
            logger.error(f"Database connection error: {e}")
            raise
        finally:
            if connection:
                self._pool.putconn(connection)
    
    @contextmanager
    def get_cursor(self, commit: bool = False):
        """Get a database cursor with automatic transaction management"""
        with self.get_connection() as connection:
            cursor = None
            try:
                cursor = connection.cursor()
                yield cursor
                if commit:
                    connection.commit()
            except Exception as e:
                connection.rollback()
                logger.error(f"Database cursor error: {e}")
                raise
            finally:
                if cursor:
                    cursor.close()
    
    def execute_query(self, query: str, params: Optional[tuple] = None, fetch_one: bool = False, fetch_all: bool = False) -> Optional[Any]:
        """Execute a query and return results"""
        with self.get_cursor(commit=True) as cursor:
            cursor.execute(query, params)
            
            if fetch_one:
                return cursor.fetchone()
            elif fetch_all:
                return cursor.fetchall()
            else:
                return cursor.rowcount
    
    def execute_many(self, query: str, params_list: list) -> int:
        """Execute a query multiple times with different parameters"""
        with self.get_cursor(commit=True) as cursor:
            cursor.executemany(query, params_list)
            return cursor.rowcount
    
    def test_connection(self) -> bool:
        """Test database connectivity"""
        try:
            with self.get_cursor() as cursor:
                cursor.execute("SELECT 1 as test")
                result = cursor.fetchone()
                return result['test'] == 1
        except Exception as e:
            logger.error(f"Database connection test failed: {e}")
            return False

# Global database manager instance
_db_manager: Optional[DatabaseConnectionManager] = None

def get_database_manager() -> DatabaseConnectionManager:
    """Get the global database manager instance"""
    global _db_manager
    if _db_manager is None:
        _db_manager = DatabaseConnectionManager()
    return _db_manager

def initialize_database():
    """Initialize the database connection pool"""
    manager = get_database_manager()
    manager.initialize_pool()

def close_database():
    """Close the database connection pool"""
    global _db_manager
    if _db_manager:
        _db_manager.close_pool()
        _db_manager = None

# Convenience functions for direct database access
def execute_query(query: str, params: Optional[tuple] = None, fetch_one: bool = False, fetch_all: bool = False) -> Optional[Any]:
    """Execute a query using the global database manager"""
    return get_database_manager().execute_query(query, params, fetch_one, fetch_all)

def execute_many(query: str, params_list: list) -> int:
    """Execute multiple queries using the global database manager"""
    return get_database_manager().execute_many(query, params_list)

def test_database_connection() -> bool:
    """Test database connectivity using the global database manager"""
    return get_database_manager().test_connection()