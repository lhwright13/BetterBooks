"""
JSON-based Context Retriever

Loads transcript.json files from book folders and retrieves
text up to a given timestamp. Simple and effective for MVP.

With runtime transcription fallback:
- First checks for pre-existing transcript.json
- If not found or incomplete, falls back to runtime transcription
- Merges cached runtime transcripts with any existing transcript data
"""

import json
import logging
import os
from pathlib import Path
from typing import Dict, List, Optional

from .interfaces import IContextRetriever, ContextResult

logger = logging.getLogger(__name__)


class JsonContextRetriever(IContextRetriever):
    """
    Retrieves book context from JSON transcript files.

    Expects transcripts at: {book_files_path}/{book_id}/transcript.json

    If transcript.json is missing or incomplete, can fall back to
    runtime transcription using the RuntimeTranscriber.
    """

    def __init__(
        self,
        book_files_path: str,
        enable_runtime_transcription: bool = True,
        transcription_backend: str = "local"
    ):
        """
        Initialize the retriever.

        Args:
            book_files_path: Path to the book_files directory
            enable_runtime_transcription: If True, transcribe on-demand when
                                          transcript.json is missing
            transcription_backend: Backend for runtime transcription
                                   ("local", "openai", "azure")
        """
        self.book_files_path = Path(book_files_path)
        self._cache: Dict[str, dict] = {}  # Cache loaded transcripts
        self._enable_runtime = enable_runtime_transcription
        self._transcription_backend = transcription_backend
        self._runtime_transcriber = None  # Lazy initialization

    def _get_runtime_transcriber(self):
        """Lazy-load the runtime transcriber."""
        if self._runtime_transcriber is None and self._enable_runtime:
            try:
                from .runtime_transcriber import create_transcriber
                self._runtime_transcriber = create_transcriber(
                    book_files_path=str(self.book_files_path),
                    backend=self._transcription_backend
                )
                logger.info(
                    f"Runtime transcriber initialized with {self._transcription_backend} backend"
                )
            except Exception as e:
                logger.warning(f"Failed to initialize runtime transcriber: {e}")
                self._enable_runtime = False
        return self._runtime_transcriber

    def _get_transcript_path(self, book_id: str) -> Path:
        """Get the path to a book's transcript file."""
        return self.book_files_path / book_id / "transcript.json"

    def _is_placeholder_transcript(self, transcript: dict) -> bool:
        """
        Check if a transcript is a placeholder (not real transcription).

        Placeholder transcripts have a "note" field or very short chunk text.
        """
        if transcript.get("note"):
            return True

        # Check if chunks have real content (more than 100 chars average)
        total_chars = 0
        total_chunks = 0
        for chapter in transcript.get("chapters", []):
            for chunk in chapter.get("chunks", []):
                total_chars += len(chunk.get("text", ""))
                total_chunks += 1

        if total_chunks > 0:
            avg_chars = total_chars / total_chunks
            # Real transcripts have substantial text per chunk
            if avg_chars < 100:
                return True

        return False

    def _load_transcript(self, book_id: str) -> Optional[dict]:
        """Load and cache a transcript file."""
        if book_id in self._cache:
            return self._cache[book_id]

        transcript_path = self._get_transcript_path(book_id)
        if not transcript_path.exists():
            return None

        with open(transcript_path, "r", encoding="utf-8") as f:
            transcript = json.load(f)
            self._cache[book_id] = transcript
            return transcript

    def _estimate_tokens(self, text: str) -> int:
        """Rough token estimation (4 chars per token on average)."""
        return len(text) // 4

    async def get_context(
        self,
        book_id: str,
        chapter: int,
        timestamp_seconds: float,
        max_tokens: int = 16000
    ) -> ContextResult:
        """
        Retrieve all text up to the given chapter and timestamp.

        This is the core spoiler prevention mechanism - we only return
        text the user has already heard.

        Fallback behavior:
        1. Try to load transcript.json
        2. If missing or placeholder, attempt runtime transcription
        3. Merge runtime results with any existing data
        """
        transcript = self._load_transcript(book_id)

        # Check if we need runtime transcription
        use_runtime = False
        if transcript is None:
            use_runtime = True
            logger.info(f"No transcript.json for {book_id}, will try runtime transcription")
        elif self._is_placeholder_transcript(transcript):
            use_runtime = True
            logger.info(f"Placeholder transcript for {book_id}, will try runtime transcription")

        # Attempt runtime transcription if needed
        if use_runtime and self._enable_runtime:
            runtime_result = await self._get_runtime_context(
                book_id, chapter, timestamp_seconds, max_tokens
            )
            if runtime_result is not None:
                return runtime_result
            logger.warning(
                f"Runtime transcription failed for {book_id}, "
                "falling back to available data"
            )

        # No transcript available at all
        if not transcript:
            return ContextResult(
                text="",
                token_estimate=0,
                chapters_included=[],
                current_chapter=chapter,
                current_timestamp=timestamp_seconds,
                truncated=False,
                retrieval_method="json"
            )

        text_parts = []
        chapters_included = []

        for chapter_data in transcript.get("chapters", []):
            chapter_num = chapter_data.get("chapter", 0)

            # Skip chapters after current
            if chapter_num > chapter:
                break

            chapter_text_parts = []

            for chunk in chapter_data.get("chunks", []):
                chunk_start = chunk.get("start", 0)
                chunk_text = chunk.get("text", "")

                # For current chapter, only include chunks up to timestamp
                # Special case: when timestamp is 0, include the first chunk
                # (user just started, give them initial context)
                if chapter_num == chapter:
                    if chunk_start > timestamp_seconds and timestamp_seconds > 0:
                        break
                    elif chunk_start > timestamp_seconds and timestamp_seconds == 0:
                        # Include first chunk at timestamp 0, then stop
                        chapter_text_parts.append(chunk_text)
                        break

                chapter_text_parts.append(chunk_text)

            if chapter_text_parts:
                # Add chapter marker for clarity
                chapter_title = chapter_data.get("title", f"Chapter {chapter_num}")
                chapter_text = f"\n\n=== {chapter_title} ===\n\n" + " ".join(chapter_text_parts)
                text_parts.append(chapter_text)
                chapters_included.append(chapter_num)

        full_text = "".join(text_parts).strip()
        token_estimate = self._estimate_tokens(full_text)
        truncated = False

        # Truncate from the beginning if too long
        if token_estimate > max_tokens:
            # Keep removing oldest chapters until we're under budget
            while token_estimate > max_tokens and len(text_parts) > 1:
                text_parts.pop(0)
                chapters_included.pop(0)
                full_text = "".join(text_parts).strip()
                token_estimate = self._estimate_tokens(full_text)
                truncated = True

        return ContextResult(
            text=full_text,
            token_estimate=token_estimate,
            chapters_included=chapters_included,
            current_chapter=chapter,
            current_timestamp=timestamp_seconds,
            truncated=truncated,
            retrieval_method="json"
        )

    async def _get_runtime_context(
        self,
        book_id: str,
        chapter: int,
        timestamp_seconds: float,
        max_tokens: int
    ) -> Optional[ContextResult]:
        """
        Get context using runtime transcription.

        Returns None if transcription is not available or fails.
        """
        transcriber = self._get_runtime_transcriber()
        if transcriber is None:
            return None

        try:
            # Transcribe up to the requested position
            chunks = await transcriber.transcribe_up_to(
                book_id=book_id,
                chapter=chapter,
                timestamp_seconds=timestamp_seconds
            )

            if not chunks:
                return None

            # Group chunks by chapter
            chapters_data: Dict[int, List[dict]] = {}
            for chunk in chunks:
                chap = chunk.get("chapter", 1)
                if chap not in chapters_data:
                    chapters_data[chap] = []
                chapters_data[chap].append(chunk)

            # Build text parts
            text_parts = []
            chapters_included = []

            for chap_num in sorted(chapters_data.keys()):
                chapter_chunks = chapters_data[chap_num]
                chapter_text_parts = [c.get("text", "") for c in chapter_chunks]

                if chapter_text_parts:
                    chapter_title = f"Chapter {chap_num}"
                    chapter_text = f"\n\n=== {chapter_title} ===\n\n" + " ".join(chapter_text_parts)
                    text_parts.append(chapter_text)
                    chapters_included.append(chap_num)

            full_text = "".join(text_parts).strip()
            token_estimate = self._estimate_tokens(full_text)
            truncated = False

            # Truncate from the beginning if too long
            if token_estimate > max_tokens:
                while token_estimate > max_tokens and len(text_parts) > 1:
                    text_parts.pop(0)
                    chapters_included.pop(0)
                    full_text = "".join(text_parts).strip()
                    token_estimate = self._estimate_tokens(full_text)
                    truncated = True

            return ContextResult(
                text=full_text,
                token_estimate=token_estimate,
                chapters_included=chapters_included,
                current_chapter=chapter,
                current_timestamp=timestamp_seconds,
                truncated=truncated,
                retrieval_method="runtime_transcription"
            )

        except Exception as e:
            logger.error(f"Runtime transcription error: {e}")
            return None

    async def get_chapter_count(self, book_id: str) -> int:
        """Get the total number of chapters."""
        transcript = self._load_transcript(book_id)
        if transcript:
            return len(transcript.get("chapters", []))

        # Fallback: count audio files
        book_dir = self.book_files_path / book_id
        if book_dir.exists():
            mp3_count = len(list(book_dir.glob("*.mp3")))
            if mp3_count > 0:
                return mp3_count

        return 0

    async def has_transcript(self, book_id: str) -> bool:
        """
        Check if transcript is available.

        Returns True if either:
        - transcript.json exists (even if placeholder)
        - Runtime transcription is available and book has audio files
        """
        if self._get_transcript_path(book_id).exists():
            return True

        # Check if runtime transcription is possible
        if self._enable_runtime:
            book_dir = self.book_files_path / book_id
            if book_dir.exists():
                mp3_files = list(book_dir.glob("*.mp3"))
                if mp3_files:
                    transcriber = self._get_runtime_transcriber()
                    if transcriber is not None:
                        return True

        return False

    def get_transcription_status(self, book_id: str) -> dict:
        """
        Get detailed transcription status for a book.

        Returns info about available transcripts and runtime capability.
        """
        status = {
            "book_id": book_id,
            "has_json_transcript": self._get_transcript_path(book_id).exists(),
            "is_placeholder": False,
            "runtime_available": False,
            "runtime_backend": self._transcription_backend,
            "audio_files": 0
        }

        # Check transcript quality
        transcript = self._load_transcript(book_id)
        if transcript:
            status["is_placeholder"] = self._is_placeholder_transcript(transcript)
            status["json_chapters"] = len(transcript.get("chapters", []))

        # Check audio files
        book_dir = self.book_files_path / book_id
        if book_dir.exists():
            status["audio_files"] = len(list(book_dir.glob("*.mp3")))

        # Check runtime capability
        if self._enable_runtime:
            transcriber = self._get_runtime_transcriber()
            if transcriber is not None:
                status["runtime_available"] = True
                runtime_status = transcriber.get_transcript_status(book_id)
                status["runtime_cache"] = runtime_status

        return status

    def clear_cache(self):
        """Clear the transcript cache (both JSON and runtime)."""
        self._cache.clear()
        if self._runtime_transcriber is not None:
            self._runtime_transcriber.clear_cache()
