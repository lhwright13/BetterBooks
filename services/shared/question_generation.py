"""
Personalized Question Generation System

This module provides AI-powered question generation for audiobook chapters with:
- Multiple difficulty levels (beginner, intermediate, advanced)
- Different question types (comprehension, analysis, discussion, creative)
- Educational and casual reading modes
- Adaptive difficulty based on user engagement
"""

import os
import re
import json
import random
import asyncio
from typing import List, Dict, Any, Optional, Union, Tuple
from datetime import datetime
from dataclasses import dataclass
from enum import Enum

import aiohttp
from chapter_detection import DetectedChapter
from chapter_summaries import ChapterSummary


class QuestionDifficulty(Enum):
    """Difficulty levels for generated questions."""
    BEGINNER = "beginner"  # Basic comprehension, facts
    INTERMEDIATE = "intermediate"  # Analysis, connections
    ADVANCED = "advanced"  # Critical thinking, themes
    ADAPTIVE = "adaptive"  # Adjusts based on user performance


class QuestionType(Enum):
    """Types of questions that can be generated."""
    COMPREHENSION = "comprehension"  # What happened? Who did what?
    ANALYSIS = "analysis"  # Why did this happen? What does it mean?
    DISCUSSION = "discussion"  # Open-ended, opinion-based
    CREATIVE = "creative"  # What if? Imagine if...
    VOCABULARY = "vocabulary"  # Word meanings, language
    PREDICTION = "prediction"  # What might happen next?
    CONNECTION = "connection"  # How does this relate to earlier events?


class ReadingMode(Enum):
    """Reading modes that affect question style."""
    EDUCATIONAL = "educational"  # Academic focus, learning objectives
    CASUAL = "casual"  # Fun, engaging, less formal
    CHILD = "child"  # Simple language, age-appropriate
    PROFESSIONAL = "professional"  # Business/career development focus
    LANGUAGE_LEARNING = "language_learning"  # ESL/language practice


@dataclass
class GeneratedQuestion:
    """Represents a generated question with metadata."""
    question_id: str
    chapter_id: str
    question_text: str
    question_type: QuestionType
    difficulty: QuestionDifficulty
    suggested_answer: str
    answer_guidelines: List[str]  # Key points for good answer
    follow_up_questions: List[str]
    related_themes: List[str]
    position_context: Dict[str, Any]  # Where in chapter this relates to
    generation_timestamp: datetime
    confidence_score: float
    metadata: Dict[str, Any]


@dataclass
class QuestionSet:
    """A collection of questions for a chapter or section."""
    set_id: str
    chapter_id: str
    chapter_title: str
    questions: List[GeneratedQuestion]
    total_questions: int
    difficulty_distribution: Dict[str, int]
    type_distribution: Dict[str, int]
    reading_mode: ReadingMode
    generation_metadata: Dict[str, Any]


@dataclass
class QuestionGenerationRequest:
    """Request for generating questions."""
    book_id: str
    book_title: str
    chapter_id: str
    chapter_number: int
    current_position: Optional[float] = None  # Timestamp in audiobook
    num_questions: int = 5
    difficulty: QuestionDifficulty = QuestionDifficulty.INTERMEDIATE
    question_types: Optional[List[QuestionType]] = None
    reading_mode: ReadingMode = ReadingMode.CASUAL
    user_level: Optional[str] = None  # For adaptive difficulty
    focus_areas: Optional[List[str]] = None  # Specific topics to focus on


class QuestionGenerator:
    """AI-powered question generation system."""
    
    def __init__(self, llm_gateway_url: str = "http://llm_gateway:8000"):
        self.llm_gateway_url = llm_gateway_url
        
        # Question templates by type and difficulty
        self.question_templates = {
            QuestionType.COMPREHENSION: {
                QuestionDifficulty.BEGINNER: [
                    "What happened when {event}?",
                    "Who is {character} and what did they do?",
                    "Where does {scene} take place?",
                    "What is the main event in this chapter?"
                ],
                QuestionDifficulty.INTERMEDIATE: [
                    "Describe the sequence of events that led to {outcome}.",
                    "How did {character} react to {event}?",
                    "What were the consequences of {action}?",
                    "Explain the relationship between {character1} and {character2}."
                ],
                QuestionDifficulty.ADVANCED: [
                    "Analyze the chain of cause and effect in this chapter.",
                    "How do the events here connect to the overall narrative?",
                    "What implicit information can we infer about {character}?"
                ]
            },
            QuestionType.ANALYSIS: {
                QuestionDifficulty.BEGINNER: [
                    "Why do you think {character} did {action}?",
                    "What might be the reason for {event}?",
                    "How does {character} feel about {situation}?"
                ],
                QuestionDifficulty.INTERMEDIATE: [
                    "What motivates {character}'s actions in this chapter?",
                    "How does {event} change the story's direction?",
                    "What is the significance of {symbol/object}?",
                    "Compare {character}'s behavior here with earlier chapters."
                ],
                QuestionDifficulty.ADVANCED: [
                    "Analyze the author's use of {literary_device} in this section.",
                    "How does this chapter develop the theme of {theme}?",
                    "What commentary might the author be making about {topic}?",
                    "Evaluate the reliability of the narrator in this passage."
                ]
            },
            QuestionType.DISCUSSION: {
                QuestionDifficulty.BEGINNER: [
                    "What would you do if you were {character}?",
                    "Do you agree with {character}'s decision? Why?",
                    "Which character do you like most? Why?"
                ],
                QuestionDifficulty.INTERMEDIATE: [
                    "Is {character}'s action justified? Explain your reasoning.",
                    "How might the story change if {alternative_event}?",
                    "What moral dilemma does {character} face?",
                    "Discuss the fairness of {situation}."
                ],
                QuestionDifficulty.ADVANCED: [
                    "Debate the ethical implications of {character}'s choice.",
                    "How does this chapter reflect contemporary issues?",
                    "What philosophical questions does this raise?",
                    "Critically evaluate the author's portrayal of {topic}."
                ]
            },
            QuestionType.CREATIVE: {
                QuestionDifficulty.BEGINNER: [
                    "Draw or describe what {scene} looks like to you.",
                    "Write a diary entry from {character}'s perspective.",
                    "Imagine you could talk to {character}. What would you say?"
                ],
                QuestionDifficulty.INTERMEDIATE: [
                    "Rewrite this scene from {character}'s point of view.",
                    "Create an alternative ending for this chapter.",
                    "Design a movie poster for this chapter.",
                    "Write a news article about {event}."
                ],
                QuestionDifficulty.ADVANCED: [
                    "Write a missing scene that could fit in this chapter.",
                    "Create a psychological profile of {character}.",
                    "Compose a poem inspired by this chapter's themes.",
                    "Draft a letter from {character1} to {character2}."
                ]
            },
            QuestionType.PREDICTION: {
                QuestionDifficulty.BEGINNER: [
                    "What do you think will happen next?",
                    "Will {character} succeed? Why or why not?",
                    "What problem might {character} face next?"
                ],
                QuestionDifficulty.INTERMEDIATE: [
                    "Based on {event}, predict the next chapter's conflict.",
                    "How will {character}'s decision affect future events?",
                    "What foreshadowing suggests about upcoming events?"
                ],
                QuestionDifficulty.ADVANCED: [
                    "Analyze the narrative trajectory and predict the climax.",
                    "How will the themes developed here culminate?",
                    "What narrative patterns suggest about the resolution?"
                ]
            }
        }
        
        # Reading mode adjustments
        self.mode_adjustments = {
            ReadingMode.EDUCATIONAL: {
                "tone": "academic",
                "focus": "learning objectives and critical thinking",
                "include_vocabulary": True,
                "formal_language": True
            },
            ReadingMode.CASUAL: {
                "tone": "conversational",
                "focus": "enjoyment and engagement",
                "include_vocabulary": False,
                "formal_language": False
            },
            ReadingMode.CHILD: {
                "tone": "friendly and simple",
                "focus": "basic understanding and fun",
                "include_vocabulary": True,
                "formal_language": False
            },
            ReadingMode.PROFESSIONAL: {
                "tone": "business-oriented",
                "focus": "leadership and professional development",
                "include_vocabulary": False,
                "formal_language": True
            },
            ReadingMode.LANGUAGE_LEARNING: {
                "tone": "instructional",
                "focus": "language practice and comprehension",
                "include_vocabulary": True,
                "formal_language": True
            }
        }

    async def generate_questions(
        self,
        request: QuestionGenerationRequest,
        chapter_text: str,
        chapter_summary: Optional[ChapterSummary] = None
    ) -> QuestionSet:
        """
        Generate a set of questions for a chapter.
        
        Args:
            request: Question generation request with parameters
            chapter_text: Full text of the chapter
            chapter_summary: Optional pre-generated summary
            
        Returns:
            QuestionSet with generated questions
        """
        print(f"🎯 Generating {request.num_questions} questions for Chapter {request.chapter_number}")
        
        # Determine question types to generate
        if request.question_types:
            selected_types = request.question_types
        else:
            selected_types = self._select_question_types(request.reading_mode, request.num_questions)
        
        # Generate questions
        questions = []
        for i in range(request.num_questions):
            question_type = selected_types[i % len(selected_types)]
            
            question = await self._generate_single_question(
                chapter_text=chapter_text,
                chapter_summary=chapter_summary,
                question_type=question_type,
                difficulty=request.difficulty,
                reading_mode=request.reading_mode,
                chapter_context={
                    "chapter_number": request.chapter_number,
                    "chapter_id": request.chapter_id,
                    "position": request.current_position,
                    "focus_areas": request.focus_areas
                }
            )
            
            if question:
                questions.append(question)
        
        # Calculate distributions
        difficulty_dist = {}
        type_dist = {}
        for q in questions:
            difficulty_dist[q.difficulty.value] = difficulty_dist.get(q.difficulty.value, 0) + 1
            type_dist[q.question_type.value] = type_dist.get(q.question_type.value, 0) + 1
        
        return QuestionSet(
            set_id=f"qset_{request.chapter_id}_{datetime.now().timestamp()}",
            chapter_id=request.chapter_id,
            chapter_title=f"Chapter {request.chapter_number}",
            questions=questions,
            total_questions=len(questions),
            difficulty_distribution=difficulty_dist,
            type_distribution=type_dist,
            reading_mode=request.reading_mode,
            generation_metadata={
                "request_params": {
                    "difficulty": request.difficulty.value,
                    "num_questions": request.num_questions,
                    "focus_areas": request.focus_areas
                },
                "generation_timestamp": datetime.now().isoformat(),
                "chapter_word_count": len(chapter_text.split())
            }
        )

    async def _generate_single_question(
        self,
        chapter_text: str,
        chapter_summary: Optional[ChapterSummary],
        question_type: QuestionType,
        difficulty: QuestionDifficulty,
        reading_mode: ReadingMode,
        chapter_context: Dict[str, Any]
    ) -> Optional[GeneratedQuestion]:
        """Generate a single question using AI."""
        
        # Prepare context for question generation
        context = self._prepare_question_context(chapter_text, chapter_summary, chapter_context)
        
        # Get mode adjustments
        mode_config = self.mode_adjustments[reading_mode]
        
        # Build prompt
        prompt = self._build_question_prompt(
            context=context,
            question_type=question_type,
            difficulty=difficulty,
            mode_config=mode_config
        )
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.llm_gateway_url}/complete",
                    json={
                        "prompt": prompt,
                        "max_tokens": 500,
                        "temperature": 0.7  # Higher for more creative questions
                    },
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        
                        # Parse the AI response
                        parsed_question = self._parse_question_response(
                            result.get("response", ""),
                            question_type,
                            difficulty
                        )
                        
                        if parsed_question:
                            return GeneratedQuestion(
                                question_id=f"q_{chapter_context['chapter_id']}_{datetime.now().timestamp()}",
                                chapter_id=chapter_context['chapter_id'],
                                question_text=parsed_question['question'],
                                question_type=question_type,
                                difficulty=difficulty,
                                suggested_answer=parsed_question.get('answer', ''),
                                answer_guidelines=parsed_question.get('guidelines', []),
                                follow_up_questions=parsed_question.get('follow_ups', []),
                                related_themes=parsed_question.get('themes', []),
                                position_context={
                                    "chapter_number": chapter_context['chapter_number'],
                                    "timestamp": chapter_context.get('position')
                                },
                                generation_timestamp=datetime.now(),
                                confidence_score=self._calculate_question_confidence(parsed_question),
                                metadata={
                                    "reading_mode": reading_mode.value,
                                    "generation_method": "ai",
                                    "model": "gemini-pro"
                                }
                            )
        except Exception as e:
            print(f"Error generating question: {e}")
        
        # Fallback to template-based generation
        return self._generate_fallback_question(
            chapter_text, question_type, difficulty, chapter_context
        )

    def _prepare_question_context(
        self,
        chapter_text: str,
        chapter_summary: Optional[ChapterSummary],
        chapter_context: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Prepare context for question generation."""
        
        # Truncate chapter text if too long
        max_text_length = 2000
        if len(chapter_text) > max_text_length:
            # Take beginning and end for context
            chapter_excerpt = chapter_text[:1000] + "\n...\n" + chapter_text[-1000:]
        else:
            chapter_excerpt = chapter_text
        
        context = {
            "chapter_text": chapter_excerpt,
            "chapter_number": chapter_context['chapter_number'],
            "word_count": len(chapter_text.split())
        }
        
        if chapter_summary:
            context.update({
                "summary": chapter_summary.summary_text,
                "key_points": chapter_summary.key_points,
                "themes": chapter_summary.themes,
                "characters": chapter_summary.characters_mentioned
            })
        
        if chapter_context.get('focus_areas'):
            context['focus_areas'] = chapter_context['focus_areas']
        
        return context

    def _build_question_prompt(
        self,
        context: Dict[str, Any],
        question_type: QuestionType,
        difficulty: QuestionDifficulty,
        mode_config: Dict[str, Any]
    ) -> str:
        """Build prompt for AI question generation."""
        
        # Question type descriptions
        type_descriptions = {
            QuestionType.COMPREHENSION: "comprehension question about what happened",
            QuestionType.ANALYSIS: "analytical question about why or how things happened",
            QuestionType.DISCUSSION: "open-ended discussion question",
            QuestionType.CREATIVE: "creative thinking or imagination question",
            QuestionType.VOCABULARY: "vocabulary or language question",
            QuestionType.PREDICTION: "prediction question about what might happen next",
            QuestionType.CONNECTION: "question connecting to earlier events or themes"
        }
        
        # Difficulty descriptions
        difficulty_descriptions = {
            QuestionDifficulty.BEGINNER: "simple and straightforward",
            QuestionDifficulty.INTERMEDIATE: "moderately complex requiring some thought",
            QuestionDifficulty.ADVANCED: "complex and challenging requiring deep analysis"
        }
        
        prompt = f"""Generate a {type_descriptions[question_type]} for this audiobook chapter.

Chapter Context:
Chapter {context['chapter_number']}
Text excerpt: {context.get('chapter_text', '')}

{f"Summary: {context.get('summary', '')}" if context.get('summary') else ""}
{f"Key themes: {', '.join(context.get('themes', []))}" if context.get('themes') else ""}
{f"Characters: {', '.join(context.get('characters', []))}" if context.get('characters') else ""}

Instructions:
- Create a {difficulty_descriptions[difficulty]} question
- Use a {mode_config['tone']} tone
- Focus on {mode_config['focus']}
- Question type: {question_type.value}
- Difficulty level: {difficulty.value}

Generate a question that:
1. Is appropriate for the difficulty level
2. Relates directly to the chapter content
3. Encourages thinking and engagement
4. Is clear and well-formulated

Provide your response in JSON format:
{{
    "question": "The question text",
    "answer": "A suggested answer or answer guidelines",
    "guidelines": ["Key point 1", "Key point 2", "Key point 3"],
    "follow_ups": ["Follow-up question 1", "Follow-up question 2"],
    "themes": ["Related theme 1", "Related theme 2"]
}}

Question:"""

        return prompt

    def _parse_question_response(
        self,
        response: str,
        question_type: QuestionType,
        difficulty: QuestionDifficulty
    ) -> Optional[Dict[str, Any]]:
        """Parse AI response into structured question data."""
        
        try:
            # Try to parse as JSON
            import json
            question_data = json.loads(response)
            
            # Validate required fields
            if 'question' in question_data and question_data['question']:
                return {
                    'question': question_data['question'],
                    'answer': question_data.get('answer', ''),
                    'guidelines': question_data.get('guidelines', []),
                    'follow_ups': question_data.get('follow_ups', []),
                    'themes': question_data.get('themes', [])
                }
        except:
            # Fallback: try to extract question from plain text
            lines = response.strip().split('\n')
            for line in lines:
                if '?' in line and len(line) > 10:
                    return {
                        'question': line.strip(),
                        'answer': '',
                        'guidelines': [],
                        'follow_ups': [],
                        'themes': []
                    }
        
        return None

    def _generate_fallback_question(
        self,
        chapter_text: str,
        question_type: QuestionType,
        difficulty: QuestionDifficulty,
        chapter_context: Dict[str, Any]
    ) -> GeneratedQuestion:
        """Generate a fallback question using templates."""
        
        # Extract basic information from text
        words = chapter_text.split()
        
        # Simple character extraction (capitalized words)
        potential_characters = [w for w in words if w and w[0].isupper() and len(w) > 2]
        character = potential_characters[0] if potential_characters else "the main character"
        
        # Get a template
        templates = self.question_templates.get(question_type, {}).get(
            difficulty,
            ["What happens in this chapter?"]
        )
        
        template = random.choice(templates)
        
        # Simple template filling
        question_text = template.replace("{character}", character)
        question_text = question_text.replace("{event}", "this event")
        question_text = question_text.replace("{action}", "this action")
        
        return GeneratedQuestion(
            question_id=f"q_fallback_{datetime.now().timestamp()}",
            chapter_id=chapter_context['chapter_id'],
            question_text=question_text,
            question_type=question_type,
            difficulty=difficulty,
            suggested_answer="Please refer to the chapter content for the answer.",
            answer_guidelines=[],
            follow_up_questions=[],
            related_themes=[],
            position_context=chapter_context,
            generation_timestamp=datetime.now(),
            confidence_score=0.3,  # Low confidence for fallback
            metadata={"generation_method": "fallback_template"}
        )

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
                QuestionType.CONNECTION,
                QuestionType.VOCABULARY
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
                QuestionType.VOCABULARY
            ],
            ReadingMode.PROFESSIONAL: [
                QuestionType.ANALYSIS,
                QuestionType.DISCUSSION,
                QuestionType.CONNECTION
            ],
            ReadingMode.LANGUAGE_LEARNING: [
                QuestionType.VOCABULARY,
                QuestionType.COMPREHENSION,
                QuestionType.DISCUSSION
            ]
        }
        
        preferred_types = mode_preferences.get(reading_mode, list(QuestionType))
        
        # Distribute questions across types
        selected = []
        for i in range(num_questions):
            selected.append(preferred_types[i % len(preferred_types)])
        
        return selected

    def _calculate_question_confidence(self, parsed_question: Dict[str, Any]) -> float:
        """Calculate confidence score for a generated question."""
        
        confidence = 0.5  # Base confidence
        
        # Increase confidence for complete responses
        if parsed_question.get('question'):
            confidence += 0.2
        if parsed_question.get('answer'):
            confidence += 0.1
        if parsed_question.get('guidelines'):
            confidence += 0.1
        if len(parsed_question.get('follow_ups', [])) > 0:
            confidence += 0.05
        if len(parsed_question.get('themes', [])) > 0:
            confidence += 0.05
        
        return min(1.0, confidence)

    async def generate_adaptive_questions(
        self,
        request: QuestionGenerationRequest,
        chapter_text: str,
        user_performance: Dict[str, Any]
    ) -> QuestionSet:
        """
        Generate questions with adaptive difficulty based on user performance.
        
        Args:
            request: Base question generation request
            chapter_text: Chapter content
            user_performance: User's past performance data
            
        Returns:
            QuestionSet with adaptively selected difficulties
        """
        # Analyze user performance
        avg_correct_rate = user_performance.get('correct_rate', 0.5)
        recent_difficulties = user_performance.get('recent_difficulties', [])
        
        # Adjust difficulty based on performance
        if avg_correct_rate > 0.8:
            # User doing well, increase difficulty
            adjusted_difficulty = QuestionDifficulty.ADVANCED
        elif avg_correct_rate < 0.4:
            # User struggling, decrease difficulty
            adjusted_difficulty = QuestionDifficulty.BEGINNER
        else:
            adjusted_difficulty = QuestionDifficulty.INTERMEDIATE
        
        # Update request with adaptive difficulty
        request.difficulty = adjusted_difficulty
        
        # Generate questions with mix of difficulties
        return await self.generate_questions(request, chapter_text)


# Utility functions
async def generate_chapter_questions(
    chapter_id: str,
    chapter_number: int,
    chapter_text: str,
    num_questions: int = 5,
    difficulty: QuestionDifficulty = QuestionDifficulty.INTERMEDIATE,
    reading_mode: ReadingMode = ReadingMode.CASUAL
) -> QuestionSet:
    """
    Convenience function to generate questions for a chapter.
    
    Args:
        chapter_id: Unique chapter identifier
        chapter_number: Chapter number
        chapter_text: Full chapter text
        num_questions: Number of questions to generate
        difficulty: Question difficulty level
        reading_mode: Reading mode for tone/style
        
    Returns:
        QuestionSet with generated questions
    """
    generator = QuestionGenerator()
    
    request = QuestionGenerationRequest(
        book_id="",
        book_title="",
        chapter_id=chapter_id,
        chapter_number=chapter_number,
        num_questions=num_questions,
        difficulty=difficulty,
        reading_mode=reading_mode
    )
    
    return await generator.generate_questions(request, chapter_text)


def format_questions_for_display(question_set: QuestionSet) -> str:
    """Format a question set for human-readable display."""
    output = f"📝 Discussion Questions - Chapter {question_set.chapter_title}\n"
    output += f"Mode: {question_set.reading_mode.value.title()} | "
    output += f"Total: {question_set.total_questions} questions\n"
    output += "=" * 60 + "\n\n"
    
    for i, question in enumerate(question_set.questions, 1):
        output += f"Q{i}. {question.question_text}\n"
        output += f"   Type: {question.question_type.value} | "
        output += f"Difficulty: {question.difficulty.value}\n"
        
        if question.suggested_answer:
            output += f"   💡 Suggested Answer: {question.suggested_answer}\n"
        
        if question.answer_guidelines:
            output += f"   📌 Key Points: {', '.join(question.answer_guidelines[:3])}\n"
        
        if question.follow_up_questions:
            output += f"   🔄 Follow-up: {question.follow_up_questions[0]}\n"
        
        output += "\n"
    
    return output