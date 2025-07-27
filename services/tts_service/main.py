"""Service providing text-to-speech synthesis using the Coqui TTS library."""

import base64
import os
import tempfile

from fastapi import FastAPI, HTTPException
import logging
from pydantic import BaseModel
from TTS.api import TTS

# Name of the TTS model to load. The default is a small English model that ships
# with the library.
MODEL_NAME = os.getenv("TTS_MODEL", "tts_models/en/ljspeech/tacotron2-DDC")

# Initialize the TTS engine at startup to avoid repeated loads
tts = TTS(MODEL_NAME, progress_bar=False, gpu=False)

# FastAPI application instance
app = FastAPI()

@app.get("/health")
def health() -> dict:
    """Endpoint used for liveness checks."""
    return {"status": "ok"}


class SynthesisRequest(BaseModel):
    """Request body for speech synthesis."""

    text: str


@app.post("/synthesize")
def synthesize(req: SynthesisRequest) -> dict:
    """Generate speech audio from the supplied text."""
    # Validate input text. Tacotron2 fails on empty or extremely short inputs.
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="Text is empty.")

    logging.info("Synthesizing text: %s", req.text)

    # Create a temporary file path for the synthesized audio
    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)  # Close the descriptor so the library can write to it

    # Let the TTS library synthesize and write the audio directly to file
    try:
        tts.tts_to_file(req.text, file_path=path)
    except RuntimeError as err:
        os.remove(path)
        raise HTTPException(status_code=500, detail=str(err)) from err

    # Read the file back into memory and encode as base64 for transmission
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode()

    # Clean up the temporary file
    os.remove(path)

    return {"audio": data}

