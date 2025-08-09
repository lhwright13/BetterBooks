"""
Core data types for Smart Chapter Summaries system.

This module contains the essential data structures without external dependencies.
"""

from typing import List, Dict, Any, Optional
from datetime import datetime
from dataclasses import dataclass
from enum import Enum


class SummaryStyle(Enum):
    """Different summary styles available."""
    BRIEF = "brief"  # 1-2 sentences, key points only
    DETAILED = "detailed"  # 3-5 sentences, comprehensive overview
    THEMES = "themes"  # Focus on themes, symbols, character development
    KEY_POINTS = "key_points"  # Bullet point format with main events
    QUESTION_BASED = "question_based"  # Summary in Q&A format


@dataclass
class ChapterSummary:
    """Represents a generated chapter summary."""
    chapter_id: str
    chapter_number: int
    chapter_title: str
    summary_style: SummaryStyle
    summary_text: str
    key_points: List[str]
    themes: List[str]
    characters_mentioned: List[str]
    word_count: int
    confidence_score: float  # 0-1 confidence in summary quality
    generation_timestamp: datetime
    metadata: Dict[str, Any]


@dataclass
class SummaryRequest:
    """Request for generating chapter summaries."""
    book_id: str
    book_title: str
    chapter_ids: Optional[List[str]] = None  # None = all chapters
    summary_style: SummaryStyle = SummaryStyle.DETAILED
    include_themes: bool = True
    include_characters: bool = True
    max_summary_length: int = 500  # characters
    custom_prompt: Optional[str] = None