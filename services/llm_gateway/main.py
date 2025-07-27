"""Tiny wrapper around the OpenAI API used for text generation."""

import os

try:  # pragma: no cover - library may not be installed during tests
    from openai import OpenAI, OpenAIError, RateLimitError
except Exception:  # pragma: no cover - openai is replaced with a stub in tests
    from openai import OpenAI  # type: ignore
    OpenAIError = Exception  # type: ignore
    RateLimitError = Exception  # type: ignore
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
    try:
        resp = client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-3.5-turbo"),
            messages=[{"role": "user", "content": prompt}],
            max_tokens=req.max_tokens,
        )
    except RateLimitError as exc:  # pragma: no cover - requires actual API call
        # If the OpenAI API rejects the request due to usage limits or invalid
        # credentials return a 429 to indicate the upstream service is
        # unavailable. This normally happens in development when the API key is
        # missing or exhausted.
        raise HTTPException(status_code=429, detail=str(exc))
    except OpenAIError as exc:  # pragma: no cover - requires actual API call
        # Catch all other OpenAI related errors and return a generic 502 so the
        # caller knows the request failed.
        raise HTTPException(status_code=502, detail=str(exc))

    return {"text": resp.choices[0].message.content.strip()}

