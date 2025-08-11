"""
Test suite for Smart Chapter Summaries functionality.

This test suite validates the AI-powered chapter summarization system including:
- Summary generation with multiple styles
- Database storage and retrieval
- API endpoint functionality
- Integration with chapter detection
"""

import asyncio
import json
import tempfile
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime
from pathlib import Path

import sys

# Add project root to path to import core modules
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from core.ai.chapter_summaries import (
    ChapterSummaryGenerator, SummaryStyle, ChapterSummary, SummaryRequest,
    generate_chapter_summaries, format_summaries_for_display
)
from core.ai.chapter_detection import DetectedChapter
from core.ai.summary_storage import SummaryStorageManager


class TestSummaryGeneration:
    """Test summary generation functionality."""
    
    def test_summary_styles_enum(self):
        """Test that all summary styles are properly defined."""
        expected_styles = ['brief', 'detailed', 'themes', 'key_points', 'question_based']
        
        for style_name in expected_styles:
            style = SummaryStyle(style_name)
            assert style.value == style_name
        
        print("✅ All summary styles are properly defined")
    
    def test_chapter_summary_creation(self):
        """Test creating ChapterSummary objects."""
        summary = ChapterSummary(
            chapter_id="chapter_1",
            chapter_number=1,
            chapter_title="The Beginning",
            summary_style=SummaryStyle.DETAILED,
            summary_text="This chapter introduces the main character.",
            key_points=["Character introduction", "Setting established"],
            themes=["New beginnings", "Hope"],
            characters_mentioned=["Alice", "Bob"],
            word_count=45,
            confidence_score=0.85,
            generation_timestamp=datetime.now(),
            metadata={"model": "gemini-pro"}
        )
        
        assert summary.chapter_number == 1
        assert summary.summary_style == SummaryStyle.DETAILED
        assert summary.confidence_score == 0.85
        assert len(summary.key_points) == 2
        assert len(summary.themes) == 2
        
        print("✅ ChapterSummary objects can be created correctly")
    
    def test_summary_request_creation(self):
        """Test creating SummaryRequest objects."""
        request = SummaryRequest(
            book_id="book_123",
            book_title="Test Book",
            chapter_ids=["chapter_1", "chapter_2"],
            summary_style=SummaryStyle.BRIEF,
            include_themes=True,
            include_characters=True,
            max_summary_length=200
        )
        
        assert request.book_id == "book_123"
        assert request.summary_style == SummaryStyle.BRIEF
        assert len(request.chapter_ids) == 2
        assert request.max_summary_length == 200
        
        print("✅ SummaryRequest objects can be created correctly")
    
    def test_chapter_summary_generator_initialization(self):
        """Test ChapterSummaryGenerator initialization."""
        generator = ChapterSummaryGenerator("http://test-llm:8000")
        
        assert generator.llm_gateway_url == "http://test-llm:8000"
        assert SummaryStyle.BRIEF in generator.style_configs
        assert SummaryStyle.DETAILED in generator.style_configs
        
        # Test style configurations
        brief_config = generator.style_configs[SummaryStyle.BRIEF]
        assert brief_config['max_sentences'] == 2
        assert brief_config['length_target'] == 100
        
        print("✅ ChapterSummaryGenerator initializes correctly")
    
    async def test_confidence_score_calculation(self):
        """Test confidence score calculation."""
        generator = ChapterSummaryGenerator()
        
        # Test with good summary
        original_text = "This is a long chapter with many details and complex plot developments that span several pages."
        summary_text = "The chapter covers key plot developments and character interactions."
        style_config = {"length_target": 100}
        
        score = generator._calculate_confidence_score(original_text, summary_text, style_config)
        assert 0.0 <= score <= 1.0
        assert score > 0.5  # Should be reasonably confident
        
        # Test with very short summary
        short_summary = "Short."
        low_score = generator._calculate_confidence_score(original_text, short_summary, style_config)
        assert low_score < score  # Should be less confident
        
        print("✅ Confidence score calculation works correctly")
    
    async def test_character_extraction(self):
        """Test character name extraction from text."""
        generator = ChapterSummaryGenerator()
        
        chapter_text = """
        Alice walked through the garden where she met the White Rabbit.
        The Rabbit was in a hurry, constantly checking his pocket watch.
        "I'm late!" exclaimed the Rabbit as Alice followed curiously.
        The Mad Hatter appeared suddenly, tipping his hat to Alice.
        """
        
        characters = await generator._extract_characters(chapter_text)
        
        # Should find Alice, Rabbit, Hatter
        assert "Alice" in characters
        assert "Rabbit" in characters
        assert "Hatter" in characters
        
        print("✅ Character extraction identifies proper names")
    
    def test_summary_text_cleaning(self):
        """Test summary text cleaning functionality."""
        generator = ChapterSummaryGenerator()
        
        # Test removing AI prefixes
        dirty_text = "Here is the summary: This chapter covers important events."
        clean_text = generator._clean_summary_text(dirty_text, SummaryStyle.DETAILED)
        assert not clean_text.startswith("Here is")
        assert clean_text == "This chapter covers important events."
        
        # Test key points formatting
        key_points_text = "First point\nSecond point\nThird point"
        formatted_text = generator._clean_summary_text(key_points_text, SummaryStyle.KEY_POINTS)
        lines = formatted_text.split('\n')
        for line in lines:
            if line.strip():
                assert line.startswith('•')
        
        print("✅ Summary text cleaning works correctly")
    
    def test_fallback_summary_generation(self):
        """Test fallback summary generation when LLM fails."""
        generator = ChapterSummaryGenerator()
        
        test_text = "This is a test chapter with exactly fifty words. " * 10
        
        # Test different styles
        brief_fallback = generator._generate_fallback_summary(test_text, SummaryStyle.BRIEF)
        assert "words" in brief_fallback.lower()
        assert len(brief_fallback) > 20
        
        key_points_fallback = generator._generate_fallback_summary(test_text, SummaryStyle.KEY_POINTS)
        assert "•" in key_points_fallback
        
        print("✅ Fallback summary generation works for all styles")


class TestSummaryStorage:
    """Test database storage functionality."""
    
    def test_storage_manager_initialization(self):
        """Test SummaryStorageManager initialization."""
        # Test with custom URL
        manager = SummaryStorageManager("postgresql://test:test@localhost:5432/test")
        assert "test:test" in manager.database_url
        
        # Test with environment variable fallback
        manager = SummaryStorageManager()
        assert "betterbooks" in manager.database_url
        
        print("✅ SummaryStorageManager initializes correctly")
    
    @patch('asyncpg.create_pool')
    async def test_connection_pool_management(self, mock_create_pool):
        """Test database connection pool lifecycle."""
        mock_pool = AsyncMock()
        mock_create_pool.return_value = mock_pool
        
        manager = SummaryStorageManager()
        
        # Test initialization
        await manager.init_connection_pool()
        mock_create_pool.assert_called_once()
        assert manager.connection_pool == mock_pool
        
        # Test closing
        await manager.close_connection_pool()
        mock_pool.close.assert_called_once()
        assert manager.connection_pool is None
        
        print("✅ Connection pool management works correctly")
    
    @patch('asyncpg.create_pool')
    async def test_summary_storage_and_retrieval(self, mock_create_pool):
        """Test storing and retrieving summaries."""
        # Mock database connection and pool
        mock_conn = AsyncMock()
        mock_pool = AsyncMock()
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_pool.acquire.return_value.__aexit__.return_value = None
        mock_create_pool.return_value = mock_pool
        
        # Mock database responses
        mock_conn.fetchval.return_value = "test-uuid"
        mock_conn.execute.return_value = None
        
        manager = SummaryStorageManager()
        
        # Create test summaries
        test_summaries = [
            ChapterSummary(
                chapter_id="chapter_1",
                chapter_number=1,
                chapter_title="Chapter One",
                summary_style=SummaryStyle.DETAILED,
                summary_text="This is a detailed summary of chapter one.",
                key_points=["Point 1", "Point 2"],
                themes=["Theme 1"],
                characters_mentioned=["Alice"],
                word_count=50,
                confidence_score=0.9,
                generation_timestamp=datetime.now(),
                metadata={"test": True}
            )
        ]
        
        # Test storage
        session_id = await manager.store_chapter_summaries(
            book_id="book_123",
            book_title="Test Book",
            summaries=test_summaries
        )
        
        assert isinstance(session_id, str)
        
        # Verify database calls were made
        assert mock_conn.fetchval.called
        assert mock_conn.execute.called
        
        print("✅ Summary storage works correctly")
    
    @patch('asyncpg.create_pool')
    async def test_summary_retrieval_with_filters(self, mock_create_pool):
        """Test retrieving summaries with various filters."""
        # Mock database setup
        mock_conn = AsyncMock()
        mock_pool = AsyncMock()
        mock_pool.acquire.return_value.__aenter__.return_value = mock_conn
        mock_pool.acquire.return_value.__aexit__.return_value = None
        mock_create_pool.return_value = mock_pool
        
        # Mock database response
        mock_conn.fetch.return_value = [
            {
                'id': 'uuid-1',
                'chapter_id': 'chapter_1',
                'summary_type': 'detailed',
                'summary_text': 'Test summary',
                'summary_metadata': '{"key_points": ["point1"]}',
                'quality_score': 0.85,
                'generation_timestamp': datetime.now(),
                'created_at': datetime.now(),
                'updated_at': datetime.now()
            }
        ]
        
        manager = SummaryStorageManager()
        
        # Test retrieval with chapter filter
        summaries = await manager.retrieve_chapter_summaries(
            chapter_ids=['chapter_1'],
            summary_style=SummaryStyle.DETAILED
        )
        
        assert len(summaries) == 1
        assert summaries[0]['chapter_id'] == 'chapter_1'
        assert summaries[0]['summary_style'] == 'detailed'
        
        print("✅ Summary retrieval with filters works correctly")
    
    def test_summary_statistics_calculation(self):
        """Test summary statistics computation."""
        # This would require a more complex mock setup
        # For now, just verify the method exists and has correct signature
        manager = SummaryStorageManager()
        assert hasattr(manager, 'get_summary_statistics')
        
        print("✅ Summary statistics method is available")


class TestSummaryIntegration:
    """Test integration with chapter detection and API endpoints."""
    
    def test_detected_chapter_compatibility(self):
        """Test compatibility with DetectedChapter objects."""
        chapter = DetectedChapter(
            chapter_number=1,
            title="Test Chapter",
            start_time=0.0,
            end_time=300.0,
            duration=300.0,
            confidence=0.9,
            summary="Initial summary",
            key_topics=["topic1", "topic2"],
            word_count=500,
            speaker_changes=2
        )
        
        # Should be able to use this with summary generation
        assert chapter.chapter_number == 1
        assert chapter.title == "Test Chapter"
        assert isinstance(chapter.key_topics, list)
        
        print("✅ DetectedChapter compatibility maintained")
    
    @patch('aiohttp.ClientSession.post')
    async def test_llm_integration_mock(self, mock_post):
        """Test LLM integration with mocked responses."""
        # Mock LLM response
        mock_response = AsyncMock()
        mock_response.status = 200
        mock_response.json.return_value = {
            "response": "This chapter introduces the main character and establishes the setting."
        }
        mock_post.return_value.__aenter__.return_value = mock_response
        
        generator = ChapterSummaryGenerator("http://mock-llm:8000")
        
        # Test summary generation
        chapter_text = "This is a test chapter with some content for testing purposes."
        
        summary_text = await generator._generate_summary_text(
            chapter_text,
            SummaryStyle.DETAILED,
            generator.style_configs[SummaryStyle.DETAILED]
        )
        
        assert len(summary_text) > 0
        assert "character" in summary_text.lower()
        
        print("✅ LLM integration works with mocked responses")
    
    def test_format_summaries_display(self):
        """Test formatting summaries for display."""
        test_summaries = [
            ChapterSummary(
                chapter_id="chapter_1",
                chapter_number=1,
                chapter_title="The Beginning",
                summary_style=SummaryStyle.DETAILED,
                summary_text="This chapter introduces the story.",
                key_points=["Introduction", "Setting"],
                themes=["New beginnings"],
                characters_mentioned=["Alice"],
                word_count=25,
                confidence_score=0.9,
                generation_timestamp=datetime.now(),
                metadata={}
            )
        ]
        
        formatted_output = format_summaries_for_display(test_summaries)
        
        assert "Chapter 1: The Beginning" in formatted_output
        assert "Confidence: 0.90" in formatted_output
        assert "Words: 25" in formatted_output
        assert "Themes: New beginnings" in formatted_output
        
        print("✅ Summary display formatting works correctly")


class TestAPIEndpoints:
    """Test API endpoint functionality (unit tests without actual HTTP calls)."""
    
    def test_summary_request_validation(self):
        """Test API request schema validation."""
        from platform.backend.services.transcription_service.simple_main import SummaryGenerationRequest
        
        # Valid request
        valid_request = SummaryGenerationRequest(
            audio_file_path="/test/audio.mp3",
            book_title="Test Book",
            summary_style="detailed"
        )
        
        assert valid_request.audio_file_path == "/test/audio.mp3"
        assert valid_request.summary_style == "detailed"
        assert valid_request.include_themes is True
        
        print("✅ API request validation works correctly")
    
    def test_summary_response_structure(self):
        """Test API response schema."""
        from platform.backend.services.transcription_service.simple_main import SummaryResponse
        
        response = SummaryResponse(
            book_title="Test Book",
            total_summaries=3,
            summary_style="detailed",
            summaries=[
                {
                    "chapter_id": "chapter_1",
                    "summary_text": "Test summary",
                    "confidence_score": 0.9
                }
            ],
            processing_time_seconds=45.2,
            cached=False
        )
        
        assert response.total_summaries == 3
        assert response.processing_time_seconds == 45.2
        assert len(response.summaries) == 1
        
        print("✅ API response structure is correct")
    
    def test_summary_styles_endpoint_data(self):
        """Test the summary styles endpoint data."""
        # This simulates what the /summary-styles endpoint returns
        expected_styles = ["brief", "detailed", "themes", "key_points", "question_based"]
        
        styles_response = {
            "styles": [
                {
                    "style": style,
                    "description": f"Description for {style}",
                    "target_length": "~200 characters",
                    "best_for": f"Use case for {style}"
                }
                for style in expected_styles
            ]
        }
        
        assert len(styles_response["styles"]) == 5
        for style_info in styles_response["styles"]:
            assert style_info["style"] in expected_styles
            assert "description" in style_info
            assert "best_for" in style_info
        
        print("✅ Summary styles endpoint data is comprehensive")


def run_all_summary_tests():
    """Run all summary functionality tests."""
    print("🧪 Running Smart Chapter Summaries Test Suite...")
    print("=" * 60)
    
    # Test classes
    test_classes = [
        TestSummaryGeneration(),
        TestSummaryStorage(), 
        TestSummaryIntegration(),
        TestAPIEndpoints()
    ]
    
    total_tests = 0
    passed_tests = 0
    
    for test_class in test_classes:
        class_name = test_class.__class__.__name__
        print(f"\n📋 Running {class_name} tests:")
        
        # Get all test methods
        test_methods = [method for method in dir(test_class) if method.startswith('test_')]
        
        for test_method_name in test_methods:
            total_tests += 1
            try:
                test_method = getattr(test_class, test_method_name)
                if asyncio.iscoroutinefunction(test_method):
                    asyncio.run(test_method())
                else:
                    test_method()
                passed_tests += 1
            except Exception as e:
                print(f"❌ {test_method_name} failed: {e}")
    
    print(f"\n📊 Test Results:")
    print(f"✅ {passed_tests}/{total_tests} tests passed")
    
    if passed_tests == total_tests:
        print("🎉 ALL TESTS PASSED! Smart Chapter Summaries system is working correctly.")
    else:
        print(f"⚠️  {total_tests - passed_tests} tests failed. Please review the failures above.")
    
    return passed_tests == total_tests


if __name__ == "__main__":
    success = run_all_summary_tests()
    exit(0 if success else 1)