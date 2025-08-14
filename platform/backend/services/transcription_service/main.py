"""Azure Speech-enabled transcription service for BetterBooks."""

import os
import logging
import asyncio
from typing import Dict, Any, Optional, List
from datetime import datetime
import tempfile
import yaml

from fastapi import FastAPI, File, UploadFile, HTTPException, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from azure_speech_service import AzureSpeechService, AzureSpeechConfig

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
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

# Global variables
azure_speech_service: Optional[AzureSpeechService] = None
config: Dict[str, Any] = {}

# Pydantic models
class TranscriptionRequest(BaseModel):
    """Request model for text-based transcription."""
    text: str = Field(..., description="Text to process (for testing)")
    language: Optional[str] = Field("en-US", description="Language code")

class AudioFormat(BaseModel):
    """Audio format specification."""
    sample_rate: int = Field(16000, description="Sample rate in Hz")
    channels: int = Field(1, description="Number of channels")
    bits_per_sample: int = Field(16, description="Bits per sample")

class TranscriptionResponse(BaseModel):
    """Response model for transcription results."""
    text: str = Field(..., description="Transcribed text")
    language: str = Field(..., description="Detected/specified language")
    confidence: Optional[float] = Field(None, description="Transcription confidence")
    segments: Optional[List[str]] = Field(None, description="Text segments")
    word_timestamps: Optional[List[Dict]] = Field(None, description="Word-level timestamps")
    service: str = Field(..., description="Service used for transcription")
    duration_ms: Optional[int] = Field(None, description="Processing duration")

class LanguageDetectionResponse(BaseModel):
    """Response model for language detection."""
    detected_language: str = Field(..., description="Detected language code")
    confidence: Optional[float] = Field(None, description="Detection confidence")
    supported_languages: List[str] = Field(..., description="List of supported languages")

def load_config():
    """Load configuration from YAML file."""
    global config
    try:
        with open('/context_config.yaml', 'r') as f:
            config = yaml.safe_load(f)
            logger.info("Configuration loaded successfully")
    except Exception as e:
        logger.warning(f"Could not load config: {e}, using defaults")
        config = {
            'context': {
                'transcription': {
                    'enabled': True,
                    'service': 'azure',
                    'azure': {
                        'region': 'eastus',
                        'language': 'en-US',
                        'profanity_filter': False,
                        'enable_dictation': True,
                        'enable_punctuation': True
                    }
                }
            }
        }

def initialize_azure_service():
    """Initialize Azure Speech Service."""
    global azure_speech_service
    
    try:
        # Check if Azure is configured
        api_key = os.getenv("AZURE_SPEECH_KEY")
        if not api_key:
            logger.warning("AZURE_SPEECH_KEY not provided. Azure Speech Service will be unavailable.")
            return False
        
        # Create Azure config from environment
        azure_config = AzureSpeechConfig.from_env()
        
        # Initialize service
        azure_speech_service = AzureSpeechService(azure_config)
        logger.info("Azure Speech Service initialized successfully")
        return True
        
    except Exception as e:
        logger.error(f"Failed to initialize Azure Speech Service: {e}")
        return False

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup."""
    load_config()
    azure_initialized = initialize_azure_service()
    
    if azure_initialized:
        logger.info("Transcription service started with Azure Speech Service")
    else:
        logger.warning("Transcription service started without Azure Speech Service")

@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "transcription",
        "status": "running",
        "azure_enabled": azure_speech_service is not None,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "azure_speech": azure_speech_service is not None,
        "config_loaded": bool(config),
        "timestamp": datetime.now().isoformat()
    }

@app.get("/supported-languages", response_model=LanguageDetectionResponse)
async def get_supported_languages():
    """Get list of supported languages."""
    if not azure_speech_service:
        raise HTTPException(
            status_code=503, 
            detail="Azure Speech Service not available"
        )
    
    supported = azure_speech_service.get_supported_languages()
    
    return LanguageDetectionResponse(
        detected_language="unknown",
        supported_languages=supported
    )

@app.post("/transcribe/file", response_model=TranscriptionResponse)
async def transcribe_file(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(..., description="Audio file to transcribe"),
    language: Optional[str] = None
):
    """Transcribe an uploaded audio file."""
    if not azure_speech_service:
        raise HTTPException(
            status_code=503, 
            detail="Azure Speech Service not available"
        )
    
    start_time = datetime.now()
    
    # Validate file type
    allowed_types = [
        "audio/wav", "audio/mpeg", "audio/mp3", "audio/m4a", 
        "audio/ogg", "audio/flac", "audio/aac"
    ]
    
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400, 
            detail=f"Unsupported file type: {file.content_type}"
        )
    
    # Save uploaded file temporarily
    temp_file = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_file:
            content = await file.read()
            temp_file.write(content)
            temp_file_path = temp_file.name
        
        # Override language if provided
        if language:
            azure_speech_service.config.language = language
        
        # Transcribe the audio file
        result = await azure_speech_service.transcribe_audio_file(temp_file_path)
        
        # Clean up temp file in background
        background_tasks.add_task(os.unlink, temp_file_path)
        
        # Calculate processing time
        duration_ms = int((datetime.now() - start_time).total_seconds() * 1000)
        
        return TranscriptionResponse(
            text=result["text"],
            language=result["language"],
            segments=result.get("segments"),
            word_timestamps=result.get("word_timestamps"),
            service="azure",
            duration_ms=duration_ms
        )
        
    except Exception as e:
        # Clean up temp file on error
        if temp_file and os.path.exists(temp_file.name):
            os.unlink(temp_file.name)
        
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

@app.post("/transcribe/stream", response_model=TranscriptionResponse)
async def transcribe_stream(
    request: Request,
    audio_format: AudioFormat = AudioFormat(),
    language: Optional[str] = None
):
    """Transcribe audio from a stream (raw audio data in request body)."""
    if not azure_speech_service:
        raise HTTPException(
            status_code=503, 
            detail="Azure Speech Service not available"
        )
    
    start_time = datetime.now()
    
    try:
        # Read raw audio data from request body
        audio_data = await request.body()
        
        if not audio_data:
            raise HTTPException(status_code=400, detail="No audio data provided")
        
        # Override language if provided
        if language:
            azure_speech_service.config.language = language
        
        # Prepare audio format info
        format_info = {
            "sample_rate": audio_format.sample_rate,
            "channels": audio_format.channels,
            "bits_per_sample": audio_format.bits_per_sample
        }
        
        # Transcribe the audio stream
        result = await azure_speech_service.transcribe_audio_stream(audio_data, format_info)
        
        # Calculate processing time
        duration_ms = int((datetime.now() - start_time).total_seconds() * 1000)
        
        return TranscriptionResponse(
            text=result["text"],
            language=result["language"],
            segments=result.get("segments"),
            word_timestamps=result.get("word_timestamps"),
            service="azure",
            duration_ms=duration_ms
        )
        
    except Exception as e:
        logger.error(f"Stream transcription error: {e}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

@app.post("/detect-language")
async def detect_language(
    request: Request,
    audio_format: AudioFormat = AudioFormat()
) -> LanguageDetectionResponse:
    """Detect the language of audio data."""
    if not azure_speech_service:
        raise HTTPException(
            status_code=503, 
            detail="Azure Speech Service not available"
        )
    
    try:
        # Read raw audio data from request body
        audio_data = await request.body()
        
        if not audio_data:
            raise HTTPException(status_code=400, detail="No audio data provided")
        
        # Prepare audio format info
        format_info = {
            "sample_rate": audio_format.sample_rate,
            "channels": audio_format.channels,
            "bits_per_sample": audio_format.bits_per_sample
        }
        
        # Detect language
        detected_lang = await azure_speech_service.detect_language(audio_data, format_info)
        supported_langs = azure_speech_service.get_supported_languages()
        
        return LanguageDetectionResponse(
            detected_language=detected_lang,
            supported_languages=supported_langs
        )
        
    except Exception as e:
        logger.error(f"Language detection error: {e}")
        raise HTTPException(status_code=500, detail=f"Language detection failed: {str(e)}")

@app.post("/transcribe/with-translation", response_model=Dict[str, Any])
async def transcribe_with_translation(
    request: Request,
    target_languages: List[str],
    audio_format: AudioFormat = AudioFormat(),
    source_language: Optional[str] = None
):
    """Transcribe audio and translate to multiple languages."""
    if not azure_speech_service:
        raise HTTPException(
            status_code=503, 
            detail="Azure Speech Service not available"
        )
    
    start_time = datetime.now()
    
    try:
        # Read raw audio data
        audio_data = await request.body()
        
        if not audio_data:
            raise HTTPException(status_code=400, detail="No audio data provided")
        
        # Override source language if provided
        if source_language:
            azure_speech_service.config.language = source_language
        
        # Prepare audio format info
        format_info = {
            "sample_rate": audio_format.sample_rate,
            "channels": audio_format.channels,
            "bits_per_sample": audio_format.bits_per_sample
        }
        
        # Perform transcription with translation
        result = await azure_speech_service.transcribe_with_translation(
            audio_data, format_info, target_languages
        )
        
        # Calculate processing time
        duration_ms = int((datetime.now() - start_time).total_seconds() * 1000)
        
        return {
            "transcription": result["transcription"],
            "translations": result["translations"],
            "service": "azure",
            "duration_ms": duration_ms
        }
        
    except Exception as e:
        logger.error(f"Translation error: {e}")
        raise HTTPException(status_code=500, detail=f"Translation failed: {str(e)}")

@app.get("/config")
async def get_config():
    """Get current configuration."""
    return {
        "transcription_enabled": config.get('context', {}).get('transcription', {}).get('enabled', False),
        "service": config.get('context', {}).get('transcription', {}).get('service', 'unknown'),
        "azure_config": config.get('context', {}).get('transcription', {}).get('azure', {}),
        "azure_service_available": azure_speech_service is not None
    }

@app.post("/test")
async def test_service(request: TranscriptionRequest) -> TranscriptionResponse:
    """Test endpoint that returns mock transcription data."""
    return TranscriptionResponse(
        text=f"Mock transcription of: {request.text}",
        language=request.language or "en-US",
        service="azure-mock",
        duration_ms=100
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")