import importlib
import os
import sys
from unittest.mock import patch, MagicMock

from fastapi.testclient import TestClient

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


def test_api_gateway_health():
    mod = importlib.import_module('services.api_gateway.main')
    client = TestClient(mod.app)
    resp = client.get('/health')
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_llm_gateway_health():
    patches = {
        'openai.Completion.create': lambda **kwargs: MagicMock(choices=[MagicMock(text='hi')])
    }
    with patch('openai.Completion.create', lambda **kwargs: MagicMock(choices=[MagicMock(text='hi')])):
        mod = importlib.import_module('services.llm_gateway.main')
        client = TestClient(mod.app)
        resp = client.get('/health')
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}


def test_context_service_health():
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
    class DummyTTS:
        def __init__(self, *a, **k):
            pass
        def tts(self, text):
            return b''
        def save_wav(self, wav, path):
            with open(path, 'wb') as f:
                f.write(b'')

    mock_module = MagicMock(TTS=DummyTTS)
    with patch.dict('sys.modules', {'TTS.api': mock_module, 'TTS': MagicMock(api=mock_module)}):
        mod = importlib.import_module('services.tts_service.main')
        client = TestClient(mod.app)
        resp = client.get('/health')
        assert resp.status_code == 200
        assert resp.json() == {"status": "ok"}
