"""Tiny wrapper around the OpenAI API used for text generation."""

import os

from openai import OpenAI
from fastapi import FastAPI
from pydantic import BaseModel

# Create an OpenAI client using the API key provided in the environment.
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

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

    resp = client.completions.create(
        model="text-davinci-003",
        prompt=req.prompt,
        max_tokens=req.max_tokens,
    )
    return {"text": resp.choices[0].text.strip()}

