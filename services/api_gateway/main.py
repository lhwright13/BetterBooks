import os

import httpx
from fastapi import FastAPI
from pydantic import BaseModel

CONTEXT_URL = os.getenv("CONTEXT_SERVICE_URL", "http://context_service:8000")
LLM_URL = os.getenv("LLM_GATEWAY_URL", "http://llm_gateway:8000")
TTS_URL = os.getenv("TTS_SERVICE_URL", "http://tts_service:8000")

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}


class Prompt(BaseModel):
    prompt: str


class Text(BaseModel):
    text: str


@app.post("/complete")
def complete(prompt: Prompt):
    resp = httpx.post(f"{LLM_URL}/complete", json=prompt.dict())
    return resp.json()


@app.post("/tts")
def tts(text: Text):
    resp = httpx.post(f"{TTS_URL}/synthesize", json=text.dict())
    return resp.json()


@app.post("/context/search")
def search_context(query: dict):
    resp = httpx.post(f"{CONTEXT_URL}/search", json=query)
    return resp.json()

