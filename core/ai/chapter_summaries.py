"""
Smart Chapter Summaries System

This module provides AI-powered chapter summarization with multiple styles and formats.
Integrates with the chapter detection system to automatically generate summaries.
"""

import os
import re
import json
import asyncio
from typing import List, Dict, Any, Optional, Union
from datetime import datetime
from dataclasses import dataclass
from enum import Enum

import aiohttp
from chapter_detection import DetectedChapter


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


class ChapterSummaryGenerator:
    """AI-powered chapter summary generation system."""
    
    def __init__(self, llm_gateway_url: str = "http://llm_gateway:8000"):
        self.llm_gateway_url = llm_gateway_url
        
        # Summary style configurations
        self.style_configs = {
            SummaryStyle.BRIEF: {
                "max_sentences": 2,
                "focus": "main events and outcomes",
                "length_target": 100
            },
            SummaryStyle.DETAILED: {
                "max_sentences": 5,
                "focus": "comprehensive overview with context",
                "length_target": 300
            },
            SummaryStyle.THEMES: {
                "max_sentences": 4,
                "focus": "themes, symbols, and character development",
                "length_target": 250
            },
            SummaryStyle.KEY_POINTS: {
                "max_sentences": 6,
                "focus": "bullet points of main events",
                "length_target": 200
            },
            SummaryStyle.QUESTION_BASED: {
                "max_sentences": 4,
                "focus": "Q&A format covering main points",
                "length_target": 300
            }
        }

    async def generate_chapter_summary(
        self,
        chapter: DetectedChapter,
        chapter_text: str,
        summary_style: SummaryStyle = SummaryStyle.DETAILED,
        book_context: Optional[str] = None
    ) -> ChapterSummary:
        """
        Generate a summary for a single chapter.
        
        Args:
            chapter: DetectedChapter object with metadata
            chapter_text: Full text content of the chapter
            summary_style: Style of summary to generate
            book_context: Optional context about the book
            
        Returns:
            ChapterSummary with generated content
        """
        print(f"📝 Generating {summary_style.value} summary for Chapter {chapter.chapter_number}: {chapter.title}")
        
        # Get style configuration
        style_config = self.style_configs[summary_style]
        
        # Generate the summary text
        summary_text = await self._generate_summary_text(
            chapter_text, 
            summary_style, 
            style_config,
            book_context
        )
        
        # Extract key points and themes
        key_points = await self._extract_key_points(chapter_text, summary_text)
        themes = await self._extract_themes(chapter_text) if summary_style in [SummaryStyle.THEMES, SummaryStyle.DETAILED] else []
        characters = await self._extract_characters(chapter_text)
        
        # Calculate confidence score
        confidence_score = self._calculate_confidence_score(
            chapter_text, summary_text, style_config
        )
        
        return ChapterSummary(
            chapter_id=f"chapter_{chapter.chapter_number}",
            chapter_number=chapter.chapter_number,
            chapter_title=chapter.title,
            summary_style=summary_style,
            summary_text=summary_text,
            key_points=key_points,
            themes=themes,
            characters_mentioned=characters,
            word_count=len(summary_text.split()),
            confidence_score=confidence_score,
            generation_timestamp=datetime.now(),
            metadata={
                "original_word_count": len(chapter_text.split()),
                "compression_ratio": len(summary_text) / len(chapter_text),
                "style_config": style_config,
                "llm_model": "gemini-pro"
            }
        )

    async def generate_book_summaries(
        self,
        request: SummaryRequest,
        chapters: List[DetectedChapter],
        chapter_texts: Dict[str, str]
    ) -> List[ChapterSummary]:
        """
        Generate summaries for multiple chapters of a book.
        
        Args:
            request: Summary generation request
            chapters: List of detected chapters
            chapter_texts: Mapping of chapter_id to text content
            
        Returns:
            List of generated summaries
        """
        print(f"📚 Generating {request.summary_style.value} summaries for {len(chapters)} chapters")
        
        # Filter chapters if specific ones requested
        if request.chapter_ids:
            chapters = [c for c in chapters if f"chapter_{c.chapter_number}" in request.chapter_ids]
        
        # Generate book context for better summaries
        book_context = await self._generate_book_context(request.book_title, chapters)
        
        # Generate summaries for each chapter
        summaries = []
        for chapter in chapters:
            chapter_id = f"chapter_{chapter.chapter_number}"
            if chapter_id in chapter_texts:
                try:
                    summary = await self.generate_chapter_summary(
                        chapter=chapter,
                        chapter_text=chapter_texts[chapter_id],
                        summary_style=request.summary_style,
                        book_context=book_context
                    )
                    summaries.append(summary)
                except Exception as e:
                    print(f"❌ Failed to generate summary for {chapter_id}: {e}")
                    continue
        
        print(f"✅ Generated {len(summaries)} summaries successfully")
        return summaries

    async def _generate_summary_text(
        self,
        chapter_text: str,
        style: SummaryStyle,
        style_config: Dict[str, Any],
        book_context: Optional[str] = None
    ) -> str:
        """Generate summary text using LLM based on style."""
        
        # Truncate very long chapters for processing
        if len(chapter_text) > 3000:
            chapter_text = chapter_text[:3000] + "..."
        
        # Build style-specific prompt
        style_prompts = {
            SummaryStyle.BRIEF: f"Write a brief {style_config['max_sentences']}-sentence summary focusing on {style_config['focus']}.",
            SummaryStyle.DETAILED: f"Write a detailed {style_config['max_sentences']}-sentence summary that provides {style_config['focus']}.",
            SummaryStyle.THEMES: f"Write a {style_config['max_sentences']}-sentence summary focusing on {style_config['focus']}.",
            SummaryStyle.KEY_POINTS: f"Create a bullet-point summary with {style_config['max_sentences']} key points covering {style_config['focus']}.",
            SummaryStyle.QUESTION_BASED: f"Create a {style_config['max_sentences']}-question Q&A summary covering {style_config['focus']}."
        }
        
        context_addition = f"\n\nBook Context: {book_context}" if book_context else ""
        
        prompt = f"""Analyze this audiobook chapter and create a high-quality summary.

Chapter Content:
{chapter_text}
{context_addition}

Instructions:
{style_prompts[style]}

Target length: ~{style_config['length_target']} characters
Focus: {style_config['focus']}

Requirements:
- Be accurate to the source material
- Maintain narrative flow and coherence
- Include specific details and events
- Avoid spoilers for future chapters
- Write in clear, engaging prose

Summary:"""

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.llm_gateway_url}/complete",
                    json={
                        "prompt": prompt,
                        "max_tokens": 400,
                        "temperature": 0.3
                    },
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        summary = result.get("response", "").strip()
                        
                        # Clean up the summary
                        summary = self._clean_summary_text(summary, style)
                        return summary
                    else:
                        print(f"LLM request failed with status {response.status}")
                        return self._generate_fallback_summary(chapter_text, style)
                        
        except Exception as e:
            print(f"Error generating summary: {e}")
            return self._generate_fallback_summary(chapter_text, style)

    async def _extract_key_points(self, chapter_text: str, summary_text: str) -> List[str]:
        """Extract key points from the chapter using LLM."""
        prompt = f"""Based on this chapter content and its summary, extract 3-5 key points or events.

Chapter Summary: {summary_text}

Chapter Content (first 1000 chars): {chapter_text[:1000]}

Extract the most important events, decisions, or revelations. Format as a simple list:
1. [First key point]
2. [Second key point]
3. [Third key point]

Key Points:"""

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.llm_gateway_url}/complete",
                    json={
                        "prompt": prompt,
                        "max_tokens": 200,
                        "temperature": 0.2
                    },
                    timeout=aiohttp.ClientTimeout(total=15)
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        response_text = result.get("response", "").strip()
                        
                        # Parse numbered list into array
                        points = []
                        for line in response_text.split('\n'):
                            line = line.strip()
                            if line and (line[0].isdigit() or line.startswith('•') or line.startswith('-')):
                                # Remove numbering and clean
                                point = re.sub(r'^[\d\.\)\-\•\*]\s*', '', line).strip()
                                if point:
                                    points.append(point)
                        
                        return points[:5]  # Limit to 5 points
        except Exception as e:
            print(f"Error extracting key points: {e}")
        
        # Fallback: extract from summary
        sentences = summary_text.split('.')
        return [s.strip() + '.' for s in sentences[:3] if s.strip()]

    async def _extract_themes(self, chapter_text: str) -> List[str]:
        """Extract themes and literary elements from the chapter."""
        prompt = f"""Analyze this chapter for major themes, symbols, or literary elements.

Chapter Content (first 1500 chars): {chapter_text[:1500]}

Identify 2-4 major themes present in this chapter. Focus on:
- Character development
- Relationships and conflicts
- Symbolic elements
- Emotional or psychological themes
- Social or cultural themes

Format as a simple list:
- [Theme 1]
- [Theme 2]
- [Theme 3]

Themes:"""

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.llm_gateway_url}/complete",
                    json={
                        "prompt": prompt,
                        "max_tokens": 150,
                        "temperature": 0.4
                    },
                    timeout=aiohttp.ClientTimeout(total=15)
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        response_text = result.get("response", "").strip()
                        
                        # Parse list into array
                        themes = []
                        for line in response_text.split('\n'):
                            line = line.strip()
                            if line and (line.startswith('-') or line.startswith('•')):
                                theme = line[1:].strip()
                                if theme:
                                    themes.append(theme)
                        
                        return themes[:4]  # Limit to 4 themes
        except Exception as e:
            print(f"Error extracting themes: {e}")
        
        return []

    async def _extract_characters(self, chapter_text: str) -> List[str]:
        """Extract mentioned characters from the chapter."""
        # Simple character extraction - look for capitalized names
        # This could be enhanced with NER (Named Entity Recognition)
        
        words = chapter_text.split()
        potential_names = []
        
        for word in words:
            # Look for capitalized words that might be names
            clean_word = re.sub(r'[^\w]', '', word)
            if (clean_word and clean_word[0].isupper() and 
                len(clean_word) > 2 and clean_word.lower() not in 
                ['the', 'and', 'but', 'or', 'chapter', 'he', 'she', 'it', 'they']):
                potential_names.append(clean_word)
        
        # Get most frequent capitalized words (likely names)
        from collections import Counter
        name_counts = Counter(potential_names)
        
        # Return top 5 most mentioned names
        return [name for name, count in name_counts.most_common(5) if count > 1]

    async def _generate_book_context(self, book_title: str, chapters: List[DetectedChapter]) -> str:
        """Generate contextual information about the book for better summaries."""
        chapter_titles = [f"Chapter {c.chapter_number}: {c.title}" for c in chapters[:5]]
        
        context = f"Book: {book_title}\n"
        context += f"Total Chapters: {len(chapters)}\n"
        context += f"Sample Chapter Titles: {', '.join(chapter_titles)}"
        
        return context

    def _clean_summary_text(self, summary: str, style: SummaryStyle) -> str:
        """Clean and format the generated summary text."""
        # Remove common AI response prefixes
        prefixes = ["Here is", "Here's", "The summary is", "Summary:", "Chapter Summary:"]
        for prefix in prefixes:
            if summary.lower().startswith(prefix.lower()):
                summary = summary[len(prefix):].strip()
        
        # Handle different formatting for different styles
        if style == SummaryStyle.KEY_POINTS:
            # Ensure bullet point format
            lines = summary.split('\n')
            formatted_lines = []
            for line in lines:
                line = line.strip()
                if line and not line.startswith('•') and not line.startswith('-'):
                    line = f"• {line}"
                if line:
                    formatted_lines.append(line)
            summary = '\n'.join(formatted_lines)
        
        return summary.strip()

    def _generate_fallback_summary(self, chapter_text: str, style: SummaryStyle) -> str:
        """Generate a basic fallback summary if LLM fails."""
        words = chapter_text.split()
        
        if style == SummaryStyle.BRIEF:
            return f"This chapter contains {len(words)} words and covers key story developments."
        elif style == SummaryStyle.KEY_POINTS:
            return "• Chapter content covers important story elements\n• Character development and plot progression\n• Key events and dialogue"
        else:
            return f"This chapter contains approximately {len(words)} words and represents an important part of the story's development."

    def _calculate_confidence_score(
        self, 
        original_text: str, 
        summary: str, 
        style_config: Dict[str, Any]
    ) -> float:
        """Calculate confidence score for the generated summary."""
        if not summary or len(summary) < 20:
            return 0.1
        
        # Factors for confidence calculation
        factors = []
        
        # Length appropriateness (compared to target)
        target_length = style_config['length_target']
        length_ratio = len(summary) / target_length
        if 0.5 <= length_ratio <= 2.0:
            factors.append(0.8)
        else:
            factors.append(0.4)
        
        # Content density (compression ratio)
        compression = len(summary) / len(original_text)
        if 0.05 <= compression <= 0.3:  # Good compression ratio
            factors.append(0.9)
        else:
            factors.append(0.6)
        
        # Sentence structure (has proper sentences)
        sentence_count = len([s for s in summary.split('.') if s.strip()])
        if sentence_count >= 2:
            factors.append(0.8)
        else:
            factors.append(0.5)
        
        # Average the factors
        return sum(factors) / len(factors)


# Utility functions for easy integration
async def generate_chapter_summaries(
    chapters: List[DetectedChapter],
    chapter_texts: Dict[str, str],
    book_title: str,
    summary_style: SummaryStyle = SummaryStyle.DETAILED
) -> List[ChapterSummary]:
    """
    Convenience function to generate summaries for detected chapters.
    
    Args:
        chapters: List of DetectedChapter objects
        chapter_texts: Mapping of chapter_id to text content  
        book_title: Title of the book
        summary_style: Style of summaries to generate
        
    Returns:
        List of generated ChapterSummary objects
    """
    generator = ChapterSummaryGenerator()
    
    request = SummaryRequest(
        book_id="",  # Will be populated by caller
        book_title=book_title,
        summary_style=summary_style
    )
    
    return await generator.generate_book_summaries(request, chapters, chapter_texts)


def format_summaries_for_display(summaries: List[ChapterSummary]) -> str:
    """Format chapter summaries for human-readable display."""
    output = f"📚 Chapter Summaries ({len(summaries)} chapters)\n"
    output += "=" * 60 + "\n\n"
    
    for summary in summaries:
        output += f"**Chapter {summary.chapter_number}: {summary.chapter_title}**\n"
        output += f"Style: {summary.summary_style.value.title()} | "
        output += f"Confidence: {summary.confidence_score:.2f} | "
        output += f"Words: {summary.word_count}\n\n"
        
        if summary.summary_style == SummaryStyle.KEY_POINTS:
            output += summary.summary_text + "\n"
        else:
            output += f"{summary.summary_text}\n"
        
        if summary.themes:
            output += f"\n🎭 Themes: {', '.join(summary.themes[:3])}\n"
        
        if summary.characters_mentioned:
            output += f"👥 Characters: {', '.join(summary.characters_mentioned[:3])}\n"
        
        output += "\n" + "-" * 50 + "\n\n"
    
    return output