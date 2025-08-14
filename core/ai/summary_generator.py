"""
Simplified Chapter Summary Generator using Azure OpenAI

This module provides AI-powered chapter summarization with multiple styles
for pre-chaptered audiobooks. Uses Azure OpenAI instead of complex LLM gateway.
"""

import os
import json
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime
from dataclasses import dataclass
from enum import Enum

from .azure_llm_client import AzureLLMClient, generate_json_response, estimate_cost
from .chapter_processor import ChapterInfo


class SummaryStyle(Enum):
    """Different summary styles available."""
    BRIEF = "brief"  # 1-2 sentences, key points only
    DETAILED = "detailed"  # 3-5 sentences, comprehensive overview
    THEMES = "themes"  # Focus on themes, symbols, character development
    KEY_POINTS = "key_points"  # Bullet point format with main events
    QUESTION_BASED = "question_based"  # Summary in Q&A format


@dataclass
class ChapterSummary:
    """Generated chapter summary with metadata."""
    chapter_number: int
    chapter_title: str
    summary_style: SummaryStyle
    summary_text: str
    key_points: List[str]
    themes: List[str]
    characters_mentioned: List[str]
    word_count: int
    confidence_score: float
    generation_timestamp: datetime
    cost_estimate: float
    generation_time: float
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "chapter_number": self.chapter_number,
            "chapter_title": self.chapter_title,
            "summary_style": self.summary_style.value,
            "summary_text": self.summary_text,
            "key_points": self.key_points,
            "themes": self.themes,
            "characters_mentioned": self.characters_mentioned,
            "word_count": self.word_count,
            "confidence_score": self.confidence_score,
            "generation_timestamp": self.generation_timestamp.isoformat(),
            "cost_estimate": self.cost_estimate,
            "generation_time": self.generation_time
        }


class SummaryGenerator:
    """Simplified summary generator using Azure OpenAI."""
    
    def __init__(self):
        """Initialize summary generator."""
        self.style_configs = {
            SummaryStyle.BRIEF: {
                "max_sentences": 2,
                "target_words": 50,
                "focus": "main events and outcomes",
                "system_prompt": "You are a concise summarizer. Provide brief, clear summaries."
            },
            SummaryStyle.DETAILED: {
                "max_sentences": 5,
                "target_words": 150,
                "focus": "comprehensive overview with context and details",
                "system_prompt": "You are a detailed summarizer. Provide thorough, comprehensive summaries."
            },
            SummaryStyle.THEMES: {
                "max_sentences": 4,
                "target_words": 120,
                "focus": "themes, symbols, character development, and literary elements",
                "system_prompt": "You are a literary analyst. Focus on themes, symbolism, and character development."
            },
            SummaryStyle.KEY_POINTS: {
                "max_sentences": 6,
                "target_words": 100,
                "focus": "bullet points of main events and important information",
                "system_prompt": "You are an organizer. Present information in clear bullet points."
            },
            SummaryStyle.QUESTION_BASED: {
                "max_sentences": 4,
                "target_words": 130,
                "focus": "Q&A format covering main points and key questions",
                "system_prompt": "You are an educator. Present summaries in question and answer format."
            }
        }
    
    async def generate_summary(
        self,
        chapter_info: ChapterInfo,
        chapter_text: str,
        summary_style: SummaryStyle = SummaryStyle.DETAILED,
        book_context: Optional[str] = None
    ) -> ChapterSummary:
        """
        Generate a summary for a chapter.
        
        Args:
            chapter_info: Chapter information
            chapter_text: Full text content of the chapter
            summary_style: Style of summary to generate
            book_context: Optional context about the book
            
        Returns:
            ChapterSummary with generated content
        """
        start_time = datetime.now()
        
        if len(chapter_text.strip()) < 50:
            # Handle very short or missing text
            return self._create_fallback_summary(chapter_info, summary_style, start_time)
        
        # Get style configuration
        config = self.style_configs[summary_style]
        
        # Generate the summary
        summary_result = await self._generate_summary_content(
            chapter_text=chapter_text,
            chapter_info=chapter_info,
            style_config=config,
            summary_style=summary_style,
            book_context=book_context
        )
        
        generation_time = (datetime.now() - start_time).total_seconds()
        
        # Extract content from result
        summary_text = summary_result.get("summary", "")
        key_points = summary_result.get("key_points", [])
        themes = summary_result.get("themes", [])
        characters = summary_result.get("characters", [])
        cost_estimate = summary_result.get("cost_estimate", 0.0)
        
        # Calculate confidence score
        confidence = self._calculate_confidence(summary_text, chapter_text, config)
        
        return ChapterSummary(
            chapter_number=chapter_info.chapter_number,
            chapter_title=chapter_info.title,
            summary_style=summary_style,
            summary_text=summary_text,
            key_points=key_points[:5],  # Limit to 5 key points
            themes=themes[:4],  # Limit to 4 themes
            characters_mentioned=characters[:5],  # Limit to 5 characters
            word_count=len(summary_text.split()),
            confidence_score=confidence,
            generation_timestamp=start_time,
            cost_estimate=cost_estimate,
            generation_time=generation_time
        )
    
    async def generate_book_summaries(
        self,
        book_title: str,
        chapters: List[tuple],  # List of (ChapterInfo, chapter_text)
        summary_style: SummaryStyle = SummaryStyle.DETAILED
    ) -> List[ChapterSummary]:
        """
        Generate summaries for all chapters in a book.
        
        Args:
            book_title: Title of the book
            chapters: List of (ChapterInfo, chapter_text) tuples
            summary_style: Style for all summaries
            
        Returns:
            List of ChapterSummary objects
        """
        print(f"📚 Generating {summary_style.value} summaries for {len(chapters)} chapters of '{book_title}'")
        
        # Generate book context
        book_context = f"Book: {book_title}, Total Chapters: {len(chapters)}"
        
        summaries = []
        total_cost = 0.0
        
        for chapter_info, chapter_text in chapters:
            try:
                summary = await self.generate_summary(
                    chapter_info=chapter_info,
                    chapter_text=chapter_text,
                    summary_style=summary_style,
                    book_context=book_context
                )
                summaries.append(summary)
                total_cost += summary.cost_estimate
                
                print(f"✅ Generated summary for Chapter {chapter_info.chapter_number} (${summary.cost_estimate:.4f})")
                
            except Exception as e:
                print(f"❌ Failed to generate summary for Chapter {chapter_info.chapter_number}: {e}")
                # Create a fallback summary
                fallback = self._create_fallback_summary(chapter_info, summary_style, datetime.now())
                summaries.append(fallback)
        
        print(f"📊 Total summaries: {len(summaries)}, Total cost: ${total_cost:.4f}")
        return summaries
    
    async def _generate_summary_content(
        self,
        chapter_text: str,
        chapter_info: ChapterInfo,
        style_config: Dict[str, Any],
        summary_style: SummaryStyle,
        book_context: Optional[str]
    ) -> Dict[str, Any]:
        """Generate summary content using Azure OpenAI."""
        
        # Truncate very long chapters
        max_input_length = 8000  # Leave room for prompt
        if len(chapter_text) > max_input_length:
            chapter_text = chapter_text[:max_input_length] + "..."
        
        # Build the prompt
        prompt = self._build_prompt(
            chapter_text=chapter_text,
            chapter_info=chapter_info,
            style_config=style_config,
            summary_style=summary_style,
            book_context=book_context
        )
        
        # Estimate cost
        estimated_cost = estimate_cost(prompt, "500 words", "gpt-4")
        
        # Generate response
        expected_fields = ["summary", "key_points", "themes", "characters"]
        response = await generate_json_response(
            prompt=prompt,
            expected_fields=expected_fields,
            max_tokens=600,
            temperature=0.3
        )
        
        # Add cost estimate to response
        response["cost_estimate"] = estimated_cost
        
        return response
    
    def _build_prompt(
        self,
        chapter_text: str,
        chapter_info: ChapterInfo,
        style_config: Dict[str, Any],
        summary_style: SummaryStyle,
        book_context: Optional[str]
    ) -> str:
        """Build the prompt for summary generation."""
        
        context_section = f"\nBook Context: {book_context}" if book_context else ""
        
        # Style-specific instructions
        style_instructions = {
            SummaryStyle.BRIEF: f"Write a brief {style_config['max_sentences']}-sentence summary focusing on {style_config['focus']}.",
            SummaryStyle.DETAILED: f"Write a detailed {style_config['max_sentences']}-sentence summary that provides {style_config['focus']}.",
            SummaryStyle.THEMES: f"Write a {style_config['max_sentences']}-sentence summary focusing on {style_config['focus']}.",
            SummaryStyle.KEY_POINTS: f"Create a summary with {style_config['max_sentences']} key bullet points covering {style_config['focus']}.",
            SummaryStyle.QUESTION_BASED: f"Create a {style_config['max_sentences']}-question Q&A summary covering {style_config['focus']}."
        }
        
        return f"""Analyze this audiobook chapter and create a high-quality summary.

Chapter: {chapter_info.title}
Chapter Number: {chapter_info.chapter_number}
Duration: {chapter_info.duration_seconds:.1f} seconds{context_section}

Chapter Content:
{chapter_text}

Instructions:
{style_instructions[summary_style]}

Target length: ~{style_config['target_words']} words
Focus: {style_config['focus']}

Requirements:
- Be accurate to the source material
- Maintain narrative flow and coherence
- Include specific details and events
- Avoid spoilers for future chapters
- Write in clear, engaging prose

Also identify:
- 3-5 key points or events
- 2-4 main themes or topics
- 3-5 important characters mentioned

Provide your response in this exact JSON format:
{{
    "summary": "Your summary text here",
    "key_points": ["Key point 1", "Key point 2", "Key point 3"],
    "themes": ["Theme 1", "Theme 2"],
    "characters": ["Character 1", "Character 2", "Character 3"]
}}"""
    
    def _calculate_confidence(
        self,
        summary_text: str,
        original_text: str,
        style_config: Dict[str, Any]
    ) -> float:
        """Calculate confidence score for the generated summary."""
        if not summary_text or len(summary_text) < 20:
            return 0.1
        
        factors = []
        
        # Length appropriateness
        target_words = style_config['target_words']
        actual_words = len(summary_text.split())
        length_ratio = actual_words / target_words
        if 0.5 <= length_ratio <= 2.0:
            factors.append(0.8)
        else:
            factors.append(0.4)
        
        # Content density (compression ratio)
        if len(original_text) > 0:
            compression = len(summary_text) / len(original_text)
            if 0.05 <= compression <= 0.3:
                factors.append(0.9)
            else:
                factors.append(0.6)
        else:
            factors.append(0.5)
        
        # Has proper sentences
        sentence_count = len([s for s in summary_text.split('.') if s.strip()])
        if sentence_count >= 2:
            factors.append(0.8)
        else:
            factors.append(0.5)
        
        return sum(factors) / len(factors)
    
    def _create_fallback_summary(
        self,
        chapter_info: ChapterInfo,
        summary_style: SummaryStyle,
        start_time: datetime
    ) -> ChapterSummary:
        """Create a fallback summary when generation fails."""
        
        fallback_text = {
            SummaryStyle.BRIEF: f"Chapter {chapter_info.chapter_number} content.",
            SummaryStyle.DETAILED: f"This is Chapter {chapter_info.chapter_number}: {chapter_info.title}. The chapter contains important story content and character development.",
            SummaryStyle.THEMES: f"Chapter {chapter_info.chapter_number} explores various themes and character relationships.",
            SummaryStyle.KEY_POINTS: f"• Chapter {chapter_info.chapter_number} begins\n• Story content continues\n• Chapter concludes",
            SummaryStyle.QUESTION_BASED: f"Q: What happens in this chapter?\nA: Chapter {chapter_info.chapter_number} contains story content."
        }
        
        return ChapterSummary(
            chapter_number=chapter_info.chapter_number,
            chapter_title=chapter_info.title,
            summary_style=summary_style,
            summary_text=fallback_text[summary_style],
            key_points=[],
            themes=[],
            characters_mentioned=[],
            word_count=len(fallback_text[summary_style].split()),
            confidence_score=0.1,
            generation_timestamp=start_time,
            cost_estimate=0.0,
            generation_time=0.0
        )


# Convenience functions
async def generate_chapter_summary(
    chapter_info: ChapterInfo,
    chapter_text: str,
    style: SummaryStyle = SummaryStyle.DETAILED
) -> ChapterSummary:
    """
    Simple function to generate a single chapter summary.
    
    Args:
        chapter_info: Chapter information
        chapter_text: Chapter text content
        style: Summary style
        
    Returns:
        ChapterSummary object
    """
    generator = SummaryGenerator()
    return await generator.generate_summary(chapter_info, chapter_text, style)


async def generate_all_summaries(
    book_title: str,
    chapters_data: List[tuple],
    style: SummaryStyle = SummaryStyle.DETAILED
) -> List[ChapterSummary]:
    """
    Generate summaries for all chapters in a book.
    
    Args:
        book_title: Title of the book
        chapters_data: List of (ChapterInfo, text) tuples
        style: Summary style for all chapters
        
    Returns:
        List of ChapterSummary objects
    """
    generator = SummaryGenerator()
    return await generator.generate_book_summaries(book_title, chapters_data, style)


def save_summaries_to_file(summaries: List[ChapterSummary], output_path: str):
    """
    Save summaries to a JSON file.
    
    Args:
        summaries: List of ChapterSummary objects
        output_path: Path to save the JSON file
    """
    data = {
        "generated_at": datetime.now().isoformat(),
        "total_summaries": len(summaries),
        "total_cost": sum(s.cost_estimate for s in summaries),
        "summaries": [s.to_dict() for s in summaries]
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def format_summary_for_display(summary: ChapterSummary) -> str:
    """Format a summary for human-readable display."""
    output = f"📖 {summary.chapter_title}\n"
    output += f"Style: {summary.summary_style.value.title()} | "
    output += f"Confidence: {summary.confidence_score:.2f} | "
    output += f"Cost: ${summary.cost_estimate:.4f}\n"
    output += "=" * 60 + "\n\n"
    
    output += f"{summary.summary_text}\n\n"
    
    if summary.key_points:
        output += "🔑 Key Points:\n"
        for point in summary.key_points:
            output += f"• {point}\n"
        output += "\n"
    
    if summary.themes:
        output += f"🎭 Themes: {', '.join(summary.themes)}\n"
    
    if summary.characters_mentioned:
        output += f"👥 Characters: {', '.join(summary.characters_mentioned)}\n"
    
    return output