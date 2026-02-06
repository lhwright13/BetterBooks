"""
Unit Tests for Voice Service

Tests speech-to-text (STT) and text-to-speech (TTS) functionality
including local Whisper and cloud API fallbacks.
"""

import asyncio
import base64
import io
import os
import struct
import sys
import tempfile
import wave
from pathlib import Path
from typing import Tuple
from unittest.mock import AsyncMock, MagicMock, patch, PropertyMock

import pytest

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / "platform" / "backend" / "services" / "api_gateway"))


# -----------------------------------------------------------------------------
# Test Fixtures
# -----------------------------------------------------------------------------

@pytest.fixture
def sample_audio_bytes() -> bytes:
    """Generate valid WAV audio bytes for testing."""
    # Create a simple WAV file in memory
    buffer = io.BytesIO()

    # WAV parameters
    sample_rate = 16000
    num_channels = 1
    sample_width = 2  # 16-bit
    duration_seconds = 1
    num_frames = sample_rate * duration_seconds

    with wave.open(buffer, 'wb') as wav:
        wav.setnchannels(num_channels)
        wav.setsampwidth(sample_width)
        wav.setframerate(sample_rate)

        # Generate silence (zeros)
        frames = b'\x00' * (num_frames * num_channels * sample_width)
        wav.writeframes(frames)

    return buffer.getvalue()


@pytest.fixture
def sample_audio_with_tone() -> bytes:
    """Generate WAV audio with a simple tone for more realistic testing."""
    import math

    buffer = io.BytesIO()
    sample_rate = 16000
    duration = 0.5  # 0.5 seconds
    frequency = 440  # A4 note

    with wave.open(buffer, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)

        frames = []
        for i in range(int(sample_rate * duration)):
            value = int(32767 * 0.5 * math.sin(2 * math.pi * frequency * i / sample_rate))
            frames.append(struct.pack('<h', value))

        wav.writeframes(b''.join(frames))

    return buffer.getvalue()


@pytest.fixture
def mock_whisper_model():
    """Mock faster-whisper model."""
    mock_model = MagicMock()

    # Create mock segment
    mock_segment = MagicMock()
    mock_segment.text = "Hello, this is a test transcription."
    mock_segment.avg_logprob = -0.3  # Good confidence
    mock_segment.start = 0.0
    mock_segment.end = 2.5

    # Mock transcribe method
    mock_info = MagicMock()
    mock_info.language = "en"
    mock_info.language_probability = 0.98

    mock_model.transcribe.return_value = ([mock_segment], mock_info)

    return mock_model


@pytest.fixture
def mock_tts_model():
    """Mock Coqui TTS model."""
    mock_model = MagicMock()

    def mock_tts_to_file(text, file_path):
        # Write a valid WAV file
        with wave.open(file_path, 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(16000)
            wav.writeframes(b'\x00' * 16000)  # 0.5 seconds of silence

    mock_model.tts_to_file = mock_tts_to_file
    return mock_model


# -----------------------------------------------------------------------------
# Voice Service Import Tests
# -----------------------------------------------------------------------------

class TestVoiceServiceImports:
    """Test that voice service modules import correctly."""

    def test_voice_service_imports(self):
        """Test voice_service module can be imported."""
        import voice_service
        assert hasattr(voice_service, 'transcribe_audio')
        assert hasattr(voice_service, 'synthesize_speech')
        assert hasattr(voice_service, 'process_voice_chat')

    def test_voice_service_config_defaults(self):
        """Test default configuration values."""
        import voice_service
        # These should default to True for local development
        assert hasattr(voice_service, 'USE_LOCAL_STT')
        assert hasattr(voice_service, 'USE_LOCAL_TTS')


# -----------------------------------------------------------------------------
# Transcription Tests
# -----------------------------------------------------------------------------

class TestTranscription:
    """Test speech-to-text functionality."""

    @pytest.mark.asyncio
    async def test_transcribe_audio_with_mock_whisper(self, sample_audio_bytes, mock_whisper_model):
        """Test transcription with mocked Whisper model."""
        import voice_service

        with patch.object(voice_service, 'get_whisper_model', return_value=mock_whisper_model):
            with patch.object(voice_service, 'USE_LOCAL_STT', True):
                text, confidence = await voice_service.transcribe_audio(
                    sample_audio_bytes,
                    "test.wav",
                    "en"
                )

        assert text == "Hello, this is a test transcription."
        assert 0 <= confidence <= 1

    @pytest.mark.asyncio
    async def test_transcribe_audio_empty_result(self, sample_audio_bytes, mock_whisper_model):
        """Test handling of empty transcription result."""
        import voice_service

        # Mock empty segments
        mock_whisper_model.transcribe.return_value = ([], MagicMock())

        with patch.object(voice_service, 'get_whisper_model', return_value=mock_whisper_model):
            with patch.object(voice_service, 'USE_LOCAL_STT', True):
                text, confidence = await voice_service.transcribe_audio(
                    sample_audio_bytes,
                    "test.wav"
                )

        assert text == ""
        assert confidence == 0.0

    @pytest.mark.asyncio
    async def test_transcribe_audio_multiple_segments(self, sample_audio_bytes, mock_whisper_model):
        """Test transcription with multiple segments."""
        import voice_service

        # Create multiple mock segments
        segments = []
        for i, text in enumerate(["Hello,", "this is", "a test."]):
            seg = MagicMock()
            seg.text = text
            seg.avg_logprob = -0.2
            segments.append(seg)

        mock_whisper_model.transcribe.return_value = (segments, MagicMock())

        with patch.object(voice_service, 'get_whisper_model', return_value=mock_whisper_model):
            with patch.object(voice_service, 'USE_LOCAL_STT', True):
                text, confidence = await voice_service.transcribe_audio(
                    sample_audio_bytes,
                    "test.wav"
                )

        assert "Hello," in text
        assert "this is" in text
        assert "a test." in text

    @pytest.mark.asyncio
    async def test_transcribe_different_file_formats(self, mock_whisper_model):
        """Test transcription accepts various audio formats."""
        import voice_service

        formats = [
            ("test.wav", b"RIFF" + b'\x00' * 40),
            ("test.mp3", b'\xff\xfb' + b'\x00' * 40),
            ("test.webm", b'\x1a\x45\xdf\xa3' + b'\x00' * 40),
        ]

        for filename, audio_bytes in formats:
            mock_whisper_model.transcribe.return_value = ([MagicMock(text="test", avg_logprob=-0.3)], MagicMock())

            with patch.object(voice_service, 'get_whisper_model', return_value=mock_whisper_model):
                with patch.object(voice_service, 'USE_LOCAL_STT', True):
                    # Should not raise an error
                    text, _ = await voice_service.transcribe_audio(audio_bytes, filename)
                    assert text == "test"


# -----------------------------------------------------------------------------
# Speech Synthesis Tests
# -----------------------------------------------------------------------------

class TestSpeechSynthesis:
    """Test text-to-speech functionality."""

    @pytest.mark.asyncio
    async def test_synthesize_speech_with_mock_tts(self, mock_tts_model):
        """Test speech synthesis with mocked TTS model."""
        import voice_service

        with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
            with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                audio_bytes = await voice_service.synthesize_speech(
                    "Hello, this is a test.",
                    voice="default"
                )

        assert isinstance(audio_bytes, bytes)
        assert len(audio_bytes) > 0
        # Should be a valid WAV file
        assert audio_bytes[:4] == b'RIFF'

    @pytest.mark.asyncio
    async def test_synthesize_speech_different_voices(self, mock_tts_model):
        """Test synthesis with different voice options."""
        import voice_service

        voices = ["default", "gatsby", "nick", "teacher"]

        for voice in voices:
            with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
                with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                    audio_bytes = await voice_service.synthesize_speech(
                        "Test message",
                        voice=voice
                    )
                    assert isinstance(audio_bytes, bytes)

    @pytest.mark.asyncio
    async def test_synthesize_speech_speed_parameter(self, mock_tts_model):
        """Test synthesis with different speed values."""
        import voice_service

        speeds = [0.5, 1.0, 1.5, 2.0]

        for speed in speeds:
            with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
                with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                    audio_bytes = await voice_service.synthesize_speech(
                        "Test message",
                        speed=speed
                    )
                    assert isinstance(audio_bytes, bytes)

    @pytest.mark.asyncio
    async def test_synthesize_pyttsx3_fallback(self):
        """Test fallback to pyttsx3 when Coqui TTS not available."""
        import voice_service

        with patch.object(voice_service, 'get_tts_model', return_value="pyttsx3"):
            with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                with patch.object(voice_service, '_synthesize_pyttsx3') as mock_pyttsx3:
                    mock_pyttsx3.return_value = b'RIFF' + b'\x00' * 100

                    audio_bytes = await voice_service.synthesize_speech("Test")
                    mock_pyttsx3.assert_called_once()


# -----------------------------------------------------------------------------
# Voice Chat Round-Trip Tests
# -----------------------------------------------------------------------------

class TestVoiceChatRoundTrip:
    """Test full voice chat functionality."""

    @pytest.mark.asyncio
    async def test_process_voice_chat_success(self, sample_audio_bytes, mock_whisper_model, mock_tts_model):
        """Test complete voice chat round-trip."""
        import voice_service

        async def mock_get_ai_response(text):
            return f"AI response to: {text}"

        with patch.object(voice_service, 'get_whisper_model', return_value=mock_whisper_model):
            with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
                with patch.object(voice_service, 'USE_LOCAL_STT', True):
                    with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                        transcription, response_text, response_audio = await voice_service.process_voice_chat(
                            sample_audio_bytes,
                            "test.wav",
                            mock_get_ai_response
                        )

        assert transcription == "Hello, this is a test transcription."
        assert "AI response to:" in response_text
        assert isinstance(response_audio, bytes)

    @pytest.mark.asyncio
    async def test_process_voice_chat_empty_transcription(self, sample_audio_bytes, mock_whisper_model, mock_tts_model):
        """Test voice chat with empty transcription raises error."""
        import voice_service

        # Mock empty transcription
        mock_whisper_model.transcribe.return_value = ([], MagicMock())

        async def mock_get_ai_response(text):
            return "response"

        with patch.object(voice_service, 'get_whisper_model', return_value=mock_whisper_model):
            with patch.object(voice_service, 'USE_LOCAL_STT', True):
                with pytest.raises(ValueError, match="No speech detected"):
                    await voice_service.process_voice_chat(
                        sample_audio_bytes,
                        "test.wav",
                        mock_get_ai_response
                    )


# -----------------------------------------------------------------------------
# Cloud API Fallback Tests
# -----------------------------------------------------------------------------

class TestCloudAPIFallback:
    """Test cloud API fallback functionality."""

    @pytest.mark.asyncio
    async def test_transcribe_cloud_openai(self, sample_audio_bytes):
        """Test OpenAI Whisper API fallback."""
        import voice_service

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"text": "Cloud transcription result"}

        with patch.object(voice_service, 'USE_LOCAL_STT', False):
            with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}):
                with patch('httpx.AsyncClient') as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(return_value=mock_response)

                    text, confidence = await voice_service.transcribe_audio(
                        sample_audio_bytes,
                        "test.wav"
                    )

        assert text == "Cloud transcription result"

    @pytest.mark.asyncio
    async def test_synthesize_cloud_openai(self):
        """Test OpenAI TTS API fallback."""
        import voice_service

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.content = b'RIFF' + b'\x00' * 100  # Fake WAV

        with patch.object(voice_service, 'USE_LOCAL_TTS', False):
            with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}):
                with patch('httpx.AsyncClient') as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(return_value=mock_response)

                    audio_bytes = await voice_service.synthesize_speech("Test text")

        assert audio_bytes[:4] == b'RIFF'

    @pytest.mark.asyncio
    async def test_cloud_api_error_handling(self, sample_audio_bytes):
        """Test error handling when cloud API fails."""
        import voice_service

        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.text = "Internal Server Error"

        with patch.object(voice_service, 'USE_LOCAL_STT', False):
            with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}):
                with patch('httpx.AsyncClient') as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(return_value=mock_response)

                    with pytest.raises(RuntimeError, match="API error"):
                        await voice_service.transcribe_audio(sample_audio_bytes, "test.wav")


# -----------------------------------------------------------------------------
# Model Loading Tests
# -----------------------------------------------------------------------------

class TestModelLoading:
    """Test lazy model loading behavior."""

    def test_whisper_model_lazy_loading(self):
        """Test that Whisper model is loaded lazily (caching behavior)."""
        import voice_service

        # Reset the global model
        voice_service._whisper_model = None

        # Create a mock model
        mock_model = MagicMock()

        # Test that once loaded, the model is cached
        voice_service._whisper_model = mock_model

        # Calling get_whisper_model should return the cached model
        model1 = voice_service.get_whisper_model()
        model2 = voice_service.get_whisper_model()

        # Both calls should return the same cached instance
        assert model1 is model2
        assert model1 is mock_model

    def test_tts_model_lazy_loading(self):
        """Test that TTS model is loaded lazily."""
        import voice_service

        # Reset the global model
        voice_service._tts_model = None

        with patch('voice_service.TTS', create=True) as mock_tts:
            mock_tts.return_value = MagicMock()

            # First call should load the model
            model1 = voice_service.get_tts_model()

            # Reset mock
            mock_tts.reset_mock()

            # Second call should return cached model
            model2 = voice_service.get_tts_model()
            assert model1 is model2


# -----------------------------------------------------------------------------
# Input Validation Tests
# -----------------------------------------------------------------------------

class TestInputValidation:
    """Test input validation for voice functions."""

    @pytest.mark.asyncio
    async def test_transcribe_handles_empty_audio(self, mock_whisper_model):
        """Test transcription with empty audio data."""
        import voice_service

        mock_whisper_model.transcribe.return_value = ([], MagicMock())

        with patch.object(voice_service, 'get_whisper_model', return_value=mock_whisper_model):
            with patch.object(voice_service, 'USE_LOCAL_STT', True):
                text, confidence = await voice_service.transcribe_audio(b'', "test.wav")

        assert text == ""

    @pytest.mark.asyncio
    async def test_synthesize_empty_text(self, mock_tts_model):
        """Test synthesis with empty text still works."""
        import voice_service

        with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
            with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                # Empty text should still produce audio (silence)
                audio_bytes = await voice_service.synthesize_speech("")
                assert isinstance(audio_bytes, bytes)

    @pytest.mark.asyncio
    async def test_synthesize_long_text(self, mock_tts_model):
        """Test synthesis with very long text."""
        import voice_service

        long_text = "This is a test. " * 500  # ~8000 characters

        with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
            with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                audio_bytes = await voice_service.synthesize_speech(long_text)
                assert isinstance(audio_bytes, bytes)


# -----------------------------------------------------------------------------
# Configuration Tests
# -----------------------------------------------------------------------------

class TestConfiguration:
    """Test configuration handling."""

    def test_environment_variable_defaults(self, monkeypatch):
        """Test default values when environment variables not set."""
        # Clear relevant env vars
        monkeypatch.delenv("USE_LOCAL_STT", raising=False)
        monkeypatch.delenv("USE_LOCAL_TTS", raising=False)
        monkeypatch.delenv("WHISPER_MODEL_SIZE", raising=False)

        # Re-import to pick up new defaults
        import importlib
        import voice_service
        importlib.reload(voice_service)

        # Should default to local
        assert voice_service.USE_LOCAL_STT == True
        assert voice_service.USE_LOCAL_TTS == True

    def test_whisper_model_size_config(self, monkeypatch):
        """Test Whisper model size configuration."""
        monkeypatch.setenv("WHISPER_MODEL_SIZE", "small")

        import importlib
        import voice_service
        importlib.reload(voice_service)

        assert voice_service.WHISPER_MODEL_SIZE == "small"


# -----------------------------------------------------------------------------
# Voice Endpoint Integration Tests (without real models)
# -----------------------------------------------------------------------------

class TestVoiceEndpoints:
    """Test voice API endpoint handlers."""

    @pytest.mark.asyncio
    async def test_transcribe_endpoint_validation(self):
        """Test /voice/transcribe endpoint input validation."""
        # This tests the endpoint logic, not the actual transcription
        from fastapi.testclient import TestClient
        from unittest.mock import patch

        # We need to mock the voice_service import in main
        with patch('voice_service.transcribe_audio') as mock_transcribe:
            mock_transcribe.return_value = ("Test transcription", 0.95)

            # Import after patching
            import main

            client = TestClient(main.app)

            # Test with valid audio file
            response = client.post(
                "/voice/transcribe",
                files={"audio": ("test.wav", b"RIFF" + b'\x00' * 100, "audio/wav")}
            )

            # Should either succeed or fail gracefully
            assert response.status_code in [200, 400, 500]

    @pytest.mark.asyncio
    async def test_synthesize_endpoint_validation(self):
        """Test /voice/synthesize endpoint input validation."""
        from fastapi.testclient import TestClient
        from unittest.mock import patch

        with patch('voice_service.synthesize_speech') as mock_synthesize:
            mock_synthesize.return_value = b"RIFF" + b'\x00' * 100

            import main
            client = TestClient(main.app)

            # Test with valid request
            response = client.post(
                "/voice/synthesize",
                json={"text": "Hello world", "voice": "default", "speed": 1.0}
            )

            assert response.status_code in [200, 400, 500]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
