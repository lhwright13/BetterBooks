# BetterBooks Voice Architecture

## Overview

Demo uses fully local/free components. Production can upgrade to cloud services.

---

## Demo Stack (Free/Local)

| Component | Demo | Production (Future) |
|-----------|------|---------------------|
| LLM | Ollama (tinyllama/llama3.2) | GPT-4o / Claude |
| STT | Local Whisper | Whisper API |
| TTS | Coqui TTS / pyttsx3 | OpenAI TTS / ElevenLabs |
| Voice E2E | Placeholder | GPT-4o Realtime |

---

## Architecture (Demo)

```text
┌──────────────┐                    ┌──────────────────┐
│   Frontend   │  WebSocket/HTTP    │   API Gateway    │
│  (Browser)   │ <================> │   (port 8000)    │
└──────────────┘                    └────────┬─────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
                    ▼                        ▼                        ▼
           ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
           │ Local Whisper│         │    Ollama    │         │  Coqui TTS   │
           │    (STT)     │         │    (LLM)     │         │    (TTS)     │
           └──────────────┘         └──────────────┘         └──────────────┘
```

---

## Component Setup

### 1. Local Whisper (STT)

```bash
# Install
pip install openai-whisper

# Or faster-whisper (recommended)
pip install faster-whisper
```

```python
from faster_whisper import WhisperModel

model = WhisperModel("base", device="cpu")  # or "cuda"
segments, info = model.transcribe("audio.wav")
text = " ".join([segment.text for segment in segments])
```

### 2. Coqui TTS (Text-to-Speech)

```bash
# Install
pip install TTS
```

```python
from TTS.api import TTS

# List available models
# TTS.list_models()

tts = TTS(model_name="tts_models/en/ljspeech/tacotron2-DDC")
tts.tts_to_file(text="Hello world", file_path="output.wav")
```

Alternative (simpler, lower quality):

```bash
pip install pyttsx3
```

```python
import pyttsx3

engine = pyttsx3.init()
engine.say("Hello world")
engine.runAndWait()
```

### 3. Ollama (LLM) - Already Working

```bash
ollama serve
ollama run tinyllama
```

---

## API Endpoints

### Voice Chat (Traditional Pipeline)

```text
POST /voice/transcribe
  Input: audio file (wav/mp3)
  Output: { "text": "transcribed text" }

POST /voice/synthesize
  Input: { "text": "text to speak", "voice": "default" }
  Output: audio file (wav)

POST /voice/chat
  Input: { "audio": base64, "book_id": "...", "chapter": 1, "timestamp": 60 }
  Output: { "text": "response", "audio": base64 }
```

### End-to-End Voice (Placeholder)

```text
WS /voice/realtime
  Status: PLACEHOLDER - Returns "Feature coming soon"
  Future: GPT-4o Realtime API integration
```

---

## Voice Chat Flow (Demo)

```text
1. User clicks "Voice Chat" button
2. Browser records audio (MediaRecorder API)
3. Audio sent to /voice/transcribe (Whisper)
4. Text + book context sent to /ai/chat (Ollama)
5. Response text sent to /voice/synthesize (Coqui TTS)
6. Audio played back to user
```

Total latency (local): ~3-5 seconds
- Whisper transcription: ~1-2s
- LLM response: ~1-2s
- TTS generation: ~1s

---

## Implementation

### New Dependencies

Add to `requirements.txt`:

```text
# Voice - Local Demo
faster-whisper>=0.10.0
TTS>=0.22.0
soundfile>=0.12.0
```

### Voice Service Module

Create `platform/backend/services/api_gateway/voice_service.py`:

```python
"""
Local Voice Service for Demo
- STT: faster-whisper
- TTS: Coqui TTS
"""

import os
import tempfile
import logging
from typing import Optional
import soundfile as sf

logger = logging.getLogger(__name__)

# Lazy loading to avoid startup delay
_whisper_model = None
_tts_model = None


def get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        from faster_whisper import WhisperModel
        _whisper_model = WhisperModel("base", device="cpu", compute_type="int8")
        logger.info("Whisper model loaded")
    return _whisper_model


def get_tts_model():
    global _tts_model
    if _tts_model is None:
        from TTS.api import TTS
        _tts_model = TTS(model_name="tts_models/en/ljspeech/tacotron2-DDC")
        logger.info("TTS model loaded")
    return _tts_model


def transcribe_audio(audio_path: str) -> str:
    """Transcribe audio file to text using Whisper"""
    model = get_whisper_model()
    segments, _ = model.transcribe(audio_path)
    return " ".join([segment.text for segment in segments]).strip()


def synthesize_speech(text: str, output_path: Optional[str] = None) -> str:
    """Convert text to speech using Coqui TTS"""
    if output_path is None:
        output_path = tempfile.mktemp(suffix=".wav")

    model = get_tts_model()
    model.tts_to_file(text=text, file_path=output_path)
    return output_path


def transcribe_audio_bytes(audio_bytes: bytes, format: str = "wav") -> str:
    """Transcribe audio from bytes"""
    with tempfile.NamedTemporaryFile(suffix=f".{format}", delete=False) as f:
        f.write(audio_bytes)
        temp_path = f.name

    try:
        return transcribe_audio(temp_path)
    finally:
        os.unlink(temp_path)


def synthesize_speech_bytes(text: str) -> bytes:
    """Convert text to speech, return bytes"""
    output_path = synthesize_speech(text)
    try:
        with open(output_path, "rb") as f:
            return f.read()
    finally:
        os.unlink(output_path)
```

---

## Frontend Integration

### Recording Audio

```javascript
async function recordAudio(maxDuration = 10000) {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const recorder = new MediaRecorder(stream);
    const chunks = [];

    recorder.ondataavailable = (e) => chunks.push(e.data);
    recorder.start();

    return new Promise((resolve) => {
        setTimeout(() => {
            recorder.stop();
            recorder.onstop = () => {
                const blob = new Blob(chunks, { type: 'audio/wav' });
                resolve(blob);
            };
        }, maxDuration);
    });
}
```

### Voice Chat Button

```javascript
async function voiceChat() {
    // 1. Record
    showStatus("Listening...");
    const audioBlob = await recordAudio(5000);

    // 2. Transcribe
    showStatus("Processing...");
    const formData = new FormData();
    formData.append('audio', audioBlob);
    const transcribeResp = await fetch('/voice/transcribe', {
        method: 'POST',
        body: formData
    });
    const { text } = await transcribeResp.json();

    // 3. Get AI response (reuse existing chat endpoint)
    const chatResp = await fetch('/ai/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            book_id: currentBookId,
            chapter: currentChapter,
            timestamp_seconds: currentTimestamp,
            message: text,
            persona_id: selectedPersona
        })
    });
    const { message: aiResponse } = await chatResp.json();

    // 4. Synthesize and play
    showStatus("Speaking...");
    const audioResp = await fetch('/voice/synthesize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: aiResponse })
    });
    const audioData = await audioResp.blob();
    playAudio(audioData);
}
```

---

## Cost Summary (Demo)

| Component | Cost |
|-----------|------|
| Whisper (local) | Free |
| Coqui TTS (local) | Free |
| Ollama (local) | Free |
| **Total** | **$0** |

---

## Future: Production Upgrade Path

When ready to upgrade:

1. **STT**: Switch from local Whisper to Whisper API
   - Change: API call instead of local model
   - Cost: ~$0.006/minute

2. **TTS**: Switch from Coqui to OpenAI TTS
   - Change: API call instead of local model
   - Cost: ~$0.015/1000 chars

3. **Voice E2E**: Enable GPT-4o Realtime
   - Change: Implement WebSocket proxy
   - Cost: ~$0.30/minute

---

## Deferred (Do Later)

- Email verification
- Payment integration
- Subscription tiers
- GPT-4o Realtime (end-to-end voice)
- Voice activity detection improvements
- Multi-language support
