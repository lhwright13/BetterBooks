import os

import openai
from fastapi import FastAPI
from pydantic import BaseModel

openai.api_key = os.getenv("OPENAI_API_KEY")

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}


class CompletionRequest(BaseModel):
    prompt: str
    max_tokens: int = 50


@app.post("/complete")
def complete(req: CompletionRequest):
    resp = openai.Completion.create(
        model="text-davinci-003",
        prompt=req.prompt,
        max_tokens=req.max_tokens,
    )
    return {"text": resp.choices[0].text.strip()}

