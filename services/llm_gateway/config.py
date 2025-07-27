"""Configuration loader for the Gemini LLM Gateway."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict


DEFAULT_PATH = Path(__file__).with_name("config.json")


def load_config(path: str | Path | None = None) -> Dict[str, Any]:
    """Load configuration from a JSON file and environment variables."""
    cfg_path = Path(path or os.getenv("GEMINI_CONFIG", DEFAULT_PATH))
    data: Dict[str, Any] = {}
    if cfg_path.exists():
        with open(cfg_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    data.setdefault("model", "gemini-pro")
    data.setdefault("generation_config", {"temperature": 0.7})
    env_key = os.getenv("GEMINI_API_KEY")
    if env_key:
        data["api_key"] = env_key
    data.setdefault("api_key", "test-key")
    return data
