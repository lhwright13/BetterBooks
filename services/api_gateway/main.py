"""Simple API Gateway used by the mobile application.

The gateway forwards requests to the underlying microservices so the client
only needs to communicate with one endpoint. Each function below performs a
lightweight HTTP request to another service and returns the response verbatim.
"""

import os

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Base URLs for the other services. These can be overridden via environment
# variables when running inside Docker or a deployment environment.
CONTEXT_URL = os.getenv("CONTEXT_SERVICE_URL", "http://context_service:8000")
LLM_URL = os.getenv("LLM_GATEWAY_URL", "http://llm_gateway:8000")
TTS_URL = os.getenv("TTS_SERVICE_URL", "http://tts_service:8000")

# Main FastAPI application used by the unit tests and docker-compose setup
app = FastAPI()

# Allow requests from the web demo running on a different port. Without CORS
# the browser would block calls from the 8080 UI to the gateway on 8000.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health() -> dict:
    """Simple liveness probe used by tests and Kubernetes."""
    return {"status": "ok"}


class Prompt(BaseModel):
    """Request body for the `/complete` endpoint."""

    prompt: str
    config: str | None = None


class Text(BaseModel):
    """Request body for the `/tts` endpoint."""

    text: str


@app.post("/complete")
def complete(prompt: Prompt) -> dict:
    """Proxy text completion requests to the LLM Gateway."""

    resp = httpx.post(f"{LLM_URL}/complete", json=prompt.dict(exclude_none=True))
    try:
        resp.raise_for_status()
    except httpx.HTTPStatusError:
        # Bubble up the error from the LLM Gateway so the client receives a
        # meaningful status code instead of a generic 500 from this service.
        detail = resp.json().get("detail", resp.text)
        raise HTTPException(status_code=resp.status_code, detail=detail)

    return resp.json()


@app.post("/tts")
def tts(text: Text) -> dict:
    """Proxy text-to-speech synthesis requests to the TTS Service."""

    resp = httpx.post(f"{TTS_URL}/synthesize", json=text.dict())
    return resp.json()


@app.get("/configs")
def list_configs() -> dict:
    """Return available LLM configuration names."""

    resp = httpx.get(f"{LLM_URL}/configs")
    return resp.json()


@app.post("/context/search")
def search_context(query: dict) -> dict:
    """Forward vector similarity searches to the Context Service."""

    resp = httpx.post(f"{CONTEXT_URL}/search", json=query)
    return resp.json()

