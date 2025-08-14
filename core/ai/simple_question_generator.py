"""
Simplified Question Generator using Azure OpenAI

This module provides AI-powered question generation for audiobook chapters
with multiple difficulty levels and question types. Uses Azure OpenAI directly.
"""

import json
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime
from dataclasses import dataclass
from enum import Enum

from .azure_llm_client import AzureLLMClient, generate_json_response, estimate_cost
from .chapter_processor import ChapterInfo
from .summary_generator import ChapterSummary


class QuestionDifficulty(Enum):
    """Difficulty levels for generated questions."""
    BEGINNER = "beginner"
    INTERMEDIATE = "intermediate"  
    ADVANCED = "advanced"


class QuestionType(Enum):
    """Types of questions that can be generated."""
    COMPREHENSION = "comprehension"  # What happened?
    ANALYSIS = "analysis"  # Why did this happen?
    DISCUSSION = "discussion"  # Opinion-based
    CREATIVE = "creative"  # What if scenarios
    PREDICTION = "prediction"  # What might happen next?


class ReadingMode(Enum):
    """Reading modes that affect question style."""
    EDUCATIONAL = "educational"  # Academic focus
    CASUAL = "casual"  # Fun, engaging
    CHILD = "child"  # Simple language
    PROFESSIONAL = "professional"  # Business focus


@dataclass
class GeneratedQuestion:
    """A generated question with metadata."""
    question_text: str
    question_type: QuestionType
    difficulty: QuestionDifficulty
    suggested_answer: str
    answer_guidelines: List[str]
    follow_up_questions: List[str]
    related_themes: List[str]
    confidence_score: float
    generation_timestamp: datetime
    cost_estimate: float
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "question_text": self.question_text,
            "question_type": self.question_type.value,
            "difficulty": self.difficulty.value,
            "suggested_answer": self.suggested_answer,
            "answer_guidelines": self.answer_guidelines,
            "follow_up_questions": self.follow_up_questions,
            "related_themes": self.related_themes,
            "confidence_score": self.confidence_score,
            "generation_timestamp": self.generation_timestamp.isoformat(),
            "cost_estimate": self.cost_estimate
        }


@dataclass
class QuestionSet:
    """A collection of questions for a chapter."""
    chapter_number: int
    chapter_title: str
    questions: List[GeneratedQuestion]
    total_questions: int
    difficulty_distribution: Dict[str, int]
    type_distribution: Dict[str, int]
    reading_mode: ReadingMode
    total_cost: float
    generation_time: float
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "chapter_number": self.chapter_number,
            "chapter_title": self.chapter_title,
            "total_questions": self.total_questions,
            "difficulty_distribution": self.difficulty_distribution,
            "type_distribution": self.type_distribution,
            "reading_mode": self.reading_mode.value,
            "total_cost": self.total_cost,
            "generation_time": self.generation_time,
            "questions": [q.to_dict() for q in self.questions]
        }


class SimpleQuestionGenerator:
    """Simplified question generator using Azure OpenAI."""
    
    def __init__(self):
        """Initialize question generator."""
        self.reading_mode_configs = {
            ReadingMode.EDUCATIONAL: {
                "tone": "academic and formal",
                "focus": "learning objectives and critical thinking",
                "complexity": "analytical and detailed"
            },
            ReadingMode.CASUAL: {
                "tone": "conversational and friendly",
                "focus": "enjoyment and engagement",
                "complexity": "accessible and interesting"
            },
            ReadingMode.CHILD: {
                "tone": "simple and encouraging",
                "focus": "basic understanding and fun",
                "complexity": "age-appropriate and clear"
            },
            ReadingMode.PROFESSIONAL: {
                "tone": "business-oriented and practical",
                "focus": "leadership and professional development",
                "complexity": "strategic and applicable"
            }
        }
    
    async def generate_questions(
        self,
        chapter_info: ChapterInfo,
        chapter_text: str,
        num_questions: int = 5,
        difficulty: QuestionDifficulty = QuestionDifficulty.INTERMEDIATE,
        reading_mode: ReadingMode = ReadingMode.CASUAL,
        question_types: Optional[List[QuestionType]] = None,
        chapter_summary: Optional[ChapterSummary] = None
    ) -> QuestionSet:
        """
        Generate questions for a chapter.
        
        Args:
            chapter_info: Chapter information
            chapter_text: Full text content
            num_questions: Number of questions to generate
            difficulty: Question difficulty level
            reading_mode: Reading mode for tone/style
            question_types: Specific question types (None = mixed)
            chapter_summary: Optional pre-generated summary
            
        Returns:
            QuestionSet with generated questions
        """
        start_time = datetime.now()
        
        print(f"🎯 Generating {num_questions} {difficulty.value} questions for Chapter {chapter_info.chapter_number}")
        
        # Select question types if not specified
        if not question_types:
            question_types = self._select_question_types(reading_mode, num_questions)
        
        # Generate questions
        questions = []
        total_cost = 0.0
        
        for i in range(num_questions):
            question_type = question_types[i % len(question_types)]
            
            try:
                question = await self._generate_single_question(
                    chapter_info=chapter_info,
                    chapter_text=chapter_text,
                    question_type=question_type,
                    difficulty=difficulty,
                    reading_mode=reading_mode,
                    chapter_summary=chapter_summary
                )
                
                if question:
                    questions.append(question)
                    total_cost += question.cost_estimate
                    
            except Exception as e:
                print(f"❌ Failed to generate question {i+1}: {e}")
                # Create fallback question
                fallback = self._create_fallback_question(
                    chapter_info, question_type, difficulty
                )
                questions.append(fallback)
        
        generation_time = (datetime.now() - start_time).total_seconds()
        
        # Calculate distributions
        difficulty_dist = {}
        type_dist = {}
        for q in questions:
            difficulty_dist[q.difficulty.value] = difficulty_dist.get(q.difficulty.value, 0) + 1
            type_dist[q.question_type.value] = type_dist.get(q.question_type.value, 0) + 1
        
        print(f"✅ Generated {len(questions)} questions in {generation_time:.1f}s (${total_cost:.4f})")
        
        return QuestionSet(
            chapter_number=chapter_info.chapter_number,
            chapter_title=chapter_info.title,
            questions=questions,
            total_questions=len(questions),
            difficulty_distribution=difficulty_dist,
            type_distribution=type_dist,
            reading_mode=reading_mode,
            total_cost=total_cost,
            generation_time=generation_time
        )
    
    async def _generate_single_question(
        self,
        chapter_info: ChapterInfo,
        chapter_text: str,
        question_type: QuestionType,
        difficulty: QuestionDifficulty,
        reading_mode: ReadingMode,
        chapter_summary: Optional[ChapterSummary]
    ) -> Optional[GeneratedQuestion]:
        """Generate a single question using Azure OpenAI."""
        
        # Build prompt
        prompt = self._build_question_prompt(
            chapter_info=chapter_info,
            chapter_text=chapter_text,
            question_type=question_type,
            difficulty=difficulty,
            reading_mode=reading_mode,
            chapter_summary=chapter_summary
        )
        
        # Estimate cost
        estimated_cost = estimate_cost(prompt, "300 words", "gpt-4")
        
        # Generate response
        expected_fields = ["question", "answer", "guidelines", "follow_ups", "themes"]
        response = await generate_json_response(
            prompt=prompt,
            expected_fields=expected_fields,
            max_tokens=400,
            temperature=0.7  # Higher for more creative questions
        )
        
        if not response.get("question"):
            return None
        
        # Calculate confidence
        confidence = self._calculate_question_confidence(response)
        
        return GeneratedQuestion(
            question_text=response.get("question", ""),
            question_type=question_type,
            difficulty=difficulty,
            suggested_answer=response.get("answer", ""),
            answer_guidelines=response.get("guidelines", []),
            follow_up_questions=response.get("follow_ups", []),
            related_themes=response.get("themes", []),
            confidence_score=confidence,
            generation_timestamp=datetime.now(),
            cost_estimate=estimated_cost
        )
    
    def _build_question_prompt(
        self,
        chapter_info: ChapterInfo,
        chapter_text: str,
        question_type: QuestionType,
        difficulty: QuestionDifficulty,
        reading_mode: ReadingMode,
        chapter_summary: Optional[ChapterSummary]
    ) -> str:
        """Build prompt for question generation."""
        
        # Truncate chapter text if too long
        max_text_length = 6000
        if len(chapter_text) > max_text_length:
            chapter_text = chapter_text[:max_text_length] + "..."
        
        # Get mode configuration
        mode_config = self.reading_mode_configs[reading_mode]
        
        # Question type descriptions
        type_descriptions = {
            QuestionType.COMPREHENSION: "comprehension question about what happened in the chapter",
            QuestionType.ANALYSIS: "analytical question about why or how things happened",
            QuestionType.DISCUSSION: "open-ended discussion question that invites personal opinions",
            QuestionType.CREATIVE: "creative thinking question that explores possibilities",
            QuestionType.PREDICTION: "prediction question about what might happen next"
        }
        
        # Difficulty descriptions
        difficulty_descriptions = {
            QuestionDifficulty.BEGINNER: "simple and straightforward, focusing on basic facts",
            QuestionDifficulty.INTERMEDIATE: "moderately complex, requiring some analysis",
            QuestionDifficulty.ADVANCED: "challenging and complex, requiring deep critical thinking"
        }
        
        # Include summary if available
        summary_section = ""
        if chapter_summary:
            summary_section = f"\nChapter Summary: {chapter_summary.summary_text}"
            if chapter_summary.key_points:
                summary_section += f"\nKey Points: {', '.join(chapter_summary.key_points[:3])}"
        
        return f"""Generate a {type_descriptions[question_type]} for this audiobook chapter.

Chapter: {chapter_info.title} (Chapter {chapter_info.chapter_number})
Duration: {chapter_info.duration_seconds:.1f} seconds{summary_section}

Chapter Content:
{chapter_text}

Instructions:
- Create a {difficulty_descriptions[difficulty]} question
- Use a {mode_config['tone']} tone
- Focus on {mode_config['focus']}
- Make it {mode_config['complexity']}
- Question type: {question_type.value}
- Difficulty level: {difficulty.value}

Requirements:
1. Create an engaging, thought-provoking question
2. Relate directly to the chapter content
3. Be appropriate for the specified difficulty level
4. Encourage meaningful engagement with the material
5. Be clear and well-formulated

Provide your response in this exact JSON format:
{{
    "question": "Your question text here",
    "answer": "A suggested answer or key points to cover",
    "guidelines": ["Key point 1 for a good answer", "Key point 2", "Key point 3"],
    "follow_ups": ["Related follow-up question 1", "Follow-up question 2"],
    "themes": ["Related theme 1", "Related theme 2"]
}}"""
    
    def _select_question_types(
        self,
        reading_mode: ReadingMode,
        num_questions: int
    ) -> List[QuestionType]:
        """Select appropriate question types based on reading mode."""
        
        mode_preferences = {
            ReadingMode.EDUCATIONAL: [
                QuestionType.COMPREHENSION,
                QuestionType.ANALYSIS,
                QuestionType.DISCUSSION,
                QuestionType.PREDICTION
            ],
            ReadingMode.CASUAL: [
                QuestionType.DISCUSSION,
                QuestionType.PREDICTION,
                QuestionType.CREATIVE,
                QuestionType.COMPREHENSION
            ],
            ReadingMode.CHILD: [
                QuestionType.COMPREHENSION,
                QuestionType.CREATIVE,
                QuestionType.PREDICTION,
                QuestionType.DISCUSSION
            ],
            ReadingMode.PROFESSIONAL: [
                QuestionType.ANALYSIS,
                QuestionType.DISCUSSION,
                QuestionType.COMPREHENSION,
                QuestionType.CREATIVE
            ]
        }
        
        preferred = mode_preferences.get(reading_mode, list(QuestionType))
        
        # Distribute questions across types
        selected = []
        for i in range(num_questions):
            selected.append(preferred[i % len(preferred)])
        
        return selected
    
    def _calculate_question_confidence(self, response: Dict[str, Any]) -> float:
        """Calculate confidence score for a generated question."""
        confidence = 0.5  # Base confidence
        
        if response.get("question") and len(response["question"]) > 10:
            confidence += 0.2
        if response.get("answer"):
            confidence += 0.1
        if response.get("guidelines") and len(response["guidelines"]) > 0:
            confidence += 0.1
        if response.get("follow_ups") and len(response["follow_ups"]) > 0:
            confidence += 0.05
        if response.get("themes") and len(response["themes"]) > 0:
            confidence += 0.05
        
        return min(1.0, confidence)
    
    def _create_fallback_question(
        self,
        chapter_info: ChapterInfo,
        question_type: QuestionType,
        difficulty: QuestionDifficulty
    ) -> GeneratedQuestion:
        """Create a fallback question when generation fails."""
        
        fallback_questions = {
            QuestionType.COMPREHENSION: f"What are the main events that occur in {chapter_info.title}?",
            QuestionType.ANALYSIS: f"Why do you think the events in {chapter_info.title} are significant to the story?",
            QuestionType.DISCUSSION: f"What did you think about the events in {chapter_info.title}?",
            QuestionType.CREATIVE: f"How might the story change if something different happened in {chapter_info.title}?",
            QuestionType.PREDICTION: f"Based on {chapter_info.title}, what do you think will happen next?"
        }
        
        return GeneratedQuestion(
            question_text=fallback_questions[question_type],
            question_type=question_type,
            difficulty=difficulty,
            suggested_answer="Please refer to the chapter content for details.",
            answer_guidelines=[],
            follow_up_questions=[],
            related_themes=[],
            confidence_score=0.3,
            generation_timestamp=datetime.now(),
            cost_estimate=0.0
        )


# Convenience functions
async def generate_chapter_questions(
    chapter_info: ChapterInfo,
    chapter_text: str,
    num_questions: int = 5,
    difficulty: QuestionDifficulty = QuestionDifficulty.INTERMEDIATE,
    reading_mode: ReadingMode = ReadingMode.CASUAL
) -> QuestionSet:
    """
    Simple function to generate questions for a chapter.
    
    Args:
        chapter_info: Chapter information
        chapter_text: Full chapter text
        num_questions: Number of questions to generate
        difficulty: Question difficulty level
        reading_mode: Reading mode for tone/style
        
    Returns:
        QuestionSet with generated questions
    """
    generator = SimpleQuestionGenerator()
    return await generator.generate_questions(
        chapter_info=chapter_info,
        chapter_text=chapter_text,
        num_questions=num_questions,
        difficulty=difficulty,
        reading_mode=reading_mode
    )


def save_questions_to_file(question_set: QuestionSet, output_path: str):
    """
    Save questions to a JSON file.
    
    Args:
        question_set: QuestionSet object
        output_path: Path to save the JSON file
    """
    data = {
        "generated_at": datetime.now().isoformat(),
        "chapter_questions": question_set.to_dict()
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def format_questions_for_display(question_set: QuestionSet) -> str:
    """Format questions for human-readable display."""
    output = f"❓ Discussion Questions - {question_set.chapter_title}\n"
    output += f"Mode: {question_set.reading_mode.value.title()} | "
    output += f"Total: {question_set.total_questions} questions | "
    output += f"Cost: ${question_set.total_cost:.4f}\n"
    output += "=" * 70 + "\n\n"
    
    for i, question in enumerate(question_set.questions, 1):
        output += f"Q{i}. {question.question_text}\n"
        output += f"    Type: {question.question_type.value} | "
        output += f"Difficulty: {question.difficulty.value} | "
        output += f"Confidence: {question.confidence_score:.2f}\n"
        
        if question.suggested_answer:
            output += f"    💡 Answer: {question.suggested_answer}\n"
        
        if question.answer_guidelines:
            output += f"    📌 Guidelines: {', '.join(question.answer_guidelines[:2])}\n"
        
        if question.follow_up_questions:
            output += f"    🔄 Follow-up: {question.follow_up_questions[0]}\n"
        
        output += "\n"
    
    return output