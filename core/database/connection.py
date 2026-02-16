import os
import logging
from typing import Optional, Any
from contextlib import contextmanager
import psycopg2
from psycopg2.extras import RealDictCursor

logger = logging.getLogger(__name__)


class DatabaseConfig:

    def __init__(self):
        self.database_url = os.getenv('DATABASE_URL')

        if not self.database_url:
            rds_host = os.getenv('RDS_HOSTNAME')
            rds_db = os.getenv('RDS_DB_NAME', 'betterbooks')
            rds_user = os.getenv('RDS_USERNAME', 'betterbooks')
            rds_password = os.getenv('RDS_PASSWORD')

            if rds_host and rds_password:
                self.database_url = f"postgresql://{rds_user}:{rds_password}@{rds_host}:5432/{rds_db}"
            elif os.path.exists('/.dockerenv') or os.getenv('DOCKER_ENV'):
                self.database_url = 'postgresql://betterbooks:betterbooks@postgres_primary:5432/betterbooks'
            else:
                self.database_url = 'postgresql://betterbooks:testpassword123@localhost:5432/betterbooks'

        is_production = os.getenv('ENVIRONMENT', 'development') == 'production'
        default_min = '5' if is_production else '1'
        default_max = '25' if is_production else '10'

        self.min_connections = int(os.getenv('DB_MIN_CONNECTIONS', default_min))
        self.max_connections = int(os.getenv('DB_MAX_CONNECTIONS', default_max))
        self.connection_timeout = int(os.getenv('DB_CONNECTION_TIMEOUT', '30'))
        self.ssl_mode = os.getenv('DB_SSL_MODE', 'prefer')


class DatabaseConnectionManager:

    def __init__(self, config: Optional[DatabaseConfig] = None):
        self.config = config or DatabaseConfig()
        self._pool: Optional[psycopg2.pool.ThreadedConnectionPool] = None
        self._initialized = False

    def initialize_pool(self) -> None:
        if self._initialized:
            return

        try:
            dsn = self.config.database_url
            ssl_mode = self.config.ssl_mode

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
        if self._pool:
            self._pool.closeall()
            self._initialized = False
            logger.info("Database connection pool closed")

    @contextmanager
    def get_connection(self):
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
        with self.get_cursor(commit=True) as cursor:
            cursor.execute(query, params)

            if fetch_one:
                return cursor.fetchone()
            if fetch_all:
                return cursor.fetchall()
            return cursor.rowcount

    def execute_many(self, query: str, params_list: list) -> int:
        with self.get_cursor(commit=True) as cursor:
            cursor.executemany(query, params_list)
            return cursor.rowcount

    def test_connection(self) -> bool:
        try:
            with self.get_cursor() as cursor:
                cursor.execute("SELECT 1 as test")
                result = cursor.fetchone()
                return result['test'] == 1
        except Exception as e:
            logger.error(f"Database connection test failed: {e}")
            return False


_db_manager: Optional[DatabaseConnectionManager] = None


def get_database_manager() -> DatabaseConnectionManager:
    global _db_manager
    if _db_manager is None:
        _db_manager = DatabaseConnectionManager()
    return _db_manager


def initialize_database():
    manager = get_database_manager()
    manager.initialize_pool()


def close_database():
    global _db_manager
    if _db_manager:
        _db_manager.close_pool()
        _db_manager = None


def execute_query(query: str, params: Optional[tuple] = None, fetch_one: bool = False, fetch_all: bool = False) -> Optional[Any]:
    return get_database_manager().execute_query(query, params, fetch_one, fetch_all)


def execute_many(query: str, params_list: list) -> int:
    return get_database_manager().execute_many(query, params_list)


def test_database_connection() -> bool:
    return get_database_manager().test_connection()
