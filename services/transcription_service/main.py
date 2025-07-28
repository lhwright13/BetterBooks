"""Transcription service for extracting text from audio files."""

import os
import json
import hashlib
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
import yaml

from faster_whisper import WhisperModel
from fastapi import FastAPI, HTTPException, File, UploadFile, Form
from pydantic import BaseModel
import librosa
import numpy as np


# Load configuration
def load_config():
    config_path = Path("/context_config.yaml")
    if not config_path.exists():
        # Fallback to relative path for development
        config_path = Path(__file__).parent.parent.parent / "context_config.yaml"
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


config = load_config()
context_config = config['context']

# Initialize Faster-Whisper model
# Use CPU with int8 quantization for better performance
whisper_model = WhisperModel(
    context_config['transcription']['model'], 
    device="cpu", 
    compute_type="int8"
)

app = FastAPI()

# Cache directory for transcripts
CACHE_DIR = Path("/app/transcript_cache")
CACHE_DIR.mkdir(exist_ok=True)


class TranscriptionRequest(BaseModel):
    """Schema for transcription requests."""
    audio_file_path: str
    start_time: float = 0.0
    duration: float = None  # None means full file


class ContextRequest(BaseModel):
    """Schema for context extraction requests."""
    book_name: str
    chapter_name: Optional[str] = None
    current_position: float  # Current playback position in seconds
    

class TranscriptionResponse(BaseModel):
    """Schema for transcription responses."""
    text: str
    segments: List[Dict[str, Any]]
    duration: float
    cached: bool


def get_cache_key(file_path: str, start_time: float, duration: Optional[float]) -> str:
    """Generate cache key for transcript."""
    content = f"{file_path}:{start_time}:{duration}"
    return hashlib.md5(content.encode()).hexdigest()


def get_cached_transcript(cache_key: str) -> Optional[Dict]:
    """Retrieve cached transcript if available and not expired."""
    cache_file = CACHE_DIR / f"{cache_key}.json"
    
    if not cache_file.exists():
        return None
        
    try:
        with open(cache_file, 'r') as f:
            cached_data = json.load(f)
            
        # Check if cache is expired
        cached_time = datetime.fromisoformat(cached_data['timestamp'])
        expiry_time = cached_time + timedelta(hours=context_config['storage']['cache_duration_hours'])
        
        if datetime.now() > expiry_time:
            cache_file.unlink()  # Delete expired cache
            return None
            
        return cached_data
    except Exception:
        return None


def save_transcript_cache(cache_key: str, transcript_data: Dict):
    """Save transcript to cache."""
    if not context_config['storage']['cache_transcripts']:
        return
        
    cache_file = CACHE_DIR / f"{cache_key}.json"
    transcript_data['timestamp'] = datetime.now().isoformat()
    
    try:
        with open(cache_file, 'w') as f:
            json.dump(transcript_data, f)
    except Exception as e:
        print(f"Failed to cache transcript: {e}")


def extract_audio_segment(file_path: str, start_time: float, duration: Optional[float] = None) -> np.ndarray:
    """Extract audio segment from file."""
    try:
        # Load audio file
        audio, sr = librosa.load(file_path, sr=16000)  # Whisper expects 16kHz
        
        start_sample = int(start_time * sr)
        
        if duration:
            end_sample = int((start_time + duration) * sr)
            audio_segment = audio[start_sample:end_sample]
        else:
            audio_segment = audio[start_sample:]
            
        return audio_segment
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to load audio: {str(e)}")


def transcribe_audio(audio_data: np.ndarray) -> Dict:
    """Transcribe audio using Faster-Whisper."""
    try:
        # Create temporary file for Faster-Whisper
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_file:
            import soundfile as sf
            sf.write(temp_file.name, audio_data, 16000)
            
            # Transcribe with Faster-Whisper
            segments, info = whisper_model.transcribe(
                temp_file.name,
                language=context_config['transcription']['language'],
                vad_filter=True,  # Voice activity detection for better accuracy
                vad_parameters=dict(min_silence_duration_ms=500)  # Faster processing
            )
            
            # Convert segments to list and format like original whisper
            segments_list = []
            full_text = ""
            
            for segment in segments:
                segment_dict = {
                    'start': segment.start,
                    'end': segment.end,
                    'text': segment.text.strip()
                }
                segments_list.append(segment_dict)
                full_text += segment.text.strip() + " "
            
            # Clean up temp file
            os.unlink(temp_file.name)
            
            return {
                'text': full_text.strip(),
                'segments': segments_list,
                'language': info.language,
                'language_probability': info.language_probability
            }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")


@app.get("/health")
def health() -> Dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok"}


@app.post("/transcribe", response_model=TranscriptionResponse)
def transcribe(request: TranscriptionRequest) -> TranscriptionResponse:
    """Transcribe audio file or segment."""
    
    # Check cache first
    cache_key = get_cache_key(request.audio_file_path, request.start_time, request.duration)
    cached_result = get_cached_transcript(cache_key)
    
    if cached_result:
        return TranscriptionResponse(
            text=cached_result['text'],
            segments=cached_result['segments'],
            duration=cached_result['duration'],
            cached=True
        )
    
    # Extract audio segment
    audio_data = extract_audio_segment(
        request.audio_file_path, 
        request.start_time, 
        request.duration
    )
    
    # Transcribe
    result = transcribe_audio(audio_data)
    
    # Prepare response
    response_data = {
        'text': result['text'],
        'segments': result['segments'],
        'duration': len(audio_data) / 16000,  # Duration in seconds
        'cached': False
    }
    
    # Cache the result
    save_transcript_cache(cache_key, response_data)
    
    return TranscriptionResponse(**response_data)


@app.post("/context")
def get_context(request: ContextRequest) -> Dict[str, Any]:
    """Extract context around current playback position."""
    
    # Build file path
    if request.chapter_name:
        audio_file = Path(f"/app/book_files/{request.book_name}/{request.chapter_name}")
    else:
        # Single file book
        files = list(Path(f"/app/book_files/{request.book_name}").glob("*.mp3"))
        if not files:
            raise HTTPException(status_code=404, detail="Audio file not found")
        audio_file = files[0]
    
    if not audio_file.exists():
        raise HTTPException(status_code=404, detail="Audio file not found")
    
    # Calculate context window
    duration_seconds = context_config['duration_minutes'] * 60
    overlap_seconds = context_config['overlap_seconds']
    
    # Start context window before current position
    context_start = max(0, request.current_position - duration_seconds + overlap_seconds)
    context_duration = min(duration_seconds, request.current_position + overlap_seconds)
    
    # Get transcript for context window
    transcription_request = TranscriptionRequest(
        audio_file_path=str(audio_file),
        start_time=context_start,
        duration=context_duration
    )
    
    transcript_result = transcribe(transcription_request)
    
    # Format context with timestamps if enabled
    context_text = transcript_result.text
    
    if context_config['delivery']['include_timestamps']:
        # Add timestamp information
        context_segments = []
        for segment in transcript_result.segments:
            start_time = context_start + segment['start']
            end_time = context_start + segment['end']
            
            if context_config['delivery']['include_timestamps']:
                context_segments.append(
                    f"[{int(start_time//60):02d}:{int(start_time%60):02d}] {segment['text']}"
                )
            else:
                context_segments.append(segment['text'])
        
        context_text = " ".join(context_segments)
    
    # Trim context if too long
    max_tokens = context_config['delivery']['max_context_tokens']
    if len(context_text.split()) > max_tokens:
        words = context_text.split()
        context_text = " ".join(words[-max_tokens:])
        context_text = "..." + context_text
    
    return {
        "context_text": context_text,
        "context_start_time": context_start,
        "context_duration": context_duration,
        "current_position": request.current_position,
        "book_name": request.book_name,
        "chapter_name": request.chapter_name,
        "cached": transcript_result.cached
    }


@app.get("/config")
def get_config() -> Dict[str, Any]:
    """Return current configuration."""
    return context_config