import json
import logging
from pathlib import Path
from typing import Dict, List, Optional

from .interfaces import IContextRetriever, ContextResult

logger = logging.getLogger(__name__)


class JsonContextRetriever(IContextRetriever):

    def __init__(
        self,
        book_files_path: str,
        enable_runtime_transcription: bool = True,
        transcription_backend: str = "local"
    ):
        self.book_files_path = Path(book_files_path)
        self._cache: Dict[str, dict] = {}
        self._enable_runtime = enable_runtime_transcription
        self._transcription_backend = transcription_backend
        self._runtime_transcriber = None

    def _get_runtime_transcriber(self):
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
        return self.book_files_path / book_id / "transcript.json"

    def _is_placeholder_transcript(self, transcript: dict) -> bool:
        total_chars = 0
        total_chunks = 0
        for chapter in transcript.get("chapters", []):
            for chunk in chapter.get("chunks", []):
                total_chars += len(chunk.get("text", ""))
                total_chunks += 1

        if total_chunks == 0:
            return True

        return total_chars / total_chunks < 100

    def _load_transcript(self, book_id: str) -> Optional[dict]:
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
        return len(text) // 4

    def _truncate_to_budget(self, text_parts, chapters_included, max_tokens):
        full_text = "".join(text_parts).strip()
        token_estimate = self._estimate_tokens(full_text)
        truncated = False

        while token_estimate > max_tokens and len(text_parts) > 1:
            text_parts.pop(0)
            chapters_included.pop(0)
            full_text = "".join(text_parts).strip()
            token_estimate = self._estimate_tokens(full_text)
            truncated = True

        return full_text, token_estimate, truncated

    def _empty_result(self, chapter, timestamp_seconds, method="json"):
        return ContextResult(
            text="",
            token_estimate=0,
            chapters_included=[],
            current_chapter=chapter,
            current_timestamp=timestamp_seconds,
            truncated=False,
            retrieval_method=method
        )

    async def get_context(
        self,
        book_id: str,
        chapter: int,
        timestamp_seconds: float,
        max_tokens: int = 16000
    ) -> ContextResult:
        transcript = self._load_transcript(book_id)

        needs_runtime = (
            transcript is None or self._is_placeholder_transcript(transcript)
        )

        if needs_runtime:
            logger.info(f"No usable transcript for {book_id}, will try runtime transcription")

        if needs_runtime and self._enable_runtime:
            runtime_result = await self._get_runtime_context(
                book_id, chapter, timestamp_seconds, max_tokens
            )
            if runtime_result is not None:
                return runtime_result
            logger.warning(
                f"Runtime transcription failed for {book_id}, "
                "falling back to available data"
            )

        if not transcript:
            return self._empty_result(chapter, timestamp_seconds)

        text_parts = []
        chapters_included = []

        for chapter_data in transcript.get("chapters", []):
            chapter_num = chapter_data.get("chapter", 0)

            if chapter_num > chapter:
                break

            chapter_text_parts = []

            for chunk in chapter_data.get("chunks", []):
                chunk_start = chunk.get("start", 0)
                chunk_text = chunk.get("text", "")

                if chapter_num == chapter and chunk_start > timestamp_seconds:
                    if timestamp_seconds == 0:
                        chapter_text_parts.append(chunk_text)
                    break

                chapter_text_parts.append(chunk_text)

            if chapter_text_parts:
                chapter_title = chapter_data.get("title", f"Chapter {chapter_num}")
                chapter_text = f"\n\n=== {chapter_title} ===\n\n" + " ".join(chapter_text_parts)
                text_parts.append(chapter_text)
                chapters_included.append(chapter_num)

        full_text, token_estimate, truncated = self._truncate_to_budget(
            text_parts, chapters_included, max_tokens
        )

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
        transcriber = self._get_runtime_transcriber()
        if transcriber is None:
            return None

        try:
            chunks = await transcriber.transcribe_up_to(
                book_id=book_id,
                chapter=chapter,
                timestamp_seconds=timestamp_seconds
            )

            if not chunks:
                return None

            chapters_data: Dict[int, List[dict]] = {}
            for chunk in chunks:
                chap = chunk.get("chapter", 1)
                if chap not in chapters_data:
                    chapters_data[chap] = []
                chapters_data[chap].append(chunk)

            text_parts = []
            chapters_included = []

            for chap_num in sorted(chapters_data.keys()):
                chapter_text_parts = [
                    c.get("text", "") for c in chapters_data[chap_num]
                ]
                if chapter_text_parts:
                    chapter_text = f"\n\n=== Chapter {chap_num} ===\n\n" + " ".join(chapter_text_parts)
                    text_parts.append(chapter_text)
                    chapters_included.append(chap_num)

            full_text, token_estimate, truncated = self._truncate_to_budget(
                text_parts, chapters_included, max_tokens
            )

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
        transcript = self._load_transcript(book_id)
        if transcript:
            return len(transcript.get("chapters", []))

        book_dir = self.book_files_path / book_id
        if book_dir.exists():
            mp3_count = len(list(book_dir.glob("*.mp3")))
            if mp3_count > 0:
                return mp3_count

        return 0

    async def has_transcript(self, book_id: str) -> bool:
        if self._get_transcript_path(book_id).exists():
            return True

        if self._enable_runtime:
            book_dir = self.book_files_path / book_id
            if book_dir.exists() and list(book_dir.glob("*.mp3")):
                if self._get_runtime_transcriber() is not None:
                    return True

        return False

    def get_transcription_status(self, book_id: str) -> dict:
        status = {
            "book_id": book_id,
            "has_json_transcript": self._get_transcript_path(book_id).exists(),
            "is_placeholder": False,
            "runtime_available": False,
            "runtime_backend": self._transcription_backend,
            "audio_files": 0
        }

        transcript = self._load_transcript(book_id)
        if transcript:
            status["is_placeholder"] = self._is_placeholder_transcript(transcript)
            status["json_chapters"] = len(transcript.get("chapters", []))

        book_dir = self.book_files_path / book_id
        if book_dir.exists():
            status["audio_files"] = len(list(book_dir.glob("*.mp3")))

        if self._enable_runtime:
            transcriber = self._get_runtime_transcriber()
            if transcriber is not None:
                status["runtime_available"] = True
                status["runtime_cache"] = transcriber.get_transcript_status(book_id)

        return status

    def clear_cache(self):
        self._cache.clear()
        if self._runtime_transcriber is not None:
            self._runtime_transcriber.clear_cache()
