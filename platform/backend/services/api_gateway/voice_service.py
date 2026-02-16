import os
import tempfile
import logging
from typing import Tuple
from pathlib import Path

logger = logging.getLogger(__name__)

_whisper_model = None
_tts_model = None

USE_LOCAL_STT = os.getenv("USE_LOCAL_STT", "true").lower() == "true"
USE_LOCAL_TTS = os.getenv("USE_LOCAL_TTS", "true").lower() == "true"
WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL_SIZE", "base")

SUPPORTED_AUDIO_EXTENSIONS = {".wav", ".mp3", ".webm", ".ogg", ".flac", ".m4a"}


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


def get_tts_model():
    global _tts_model
    if _tts_model is None:
        try:
            from TTS.api import TTS
            model_name = os.getenv("TTS_MODEL", "tts_models/en/ljspeech/tacotron2-DDC")
            _tts_model = TTS(model_name=model_name, progress_bar=False)
            logger.info(f"TTS model loaded: {model_name}")
        except ImportError:
            logger.warning("Coqui TTS not installed. Trying pyttsx3 fallback.")
            try:
                import pyttsx3
                _tts_model = "pyttsx3"
                logger.info("Using pyttsx3 for TTS (lower quality)")
            except ImportError:
                logger.error("No TTS backend available. Run: pip install TTS or pip install pyttsx3")
                raise RuntimeError("No TTS backend available")
    return _tts_model


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
    import asyncio

    ext = Path(filename).suffix.lower() or ".wav"
    if ext not in SUPPORTED_AUDIO_EXTENSIONS:
        ext = ".wav"

    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as f:
        f.write(audio_bytes)
        temp_path = f.name

    try:
        model = get_whisper_model()

        loop = asyncio.get_event_loop()
        segments, info = await loop.run_in_executor(
            None,
            lambda: model.transcribe(
                temp_path,
                language=language if language != "auto" else None,
                beam_size=5,
                vad_filter=True
            )
        )

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


async def synthesize_speech(
    text: str,
    voice: str = "default",
    speed: float = 1.0
) -> bytes:
    if USE_LOCAL_TTS:
        return await _synthesize_local(text, voice, speed)
    return await _synthesize_cloud(text, voice, speed)


async def _synthesize_local(text: str, voice: str, speed: float) -> bytes:
    import asyncio

    model = get_tts_model()

    if model == "pyttsx3":
        return await _synthesize_pyttsx3(text, voice, speed)

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        temp_path = f.name

    try:
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            lambda: model.tts_to_file(text=text, file_path=temp_path)
        )

        with open(temp_path, "rb") as f:
            audio_bytes = f.read()

        logger.info(f"Synthesized {len(text)} chars -> {len(audio_bytes)} bytes audio")
        return audio_bytes

    finally:
        _cleanup_temp_file(temp_path)


async def _synthesize_pyttsx3(text: str, voice: str, speed: float) -> bytes:
    import asyncio
    import platform

    if platform.system() == "Darwin":
        return await _synthesize_macos_say(text, voice, speed)

    import pyttsx3

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        temp_path = f.name

    try:
        def _synthesize():
            engine = pyttsx3.init()
            engine.setProperty('rate', int(150 * speed))
            engine.save_to_file(text, temp_path)
            engine.runAndWait()

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, _synthesize)

        with open(temp_path, "rb") as f:
            return f.read()

    finally:
        _cleanup_temp_file(temp_path)


MACOS_VOICE_MAP = {
    "default": "Samantha",
    "male": "Daniel",
    "female": "Samantha",
    "british": "Daniel",
    "narrator": "Alex",
}


async def _synthesize_macos_say(text: str, voice: str, speed: float) -> bytes:
    import asyncio
    import subprocess

    with tempfile.NamedTemporaryFile(suffix=".aiff", delete=False) as f:
        aiff_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wav_path = f.name

    try:
        rate = int(175 * speed)
        selected_voice = MACOS_VOICE_MAP.get(voice, "Samantha")

        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            lambda: subprocess.run(
                ["say", "-v", selected_voice, "-r", str(rate), "-o", aiff_path, text],
                check=True,
                capture_output=True
            )
        )

        await loop.run_in_executor(
            None,
            lambda: subprocess.run(
                ["afconvert", "-f", "WAVE", "-d", "LEI16@22050", aiff_path, wav_path],
                check=True,
                capture_output=True
            )
        )

        with open(wav_path, "rb") as f:
            audio_bytes = f.read()

        logger.info(f"macOS TTS: {len(text)} chars -> {len(audio_bytes)} bytes audio")
        return audio_bytes

    except subprocess.CalledProcessError as e:
        logger.error(f"macOS say command failed: {e}")
        raise RuntimeError(f"TTS failed: {e}")

    finally:
        for path in [aiff_path, wav_path]:
            _cleanup_temp_file(path)


CLOUD_VOICE_MAP = {
    "default": "alloy",
    "gatsby": "onyx",
    "nick": "echo",
    "daisy": "nova",
    "teacher": "alloy",
    "tutor": "shimmer",
}


async def _synthesize_cloud(text: str, voice: str, speed: float) -> bytes:
    import httpx

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY not configured for cloud TTS")

    openai_voice = CLOUD_VOICE_MAP.get(voice.lower(), "alloy")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.openai.com/v1/audio/speech",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": "tts-1",
                "input": text,
                "voice": openai_voice,
                "speed": speed,
                "response_format": "wav"
            },
            timeout=30.0
        )

        if response.status_code != 200:
            logger.error(f"OpenAI TTS API error: {response.text}")
            raise RuntimeError(f"TTS API error: {response.status_code}")

        return response.content


async def process_voice_chat(
    audio_bytes: bytes,
    filename: str,
    get_ai_response,
    voice: str = "default"
) -> Tuple[str, str, bytes]:
    transcription, confidence = await transcribe_audio(audio_bytes, filename)

    if not transcription.strip():
        raise ValueError("No speech detected in audio")

    response_text = await get_ai_response(transcription)
    response_audio = await synthesize_speech(response_text, voice=voice)

    return transcription, response_text, response_audio
