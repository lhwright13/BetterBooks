"""Google Cloud Text-to-Speech service with configurable voice parameters."""

import base64
import os
import sys
import json
from pathlib import Path
from typing import Optional, Dict, Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google.cloud import texttospeech
from google.oauth2 import service_account

from core.infrastructure.metrics import setup_metrics
from core.infrastructure.health_checks import HealthCheck, create_health_endpoint

# Initialize Google TTS client
def create_tts_client():
    """Create Google TTS client using API key authentication."""
    # Use the same API key as Gemini
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY environment variable is required")
    
    # For Google Cloud TTS, we'll use the REST API with the API key
    # This is simpler than service account authentication
    return api_key

api_key = create_tts_client()

# FastAPI application
app = FastAPI(
    title="EchoWright TTS Service",
    description="Text-to-speech synthesis service",
    version="1.0.0"
)

# Set up metrics
metrics_collector = setup_metrics(app, "tts_service")

# Set up health checks
health_check = HealthCheck("tts_service", "1.0.0")
create_health_endpoint(app, health_check)

# Default TTS configuration
DEFAULT_TTS_CONFIG = {
    "voice": {
        "language_code": "en-US",
        "name": "en-US-Neural2-F",  # High quality neural female voice
        "ssml_gender": "FEMALE"
    },
    "audio_config": {
        "audio_encoding": "MP3",
        "speaking_rate": 1.0,
        "pitch": 0.0,
        "volume_gain_db": 0.0,
        "sample_rate_hertz": 24000,
        "effects_profile_id": ["headphone-class-device"]
    }
}

class TTSRequest(BaseModel):
    """Request schema for text-to-speech synthesis."""
    text: str
    config: Optional[str] = None  # Persona config name


class TTSResponse(BaseModel):
    """Response schema for text-to-speech synthesis."""
    audio: str  # Base64 encoded audio
    voice_used: str
    config_used: str


def load_tts_config(config_name: Optional[str] = None) -> Dict[str, Any]:
    """Load TTS configuration from persona config file."""
    if not config_name:
        return DEFAULT_TTS_CONFIG
    
    # Try to load from llm_configs directory (mounted in Docker)
    config_paths = [
        Path("/app/llm_configs") / f"{config_name}.json",
        Path(__file__).parent.parent.parent / "llm_configs" / f"{config_name}.json"
    ]
    
    for config_path in config_paths:
        if config_path.exists():
            try:
                with open(config_path, 'r') as f:
                    config_data = json.load(f)
                    # Return TTS config if it exists, otherwise use default
                    return config_data.get('tts_config', DEFAULT_TTS_CONFIG)
            except Exception as e:
                print(f"Error loading config {config_name}: {e}")
                break
    
    return DEFAULT_TTS_CONFIG


async def synthesize_with_google_tts(text: str, tts_config: Dict[str, Any]) -> bytes:
    """Synthesize speech using Google Cloud TTS REST API."""
    import httpx
    
    # Prepare request payload
    request_payload = {
        "input": {"text": text},
        "voice": tts_config["voice"],
        "audioConfig": tts_config["audio_config"]
    }
    
    # Make request to Google TTS REST API
    url = f"https://texttospeech.googleapis.com/v1/text:synthesize?key={api_key}"
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            url,
            json=request_payload,
            headers={"Content-Type": "application/json"},
            timeout=30.0
        )
        
        if response.status_code != 200:
            error_details = response.text
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Google TTS API error: {error_details}"
            )
        
        result = response.json()
        audio_content = base64.b64decode(result["audioContent"])
        return audio_content


@app.get("/health")
def health():
    """Health check endpoint."""
    return {"status": "ok", "service": "google-tts"}


@app.post("/synthesize", response_model=TTSResponse)
async def synthesize_speech(request: TTSRequest):
    """
    Synthesize speech from text using Google Cloud TTS with configurable parameters.
    
    The voice configuration is loaded from the persona's JSON file in llm_configs.
    """
    
    # Validate API key
    if not api_key or api_key == "test-key":
        raise HTTPException(
            status_code=500, 
            detail="GEMINI_API_KEY not configured. Please set GEMINI_API_KEY environment variable."
        )
    
    # Validate text length (Google TTS supports up to 5000 characters)
    if len(request.text) > 5000:
        raise HTTPException(
            status_code=400,
            detail="Text too long. Google TTS supports maximum 5000 characters per request."
        )
    
    try:
        # Load TTS configuration for the specified persona
        tts_config = load_tts_config(request.config)
        
        # Synthesize speech
        audio_content = await synthesize_with_google_tts(request.text, tts_config)
        
        # Convert to base64
        audio_base64 = base64.b64encode(audio_content).decode('utf-8')
        
        return TTSResponse(
            audio=audio_base64,
            voice_used=tts_config["voice"]["name"],
            config_used=request.config or "default"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        error_msg = str(e)
        if "API key" in error_msg or "authentication" in error_msg.lower():
            raise HTTPException(status_code=401, detail="Invalid Google API key")
        elif "quota" in error_msg.lower():
            raise HTTPException(status_code=429, detail="Google TTS API quota exceeded")
        else:
            raise HTTPException(status_code=500, detail=f"Google TTS error: {error_msg}")


@app.get("/voices")
def list_available_voices():
    """List some popular Google TTS voice options."""
    return {
        "neural_voices": {
            "en-US-Neural2-A": "Female, warm and friendly",
            "en-US-Neural2-C": "Female, clear and professional", 
            "en-US-Neural2-D": "Male, deep and authoritative",
            "en-US-Neural2-F": "Female, bright and engaging",
            "en-US-Neural2-G": "Female, calm and soothing",
            "en-US-Neural2-J": "Male, warm and conversational"
        },
        "wavenet_voices": {
            "en-US-Wavenet-A": "Female, natural and expressive",
            "en-US-Wavenet-B": "Male, professional and clear",
            "en-US-Wavenet-C": "Female, friendly and approachable",
            "en-US-Wavenet-D": "Male, authoritative and confident"
        },
        "parameters": {
            "speaking_rate": "0.25 to 4.0 (1.0 = normal speed)",
            "pitch": "-20.0 to 20.0 (0.0 = normal pitch)",
            "volume_gain_db": "-96.0 to 16.0 (0.0 = normal volume)",
            "effects_profile_id": ["telephony-class-application", "wearable-class-device", "handset-class-device", "headphone-class-device", "small-bluetooth-speaker-class-device", "medium-bluetooth-speaker-class-device", "large-home-entertainment-class-device", "large-automotive-class-device"]
        }
    }


@app.get("/config/{config_name}")
def get_tts_config(config_name: str):
    """Get TTS configuration for a specific persona."""
    config = load_tts_config(config_name)
    return {"config_name": config_name, "tts_config": config}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)