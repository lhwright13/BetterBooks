from typing import Optional
from dataclasses import dataclass

from context import IContextRetriever, ContextResult
from personas import IPersonaManager, PersonaConfig


@dataclass
class BuiltPrompt:
    system_prompt: str
    persona: PersonaConfig
    context: ContextResult


class PromptBuilder:

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

    def __init__(self, context_retriever: IContextRetriever, persona_manager: IPersonaManager):
        self.context_retriever = context_retriever
        self.persona_manager = persona_manager

    def _format_timestamp(self, seconds: float) -> str:
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
        persona = await self.persona_manager.get_persona(persona_id, book_id)
        if not persona:
            return None

        context = await self.context_retriever.get_context(
            book_id=book_id,
            chapter=chapter,
            timestamp_seconds=timestamp_seconds,
            max_tokens=max_context_tokens
        )

        system_parts = [
            persona.system_prompt,
            self.SPOILER_BOUNDARY_INSTRUCTION.format(
                chapter=chapter,
                timestamp=self._format_timestamp(timestamp_seconds)
            ),
        ]

        if context.text:
            system_parts.append(self.CONTEXT_HEADER + context.text)
            if context.truncated:
                system_parts.append(
                    f"\n[Note: Earlier chapters were truncated. "
                    f"Context includes chapters {context.chapters_included}]"
                )

        return BuiltPrompt(
            system_prompt="\n\n".join(system_parts),
            persona=persona,
            context=context
        )

    async def build_simple(
        self,
        persona_id: str,
        book_id: Optional[str] = None
    ) -> Optional[BuiltPrompt]:
        persona = await self.persona_manager.get_persona(persona_id, book_id)
        if not persona:
            return None

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
