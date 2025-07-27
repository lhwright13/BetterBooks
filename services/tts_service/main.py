"""Service providing text-to-speech synthesis using the Coqui TTS library."""

import base64
import os
import tempfile

from fastapi import FastAPI
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

    # Generate the waveform in memory
    wav = tts.tts(req.text)

    # Save the waveform to a temporary file so it can be base64 encoded
    fd, path = tempfile.mkstemp(suffix=".wav")
    tts.save_wav(wav, path)

    # Read the file back into memory and encode as base64 for transmission
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode()

    # Clean up the temporary file
    os.close(fd)
    os.remove(path)

    return {"audio": data}

