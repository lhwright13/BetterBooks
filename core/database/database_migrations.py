import re
import logging
import hashlib
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
import asyncio

logger = logging.getLogger(__name__)


class MigrationStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    ROLLED_BACK = "rolled_back"


@dataclass
class Migration:
    version: str
    name: str
    up_sql: str
    down_sql: str = ""
    description: str = ""
    checksum: str = ""
    applied_at: Optional[datetime] = None
    execution_time: Optional[float] = None
    status: MigrationStatus = MigrationStatus.PENDING

    def __post_init__(self):
        if not self.checksum:
            self.checksum = self._calculate_checksum()

    def _calculate_checksum(self) -> str:
        content = f"{self.version}{self.name}{self.up_sql}{self.down_sql}"
        return hashlib.sha256(content.encode()).hexdigest()


class DatabaseMigrationManager:

    def __init__(self, db_manager, migrations_dir: str = None):
        self.db_manager = db_manager
        self.migrations_dir = Path(migrations_dir or "migrations")
        self.migrations: List[Migration] = []
        self._migration_lock = asyncio.Lock()

    async def initialize(self) -> bool:
        try:
            logger.info("Initializing database migration system...")

            await self._create_migrations_table()
            self._load_migrations_from_filesystem()
            await self._validate_applied_migrations()

            logger.info(f"Migration system initialized with {len(self.migrations)} migrations")
            return True

        except Exception as e:
            logger.error(f"Failed to initialize migration system: {e}")
            return False

    async def _create_migrations_table(self):
        sql = """
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                name VARCHAR(500) NOT NULL,
                checksum VARCHAR(64) NOT NULL,
                applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                execution_time INTERVAL,
                status VARCHAR(50) DEFAULT 'completed',
                rollback_sql TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        """

        await self.db_manager.execute_query(sql, fetch_all=False)

        await self.db_manager.execute_query("""
            CREATE INDEX IF NOT EXISTS idx_schema_migrations_version
            ON schema_migrations(version)
        """, fetch_all=False)

        await self.db_manager.execute_query("""
            CREATE INDEX IF NOT EXISTS idx_schema_migrations_applied_at
            ON schema_migrations(applied_at)
        """, fetch_all=False)

        logger.info("Migration tracking table created")

    def _load_migrations_from_filesystem(self):
        if not self.migrations_dir.exists():
            logger.warning(f"Migrations directory {self.migrations_dir} does not exist")
            return

        migration_files = []
        for ext in ['*.sql', '*.py']:
            migration_files.extend(self.migrations_dir.glob(ext))

        for file_path in sorted(migration_files):
            try:
                migration = self._parse_migration_file(file_path)
                if migration:
                    self.migrations.append(migration)
            except Exception as e:
                logger.error(f"Failed to parse migration file {file_path}: {e}")

        logger.info(f"Loaded {len(self.migrations)} migrations from filesystem")

    def _parse_migration_file(self, file_path: Path) -> Optional[Migration]:
        filename = file_path.name

        # Expected format: V001_20240101_create_users_table.sql
        version_match = re.match(r'V(\d+)_(\d+)_(.+)\.(sql|py)$', filename)
        if not version_match:
            logger.warning(f"Migration file {filename} doesn't match naming pattern")
            return None

        version_num, timestamp, name_part, extension = version_match.groups()
        version = f"V{version_num}_{timestamp}"
        name = name_part.replace('_', ' ').title()

        content = file_path.read_text(encoding='utf-8')

        if extension == 'py':
            logger.warning(f"Python migrations not yet supported: {filename}")
            return None

        up_sql, down_sql = self._parse_sql_migration(content)

        return Migration(
            version=version,
            name=name,
            up_sql=up_sql,
            down_sql=down_sql,
            description=f"Migration {version}: {name}",
        )

    def _parse_sql_migration(self, content: str) -> Tuple[str, str]:
        up_match = re.search(r'-- \+migrate Up\s*\n(.*?)(?=-- \+migrate Down|\Z)',
                            content, re.DOTALL | re.IGNORECASE)
        down_match = re.search(r'-- \+migrate Down\s*\n(.*)',
                              content, re.DOTALL | re.IGNORECASE)

        up_sql = up_match.group(1).strip() if up_match else content.strip()
        down_sql = down_match.group(1).strip() if down_match else ""

        return up_sql, down_sql

    async def _validate_applied_migrations(self):
        applied_migrations = await self.db_manager.execute_query("""
            SELECT version, name, checksum, status
            FROM schema_migrations
            ORDER BY version
        """)

        applied_dict = {m["version"]: m for m in applied_migrations}

        for migration in self.migrations:
            if migration.version in applied_dict:
                applied = applied_dict[migration.version]

                if applied["checksum"] != migration.checksum:
                    logger.error(
                        f"Checksum mismatch for migration {migration.version}. "
                        f"Applied: {applied['checksum']}, "
                        f"Current: {migration.checksum}"
                    )
                    raise ValueError(f"Migration {migration.version} has been modified")

                migration.status = MigrationStatus(applied["status"])
                if migration.status == MigrationStatus.COMPLETED:
                    logger.debug(f"Migration {migration.version} already applied")

    async def get_migration_status(self) -> Dict[str, Any]:
        applied_count = len([m for m in self.migrations if m.status == MigrationStatus.COMPLETED])
        pending_count = len([m for m in self.migrations if m.status == MigrationStatus.PENDING])
        failed_count = len([m for m in self.migrations if m.status == MigrationStatus.FAILED])

        latest_applied = await self.db_manager.execute_query("""
            SELECT version, applied_at
            FROM schema_migrations
            WHERE status = 'completed'
            ORDER BY applied_at DESC
            LIMIT 1
        """, fetch_one=True)

        return {
            "total_migrations": len(self.migrations),
            "applied": applied_count,
            "pending": pending_count,
            "failed": failed_count,
            "latest_applied": latest_applied,
            "migrations": [
                {
                    "version": m.version,
                    "name": m.name,
                    "status": m.status.value,
                    "applied_at": m.applied_at,
                    "execution_time": m.execution_time,
                }
                for m in self.migrations
            ],
        }

    async def apply_migrations(self, dry_run: bool = False, target_version: str = None) -> Dict[str, Any]:
        async with self._migration_lock:
            logger.info(f"Starting migration {'dry-run' if dry_run else 'application'}")

            results = {
                "applied": [],
                "failed": [],
                "skipped": [],
                "dry_run": dry_run,
            }

            pending_migrations = [
                m for m in self.migrations
                if m.status == MigrationStatus.PENDING
            ]

            if target_version:
                pending_migrations = [
                    m for m in pending_migrations
                    if m.version <= target_version
                ]

            logger.info(f"Found {len(pending_migrations)} pending migrations")

            if dry_run:
                for migration in pending_migrations:
                    results["applied"].append({
                        "version": migration.version,
                        "name": migration.name,
                        "sql": migration.up_sql[:200] + "..." if len(migration.up_sql) > 200 else migration.up_sql,
                    })
                return results

            for migration in pending_migrations:
                try:
                    await self._apply_single_migration(migration)
                    results["applied"].append({
                        "version": migration.version,
                        "name": migration.name,
                        "execution_time": migration.execution_time,
                    })

                except Exception as e:
                    logger.error(f"Failed to apply migration {migration.version}: {e}")
                    results["failed"].append({
                        "version": migration.version,
                        "name": migration.name,
                        "error": str(e),
                    })
                    break

            logger.info(
                f"Migration complete. Applied: {len(results['applied'])}, "
                f"Failed: {len(results['failed'])}"
            )

            return results

    async def _apply_single_migration(self, migration: Migration):
        logger.info(f"Applying migration {migration.version}: {migration.name}")

        start_time = asyncio.get_event_loop().time()

        try:
            await self._update_migration_status(
                migration.version,
                MigrationStatus.RUNNING
            )

            async with self.db_manager.database_connection() as conn:
                async with conn.transaction():
                    statements = [
                        stmt.strip() for stmt in migration.up_sql.split(';')
                        if stmt.strip()
                    ]

                    for statement in statements:
                        await conn.execute(statement)

            execution_time = asyncio.get_event_loop().time() - start_time
            migration.execution_time = execution_time

            await self._record_migration_success(migration, execution_time)

            logger.info(
                f"Successfully applied migration {migration.version} "
                f"in {execution_time:.3f} seconds"
            )

        except Exception as e:
            await self._update_migration_status(
                migration.version,
                MigrationStatus.FAILED
            )
            migration.status = MigrationStatus.FAILED

            logger.error(f"Migration {migration.version} failed: {e}")
            raise

    async def _record_migration_success(self, migration: Migration, execution_time: float):
        await self.db_manager.execute_query("""
            INSERT INTO schema_migrations
            (version, name, checksum, applied_at, execution_time, status, rollback_sql)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (version) DO UPDATE SET
                status = EXCLUDED.status,
                applied_at = EXCLUDED.applied_at,
                execution_time = EXCLUDED.execution_time,
                updated_at = NOW()
        """, (
            migration.version,
            migration.name,
            migration.checksum,
            datetime.now(timezone.utc),
            f"{execution_time} seconds",
            MigrationStatus.COMPLETED.value,
            migration.down_sql,
        ), fetch_all=False)

        migration.status = MigrationStatus.COMPLETED
        migration.applied_at = datetime.now(timezone.utc)
        migration.execution_time = execution_time

    async def _update_migration_status(self, version: str, status: MigrationStatus):
        await self.db_manager.execute_query("""
            INSERT INTO schema_migrations (version, name, checksum, status)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (version) DO UPDATE SET
                status = EXCLUDED.status,
                updated_at = NOW()
        """, (version, "Unknown", "unknown", status.value), fetch_all=False)

    async def rollback_migration(self, version: str) -> Dict[str, Any]:
        async with self._migration_lock:
            logger.info(f"Rolling back migration {version}")

            migration_info = await self.db_manager.execute_query("""
                SELECT version, name, rollback_sql, status
                FROM schema_migrations
                WHERE version = %s
            """, (version,), fetch_one=True)

            if not migration_info:
                raise ValueError(f"Migration {version} not found")

            if migration_info["status"] != MigrationStatus.COMPLETED.value:
                raise ValueError(f"Cannot rollback migration {version} with status {migration_info['status']}")

            rollback_sql = migration_info["rollback_sql"]
            if not rollback_sql:
                raise ValueError(f"Migration {version} has no rollback SQL")

            try:
                start_time = asyncio.get_event_loop().time()

                async with self.db_manager.database_connection() as conn:
                    async with conn.transaction():
                        statements = [
                            stmt.strip() for stmt in rollback_sql.split(';')
                            if stmt.strip()
                        ]

                        for statement in statements:
                            await conn.execute(statement)

                execution_time = asyncio.get_event_loop().time() - start_time

                await self.db_manager.execute_query("""
                    UPDATE schema_migrations
                    SET status = %s, updated_at = NOW()
                    WHERE version = %s
                """, (MigrationStatus.ROLLED_BACK.value, version), fetch_all=False)

                logger.info(f"Successfully rolled back migration {version} in {execution_time:.3f} seconds")

                return {
                    "version": version,
                    "name": migration_info["name"],
                    "execution_time": execution_time,
                    "status": "rolled_back",
                }

            except Exception as e:
                logger.error(f"Failed to rollback migration {version}: {e}")
                raise

    async def create_migration(self, name: str, up_sql: str, down_sql: str = "") -> str:
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        next_num = len(self.migrations) + 1
        version = f"V{next_num:03d}_{timestamp}"

        safe_name = re.sub(r'[^\w\s-]', '', name).strip()
        safe_name = re.sub(r'[-\s]+', '_', safe_name).lower()
        filename = f"{version}_{safe_name}.sql"

        content = f"""-- Migration: {name}
-- Created: {datetime.now().isoformat()}
-- Version: {version}

-- +migrate Up
{up_sql}

-- +migrate Down
{down_sql}
"""

        self.migrations_dir.mkdir(parents=True, exist_ok=True)

        migration_file = self.migrations_dir / filename
        migration_file.write_text(content, encoding='utf-8')

        logger.info(f"Created migration file: {filename}")

        return version


_migration_manager: Optional[DatabaseMigrationManager] = None


async def get_migration_manager(db_manager) -> DatabaseMigrationManager:
    global _migration_manager
    if _migration_manager is None:
        _migration_manager = DatabaseMigrationManager(db_manager)
        await _migration_manager.initialize()
    return _migration_manager


async def apply_migrations(db_manager, dry_run: bool = False):
    migration_manager = await get_migration_manager(db_manager)
    return await migration_manager.apply_migrations(dry_run=dry_run)


async def get_migration_status(db_manager):
    migration_manager = await get_migration_manager(db_manager)
    return await migration_manager.get_migration_status()
