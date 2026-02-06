"""
Context Retriever Interfaces

Defines the contract for retrieving book context up to a given timestamp.
Implementations can be swapped (JSON files, database, RAG, hybrid).
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List


@dataclass
class ContextResult:
    """Result from context retrieval."""
    text: str                          # The actual book text
    token_estimate: int                # Rough token count for LLM budgeting
    chapters_included: List[int]       # Which chapters were included
    current_chapter: int               # The chapter user is currently in
    current_timestamp: float           # The timestamp user is at
    truncated: bool                    # Was context truncated due to size?
    retrieval_method: str              # "json", "database", "rag", "hybrid"


class IContextRetriever(ABC):
    """
    Interface for retrieving book context.

    Given a book ID, chapter number, and timestamp, returns all text
    from the book up to that point. This is the core of the spoiler
    prevention system - we only give the LLM text the user has heard.
    """

    @abstractmethod
    async def get_context(
        self,
        book_id: str,
        chapter: int,
        timestamp_seconds: float,
        max_tokens: int = 16000
    ) -> ContextResult:
        """
        Retrieve book context up to the given position.

        Args:
            book_id: Identifier for the book (folder name)
            chapter: Current chapter number (1-indexed)
            timestamp_seconds: Position within the chapter in seconds
            max_tokens: Maximum tokens to return (truncates oldest if exceeded)

        Returns:
            ContextResult with the text and metadata
        """
        pass

    @abstractmethod
    async def get_chapter_count(self, book_id: str) -> int:
        """Get the total number of chapters in a book."""
        pass

    @abstractmethod
    async def has_transcript(self, book_id: str) -> bool:
        """Check if a book has a transcript available."""
        pass
