import json
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List
from unittest.mock import MagicMock

import pytest

PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


@pytest.fixture
def sample_user_data() -> Dict[str, Any]:
    return {
        "id": "user_12345",
        "email": "testuser@example.com",
        "username": "testuser",
        "display_name": "Test User",
        "role": "user",
        "is_active": True,
        "email_verified": True,
        "created_at": datetime(2024, 1, 15, 10, 30, 0, tzinfo=timezone.utc),
        "hashed_password": "$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/RgKqJ6YJS"
    }


@pytest.fixture
def sample_book_data() -> Dict[str, Any]:
    return {
        "id": "book_gatsby_001",
        "title": "The Great Gatsby",
        "author": "F. Scott Fitzgerald",
        "description": "A story of wealth, love, and the American Dream in the Jazz Age.",
        "cover_image_url": "/covers/gatsby.jpg",
        "price_usd": 9.99,
        "credit_price": 1,
        "is_featured": True,
        "is_bestseller": True,
        "is_new_release": False,
        "duration_minutes": 285,
        "created_at": datetime(2024, 1, 10, 0, 0, 0, tzinfo=timezone.utc)
    }


@pytest.fixture
def sample_books_list() -> List[Dict[str, Any]]:
    return [
        {
            "id": "book_gatsby_001",
            "title": "The Great Gatsby",
            "author": "F. Scott Fitzgerald",
            "cover_image_url": "/covers/gatsby.jpg",
            "price_usd": 9.99,
            "credit_price": 1,
            "is_featured": True,
            "is_bestseller": True,
            "is_new_release": False
        },
        {
            "id": "book_moby_002",
            "title": "Moby Dick",
            "author": "Herman Melville",
            "cover_image_url": "/covers/moby.jpg",
            "price_usd": 12.99,
            "credit_price": 1,
            "is_featured": False,
            "is_bestseller": True,
            "is_new_release": False
        },
        {
            "id": "book_alice_003",
            "title": "Alice's Adventures in Wonderland",
            "author": "Lewis Carroll",
            "cover_image_url": "/covers/alice.jpg",
            "price_usd": 7.99,
            "credit_price": 1,
            "is_featured": True,
            "is_bestseller": False,
            "is_new_release": True
        }
    ]


@pytest.fixture
def sample_user_credits() -> Dict[str, Any]:
    return {
        "total_credits": 10,
        "used_credits": 3,
        "available_credits": 7
    }


@pytest.fixture
def sample_user_library() -> Dict[str, Any]:
    return {
        "books": [
            {
                "id": "book_gatsby_001",
                "title": "The Great Gatsby",
                "author": "F. Scott Fitzgerald",
                "cover_image_url": "/covers/gatsby.jpg",
                "progress": 0.45,
                "purchased_at": "2024-01-20T14:30:00Z"
            }
        ],
        "total_books": 1
    }


@pytest.fixture
def sample_transcript_data() -> Dict[str, Any]:
    return {
        "book_id": "the-great-gatsby",
        "title": "The Great Gatsby",
        "author": "F. Scott Fitzgerald",
        "total_chapters": 9,
        "chapters": [
            {
                "chapter": 1,
                "title": "Chapter 1",
                "duration_seconds": 1290,
                "chunks": [
                    {
                        "index": 0,
                        "start": 0.0,
                        "end": 35.0,
                        "text": "In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since. Whenever you feel like criticizing anyone, he told me, just remember that all the people in this world haven't had the advantages that you've had."
                    },
                    {
                        "index": 1,
                        "start": 35.0,
                        "end": 70.0,
                        "text": "He didn't say any more, but we've always been unusually communicative in a reserved way, and I understood that he meant a great deal more than that. In consequence, I'm inclined to reserve all judgments, a habit that has opened up many curious natures to me and also made me the victim of not a few veteran bores."
                    },
                    {
                        "index": 2,
                        "start": 70.0,
                        "end": 110.0,
                        "text": "The abnormal mind is quick to detect and attach itself to this quality when it appears in a normal person, and so it came about that in college I was unjustly accused of being a politician, because I was privy to the secret griefs of wild, unknown men."
                    }
                ]
            },
            {
                "chapter": 2,
                "title": "Chapter 2",
                "duration_seconds": 890,
                "chunks": [
                    {
                        "index": 0,
                        "start": 0.0,
                        "end": 40.0,
                        "text": "About halfway between West Egg and New York the motor road hastily joins the railroad and runs beside it for a quarter of a mile, so as to shrink away from a certain desolate area of land. This is the start of chapter two with enough text to pass the placeholder check."
                    },
                    {
                        "index": 1,
                        "start": 40.0,
                        "end": 85.0,
                        "text": "This is a valley of ashes - a fantastic farm where ashes grow like wheat into ridges and hills and grotesque gardens; where ashes take the forms of houses and chimneys and rising smoke and, finally, with a transcendent effort, of men who move dimly and already crumbling through the powdery air."
                    }
                ]
            },
            {
                "chapter": 3,
                "title": "Chapter 3",
                "duration_seconds": 1190,
                "chunks": [
                    {
                        "index": 0,
                        "start": 0.0,
                        "end": 45.0,
                        "text": "There was music from my neighbor's house through the summer nights. In his blue gardens men and girls came and went like moths among the whisperings and the champagne and the stars. At high tide in the afternoon I watched his guests diving from the tower of his raft."
                    }
                ]
            }
        ]
    }


@pytest.fixture
def sample_placeholder_transcript() -> Dict[str, Any]:
    return {
        "book_id": "placeholder-book",
        "title": "Placeholder Book",
        "note": "Timestamps are approximate. Run Whisper for accurate alignment.",
        "chapters": [
            {
                "chapter": 1,
                "title": "Chapter 1",
                "chunks": [
                    {"index": 0, "start": 0.0, "end": 10.0, "text": "Short placeholder."}
                ]
            }
        ]
    }


@pytest.fixture
def temp_book_files_dir(sample_transcript_data):
    with tempfile.TemporaryDirectory() as tmpdir:
        book_dir = Path(tmpdir) / "the-great-gatsby"
        book_dir.mkdir(parents=True)

        transcript_path = book_dir / "transcript.json"
        with open(transcript_path, "w", encoding="utf-8") as f:
            json.dump(sample_transcript_data, f)

        personas_dir = book_dir / "personas"
        personas_dir.mkdir()

        nick_persona = {
            "id": "nick-carraway",
            "name": "Nick Carraway",
            "type": "character",
            "base_preprompt": "You are Nick Carraway, the narrator of The Great Gatsby.",
            "generation_config": {"temperature": 0.7},
            "tts_config": {
                "voice": {"name": "en-US-Neural2-J"},
                "audio_config": {"speaking_rate": 1.0}
            }
        }

        with open(personas_dir / "Nick Carraway.json", "w", encoding="utf-8") as f:
            json.dump(nick_persona, f)

        yield tmpdir


@pytest.fixture
def temp_config_dir():
    with tempfile.TemporaryDirectory() as tmpdir:
        personas_dir = Path(tmpdir) / "personas"
        personas_dir.mkdir(parents=True)

        global_personas = {
            "description": "Global personas available for all books",
            "personas": [
                {
                    "id": "english-teacher",
                    "name": "English Teacher",
                    "type": "guide",
                    "description": "Analyzes themes, symbolism, and literary devices",
                    "system_prompt": "You are an experienced English teacher helping a student.",
                    "temperature": 0.7,
                    "voice": {
                        "provider": "azure",
                        "voice_id": "en-US-AriaNeural",
                        "style": "friendly",
                        "rate": 0.95
                    }
                },
                {
                    "id": "reading-companion",
                    "name": "Reading Companion",
                    "type": "guide",
                    "description": "Straightforward answers about plot and characters",
                    "system_prompt": "You are a helpful reading companion.",
                    "temperature": 0.5,
                    "voice": {
                        "provider": "azure",
                        "voice_id": "en-US-GuyNeural"
                    }
                }
            ]
        }

        with open(personas_dir / "global.json", "w", encoding="utf-8") as f:
            json.dump(global_personas, f)

        yield tmpdir


@pytest.fixture
def mock_redis_client():
    mock_client = MagicMock()
    mock_client.get.return_value = None
    mock_client.setex.return_value = True
    mock_client.incr.return_value = 1
    mock_client.expire.return_value = True
    mock_client.ping.return_value = True
    return mock_client


@pytest.fixture
def sample_reading_progress() -> Dict[str, Any]:
    return {
        "user_id": "user_12345",
        "book_id": "book_gatsby_001",
        "current_position_seconds": 1200,
        "total_listening_time": 3600,
        "completion_percentage": 25.5,
        "last_accessed": datetime(2024, 1, 25, 18, 30, 0, tzinfo=timezone.utc),
        "is_completed": False,
        "updated_at": datetime(2024, 1, 25, 18, 30, 0, tzinfo=timezone.utc)
    }


@pytest.fixture
def sample_bookmark_data() -> Dict[str, Any]:
    return {
        "id": "bookmark_001",
        "user_id": "user_12345",
        "book_id": "book_gatsby_001",
        "position_seconds": 450,
        "notes": "Important passage about the green light",
        "created_at": datetime(2024, 1, 22, 10, 15, 0, tzinfo=timezone.utc)
    }


@pytest.fixture(autouse=True)
def setup_test_environment(monkeypatch):
    monkeypatch.setenv("JWT_SECRET_KEY", "test-jwt-secret-key-for-unit-tests")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/15")
    monkeypatch.setenv("DATABASE_URL", "postgresql://test:test@localhost:5432/test_db")
