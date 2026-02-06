"""
Persona Manager Interfaces

Defines the contract for loading and managing AI personas.
Personas can be book-specific characters or global helpers.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class VoiceConfig:
    """TTS voice configuration for a persona."""
    provider: str = "azure"            # "azure", "elevenlabs", "openai"
    voice_id: str = "en-US-AriaNeural" # Provider-specific voice ID
    style: Optional[str] = None        # Azure-specific style
    rate: float = 1.0                  # Speaking rate (0.5 - 2.0)
    pitch: Optional[str] = None        # Pitch adjustment


@dataclass
class PersonaConfig:
    """Configuration for an AI persona."""
    id: str                            # Unique identifier
    name: str                          # Display name
    type: str                          # "character" or "guide"
    system_prompt: str                 # The full system prompt
    temperature: float = 0.7           # LLM temperature
    description: str = ""              # Short description for UI
    avatar: Optional[str] = None       # Avatar image filename
    voice: VoiceConfig = field(default_factory=VoiceConfig)
    book_id: Optional[str] = None      # None for global personas


class IPersonaManager(ABC):
    """
    Interface for managing personas.

    Loads personas from various sources (JSON files, database, API).
    Merges book-specific personas with global personas.
    """

    @abstractmethod
    async def get_persona(
        self,
        persona_id: str,
        book_id: Optional[str] = None
    ) -> Optional[PersonaConfig]:
        """
        Get a specific persona by ID.

        Args:
            persona_id: The persona's unique identifier
            book_id: Optional book ID to check book-specific personas first

        Returns:
            PersonaConfig if found, None otherwise
        """
        pass

    @abstractmethod
    async def get_personas_for_book(self, book_id: str) -> List[PersonaConfig]:
        """
        Get all personas available for a specific book.

        Returns both book-specific personas (characters) and
        global personas (helpers/teachers).

        Args:
            book_id: The book's identifier

        Returns:
            List of all available personas, book-specific first
        """
        pass

    @abstractmethod
    async def get_global_personas(self) -> List[PersonaConfig]:
        """Get all global personas (available for any book)."""
        pass
