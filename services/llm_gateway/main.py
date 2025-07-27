"""Tiny wrapper around the OpenAI API used for text generation."""

import os

from openai import OpenAI
from fastapi import FastAPI
from pydantic import BaseModel

# Import the prompt modification helper. When the service runs inside Docker the
# `main.py` file is executed directly (``uvicorn main:app``), so the relative
# import fails. Fall back to an absolute import in that scenario to keep local
# tests working.
try:  # pragma: no cover - import tested implicitly
    from .prompt_modifier import modify_prompt
except ImportError:  # pragma: no cover - running as a script
    from prompt_modifier import modify_prompt

# Create an OpenAI client using the API key provided in the environment.  When
# running unit tests the key may not be set so we fall back to a dummy value to
# avoid initialization errors.
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY", "sk-test"))

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
    """Call OpenAI to generate a text completion."""

    prompt = modify_prompt(req.prompt)
    resp = client.chat.completions.create(
        model=os.getenv("OPENAI_MODEL", "gpt-3.5-turbo"),
        messages=[{"role": "user", "content": prompt}],
        max_tokens=req.max_tokens,
    )
    return {"text": resp.choices[0].message.content.strip()}

