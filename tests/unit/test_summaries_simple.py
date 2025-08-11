"""
Simple test for Smart Chapter Summaries core functionality.

This tests the core data structures and logic without external dependencies.
"""

import sys
from pathlib import Path
from datetime import datetime

# Add project root to path to import core modules
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

# Import only the core classes (not the generator which needs aiohttp)
try:
    from core.ai import summary_types, chapter_detection
    SummaryStyle = summary_types.SummaryStyle
    ChapterSummary = summary_types.ChapterSummary
    SummaryRequest = summary_types.SummaryRequest
    DetectedChapter = chapter_detection.DetectedChapter
    print("✅ Successfully imported core summary classes")
except ImportError as e:
    print(f"❌ Failed to import classes: {e}")
    sys.exit(1)

def test_summary_styles():
    """Test that all summary styles are defined correctly."""
    print("🧪 Testing Summary Styles...")
    
    expected_styles = ['brief', 'detailed', 'themes', 'key_points', 'question_based']
    
    for style_name in expected_styles:
        try:
            style = SummaryStyle(style_name)
            assert style.value == style_name
            print(f"  ✅ {style_name} style works")
        except Exception as e:
            print(f"  ❌ {style_name} style failed: {e}")
            return False
    
    return True

def test_chapter_summary_creation():
    """Test creating ChapterSummary objects."""
    print("🧪 Testing ChapterSummary Creation...")
    
    try:
        summary = ChapterSummary(
            chapter_id="chapter_1",
            chapter_number=1,
            chapter_title="The Beginning",
            summary_style=SummaryStyle.DETAILED,
            summary_text="This chapter introduces the main character and sets up the story world.",
            key_points=["Character introduction", "World building", "Initial conflict"],
            themes=["New beginnings", "Hope", "Adventure"],
            characters_mentioned=["Alice", "White Rabbit"],
            word_count=65,
            confidence_score=0.85,
            generation_timestamp=datetime.now(),
            metadata={"model": "gemini-pro", "processing_time": 12.5}
        )
        
        # Validate all fields
        assert summary.chapter_number == 1
        assert summary.chapter_title == "The Beginning"
        assert summary.summary_style == SummaryStyle.DETAILED
        assert len(summary.key_points) == 3
        assert len(summary.themes) == 3
        assert len(summary.characters_mentioned) == 2
        assert summary.word_count == 65
        assert 0.0 <= summary.confidence_score <= 1.0
        assert isinstance(summary.generation_timestamp, datetime)
        assert isinstance(summary.metadata, dict)
        
        print("  ✅ ChapterSummary object created successfully")
        print(f"  ✅ All fields validated (confidence: {summary.confidence_score})")
        return True
        
    except Exception as e:
        print(f"  ❌ ChapterSummary creation failed: {e}")
        return False

def test_summary_request_creation():
    """Test creating SummaryRequest objects."""
    print("🧪 Testing SummaryRequest Creation...")
    
    try:
        request = SummaryRequest(
            book_id="book_12345",
            book_title="Alice's Adventures in Wonderland",
            chapter_ids=["chapter_1", "chapter_2", "chapter_3"],
            summary_style=SummaryStyle.BRIEF,
            include_themes=True,
            include_characters=True,
            max_summary_length=200,
            custom_prompt="Focus on character development"
        )
        
        # Validate fields
        assert request.book_id == "book_12345"
        assert request.book_title == "Alice's Adventures in Wonderland"
        assert len(request.chapter_ids) == 3
        assert request.summary_style == SummaryStyle.BRIEF
        assert request.include_themes is True
        assert request.include_characters is True
        assert request.max_summary_length == 200
        assert request.custom_prompt == "Focus on character development"
        
        print("  ✅ SummaryRequest object created successfully")
        print("  ✅ All fields validated")
        return True
        
    except Exception as e:
        print(f"  ❌ SummaryRequest creation failed: {e}")
        return False

def test_integration_with_chapter_detection():
    """Test compatibility with DetectedChapter objects."""
    print("🧪 Testing Integration with Chapter Detection...")
    
    try:
        # Create a DetectedChapter (from existing system)
        detected_chapter = DetectedChapter(
            chapter_number=1,
            title="The Rabbit Hole",
            start_time=0.0,
            end_time=420.5,
            duration=420.5,
            confidence=0.92,
            summary="Alice falls down a rabbit hole into Wonderland",
            key_topics=["rabbit hole", "falling", "curiosity"],
            word_count=850,
            speaker_changes=1
        )
        
        # Create a ChapterSummary that corresponds to it
        chapter_summary = ChapterSummary(
            chapter_id=f"chapter_{detected_chapter.chapter_number}",
            chapter_number=detected_chapter.chapter_number,
            chapter_title=detected_chapter.title,
            summary_style=SummaryStyle.DETAILED,
            summary_text="In this opening chapter, young Alice follows a White Rabbit down a mysterious rabbit hole, tumbling into the fantastical world of Wonderland where normal rules don't apply.",
            key_points=[
                "Alice sees a White Rabbit with a pocket watch",
                "She follows the rabbit down a hole",
                "Falls for a long time, observing strange things",
                "Lands in a hall full of locked doors"
            ],
            themes=["Curiosity and adventure", "Loss of control", "Transition to new world"],
            characters_mentioned=["Alice", "White Rabbit"],
            word_count=156,
            confidence_score=0.88,
            generation_timestamp=datetime.now(),
            metadata={
                "source_chapter": {
                    "duration": detected_chapter.duration,
                    "detection_confidence": detected_chapter.confidence,
                    "original_word_count": detected_chapter.word_count
                }
            }
        )
        
        # Validate integration
        assert chapter_summary.chapter_number == detected_chapter.chapter_number
        assert chapter_summary.chapter_title == detected_chapter.title
        assert "source_chapter" in chapter_summary.metadata
        
        print("  ✅ DetectedChapter and ChapterSummary integration works")
        print(f"  ✅ Chapter {detected_chapter.chapter_number}: '{detected_chapter.title}'")
        print(f"  ✅ Summary generated with {chapter_summary.confidence_score:.2f} confidence")
        return True
        
    except Exception as e:
        print(f"  ❌ Integration test failed: {e}")
        return False

def test_multiple_summary_styles():
    """Test creating summaries with different styles."""
    print("🧪 Testing Multiple Summary Styles...")
    
    chapter_text = "Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do. Once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it."
    
    styles_to_test = [
        (SummaryStyle.BRIEF, "Brief summary for quick reading"),
        (SummaryStyle.DETAILED, "Detailed summary with comprehensive coverage"),
        (SummaryStyle.THEMES, "Summary focused on literary themes and symbols"),
        (SummaryStyle.KEY_POINTS, "• Point 1: Alice is bored\n• Point 2: Sister reading\n• Point 3: Book lacks pictures"),
        (SummaryStyle.QUESTION_BASED, "What is Alice doing? She's sitting with her sister.")
    ]
    
    try:
        for style, sample_text in styles_to_test:
            summary = ChapterSummary(
                chapter_id="test_chapter",
                chapter_number=1,
                chapter_title="Test Chapter",
                summary_style=style,
                summary_text=sample_text,
                key_points=["Test point"] if style != SummaryStyle.KEY_POINTS else [],
                themes=["Boredom", "Curiosity"] if style == SummaryStyle.THEMES else [],
                characters_mentioned=["Alice"],
                word_count=len(sample_text.split()),
                confidence_score=0.75,
                generation_timestamp=datetime.now(),
                metadata={"style": style.value}
            )
            
            assert summary.summary_style == style
            print(f"  ✅ {style.value} style summary created")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Multiple styles test failed: {e}")
        return False

def run_all_tests():
    """Run all core functionality tests."""
    print("📚 Smart Chapter Summaries - Core Functionality Tests")
    print("=" * 60)
    
    tests = [
        ("Summary Styles", test_summary_styles),
        ("ChapterSummary Creation", test_chapter_summary_creation),
        ("SummaryRequest Creation", test_summary_request_creation),
        ("Chapter Detection Integration", test_integration_with_chapter_detection),
        ("Multiple Summary Styles", test_multiple_summary_styles),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🔍 Running: {test_name}")
        try:
            if test_func():
                passed += 1
                print(f"✅ {test_name} PASSED")
            else:
                print(f"❌ {test_name} FAILED")
        except Exception as e:
            print(f"❌ {test_name} CRASHED: {e}")
    
    print(f"\n📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 ALL CORE TESTS PASSED!")
        print("\n📋 Smart Chapter Summaries Core Features Verified:")
        print("  ✅ 5 summary styles (brief, detailed, themes, key_points, question_based)")
        print("  ✅ ChapterSummary data structure with full metadata")
        print("  ✅ SummaryRequest configuration system")
        print("  ✅ Integration with existing chapter detection")
        print("  ✅ Multiple summary style support")
        print("\n🚀 Ready for API integration and LLM-powered generation!")
        return True
    else:
        print(f"⚠️ {total - passed} tests failed. Please review the implementation.")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)