"""
Unit Tests for Context Retrieval Engine

Tests for:
- /Users/lhwri/BetterBooks/platform/backend/services/api_gateway/context/json_retriever.py
- /Users/lhwri/BetterBooks/platform/backend/services/api_gateway/context/interfaces.py

Covers:
- JSON transcript loading
- Timestamp-based text extraction
- Spoiler boundary enforcement
- Token estimation and truncation
- Chapter counting
"""

import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

# Add project root to path - must be before importing project modules
PROJECT_ROOT = Path(__file__).parent.parent.parent
API_GATEWAY_PATH = PROJECT_ROOT / "platform" / "backend" / "services" / "api_gateway"
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(API_GATEWAY_PATH))

# Import using relative path from api_gateway
from context.interfaces import (
    ContextResult,
    IContextRetriever
)
from context.json_retriever import (
    JsonContextRetriever
)


class TestContextResultDataclass:
    """Tests for the ContextResult dataclass."""

    def test_context_result_creation(self):
        """ContextResult should store all required fields."""
        result = ContextResult(
            text="Sample book text here.",
            token_estimate=5,
            chapters_included=[1, 2],
            current_chapter=2,
            current_timestamp=120.5,
            truncated=False,
            retrieval_method="json"
        )

        assert result.text == "Sample book text here."
        assert result.token_estimate == 5
        assert result.chapters_included == [1, 2]
        assert result.current_chapter == 2
        assert result.current_timestamp == 120.5
        assert result.truncated is False
        assert result.retrieval_method == "json"

    def test_context_result_truncated(self):
        """ContextResult should track truncation status."""
        result = ContextResult(
            text="Truncated text...",
            token_estimate=16000,
            chapters_included=[3, 4, 5],
            current_chapter=5,
            current_timestamp=300.0,
            truncated=True,
            retrieval_method="json"
        )

        assert result.truncated is True
        assert len(result.chapters_included) == 3


class TestJsonContextRetrieverInit:
    """Tests for JsonContextRetriever initialization."""

    def test_init_with_defaults(self, temp_book_files_dir):
        """Retriever should initialize with default settings."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir
        )

        assert retriever.book_files_path == Path(temp_book_files_dir)
        assert retriever._enable_runtime is True
        assert retriever._cache == {}

    def test_init_without_runtime_transcription(self, temp_book_files_dir):
        """Retriever should respect disabled runtime transcription."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        assert retriever._enable_runtime is False

    def test_init_with_custom_backend(self, temp_book_files_dir):
        """Retriever should accept custom transcription backend."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            transcription_backend="azure"
        )

        assert retriever._transcription_backend == "azure"


class TestTranscriptLoading:
    """Tests for transcript file loading."""

    def test_load_transcript_success(self, temp_book_files_dir, sample_transcript_data):
        """Should load transcript from JSON file."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        transcript = retriever._load_transcript("the-great-gatsby")

        assert transcript is not None
        assert transcript["title"] == "The Great Gatsby"
        assert transcript["total_chapters"] == 9
        assert len(transcript["chapters"]) == 3

    def test_load_transcript_caching(self, temp_book_files_dir):
        """Should cache loaded transcripts."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        # First load
        transcript1 = retriever._load_transcript("the-great-gatsby")
        # Second load should use cache
        transcript2 = retriever._load_transcript("the-great-gatsby")

        assert transcript1 is transcript2  # Same object from cache
        assert "the-great-gatsby" in retriever._cache

    def test_load_transcript_missing_file(self, temp_book_files_dir):
        """Should return None for missing transcript."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        transcript = retriever._load_transcript("nonexistent-book")

        assert transcript is None

    def test_get_transcript_path(self, temp_book_files_dir):
        """Should construct correct transcript path."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        path = retriever._get_transcript_path("the-great-gatsby")

        expected = Path(temp_book_files_dir) / "the-great-gatsby" / "transcript.json"
        assert path == expected


class TestPlaceholderDetection:
    """Tests for placeholder transcript detection."""

    def test_detect_placeholder_with_note(self, temp_book_files_dir, sample_placeholder_transcript):
        """Should detect placeholder when note field exists."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        is_placeholder = retriever._is_placeholder_transcript(sample_placeholder_transcript)

        assert is_placeholder is True

    def test_detect_placeholder_short_text(self, temp_book_files_dir):
        """Should detect placeholder when average chunk text is too short."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        short_transcript = {
            "chapters": [
                {
                    "chapter": 1,
                    "chunks": [
                        {"text": "Short."},
                        {"text": "Also short."},
                        {"text": "Tiny."}
                    ]
                }
            ]
        }

        is_placeholder = retriever._is_placeholder_transcript(short_transcript)

        assert is_placeholder is True

    def test_real_transcript_not_placeholder(self, temp_book_files_dir, sample_transcript_data):
        """Should not flag real transcripts as placeholders."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        is_placeholder = retriever._is_placeholder_transcript(sample_transcript_data)

        assert is_placeholder is False


class TestTokenEstimation:
    """Tests for token estimation."""

    def test_estimate_tokens_short_text(self, temp_book_files_dir):
        """Should estimate tokens for short text."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        # ~40 chars / 4 = 10 tokens
        estimate = retriever._estimate_tokens("This is a short text for testing.")

        assert estimate >= 8
        assert estimate <= 12

    def test_estimate_tokens_long_text(self, temp_book_files_dir):
        """Should estimate tokens for longer text."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        # 1000 chars / 4 = 250 tokens
        long_text = "word " * 200  # ~1000 chars
        estimate = retriever._estimate_tokens(long_text)

        assert estimate >= 200
        assert estimate <= 300

    def test_estimate_tokens_empty(self, temp_book_files_dir):
        """Should return 0 for empty text."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        estimate = retriever._estimate_tokens("")

        assert estimate == 0


class TestContextRetrieval:
    """Tests for the main get_context method."""

    @pytest.mark.asyncio
    async def test_get_context_chapter_one_start(self, temp_book_files_dir):
        """Should get context from start of first chapter."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=0.0
        )

        assert isinstance(result, ContextResult)
        assert result.current_chapter == 1
        assert result.current_timestamp == 0.0
        assert 1 in result.chapters_included
        # Should have first chunk text
        assert "younger and more vulnerable" in result.text

    @pytest.mark.asyncio
    async def test_get_context_mid_chapter(self, temp_book_files_dir):
        """Should get context up to mid-chapter timestamp."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=50.0  # Between chunk 1 (35s) and chunk 2 (70s)
        )

        assert result.current_chapter == 1
        # Should include chunks 0 and 1
        assert "younger and more vulnerable" in result.text
        assert "unusually communicative" in result.text
        # Should NOT include chunk 2 (starts at 70s)
        assert "abnormal mind" not in result.text

    @pytest.mark.asyncio
    async def test_get_context_respects_spoiler_boundary(self, temp_book_files_dir):
        """Should not include text beyond current timestamp (spoiler prevention)."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=2,
            timestamp_seconds=30.0  # In chapter 2, before second chunk
        )

        # Should include chapter 1 fully
        assert "Chapter 1" in result.text
        # Should include chapter 2 first chunk
        assert "West Egg" in result.text
        # Should NOT include chapter 2 second chunk (starts at 40s)
        assert "valley of ashes" not in result.text
        # Should definitely NOT include chapter 3
        assert "Chapter 3" not in result.text

    @pytest.mark.asyncio
    async def test_get_context_includes_previous_chapters(self, temp_book_files_dir):
        """Should include all text from previous chapters."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=2,
            timestamp_seconds=100.0  # Well into chapter 2
        )

        # Should include chapter 1
        assert 1 in result.chapters_included
        # Should include chapter 2
        assert 2 in result.chapters_included
        # Should NOT include chapter 3
        assert 3 not in result.chapters_included

    @pytest.mark.asyncio
    async def test_get_context_missing_transcript(self, temp_book_files_dir):
        """Should return empty context for missing transcript."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="nonexistent-book",
            chapter=1,
            timestamp_seconds=0.0
        )

        assert result.text == ""
        assert result.token_estimate == 0
        assert result.chapters_included == []

    @pytest.mark.asyncio
    async def test_get_context_truncation_removes_oldest(self, temp_book_files_dir):
        """Should truncate from beginning when exceeding max_tokens."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        # Request with very low max_tokens
        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=3,
            timestamp_seconds=100.0,
            max_tokens=50  # Very low limit
        )

        # Should be truncated
        if result.token_estimate > 50:
            # If we got more tokens, it means we couldn't truncate further
            # (only one chapter left)
            assert len(result.chapters_included) == 1
        else:
            # Should have removed oldest chapters first
            assert result.truncated is True or len(result.chapters_included) < 3


class TestChapterCounting:
    """Tests for chapter count retrieval."""

    @pytest.mark.asyncio
    async def test_get_chapter_count_from_transcript(self, temp_book_files_dir):
        """Should get chapter count from transcript file."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        count = await retriever.get_chapter_count("the-great-gatsby")

        assert count == 3  # Sample transcript has 3 chapters

    @pytest.mark.asyncio
    async def test_get_chapter_count_no_transcript(self, temp_book_files_dir):
        """Should return 0 for books without transcript."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        count = await retriever.get_chapter_count("nonexistent-book")

        assert count == 0


class TestTranscriptAvailability:
    """Tests for transcript availability checking."""

    @pytest.mark.asyncio
    async def test_has_transcript_true(self, temp_book_files_dir):
        """Should return True when transcript exists."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        has_it = await retriever.has_transcript("the-great-gatsby")

        assert has_it is True

    @pytest.mark.asyncio
    async def test_has_transcript_false(self, temp_book_files_dir):
        """Should return False when transcript doesn't exist."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        has_it = await retriever.has_transcript("nonexistent-book")

        assert has_it is False


class TestTranscriptionStatus:
    """Tests for transcription status reporting."""

    def test_get_transcription_status_with_transcript(self, temp_book_files_dir):
        """Should report status for book with transcript."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        status = retriever.get_transcription_status("the-great-gatsby")

        assert status["book_id"] == "the-great-gatsby"
        assert status["has_json_transcript"] is True
        assert status["is_placeholder"] is False
        assert status["json_chapters"] == 3

    def test_get_transcription_status_no_transcript(self, temp_book_files_dir):
        """Should report status for book without transcript."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        status = retriever.get_transcription_status("nonexistent-book")

        assert status["book_id"] == "nonexistent-book"
        assert status["has_json_transcript"] is False


class TestCacheManagement:
    """Tests for cache clearing functionality."""

    def test_clear_cache(self, temp_book_files_dir):
        """Should clear the transcript cache."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        # Load to populate cache
        retriever._load_transcript("the-great-gatsby")
        assert len(retriever._cache) > 0

        # Clear cache
        retriever.clear_cache()

        assert retriever._cache == {}


class TestChapterMarkers:
    """Tests for chapter marker formatting in output."""

    @pytest.mark.asyncio
    async def test_chapter_markers_in_output(self, temp_book_files_dir):
        """Context should include chapter markers for clarity."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=2,
            timestamp_seconds=100.0
        )

        # Should have chapter markers
        assert "=== Chapter 1 ===" in result.text
        assert "=== Chapter 2 ===" in result.text


class TestEdgeCases:
    """Tests for edge cases and boundary conditions."""

    @pytest.mark.asyncio
    async def test_zero_timestamp_includes_first_chunk(self, temp_book_files_dir):
        """At timestamp 0, should include first chunk for initial context."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=0.0
        )

        # Should have at least the first chunk
        assert result.text != ""
        assert result.token_estimate > 0

    @pytest.mark.asyncio
    async def test_exact_chunk_boundary(self, temp_book_files_dir):
        """At exact chunk boundary, should include that chunk."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=35.0  # Exact start of chunk 1
        )

        # Should include chunk at 35s
        assert "unusually communicative" in result.text

    @pytest.mark.asyncio
    async def test_very_large_timestamp(self, temp_book_files_dir):
        """Large timestamp should include all available content."""
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=10000.0  # Way past any chunk
        )

        # Should include all of chapter 1
        assert "younger and more vulnerable" in result.text
        assert "unusually communicative" in result.text
        assert "abnormal mind" in result.text
