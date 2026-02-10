"""
Voice Service for BetterBooks

Provides local speech-to-text (STT) and text-to-speech (TTS) capabilities.
Designed to work without cloud APIs for development, with optional cloud upgrades.

Components:
- STT: faster-whisper (local) or Whisper API (cloud)
- TTS: Coqui TTS (local) or OpenAI TTS (cloud)
"""

import os
import io
import tempfile
import logging
from typing import Optional, Tuple
from pathlib import Path

logger = logging.getLogger(__name__)

# Lazy-loaded models to avoid startup delay
_whisper_model = None
_tts_model = None

# Configuration
USE_LOCAL_STT = os.getenv("USE_LOCAL_STT", "true").lower() == "true"
USE_LOCAL_TTS = os.getenv("USE_LOCAL_TTS", "true").lower() == "true"
WHISPER_MODEL_SIZE = os.getenv("WHISPER_MODEL_SIZE", "base")  # tiny, base, small, medium, large


def get_whisper_model():
    """Lazy-load the Whisper model for speech-to-text."""
    global _whisper_model
    if _whisper_model is None:
        try:
            from faster_whisper import WhisperModel
            # Use CPU with int8 for efficiency on most machines
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
        except Exception as e:
            logger.error(f"Failed to load Whisper model: {e}")
            raise
    return _whisper_model


def get_tts_model():
    """Lazy-load the TTS model for text-to-speech."""
    global _tts_model
    if _tts_model is None:
        try:
            from TTS.api import TTS
            # Use a good quality English model
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
        except Exception as e:
            logger.error(f"Failed to load TTS model: {e}")
            raise
    return _tts_model


async def transcribe_audio(
    audio_bytes: bytes,
    filename: str = "audio.wav",
    language: str = "en"
) -> Tuple[str, float]:
    """
    Transcribe audio to text.

    Args:
        audio_bytes: Raw audio file bytes (wav, mp3, webm, etc.)
        filename: Original filename for format detection
        language: Language code (default: "en")

    Returns:
        Tuple of (transcribed_text, confidence_score)
    """
    if USE_LOCAL_STT:
        return await _transcribe_local(audio_bytes, filename, language)
    else:
        return await _transcribe_cloud(audio_bytes, filename, language)


async def _transcribe_local(
    audio_bytes: bytes,
    filename: str,
    language: str
) -> Tuple[str, float]:
    """Transcribe using local faster-whisper."""
    import asyncio

    # Determine file extension
    ext = Path(filename).suffix.lower() or ".wav"
    if ext not in [".wav", ".mp3", ".webm", ".ogg", ".flac", ".m4a"]:
        ext = ".wav"

    # Write to temp file (faster-whisper needs file path)
    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as f:
        f.write(audio_bytes)
        temp_path = f.name

    try:
        model = get_whisper_model()

        # Run transcription in thread pool to not block async
        loop = asyncio.get_event_loop()
        segments, info = await loop.run_in_executor(
            None,
            lambda: model.transcribe(
                temp_path,
                language=language if language != "auto" else None,
                beam_size=5,
                vad_filter=True  # Filter out non-speech
            )
        )

        # Combine all segments
        text_parts = []
        total_confidence = 0.0
        segment_count = 0

        for segment in segments:
            text_parts.append(segment.text)
            # Approximate confidence from avg_logprob
            confidence = min(1.0, max(0.0, 1.0 + segment.avg_logprob))
            total_confidence += confidence
            segment_count += 1

        text = " ".join(text_parts).strip()
        avg_confidence = total_confidence / segment_count if segment_count > 0 else 0.0

        logger.info(f"Transcribed {len(audio_bytes)} bytes -> {len(text)} chars (confidence: {avg_confidence:.2f})")
        return text, avg_confidence

    finally:
        # Clean up temp file
        try:
            os.unlink(temp_path)
        except:
            pass


async def _transcribe_cloud(
    audio_bytes: bytes,
    filename: str,
    language: str
) -> Tuple[str, float]:
    """Transcribe using OpenAI Whisper API."""
    import httpx

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        # Fall back to Azure OpenAI
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
        return result.get("text", ""), 0.9  # OpenAI doesn't return confidence


async def _transcribe_azure(
    audio_bytes: bytes,
    filename: str,
    language: str
) -> Tuple[str, float]:
    """Transcribe using Azure OpenAI Whisper."""
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
    """
    Convert text to speech audio.

    Args:
        text: Text to synthesize
        voice: Voice identifier (persona-specific or default)
        speed: Speech speed multiplier (0.5-2.0)

    Returns:
        Audio bytes (WAV format)
    """
    if USE_LOCAL_TTS:
        return await _synthesize_local(text, voice, speed)
    else:
        return await _synthesize_cloud(text, voice, speed)


async def _synthesize_local(text: str, voice: str, speed: float) -> bytes:
    """Synthesize using local Coqui TTS or pyttsx3."""
    import asyncio

    model = get_tts_model()

    if model == "pyttsx3":
        return await _synthesize_pyttsx3(text, voice, speed)

    # Coqui TTS
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
        try:
            os.unlink(temp_path)
        except:
            pass


async def _synthesize_pyttsx3(text: str, voice: str, speed: float) -> bytes:
    """Fallback synthesis using macOS 'say' command or pyttsx3."""
    import asyncio
    import subprocess
    import platform

    # On macOS, use 'say' command which works reliably
    if platform.system() == "Darwin":
        return await _synthesize_macos_say(text, voice, speed)

    # On other platforms, use pyttsx3
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
        try:
            os.unlink(temp_path)
        except:
            pass


async def _synthesize_macos_say(text: str, voice: str, speed: float) -> bytes:
    """Use macOS 'say' command for TTS - reliable and high quality."""
    import asyncio
    import subprocess

    # Create temp file for AIFF output
    with tempfile.NamedTemporaryFile(suffix=".aiff", delete=False) as f:
        aiff_path = f.name
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wav_path = f.name

    try:
        # Map speed to words per minute (default ~175 wpm)
        rate = int(175 * speed)

        # Choose voice based on persona or use default
        voice_map = {
            "default": "Samantha",
            "male": "Daniel",
            "female": "Samantha",
            "british": "Daniel",
            "narrator": "Alex",
        }
        selected_voice = voice_map.get(voice, "Samantha")

        # Run 'say' command
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(
            None,
            lambda: subprocess.run(
                ["say", "-v", selected_voice, "-r", str(rate), "-o", aiff_path, text],
                check=True,
                capture_output=True
            )
        )

        # Convert AIFF to WAV using afconvert (macOS built-in)
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
            try:
                os.unlink(path)
            except:
                pass


async def _synthesize_cloud(text: str, voice: str, speed: float) -> bytes:
    """Synthesize using OpenAI TTS API."""
    import httpx

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY not configured for cloud TTS")

    # Map persona voices to OpenAI voices
    voice_mapping = {
        "default": "alloy",
        "gatsby": "onyx",      # Deep, mysterious
        "nick": "echo",        # Thoughtful narrator
        "daisy": "nova",       # Feminine, breathy
        "teacher": "alloy",    # Clear, neutral
        "tutor": "shimmer",    # Warm, patient
    }
    openai_voice = voice_mapping.get(voice.lower(), "alloy")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.openai.com/v1/audio/speech",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": "tts-1",  # or "tts-1-hd" for higher quality
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


# Convenience function for full voice chat round-trip
async def process_voice_chat(
    audio_bytes: bytes,
    filename: str,
    get_ai_response,  # Callable that takes text and returns response
    voice: str = "default"
) -> Tuple[str, str, bytes]:
    """
    Process a complete voice chat interaction.

    Args:
        audio_bytes: Input audio
        filename: Input filename
        get_ai_response: Async function that takes user text and returns AI response text
        voice: Voice for TTS output

    Returns:
        Tuple of (user_transcription, ai_response_text, ai_response_audio)
    """
    # Step 1: Transcribe user input
    transcription, confidence = await transcribe_audio(audio_bytes, filename)

    if not transcription.strip():
        raise ValueError("No speech detected in audio")

    # Step 2: Get AI response
    response_text = await get_ai_response(transcription)

    # Step 3: Synthesize response
    response_audio = await synthesize_speech(response_text, voice=voice)

    return transcription, response_text, response_audio
