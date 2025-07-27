"""Tiny wrapper around the Gemini API used for text generation."""

import os
import types

try:  # pragma: no cover - library may not be installed during tests
    import google.generativeai as genai
    from google.generativeai.types import GenerationConfig
except Exception:  # pragma: no cover - the library may be stubbed in tests
    genai = types.SimpleNamespace(configure=lambda *a, **k: None, GenerativeModel=lambda *a, **k: None)  # type: ignore
    GenerationConfig = dict  # type: ignore
from pathlib import Path
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Import the prompt modification helper. When the service runs inside Docker the
# ``main.py`` file is executed directly (``uvicorn main:app``). In that case the
# module is executed as a script and relative imports fail. Fall back to
# absolute imports so local tests keep working.
try:  # pragma: no cover - import tested implicitly
    from .prompt_modifier import modify_prompt
except ImportError:  # pragma: no cover - running as a script
    from prompt_modifier import modify_prompt

try:  # pragma: no cover - import tested implicitly
    from .config import load_config
except ImportError:  # pragma: no cover - running as a script
    from config import load_config

cfg = load_config()
prompt_options = cfg.get("prompt_options", {})
base_preprompt = cfg.get("base_preprompt", "")

# Directory containing additional LLM configuration JSON files
CONFIG_DIR = Path(__file__).resolve().parents[2] / "llm_configs"

genai.configure(api_key=cfg["api_key"])
model = genai.GenerativeModel(cfg["model"])
gen_config_defaults = cfg.get("generation_config", {})

# FastAPI application instance
app = FastAPI()

@app.get("/health")
def health() -> dict:
    """Endpoint used to confirm the service is running."""
    return {"status": "ok"}


class CompletionRequest(BaseModel):
    """Schema for completion requests."""

    prompt: str
    max_tokens: int = 50
    config: str | None = None


@app.post("/complete")
def complete(req: CompletionRequest) -> dict:
    """Call Gemini to generate a text completion."""

    # Load configuration based on the optional `config` parameter. Defaults
    # to the main configuration loaded at startup.
    cfg_local = cfg
    if req.config:
        cfg_path = CONFIG_DIR / f"{req.config}.json"
        if not cfg_path.exists():
            raise HTTPException(status_code=400, detail="Unknown config")
        cfg_local = load_config(cfg_path)

    local_prompt_options = cfg_local.get("prompt_options", {})
    local_base_preprompt = cfg_local.get("base_preprompt", "")

    prompt = modify_prompt(req.prompt, local_prompt_options)
    if local_base_preprompt:
        prompt = f"{local_base_preprompt}\n\n{prompt}"
    try:
        genai.configure(api_key=cfg_local["api_key"])
        model_local = genai.GenerativeModel(cfg_local["model"])
        gen_config_defaults_local = cfg_local.get("generation_config", {})
        config = GenerationConfig(
            **{
                **gen_config_defaults_local,
                "max_output_tokens": req.max_tokens,
            }
        )
        resp = model_local.generate_content(
            prompt,
            generation_config=config,
        )
    except Exception as exc:  # pragma: no cover - requires actual API call
        raise HTTPException(status_code=502, detail=str(exc))

    return {"text": resp.text.strip()}


@app.get("/configs")
def list_configs() -> dict:
    """Return available configuration names found in ``llm_configs``."""

    configs = []
    if CONFIG_DIR.exists():
        configs = [p.stem for p in CONFIG_DIR.glob("*.json")]
    return {"configs": configs}

