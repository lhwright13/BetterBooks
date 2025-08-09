"""
Database storage and retrieval for AI-generated chapter summaries.

This module handles storing, retrieving, and managing chapter summaries
in PostgreSQL using the existing database schema.
"""

import os
import uuid
import json
import asyncio
from typing import List, Dict, Any, Optional, Union
from datetime import datetime

import asyncpg
from chapter_summaries import ChapterSummary, SummaryStyle


class SummaryStorageManager:
    """Manages storage and retrieval of chapter summaries in PostgreSQL."""
    
    def __init__(self, database_url: Optional[str] = None):
        self.database_url = database_url or os.getenv(
            "DATABASE_URL", 
            "postgresql://betterbooks:betterbooks@localhost:5432/betterbooks"
        )
        self.connection_pool = None
    
    async def init_connection_pool(self):
        """Initialize database connection pool."""
        if not self.connection_pool:
            self.connection_pool = await asyncpg.create_pool(
                self.database_url,
                min_size=1,
                max_size=5,
                command_timeout=30
            )
    
    async def close_connection_pool(self):
        """Close database connection pool."""
        if self.connection_pool:
            await self.connection_pool.close()
            self.connection_pool = None
    
    async def store_chapter_summaries(
        self,
        book_id: str,
        book_title: str,
        summaries: List[ChapterSummary],
        storage_metadata: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        Store chapter summaries in the database.
        
        Args:
            book_id: Unique identifier for the book
            book_title: Title of the book
            summaries: List of ChapterSummary objects to store
            storage_metadata: Optional metadata about the storage operation
            
        Returns:
            session_id: Unique identifier for this storage session
        """
        await self.init_connection_pool()
        
        session_id = str(uuid.uuid4())
        
        async with self.connection_pool.acquire() as conn:
            async with conn.transaction():
                # Store each summary
                for summary in summaries:
                    # 1. Store in ai_summaries table
                    summary_uuid = await conn.fetchval("""
                        INSERT INTO ai_summaries (
                            content_type, content_id, summary_type, summary_text,
                            summary_metadata, generated_by, quality_score
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
                        ON CONFLICT (content_type, content_id, summary_type) 
                        DO UPDATE SET
                            summary_text = EXCLUDED.summary_text,
                            summary_metadata = EXCLUDED.summary_metadata,
                            quality_score = EXCLUDED.quality_score,
                            updated_at = NOW()
                        RETURNING id
                    """, 
                        'chapter',
                        summary.chapter_id,
                        summary.summary_style.value,
                        summary.summary_text,
                        json.dumps({
                            'key_points': summary.key_points,
                            'themes': summary.themes,
                            'characters_mentioned': summary.characters_mentioned,
                            'word_count': summary.word_count,
                            'confidence_score': summary.confidence_score,
                            'generation_timestamp': summary.generation_timestamp.isoformat(),
                            'metadata': summary.metadata
                        }),
                        'ai_summary_system',
                        summary.confidence_score
                    )
                    
                    # 2. Store in chapter_metadata table (if chapter exists)
                    await conn.execute("""
                        INSERT INTO chapter_metadata (
                            chapter_id, ai_generated_summary, ai_confidence,
                            key_topics, metadata
                        ) VALUES ($1, $2, $3, $4, $5)
                        ON CONFLICT (chapter_id) 
                        DO UPDATE SET
                            ai_generated_summary = EXCLUDED.ai_generated_summary,
                            ai_confidence = EXCLUDED.ai_confidence,
                            key_topics = EXCLUDED.key_topics,
                            metadata = EXCLUDED.metadata,
                            updated_at = NOW()
                    """,
                        summary.chapter_id,
                        summary.summary_text,
                        summary.confidence_score,
                        summary.themes + summary.key_points,  # Combine themes and key points
                        json.dumps({
                            'summary_style': summary.summary_style.value,
                            'word_count': summary.word_count,
                            'characters_mentioned': summary.characters_mentioned,
                            'generation_metadata': summary.metadata
                        })
                    )
                
                # 3. Create a summary generation session record
                await conn.execute("""
                    INSERT INTO summary_generation_sessions (
                        id, book_id, book_title, total_summaries_generated,
                        summary_style, generation_metadata, session_timestamp
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
                """,
                    session_id,
                    book_id,
                    book_title,
                    len(summaries),
                    summaries[0].summary_style.value if summaries else 'mixed',
                    json.dumps(storage_metadata or {}),
                    datetime.now()
                )
        
        return session_id
    
    async def retrieve_chapter_summaries(
        self,
        book_id: Optional[str] = None,
        chapter_ids: Optional[List[str]] = None,
        summary_style: Optional[SummaryStyle] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        Retrieve chapter summaries from the database.
        
        Args:
            book_id: Optional book ID to filter by
            chapter_ids: Optional list of specific chapter IDs
            summary_style: Optional summary style to filter by
            limit: Maximum number of summaries to return
            
        Returns:
            List of summary dictionaries with metadata
        """
        await self.init_connection_pool()
        
        # Build query based on filters
        conditions = ["content_type = 'chapter'"]
        params = []
        param_count = 1
        
        if chapter_ids:
            placeholders = ','.join(f'${param_count + i}' for i in range(len(chapter_ids)))
            conditions.append(f"content_id = ANY(ARRAY[{placeholders}])")
            params.extend(chapter_ids)
            param_count += len(chapter_ids)
        
        if summary_style:
            conditions.append(f"summary_type = ${param_count}")
            params.append(summary_style.value)
            param_count += 1
        
        where_clause = " AND ".join(conditions)
        
        query = f"""
            SELECT 
                id, content_id as chapter_id, summary_type, summary_text,
                summary_metadata, quality_score, generation_timestamp,
                created_at, updated_at
            FROM ai_summaries 
            WHERE {where_clause}
            ORDER BY generation_timestamp DESC
            LIMIT ${param_count}
        """
        params.append(limit)
        
        async with self.connection_pool.acquire() as conn:
            rows = await conn.fetch(query, *params)
            
            summaries = []
            for row in rows:
                metadata = json.loads(row['summary_metadata']) if row['summary_metadata'] else {}
                
                summary_dict = {
                    'id': str(row['id']),
                    'chapter_id': row['chapter_id'],
                    'summary_style': row['summary_type'],
                    'summary_text': row['summary_text'],
                    'quality_score': float(row['quality_score']) if row['quality_score'] else 0.0,
                    'generation_timestamp': row['generation_timestamp'],
                    'created_at': row['created_at'],
                    'updated_at': row['updated_at'],
                    **metadata  # Unpack metadata fields
                }
                
                summaries.append(summary_dict)
            
            return summaries
    
    async def get_summary_by_chapter(
        self, 
        chapter_id: str, 
        summary_style: SummaryStyle = SummaryStyle.DETAILED
    ) -> Optional[Dict[str, Any]]:
        """
        Get a specific summary for a chapter.
        
        Args:
            chapter_id: The chapter identifier
            summary_style: The style of summary to retrieve
            
        Returns:
            Summary dictionary or None if not found
        """
        summaries = await self.retrieve_chapter_summaries(
            chapter_ids=[chapter_id],
            summary_style=summary_style,
            limit=1
        )
        
        return summaries[0] if summaries else None
    
    async def get_book_summaries(
        self,
        book_id: str,
        summary_style: Optional[SummaryStyle] = None
    ) -> List[Dict[str, Any]]:
        """
        Get all summaries for a specific book.
        
        Args:
            book_id: The book identifier
            summary_style: Optional style filter
            
        Returns:
            List of summary dictionaries ordered by chapter number
        """
        # First get chapters for this book to get proper ordering
        await self.init_connection_pool()
        
        async with self.connection_pool.acquire() as conn:
            # Get chapter IDs for this book
            chapter_rows = await conn.fetch("""
                SELECT id, chapter_number 
                FROM book_chapters 
                WHERE book_id = $1 
                ORDER BY chapter_number
            """, uuid.UUID(book_id) if book_id else None)
            
            if not chapter_rows:
                return []
            
            chapter_ids = [row['id'] for row in chapter_rows]
        
        # Get summaries for these chapters
        summaries = await self.retrieve_chapter_summaries(
            chapter_ids=chapter_ids,
            summary_style=summary_style
        )
        
        # Sort by chapter number
        chapter_order = {row['id']: row['chapter_number'] for row in chapter_rows}
        summaries.sort(key=lambda s: chapter_order.get(s['chapter_id'], 999))
        
        return summaries
    
    async def delete_summaries(
        self,
        chapter_ids: Optional[List[str]] = None,
        book_id: Optional[str] = None,
        summary_style: Optional[SummaryStyle] = None
    ) -> int:
        """
        Delete summaries based on filters.
        
        Args:
            chapter_ids: Optional list of chapter IDs
            book_id: Optional book ID (requires joining with chapters table)
            summary_style: Optional summary style filter
            
        Returns:
            Number of summaries deleted
        """
        await self.init_connection_pool()
        
        conditions = ["content_type = 'chapter'"]
        params = []
        param_count = 1
        
        if chapter_ids:
            placeholders = ','.join(f'${param_count + i}' for i in range(len(chapter_ids)))
            conditions.append(f"content_id = ANY(ARRAY[{placeholders}])")
            params.extend(chapter_ids)
            param_count += len(chapter_ids)
        
        if summary_style:
            conditions.append(f"summary_type = ${param_count}")
            params.append(summary_style.value)
            param_count += 1
        
        if book_id and not chapter_ids:
            # Need to join with book_chapters to filter by book_id
            query = f"""
                DELETE FROM ai_summaries 
                WHERE id IN (
                    SELECT s.id FROM ai_summaries s
                    JOIN book_chapters c ON s.content_id = c.id
                    WHERE c.book_id = ${param_count} AND s.content_type = 'chapter'
                    {f"AND s.summary_type = ${param_count + 1}" if summary_style else ""}
                )
            """
            params.append(uuid.UUID(book_id))
            if summary_style:
                params.append(summary_style.value)
        else:
            where_clause = " AND ".join(conditions)
            query = f"DELETE FROM ai_summaries WHERE {where_clause}"
        
        async with self.connection_pool.acquire() as conn:
            result = await conn.execute(query, *params)
            # Extract number from result string like "DELETE 5"
            return int(result.split()[-1]) if result and result.split()[-1].isdigit() else 0
    
    async def get_summary_statistics(self, book_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Get statistics about stored summaries.
        
        Args:
            book_id: Optional book ID to filter statistics
            
        Returns:
            Dictionary with summary statistics
        """
        await self.init_connection_pool()
        
        base_query = """
            SELECT 
                COUNT(*) as total_summaries,
                COUNT(DISTINCT content_id) as unique_chapters,
                COUNT(DISTINCT summary_type) as summary_styles,
                AVG(quality_score) as avg_quality_score,
                MIN(generation_timestamp) as earliest_summary,
                MAX(generation_timestamp) as latest_summary
            FROM ai_summaries 
            WHERE content_type = 'chapter'
        """
        
        params = []
        if book_id:
            base_query += """
                AND content_id IN (
                    SELECT id FROM book_chapters WHERE book_id = $1
                )
            """
            params.append(uuid.UUID(book_id))
        
        async with self.connection_pool.acquire() as conn:
            row = await conn.fetchrow(base_query, *params)
            
            # Get style breakdown
            style_query = """
                SELECT summary_type, COUNT(*) as count
                FROM ai_summaries 
                WHERE content_type = 'chapter'
            """
            if book_id:
                style_query += """
                    AND content_id IN (
                        SELECT id FROM book_chapters WHERE book_id = $1
                    )
                """
            style_query += " GROUP BY summary_type ORDER BY count DESC"
            
            style_rows = await conn.fetch(style_query, *params)
            
            return {
                'total_summaries': row['total_summaries'],
                'unique_chapters': row['unique_chapters'],
                'summary_styles_used': row['summary_styles'],
                'average_quality_score': float(row['avg_quality_score']) if row['avg_quality_score'] else 0.0,
                'earliest_summary': row['earliest_summary'],
                'latest_summary': row['latest_summary'],
                'style_breakdown': {
                    row['summary_type']: row['count'] for row in style_rows
                }
            }


# Add the missing table for summary generation sessions
# This would go in a migration file, but including here for reference
SUMMARY_SESSIONS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS summary_generation_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id TEXT NOT NULL,
    book_title TEXT NOT NULL,
    total_summaries_generated INTEGER NOT NULL DEFAULT 0,
    summary_style VARCHAR(50) NOT NULL,
    generation_metadata JSONB DEFAULT '{}',
    session_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_summary_sessions_book_id ON summary_generation_sessions(book_id);
CREATE INDEX IF NOT EXISTS idx_summary_sessions_timestamp ON summary_generation_sessions(session_timestamp DESC);
"""


# Utility functions for easy integration
async def store_chapter_summaries_simple(
    book_id: str,
    book_title: str, 
    summaries: List[ChapterSummary]
) -> str:
    """
    Simple function to store chapter summaries.
    
    Args:
        book_id: Unique identifier for the book
        book_title: Title of the book
        summaries: List of ChapterSummary objects
        
    Returns:
        session_id: Unique identifier for storage session
    """
    storage = SummaryStorageManager()
    try:
        return await storage.store_chapter_summaries(book_id, book_title, summaries)
    finally:
        await storage.close_connection_pool()


async def get_chapter_summary_simple(
    chapter_id: str, 
    summary_style: SummaryStyle = SummaryStyle.DETAILED
) -> Optional[Dict[str, Any]]:
    """
    Simple function to get a chapter summary.
    
    Args:
        chapter_id: The chapter identifier
        summary_style: Style of summary to retrieve
        
    Returns:
        Summary dictionary or None if not found
    """
    storage = SummaryStorageManager()
    try:
        return await storage.get_summary_by_chapter(chapter_id, summary_style)
    finally:
        await storage.close_connection_pool()


async def get_book_summaries_simple(
    book_id: str,
    summary_style: Optional[SummaryStyle] = None
) -> List[Dict[str, Any]]:
    """
    Simple function to get all summaries for a book.
    
    Args:
        book_id: The book identifier
        summary_style: Optional style filter
        
    Returns:
        List of summary dictionaries
    """
    storage = SummaryStorageManager()
    try:
        return await storage.get_book_summaries(book_id, summary_style)
    finally:
        await storage.close_connection_pool()