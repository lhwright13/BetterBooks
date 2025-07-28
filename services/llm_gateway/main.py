"""Tiny wrapper around the Gemini API used for text generation."""

import os
import types

try:  # pragma: no cover - library may not be installed during tests
    import google.generativeai as genai
    from google.generativeai.types import GenerationConfig, HarmCategory, HarmBlockThreshold
except Exception:  # pragma: no cover - the library may be stubbed in tests
    genai = types.SimpleNamespace(configure=lambda *a, **k: None, GenerativeModel=lambda *a, **k: None)  # type: ignore
    GenerationConfig = dict  # type: ignore
    HarmCategory = types.SimpleNamespace()  # type: ignore
    HarmBlockThreshold = types.SimpleNamespace()  # type: ignore
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

# Directory containing additional LLM configuration JSON files. When the service
# is packaged into a Docker image, the configs are mounted at /app/llm_configs.
# Try the mounted path first, then fall back to repository structure.
_app_configs = Path("/app/llm_configs")
if _app_configs.exists():
    CONFIG_DIR = _app_configs
else:
    _parents = Path(__file__).resolve().parents
    CONFIG_DIR = (_parents[2] if len(_parents) > 2 else _parents[-1]) / "llm_configs"

# Validate API key before configuring
api_key = cfg["api_key"]
if not api_key or api_key == "test-key" or api_key.strip() == "":
    raise ValueError("Valid GEMINI_API_KEY environment variable is required")

genai.configure(api_key=api_key)
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
    max_tokens: int = 4000
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
        # Validate API key for local config
        local_api_key = cfg_local["api_key"]
        if not local_api_key or local_api_key == "test-key" or local_api_key.strip() == "":
            raise ValueError("Valid API key is required")
        
        genai.configure(api_key=local_api_key)
        model_local = genai.GenerativeModel(cfg_local["model"])
        gen_config_defaults_local = cfg_local.get("generation_config", {})
        config = GenerationConfig(
            **{
                **gen_config_defaults_local,
                "max_output_tokens": req.max_tokens,
            }
        )
        print(f"Final prompt: {prompt}")
        
        # Safety settings to prevent truncation
        safety_settings = {
            HarmCategory.HARM_CATEGORY_HATE_SPEECH: HarmBlockThreshold.BLOCK_NONE,
            HarmCategory.HARM_CATEGORY_HARASSMENT: HarmBlockThreshold.BLOCK_NONE,
            HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: HarmBlockThreshold.BLOCK_NONE,
            HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: HarmBlockThreshold.BLOCK_NONE,
        }
        
        resp = model_local.generate_content(
            prompt,
            generation_config=config,
            safety_settings=safety_settings,
        )
    except Exception as exc:  # pragma: no cover - requires actual API call
        raise HTTPException(status_code=502, detail=str(exc))

    # Validate response has text attribute
    if not hasattr(resp, 'text') or resp.text is None:
        raise HTTPException(status_code=502, detail="Invalid response from language model")
    
    return {"text": resp.text.strip()}


@app.get("/configs")
def list_configs() -> dict:
    """Return available configuration names found in ``llm_configs``."""

    configs = []
    if CONFIG_DIR.exists():
        configs = [p.stem for p in CONFIG_DIR.glob("*.json")]
    return {"configs": configs}

