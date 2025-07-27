"""Tiny wrapper around the Gemini API used for text generation."""

import os
import types

try:  # pragma: no cover - library may not be installed during tests
    import google.generativeai as genai
    from google.generativeai.types import GenerationConfig
except Exception:  # pragma: no cover - the library may be stubbed in tests
    genai = types.SimpleNamespace(configure=lambda *a, **k: None, GenerativeModel=lambda *a, **k: None)  # type: ignore
    GenerationConfig = dict  # type: ignore
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Import the prompt modification helper. When the service runs inside Docker the
# `main.py` file is executed directly (``uvicorn main:app``), so the relative
# import fails. Fall back to an absolute import in that scenario to keep local
# tests working.
try:  # pragma: no cover - import tested implicitly
    from .prompt_modifier import modify_prompt
except ImportError:  # pragma: no cover - running as a script
    from prompt_modifier import modify_prompt

from .config import load_config

cfg = load_config()

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


@app.post("/complete")
def complete(req: CompletionRequest) -> dict:
    """Call Gemini to generate a text completion."""

    prompt = modify_prompt(req.prompt)
    try:
        config = GenerationConfig(
            **{
                **gen_config_defaults,
                "max_output_tokens": req.max_tokens,
            }
        )
        resp = model.generate_content(
            prompt,
            generation_config=config,
        )
    except Exception as exc:  # pragma: no cover - requires actual API call
        raise HTTPException(status_code=502, detail=str(exc))

    return {"text": resp.text.strip()}

