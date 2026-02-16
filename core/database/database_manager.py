import os
import time
import asyncio
import logging
from typing import Optional, Dict, Any, List
from contextlib import asynccontextmanager
import psycopg
from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool
import threading

logger = logging.getLogger(__name__)


class DatabaseConfig:

    def __init__(
        self,
        database_url: str = None,
        read_replica_url: str = None,
        min_connections: int = 5,
        max_connections: int = 20,
        connection_timeout: float = 30.0,
        command_timeout: float = 60.0,
        max_idle_time: float = 300.0,
        retry_attempts: int = 3,
        retry_delay: float = 1.0,
        enable_read_replica: bool = False,
    ):
        self.database_url = database_url or os.getenv(
            "DATABASE_URL",
            "postgresql://betterbooks:betterbooks@pgbouncer:6432/betterbooks"
        )
        self.read_replica_url = read_replica_url or os.getenv(
            "READ_REPLICA_URL",
            "postgresql://betterbooks:betterbooks@pgbouncer_replica:6432/betterbooks"
        )
        self.min_connections = min_connections
        self.max_connections = max_connections
        self.connection_timeout = connection_timeout
        self.command_timeout = command_timeout
        self.max_idle_time = max_idle_time
        self.retry_attempts = retry_attempts
        self.retry_delay = retry_delay
        self.enable_read_replica = enable_read_replica


class DatabaseMetrics:

    def __init__(self):
        self._lock = threading.Lock()
        self.reset_metrics()

    def reset_metrics(self):
        with self._lock:
            self.queries_executed = 0
            self.queries_failed = 0
            self.total_query_time = 0.0
            self.connections_created = 0
            self.connections_failed = 0
            self.pool_waits = 0
            self.slow_queries = 0
            self.last_error = None
            self.last_error_time = None

    def record_query(self, duration: float, success: bool = True):
        with self._lock:
            self.queries_executed += 1
            self.total_query_time += duration

            if not success:
                self.queries_failed += 1

            if duration > 1.0:
                self.slow_queries += 1

    def record_connection(self, success: bool = True):
        with self._lock:
            if success:
                self.connections_created += 1
            else:
                self.connections_failed += 1

    def record_pool_wait(self):
        with self._lock:
            self.pool_waits += 1

    def record_error(self, error: Exception):
        with self._lock:
            self.last_error = str(error)
            self.last_error_time = time.time()

    def get_metrics(self) -> Dict[str, Any]:
        with self._lock:
            avg_query_time = (
                self.total_query_time / max(self.queries_executed, 1)
            )

            return {
                "queries_executed": self.queries_executed,
                "queries_failed": self.queries_failed,
                "query_failure_rate": self.queries_failed / max(self.queries_executed, 1),
                "average_query_time": avg_query_time,
                "slow_queries": self.slow_queries,
                "connections_created": self.connections_created,
                "connections_failed": self.connections_failed,
                "pool_waits": self.pool_waits,
                "last_error": self.last_error,
                "last_error_time": self.last_error_time,
            }


class DatabaseManager:

    def __init__(self, config: DatabaseConfig = None):
        self.config = config or DatabaseConfig()
        self.primary_pool: Optional[AsyncConnectionPool] = None
        self.replica_pool: Optional[AsyncConnectionPool] = None
        self.metrics = DatabaseMetrics()
        self._health_cache = {}
        self._health_cache_timeout = 30
        self._lock = asyncio.Lock()

    async def initialize(self) -> bool:
        try:
            logger.info(
                f"Initializing database connection pools "
                f"(min={self.config.min_connections}, max={self.config.max_connections}, "
                f"replica={self.config.enable_read_replica})"
            )

            self.primary_pool = AsyncConnectionPool(
                self.config.database_url,
                min_size=self.config.min_connections,
                max_size=self.config.max_connections,
                timeout=self.config.connection_timeout,
                max_idle=self.config.max_idle_time,
                open=False,
            )
            await self.primary_pool.open()

            async with self.primary_pool.connection() as conn:
                await conn.execute("SELECT 1")

            logger.info("Primary database pool initialized successfully")

            if self.config.enable_read_replica:
                try:
                    self.replica_pool = AsyncConnectionPool(
                        self.config.read_replica_url,
                        min_size=max(1, self.config.min_connections // 2),
                        max_size=max(5, self.config.max_connections // 2),
                        timeout=self.config.connection_timeout,
                        max_idle=self.config.max_idle_time,
                        open=False,
                        configure=lambda conn: conn.__setattr__('row_factory', dict_row) or None
                    )
                    await self.replica_pool.open()

                    async with self.replica_pool.connection() as conn:
                        await conn.execute("SELECT 1")

                    logger.info("Read replica pool initialized successfully")

                except Exception as e:
                    logger.warning(f"Failed to initialize read replica pool: {e}")
                    logger.info("Continuing with primary-only configuration")
                    self.replica_pool = None
                    self.config.enable_read_replica = False

            self.metrics.record_connection(success=True)
            logger.info("Database connection pools initialized successfully")
            return True

        except Exception as e:
            self.metrics.record_error(e)
            self.metrics.record_connection(success=False)
            logger.error(f"Failed to initialize database pools: {e}")
            return False

    async def close(self):
        if self.primary_pool:
            await self.primary_pool.close()
            logger.info("Primary database pool closed")

        if self.replica_pool:
            await self.replica_pool.close()
            logger.info("Read replica pool closed")

    @asynccontextmanager
    async def get_connection(self, prefer_replica: bool = None):
        if not self.primary_pool:
            raise RuntimeError("Database pools not initialized")

        use_replica = (
            prefer_replica
            and self.config.enable_read_replica
            and self.replica_pool is not None
        )

        pool = self.replica_pool if use_replica else self.primary_pool
        pool_name = "replica" if use_replica else "primary"

        start_time = time.time()

        try:
            async with pool.connection() as conn:
                conn.row_factory = dict_row
                await conn.execute(f"SET statement_timeout = {int(self.config.command_timeout * 1000)}")
                logger.debug(f"Using {pool_name} database connection")
                yield conn

        except asyncio.TimeoutError:
            self.metrics.record_pool_wait()
            logger.warning(f"{pool_name} connection pool timeout")
            raise
        except Exception as e:
            self.metrics.record_error(e)
            logger.error(f"Error with {pool_name} connection: {e}")
            raise
        finally:
            duration = time.time() - start_time
            if duration > 0.1:
                logger.debug(f"{pool_name.title()} connection acquired in {duration:.3f}s")

    @asynccontextmanager
    async def transaction(self):
        async with self.get_connection() as conn:
            async with conn.transaction():
                yield conn

    async def execute_query(
        self,
        query: str,
        params: tuple = None,
        fetch_one: bool = False,
        fetch_all: bool = True,
    ) -> Any:
        last_exception = None

        for attempt in range(self.config.retry_attempts):
            start_time = time.time()

            try:
                async with self.get_connection() as conn:
                    cursor = await conn.execute(query, params)

                    if fetch_one:
                        result = await cursor.fetchone()
                    elif fetch_all:
                        result = await cursor.fetchall()
                    else:
                        result = None

                    duration = time.time() - start_time
                    self.metrics.record_query(duration, success=True)

                    return result

            except Exception as e:
                duration = time.time() - start_time
                self.metrics.record_query(duration, success=False)

                last_exception = e

                if attempt < self.config.retry_attempts - 1:
                    wait_time = self.config.retry_delay * (2 ** attempt)
                    logger.warning(
                        f"Query attempt {attempt + 1} failed, retrying in {wait_time}s: {e}"
                    )
                    await asyncio.sleep(wait_time)
                else:
                    logger.error(f"Query failed after {self.config.retry_attempts} attempts: {e}")

        self.metrics.record_error(last_exception)
        raise last_exception

    async def get_health_status(self) -> Dict[str, Any]:
        current_time = time.time()
        cache_key = "health_status"

        if (cache_key in self._health_cache and
            current_time - self._health_cache[cache_key]["timestamp"] < self._health_cache_timeout):
            return self._health_cache[cache_key]["data"]

        health_info = {
            "status": "unknown",
            "connected": False,
            "pool_info": {},
            "performance": {},
            "timestamp": current_time,
        }

        try:
            result = await self.execute_query("SELECT 1", fetch_one=True)
            if result:
                health_info["connected"] = True
                health_info["status"] = "healthy"

            if self.primary_pool:
                health_info["pool_info"] = {
                    "size": self.primary_pool.size,
                    "available": self.primary_pool.available,
                    "waiting": self.primary_pool.waiting,
                }

            health_info["performance"] = self.metrics.get_metrics()

            db_info = await self._get_database_info()
            health_info.update(db_info)

        except Exception as e:
            health_info["status"] = "unhealthy"
            health_info["error"] = str(e)
            logger.error(f"Database health check failed: {e}")

        self._health_cache[cache_key] = {
            "data": health_info,
            "timestamp": current_time,
        }

        return health_info

    async def _get_database_info(self) -> Dict[str, Any]:
        try:
            version_result = await self.execute_query("SELECT version()", fetch_one=True)

            connections_result = await self.execute_query(
                "SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active'",
                fetch_one=True
            )

            size_result = await self.execute_query(
                "SELECT pg_database_size(current_database()) as db_size",
                fetch_one=True
            )

            return {
                "version": version_result["version"] if version_result else "unknown",
                "active_connections": connections_result["active_connections"] if connections_result else 0,
                "database_size": size_result["db_size"] if size_result else 0,
            }

        except Exception as e:
            logger.warning(f"Could not fetch database info: {e}")
            return {}

    async def optimize_tables(self, tables: List[str] = None) -> Dict[str, Any]:
        results = {
            "tables_analyzed": [],
            "tables_vacuumed": [],
            "errors": [],
        }

        if not tables:
            table_query = """
                SELECT tablename FROM pg_tables
                WHERE schemaname = 'public'
            """
            table_results = await self.execute_query(table_query)
            tables = [row["tablename"] for row in table_results]

        for table in tables:
            try:
                await self.execute_query(f"ANALYZE {table}", fetch_all=False)
                results["tables_analyzed"].append(table)

                await self.execute_query(f"VACUUM (ANALYZE) {table}", fetch_all=False)
                results["tables_vacuumed"].append(table)

                logger.info(f"Optimized table: {table}")

            except Exception as e:
                error_msg = f"Failed to optimize table {table}: {e}"
                results["errors"].append(error_msg)
                logger.error(error_msg)

        return results

    def get_metrics_summary(self) -> Dict[str, Any]:
        return self.metrics.get_metrics()


_db_manager: Optional[DatabaseManager] = None


async def get_database_manager(config: DatabaseConfig = None) -> DatabaseManager:
    global _db_manager

    if _db_manager is None:
        _db_manager = DatabaseManager(config)
        await _db_manager.initialize()

    return _db_manager


async def close_database_manager():
    global _db_manager
    if _db_manager:
        await _db_manager.close()
        _db_manager = None


async def execute_query(query: str, params: tuple = None, **kwargs) -> Any:
    db_manager = await get_database_manager()
    return await db_manager.execute_query(query, params, **kwargs)


async def get_db_health() -> Dict[str, Any]:
    db_manager = await get_database_manager()
    return await db_manager.get_health_status()


@asynccontextmanager
async def database_connection():
    db_manager = await get_database_manager()
    async with db_manager.get_connection() as conn:
        yield conn
