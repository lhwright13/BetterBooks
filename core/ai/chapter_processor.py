"""
Simple Chapter Processor for Pre-Chaptered Books

This module handles loading and processing chapters from the book_files directory
structure where books are already divided into chapter audio files.

No AI-powered chapter detection needed - just reads existing chapter files.
"""

import os
import re
import json
from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path
from dataclasses import dataclass
from datetime import datetime

# Audio duration estimation without heavy dependencies


@dataclass
class ChapterInfo:
    """Information about a chapter from pre-chaptered book."""
    chapter_number: int
    title: str
    audio_file_path: str
    duration_seconds: float
    file_size_bytes: int
    exists: bool


@dataclass
class BookChapters:
    """Collection of chapters for a book."""
    book_title: str
    book_path: str
    total_chapters: int
    chapters: List[ChapterInfo]
    total_duration_seconds: float
    last_updated: datetime


class ChapterProcessor:
    """Simple processor for pre-chaptered audiobooks."""
    
    def __init__(self, book_files_root: str = "book_files"):
        """
        Initialize chapter processor.
        
        Args:
            book_files_root: Root directory containing book folders
        """
        self.book_files_root = Path(book_files_root)
        
    def discover_books(self) -> List[str]:
        """
        Discover all available books in the book_files directory.
        
        Returns:
            List of book directory names
        """
        if not self.book_files_root.exists():
            return []
        
        books = []
        for item in self.book_files_root.iterdir():
            if item.is_dir():
                # Check if directory contains audio files
                audio_files = self._find_audio_files(item)
                if audio_files:
                    books.append(item.name)
        
        return sorted(books)
    
    def load_book_chapters(self, book_title: str) -> Optional[BookChapters]:
        """
        Load all chapters for a book.
        
        Args:
            book_title: Name of the book directory
            
        Returns:
            BookChapters object or None if book not found
        """
        book_path = self.book_files_root / book_title
        
        if not book_path.exists() or not book_path.is_dir():
            return None
        
        # Find all audio files
        audio_files = self._find_audio_files(book_path)
        
        if not audio_files:
            return None
        
        # Extract chapter information
        chapters = []
        total_duration = 0.0
        
        for audio_file in sorted(audio_files):
            chapter_info = self._extract_chapter_info(audio_file, book_path)
            if chapter_info:
                chapters.append(chapter_info)
                total_duration += chapter_info.duration_seconds
        
        return BookChapters(
            book_title=book_title,
            book_path=str(book_path),
            total_chapters=len(chapters),
            chapters=chapters,
            total_duration_seconds=total_duration,
            last_updated=datetime.now()
        )
    
    def get_chapter_text(self, chapter_info: ChapterInfo, transcript_source: str = "auto") -> str:
        """
        Get text content for a chapter.
        
        Args:
            chapter_info: Chapter information
            transcript_source: Source for transcript ('auto', 'file', 'extract')
            
        Returns:
            Chapter text content
        """
        chapter_dir = Path(chapter_info.audio_file_path).parent
        
        # Look for existing transcript files
        transcript_files = [
            chapter_dir / f"{Path(chapter_info.audio_file_path).stem}.txt",
            chapter_dir / f"{Path(chapter_info.audio_file_path).stem}.transcript",
            chapter_dir / f"Chapter {chapter_info.chapter_number}.txt",
            chapter_dir / f"chapter_{chapter_info.chapter_number}.txt"
        ]
        
        for transcript_file in transcript_files:
            if transcript_file.exists():
                try:
                    with open(transcript_file, 'r', encoding='utf-8') as f:
                        return f.read().strip()
                except Exception as e:
                    print(f"Error reading transcript file {transcript_file}: {e}")
        
        # If no transcript file found, return placeholder
        return f"Chapter {chapter_info.chapter_number}: {chapter_info.title}\n\n[Transcript not available. Duration: {chapter_info.duration_seconds:.1f} seconds]"
    
    def _find_audio_files(self, directory: Path) -> List[Path]:
        """Find all audio files in a directory."""
        audio_extensions = {'.mp3', '.wav', '.m4a', '.flac', '.ogg', '.aac'}
        
        audio_files = []
        for file_path in directory.iterdir():
            if file_path.is_file() and file_path.suffix.lower() in audio_extensions:
                audio_files.append(file_path)
        
        return audio_files
    
    def _extract_chapter_info(self, audio_file: Path, book_path: Path) -> Optional[ChapterInfo]:
        """Extract chapter information from audio file."""
        try:
            # Extract chapter number from filename
            chapter_number = self._extract_chapter_number(audio_file.name)
            
            # Generate chapter title from filename
            title = self._generate_chapter_title(audio_file.name, chapter_number)
            
            # Get file size
            file_size = audio_file.stat().st_size
            
            # Estimate audio duration from file size (lightweight approach)
            # Assume 128kbps MP3: ~1MB per minute
            duration = file_size / (128 * 1024 / 8) * 60 if file_size > 0 else 0.0
            
            return ChapterInfo(
                chapter_number=chapter_number,
                title=title,
                audio_file_path=str(audio_file),
                duration_seconds=duration,
                file_size_bytes=file_size,
                exists=True
            )
            
        except Exception as e:
            print(f"Error processing audio file {audio_file}: {e}")
            return None
    
    def _extract_chapter_number(self, filename: str) -> int:
        """Extract chapter number from filename."""
        # Common patterns for chapter numbers
        patterns = [
            r'[Cc]hapter\s*(\d+)',  # "Chapter 1", "chapter 01"
            r'[Cc]h\s*(\d+)',       # "Ch 1", "ch01"
            r'^(\d+)',              # "1.mp3", "01.mp3"
            r'(\d+)',               # Any number in filename
        ]
        
        for pattern in patterns:
            match = re.search(pattern, filename)
            if match:
                return int(match.group(1))
        
        # Fallback: return 1 if no number found
        return 1
    
    def _generate_chapter_title(self, filename: str, chapter_number: int) -> str:
        """Generate a chapter title from filename."""
        # Remove file extension
        name = Path(filename).stem
        
        # Clean up the name
        # Remove common prefixes
        name = re.sub(r'^[Cc]hapter\s*\d+\s*[-_:\s]*', '', name)
        name = re.sub(r'^[Cc]h\s*\d+\s*[-_:\s]*', '', name)
        name = re.sub(r'^\d+\s*[-_:\s]*', '', name)
        
        # Replace underscores and dashes with spaces
        name = re.sub(r'[-_]+', ' ', name)
        
        # Capitalize words
        name = ' '.join(word.capitalize() for word in name.split())
        
        # If name is empty or just numbers, use generic title
        if not name or name.isdigit():
            name = f"Chapter {chapter_number}"
        else:
            # Ensure it starts with "Chapter X: "
            if not name.startswith(f"Chapter {chapter_number}"):
                name = f"Chapter {chapter_number}: {name}"
        
        return name


def format_duration(seconds: float) -> str:
    """Format duration in seconds to human-readable format."""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    else:
        return f"{minutes:02d}:{secs:02d}"


def get_book_metadata(book_chapters: BookChapters) -> Dict[str, Any]:
    """
    Generate metadata summary for a book.
    
    Args:
        book_chapters: BookChapters object
        
    Returns:
        Dictionary with book metadata
    """
    return {
        "title": book_chapters.book_title,
        "total_chapters": book_chapters.total_chapters,
        "total_duration": book_chapters.total_duration_seconds,
        "formatted_duration": format_duration(book_chapters.total_duration_seconds),
        "chapters": [
            {
                "number": ch.chapter_number,
                "title": ch.title,
                "duration": ch.duration_seconds,
                "formatted_duration": format_duration(ch.duration_seconds),
                "file_size_mb": ch.file_size_bytes / (1024 * 1024),
                "exists": ch.exists
            }
            for ch in book_chapters.chapters
        ],
        "last_updated": book_chapters.last_updated.isoformat()
    }


# Convenience functions
def load_book(book_title: str, book_files_root: str = "book_files") -> Optional[BookChapters]:
    """
    Simple function to load a book's chapters.
    
    Args:
        book_title: Name of the book
        book_files_root: Root directory for book files
        
    Returns:
        BookChapters object or None if not found
    """
    processor = ChapterProcessor(book_files_root)
    return processor.load_book_chapters(book_title)


def get_available_books(book_files_root: str = "book_files") -> List[str]:
    """
    Get list of available books.
    
    Args:
        book_files_root: Root directory for book files
        
    Returns:
        List of book titles
    """
    processor = ChapterProcessor(book_files_root)
    return processor.discover_books()


def get_chapter_content(
    book_title: str, 
    chapter_number: int,
    book_files_root: str = "book_files"
) -> Tuple[Optional[ChapterInfo], str]:
    """
    Get chapter information and text content.
    
    Args:
        book_title: Name of the book
        chapter_number: Chapter number to retrieve
        book_files_root: Root directory for book files
        
    Returns:
        Tuple of (ChapterInfo, text_content) or (None, empty_string)
    """
    processor = ChapterProcessor(book_files_root)
    book_chapters = processor.load_book_chapters(book_title)
    
    if not book_chapters:
        return None, ""
    
    # Find the requested chapter
    for chapter in book_chapters.chapters:
        if chapter.chapter_number == chapter_number:
            text_content = processor.get_chapter_text(chapter)
            return chapter, text_content
    
    return None, ""