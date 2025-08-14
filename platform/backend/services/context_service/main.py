"""REST service that manages embeddings in a Postgres database with connection pooling."""

import os
import sys
from pathlib import Path
from typing import List
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from pgvector.psycopg import register_vector

from core.database.database_manager import (
    DatabaseConfig, get_database_manager, close_database_manager, 
    execute_query, database_connection, get_db_health
)
from core.database.database_indexes import get_index_manager, create_all_indexes
from core.database.database_migrations import get_migration_manager, apply_migrations, get_migration_status
from core.infrastructure.logging_config import setup_logging
from core.infrastructure.health_checks import HealthCheck, create_health_endpoint, check_database
from core.infrastructure.metrics import setup_metrics
# from core.infrastructure.tracing import (
#     setup_tracing, instrument_fastapi, instrument_external_libraries,
#     get_development_tracing_config, DatabaseTracingHelper
# )

# Set up structured logging
logger = setup_logging(
    service_name="context_service",
    log_level=os.getenv("LOG_LEVEL", "INFO")
)

# Set up distributed tracing
# environment = os.getenv("ENVIRONMENT", "development")
# if environment == "development":
#     tracing_config = get_development_tracing_config("context_service")
# else:
#     from tracing import get_production_tracing_config
#     tracing_config = get_production_tracing_config("context_service")

# tracer = setup_tracing(tracing_config)
# instrument_external_libraries()

# Database initialization
async def init_database():
    """Initialize database schema and extensions."""
    try:
        # Get database manager
        db_config = DatabaseConfig(
            min_connections=3,
            max_connections=15,
            connection_timeout=10.0
        )
        db_manager = await get_database_manager(db_config)
        
        logger.info("Initializing database schema...")
        
        async with database_connection() as conn:
            # Enable pgvector extension
            await conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
            
            # Register vector type - skipping for compatibility
            # TODO: Fix pgvector registration for psycopg3
            logger.info("Skipping vector type registration for compatibility")
            
            # Create embeddings table with optimized structure
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS embeddings (
                    id TEXT PRIMARY KEY,
                    embedding vector(1536),
                    book_id TEXT,
                    chapter_id TEXT,
                    content_type TEXT DEFAULT 'text',
                    metadata JSONB DEFAULT '{}',
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                )
            """)
            
            # Create indexes for performance
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_embeddings_book_id 
                ON embeddings(book_id)
            """)
            
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_embeddings_chapter_id 
                ON embeddings(chapter_id)
            """)
            
            # Note: Vector and other indexes are created separately via index manager
            
            await conn.commit()
        
        logger.info("Database schema initialized successfully")
        
        # Apply any pending migrations
        logger.info("Checking for pending migrations...")
        migration_results = await apply_migrations(db_manager)
        logger.info(
            f"Migration completed: {len(migration_results['applied'])} applied, "
            f"{len(migration_results['failed'])} failed"
        )
        
        # Create all indexes for optimal performance  
        logger.info("Creating database indexes...")
        index_results = await create_all_indexes(db_manager)
        logger.info(
            f"Index creation completed: {len(index_results['created'])} created, "
            f"{len(index_results['skipped'])} skipped, {len(index_results['failed'])} failed"
        )
        
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle."""
    # Startup
    logger.info("Starting Context Service...")
    await init_database()
    yield
    # Shutdown
    logger.info("Shutting down Context Service...")
    await close_database_manager()

# FastAPI application instance with lifecycle management
app = FastAPI(
    title="EchoWright Context Service",
    description="Vector embeddings and similarity search service",
    version="1.0.0",
    lifespan=lifespan
)

# Set up health checks
health_check = HealthCheck("context_service", "1.0.0")

# Add database health check
async def check_database_health():
    return await get_db_health()

health_check.add_check("database", check_database_health)
create_health_endpoint(app, health_check)

# Set up metrics
metrics_collector = setup_metrics(app, "context_service")

# Instrument FastAPI with tracing
# instrument_fastapi(app, "context_service")

# Custom metrics
embedding_queries = metrics_collector.create_counter(
    "embedding_queries_total",
    "Total embedding queries",
    ["operation", "status"]
)

embedding_query_duration = metrics_collector.create_histogram(
    "embedding_query_duration_seconds",
    "Embedding query duration",
    ["operation"],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)
)


class EmbeddingItem(BaseModel):
    """Model for inserting or updating an embedding."""

    id: str
    embedding: List[float]
    book_id: str = None
    chapter_id: str = None
    content_type: str = "text"
    metadata: dict = {}


class SearchQuery(BaseModel):
    """Query for similarity search."""

    embedding: List[float]
    top_k: int = 5
    book_id: str = None
    chapter_id: str = None
    min_similarity: float = None


@app.post("/embeddings")
async def add_embedding(item: EmbeddingItem) -> dict:
    """Insert or update an embedding vector with enhanced metadata."""
    
    import time
    start_time = time.time()
    
    try:
        with tracer.start_as_current_span("context_service.add_embedding") as span:
            span.set_attribute("embedding_id", item.id)
            span.set_attribute("book_id", item.book_id or "unknown")
            span.set_attribute("chapter_id", item.chapter_id or "unknown")
            
            with DatabaseTracingHelper.trace_db_query(tracer, "UPSERT", "embeddings") as db_span:
                result = await execute_query(
                    """
                    INSERT INTO embeddings (id, embedding, book_id, chapter_id, content_type, metadata, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (id) DO UPDATE SET 
                        embedding = EXCLUDED.embedding,
                        book_id = EXCLUDED.book_id,
                        chapter_id = EXCLUDED.chapter_id,
                        content_type = EXCLUDED.content_type,
                        metadata = EXCLUDED.metadata,
                        updated_at = NOW()
                    """,
                    (item.id, item.embedding, item.book_id, item.chapter_id, 
                     item.content_type, item.metadata),
                    fetch_all=False
                )
                
                DatabaseTracingHelper.add_db_query_attributes(db_span, rows_affected=1)
        
        # Record metrics
        duration = time.time() - start_time
        embedding_queries.labels(operation="upsert", status="success").inc()
        embedding_query_duration.labels(operation="upsert").observe(duration)
        
        logger.info(
            "Embedding stored",
            embedding_id=item.id,
            book_id=item.book_id,
            duration=duration
        )
        
        return {"status": "stored", "id": item.id}
        
    except Exception as e:
        # Record error metrics
        duration = time.time() - start_time
        embedding_queries.labels(operation="upsert", status="error").inc()
        embedding_query_duration.labels(operation="upsert").observe(duration)
        
        logger.error(f"Failed to store embedding: {e}", embedding_id=item.id)
        raise HTTPException(status_code=500, detail=f"Failed to store embedding: {str(e)}")


@app.post("/search")
async def search_embeddings(query: SearchQuery) -> dict:
    """Find IDs of embeddings most similar to the query vector with enhanced filtering."""
    
    import time
    start_time = time.time()
    
    try:
        with tracer.start_as_current_span("context_service.search_embeddings") as span:
            span.set_attribute("top_k", query.top_k)
            span.set_attribute("book_id", query.book_id or "any")
            span.set_attribute("chapter_id", query.chapter_id or "any")
            
            # Build query with optional filters
            where_clauses = []
            params = [query.embedding, query.top_k]
            
            if query.book_id:
                where_clauses.append("book_id = %s")
                params.insert(-1, query.book_id)
            
            if query.chapter_id:
                where_clauses.append("chapter_id = %s") 
                params.insert(-1, query.chapter_id)
            
            where_clause = " AND " + " AND ".join(where_clauses) if where_clauses else ""
            
            sql_query = f"""
                SELECT id, book_id, chapter_id, metadata, 
                       (1 - (embedding <-> %s::vector)) as similarity
                FROM embeddings
                WHERE 1=1{where_clause}
                ORDER BY embedding <-> %s::vector
                LIMIT %s
            """
            
            with DatabaseTracingHelper.trace_db_query(tracer, "SELECT", "embeddings") as db_span:
                results = await execute_query(sql_query, tuple(params))
                DatabaseTracingHelper.add_db_query_attributes(db_span, rows_affected=len(results))
            
            # Filter by minimum similarity if specified
            if query.min_similarity:
                results = [r for r in results if r["similarity"] >= query.min_similarity]
            
            span.set_attribute("results_found", len(results))
        
        # Record metrics
        duration = time.time() - start_time
        embedding_queries.labels(operation="search", status="success").inc()
        embedding_query_duration.labels(operation="search").observe(duration)
        
        logger.info(
            "Embedding search completed",
            results_count=len(results),
            duration=duration,
            book_id=query.book_id
        )
        
        return {
            "results": results,
            "count": len(results),
            "query_time": duration
        }
        
    except Exception as e:
        # Record error metrics  
        duration = time.time() - start_time
        embedding_queries.labels(operation="search", status="error").inc()
        embedding_query_duration.labels(operation="search").observe(duration)
        
        logger.error(f"Failed to search embeddings: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to search embeddings: {str(e)}")


@app.get("/embeddings/stats")
async def get_embedding_stats() -> dict:
    """Get statistics about stored embeddings."""
    
    try:
        with tracer.start_as_current_span("context_service.get_stats") as span:
            # Get total count
            total_result = await execute_query(
                "SELECT COUNT(*) as total FROM embeddings",
                fetch_one=True
            )
            
            # Get count by book
            book_stats = await execute_query("""
                SELECT book_id, COUNT(*) as count
                FROM embeddings 
                WHERE book_id IS NOT NULL
                GROUP BY book_id
                ORDER BY count DESC
            """)
            
            # Get recent activity
            recent_result = await execute_query("""
                SELECT COUNT(*) as recent_count
                FROM embeddings 
                WHERE created_at > NOW() - INTERVAL '24 hours'
            """, fetch_one=True)
            
            stats = {
                "total_embeddings": total_result["total"] if total_result else 0,
                "recent_embeddings": recent_result["recent_count"] if recent_result else 0,
                "books": book_stats or [],
                "database_health": await get_db_health()
            }
            
            span.set_attribute("total_embeddings", stats["total_embeddings"])
        
        return stats
        
    except Exception as e:
        logger.error(f"Failed to get embedding stats: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get stats: {str(e)}")


@app.delete("/embeddings/{embedding_id}")
async def delete_embedding(embedding_id: str) -> dict:
    """Delete a specific embedding."""
    
    try:
        with tracer.start_as_current_span("context_service.delete_embedding") as span:
            span.set_attribute("embedding_id", embedding_id)
            
            result = await execute_query(
                "DELETE FROM embeddings WHERE id = %s",
                (embedding_id,),
                fetch_all=False
            )
        
        return {"status": "deleted", "id": embedding_id}
        
    except Exception as e:
        logger.error(f"Failed to delete embedding: {e}", embedding_id=embedding_id)
        raise HTTPException(status_code=500, detail=f"Failed to delete embedding: {str(e)}")


@app.get("/admin/indexes")
async def get_index_info() -> dict:
    """Get information about database indexes."""
    
    try:
        with tracer.start_as_current_span("context_service.get_index_info") as span:
            index_manager = get_index_manager()
            db_manager = await get_database_manager()
            
            # Get index definitions
            index_definitions = []
            for idx in index_manager.get_index_definitions():
                index_definitions.append({
                    "name": idx.name,
                    "table": idx.table,
                    "columns": idx.columns,
                    "type": idx.index_type.value,
                    "unique": idx.unique,
                    "description": idx.description
                })
            
            # Get usage analysis
            analysis = await index_manager.analyze_index_usage(db_manager)
            
            span.set_attribute("total_indexes", len(index_definitions))
        
        return {
            "index_definitions": index_definitions,
            "usage_analysis": analysis,
            "total_indexes": len(index_definitions)
        }
        
    except Exception as e:
        logger.error(f"Failed to get index info: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get index info: {str(e)}")


@app.post("/admin/indexes/recreate")
async def recreate_indexes() -> dict:
    """Recreate all database indexes."""
    
    try:
        with tracer.start_as_current_span("context_service.recreate_indexes") as span:
            db_manager = await get_database_manager()
            
            # Recreate indexes
            results = await create_all_indexes(db_manager)
            
            span.set_attribute("indexes_created", len(results["created"]))
            span.set_attribute("indexes_failed", len(results["failed"]))
        
        logger.info("Indexes recreated successfully", **results)
        return {"status": "completed", "results": results}
        
    except Exception as e:
        logger.error(f"Failed to recreate indexes: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to recreate indexes: {str(e)}")


@app.get("/admin/indexes/optimize")
async def optimize_indexes() -> dict:
    """Get index optimization recommendations."""
    
    try:
        with tracer.start_as_current_span("context_service.optimize_indexes") as span:
            index_manager = get_index_manager()
            db_manager = await get_database_manager()
            
            # Get optimization recommendations
            optimization = await index_manager.optimize_vector_indexes(db_manager)
            
            span.set_attribute("recommendations_count", len(optimization.get("recommendations", [])))
        
        return optimization
        
    except Exception as e:
        logger.error(f"Failed to optimize indexes: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to optimize indexes: {str(e)}")


@app.get("/admin/migrations")
async def get_migrations_status() -> dict:
    """Get database migrations status."""
    
    try:
        with tracer.start_as_current_span("context_service.get_migrations_status") as span:
            db_manager = await get_database_manager()
            
            # Get migration status
            status = await get_migration_status(db_manager)
            
            span.set_attribute("total_migrations", status["total_migrations"])
            span.set_attribute("pending_migrations", status["pending"])
        
        return status
        
    except Exception as e:
        logger.error(f"Failed to get migration status: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get migration status: {str(e)}")


@app.post("/admin/migrations/apply")
async def apply_pending_migrations(dry_run: bool = False) -> dict:
    """Apply pending database migrations."""
    
    try:
        with tracer.start_as_current_span("context_service.apply_migrations") as span:
            db_manager = await get_database_manager()
            
            # Apply migrations
            results = await apply_migrations(db_manager, dry_run=dry_run)
            
            span.set_attribute("applied_count", len(results["applied"]))
            span.set_attribute("failed_count", len(results["failed"]))
            span.set_attribute("dry_run", dry_run)
        
        logger.info("Migrations applied successfully", **results)
        return {"status": "completed", "results": results}
        
    except Exception as e:
        logger.error(f"Failed to apply migrations: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to apply migrations: {str(e)}")


@app.post("/admin/migrations/{version}/rollback")
async def rollback_migration(version: str) -> dict:
    """Rollback a specific migration."""
    
    try:
        with tracer.start_as_current_span("context_service.rollback_migration") as span:
            db_manager = await get_database_manager()
            migration_manager = await get_migration_manager(db_manager)
            
            # Rollback migration
            result = await migration_manager.rollback_migration(version)
            
            span.set_attribute("migration_version", version)
            span.set_attribute("execution_time", result["execution_time"])
        
        logger.info(f"Migration {version} rolled back successfully", **result)
        return {"status": "completed", "result": result}
        
    except Exception as e:
        logger.error(f"Failed to rollback migration {version}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to rollback migration: {str(e)}")


@app.post("/admin/migrations/create")
async def create_migration(
    name: str,
    up_sql: str,
    down_sql: str = ""
) -> dict:
    """Create a new migration file."""
    
    try:
        with tracer.start_as_current_span("context_service.create_migration") as span:
            db_manager = await get_database_manager()
            migration_manager = await get_migration_manager(db_manager)
            
            # Create migration
            version = await migration_manager.create_migration(name, up_sql, down_sql)
            
            span.set_attribute("migration_version", version)
            span.set_attribute("migration_name", name)
        
        logger.info(f"Migration {version} created successfully", migration_name=name)
        return {"status": "created", "version": version, "name": name}
        
    except Exception as e:
        logger.error(f"Failed to create migration: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create migration: {str(e)}")

