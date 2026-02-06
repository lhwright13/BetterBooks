"""
Pytest Fixtures for BetterBooks Unit Tests

Provides mock objects, sample data, and test utilities for testing
core modules without requiring a real database connection.
"""

import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# Add project root to path for imports
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


# -----------------------------------------------------------------------------
# Sample Test Data
# -----------------------------------------------------------------------------

@pytest.fixture
def sample_user_data() -> Dict[str, Any]:
    """Sample user data for testing authentication and user operations."""
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
def sample_admin_data() -> Dict[str, Any]:
    """Sample admin user data."""
    return {
        "id": "admin_001",
        "email": "admin@betterbooks.com",
        "username": "admin",
        "display_name": "Administrator",
        "role": "admin",
        "is_active": True,
        "email_verified": True,
        "created_at": datetime(2024, 1, 1, 0, 0, 0, tzinfo=timezone.utc),
        "hashed_password": "$2b$12$XyZaBcDeFgHiJkLmNoPqRs"
    }


@pytest.fixture
def sample_book_data() -> Dict[str, Any]:
    """Sample book data for testing book-related operations."""
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
    """List of sample books for testing browse and library functions."""
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
    """Sample user credits data."""
    return {
        "total_credits": 10,
        "used_credits": 3,
        "available_credits": 7
    }


@pytest.fixture
def sample_user_library() -> Dict[str, Any]:
    """Sample user library data."""
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


# -----------------------------------------------------------------------------
# Mock Database Connection
# -----------------------------------------------------------------------------

@pytest.fixture
def mock_db_connection():
    """Mock psycopg2 database connection for testing db_utils."""
    mock_conn = MagicMock()
    mock_cursor = MagicMock()

    # Set up cursor as context manager
    mock_cursor.__enter__ = MagicMock(return_value=mock_cursor)
    mock_cursor.__exit__ = MagicMock(return_value=False)

    # Set up connection as context manager
    mock_conn.__enter__ = MagicMock(return_value=mock_conn)
    mock_conn.__exit__ = MagicMock(return_value=False)
    mock_conn.cursor = MagicMock(return_value=mock_cursor)

    return mock_conn, mock_cursor


@pytest.fixture
def mock_db_cursor_with_user(mock_db_connection, sample_user_data):
    """Mock database cursor that returns user data."""
    mock_conn, mock_cursor = mock_db_connection
    mock_cursor.fetchone.return_value = sample_user_data
    return mock_conn, mock_cursor


# -----------------------------------------------------------------------------
# Sample Transcript Data
# -----------------------------------------------------------------------------

@pytest.fixture
def sample_transcript_data() -> Dict[str, Any]:
    """Sample transcript JSON data for testing context retrieval."""
    # Note: Each chunk text must be >100 chars average to not be detected as placeholder
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
    """Sample placeholder transcript (short text, has note)."""
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


# -----------------------------------------------------------------------------
# Temporary Book Files Directory
# -----------------------------------------------------------------------------

@pytest.fixture
def temp_book_files_dir(sample_transcript_data):
    """Create a temporary book_files directory with test data."""
    with tempfile.TemporaryDirectory() as tmpdir:
        book_dir = Path(tmpdir) / "the-great-gatsby"
        book_dir.mkdir(parents=True)

        # Write transcript.json
        transcript_path = book_dir / "transcript.json"
        with open(transcript_path, "w", encoding="utf-8") as f:
            json.dump(sample_transcript_data, f)

        # Create personas directory with sample persona
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
    """Create a temporary config directory with global personas."""
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


# -----------------------------------------------------------------------------
# JWT and Auth Mocks
# -----------------------------------------------------------------------------

@pytest.fixture
def mock_jwt_secret():
    """Provide a test JWT secret key."""
    return "test-jwt-secret-key-for-unit-tests"


@pytest.fixture
def mock_bcrypt_available():
    """Mock bcrypt availability."""
    with patch.dict("sys.modules", {"bcrypt": MagicMock()}):
        yield


@pytest.fixture
def mock_redis_client():
    """Mock Redis client for session/rate limiting tests."""
    mock_client = MagicMock()
    mock_client.get.return_value = None
    mock_client.setex.return_value = True
    mock_client.incr.return_value = 1
    mock_client.expire.return_value = True
    mock_client.ping.return_value = True
    return mock_client


# -----------------------------------------------------------------------------
# Progress Tracking Fixtures
# -----------------------------------------------------------------------------

@pytest.fixture
def sample_reading_progress() -> Dict[str, Any]:
    """Sample reading progress data."""
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
    """Sample bookmark data."""
    return {
        "id": "bookmark_001",
        "user_id": "user_12345",
        "book_id": "book_gatsby_001",
        "position_seconds": 450,
        "notes": "Important passage about the green light",
        "created_at": datetime(2024, 1, 22, 10, 15, 0, tzinfo=timezone.utc)
    }


# -----------------------------------------------------------------------------
# Async Test Utilities
# -----------------------------------------------------------------------------

@pytest.fixture
def async_mock():
    """Create an async mock for async function testing."""
    def _create_async_mock(return_value=None):
        mock = AsyncMock()
        mock.return_value = return_value
        return mock
    return _create_async_mock


# -----------------------------------------------------------------------------
# Environment Setup
# -----------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def setup_test_environment(monkeypatch):
    """Set up test environment variables."""
    monkeypatch.setenv("JWT_SECRET_KEY", "test-jwt-secret-key-for-unit-tests")
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/15")
    monkeypatch.setenv("DATABASE_URL", "postgresql://test:test@localhost:5432/test_db")
