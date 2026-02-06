"""
Chat Data Models

Request and response models for the AI chat endpoint.
"""

from dataclasses import dataclass, field
from typing import List, Optional
from enum import Enum


class MessageRole(str, Enum):
    """Role in a chat message."""
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


@dataclass
class ChatMessage:
    """A single message in a conversation."""
    role: MessageRole
    content: str


@dataclass
class ChatRequest:
    """Request to the /ai/chat endpoint."""
    book_id: str                          # Which book the user is reading
    chapter: int                          # Current chapter number
    timestamp_seconds: float              # Current position in chapter
    persona_id: str                       # Which persona to chat with
    message: str                          # User's question
    conversation_history: List[ChatMessage] = field(default_factory=list)  # Previous messages


@dataclass
class ChatResponse:
    """Response from the /ai/chat endpoint."""
    message: str                          # AI's response
    persona_id: str                       # Which persona responded
    persona_name: str                     # Display name for UI
    chapters_used: List[int]             # Which chapters were in context
    token_estimate: int                   # Estimated tokens used for context
    voice_config: Optional[dict] = None   # Voice settings for TTS (if needed)
