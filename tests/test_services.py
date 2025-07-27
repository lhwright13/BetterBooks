"""Basic unit tests for the microservices."""

import importlib
import os
import sys
from unittest.mock import patch, MagicMock

from fastapi.testclient import TestClient
import types

# Ensure the services package can be imported when running tests directly
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


def test_api_gateway_health():
    """Ensure the API Gateway health endpoint returns 200."""

    mod = importlib.import_module("services.api_gateway.main")
    client = TestClient(mod.app)
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_llm_gateway_health():
    """Health check for the LLM Gateway with OpenAI mocked out."""
    dummy_openai = types.ModuleType("openai")
    dummy_openai.OpenAI = MagicMock
    dummy_openai.resources = types.SimpleNamespace(
        chat=types.SimpleNamespace(
            completions=types.SimpleNamespace(
                Completions=types.SimpleNamespace(create=lambda *a, **k: None)
            )
        )
    )

    with patch.dict("sys.modules", {"openai": dummy_openai}):
        with patch(
            "openai.resources.chat.completions.Completions.create",
            lambda *a, **kwargs: MagicMock(
                choices=[MagicMock(message=MagicMock(content="hi"))]
            ),
        ):
            mod = importlib.import_module("services.llm_gateway.main")
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
            mod = importlib.import_module('services.context_service.main')
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
        mod = importlib.import_module('services.tts_service.main')
        client = TestClient(mod.app)
        resp = client.get('/health')
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}
