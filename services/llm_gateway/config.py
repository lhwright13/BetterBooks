"""Configuration loader for the Gemini LLM Gateway."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict


# Look for a global configuration file at the repository root.  Fall back to the
# legacy local file if it doesn't exist.
DEFAULT_ROOT_PATH = Path(__file__).resolve().parents[2] / "llm_config.json"
DEFAULT_LOCAL_PATH = Path(__file__).with_name("config.json")


def load_config(path: str | Path | None = None) -> Dict[str, Any]:
    """Load configuration from a JSON file and environment variables."""
    env_path = os.getenv("GEMINI_CONFIG")
    if path:
        cfg_path = Path(path)
    elif env_path:
        cfg_path = Path(env_path)
    else:
        cfg_path = DEFAULT_ROOT_PATH if DEFAULT_ROOT_PATH.exists() else DEFAULT_LOCAL_PATH

    data: Dict[str, Any] = {}
    if cfg_path.exists():
        with open(cfg_path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    data.setdefault("model", "gemini-2.0-flash")
    data.setdefault("generation_config", {"temperature": 0.7})
    data.setdefault("prompt_options", {})
    data.setdefault("base_preprompt", "")
    env_key = os.getenv("GEMINI_API_KEY")
    if env_key:
        data["api_key"] = env_key
    data.setdefault("api_key", "test-key")
    return data
