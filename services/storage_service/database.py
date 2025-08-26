"""
Storage Service Database Manager
Handles download logging and bandwidth tracking
"""

import asyncio
import asyncpg
import os
from typing import List, Dict, Optional, Any
from datetime import datetime, timezone, timedelta
import uuid
import logging

logger = logging.getLogger(__name__)

class StorageDatabase:
    def __init__(self):
        self.pool = None
        self.database_url = os.getenv(
            "DATABASE_URL", 
            "postgresql://postgres:password@localhost:5432/betterbooks"
        )
    
    async def initialize(self):
        """Initialize database connection pool"""
        try:
            self.pool = await asyncpg.create_pool(
                self.database_url,
                min_size=2,
                max_size=10,
                command_timeout=60,
            )
            
            # Create tables if they don't exist
            await self._create_tables()
            
            logger.info("Storage database initialized")
        except Exception as e:
            logger.error(f"Failed to initialize storage database: {e}")
            raise
    
    async def close(self):
        """Close database connection pool"""
        if self.pool:
            await self.pool.close()
            logger.info("Storage database connection pool closed")
    
    async def health_check(self) -> Dict[str, Any]:
        """Check database health"""
        try:
            async with self.pool.acquire() as conn:
                result = await conn.fetchval("SELECT 1")
                return {"status": "healthy", "connection": "ok"}
        except Exception as e:
            logger.error(f"Storage database health check failed: {e}")
            return {"status": "unhealthy", "error": str(e)}
    
    async def _create_tables(self):
        """Create storage-related tables"""
        async with self.pool.acquire() as conn:
            # Download logs table
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS download_logs (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    user_id UUID NOT NULL,
                    book_id UUID NOT NULL,
                    download_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    file_size_bytes BIGINT DEFAULT 0,
                    ip_address INET,
                    user_agent TEXT,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                )
            """)
            
            # File metadata table
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS file_metadata (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    book_id UUID NOT NULL UNIQUE,
                    title TEXT NOT NULL,
                    total_files INTEGER DEFAULT 0,
                    total_size_bytes BIGINT DEFAULT 0,
                    blob_container TEXT,
                    blob_path_prefix TEXT,
                    metadata_json JSONB,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                )
            """)
            
            # Create indexes
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_download_logs_user_id 
                ON download_logs(user_id)
            """)
            
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_download_logs_book_id 
                ON download_logs(book_id)
            """)
            
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_download_logs_time 
                ON download_logs(download_time)
            """)
    
    async def log_download(
        self,
        user_id: str,
        book_id: str,
        file_size: int = 0,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ):
        """Log a download request"""
        try:
            async with self.pool.acquire() as conn:
                await conn.execute("""
                    INSERT INTO download_logs 
                    (user_id, book_id, file_size_bytes, ip_address, user_agent)
                    VALUES ($1, $2, $3, $4, $5)
                """, user_id, book_id, file_size, ip_address, user_agent)
            
            logger.info(f"Logged download: user={user_id}, book={book_id}, size={file_size}")
        
        except Exception as e:
            logger.error(f"Error logging download: {e}")
            # Don't raise exception - logging failures shouldn't break downloads
    
    async def store_file_metadata(
        self,
        book_id: str,
        title: str,
        filename: str,
        file_size: int,
        blob_url: str,
        content_type: Optional[str] = None
    ):
        """Store file metadata"""
        try:
            metadata = {
                "filename": filename,
                "blob_url": blob_url,
                "content_type": content_type,
                "uploaded_at": datetime.now(timezone.utc).isoformat()
            }
            
            async with self.pool.acquire() as conn:
                await conn.execute("""
                    INSERT INTO file_metadata 
                    (book_id, title, total_files, total_size_bytes, metadata_json)
                    VALUES ($1, $2, 1, $3, $4)
                    ON CONFLICT (book_id) DO UPDATE SET
                        total_files = file_metadata.total_files + 1,
                        total_size_bytes = file_metadata.total_size_bytes + $3,
                        metadata_json = file_metadata.metadata_json || $4,
                        updated_at = NOW()
                """, book_id, title, file_size, metadata)
            
            logger.info(f"Stored file metadata: book={book_id}, file={filename}")
        
        except Exception as e:
            logger.error(f"Error storing file metadata: {e}")
            raise
    
    async def update_book_files(
        self,
        book_id: str,
        files: List[Dict[str, Any]],
        total_size: int
    ):
        """Update book with multiple files"""
        try:
            metadata = {
                "files": files,
                "upload_batch_at": datetime.now(timezone.utc).isoformat()
            }
            
            async with self.pool.acquire() as conn:
                await conn.execute("""
                    UPDATE file_metadata SET
                        total_files = $2,
                        total_size_bytes = $3,
                        metadata_json = metadata_json || $4,
                        updated_at = NOW()
                    WHERE book_id = $1
                """, book_id, len(files), total_size, metadata)
            
            logger.info(f"Updated book files: book={book_id}, files={len(files)}")
        
        except Exception as e:
            logger.error(f"Error updating book files: {e}")
            raise
    
    async def get_bandwidth_usage(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None
    ) -> Dict[str, Any]:
        """Get bandwidth usage statistics"""
        try:
            # Default to last 30 days if no dates provided
            if not start_date:
                start = datetime.now(timezone.utc) - timedelta(days=30)
            else:
                start = datetime.fromisoformat(start_date)
            
            if not end_date:
                end = datetime.now(timezone.utc)
            else:
                end = datetime.fromisoformat(end_date)
            
            async with self.pool.acquire() as conn:
                # Get total stats
                stats = await conn.fetchrow("""
                    SELECT 
                        COUNT(*) as total_downloads,
                        COALESCE(SUM(file_size_bytes), 0) as total_bytes,
                        COUNT(DISTINCT user_id) as unique_users
                    FROM download_logs 
                    WHERE download_time >= $1 AND download_time <= $2
                """, start, end)
                
                # Get top books
                top_books = await conn.fetch("""
                    SELECT 
                        book_id,
                        COUNT(*) as download_count,
                        SUM(file_size_bytes) as total_bytes
                    FROM download_logs 
                    WHERE download_time >= $1 AND download_time <= $2
                    GROUP BY book_id
                    ORDER BY download_count DESC
                    LIMIT 10
                """, start, end)
            
            return {
                "period_start": start,
                "period_end": end,
                "total_downloads": stats['total_downloads'],
                "total_bytes_transferred": stats['total_bytes'],
                "total_gb_transferred": round(stats['total_bytes'] / (1024**3), 2),
                "unique_users": stats['unique_users'],
                "top_books": [
                    {
                        "book_id": str(book['book_id']),
                        "download_count": book['download_count'],
                        "total_bytes": book['total_bytes'],
                        "total_mb": round(book['total_bytes'] / (1024**2), 2)
                    }
                    for book in top_books
                ]
            }
        
        except Exception as e:
            logger.error(f"Error getting bandwidth usage: {e}")
            return {
                "period_start": start if 'start' in locals() else None,
                "period_end": end if 'end' in locals() else None,
                "total_downloads": 0,
                "total_bytes_transferred": 0,
                "total_gb_transferred": 0.0,
                "unique_users": 0,
                "top_books": [],
                "error": str(e)
            }
    
    async def cleanup_expired_downloads(self) -> int:
        """Clean up old download logs (older than 90 days)"""
        try:
            cutoff_date = datetime.now(timezone.utc) - timedelta(days=90)
            
            async with self.pool.acquire() as conn:
                result = await conn.execute("""
                    DELETE FROM download_logs 
                    WHERE download_time < $1
                """, cutoff_date)
            
            # Extract count from result string (e.g., "DELETE 42")
            count = int(result.split()[-1]) if result.split()[-1].isdigit() else 0
            
            logger.info(f"Cleaned up {count} old download logs")
            return count
        
        except Exception as e:
            logger.error(f"Error cleaning up download logs: {e}")
            return 0