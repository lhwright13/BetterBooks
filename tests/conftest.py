"""Shared pytest fixtures and configuration for all tests."""

import os
import sys
import json
import asyncio
from pathlib import Path
from typing import Generator, Any, Dict
from unittest.mock import Mock, MagicMock, patch
import pytest
from fastapi.testclient import TestClient
import redis
from fakeredis import FakeRedis

# Add project root to path for imports
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Test configuration
TEST_CONFIG = {
    "test_mode": True,
    "database_url": "postgresql://test:test@localhost:5432/test_db",
    "redis_url": "redis://localhost:6379/1",
    "api_base_url": "http://localhost:8000",
    "gemini_api_key": "test-key-for-testing",
    "log_level": "DEBUG"
}

@pytest.fixture(scope="session")
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture
def mock_redis():
    """Provide a fake Redis client for testing."""
    return FakeRedis(decode_responses=False)

@pytest.fixture
def mock_database():
    """Mock database connection."""
    mock_db = MagicMock()
    mock_db.execute = MagicMock(return_value=None)
    mock_db.fetch_one = MagicMock(return_value={"id": 1, "status": "ok"})
    mock_db.fetch_all = MagicMock(return_value=[])
    return mock_db

@pytest.fixture
def mock_gemini():
    """Mock Google Gemini API."""
    with patch("google.generativeai.configure") as mock_configure:
        with patch("google.generativeai.GenerativeModel") as mock_model:
            mock_instance = MagicMock()
            mock_response = MagicMock()
            mock_response.text = "Test response from Gemini"
            mock_instance.generate_content.return_value = mock_response
            mock_model.return_value = mock_instance
            yield {
                "configure": mock_configure,
                "model": mock_model,
                "instance": mock_instance,
                "response": mock_response
            }

@pytest.fixture
def mock_tts():
    """Mock TTS service."""
    mock_tts = MagicMock()
    mock_tts.synthesize = MagicMock(return_value=b"fake_audio_data")
    mock_tts.get_voices = MagicMock(return_value=["voice1", "voice2"])
    return mock_tts

@pytest.fixture
def sample_embeddings():
    """Sample embeddings for testing."""
    return {
        "text": "This is a test sentence.",
        "embedding": [0.1] * 384,  # Standard embedding size
        "metadata": {
            "model": "all-MiniLM-L6-v2",
            "timestamp": "2024-01-01T00:00:00Z"
        }
    }

@pytest.fixture
def sample_llm_request():
    """Sample LLM completion request."""
    return {
        "prompt": "What is the meaning of life?",
        "max_tokens": 100,
        "config": "default"
    }

@pytest.fixture
def sample_tts_request():
    """Sample TTS synthesis request."""
    return {
        "text": "Hello, this is a test.",
        "voice": "en-US-Standard-A",
        "speed": 1.0,
        "format": "mp3"
    }

@pytest.fixture
def sample_context_request():
    """Sample context storage request."""
    return {
        "text": "Chapter 1: The Beginning",
        "metadata": {
            "book_id": "book_123",
            "chapter": 1,
            "timestamp": "2024-01-01T00:00:00Z"
        }
    }

@pytest.fixture
def api_headers():
    """Common API headers for testing."""
    return {
        "Content-Type": "application/json",
        "X-Request-ID": "test-request-123",
        "Authorization": "Bearer test-token"
    }

@pytest.fixture
def mock_health_check():
    """Mock health check responses."""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": "2024-01-01T00:00:00Z",
        "checks": {
            "database": {"status": "ok", "latency_ms": 5},
            "redis": {"status": "ok", "latency_ms": 2},
            "external_apis": {"status": "ok"}
        }
    }

@pytest.fixture
def mock_logger():
    """Mock logger for testing."""
    logger = MagicMock()
    logger.info = MagicMock()
    logger.error = MagicMock()
    logger.warning = MagicMock()
    logger.debug = MagicMock()
    return logger

@pytest.fixture
def test_audio_file(tmp_path):
    """Create a temporary test audio file."""
    audio_file = tmp_path / "test_audio.mp3"
    audio_file.write_bytes(b"fake_mp3_data_header" + b"\x00" * 1024)
    return str(audio_file)

@pytest.fixture
def test_config_file(tmp_path):
    """Create a temporary config file."""
    config_file = tmp_path / "test_config.json"
    config_data = {
        "model": "gemini-pro",
        "api_key": "test-key",
        "generation_config": {
            "temperature": 0.7,
            "top_p": 0.9
        }
    }
    config_file.write_text(json.dumps(config_data))
    return str(config_file)

@pytest.fixture(autouse=True)
def reset_environment():
    """Reset environment variables for each test."""
    original_env = os.environ.copy()
    
    # Set test environment variables
    os.environ["ENVIRONMENT"] = "test"
    os.environ["LOG_LEVEL"] = "DEBUG"
    os.environ["GEMINI_API_KEY"] = "test-key-for-testing"
    
    yield
    
    # Restore original environment
    os.environ.clear()
    os.environ.update(original_env)

@pytest.fixture
def mock_metrics():
    """Mock Prometheus metrics."""
    metrics = MagicMock()
    metrics.increment = MagicMock()
    metrics.observe = MagicMock()
    metrics.set = MagicMock()
    return metrics

# Performance testing fixtures
@pytest.fixture
def performance_timer():
    """Simple timer for performance tests."""
    import time
    
    class Timer:
        def __init__(self):
            self.start_time = None
            self.end_time = None
        
        def start(self):
            self.start_time = time.time()
        
        def stop(self):
            self.end_time = time.time()
            return self.end_time - self.start_time
        
        def elapsed(self):
            if self.start_time and self.end_time:
                return self.end_time - self.start_time
            return None
    
    return Timer()

# Async fixtures
@pytest.fixture
async def async_mock_database():
    """Async mock database for async tests."""
    mock_db = MagicMock()
    mock_db.execute = MagicMock(return_value=None)
    mock_db.fetch_one = MagicMock(return_value={"id": 1, "status": "ok"})
    mock_db.fetch_all = MagicMock(return_value=[])
    mock_db.close = MagicMock(return_value=None)
    return mock_db

# Test data generators
@pytest.fixture
def generate_test_chapters():
    """Generate test chapter data."""
    def _generate(count=10):
        chapters = []
        for i in range(count):
            chapters.append({
                "id": i + 1,
                "title": f"Chapter {i + 1}",
                "content": f"Content for chapter {i + 1}",
                "embedding": [0.1] * 384,
                "metadata": {
                    "position": i,
                    "word_count": 1000 + i * 100
                }
            })
        return chapters
    return _generate

@pytest.fixture
def generate_test_prompts():
    """Generate test prompts for LLM testing."""
    def _generate(count=5):
        prompts = [
            "Summarize this chapter",
            "What are the main themes?",
            "Describe the protagonist",
            "Explain the setting",
            "What happens next?"
        ]
        return prompts[:count]
    return _generate

# Cleanup fixtures
@pytest.fixture(autouse=True)
def cleanup_test_files(tmp_path):
    """Clean up any test files created during tests."""
    yield
    # Cleanup happens automatically with tmp_path

# Custom markers
def pytest_configure(config):
    """Register custom markers."""
    config.addinivalue_line(
        "markers", "unit: Unit tests"
    )
    config.addinivalue_line(
        "markers", "integration: Integration tests"
    )
    config.addinivalue_line(
        "markers", "performance: Performance tests"
    )
    config.addinivalue_line(
        "markers", "slow: Slow running tests"
    )
    config.addinivalue_line(
        "markers", "requires_redis: Tests requiring Redis"
    )
    config.addinivalue_line(
        "markers", "requires_database: Tests requiring database"
    )
    config.addinivalue_line(
        "markers", "requires_external_api: Tests requiring external APIs"
    )