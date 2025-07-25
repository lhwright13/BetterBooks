import base64
import os
import tempfile

from fastapi import FastAPI
from pydantic import BaseModel
from TTS.api import TTS

MODEL_NAME = os.getenv("TTS_MODEL", "tts_models/en/ljspeech/tacotron2-DDC")
tts = TTS(MODEL_NAME, progress_bar=False, gpu=False)

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}


class SynthesisRequest(BaseModel):
    text: str


@app.post("/synthesize")
def synthesize(req: SynthesisRequest):
    wav = tts.tts(req.text)
    fd, path = tempfile.mkstemp(suffix=".wav")
    tts.save_wav(wav, path)
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode()
    os.close(fd)
    os.remove(path)
    return {"audio": data}

