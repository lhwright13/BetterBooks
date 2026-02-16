import os
import json
import hashlib
import logging
import asyncio
import subprocess
import tempfile
from abc import ABC, abstractmethod
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import List, Optional, Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)


def _extract_audio_segment(audio_path: Path, start_time: float, end_time: Optional[float]) -> Path:
    try:
        suffix = audio_path.suffix
        temp_fd, temp_path = tempfile.mkstemp(suffix=suffix)
        os.close(temp_fd)

        cmd = ["ffmpeg", "-y", "-i", str(audio_path), "-ss", str(start_time)]
        if end_time is not None:
            cmd.extend(["-to", str(end_time)])
        cmd.extend(["-c", "copy", temp_path])

        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            logger.warning(f"ffmpeg segment extraction failed: {result.stderr}")
            return audio_path

        return Path(temp_path)

    except FileNotFoundError:
        logger.warning("ffmpeg not found, transcribing full file")
        return audio_path
    except Exception as e:
        logger.warning(f"Segment extraction failed: {e}")
        return audio_path


@dataclass
class TranscriptChunk:
    index: int
    start: float
    end: float
    text: str

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class ChapterTranscript:
    chapter: int
    title: str
    duration_seconds: float
    chunks: List[TranscriptChunk] = field(default_factory=list)
    complete: bool = False
    last_transcribed_timestamp: float = 0.0

    def to_dict(self) -> dict:
        return {
            "chapter": self.chapter,
            "title": self.title,
            "duration_seconds": self.duration_seconds,
            "chunks": [c.to_dict() for c in self.chunks],
            "complete": self.complete,
            "last_transcribed_timestamp": self.last_transcribed_timestamp
        }

    @classmethod
    def from_dict(cls, data: dict) -> "ChapterTranscript":
        chunks = [
            TranscriptChunk(**c) if isinstance(c, dict) else c
            for c in data.get("chunks", [])
        ]
        return cls(
            chapter=data["chapter"],
            title=data.get("title", f"Chapter {data['chapter']}"),
            duration_seconds=data.get("duration_seconds", 0),
            chunks=chunks,
            complete=data.get("complete", False),
            last_transcribed_timestamp=data.get("last_transcribed_timestamp", 0.0)
        )


@dataclass
class BookTranscriptCache:
    book_id: str
    title: str
    author: str
    chapters: Dict[int, ChapterTranscript] = field(default_factory=dict)
    last_updated: str = ""
    backend_used: str = ""

    def to_dict(self) -> dict:
        return {
            "book_id": self.book_id,
            "title": self.title,
            "author": self.author,
            "chapters": {
                str(k): v.to_dict() for k, v in self.chapters.items()
            },
            "last_updated": self.last_updated,
            "backend_used": self.backend_used
        }

    @classmethod
    def from_dict(cls, data: dict) -> "BookTranscriptCache":
        chapters = {
            int(k): ChapterTranscript.from_dict(v)
            for k, v in data.get("chapters", {}).items()
        }
        return cls(
            book_id=data["book_id"],
            title=data.get("title", ""),
            author=data.get("author", ""),
            chapters=chapters,
            last_updated=data.get("last_updated", ""),
            backend_used=data.get("backend_used", "")
        )


class TranscriptionBackend(ABC):

    @abstractmethod
    async def transcribe(
        self,
        audio_path: Path,
        start_time: float = 0,
        end_time: Optional[float] = None
    ) -> List[TranscriptChunk]:
        pass

    @abstractmethod
    def is_available(self) -> bool:
        pass


class LocalWhisperBackend(TranscriptionBackend):

    def __init__(self, model_name: str = "base"):
        self.model_name = model_name
        self._model = None
        self._whisper_available = None

    def is_available(self) -> bool:
        if self._whisper_available is not None:
            return self._whisper_available

        try:
            import whisper
            self._whisper_available = True
        except ImportError:
            logger.warning(
                "openai-whisper not installed. Install with: pip install openai-whisper"
            )
            self._whisper_available = False

        return self._whisper_available

    def _get_model(self):
        if self._model is None:
            import whisper
            logger.info(f"Loading Whisper model: {self.model_name}")
            self._model = whisper.load_model(self.model_name)
            logger.info("Whisper model loaded successfully")
        return self._model

    async def transcribe(
        self,
        audio_path: Path,
        start_time: float = 0,
        end_time: Optional[float] = None
    ) -> List[TranscriptChunk]:
        if not self.is_available():
            raise RuntimeError("Whisper not available")

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None, self._transcribe_sync, audio_path, start_time, end_time
        )

    def _transcribe_sync(
        self,
        audio_path: Path,
        start_time: float,
        end_time: Optional[float]
    ) -> List[TranscriptChunk]:
        import whisper

        model = self._get_model()

        if start_time > 0 or end_time is not None:
            audio_path = _extract_audio_segment(audio_path, start_time, end_time)

        result = model.transcribe(
            str(audio_path),
            word_timestamps=True,
            verbose=False
        )

        chunks = []
        offset = start_time if start_time > 0 else 0
        for i, segment in enumerate(result.get("segments", [])):
            chunks.append(TranscriptChunk(
                index=i,
                start=segment["start"] + offset,
                end=segment["end"] + offset,
                text=segment["text"].strip()
            ))

        return chunks


class OpenAIWhisperBackend(TranscriptionBackend):

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("OPENAI_API_KEY")
        self._client = None

    def is_available(self) -> bool:
        if not self.api_key:
            logger.warning("OPENAI_API_KEY not set for Whisper API")
            return False

        try:
            import openai
            return True
        except ImportError:
            logger.warning("openai package not installed")
            return False

    def _get_client(self):
        if self._client is None:
            from openai import OpenAI
            self._client = OpenAI(api_key=self.api_key)
        return self._client

    async def transcribe(
        self,
        audio_path: Path,
        start_time: float = 0,
        end_time: Optional[float] = None
    ) -> List[TranscriptChunk]:
        if not self.is_available():
            raise RuntimeError("OpenAI Whisper API not available")

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None, self._transcribe_sync, audio_path, start_time, end_time
        )

    def _transcribe_sync(
        self,
        audio_path: Path,
        start_time: float,
        end_time: Optional[float]
    ) -> List[TranscriptChunk]:
        client = self._get_client()

        if start_time > 0 or end_time is not None:
            audio_path = _extract_audio_segment(audio_path, start_time, end_time)

        with open(audio_path, "rb") as audio_file:
            response = client.audio.transcriptions.create(
                model="whisper-1",
                file=audio_file,
                response_format="verbose_json",
                timestamp_granularities=["segment"]
            )

        chunks = []
        offset = start_time if start_time > 0 else 0

        for i, segment in enumerate(response.segments or []):
            chunks.append(TranscriptChunk(
                index=i,
                start=segment.start + offset,
                end=segment.end + offset,
                text=segment.text.strip()
            ))

        return chunks


class AzureSpeechBackend(TranscriptionBackend):

    def __init__(
        self,
        speech_key: Optional[str] = None,
        speech_region: Optional[str] = None
    ):
        self.speech_key = speech_key or os.environ.get("AZURE_SPEECH_KEY")
        self.speech_region = speech_region or os.environ.get("AZURE_SPEECH_REGION")

    def is_available(self) -> bool:
        if not self.speech_key or not self.speech_region:
            logger.warning(
                "AZURE_SPEECH_KEY and AZURE_SPEECH_REGION required for Azure backend"
            )
            return False

        try:
            import azure.cognitiveservices.speech as speechsdk
            return True
        except ImportError:
            logger.warning("azure-cognitiveservices-speech not installed")
            return False

    async def transcribe(
        self,
        audio_path: Path,
        start_time: float = 0,
        end_time: Optional[float] = None
    ) -> List[TranscriptChunk]:
        if not self.is_available():
            raise RuntimeError("Azure Speech not available")

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None, self._transcribe_sync, audio_path, start_time, end_time
        )

    def _transcribe_sync(
        self,
        audio_path: Path,
        start_time: float,
        end_time: Optional[float]
    ) -> List[TranscriptChunk]:
        import time
        import azure.cognitiveservices.speech as speechsdk

        if start_time > 0 or end_time is not None:
            audio_path = _extract_audio_segment(audio_path, start_time, end_time)

        speech_config = speechsdk.SpeechConfig(
            subscription=self.speech_key,
            region=self.speech_region
        )
        speech_config.request_word_level_timestamps()

        audio_config = speechsdk.audio.AudioConfig(filename=str(audio_path))
        recognizer = speechsdk.SpeechRecognizer(
            speech_config=speech_config,
            audio_config=audio_config
        )

        chunks = []
        offset = start_time if start_time > 0 else 0
        done = False
        chunk_index = 0

        def recognized_cb(evt):
            nonlocal chunk_index
            if evt.result.reason == speechsdk.ResultReason.RecognizedSpeech:
                start = evt.result.offset / 10_000_000 + offset
                duration = evt.result.duration / 10_000_000
                chunks.append(TranscriptChunk(
                    index=chunk_index,
                    start=start,
                    end=start + duration,
                    text=evt.result.text.strip()
                ))
                chunk_index += 1

        def stop_cb(evt):
            nonlocal done
            done = True

        recognizer.recognized.connect(recognized_cb)
        recognizer.session_stopped.connect(stop_cb)
        recognizer.canceled.connect(stop_cb)

        recognizer.start_continuous_recognition()
        while not done:
            time.sleep(0.1)
        recognizer.stop_continuous_recognition()

        return chunks


class RuntimeTranscriber:

    BACKENDS = {
        "local": LocalWhisperBackend,
        "openai": OpenAIWhisperBackend,
        "azure": AzureSpeechBackend
    }

    def __init__(
        self,
        book_files_path: str,
        backend: str = "local",
        cache_dir: Optional[str] = None,
        whisper_model: str = "base"
    ):
        self.book_files_path = Path(book_files_path)
        self.backend_name = backend

        self.cache_dir = Path(cache_dir) if cache_dir else self.book_files_path / ".cache" / "transcripts"
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        if backend == "local":
            self.backend = LocalWhisperBackend(model_name=whisper_model)
        elif backend == "openai":
            self.backend = OpenAIWhisperBackend()
        elif backend == "azure":
            self.backend = AzureSpeechBackend()
        else:
            raise ValueError(f"Unknown backend: {backend}. Use: local, openai, azure")

        self._memory_cache: Dict[str, BookTranscriptCache] = {}

        logger.info(
            f"RuntimeTranscriber initialized with {backend} backend, "
            f"cache at {self.cache_dir}"
        )

    def _get_cache_path(self, book_id: str) -> Path:
        safe_id = hashlib.md5(book_id.encode()).hexdigest()[:12]
        return self.cache_dir / f"{safe_id}_transcript_cache.json"

    def _load_cache(self, book_id: str) -> Optional[BookTranscriptCache]:
        if book_id in self._memory_cache:
            return self._memory_cache[book_id]

        cache_path = self._get_cache_path(book_id)
        if cache_path.exists():
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                cache = BookTranscriptCache.from_dict(data)
                self._memory_cache[book_id] = cache
                return cache
            except Exception as e:
                logger.warning(f"Failed to load cache for {book_id}: {e}")

        return None

    def _save_cache(self, cache: BookTranscriptCache):
        cache.last_updated = datetime.now().isoformat()
        cache.backend_used = self.backend_name

        cache_path = self._get_cache_path(cache.book_id)
        try:
            with open(cache_path, "w", encoding="utf-8") as f:
                json.dump(cache.to_dict(), f, indent=2)
            self._memory_cache[cache.book_id] = cache
        except Exception as e:
            logger.error(f"Failed to save cache: {e}")

    def _get_audio_path(self, book_id: str, chapter: int) -> Optional[Path]:
        book_dir = self.book_files_path / book_id
        if not book_dir.exists():
            return None

        patterns = [
            f"*_{chapter:02d}_*.mp3",
            f"*_{chapter:02d}.mp3",
            f"chapter_{chapter:02d}*.mp3",
            f"chapter{chapter:02d}*.mp3",
            f"*_chapter_{chapter}*.mp3",
        ]

        for pattern in patterns:
            matches = list(book_dir.glob(pattern))
            if matches:
                return matches[0]

        mp3_files = sorted(book_dir.glob("*.mp3"))
        if 0 < chapter <= len(mp3_files):
            return mp3_files[chapter - 1]

        return None

    def _get_book_metadata(self, book_id: str) -> Dict[str, Any]:
        transcript_path = self.book_files_path / book_id / "transcript.json"
        if transcript_path.exists():
            try:
                with open(transcript_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                return {
                    "title": data.get("title", book_id),
                    "author": data.get("author", "Unknown"),
                    "total_chapters": data.get("total_chapters", 0)
                }
            except Exception:
                pass

        book_dir = self.book_files_path / book_id
        mp3_count = len(list(book_dir.glob("*.mp3"))) if book_dir.exists() else 0

        return {
            "title": book_id,
            "author": "Unknown",
            "total_chapters": mp3_count
        }

    def _get_or_create_cache(self, book_id: str) -> BookTranscriptCache:
        cache = self._load_cache(book_id)
        if cache is not None:
            return cache

        metadata = self._get_book_metadata(book_id)
        return BookTranscriptCache(
            book_id=book_id,
            title=metadata["title"],
            author=metadata["author"]
        )

    async def transcribe_up_to(
        self,
        book_id: str,
        chapter: int,
        timestamp_seconds: float,
        chunk_duration: float = 30.0
    ) -> List[Dict[str, Any]]:
        if not self.backend.is_available():
            logger.error(f"Transcription backend {self.backend_name} is not available")
            return []

        cache = self._get_or_create_cache(book_id)
        all_chunks = []
        needs_save = False

        for chap_num in range(1, chapter + 1):
            target_time = float("inf") if chap_num < chapter else timestamp_seconds

            chapter_cache = cache.chapters.get(chap_num)

            if chapter_cache is not None:
                if chapter_cache.complete or chapter_cache.last_transcribed_timestamp >= target_time:
                    for chunk in chapter_cache.chunks:
                        if chunk.start <= target_time:
                            all_chunks.append({"chapter": chap_num, **chunk.to_dict()})
                    continue

            audio_path = self._get_audio_path(book_id, chap_num)
            if audio_path is None:
                logger.warning(f"No audio file found for {book_id} chapter {chap_num}")
                continue

            logger.info(f"Transcribing {book_id} chapter {chap_num} up to {target_time}s")

            try:
                start_time = chapter_cache.last_transcribed_timestamp if chapter_cache else 0
                end_time = target_time if target_time != float("inf") else None

                new_chunks = await self.backend.transcribe(
                    audio_path, start_time=start_time, end_time=end_time
                )

                if chapter_cache is None:
                    chapter_cache = ChapterTranscript(
                        chapter=chap_num,
                        title=f"Chapter {chap_num}",
                        duration_seconds=0
                    )
                    cache.chapters[chap_num] = chapter_cache

                existing_count = len(chapter_cache.chunks)
                for i, chunk in enumerate(new_chunks):
                    chunk.index = existing_count + i
                    chapter_cache.chunks.append(chunk)

                if new_chunks:
                    chapter_cache.last_transcribed_timestamp = max(
                        chapter_cache.last_transcribed_timestamp,
                        new_chunks[-1].end
                    )

                if end_time is None:
                    chapter_cache.complete = True

                needs_save = True

                for chunk in chapter_cache.chunks:
                    if chunk.start <= target_time:
                        all_chunks.append({"chapter": chap_num, **chunk.to_dict()})

            except Exception as e:
                logger.error(f"Transcription failed for chapter {chap_num}: {e}")
                continue

        if needs_save:
            self._save_cache(cache)

        return all_chunks

    async def get_chapter_transcript(
        self,
        book_id: str,
        chapter: int,
        force_retranscribe: bool = False
    ) -> Optional[ChapterTranscript]:
        cache = self._load_cache(book_id)

        if not force_retranscribe and cache is not None:
            chapter_cache = cache.chapters.get(chapter)
            if chapter_cache is not None and chapter_cache.complete:
                return chapter_cache

        audio_path = self._get_audio_path(book_id, chapter)
        if audio_path is None or not self.backend.is_available():
            return None

        chunks = await self.backend.transcribe(audio_path)

        last_end = chunks[-1].end if chunks else 0
        transcript = ChapterTranscript(
            chapter=chapter,
            title=f"Chapter {chapter}",
            duration_seconds=last_end,
            chunks=chunks,
            complete=True,
            last_transcribed_timestamp=last_end
        )

        if cache is None:
            cache = self._get_or_create_cache(book_id)

        cache.chapters[chapter] = transcript
        self._save_cache(cache)

        return transcript

    def get_transcript_status(self, book_id: str) -> Dict[str, Any]:
        cache = self._load_cache(book_id)
        metadata = self._get_book_metadata(book_id)

        if cache is None:
            return {
                "book_id": book_id,
                "title": metadata["title"],
                "total_chapters": metadata["total_chapters"],
                "chapters_transcribed": 0,
                "chapters_complete": 0,
                "backend": self.backend_name,
                "backend_available": self.backend.is_available(),
                "cache_exists": False
            }

        complete_count = sum(1 for c in cache.chapters.values() if c.complete)

        return {
            "book_id": book_id,
            "title": cache.title,
            "total_chapters": metadata["total_chapters"],
            "chapters_transcribed": len(cache.chapters),
            "chapters_complete": complete_count,
            "chapters": {
                str(k): {
                    "complete": v.complete,
                    "chunks": len(v.chunks),
                    "last_timestamp": v.last_transcribed_timestamp
                }
                for k, v in cache.chapters.items()
            },
            "backend": self.backend_name,
            "backend_available": self.backend.is_available(),
            "cache_exists": True,
            "last_updated": cache.last_updated
        }

    def clear_cache(self, book_id: Optional[str] = None):
        if book_id:
            cache_path = self._get_cache_path(book_id)
            if cache_path.exists():
                cache_path.unlink()
            self._memory_cache.pop(book_id, None)
            logger.info(f"Cleared cache for {book_id}")
        else:
            for cache_file in self.cache_dir.glob("*_transcript_cache.json"):
                cache_file.unlink()
            self._memory_cache.clear()
            logger.info("Cleared all transcript caches")


def create_transcriber(
    book_files_path: str,
    backend: Optional[str] = None,
    **kwargs
) -> RuntimeTranscriber:
    if backend is None:
        backend = os.environ.get("TRANSCRIPTION_BACKEND", "local")

    whisper_model = os.environ.get("WHISPER_MODEL", "base")

    return RuntimeTranscriber(
        book_files_path=book_files_path,
        backend=backend,
        whisper_model=whisper_model,
        **kwargs
    )
