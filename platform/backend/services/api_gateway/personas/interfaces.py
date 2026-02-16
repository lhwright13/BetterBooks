from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class VoiceConfig:
    provider: str = "azure"
    voice_id: str = "en-US-AriaNeural"
    style: Optional[str] = None
    rate: float = 1.0
    pitch: Optional[str] = None


@dataclass
class PersonaConfig:
    id: str
    name: str
    type: str
    system_prompt: str
    temperature: float = 0.7
    description: str = ""
    avatar: Optional[str] = None
    voice: VoiceConfig = field(default_factory=VoiceConfig)
    book_id: Optional[str] = None


class IPersonaManager(ABC):

    @abstractmethod
    async def get_persona(
        self,
        persona_id: str,
        book_id: Optional[str] = None
    ) -> Optional[PersonaConfig]:
        pass

    @abstractmethod
    async def get_personas_for_book(self, book_id: str) -> List[PersonaConfig]:
        pass

    @abstractmethod
    async def get_global_personas(self) -> List[PersonaConfig]:
        pass
