from dataclasses import dataclass, field
from typing import List, Optional
from enum import Enum


class MessageRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


@dataclass
class ChatMessage:
    role: MessageRole
    content: str


@dataclass
class ChatRequest:
    book_id: str
    chapter: int
    timestamp_seconds: float
    persona_id: str
    message: str
    conversation_history: List[ChatMessage] = field(default_factory=list)


@dataclass
class ChatResponse:
    message: str
    persona_id: str
    persona_name: str
    chapters_used: List[int]
    token_estimate: int
    voice_config: Optional[dict] = None
