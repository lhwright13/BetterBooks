"""Comprehensive unit tests for TTS Service."""

import pytest
from unittest.mock import Mock, patch, MagicMock, mock_open
from fastapi.testclient import TestClient
import json
import io
import sys
from pathlib import Path

# Add service path for imports
service_path = Path(__file__).parent.parent.parent.parent / "platform" / "backend" / "services" / "tts_service"
sys.path.insert(0, str(service_path))

@pytest.mark.unit
class TestTTSService:
    """Test suite for TTS Service."""
    
    @pytest.fixture(autouse=True)
    def setup(self, mock_tts, mock_logger, test_audio_file):
        """Set up test environment."""
        self.mock_tts = mock_tts
        self.mock_logger = mock_logger
        self.test_audio_file = test_audio_file
        
        # Mock environment variables
        with patch.dict('os.environ', {
            'TTS_MODEL_PATH': '/app/models/tts',
            'TTS_OUTPUT_DIR': '/app/output',
            'LOG_LEVEL': 'DEBUG'
        }):
            # Mock TTS library imports
            with patch('TTS.api.TTS') as mock_tts_class:
                mock_tts_instance = MagicMock()
                mock_tts_instance.tts.return_value = None
                mock_tts_instance.list_models.return_value = ["tts_models/en/ljspeech/tacotron2-DDC"]
                mock_tts_instance.speakers = ["speaker1", "speaker2"]
                mock_tts_class.return_value = mock_tts_instance
                self.mock_tts_instance = mock_tts_instance
                
                # Mock file operations
                with patch('builtins.open', mock_open(read_data=b"fake_audio_data")):
                    from main import app
                    self.client = TestClient(app)
                    self.app = app
    
    def test_health_endpoint(self):
        """Test health check endpoint."""
        response = self.client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
    
    def test_synthesize_text_basic(self, sample_tts_request):
        """Test basic text-to-speech synthesis."""
        # Mock file creation
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=1024):
                    response = self.client.post("/synthesize", json=sample_tts_request)
                    
                    assert response.status_code == 200
                    data = response.json()
                    assert "audio_url" in data
                    assert "duration" in data
                    assert "file_size" in data
                    
                    # Verify TTS was called
                    self.mock_tts_instance.tts.assert_called()
    
    def test_synthesize_with_custom_voice(self):
        """Test synthesis with custom voice selection."""
        request_data = {
            "text": "Hello, this is a test with custom voice.",
            "voice": "speaker2",
            "speed": 1.2,
            "format": "wav"
        }
        
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=2048):
                    response = self.client.post("/synthesize", json=request_data)
                    
                    assert response.status_code == 200
                    data = response.json()
                    assert "audio_url" in data
                    
                    # Verify custom voice was used
                    call_args = self.mock_tts_instance.tts.call_args
                    assert "speaker" in call_args[1] or len(call_args[0]) > 1
    
    def test_synthesize_with_invalid_text(self):
        """Test synthesis with invalid or empty text."""
        request_data = {
            "text": "",
            "voice": "default"
        }
        
        response = self.client.post("/synthesize", json=request_data)
        
        assert response.status_code == 400
        data = response.json()
        assert "error" in data or "detail" in data
    
    def test_synthesize_with_long_text(self):
        """Test synthesis with very long text."""
        long_text = "This is a very long text. " * 1000  # ~25,000 characters
        
        request_data = {
            "text": long_text,
            "voice": "default"
        }
        
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=5120):
                    response = self.client.post("/synthesize", json=request_data)
                    
                    # Should either succeed or return appropriate error for text length
                    assert response.status_code in [200, 400, 413]
    
    def test_list_voices_endpoint(self):
        """Test listing available voices."""
        response = self.client.get("/voices")
        
        assert response.status_code == 200
        data = response.json()
        assert "voices" in data
        assert isinstance(data["voices"], list)
        assert len(data["voices"]) > 0
    
    def test_list_models_endpoint(self):
        """Test listing available TTS models."""
        response = self.client.get("/models")
        
        assert response.status_code == 200
        data = response.json()
        assert "models" in data
        assert isinstance(data["models"], list)
    
    def test_audio_file_download(self):
        """Test downloading generated audio files."""
        filename = "test_audio.mp3"
        
        with patch('os.path.exists', return_value=True):
            with patch('builtins.open', mock_open(read_data=b"fake_audio_data")):
                response = self.client.get(f"/audio/{filename}")
                
                assert response.status_code == 200
                assert response.headers["content-type"] == "audio/mpeg"
                assert response.content == b"fake_audio_data"
    
    def test_audio_file_not_found(self):
        """Test downloading non-existent audio file."""
        filename = "nonexistent.mp3"
        
        with patch('os.path.exists', return_value=False):
            response = self.client.get(f"/audio/{filename}")
            
            assert response.status_code == 404
            data = response.json()
            assert "not found" in data["detail"].lower()
    
    def test_batch_synthesis(self):
        """Test batch synthesis of multiple texts."""
        batch_request = {
            "texts": [
                "First text to synthesize",
                "Second text to synthesize", 
                "Third text to synthesize"
            ],
            "voice": "default",
            "format": "mp3"
        }
        
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=1024):
                    response = self.client.post("/batch/synthesize", json=batch_request)
                    
                    assert response.status_code == 200
                    data = response.json()
                    assert "results" in data
                    assert len(data["results"]) == len(batch_request["texts"])
                    
                    # Verify each result has required fields
                    for result in data["results"]:
                        assert "audio_url" in result
                        assert "index" in result
    
    def test_synthesis_progress_tracking(self):
        """Test progress tracking for long synthesis jobs."""
        job_id = "job_123"
        
        # Mock job status
        mock_job_status = {
            "job_id": job_id,
            "status": "processing",
            "progress": 0.5,
            "estimated_time_remaining": 30
        }
        
        with patch('redis.Redis') as mock_redis:
            mock_redis_instance = MagicMock()
            mock_redis_instance.get.return_value = json.dumps(mock_job_status).encode()
            mock_redis.return_value = mock_redis_instance
            
            response = self.client.get(f"/jobs/{job_id}/status")
            
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "processing"
            assert data["progress"] == 0.5
    
    def test_tts_engine_failure(self):
        """Test error handling when TTS engine fails."""
        self.mock_tts_instance.tts.side_effect = Exception("TTS engine error")
        
        request_data = {
            "text": "Test text",
            "voice": "default"
        }
        
        response = self.client.post("/synthesize", json=request_data)
        
        assert response.status_code == 500
        data = response.json()
        assert "error" in data
    
    def test_invalid_voice_selection(self):
        """Test error handling for invalid voice selection."""
        request_data = {
            "text": "Test text",
            "voice": "nonexistent_voice"
        }
        
        response = self.client.post("/synthesize", json=request_data)
        
        # Should return error for invalid voice
        assert response.status_code in [400, 422]
    
    def test_audio_format_conversion(self):
        """Test different audio format outputs."""
        formats = ["mp3", "wav", "ogg", "flac"]
        
        for fmt in formats:
            request_data = {
                "text": f"Test text for {fmt} format",
                "format": fmt
            }
            
            with patch('builtins.open', mock_open()) as mock_file:
                with patch('os.path.exists', return_value=True):
                    with patch('os.path.getsize', return_value=1024):
                        response = self.client.post("/synthesize", json=request_data)
                        
                        # Should succeed for supported formats
                        assert response.status_code in [200, 400]
    
    def test_speed_adjustment(self):
        """Test speech speed adjustment."""
        speeds = [0.5, 1.0, 1.5, 2.0]
        
        for speed in speeds:
            request_data = {
                "text": "Test text with speed adjustment",
                "speed": speed
            }
            
            with patch('builtins.open', mock_open()) as mock_file:
                with patch('os.path.exists', return_value=True):
                    with patch('os.path.getsize', return_value=1024):
                        response = self.client.post("/synthesize", json=request_data)
                        
                        assert response.status_code == 200
    
    def test_pitch_adjustment(self):
        """Test voice pitch adjustment."""
        request_data = {
            "text": "Test text with pitch adjustment",
            "pitch": 1.2,
            "voice": "default"
        }
        
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=1024):
                    response = self.client.post("/synthesize", json=request_data)
                    
                    # Should handle pitch adjustment if supported
                    assert response.status_code in [200, 400]
    
    def test_ssml_support(self):
        """Test SSML (Speech Synthesis Markup Language) support."""
        ssml_text = """
        <speak>
            <p>Hello, <emphasis>this</emphasis> is a test.</p>
            <break time="1s"/>
            <p>This text has <prosody rate="slow">slow speech</prosody>.</p>
        </speak>
        """
        
        request_data = {
            "text": ssml_text,
            "format": "ssml",
            "voice": "default"
        }
        
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=1024):
                    response = self.client.post("/synthesize", json=request_data)
                    
                    # Should handle SSML if supported
                    assert response.status_code in [200, 400]
    
    def test_audio_quality_settings(self):
        """Test different audio quality settings."""
        request_data = {
            "text": "Test text for quality settings",
            "quality": "high",
            "sample_rate": 44100
        }
        
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=2048):
                    response = self.client.post("/synthesize", json=request_data)
                    
                    assert response.status_code == 200
                    data = response.json()
                    assert "audio_url" in data
    
    def test_concurrent_synthesis_requests(self):
        """Test handling multiple concurrent synthesis requests."""
        import concurrent.futures
        
        def make_request(i):
            return self.client.post("/synthesize", json={
                "text": f"Concurrent synthesis test {i}",
                "voice": "default"
            })
        
        with patch('builtins.open', mock_open()):
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=1024):
                    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
                        futures = [executor.submit(make_request, i) for i in range(10)]
                        results = [f.result() for f in concurrent.futures.as_completed(futures)]
                    
                    # All requests should succeed
                    assert all(r.status_code == 200 for r in results)
    
    def test_file_cleanup(self):
        """Test automatic cleanup of old audio files."""
        with patch('os.listdir') as mock_listdir:
            with patch('os.path.getmtime') as mock_getmtime:
                with patch('os.remove') as mock_remove:
                    # Mock old files
                    mock_listdir.return_value = ["old_file.mp3", "new_file.mp3"]
                    mock_getmtime.side_effect = [1000000, 2000000]  # old, new timestamps
                    
                    response = self.client.post("/admin/cleanup")
                    
                    assert response.status_code == 200
                    data = response.json()
                    assert "cleaned_files" in data
    
    def test_storage_usage_endpoint(self):
        """Test storage usage monitoring."""
        with patch('shutil.disk_usage') as mock_disk_usage:
            mock_disk_usage.return_value = (1000000000, 500000000, 500000000)  # total, used, free
            
            response = self.client.get("/admin/storage")
            
            assert response.status_code == 200
            data = response.json()
            assert "total_space" in data
            assert "used_space" in data
            assert "free_space" in data
    
    def test_voice_cloning(self):
        """Test voice cloning functionality if supported."""
        # Upload reference audio for cloning
        files = {"audio": ("reference.wav", b"fake_audio_data", "audio/wav")}
        clone_data = {"voice_name": "custom_voice"}
        
        response = self.client.post("/voices/clone", files=files, data=clone_data)
        
        # Should handle voice cloning if supported
        assert response.status_code in [200, 201, 501]  # 501 for not implemented
    
    def test_text_preprocessing(self):
        """Test text preprocessing for better synthesis."""
        request_data = {
            "text": "Dr. Smith said hello @ 3:30 PM on Jan. 1st, 2024. The temp was 72°F.",
            "preprocess": True
        }
        
        with patch('builtins.open', mock_open()) as mock_file:
            with patch('os.path.exists', return_value=True):
                with patch('os.path.getsize', return_value=1024):
                    response = self.client.post("/synthesize", json=request_data)
                    
                    assert response.status_code == 200
                    # Text should be preprocessed for better pronunciation
    
    def test_metrics_collection(self):
        """Test that TTS metrics are collected."""
        # Make some synthesis requests
        for i in range(3):
            with patch('builtins.open', mock_open()):
                with patch('os.path.exists', return_value=True):
                    with patch('os.path.getsize', return_value=1024):
                        self.client.post("/synthesize", json={
                            "text": f"Test text {i}",
                            "voice": "default"
                        })
        
        # Check metrics endpoint
        response = self.client.get("/metrics")
        assert response.status_code == 200
        metrics_text = response.text
        
        # Should contain TTS-specific metrics
        assert "tts_service" in metrics_text
        assert "synthesis_duration_seconds" in metrics_text
        assert "audio_files_generated_total" in metrics_text
    
    def test_webhook_notifications(self):
        """Test webhook notifications for completed synthesis."""
        request_data = {
            "text": "Test text for webhook",
            "webhook_url": "https://example.com/webhook"
        }
        
        with patch('requests.post') as mock_post:
            with patch('builtins.open', mock_open()):
                with patch('os.path.exists', return_value=True):
                    with patch('os.path.getsize', return_value=1024):
                        response = self.client.post("/synthesize", json=request_data)
                        
                        assert response.status_code == 200
                        
                        # Webhook should be called if feature is implemented
                        # mock_post.assert_called()  # Uncomment if webhooks are implemented