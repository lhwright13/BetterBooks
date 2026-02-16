import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).parent.parent.parent
API_GATEWAY_PATH = PROJECT_ROOT / "platform" / "backend" / "services" / "api_gateway"
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(API_GATEWAY_PATH))

from context.interfaces import ContextResult
from context.json_retriever import JsonContextRetriever


class TestContextResultDataclass:

    def test_context_result_creation(self):
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

    def test_init_with_defaults(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir
        )

        assert retriever.book_files_path == Path(temp_book_files_dir)
        assert retriever._enable_runtime is True
        assert retriever._cache == {}

    def test_init_without_runtime_transcription(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        assert retriever._enable_runtime is False

    def test_init_with_custom_backend(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            transcription_backend="azure"
        )

        assert retriever._transcription_backend == "azure"


class TestTranscriptLoading:

    def test_load_transcript_success(self, temp_book_files_dir, sample_transcript_data):
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
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        transcript1 = retriever._load_transcript("the-great-gatsby")
        transcript2 = retriever._load_transcript("the-great-gatsby")

        assert transcript1 is transcript2
        assert "the-great-gatsby" in retriever._cache

    def test_load_transcript_missing_file(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        transcript = retriever._load_transcript("nonexistent-book")

        assert transcript is None

    def test_get_transcript_path(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        path = retriever._get_transcript_path("the-great-gatsby")

        expected = Path(temp_book_files_dir) / "the-great-gatsby" / "transcript.json"
        assert path == expected


class TestPlaceholderDetection:

    def test_detect_placeholder_with_note(self, temp_book_files_dir, sample_placeholder_transcript):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        is_placeholder = retriever._is_placeholder_transcript(sample_placeholder_transcript)

        assert is_placeholder is True

    def test_detect_placeholder_short_text(self, temp_book_files_dir):
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
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        is_placeholder = retriever._is_placeholder_transcript(sample_transcript_data)

        assert is_placeholder is False


class TestTokenEstimation:

    def test_estimate_tokens_short_text(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        estimate = retriever._estimate_tokens("This is a short text for testing.")

        assert estimate >= 8
        assert estimate <= 12

    def test_estimate_tokens_long_text(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        long_text = "word " * 200
        estimate = retriever._estimate_tokens(long_text)

        assert estimate >= 200
        assert estimate <= 300

    def test_estimate_tokens_empty(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        estimate = retriever._estimate_tokens("")

        assert estimate == 0


class TestContextRetrieval:

    @pytest.mark.asyncio
    async def test_get_context_chapter_one_start(self, temp_book_files_dir):
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
        assert "younger and more vulnerable" in result.text

    @pytest.mark.asyncio
    async def test_get_context_mid_chapter(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=50.0
        )

        assert result.current_chapter == 1
        assert "younger and more vulnerable" in result.text
        assert "unusually communicative" in result.text
        assert "abnormal mind" not in result.text

    @pytest.mark.asyncio
    async def test_get_context_respects_spoiler_boundary(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=2,
            timestamp_seconds=30.0
        )

        assert "Chapter 1" in result.text
        assert "West Egg" in result.text
        assert "valley of ashes" not in result.text
        assert "Chapter 3" not in result.text

    @pytest.mark.asyncio
    async def test_get_context_includes_previous_chapters(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=2,
            timestamp_seconds=100.0
        )

        assert 1 in result.chapters_included
        assert 2 in result.chapters_included
        assert 3 not in result.chapters_included

    @pytest.mark.asyncio
    async def test_get_context_missing_transcript(self, temp_book_files_dir):
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
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=3,
            timestamp_seconds=100.0,
            max_tokens=50
        )

        if result.token_estimate > 50:
            assert len(result.chapters_included) == 1
        else:
            assert result.truncated is True or len(result.chapters_included) < 3


class TestChapterCounting:

    @pytest.mark.asyncio
    async def test_get_chapter_count_from_transcript(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        count = await retriever.get_chapter_count("the-great-gatsby")

        assert count == 3

    @pytest.mark.asyncio
    async def test_get_chapter_count_no_transcript(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        count = await retriever.get_chapter_count("nonexistent-book")

        assert count == 0


class TestTranscriptAvailability:

    @pytest.mark.asyncio
    async def test_has_transcript_true(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        has_it = await retriever.has_transcript("the-great-gatsby")

        assert has_it is True

    @pytest.mark.asyncio
    async def test_has_transcript_false(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        has_it = await retriever.has_transcript("nonexistent-book")

        assert has_it is False


class TestTranscriptionStatus:

    def test_get_transcription_status_with_transcript(self, temp_book_files_dir):
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
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        status = retriever.get_transcription_status("nonexistent-book")

        assert status["book_id"] == "nonexistent-book"
        assert status["has_json_transcript"] is False


class TestCacheManagement:

    def test_clear_cache(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        retriever._load_transcript("the-great-gatsby")
        assert len(retriever._cache) > 0

        retriever.clear_cache()

        assert retriever._cache == {}


class TestChapterMarkers:

    @pytest.mark.asyncio
    async def test_chapter_markers_in_output(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=2,
            timestamp_seconds=100.0
        )

        assert "=== Chapter 1 ===" in result.text
        assert "=== Chapter 2 ===" in result.text


class TestEdgeCases:

    @pytest.mark.asyncio
    async def test_zero_timestamp_includes_first_chunk(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=0.0
        )

        assert result.text != ""
        assert result.token_estimate > 0

    @pytest.mark.asyncio
    async def test_exact_chunk_boundary(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=35.0
        )

        assert "unusually communicative" in result.text

    @pytest.mark.asyncio
    async def test_very_large_timestamp(self, temp_book_files_dir):
        retriever = JsonContextRetriever(
            book_files_path=temp_book_files_dir,
            enable_runtime_transcription=False
        )

        result = await retriever.get_context(
            book_id="the-great-gatsby",
            chapter=1,
            timestamp_seconds=10000.0
        )

        assert "younger and more vulnerable" in result.text
        assert "unusually communicative" in result.text
        assert "abnormal mind" in result.text
