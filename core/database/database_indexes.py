import logging
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, field
from enum import Enum

logger = logging.getLogger(__name__)


class IndexType(Enum):
    BTREE = "btree"
    HASH = "hash"
    GIN = "gin"
    GIST = "gist"
    HNSW = "hnsw"
    IVFFLAT = "ivfflat"


@dataclass
class IndexDefinition:
    name: str
    table: str
    columns: List[str]
    index_type: IndexType = IndexType.BTREE
    unique: bool = False
    partial_condition: Optional[str] = None
    options: Dict[str, Any] = field(default_factory=dict)
    description: str = ""


class DatabaseIndexManager:

    def __init__(self):
        self.indexes = self._define_indexes()

    def _define_indexes(self) -> List[IndexDefinition]:
        indexes = []

        # Embeddings table
        indexes.append(IndexDefinition(
            name="idx_embeddings_pkey",
            table="embeddings",
            columns=["id"],
            unique=True,
            description="Primary key for embeddings table",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_vector_hnsw",
            table="embeddings",
            columns=["embedding"],
            index_type=IndexType.HNSW,
            options={
                "m": 16,
                "ef_construction": 64,
                "distance_function": "vector_cosine_ops",
            },
            description="HNSW index for fast vector similarity search (production)",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_vector_ivfflat",
            table="embeddings",
            columns=["embedding"],
            index_type=IndexType.IVFFLAT,
            options={
                "lists": 100,
                "distance_function": "vector_cosine_ops",
            },
            description="IVFFlat index for vector similarity search (alternative)",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_book_id",
            table="embeddings",
            columns=["book_id"],
            description="Fast lookups by book ID",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_chapter_id",
            table="embeddings",
            columns=["chapter_id"],
            description="Fast lookups by chapter ID",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_book_chapter",
            table="embeddings",
            columns=["book_id", "chapter_id"],
            description="Composite index for book and chapter filtering",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_content_type",
            table="embeddings",
            columns=["content_type"],
            description="Fast filtering by content type",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_created_at",
            table="embeddings",
            columns=["created_at"],
            description="Time-based queries and analytics",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_updated_at",
            table="embeddings",
            columns=["updated_at"],
            description="Track recent updates and modifications",
        ))

        indexes.append(IndexDefinition(
            name="idx_embeddings_metadata_gin",
            table="embeddings",
            columns=["metadata"],
            index_type=IndexType.GIN,
            description="GIN index for efficient JSONB metadata queries",
        ))

        # Users table
        indexes.append(IndexDefinition(
            name="idx_users_email",
            table="users",
            columns=["email"],
            unique=True,
            description="Unique email constraint and fast user lookups",
        ))

        indexes.append(IndexDefinition(
            name="idx_users_username",
            table="users",
            columns=["username"],
            unique=True,
            partial_condition="username IS NOT NULL",
            description="Unique username constraint (partial for nullable field)",
        ))

        indexes.append(IndexDefinition(
            name="idx_users_role",
            table="users",
            columns=["role"],
            description="Fast filtering by user role",
        ))

        indexes.append(IndexDefinition(
            name="idx_users_created_at",
            table="users",
            columns=["created_at"],
            description="User registration analytics",
        ))

        # Sessions table
        indexes.append(IndexDefinition(
            name="idx_sessions_user_id",
            table="sessions",
            columns=["user_id"],
            description="Fast session lookup by user",
        ))

        indexes.append(IndexDefinition(
            name="idx_sessions_expires_at",
            table="sessions",
            columns=["expires_at"],
            description="Efficient session cleanup and expiration",
        ))

        # Audit logs table
        indexes.append(IndexDefinition(
            name="idx_audit_logs_user_id",
            table="audit_logs",
            columns=["user_id"],
            description="Fast audit log retrieval by user",
        ))

        indexes.append(IndexDefinition(
            name="idx_audit_logs_action",
            table="audit_logs",
            columns=["action"],
            description="Filter logs by action type",
        ))

        indexes.append(IndexDefinition(
            name="idx_audit_logs_created_at",
            table="audit_logs",
            columns=["created_at"],
            description="Time-based log queries and retention",
        ))

        indexes.append(IndexDefinition(
            name="idx_audit_logs_user_action_time",
            table="audit_logs",
            columns=["user_id", "action", "created_at"],
            description="Composite index for user activity analysis",
        ))

        return indexes

    def get_create_sql(self, index_def: IndexDefinition) -> str:
        is_vector = index_def.index_type in (IndexType.HNSW, IndexType.IVFFLAT)

        if is_vector:
            columns_spec = f"{index_def.columns[0]} {index_def.options.get('distance_function', 'vector_cosine_ops')}"
        else:
            columns_spec = ", ".join(index_def.columns)

        sql_parts = ["CREATE"]

        if index_def.unique:
            sql_parts.append("UNIQUE")

        sql_parts.extend([
            "INDEX",
            f"IF NOT EXISTS {index_def.name}",
            f"ON {index_def.table}",
        ])

        if index_def.index_type != IndexType.BTREE:
            sql_parts.append(f"USING {index_def.index_type.value}")

        sql_parts.append(f"({columns_spec})")

        if index_def.partial_condition:
            sql_parts.append(f"WHERE {index_def.partial_condition}")

        if is_vector and index_def.options:
            options_list = [
                f"{key} = {value}"
                for key, value in index_def.options.items()
                if key != 'distance_function'
            ]
            if options_list:
                sql_parts.append(f"WITH ({', '.join(options_list)})")

        return " ".join(sql_parts)

    def get_drop_sql(self, index_name: str) -> str:
        return f"DROP INDEX IF EXISTS {index_name}"

    async def create_all_indexes(self, db_manager):
        logger.info(f"Creating {len(self.indexes)} database indexes...")

        results = {
            "created": [],
            "skipped": [],
            "failed": [],
        }

        for index_def in self.indexes:
            try:
                table_check_sql = """
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.tables
                        WHERE table_name = %s
                    )
                """

                table_exists = await db_manager.execute_query(
                    table_check_sql, (index_def.table,), fetch_one=True
                )

                if not table_exists["exists"]:
                    logger.debug(f"Skipping index {index_def.name} - table {index_def.table} does not exist")
                    results["skipped"].append(index_def.name)
                    continue

                create_sql = self.get_create_sql(index_def)
                await db_manager.execute_query(create_sql, fetch_all=False)

                logger.info(f"Created index: {index_def.name} on {index_def.table}")
                results["created"].append(index_def.name)

            except Exception as e:
                logger.error(f"Failed to create index {index_def.name}: {e}")
                results["failed"].append({"index": index_def.name, "error": str(e)})

        logger.info(
            f"Index creation complete. Created: {len(results['created'])}, "
            f"Skipped: {len(results['skipped'])}, Failed: {len(results['failed'])}"
        )

        return results

    async def analyze_index_usage(self, db_manager) -> Dict[str, Any]:
        logger.info("Analyzing index usage statistics...")

        try:
            usage_sql = """
                SELECT
                    schemaname,
                    tablename,
                    indexname,
                    idx_tup_read,
                    idx_tup_fetch,
                    idx_scan
                FROM pg_stat_user_indexes
                ORDER BY idx_scan DESC, idx_tup_read DESC
            """

            usage_stats = await db_manager.execute_query(usage_sql)

            size_sql = """
                SELECT
                    schemaname,
                    tablename,
                    indexname,
                    pg_size_pretty(pg_relation_size(indexrelid)) as index_size,
                    pg_relation_size(indexrelid) as index_size_bytes
                FROM pg_stat_user_indexes
                ORDER BY pg_relation_size(indexrelid) DESC
            """

            size_stats = await db_manager.execute_query(size_sql)

            index_analysis = {
                "usage_stats": usage_stats,
                "size_stats": size_stats,
                "recommendations": self._generate_index_recommendations(usage_stats),
            }

            logger.info(f"Analyzed {len(usage_stats)} indexes")
            return index_analysis

        except Exception as e:
            logger.error(f"Failed to analyze index usage: {e}")
            return {"error": str(e)}

    def _generate_index_recommendations(self, usage_stats: List[Dict]) -> List[str]:
        recommendations = []

        for stat in usage_stats:
            if stat["idx_scan"] == 0:
                recommendations.append(
                    f"Consider dropping unused index: {stat['indexname']} on {stat['tablename']}"
                )
            elif stat["idx_scan"] < 10:
                recommendations.append(
                    f"Low usage index: {stat['indexname']} on {stat['tablename']} "
                    f"({stat['idx_scan']} scans)"
                )

        return recommendations

    async def optimize_vector_indexes(self, db_manager) -> Dict[str, Any]:
        logger.info("Optimizing vector indexes...")

        try:
            stats_sql = """
                SELECT
                    COUNT(*) as total_embeddings,
                    COUNT(DISTINCT book_id) as unique_books,
                    COUNT(DISTINCT chapter_id) as unique_chapters,
                    AVG(array_length(embedding, 1)) as avg_vector_dimension
                FROM embeddings
            """

            stats = await db_manager.execute_query(stats_sql, fetch_one=True)

            recommendations = []

            if stats["total_embeddings"] > 100000:
                recommendations.append(
                    "Consider increasing HNSW ef_construction parameter for better recall"
                )

            if stats["unique_books"] > 50:
                recommendations.append(
                    "Book-based partitioning might improve query performance"
                )

            if stats["total_embeddings"] < 10000:
                recommendations.append(
                    "IVFFlat might be more efficient than HNSW for smaller datasets"
                )

            return {
                "statistics": stats,
                "recommendations": recommendations,
            }

        except Exception as e:
            logger.error(f"Failed to optimize vector indexes: {e}")
            return {"error": str(e)}

    def get_index_definitions(self) -> List[IndexDefinition]:
        return self.indexes

    def get_index_by_name(self, name: str) -> Optional[IndexDefinition]:
        for index_def in self.indexes:
            if index_def.name == name:
                return index_def
        return None

    def get_indexes_for_table(self, table: str) -> List[IndexDefinition]:
        return [idx for idx in self.indexes if idx.table == table]


_index_manager: Optional[DatabaseIndexManager] = None


def get_index_manager() -> DatabaseIndexManager:
    global _index_manager
    if _index_manager is None:
        _index_manager = DatabaseIndexManager()
    return _index_manager


async def create_all_indexes(db_manager):
    index_manager = get_index_manager()
    return await index_manager.create_all_indexes(db_manager)


async def analyze_index_performance(db_manager):
    index_manager = get_index_manager()
    return await index_manager.analyze_index_usage(db_manager)
