import json
import sys
import tempfile
from pathlib import Path
import pytest

PROJECT_ROOT = Path(__file__).parent.parent.parent
API_GATEWAY_PATH = PROJECT_ROOT / "platform" / "backend" / "services" / "api_gateway"
sys.path.insert(0, str(PROJECT_ROOT))
sys.path.insert(0, str(API_GATEWAY_PATH))

from personas.interfaces import PersonaConfig, VoiceConfig
from personas.json_persona_manager import JsonPersonaManager


class TestVoiceConfigDataclass:

    def test_voice_config_defaults(self):
        config = VoiceConfig()

        assert config.provider == "azure"
        assert config.voice_id == "en-US-AriaNeural"
        assert config.style is None
        assert config.rate == 1.0
        assert config.pitch is None

    def test_voice_config_custom_values(self):
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

    def test_persona_config_required_fields(self):
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

    def test_init(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        assert manager.book_files_path == Path(temp_book_files_dir)
        assert manager.config_path == Path(temp_config_dir)
        assert manager._global_cache is None
        assert manager._book_cache == {}


class TestVoiceConfigParsing:

    def test_parse_voice_config_empty(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        config = manager._parse_voice_config({})

        assert config.provider == "azure"
        assert config.voice_id == "en-US-AriaNeural"

    def test_parse_voice_config_new_format(self, temp_book_files_dir, temp_config_dir):
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
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

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

    def test_load_persona_from_file_success(self, temp_book_files_dir, temp_config_dir):
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
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona_path = Path(temp_book_files_dir) / "the-great-gatsby" / "personas" / "Nick Carraway.json"
        persona = manager._load_persona_from_file(persona_path, book_id="test")

        assert persona.id == "nick-carraway"


class TestGlobalPersonaLoading:

    def test_load_global_personas(self, temp_book_files_dir, temp_config_dir):
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
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_global_personas()

        for persona in personas:
            assert persona.type == "guide"
            assert persona.book_id is None

    def test_global_personas_cached(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas1 = manager._load_global_personas()
        personas2 = manager._load_global_personas()

        assert personas1 is personas2
        assert manager._global_cache is not None


class TestBookPersonaLoading:

    def test_load_book_personas(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_book_personas("the-great-gatsby")

        assert len(personas) >= 1
        nick = next((p for p in personas if "nick" in p.name.lower()), None)
        assert nick is not None

    def test_book_personas_have_book_id(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_book_personas("the-great-gatsby")

        for persona in personas:
            assert persona.book_id == "the-great-gatsby"

    def test_book_personas_cached(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas1 = manager._load_book_personas("the-great-gatsby")
        personas2 = manager._load_book_personas("the-great-gatsby")

        assert personas1 is personas2
        assert "the-great-gatsby" in manager._book_cache

    def test_load_personas_empty_folder(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = manager._load_book_personas("nonexistent-book")

        assert personas == []


class TestGetPersona:

    @pytest.mark.asyncio
    async def test_get_persona_from_book(self, temp_book_files_dir, temp_config_dir):
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
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = await manager.get_persona("english-teacher")

        assert persona is not None
        assert persona.name == "English Teacher"

    @pytest.mark.asyncio
    async def test_get_persona_not_found(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = await manager.get_persona("nonexistent-persona")

        assert persona is None

    @pytest.mark.asyncio
    async def test_get_persona_prefers_book_specific(self, temp_book_files_dir, temp_config_dir):
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
        manager._book_cache.clear()

        persona = await manager.get_persona(
            persona_id="english-teacher",
            book_id="the-great-gatsby"
        )

        assert "Gatsby Edition" in persona.name


class TestGetPersonasForBook:

    @pytest.mark.asyncio
    async def test_get_personas_for_book(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = await manager.get_personas_for_book("the-great-gatsby")

        assert len(personas) >= 3
        persona_names = [p.name for p in personas]
        assert "Nick Carraway" in persona_names
        assert "English Teacher" in persona_names

    @pytest.mark.asyncio
    async def test_book_personas_first(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        personas = await manager.get_personas_for_book("the-great-gatsby")

        book_specific = [p for p in personas if p.book_id is not None]
        global_ones = [p for p in personas if p.book_id is None]

        if book_specific and global_ones:
            first_global_idx = personas.index(global_ones[0])
            last_book_idx = personas.index(book_specific[-1])
            assert last_book_idx < first_global_idx

    @pytest.mark.asyncio
    async def test_no_duplicate_names(self, temp_book_files_dir, temp_config_dir):
        book_personas_dir = Path(temp_book_files_dir) / "the-great-gatsby" / "personas"
        duplicate_persona = {
            "id": "english-teacher-gatsby",
            "name": "English Teacher",
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

        english_teachers = [p for p in personas if p.name == "English Teacher"]
        assert len(english_teachers) == 1


class TestGetGlobalPersonas:

    @pytest.mark.asyncio
    async def test_get_global_personas(self, temp_book_files_dir, temp_config_dir):
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

    def test_clear_cache(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        manager._load_global_personas()
        manager._load_book_personas("the-great-gatsby")

        assert manager._global_cache is not None
        assert len(manager._book_cache) > 0

        manager.clear_cache()

        assert manager._global_cache is None
        assert manager._book_cache == {}


class TestSystemPromptGeneration:

    @pytest.mark.asyncio
    async def test_character_persona_has_system_prompt(self, temp_book_files_dir, temp_config_dir):
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
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        persona = await manager.get_persona("english-teacher")

        assert persona is not None
        assert len(persona.system_prompt) > 50
        assert "teacher" in persona.system_prompt.lower() or "student" in persona.system_prompt.lower()


class TestPersonaTypeDetection:

    def test_teacher_type_detected(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

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

    def test_invalid_json_file(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        invalid_path = Path(temp_book_files_dir) / "the-great-gatsby" / "personas" / "invalid.json"
        with open(invalid_path, "w") as f:
            f.write("{ invalid json content")

        persona = manager._load_persona_from_file(invalid_path)

        assert persona is None

    def test_empty_persona_file(self, temp_book_files_dir, temp_config_dir):
        manager = JsonPersonaManager(
            book_files_path=temp_book_files_dir,
            config_path=temp_config_dir
        )

        empty_path = Path(temp_book_files_dir) / "the-great-gatsby" / "personas" / "empty.json"
        with open(empty_path, "w") as f:
            f.write("{}")

        persona = manager._load_persona_from_file(empty_path)

        if persona is not None:
            assert persona.id is not None
            assert persona.name is not None
