"""Simple Azure Speech-enabled transcription service."""

import os
import logging
from typing import Dict, Any, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Transcription Service",
    description="Azure Speech Service powered audio transcription",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Check Azure configuration
AZURE_SPEECH_KEY = os.getenv("AZURE_SPEECH_KEY")
AZURE_SPEECH_REGION = os.getenv("AZURE_SPEECH_REGION", "eastus")
AZURE_CONFIGURED = bool(AZURE_SPEECH_KEY)

class TranscriptionResponse(BaseModel):
    text: str = Field(..., description="Transcribed text")
    language: str = Field(..., description="Language used")
    service: str = Field(..., description="Service used for transcription")
    duration_ms: Optional[int] = Field(None, description="Processing duration")

@app.get("/")
async def root():
    return {
        "service": "transcription",
        "status": "running",
        "azure_configured": AZURE_CONFIGURED,
        "azure_region": AZURE_SPEECH_REGION if AZURE_CONFIGURED else None,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "azure_speech": AZURE_CONFIGURED,
        "azure_region": AZURE_SPEECH_REGION if AZURE_CONFIGURED else None,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/config")
async def get_config():
    return {
        "azure_configured": AZURE_CONFIGURED,
        "azure_region": AZURE_SPEECH_REGION if AZURE_CONFIGURED else None,
        "environment": {
            "AZURE_SPEECH_KEY": "configured" if AZURE_SPEECH_KEY else "not set",
            "AZURE_SPEECH_REGION": AZURE_SPEECH_REGION,
        }
    }

@app.post("/transcribe/test", response_model=TranscriptionResponse)
async def test_transcription():
    """Test endpoint that simulates Azure transcription."""
    if not AZURE_CONFIGURED:
        raise HTTPException(
            status_code=503,
            detail="Azure Speech Service not configured. Please set AZURE_SPEECH_KEY."
        )
    
    return TranscriptionResponse(
        text="This is a test transcription using Azure Speech Service.",
        language="en-US",
        service="azure",
        duration_ms=150
    )

@app.get("/supported-languages")
async def get_supported_languages():
    """Get list of supported languages."""
    if not AZURE_CONFIGURED:
        raise HTTPException(
            status_code=503,
            detail="Azure Speech Service not configured"
        )
    
    return {
        "supported_languages": [
            "en-US", "en-GB", "es-ES", "fr-FR", "de-DE", "it-IT",
            "ja-JP", "ko-KR", "zh-CN", "pt-BR", "ru-RU", "ar-SA"
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")