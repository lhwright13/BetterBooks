"""
Chapter Storage Integration

This module handles storing and retrieving AI-detected chapters in the database,
integrating with the Context Service and providing chapter-based embeddings.
"""

import json
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime

import psycopg
from psycopg.rows import dict_row

from ..database.database_manager import execute_query, database_connection
from .chapter_detection import DetectedChapter


class ChapterStorageManager:
    """Manages chapter storage and retrieval in the database."""
    
    async def store_detected_chapters(
        self,
        book_id: str,
        book_title: str,
        audio_file_path: str,
        chapters: List[DetectedChapter],
        detection_metadata: Dict[str, Any] = None
    ) -> str:
        """
        Store AI-detected chapters in the database.
        
        Args:
            book_id: Unique identifier for the book
            book_title: Title of the book
            audio_file_path: Path to the audio file
            chapters: List of detected chapters
            detection_metadata: Additional metadata about the detection process
            
        Returns:
            Detection session ID for tracking
        """
        detection_id = f"detection_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{book_id}"
        
        async with database_connection() as conn:
            # Begin transaction
            async with conn.transaction():
                # Store book record if it doesn't exist
                await conn.execute("""
                    INSERT INTO books (id, title, audio_file_path, created_at, updated_at, is_active)
                    VALUES (%s, %s, %s, NOW(), NOW(), true)
                    ON CONFLICT (id) DO UPDATE SET
                        title = EXCLUDED.title,
                        audio_file_path = EXCLUDED.audio_file_path,
                        updated_at = NOW()
                """, (book_id, book_title, audio_file_path))
                
                # Store chapter detection session
                detection_meta = detection_metadata or {}
                detection_meta.update({
                    'total_chapters': len(chapters),
                    'detection_timestamp': datetime.now().isoformat(),
                    'audio_file_path': audio_file_path
                })
                
                await conn.execute("""
                    INSERT INTO chapter_detection_sessions (
                        id, book_id, detection_timestamp, total_chapters_detected,
                        metadata, created_at
                    ) VALUES (%s, %s, NOW(), %s, %s, NOW())
                """, (detection_id, book_id, len(chapters), json.dumps(detection_meta)))
                
                # Store individual chapters
                for chapter in chapters:
                    # Calculate duration in seconds
                    duration_seconds = int(chapter.duration)
                    
                    await conn.execute("""
                        INSERT INTO book_chapters (
                            id, book_id, chapter_number, title, start_time_seconds, 
                            end_time_seconds, transcript, summary, created_at, updated_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
                        ON CONFLICT (book_id, chapter_number) DO UPDATE SET
                            title = EXCLUDED.title,
                            start_time_seconds = EXCLUDED.start_time_seconds,
                            end_time_seconds = EXCLUDED.end_time_seconds,
                            transcript = EXCLUDED.transcript,
                            summary = EXCLUDED.summary,
                            updated_at = NOW()
                    """, (
                        f"{book_id}_chapter_{chapter.chapter_number}",
                        book_id,
                        chapter.chapter_number,
                        chapter.title,
                        int(chapter.start_time),
                        int(chapter.end_time),
                        "",  # Transcript would be filled separately
                        chapter.summary
                    ))
                    
                    # Store chapter metadata (topics, confidence, etc.)
                    chapter_metadata = {
                        'confidence': chapter.confidence,
                        'key_topics': chapter.key_topics,
                        'word_count': chapter.word_count,
                        'speaker_changes': chapter.speaker_changes,
                        'duration': chapter.duration
                    }
                    
                    await conn.execute("""
                        INSERT INTO chapter_metadata (
                            chapter_id, metadata, created_at
                        ) VALUES (%s, %s, NOW())
                        ON CONFLICT (chapter_id) DO UPDATE SET
                            metadata = EXCLUDED.metadata,
                            updated_at = NOW()
                    """, (
                        f"{book_id}_chapter_{chapter.chapter_number}",
                        json.dumps(chapter_metadata)
                    ))
        
        return detection_id
    
    async def get_book_chapters(
        self, 
        book_id: str, 
        include_metadata: bool = False
    ) -> List[Dict[str, Any]]:
        """
        Retrieve chapters for a book from the database.
        
        Args:
            book_id: Unique identifier for the book
            include_metadata: Whether to include chapter metadata
            
        Returns:
            List of chapter data
        """
        base_query = """
            SELECT 
                bc.id,
                bc.chapter_number,
                bc.title,
                bc.start_time_seconds,
                bc.end_time_seconds,
                bc.summary,
                bc.created_at,
                bc.updated_at
        """
        
        if include_metadata:
            base_query += """
                , cm.metadata
            FROM book_chapters bc
            LEFT JOIN chapter_metadata cm ON bc.id = cm.chapter_id
            """
        else:
            base_query += """
            FROM book_chapters bc
            """
        
        base_query += """
            WHERE bc.book_id = %s
            ORDER BY bc.chapter_number
        """
        
        result = await execute_query(base_query, (book_id,))
        
        chapters = []
        for row in result:
            chapter_data = {
                'id': row['id'],
                'chapter_number': row['chapter_number'],
                'title': row['title'],
                'start_time': row['start_time_seconds'],
                'end_time': row['end_time_seconds'],
                'duration': row['end_time_seconds'] - row['start_time_seconds'],
                'summary': row['summary'],
                'created_at': row['created_at'].isoformat() if row['created_at'] else None,
                'updated_at': row['updated_at'].isoformat() if row['updated_at'] else None
            }
            
            if include_metadata and 'metadata' in row and row['metadata']:
                metadata = json.loads(row['metadata']) if isinstance(row['metadata'], str) else row['metadata']
                chapter_data.update({
                    'confidence': metadata.get('confidence', 0.0),
                    'key_topics': metadata.get('key_topics', []),
                    'word_count': metadata.get('word_count', 0),
                    'speaker_changes': metadata.get('speaker_changes', 0)
                })
            
            chapters.append(chapter_data)
        
        return chapters
    
    async def get_chapter_by_timestamp(
        self, 
        book_id: str, 
        timestamp: float
    ) -> Optional[Dict[str, Any]]:
        """
        Find the chapter that contains a specific timestamp.
        
        Args:
            book_id: Unique identifier for the book
            timestamp: Time in seconds
            
        Returns:
            Chapter data if found, None otherwise
        """
        result = await execute_query("""
            SELECT 
                bc.id,
                bc.chapter_number,
                bc.title,
                bc.start_time_seconds,
                bc.end_time_seconds,
                bc.summary,
                cm.metadata
            FROM book_chapters bc
            LEFT JOIN chapter_metadata cm ON bc.id = cm.chapter_id
            WHERE bc.book_id = %s 
                AND bc.start_time_seconds <= %s 
                AND bc.end_time_seconds >= %s
            ORDER BY bc.chapter_number
            LIMIT 1
        """, (book_id, timestamp, timestamp))
        
        if not result:
            return None
        
        row = result[0]
        chapter_data = {
            'id': row['id'],
            'chapter_number': row['chapter_number'],
            'title': row['title'],
            'start_time': row['start_time_seconds'],
            'end_time': row['end_time_seconds'],
            'duration': row['end_time_seconds'] - row['start_time_seconds'],
            'summary': row['summary']
        }
        
        if row['metadata']:
            metadata = json.loads(row['metadata']) if isinstance(row['metadata'], str) else row['metadata']
            chapter_data.update({
                'confidence': metadata.get('confidence', 0.0),
                'key_topics': metadata.get('key_topics', []),
                'word_count': metadata.get('word_count', 0),
                'speaker_changes': metadata.get('speaker_changes', 0)
            })
        
        return chapter_data
    
    async def update_chapter_embeddings(
        self, 
        book_id: str, 
        chapter_embeddings: Dict[int, List[float]]
    ):
        """
        Store embeddings for chapters to enable semantic search.
        
        Args:
            book_id: Unique identifier for the book
            chapter_embeddings: Dict mapping chapter numbers to embedding vectors
        """
        async with database_connection() as conn:
            for chapter_number, embedding in chapter_embeddings.items():
                chapter_id = f"{book_id}_chapter_{chapter_number}"
                
                # Store chapter embedding
                await conn.execute("""
                    INSERT INTO embeddings (
                        id, embedding, book_id, chapter_id, content_type, 
                        metadata, created_at, updated_at
                    ) VALUES (%s, %s, %s, %s, %s, %s, NOW(), NOW())
                    ON CONFLICT (id) DO UPDATE SET
                        embedding = EXCLUDED.embedding,
                        updated_at = NOW()
                """, (
                    f"chapter_embedding_{chapter_id}",
                    embedding,
                    book_id,
                    chapter_id,
                    "chapter_summary",
                    json.dumps({
                        'chapter_number': chapter_number,
                        'embedding_type': 'chapter_summary',
                        'book_id': book_id
                    })
                ))
    
    async def search_chapters_by_content(
        self, 
        query_embedding: List[float], 
        book_id: Optional[str] = None,
        limit: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Search chapters by semantic similarity to a query embedding.
        
        Args:
            query_embedding: Query vector for similarity search
            book_id: Optional book ID to limit search
            limit: Maximum number of results
            
        Returns:
            List of similar chapters with similarity scores
        """
        base_query = """
            SELECT 
                e.book_id,
                e.chapter_id,
                e.metadata,
                bc.chapter_number,
                bc.title,
                bc.start_time_seconds,
                bc.end_time_seconds,
                bc.summary,
                (1 - (e.embedding <-> %s::vector)) as similarity
            FROM embeddings e
            JOIN book_chapters bc ON e.chapter_id = bc.id
            WHERE e.content_type = 'chapter_summary'
        """
        
        params = [query_embedding]
        
        if book_id:
            base_query += " AND e.book_id = %s"
            params.append(book_id)
        
        base_query += """
            ORDER BY e.embedding <-> %s::vector
            LIMIT %s
        """
        params.extend([query_embedding, limit])
        
        result = await execute_query(base_query, tuple(params))
        
        chapters = []
        for row in result:
            metadata = json.loads(row['metadata']) if isinstance(row['metadata'], str) else row['metadata']
            
            chapters.append({
                'book_id': row['book_id'],
                'chapter_id': row['chapter_id'],
                'chapter_number': row['chapter_number'],
                'title': row['title'],
                'start_time': row['start_time_seconds'],
                'end_time': row['end_time_seconds'],
                'summary': row['summary'],
                'similarity': float(row['similarity']),
                'metadata': metadata
            })
        
        return chapters
    
    async def get_detection_history(
        self, 
        book_id: str
    ) -> List[Dict[str, Any]]:
        """
        Get chapter detection history for a book.
        
        Args:
            book_id: Unique identifier for the book
            
        Returns:
            List of detection sessions
        """
        result = await execute_query("""
            SELECT 
                id,
                detection_timestamp,
                total_chapters_detected,
                metadata,
                created_at
            FROM chapter_detection_sessions
            WHERE book_id = %s
            ORDER BY detection_timestamp DESC
        """, (book_id,))
        
        sessions = []
        for row in result:
            metadata = json.loads(row['metadata']) if isinstance(row['metadata'], str) else row['metadata']
            
            sessions.append({
                'detection_id': row['id'],
                'timestamp': row['detection_timestamp'].isoformat() if row['detection_timestamp'] else None,
                'total_chapters': row['total_chapters_detected'],
                'metadata': metadata,
                'created_at': row['created_at'].isoformat() if row['created_at'] else None
            })
        
        return sessions
    
    async def cleanup_old_detections(
        self, 
        book_id: str, 
        keep_latest: int = 3
    ):
        """
        Clean up old chapter detection results, keeping only the latest N.
        
        Args:
            book_id: Unique identifier for the book
            keep_latest: Number of latest detections to keep
        """
        # Get detection sessions to remove
        result = await execute_query("""
            SELECT id
            FROM chapter_detection_sessions
            WHERE book_id = %s
            ORDER BY detection_timestamp DESC
            OFFSET %s
        """, (book_id, keep_latest))
        
        if result:
            session_ids = [row['id'] for row in result]
            
            async with database_connection() as conn:
                # Remove old detection sessions
                await conn.execute("""
                    DELETE FROM chapter_detection_sessions
                    WHERE id = ANY(%s)
                """, (session_ids,))


# Utility functions for integration
async def store_book_chapters(
    book_id: str,
    book_title: str,
    audio_file_path: str,
    detected_chapters: List[DetectedChapter],
    detection_metadata: Dict[str, Any] = None
) -> str:
    """
    Convenience function to store detected chapters.
    
    Args:
        book_id: Unique identifier for the book
        book_title: Title of the book
        audio_file_path: Path to the audio file
        detected_chapters: List of AI-detected chapters
        detection_metadata: Additional detection metadata
        
    Returns:
        Detection session ID
    """
    storage_manager = ChapterStorageManager()
    return await storage_manager.store_detected_chapters(
        book_id, book_title, audio_file_path, detected_chapters, detection_metadata
    )


async def get_current_chapter(
    book_id: str, 
    timestamp: float
) -> Optional[Dict[str, Any]]:
    """
    Get the current chapter for a given timestamp.
    
    Args:
        book_id: Unique identifier for the book
        timestamp: Current playback time in seconds
        
    Returns:
        Current chapter data or None
    """
    storage_manager = ChapterStorageManager()
    return await storage_manager.get_chapter_by_timestamp(book_id, timestamp)


async def search_chapters(
    query: str,
    book_id: Optional[str] = None,
    limit: int = 5
) -> List[Dict[str, Any]]:
    """
    Search chapters by text query (would need embedding generation).
    
    Args:
        query: Text query to search for
        book_id: Optional book ID to limit search
        limit: Maximum number of results
        
    Returns:
        List of matching chapters
    """
    # This would require generating embeddings for the query
    # For now, return empty list as placeholder
    return []


def format_chapter_navigation(chapters: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Format chapters for navigation UI.
    
    Args:
        chapters: List of chapter data
        
    Returns:
        Navigation-friendly chapter structure
    """
    if not chapters:
        return {"total_chapters": 0, "chapters": []}
    
    navigation_chapters = []
    total_duration = 0
    
    for chapter in chapters:
        duration = chapter.get('duration', 0)
        total_duration += duration
        
        # Format time for display
        start_mins = int(chapter.get('start_time', 0) // 60)
        start_secs = int(chapter.get('start_time', 0) % 60)
        
        navigation_chapters.append({
            'chapter_number': chapter.get('chapter_number'),
            'title': chapter.get('title'),
            'start_time': chapter.get('start_time'),
            'duration': duration,
            'formatted_start': f"{start_mins:02d}:{start_secs:02d}",
            'formatted_duration': f"{int(duration // 60):02d}:{int(duration % 60):02d}",
            'summary': chapter.get('summary', ''),
            'key_topics': chapter.get('key_topics', [])[:3]  # Limit to 3 topics
        })
    
    return {
        'total_chapters': len(chapters),
        'total_duration': total_duration,
        'formatted_total_duration': f"{int(total_duration // 3600)}:{int((total_duration % 3600) // 60):02d}:{int(total_duration % 60):02d}",
        'chapters': navigation_chapters
    }