"""
Simplified AI-Powered Features for Pre-Chaptered Books

Contains AI functionality for BetterBooks using Azure OpenAI:
- Chapter processing for pre-divided audiobooks
- Smart chapter summaries with multiple styles
- Educational question generation
- Azure OpenAI integration with cost tracking
"""

# Core Azure integration
from .azure_llm_client import AzureLLMClient, LLMResponse, LLMConfig, generate_text, generate_json_response

# Chapter processing
from .chapter_processor import (
    ChapterProcessor, ChapterInfo, BookChapters,
    load_book, get_available_books, get_chapter_content
)

# Summary generation
from .summary_generator import (
    SummaryGenerator, ChapterSummary, SummaryStyle,
    generate_chapter_summary, generate_all_summaries
)

# Question generation
from .simple_question_generator import (
    SimpleQuestionGenerator, GeneratedQuestion, QuestionSet,
    QuestionDifficulty, QuestionType, ReadingMode,
    generate_chapter_questions
)

# Legacy compatibility (keeping SummaryStyle for existing code)
from .summary_types import SummaryStyle as LegacySummaryStyle

__all__ = [
    # Azure OpenAI client
    'AzureLLMClient',
    'LLMResponse', 
    'LLMConfig',
    'generate_text',
    'generate_json_response',
    
    # Chapter processing
    'ChapterProcessor',
    'ChapterInfo',
    'BookChapters',
    'load_book',
    'get_available_books',
    'get_chapter_content',
    
    # Summary generation
    'SummaryGenerator',
    'ChapterSummary',
    'SummaryStyle',
    'generate_chapter_summary',
    'generate_all_summaries',
    
    # Question generation
    'SimpleQuestionGenerator',
    'GeneratedQuestion',
    'QuestionSet',
    'QuestionDifficulty',
    'QuestionType',
    'ReadingMode',
    'generate_chapter_questions',
    
    # Legacy compatibility
    'LegacySummaryStyle'
]