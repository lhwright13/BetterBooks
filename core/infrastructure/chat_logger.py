"""
Chat Logger for AI Chat Observability

Provides structured logging for AI chat interactions:
- Terminal output: Colored, formatted summary for development
- JSON file logging: Full interaction details for historical review
"""

import json
import logging
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any
from dataclasses import dataclass, field, asdict

logger = logging.getLogger(__name__)


# ANSI color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    RESET = '\033[0m'

    # Box drawing characters
    TOP_LEFT = '\u250c'
    TOP_RIGHT = '\u2510'
    BOTTOM_LEFT = '\u2514'
    BOTTOM_RIGHT = '\u2518'
    HORIZONTAL = '\u2500'
    VERTICAL = '\u2502'
    TEE_RIGHT = '\u251c'


@dataclass
class ChatInteraction:
    """Complete record of a chat interaction"""
    request_id: str
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"))

    # User info
    user_id: Optional[str] = None
    user_message: Optional[str] = None

    # Context info
    book_id: Optional[str] = None
    chapter: Optional[int] = None
    timestamp_seconds: Optional[float] = None
    persona_id: Optional[str] = None
    persona_name: Optional[str] = None
    chapters_included: List[int] = field(default_factory=list)
    token_estimate: Optional[int] = None
    system_prompt: Optional[str] = None

    # Response info
    response_text: Optional[str] = None
    response_latency_ms: Optional[float] = None
    model: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            "request_id": self.request_id,
            "timestamp": self.timestamp,
            "user": {
                "id": self.user_id,
                "message": self.user_message
            },
            "context": {
                "book_id": self.book_id,
                "chapter": self.chapter,
                "timestamp_seconds": self.timestamp_seconds,
                "persona_id": self.persona_id,
                "persona_name": self.persona_name,
                "chapters_included": self.chapters_included,
                "token_estimate": self.token_estimate,
                "system_prompt": self.system_prompt
            },
            "response": {
                "text": self.response_text,
                "latency_ms": self.response_latency_ms,
                "model": self.model
            }
        }


class ChatLogger:
    """
    Logger for AI chat interactions with terminal and file output.

    Usage:
        chat_logger = ChatLogger()

        # Start a new interaction
        chat_logger.log_request(request_id, user_message, book_id, chapter, persona_id, user_id)

        # Log context after prompt building
        chat_logger.log_context(request_id, system_prompt, chapters_included, token_estimate, persona_name)

        # Log response after LLM call
        chat_logger.log_response(request_id, response_text, latency_ms, model)

        # Complete the interaction (writes to file)
        chat_logger.log_complete(request_id)
    """

    def __init__(self, log_dir: Optional[str] = None):
        self.enabled = os.getenv("CHAT_LOG_ENABLED", "true").lower() == "true"
        self.log_level = os.getenv("CHAT_LOG_LEVEL", "full")  # "summary" or "full"

        # Determine log directory
        if log_dir:
            self.log_dir = Path(log_dir)
        else:
            self.log_dir = Path(os.getenv("CHAT_LOG_DIR", "./logs/chat_interactions"))

        # Create log directory if needed
        if self.enabled and self.log_level == "full":
            self.log_dir.mkdir(parents=True, exist_ok=True)

        # Store in-progress interactions
        self._interactions: Dict[str, ChatInteraction] = {}

        # Check if terminal supports colors
        self._use_colors = sys.stdout.isatty()

    def _color(self, text: str, color: str) -> str:
        """Apply color if terminal supports it"""
        if self._use_colors:
            return f"{color}{text}{Colors.RESET}"
        return text

    def _format_time(self, seconds: float) -> str:
        """Format timestamp_seconds as mm:ss"""
        minutes = int(seconds // 60)
        secs = int(seconds % 60)
        return f"{minutes}:{secs:02d}"

    def _truncate(self, text: str, max_len: int = 80) -> str:
        """Truncate text with ellipsis"""
        if len(text) <= max_len:
            return text
        return text[:max_len - 3] + "..."

    def log_request(
        self,
        request_id: str,
        user_message: str,
        book_id: str,
        chapter: int,
        timestamp_seconds: float,
        persona_id: str,
        user_id: Optional[str] = None
    ):
        """Log incoming chat request"""
        if not self.enabled:
            return

        # Create interaction record
        interaction = ChatInteraction(
            request_id=request_id,
            user_id=user_id,
            user_message=user_message,
            book_id=book_id,
            chapter=chapter,
            timestamp_seconds=timestamp_seconds,
            persona_id=persona_id
        )
        self._interactions[request_id] = interaction

        # Terminal output
        header = f"{Colors.TOP_LEFT}{Colors.HORIZONTAL} CHAT [{request_id}] "
        header += Colors.HORIZONTAL * (60 - len(f" CHAT [{request_id}] "))
        print(self._color(header, Colors.CYAN))

        # User message
        msg_display = self._truncate(user_message.replace('\n', ' '), 60)
        print(self._color(f"{Colors.VERTICAL} ", Colors.CYAN) +
              self._color("User: ", Colors.BOLD) +
              f'"{msg_display}"')

        # Book/chapter/persona info
        time_str = self._format_time(timestamp_seconds)
        print(self._color(f"{Colors.VERTICAL} ", Colors.CYAN) +
              f"Book: {book_id} | Chapter: {chapter} @ {time_str} | Persona: {persona_id}")

    def log_context(
        self,
        request_id: str,
        system_prompt: str,
        chapters_included: List[int],
        token_estimate: int,
        persona_name: Optional[str] = None,
        timestamp_seconds: Optional[float] = None
    ):
        """Log context/prompt building details"""
        if not self.enabled:
            return

        interaction = self._interactions.get(request_id)
        if interaction:
            interaction.system_prompt = system_prompt
            interaction.chapters_included = chapters_included
            interaction.token_estimate = token_estimate
            if persona_name:
                interaction.persona_name = persona_name

        # Terminal output
        print(self._color(f"{Colors.TEE_RIGHT}{Colors.HORIZONTAL} Context ", Colors.CYAN) +
              self._color(Colors.HORIZONTAL * 52, Colors.CYAN))

        chapters_str = str(chapters_included) if len(chapters_included) <= 5 else f"[{chapters_included[0]}...{chapters_included[-1]}]"
        print(self._color(f"{Colors.VERTICAL} ", Colors.CYAN) +
              f"Chapters: {chapters_str} | Tokens: ~{token_estimate:,}")

        if timestamp_seconds:
            print(self._color(f"{Colors.VERTICAL} ", Colors.CYAN) +
                  self._color(f"Spoiler Limit: Chapter {interaction.chapter if interaction else '?'}, {self._format_time(timestamp_seconds)}", Colors.DIM))

    def log_response(
        self,
        request_id: str,
        response_text: str,
        latency_ms: float,
        model: Optional[str] = None
    ):
        """Log LLM response"""
        if not self.enabled:
            return

        interaction = self._interactions.get(request_id)
        if interaction:
            interaction.response_text = response_text
            interaction.response_latency_ms = latency_ms
            interaction.model = model

        # Terminal output
        print(self._color(f"{Colors.TEE_RIGHT}{Colors.HORIZONTAL} Response ", Colors.CYAN) +
              self._color(Colors.HORIZONTAL * 51, Colors.CYAN))

        # Show response preview (first 200 chars, cleaned up)
        response_preview = response_text.replace('\n', ' ').strip()
        response_preview = self._truncate(response_preview, 200)
        print(self._color(f"{Colors.VERTICAL} ", Colors.CYAN) +
              self._color(f'"{response_preview}"', Colors.GREEN))

        # Metadata line
        model_str = model if model else "unknown"
        latency_str = f"{latency_ms/1000:.1f}s" if latency_ms >= 1000 else f"{int(latency_ms)}ms"
        print(self._color(f"{Colors.VERTICAL} ", Colors.CYAN) +
              self._color(f"[{len(response_text)} chars | {latency_str} | {model_str}]", Colors.DIM))

    def log_complete(self, request_id: str):
        """Complete the interaction and write to file"""
        if not self.enabled:
            return

        # Close the box
        footer = f"{Colors.BOTTOM_LEFT}" + Colors.HORIZONTAL * 62
        print(self._color(footer, Colors.CYAN))
        print()  # Blank line after each interaction

        # Write to file if full logging enabled
        if self.log_level == "full":
            interaction = self._interactions.get(request_id)
            if interaction:
                self._write_to_file(interaction)

        # Clean up
        self._interactions.pop(request_id, None)

    def log_error(self, request_id: str, error: str):
        """Log an error that occurred during the interaction"""
        if not self.enabled:
            return

        print(self._color(f"{Colors.TEE_RIGHT}{Colors.HORIZONTAL} ERROR ", Colors.RED) +
              self._color(Colors.HORIZONTAL * 53, Colors.RED))
        print(self._color(f"{Colors.VERTICAL} ", Colors.RED) +
              self._color(error, Colors.RED))

        # Still close the box
        footer = f"{Colors.BOTTOM_LEFT}" + Colors.HORIZONTAL * 62
        print(self._color(footer, Colors.RED))
        print()

        # Clean up
        self._interactions.pop(request_id, None)

    def _write_to_file(self, interaction: ChatInteraction):
        """Write interaction to JSON Lines file"""
        try:
            # Get today's log file
            today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
            log_file = self.log_dir / f"{today}.jsonl"

            # Append interaction as JSON line
            with open(log_file, "a", encoding="utf-8") as f:
                json.dump(interaction.to_dict(), f, ensure_ascii=False)
                f.write("\n")

        except Exception as e:
            logger.error(f"Failed to write chat log: {e}")


# Global instance
_chat_logger: Optional[ChatLogger] = None


def get_chat_logger() -> ChatLogger:
    """Get or create the global ChatLogger instance"""
    global _chat_logger
    if _chat_logger is None:
        _chat_logger = ChatLogger()
    return _chat_logger
