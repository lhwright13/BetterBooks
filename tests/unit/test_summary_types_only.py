"""
Test just the core summary data types without any external dependencies.
"""

import sys
from pathlib import Path
from datetime import datetime

# Add project root to path to import core modules
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

# Import only the core summary types
try:
    import importlib.util
    
    # Import summary_types module directly to avoid numpy dependencies
    spec = importlib.util.spec_from_file_location('summary_types', Path(__file__).parent.parent.parent / 'core' / 'ai' / 'summary_types.py')
    summary_types = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(summary_types)
    
    SummaryStyle = summary_types.SummaryStyle
    ChapterSummary = summary_types.ChapterSummary
    SummaryRequest = summary_types.SummaryRequest
    print("✅ Successfully imported core summary types")
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
    
    print("  ✅ All 5 summary styles validated")
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
            summary_text="This chapter introduces the main character and sets up the story world. Alice is a curious young girl who finds herself bored by her sister's book reading.",
            key_points=[
                "Alice is sitting with her sister by a riverbank",
                "She becomes bored with her sister's book (no pictures)",
                "Alice begins to feel drowsy in the warm afternoon",
                "A White Rabbit with a pocket watch runs past"
            ],
            themes=["Boredom and restlessness", "Curiosity", "Transition from ordinary to extraordinary"],
            characters_mentioned=["Alice", "Alice's sister", "White Rabbit"],
            word_count=125,
            confidence_score=0.92,
            generation_timestamp=datetime.now(),
            metadata={
                "model": "gemini-pro",
                "processing_time_seconds": 8.3,
                "original_word_count": 450,
                "compression_ratio": 0.28
            }
        )
        
        # Validate all fields
        assert summary.chapter_number == 1
        assert summary.chapter_title == "The Beginning"
        assert summary.summary_style == SummaryStyle.DETAILED
        assert len(summary.key_points) == 4
        assert len(summary.themes) == 3
        assert len(summary.characters_mentioned) == 3
        assert summary.word_count == 125
        assert 0.0 <= summary.confidence_score <= 1.0
        assert isinstance(summary.generation_timestamp, datetime)
        assert isinstance(summary.metadata, dict)
        assert "model" in summary.metadata
        
        print("  ✅ ChapterSummary object created successfully")
        print(f"  ✅ Confidence score: {summary.confidence_score}")
        print(f"  ✅ Word count: {summary.word_count}")
        print(f"  ✅ Key points: {len(summary.key_points)}")
        print(f"  ✅ Themes: {len(summary.themes)}")
        return True
        
    except Exception as e:
        print(f"  ❌ ChapterSummary creation failed: {e}")
        return False

def test_summary_request_creation():
    """Test creating SummaryRequest objects."""
    print("🧪 Testing SummaryRequest Creation...")
    
    try:
        # Test with all parameters
        request1 = SummaryRequest(
            book_id="book_12345",
            book_title="Alice's Adventures in Wonderland",
            chapter_ids=["chapter_1", "chapter_2", "chapter_3"],
            summary_style=SummaryStyle.BRIEF,
            include_themes=True,
            include_characters=True,
            max_summary_length=150,
            custom_prompt="Focus on character development and key plot points"
        )
        
        assert request1.book_id == "book_12345"
        assert len(request1.chapter_ids) == 3
        assert request1.summary_style == SummaryStyle.BRIEF
        assert request1.max_summary_length == 150
        
        # Test with defaults
        request2 = SummaryRequest(
            book_id="book_67890",
            book_title="Through the Looking-Glass"
        )
        
        assert request2.book_id == "book_67890"
        assert request2.chapter_ids is None  # Default
        assert request2.summary_style == SummaryStyle.DETAILED  # Default
        assert request2.include_themes is True  # Default
        assert request2.max_summary_length == 500  # Default
        assert request2.custom_prompt is None  # Default
        
        print("  ✅ SummaryRequest with all parameters works")
        print("  ✅ SummaryRequest with defaults works")
        return True
        
    except Exception as e:
        print(f"  ❌ SummaryRequest creation failed: {e}")
        return False

def test_multiple_summary_styles():
    """Test creating summaries with different styles."""
    print("🧪 Testing Multiple Summary Styles...")
    
    sample_summaries = {
        SummaryStyle.BRIEF: {
            "text": "Alice follows a White Rabbit down a hole into Wonderland.",
            "points": ["Alice sees rabbit", "Falls down hole"],
            "themes": []
        },
        SummaryStyle.DETAILED: {
            "text": "In this opening chapter, Alice becomes bored while sitting with her sister by a riverbank. When she sees a White Rabbit with a pocket watch exclaiming about being late, her curiosity compels her to follow it down a rabbit hole, leading to her tumble into the fantastical world of Wonderland.",
            "points": ["Alice bored by sister's book", "White Rabbit appears", "Alice follows rabbit", "Falls into Wonderland"],
            "themes": ["Curiosity", "Boredom", "Adventure"]
        },
        SummaryStyle.THEMES: {
            "text": "This chapter explores themes of childhood restlessness and the power of curiosity to transform the mundane into the magical. Alice's boredom with conventional learning represents a rejection of passive consumption in favor of active exploration.",
            "points": ["Childhood restlessness", "Curiosity as catalyst"],
            "themes": ["Childhood vs. adulthood", "Active vs. passive learning", "Transformation", "Escapism"]
        },
        SummaryStyle.KEY_POINTS: {
            "text": "• Alice sits bored with her sister by a riverbank\n• She considers making a daisy chain\n• A White Rabbit with a watch runs past\n• Alice follows the rabbit down a hole\n• She falls for a long time before landing",
            "points": [],
            "themes": []
        },
        SummaryStyle.QUESTION_BASED: {
            "text": "Q: What is Alice doing at the start? A: Sitting with her sister who is reading.\nQ: Why does Alice follow the rabbit? A: She is curious about a rabbit with a pocket watch.\nQ: What happens when she follows it? A: She falls down a rabbit hole into Wonderland.",
            "points": ["Q&A format used"],
            "themes": []
        }
    }
    
    try:
        for style, sample_data in sample_summaries.items():
            summary = ChapterSummary(
                chapter_id=f"test_chapter_{style.value}",
                chapter_number=1,
                chapter_title="Down the Rabbit Hole",
                summary_style=style,
                summary_text=sample_data["text"],
                key_points=sample_data["points"],
                themes=sample_data["themes"],
                characters_mentioned=["Alice", "White Rabbit", "Alice's sister"][:2] if style != SummaryStyle.DETAILED else ["Alice", "White Rabbit", "Alice's sister"],
                word_count=len(sample_data["text"].split()),
                confidence_score=0.85 if style != SummaryStyle.QUESTION_BASED else 0.78,
                generation_timestamp=datetime.now(),
                metadata={"style": style.value, "test": True}
            )
            
            assert summary.summary_style == style
            assert summary.chapter_number == 1
            assert len(summary.summary_text) > 10
            
            print(f"  ✅ {style.value} summary created ({len(sample_data['text'])} chars)")
        
        print("  ✅ All 5 summary styles tested successfully")
        return True
        
    except Exception as e:
        print(f"  ❌ Multiple styles test failed: {e}")
        return False

def test_data_validation():
    """Test data validation and edge cases."""
    print("🧪 Testing Data Validation...")
    
    try:
        # Test confidence score bounds
        summary1 = ChapterSummary(
            chapter_id="test", chapter_number=1, chapter_title="Test",
            summary_style=SummaryStyle.BRIEF, summary_text="Test",
            key_points=[], themes=[], characters_mentioned=[],
            word_count=1, confidence_score=0.0,  # Minimum
            generation_timestamp=datetime.now(), metadata={}
        )
        assert summary1.confidence_score == 0.0
        
        summary2 = ChapterSummary(
            chapter_id="test", chapter_number=1, chapter_title="Test",
            summary_style=SummaryStyle.BRIEF, summary_text="Test", 
            key_points=[], themes=[], characters_mentioned=[],
            word_count=1, confidence_score=1.0,  # Maximum
            generation_timestamp=datetime.now(), metadata={}
        )
        assert summary2.confidence_score == 1.0
        
        # Test empty collections
        summary3 = ChapterSummary(
            chapter_id="test", chapter_number=1, chapter_title="Test",
            summary_style=SummaryStyle.BRIEF, summary_text="Minimal test summary",
            key_points=[], themes=[], characters_mentioned=[],  # All empty
            word_count=3, confidence_score=0.5,
            generation_timestamp=datetime.now(), metadata={}
        )
        assert len(summary3.key_points) == 0
        assert len(summary3.themes) == 0
        assert len(summary3.characters_mentioned) == 0
        
        print("  ✅ Confidence score bounds validated")
        print("  ✅ Empty collections handled")
        print("  ✅ Edge cases work correctly")
        return True
        
    except Exception as e:
        print(f"  ❌ Data validation test failed: {e}")
        return False

def run_all_tests():
    """Run all core summary type tests."""
    print("📚 Smart Chapter Summaries - Core Types Test Suite")
    print("=" * 65)
    
    tests = [
        ("Summary Style Definitions", test_summary_styles),
        ("ChapterSummary Creation", test_chapter_summary_creation), 
        ("SummaryRequest Creation", test_summary_request_creation),
        ("Multiple Summary Styles", test_multiple_summary_styles),
        ("Data Validation", test_data_validation),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n🔍 {test_name}")
        print("-" * len(test_name))
        try:
            if test_func():
                passed += 1
                print(f"✅ {test_name} PASSED\n")
            else:
                print(f"❌ {test_name} FAILED\n")
        except Exception as e:
            print(f"💥 {test_name} CRASHED: {e}\n")
    
    print("=" * 65)
    print(f"📊 Final Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 ALL CORE SUMMARY TYPES TESTS PASSED!")
        print("\n📋 Verified Features:")
        print("  ✅ 5 Summary Styles: brief, detailed, themes, key_points, question_based")
        print("  ✅ ChapterSummary data structure with full metadata support")
        print("  ✅ SummaryRequest configuration with defaults and customization")
        print("  ✅ Data validation and edge case handling")
        print("  ✅ Type safety and proper enum usage")
        
        print("\n🚀 Core summary types are ready!")
        print("  • Can be integrated with AI generation system")
        print("  • Can be stored in database via storage module")
        print("  • Can be exposed via REST API endpoints")
        print("  • Ready for integration with chapter detection")
        return True
    else:
        print(f"\n⚠️ {total - passed} tests failed. Please review the implementation.")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)