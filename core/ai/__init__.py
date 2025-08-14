"""
AI-Powered Features Module

Contains all AI functionality for the EchoWright platform:
- Chapter detection and boundary analysis
- Smart chapter summaries with multiple styles
- Educational question generation
- Character and theme extraction
- Content analysis and metadata generation
"""

from .chapter_detection import ChapterDetectionEngine, DetectedChapter
from .chapter_summaries import ChapterSummaryGenerator
from .question_generation import QuestionGenerator  
from .summary_types import SummaryStyle
from .question_generation import QuestionType, ReadingMode

__all__ = [
    'ChapterDetectionEngine',
    'DetectedChapter',
    'ChapterSummaryGenerator',
    'QuestionGenerator',
    'SummaryStyle', 
    'QuestionType',
    'ReadingMode'
]