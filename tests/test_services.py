"""Basic unit tests for the microservices."""

import importlib
import os
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

from fastapi.testclient import TestClient
import types

# Add project root to path to allow imports
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))
# Add platform backend services to path
sys.path.insert(0, str(project_root / "platform" / "backend" / "services"))


def test_api_gateway_health():
    """Ensure the API Gateway health endpoint returns 200."""

    mod = importlib.import_module("api_gateway.main")
    client = TestClient(mod.app)
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_llm_gateway_health():
    """Health check for the LLM Gateway with Gemini mocked out."""

    dummy_genai = types.ModuleType("google.generativeai")
    dummy_types = types.ModuleType("google.generativeai.types")
    dummy_genai.configure = lambda *a, **k: None

    class DummyModel:
        def __init__(self, *a, **k):
            pass

        def generate_content(self, *a, **k):
            return types.SimpleNamespace(text="hi")

    dummy_genai.GenerativeModel = DummyModel
    dummy_types.GenerationConfig = MagicMock(return_value={})

    with patch.dict(
        "sys.modules",
        {"google.generativeai": dummy_genai, "google.generativeai.types": dummy_types},
    ):
        mod = importlib.import_module("llm_gateway.main")
        client = TestClient(mod.app)
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}


def test_context_service_health():
    """Health check for the Context Service with DB connections mocked."""

    class DummyCursor:
        def __enter__(self):
            return self
        def __exit__(self, *exc):
            pass
        def execute(self, *args, **kwargs):
            pass
        def fetchall(self):
            return []

    class DummyConn:
        def cursor(self):
            return DummyCursor()
        def commit(self):
            pass

    with patch('psycopg.connect', lambda *a, **k: DummyConn()):
        with patch('pgvector.psycopg.register_vector', lambda *a, **k: None):
            mod = importlib.import_module('context_service.main')
            client = TestClient(mod.app)
            resp = client.get('/health')
            assert resp.status_code == 200
            assert resp.json() == {"status": "ok"}


def test_tts_service_health():
    """Health check for the TTS service with the TTS library mocked."""

    class DummyTTS:
        def __init__(self, *a, **k):
            pass

        def tts(self, text):
            return b""

        def save_wav(self, wav, path):
            with open(path, "wb") as f:
                f.write(b"")

    mock_module = MagicMock(TTS=DummyTTS)
    with patch.dict('sys.modules', {'TTS.api': mock_module, 'TTS': MagicMock(api=mock_module)}):
        mod = importlib.import_module('tts_service.main')
        client = TestClient(mod.app)
        resp = client.get('/health')
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}
