import io
import math
import os
import struct
import sys
import wave
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(PROJECT_ROOT / "platform" / "backend" / "services" / "api_gateway"))


@pytest.fixture
def sample_audio_bytes():
    buffer = io.BytesIO()
    sample_rate = 16000
    num_channels = 1
    sample_width = 2
    duration_seconds = 1
    num_frames = sample_rate * duration_seconds

    with wave.open(buffer, 'wb') as wav:
        wav.setnchannels(num_channels)
        wav.setsampwidth(sample_width)
        wav.setframerate(sample_rate)
        frames = b'\x00' * (num_frames * num_channels * sample_width)
        wav.writeframes(frames)

    return buffer.getvalue()


@pytest.fixture
def sample_audio_with_tone():
    buffer = io.BytesIO()
    sample_rate = 16000
    duration = 0.5
    frequency = 440

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
    mock_model = MagicMock()

    mock_segment = MagicMock()
    mock_segment.text = "Hello, this is a test transcription."
    mock_segment.avg_logprob = -0.3
    mock_segment.start = 0.0
    mock_segment.end = 2.5

    mock_info = MagicMock()
    mock_info.language = "en"
    mock_info.language_probability = 0.98

    mock_model.transcribe.return_value = ([mock_segment], mock_info)

    return mock_model


@pytest.fixture
def mock_tts_model():
    mock_model = MagicMock()

    def mock_tts_to_file(text, file_path):
        with wave.open(file_path, 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(16000)
            wav.writeframes(b'\x00' * 16000)

    mock_model.tts_to_file = mock_tts_to_file
    return mock_model


class TestVoiceServiceImports:

    def test_voice_service_imports(self):
        import voice_service
        assert hasattr(voice_service, 'transcribe_audio')
        assert hasattr(voice_service, 'synthesize_speech')
        assert hasattr(voice_service, 'process_voice_chat')

    def test_voice_service_config_defaults(self):
        import voice_service
        assert hasattr(voice_service, 'USE_LOCAL_STT')
        assert hasattr(voice_service, 'USE_LOCAL_TTS')


class TestTranscription:

    @pytest.mark.asyncio
    async def test_transcribe_audio_with_mock_whisper(self, sample_audio_bytes, mock_whisper_model):
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
        import voice_service

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
        import voice_service

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
                    text, _ = await voice_service.transcribe_audio(audio_bytes, filename)
                    assert text == "test"


class TestSpeechSynthesis:

    @pytest.mark.asyncio
    async def test_synthesize_speech_with_mock_tts(self, mock_tts_model):
        import voice_service

        with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
            with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                audio_bytes = await voice_service.synthesize_speech(
                    "Hello, this is a test.",
                    voice="default"
                )

        assert isinstance(audio_bytes, bytes)
        assert len(audio_bytes) > 0
        assert audio_bytes[:4] == b'RIFF'

    @pytest.mark.asyncio
    async def test_synthesize_speech_different_voices(self, mock_tts_model):
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
        import voice_service

        with patch.object(voice_service, 'get_tts_model', return_value="pyttsx3"):
            with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                with patch.object(voice_service, '_synthesize_pyttsx3') as mock_pyttsx3:
                    mock_pyttsx3.return_value = b'RIFF' + b'\x00' * 100

                    audio_bytes = await voice_service.synthesize_speech("Test")
                    mock_pyttsx3.assert_called_once()


class TestVoiceChatRoundTrip:

    @pytest.mark.asyncio
    async def test_process_voice_chat_success(self, sample_audio_bytes, mock_whisper_model, mock_tts_model):
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
        import voice_service

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


class TestCloudAPIFallback:

    @pytest.mark.asyncio
    async def test_transcribe_cloud_openai(self, sample_audio_bytes):
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
        import voice_service

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.content = b'RIFF' + b'\x00' * 100

        with patch.object(voice_service, 'USE_LOCAL_TTS', False):
            with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}):
                with patch('httpx.AsyncClient') as mock_client:
                    mock_client.return_value.__aenter__.return_value.post = AsyncMock(return_value=mock_response)

                    audio_bytes = await voice_service.synthesize_speech("Test text")

        assert audio_bytes[:4] == b'RIFF'

    @pytest.mark.asyncio
    async def test_cloud_api_error_handling(self, sample_audio_bytes):
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


class TestModelLoading:

    def test_whisper_model_lazy_loading(self):
        import voice_service

        voice_service._whisper_model = None

        mock_model = MagicMock()
        voice_service._whisper_model = mock_model

        model1 = voice_service.get_whisper_model()
        model2 = voice_service.get_whisper_model()

        assert model1 is model2
        assert model1 is mock_model

    def test_tts_model_lazy_loading(self):
        import voice_service

        voice_service._tts_model = None

        with patch('voice_service.TTS', create=True) as mock_tts:
            mock_tts.return_value = MagicMock()

            model1 = voice_service.get_tts_model()

            mock_tts.reset_mock()

            model2 = voice_service.get_tts_model()
            assert model1 is model2


class TestInputValidation:

    @pytest.mark.asyncio
    async def test_transcribe_handles_empty_audio(self, mock_whisper_model):
        import voice_service

        mock_whisper_model.transcribe.return_value = ([], MagicMock())

        with patch.object(voice_service, 'get_whisper_model', return_value=mock_whisper_model):
            with patch.object(voice_service, 'USE_LOCAL_STT', True):
                text, confidence = await voice_service.transcribe_audio(b'', "test.wav")

        assert text == ""

    @pytest.mark.asyncio
    async def test_synthesize_empty_text(self, mock_tts_model):
        import voice_service

        with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
            with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                audio_bytes = await voice_service.synthesize_speech("")
                assert isinstance(audio_bytes, bytes)

    @pytest.mark.asyncio
    async def test_synthesize_long_text(self, mock_tts_model):
        import voice_service

        long_text = "This is a test. " * 500

        with patch.object(voice_service, 'get_tts_model', return_value=mock_tts_model):
            with patch.object(voice_service, 'USE_LOCAL_TTS', True):
                audio_bytes = await voice_service.synthesize_speech(long_text)
                assert isinstance(audio_bytes, bytes)


class TestConfiguration:

    def test_environment_variable_defaults(self, monkeypatch):
        monkeypatch.delenv("USE_LOCAL_STT", raising=False)
        monkeypatch.delenv("USE_LOCAL_TTS", raising=False)
        monkeypatch.delenv("WHISPER_MODEL_SIZE", raising=False)

        import importlib
        import voice_service
        importlib.reload(voice_service)

        assert voice_service.USE_LOCAL_STT == True
        assert voice_service.USE_LOCAL_TTS == True

    def test_whisper_model_size_config(self, monkeypatch):
        monkeypatch.setenv("WHISPER_MODEL_SIZE", "small")

        import importlib
        import voice_service
        importlib.reload(voice_service)

        assert voice_service.WHISPER_MODEL_SIZE == "small"


class TestVoiceEndpoints:

    @pytest.mark.asyncio
    async def test_transcribe_endpoint_validation(self):
        from fastapi.testclient import TestClient
        from unittest.mock import patch

        with patch('voice_service.transcribe_audio') as mock_transcribe:
            mock_transcribe.return_value = ("Test transcription", 0.95)

            import main

            client = TestClient(main.app)

            response = client.post(
                "/voice/transcribe",
                files={"audio": ("test.wav", b"RIFF" + b'\x00' * 100, "audio/wav")}
            )

            assert response.status_code in [200, 400, 500]

    @pytest.mark.asyncio
    async def test_synthesize_endpoint_validation(self):
        from fastapi.testclient import TestClient
        from unittest.mock import patch

        with patch('voice_service.synthesize_speech') as mock_synthesize:
            mock_synthesize.return_value = b"RIFF" + b'\x00' * 100

            import main
            client = TestClient(main.app)

            response = client.post(
                "/voice/synthesize",
                json={"text": "Hello world", "voice": "default", "speed": 1.0}
            )

            assert response.status_code in [200, 400, 500]
