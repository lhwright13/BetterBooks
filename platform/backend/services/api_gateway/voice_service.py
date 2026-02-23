import os
import tempfile
import logging
import asyncio
import re
from typing import Tuple, AsyncGenerator, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

_whisper_model = None
_background_tasks: set = set()

USE_LOCAL_STT = os.getenv("USE_LOCAL_STT", "true").lower() == "true"
WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL_SIZE", "base")

SUPPORTED_AUDIO_EXTENSIONS = {".wav", ".mp3", ".webm", ".ogg", ".flac", ".m4a"}

# Sentence-ending pattern: period, exclamation, or question mark followed by whitespace
_SENTENCE_END_RE = re.compile(r'(?<=[.!?])\s+')

# Allowed Azure voice name pattern (letters, digits, hyphens)
_AZURE_VOICE_RE = re.compile(r'^[a-zA-Z0-9\-]+$')

# Allowed SSML style values
_AZURE_STYLES = frozenset({
    "advertisement_upbeat", "affectionate", "angry", "assistant", "calm",
    "chat", "cheerful", "customerservice", "depressed", "disgruntled",
    "documentary-narration", "embarrassed", "empathetic", "envious",
    "excited", "fearful", "friendly", "gentle", "hopeful", "lyrical",
    "narration-professional", "narration-relaxed", "newscast",
    "newscast-casual", "newscast-formal", "poetry-reading", "sad",
    "serious", "shouting", "sports_commentary", "sports_commentary_excited",
    "whispering", "terrified", "unfriendly",
})


def get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        try:
            from faster_whisper import WhisperModel
            device = os.getenv("WHISPER_DEVICE", "cpu")
            compute_type = "int8" if device == "cpu" else "float16"
            _whisper_model = WhisperModel(
                WHISPER_MODEL_SIZE,
                device=device,
                compute_type=compute_type
            )
            logger.info(f"Whisper model loaded: {WHISPER_MODEL_SIZE} on {device}")
        except ImportError:
            logger.error("faster-whisper not installed. Run: pip install faster-whisper")
            raise RuntimeError("faster-whisper not installed")
    return _whisper_model


def _cleanup_temp_file(path):
    try:
        os.unlink(path)
    except Exception:
        pass


async def transcribe_audio(
    audio_bytes: bytes,
    filename: str = "audio.wav",
    language: str = "en"
) -> Tuple[str, float]:
    if USE_LOCAL_STT:
        return await _transcribe_local(audio_bytes, filename, language)
    return await _transcribe_cloud(audio_bytes, filename, language)


async def _transcribe_local(
    audio_bytes: bytes,
    filename: str,
    language: str
) -> Tuple[str, float]:
    ext = Path(filename).suffix.lower() or ".wav"
    if ext not in SUPPORTED_AUDIO_EXTENSIONS:
        ext = ".wav"

    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as f:
        f.write(audio_bytes)
        temp_path = f.name

    try:
        model = get_whisper_model()

        # Consume the generator inside the executor so decoding doesn't
        # block the event loop (faster_whisper returns a lazy generator).
        def _do_transcribe():
            segs, info = model.transcribe(
                temp_path,
                language=language if language != "auto" else None,
                beam_size=5,
                vad_filter=True
            )
            return list(segs), info

        loop = asyncio.get_running_loop()
        segments, info = await loop.run_in_executor(None, _do_transcribe)

        text_parts = []
        total_confidence = 0.0
        segment_count = 0

        for segment in segments:
            text_parts.append(segment.text)
            confidence = min(1.0, max(0.0, 1.0 + segment.avg_logprob))
            total_confidence += confidence
            segment_count += 1

        text = " ".join(text_parts).strip()
        avg_confidence = total_confidence / segment_count if segment_count > 0 else 0.0

        logger.info(f"Transcribed {len(audio_bytes)} bytes -> {len(text)} chars (confidence: {avg_confidence:.2f})")
        return text, avg_confidence

    finally:
        _cleanup_temp_file(temp_path)


async def _transcribe_cloud(
    audio_bytes: bytes,
    filename: str,
    language: str
) -> Tuple[str, float]:
    import httpx

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        azure_key = os.getenv("AZURE_OPENAI_API_KEY")
        azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        if azure_key and azure_endpoint:
            return await _transcribe_azure(audio_bytes, filename, language)
        raise RuntimeError("No cloud STT API configured (OPENAI_API_KEY or AZURE_OPENAI_API_KEY)")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.openai.com/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {api_key}"},
            files={"file": (filename, audio_bytes, "audio/wav")},
            data={"model": "whisper-1", "language": language},
            timeout=30.0
        )

        if response.status_code != 200:
            logger.error(f"OpenAI Whisper API error: {response.text}")
            raise RuntimeError(f"Whisper API error: {response.status_code}")

        result = response.json()
        return result.get("text", ""), 0.9


async def _transcribe_azure(
    audio_bytes: bytes,
    filename: str,
    language: str
) -> Tuple[str, float]:
    import httpx

    azure_key = os.getenv("AZURE_OPENAI_API_KEY")
    azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{azure_endpoint}/openai/audio/transcriptions?api-version=2024-12-01-preview",
            headers={"api-key": azure_key},
            files={"file": (filename, audio_bytes, "audio/wav")},
            data={"model": "whisper-1", "response_format": "text"},
            timeout=30.0
        )

        if response.status_code != 200:
            logger.error(f"Azure Whisper API error: {response.text}")
            raise RuntimeError(f"Azure Whisper API error: {response.status_code}")

        return response.text.strip(), 0.9


# ---- Azure TTS Streaming ----

def is_azure_tts_available() -> bool:
    return bool(os.getenv("AZURE_SPEECH_KEY") and os.getenv("AZURE_SPEECH_REGION"))


def _sanitize_voice_name(voice_name: str) -> str:
    """Validate voice name against Azure naming pattern."""
    if _AZURE_VOICE_RE.match(voice_name):
        return voice_name
    return "en-US-GuyNeural"


def _sanitize_style(style: Optional[str]) -> Optional[str]:
    """Validate style against known Azure SSML style values."""
    if style and style.lower() in _AZURE_STYLES:
        return style.lower()
    return None


def build_ssml(text: str, voice_name: str = "en-US-GuyNeural",
               style: Optional[str] = None, rate: float = 1.0) -> str:
    # Azure SSML prosody rate: relative percentage with explicit sign, or "default"
    if rate != 1.0:
        relative = (rate - 1.0) * 100
        rate_str = f"{relative:+.0f}%"
    else:
        rate_str = "default"

    escaped = (text.replace("&", "&amp;").replace("<", "&lt;")
               .replace(">", "&gt;").replace('"', "&quot;").replace("'", "&apos;"))

    safe_voice = _sanitize_voice_name(voice_name)
    safe_style = _sanitize_style(style)

    inner = escaped
    if safe_style:
        inner = (
            f'<mstts:express-as style="{safe_style}">'
            f'{escaped}'
            f'</mstts:express-as>'
        )

    return (
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
        'xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="en-US">'
        f'<voice name="{safe_voice}">'
        f'<prosody rate="{rate_str}">'
        f'{inner}'
        f'</prosody>'
        f'</voice>'
        f'</speak>'
    )


async def stream_azure_tts(
    text: str,
    voice_name: str = "en-US-GuyNeural",
    style: Optional[str] = None,
    rate: float = 1.0
) -> AsyncGenerator[bytes, None]:
    """Synthesize text to audio via Azure Speech Services, yielding WAV chunks.

    Uses the Azure Speech SDK's push audio output stream to yield audio data
    as it becomes available during synthesis.
    """
    import azure.cognitiveservices.speech as speechsdk

    speech_key = os.getenv("AZURE_SPEECH_KEY")
    speech_region = os.getenv("AZURE_SPEECH_REGION")

    if not speech_key or not speech_region:
        raise RuntimeError("AZURE_SPEECH_KEY and AZURE_SPEECH_REGION must be set")

    ssml = build_ssml(text, voice_name, style, rate)

    loop = asyncio.get_running_loop()
    audio_queue: asyncio.Queue[Optional[bytes]] = asyncio.Queue()

    class PushCallback(speechsdk.audio.PushAudioOutputStreamCallback):
        def write(self, audio_buffer: memoryview) -> int:
            data = bytes(audio_buffer)
            loop.call_soon_threadsafe(audio_queue.put_nowait, data)
            return len(data)

        def close(self):
            # Sentinel is handled by _do_synth's finally block.
            pass

    callback = PushCallback()
    push_stream = speechsdk.audio.PushAudioOutputStream(callback)
    audio_config = speechsdk.audio.AudioOutputConfig(stream=push_stream)

    speech_config = speechsdk.SpeechConfig(
        subscription=speech_key,
        region=speech_region
    )
    speech_config.set_speech_synthesis_output_format(
        speechsdk.SpeechSynthesisOutputFormat.Riff16Khz16BitMonoPcm
    )

    synthesizer = speechsdk.SpeechSynthesizer(
        speech_config=speech_config,
        audio_config=audio_config
    )

    def _do_synth():
        try:
            future = synthesizer.speak_ssml_async(ssml)
            result = future.get(timeout=30)
            if result.reason == speechsdk.ResultReason.Canceled:
                details = result.cancellation_details
                logger.error(f"Azure TTS canceled: {details.reason} - {details.error_details}")
        except TimeoutError:
            logger.error("Azure TTS synthesis timed out after 30s")
        except Exception as e:
            logger.error(f"Azure TTS synthesis exception: {e}")
        finally:
            loop.call_soon_threadsafe(audio_queue.put_nowait, None)

    synth_task = loop.run_in_executor(None, _do_synth)

    try:
        while True:
            chunk = await asyncio.wait_for(audio_queue.get(), timeout=30.0)
            if chunk is None:
                break
            yield chunk
    except asyncio.TimeoutError:
        logger.error("Azure TTS audio queue timed out")

    # Don't block indefinitely - the synth thread has its own 30s timeout
    try:
        await asyncio.wait_for(synth_task, timeout=35.0)
    except asyncio.TimeoutError:
        logger.error("Azure TTS synth task did not finish, abandoning")


async def synthesize_speech_azure(
    text: str,
    voice_name: str = "en-US-GuyNeural",
    style: Optional[str] = None,
    rate: float = 1.0
) -> bytes:
    """Non-streaming convenience wrapper: collects all chunks into a single bytes object."""
    parts = []
    async for chunk in stream_azure_tts(text, voice_name, style, rate):
        parts.append(chunk)
    return b"".join(parts)


class SentenceAccumulator:
    """Buffer LLM tokens and yield complete sentences."""

    def __init__(self):
        self._buffer = ""

    def add(self, token: str) -> list[str]:
        """Add a token and return any complete sentences."""
        self._buffer += token
        sentences = []
        while True:
            match = _SENTENCE_END_RE.search(self._buffer)
            if not match:
                break
            end = match.end()
            sentence = self._buffer[:end].strip()
            self._buffer = self._buffer[end:]
            if sentence:
                sentences.append(sentence)
        return sentences

    def flush(self) -> Optional[str]:
        """Return any remaining text when the stream ends."""
        remaining = self._buffer.strip()
        self._buffer = ""
        return remaining if remaining else None


async def warm_models():
    loop = asyncio.get_running_loop()

    async def _load_whisper():
        logger.info("Downloading Whisper model...")
        try:
            await loop.run_in_executor(None, get_whisper_model)
            logger.info("Whisper model ready")
        except Exception as e:
            logger.warning(f"Whisper model pre-load failed: {e}")

    if USE_LOCAL_STT:
        task = asyncio.create_task(_load_whisper())
        _background_tasks.add(task)
        task.add_done_callback(_background_tasks.discard)

    if is_azure_tts_available():
        logger.info("Azure TTS configured and available")
    else:
        logger.warning("Azure TTS not configured (AZURE_SPEECH_KEY / AZURE_SPEECH_REGION missing)")
