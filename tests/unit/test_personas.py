"""
Unit Tests for Persona Management

Tests for:
- /Users/lhwri/BetterBooks/platform/backend/services/api_gateway/personas/json_persona_manager.py
- /Users/lhwri/BetterBooks/platform/backend/services/api_gateway/personas/interfaces.py

Covers:
- Persona loading from JSON files
- Persona filtering by book
- System prompt generation
- Voice configuration parsing
- Global vs book-specific personas
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
from personas.interfaces import (
    IPersonaManager,
    PersonaConfig,
    VoiceConfig
)
from personas.json_persona_manager import (
    JsonPersonaManager
)


class TestVoiceConfigDataclass:
    """Tests for the VoiceConfig dataclass."""

    def test_voice_config_defaults(self):
        """VoiceConfig should have sensible defaults."""
        config = VoiceConfig()

        assert config.provider == "azure"
        assert config.voice_id == "en-US-AriaNeural"
        assert config.style is None
        assert config.rate == 1.0
        assert config.pitch is None

    def test_voice_config_custom_values(self):
        """VoiceConfig should accept custom values."""
        config = VoiceConfig(
            provider="elevenlabs",
            voice_id="custom-voice-123",
            style="friendly",
            rate=0.9,
            pitch="+5%"
        )

        assert config.provider == "elevenlabs"
        assert config.voice_id == "custom-voice-123"
        assert config.style == "friendly"
        assert config.rate == 0.9
        assert config.pitch == "+5%"


class TestPersonaConfigDataclass:
    """Tests for the PersonaConfig dataclass."""

    def test_persona_config_required_fields(self):
        """PersonaConfig should require id, name, type, system_prompt."""
        config = PersonaConfig(
            id="test-persona",
            name="Test Persona",
            type="guide",
            system_prompt="You are a helpful assistant."
        )

        assert config.id == "test-persona"
        assert config.name == "Test Persona"
        assert config.type == "guide"
        assert config.system_prompt == "You are a helpful assistant."

    def test_persona_config_defaults(self):
        """PersonaConfig should have correct defaults."""
        config = PersonaConfig(
            id="test",
            name="Test",
            type="character",
            system_prompt="Prompt"
        )

        assert config.temperature == 0.7
        assert config.description == ""
        assert config.avatar is None
        assert config.book_id is None
        assert isinstance(config.voice, VoiceConfig)

    def test_persona_config_with_voice(self):
        """PersonaConfig should accept custom VoiceConfig."""
        voice = VoiceConfig(provider="openai", voice_id="alloy")
        config = PersonaConfig(
            id="test",
            name="Test",
            type="guide",
            system_prompt="Prompt",
            voice=voice
        )

        assert config.voice.provider == "openai"
        assert config.voice.voice_id == "alloy"


class TestJsonPersonaManagerInit:
    """Tests for JsonPersonaManager initialization."""

    def test_init(self, temp_book_files_dir, temp_config_dir):
        """Manager should initialize with paths."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        assert manager.book_files_path == Path(temp_book_files_dir)
        assert manager.config_path == Path(temp_config_dir)
        assert manager._global_cache is None
        assert manager._book_cache == {}


class TestVoiceConfigParsing:
    """Tests for voice configuration parsing."""

    def test_parse_voice_config_empty(self, temp_book_files_dir, temp_config_dir):
        """Should return defaults for empty voice config."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        config = manager._parse_voice_config({})

        assert config.provider == "azure"
        assert config.voice_id == "en-US-AriaNeural"

    def test_parse_voice_config_new_format(self, temp_book_files_dir, temp_config_dir):
        """Should parse new format voice config."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        voice_data = {
            "provider": "elevenlabs",
            "voice_id": "voice-123",
            "style": "dramatic",
            "rate": 1.2,
            "pitch": "+10%"
        }
        config = manager._parse_voice_config(voice_data)

        assert config.provider == "elevenlabs"
        assert config.voice_id == "voice-123"
        assert config.style == "dramatic"
        assert config.rate == 1.2
        assert config.pitch == "+10%"

    def test_parse_voice_config_old_format(self, temp_book_files_dir, temp_config_dir):
        """Should parse old Google TTS format."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        # Old format from existing persona files
        voice_data = {
            "voice": {
                "language_code": "en-US",
                "name": "en-US-Neural2-J"
            },
            "audio_config": {
                "speaking_rate": 1.2,
                "pitch": -2.0
            }
        }
        config = manager._parse_voice_config(voice_data)

        assert config.provider == "google"
        assert config.voice_id == "en-US-Neural2-J"
        assert config.rate == 1.2


class TestPersonaLoadingFromFile:
    """Tests for loading individual persona files."""

    def test_load_persona_from_file_success(self, temp_book_files_dir, temp_config_dir):
        """Should load persona from JSON file."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona_path = Path(temp_book_files_dir) / "the-great-gatsby" / "personas" / "Nick Carraway.json"
        persona = manager._load_persona_from_file(persona_path, book_id="the-great-gatsby")

        assert persona is not None
        assert persona.name == "Nick Carraway"
        assert "narrator" in persona.system_prompt.lower()
        assert persona.book_id == "the-great-gatsby"

    def test_load_persona_from_file_missing(self, temp_book_files_dir, temp_config_dir):
        """Should return None for missing file."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = manager._load_persona_from_file(
            Path("/nonexistent/path.json"),
            book_id="test"
        )

        assert persona is None

    def test_load_persona_infers_id_from_filename(self, temp_book_files_dir, temp_config_dir):
        """Should generate ID from filename if not in JSON."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona_path = Path(temp_book_files_dir) / "the-great-gatsby" / "personas" / "Nick Carraway.json"
        persona = manager._load_persona_from_file(persona_path, book_id="test")

        # ID should be derived from filename
        assert persona.id == "nick-carraway"


class TestGlobalPersonaLoading:
    """Tests for loading global personas."""

    def test_load_global_personas(self, temp_book_files_dir, temp_config_dir):
        """Should load all global personas from config."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_global_personas()

        assert len(personas) == 2
        persona_ids = [p.id for p in personas]
        assert "english-teacher" in persona_ids
        assert "reading-companion" in persona_ids

    def test_global_personas_have_correct_type(self, temp_book_files_dir, temp_config_dir):
        """Global personas should have type 'guide'."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_global_personas()

        for persona in personas:
            assert persona.type == "guide"
            assert persona.book_id is None  # Global personas have no book_id

    def test_global_personas_cached(self, temp_book_files_dir, temp_config_dir):
        """Global personas should be cached after first load."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        # First load
        personas1 = manager._load_global_personas()
        # Second load should use cache
        personas2 = manager._load_global_personas()

        assert personas1 is personas2
        assert manager._global_cache is not None


class TestBookPersonaLoading:
    """Tests for loading book-specific personas."""

    def test_load_book_personas(self, temp_book_files_dir, temp_config_dir):
        """Should load personas from book's personas folder."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_book_personas("the-great-gatsby")

        assert len(personas) >= 1
        nick = next((p for p in personas if "nick" in p.name.lower()), None)
        assert nick is not None

    def test_book_personas_have_book_id(self, temp_book_files_dir, temp_config_dir):
        """Book-specific personas should have book_id set."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_book_personas("the-great-gatsby")

        for persona in personas:
            assert persona.book_id == "the-great-gatsby"

    def test_book_personas_cached(self, temp_book_files_dir, temp_config_dir):
        """Book personas should be cached."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        # First load
        personas1 = manager._load_book_personas("the-great-gatsby")
        # Second load should use cache
        personas2 = manager._load_book_personas("the-great-gatsby")

        assert personas1 is personas2
        assert "the-great-gatsby" in manager._book_cache

    def test_load_personas_empty_folder(self, temp_book_files_dir, temp_config_dir):
        """Should return empty list for book without personas folder."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_book_personas("nonexistent-book")

        assert personas == []


class TestGetPersona:
    """Tests for getting specific persona by ID."""

    @pytest.mark.asyncio
    async def test_get_persona_from_book(self, temp_book_files_dir, temp_config_dir):
        """Should find book-specific persona by ID."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = await manager.get_persona(
            persona_id="nick-carraway",
            book_id="the-great-gatsby"
        )

        assert persona is not None
        assert persona.name == "Nick Carraway"

    @pytest.mark.asyncio
    async def test_get_persona_global(self, temp_book_files_dir, temp_config_dir):
        """Should find global persona by ID."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = await manager.get_persona("english-teacher")

        assert persona is not None
        assert persona.name == "English Teacher"

    @pytest.mark.asyncio
    async def test_get_persona_not_found(self, temp_book_files_dir, temp_config_dir):
        """Should return None for unknown persona ID."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = await manager.get_persona("nonexistent-persona")

        assert persona is None

    @pytest.mark.asyncio
    async def test_get_persona_prefers_book_specific(self, temp_book_files_dir, temp_config_dir):
        """Should prefer book-specific persona over global with same ID."""
        # Create a book-specific persona with same ID as global
        book_personas_dir = Path(temp_book_files_dir) / "the-great-gatsby" / "personas"
        duplicate_persona = {
            "id": "english-teacher",
            "name": "English Teacher (Gatsby Edition)",
            "type": "guide",
            "system_prompt": "Book-specific version of English Teacher."
        }
        with open(book_personas_dir / "English Teacher Gatsby.json", "w") as f:
            json.dump(duplicate_persona, f)

        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )
        manager._book_cache.clear()  # Clear cache to reload

        persona = await manager.get_persona(
            persona_id="english-teacher",
            book_id="the-great-gatsby"
        )

        # Should get the book-specific version
        assert "Gatsby Edition" in persona.name


class TestGetPersonasForBook:
    """Tests for getting all personas for a specific book."""

    @pytest.mark.asyncio
    async def test_get_personas_for_book(self, temp_book_files_dir, temp_config_dir):
        """Should return both book-specific and global personas."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = await manager.get_personas_for_book("the-great-gatsby")

        # Should have book-specific (Nick) plus global personas
        assert len(personas) >= 3
        persona_names = [p.name for p in personas]
        assert "Nick Carraway" in persona_names
        assert "English Teacher" in persona_names

    @pytest.mark.asyncio
    async def test_book_personas_first(self, temp_book_files_dir, temp_config_dir):
        """Book-specific personas should come before global ones."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = await manager.get_personas_for_book("the-great-gatsby")

        # Find indices
        book_specific = [p for p in personas if p.book_id is not None]
        global_ones = [p for p in personas if p.book_id is None]

        # Book-specific should come first
        if book_specific and global_ones:
            first_global_idx = personas.index(global_ones[0])
            last_book_idx = personas.index(book_specific[-1])
            assert last_book_idx < first_global_idx

    @pytest.mark.asyncio
    async def test_no_duplicate_names(self, temp_book_files_dir, temp_config_dir):
        """Should filter out global personas that duplicate book-specific names."""
        # Create a book persona with same name as global
        book_personas_dir = Path(temp_book_files_dir) / "the-great-gatsby" / "personas"
        duplicate_persona = {
            "id": "english-teacher-gatsby",
            "name": "English Teacher",  # Same name as global
            "type": "guide",
            "system_prompt": "Gatsby-specific version."
        }
        with open(book_personas_dir / "English Teacher.json", "w") as f:
            json.dump(duplicate_persona, f)

        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )
        manager._book_cache.clear()

        personas = await manager.get_personas_for_book("the-great-gatsby")

        # Count "English Teacher" names
        english_teachers = [p for p in personas if p.name == "English Teacher"]
        assert len(english_teachers) == 1  # Only one, the book-specific one


class TestGetGlobalPersonas:
    """Tests for getting all global personas."""

    @pytest.mark.asyncio
    async def test_get_global_personas(self, temp_book_files_dir, temp_config_dir):
        """Should return all global personas."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = await manager.get_global_personas()

        assert len(personas) == 2
        for persona in personas:
            assert persona.book_id is None
            assert persona.type == "guide"


class TestCacheClearing:
    """Tests for cache management."""

    def test_clear_cache(self, temp_book_files_dir, temp_config_dir):
        """Should clear all caches."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        # Populate caches
        manager._load_global_personas()
        manager._load_book_personas("the-great-gatsby")

        assert manager._global_cache is not None
        assert len(manager._book_cache) > 0

        # Clear
        manager.clear_cache()

        assert manager._global_cache is None
        assert manager._book_cache == {}


class TestSystemPromptGeneration:
    """Tests for system prompt content."""

    @pytest.mark.asyncio
    async def test_character_persona_has_system_prompt(self, temp_book_files_dir, temp_config_dir):
        """Character personas should have detailed system prompts."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = await manager.get_persona("nick-carraway", book_id="the-great-gatsby")

        assert persona is not None
        assert len(persona.system_prompt) > 50
        assert "narrator" in persona.system_prompt.lower() or "nick" in persona.system_prompt.lower()

    @pytest.mark.asyncio
    async def test_guide_persona_has_system_prompt(self, temp_book_files_dir, temp_config_dir):
        """Guide personas should have instructional system prompts."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = await manager.get_persona("english-teacher")

        assert persona is not None
        assert len(persona.system_prompt) > 50
        assert "teacher" in persona.system_prompt.lower() or "student" in persona.system_prompt.lower()


class TestPersonaTypeDetection:
    """Tests for automatic persona type detection."""

    def test_teacher_type_detected(self, temp_book_files_dir, temp_config_dir):
        """Personas with 'teacher' in name should be detected as guide type."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        # Create a persona with 'teacher' in name but no explicit type
        test_persona_data = {
            "name": "Math Teacher",
            "base_preprompt": "You teach math."
        }

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(test_persona_data, f)
            temp_path = Path(f.name)

        try:
            persona = manager._load_persona_from_file(temp_path)
            assert persona.type == "guide"
        finally:
            temp_path.unlink()

    def test_character_type_default(self, temp_book_files_dir, temp_config_dir):
        """Personas without guide keywords should default to character type."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        test_persona_data = {
            "name": "John Smith",
            "base_preprompt": "You are John Smith."
        }

        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(test_persona_data, f)
            temp_path = Path(f.name)

        try:
            persona = manager._load_persona_from_file(temp_path)
            assert persona.type == "character"
        finally:
            temp_path.unlink()


class TestEdgeCases:
    """Tests for edge cases and error handling."""

    def test_invalid_json_file(self, temp_book_files_dir, temp_config_dir):
        """Should handle invalid JSON gracefully."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        # Create invalid JSON file
        invalid_path = Path(temp_book_files_dir) / "the-great-gatsby" / "personas" / "invalid.json"
        with open(invalid_path, "w") as f:
            f.write("{ invalid json content")

        persona = manager._load_persona_from_file(invalid_path)

        assert persona is None

    def test_empty_persona_file(self, temp_book_files_dir, temp_config_dir):
        """Should handle empty persona files."""
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        # Create empty JSON file
        empty_path = Path(temp_book_files_dir) / "the-great-gatsby" / "personas" / "empty.json"
        with open(empty_path, "w") as f:
            f.write("{}")

        persona = manager._load_persona_from_file(empty_path)

        # Should create persona with defaults
        if persona is not None:
            assert persona.id is not None
            assert persona.name is not None
