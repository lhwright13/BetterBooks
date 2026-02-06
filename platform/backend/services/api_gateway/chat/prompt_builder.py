"""
Prompt Builder

Combines persona system prompts with book context to create
complete prompts for the LLM. Handles spoiler prevention by
only including text up to the user's current position.
"""

from typing import List, Optional
from dataclasses import dataclass

from context import IContextRetriever, ContextResult
from personas import IPersonaManager, PersonaConfig


@dataclass
class BuiltPrompt:
    """Result of building a prompt."""
    system_prompt: str           # Complete system prompt for LLM
    persona: PersonaConfig       # The persona being used
    context: ContextResult       # The book context retrieved


class PromptBuilder:
    """
    Builds complete LLM prompts by combining:
    1. Persona's base system prompt
    2. Book context (text up to current timestamp)
    3. Spoiler prevention instructions
    """

    SPOILER_BOUNDARY_INSTRUCTION = """
CRITICAL RULE - SPOILER PREVENTION:
You must NEVER reveal, hint at, or discuss ANY events, plot points, character
developments, or information from parts of the book that come AFTER the reader's
current position. The reader is currently at the position marked below. Everything
after that point is OFF LIMITS.

If asked about future events, respond naturally in character:
- Characters should say they don't know what will happen
- Teachers should say "We haven't gotten to that part yet"
- Never acknowledge that you're avoiding spoilers

Current Position: Chapter {chapter}, {timestamp} into the chapter.
"""

    CONTEXT_HEADER = """
=== BOOK CONTEXT (What the reader has heard so far) ===
The following is the complete text from the audiobook up to the reader's current position.
Use this to answer questions accurately while staying in character.

"""

    def __init__(
        self,
        context_retriever: IContextRetriever,
        persona_manager: IPersonaManager
    ):
        """
        Initialize the prompt builder.

        Args:
            context_retriever: For fetching book text
            persona_manager: For loading personas
        """
        self.context_retriever = context_retriever
        self.persona_manager = persona_manager

    def _format_timestamp(self, seconds: float) -> str:
        """Format seconds as MM:SS."""
        minutes = int(seconds // 60)
        secs = int(seconds % 60)
        return f"{minutes}:{secs:02d}"

    async def build(
        self,
        book_id: str,
        chapter: int,
        timestamp_seconds: float,
        persona_id: str,
        max_context_tokens: int = 12000
    ) -> Optional[BuiltPrompt]:
        """
        Build a complete prompt for the LLM.

        Args:
            book_id: The book being read
            chapter: Current chapter number
            timestamp_seconds: Position in current chapter
            persona_id: Which persona to use
            max_context_tokens: Maximum tokens for book context

        Returns:
            BuiltPrompt with system prompt, persona, and context info
            None if persona not found
        """
        # Load persona
        persona = await self.persona_manager.get_persona(persona_id, book_id)
        if not persona:
            return None

        # Get book context up to current position
        context = await self.context_retriever.get_context(
            book_id=book_id,
            chapter=chapter,
            timestamp_seconds=timestamp_seconds,
            max_tokens=max_context_tokens
        )

        # Build the complete system prompt
        system_parts = []

        # 1. Persona's base prompt
        system_parts.append(persona.system_prompt)

        # 2. Spoiler prevention instruction
        spoiler_instruction = self.SPOILER_BOUNDARY_INSTRUCTION.format(
            chapter=chapter,
            timestamp=self._format_timestamp(timestamp_seconds)
        )
        system_parts.append(spoiler_instruction)

        # 3. Book context (if available)
        if context.text:
            context_section = self.CONTEXT_HEADER + context.text
            system_parts.append(context_section)

            # Add truncation notice if needed
            if context.truncated:
                system_parts.append(
                    f"\n[Note: Earlier chapters were truncated. "
                    f"Context includes chapters {context.chapters_included}]"
                )

        full_system_prompt = "\n\n".join(system_parts)

        return BuiltPrompt(
            system_prompt=full_system_prompt,
            persona=persona,
            context=context
        )

    async def build_simple(
        self,
        persona_id: str,
        book_id: Optional[str] = None
    ) -> Optional[BuiltPrompt]:
        """
        Build a simple prompt without book context.

        Useful for general questions to global personas
        when not reading a specific book.
        """
        persona = await self.persona_manager.get_persona(persona_id, book_id)
        if not persona:
            return None

        # Create empty context
        empty_context = ContextResult(
            text="",
            token_estimate=0,
            chapters_included=[],
            current_chapter=0,
            current_timestamp=0.0,
            truncated=False,
            retrieval_method="none"
        )

        return BuiltPrompt(
            system_prompt=persona.system_prompt,
            persona=persona,
            context=empty_context
        )
