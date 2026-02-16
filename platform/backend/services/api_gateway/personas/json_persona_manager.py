import json
from pathlib import Path
from typing import Dict, List, Optional
from .interfaces import IPersonaManager, PersonaConfig, VoiceConfig


class JsonPersonaManager(IPersonaManager):

    def __init__(self, book_files_path: str, config_path: str):
        self.book_files_path = Path(book_files_path)
        self.config_path = Path(config_path)
        self._global_cache: Optional[List[PersonaConfig]] = None
        self._book_cache: Dict[str, List[PersonaConfig]] = {}

    def _parse_voice_config(self, voice_data: dict) -> VoiceConfig:
        if not voice_data:
            return VoiceConfig()

        if "voice" in voice_data and "audio_config" in voice_data:
            voice_info = voice_data.get("voice", {})
            audio_config = voice_data.get("audio_config", {})
            return VoiceConfig(
                provider="google",
                voice_id=voice_info.get("name", "en-US-Neural2-C"),
                rate=audio_config.get("speaking_rate", 1.0),
                pitch=str(audio_config.get("pitch", 1.0)) if audio_config.get("pitch") else None
            )

        return VoiceConfig(
            provider=voice_data.get("provider", "azure"),
            voice_id=voice_data.get("voice_id", "en-US-AriaNeural"),
            style=voice_data.get("style"),
            rate=voice_data.get("rate", 1.0),
            pitch=voice_data.get("pitch")
        )

    def _load_persona_from_file(self, filepath: Path, book_id: Optional[str] = None) -> Optional[PersonaConfig]:
        if not filepath.exists():
            return None

        try:
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (json.JSONDecodeError, IOError):
            return None

        persona_id = data.get("id", filepath.stem.lower().replace(" ", "-"))
        name = data.get("name", filepath.stem)

        persona_type = data.get("type", "character")
        if any(x in name.lower() for x in ["teacher", "tutor", "helper", "companion"]):
            persona_type = "guide"

        system_prompt = data.get("system_prompt") or data.get("base_preprompt", "")
        voice_config = self._parse_voice_config(data.get("voice") or data.get("tts_config", {}))

        return PersonaConfig(
            id=persona_id,
            name=name,
            type=persona_type,
            system_prompt=system_prompt,
            temperature=data.get("temperature") or data.get("generation_config", {}).get("temperature", 0.7),
            description=data.get("description", ""),
            avatar=data.get("avatar"),
            voice=voice_config,
            book_id=book_id
        )

    def _load_global_personas(self) -> List[PersonaConfig]:
        if self._global_cache is not None:
            return self._global_cache

        global_file = self.config_path / "personas" / "global.json"
        personas = []

        if global_file.exists():
            try:
                with open(global_file, "r", encoding="utf-8") as f:
                    data = json.load(f)

                for persona_data in data.get("personas", []):
                    personas.append(PersonaConfig(
                        id=persona_data.get("id", "unknown"),
                        name=persona_data.get("name", "Unknown"),
                        type=persona_data.get("type", "guide"),
                        system_prompt=persona_data.get("system_prompt", ""),
                        temperature=persona_data.get("temperature", 0.7),
                        description=persona_data.get("description", ""),
                        avatar=persona_data.get("avatar"),
                        voice=self._parse_voice_config(persona_data.get("voice", {})),
                        book_id=None
                    ))
            except (json.JSONDecodeError, IOError):
                pass

        self._global_cache = personas
        return personas

    def _load_book_personas(self, book_id: str) -> List[PersonaConfig]:
        if book_id in self._book_cache:
            return self._book_cache[book_id]

        personas = []
        personas_dir = self.book_files_path / book_id / "personas"

        if personas_dir.exists() and personas_dir.is_dir():
            for filepath in personas_dir.glob("*.json"):
                persona = self._load_persona_from_file(filepath, book_id)
                if persona:
                    personas.append(persona)

        self._book_cache[book_id] = personas
        return personas

    async def get_persona(
        self,
        persona_id: str,
        book_id: Optional[str] = None
    ) -> Optional[PersonaConfig]:
        if book_id:
            for persona in self._load_book_personas(book_id):
                if persona.id == persona_id:
                    return persona

        for persona in self._load_global_personas():
            if persona.id == persona_id:
                return persona

        return None

    async def get_personas_for_book(self, book_id: str) -> List[PersonaConfig]:
        book_personas = self._load_book_personas(book_id)
        global_personas = self._load_global_personas()

        book_names = {p.name.lower() for p in book_personas}
        filtered_global = [p for p in global_personas if p.name.lower() not in book_names]

        return book_personas + filtered_global

    async def get_global_personas(self) -> List[PersonaConfig]:
        return self._load_global_personas()

    def clear_cache(self):
        self._global_cache = None
        self._book_cache.clear()
