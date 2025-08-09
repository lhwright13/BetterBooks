"""Transcription service for extracting text from audio files with AI-powered chapter detection."""

import os
import sys
import json
import hashlib
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
import yaml

from faster_whisper import WhisperModel
from fastapi import FastAPI, HTTPException, File, UploadFile, Form, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import librosa
import numpy as np

# Add shared modules to path  
sys.path.append(str(Path(__file__).parent.parent / "shared"))

from chapter_detection import (
    ChapterDetectionEngine, DetectedChapter, 
    detect_chapters_for_audiobook, format_chapters_for_display
)
from chapter_summaries import (
    ChapterSummaryGenerator, SummaryStyle, ChapterSummary, SummaryRequest,
    generate_chapter_summaries, format_summaries_for_display
)
from question_generation import (
    QuestionGenerator, QuestionDifficulty, QuestionType, ReadingMode,
    GeneratedQuestion, QuestionSet, QuestionGenerationRequest,
    generate_chapter_questions, format_questions_for_display
)
from logging_config import setup_logging
from health_checks import HealthCheck, create_health_endpoint
from metrics import setup_metrics


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

app = FastAPI(
    title="EchoWright Transcription Service",
    description="Audio transcription and AI-powered chapter detection",
    version="1.0.0"
)

# Add CORS middleware for web app access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8080"],  # Web app origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Set up logging and monitoring
logger = setup_logging(
    service_name="transcription_service",
    log_level=os.getenv("LOG_LEVEL", "INFO")
)

# Set up health checks
health_check = HealthCheck("transcription_service", "1.0.0")
create_health_endpoint(app, health_check)

# Set up metrics
metrics_collector = setup_metrics(app, "transcription_service")

# Cache directory for transcripts
CACHE_DIR = Path("/app/transcript_cache")
CACHE_DIR.mkdir(exist_ok=True)

# Cache for chapter detection results
CHAPTERS_CACHE_DIR = Path("/app/chapters_cache")
CHAPTERS_CACHE_DIR.mkdir(exist_ok=True)


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


class ChapterDetectionRequest(BaseModel):
    """Schema for chapter detection requests."""
    audio_file_path: str
    book_title: Optional[str] = None
    force_redetect: bool = False  # Force re-detection even if cached


class ChapterDetectionResponse(BaseModel):
    """Schema for chapter detection responses."""
    book_title: str
    audio_file_path: str
    total_chapters: int
    total_duration: float
    detection_confidence: float
    chapters: List[Dict[str, Any]]
    cached: bool
    processing_time_seconds: float


class FullBookAnalysisRequest(BaseModel):
    """Schema for full book analysis (transcription + chapter detection)."""
    audio_file_path: str
    book_title: Optional[str] = None
    include_chapter_summaries: bool = True
    force_reprocess: bool = False


class SummaryGenerationRequest(BaseModel):
    """Schema for chapter summary generation requests."""
    audio_file_path: str
    book_title: Optional[str] = None
    chapter_ids: Optional[List[str]] = None  # None = all chapters
    summary_style: str = "detailed"  # brief, detailed, themes, key_points, question_based
    include_themes: bool = True
    include_characters: bool = True
    max_summary_length: int = 500


class SummaryResponse(BaseModel):
    """Schema for summary generation responses."""
    book_title: str
    total_summaries: int
    summary_style: str
    summaries: List[Dict[str, Any]]
    processing_time_seconds: float
    cached: bool


class ChapterSummaryItem(BaseModel):
    """Schema for individual chapter summary."""
    chapter_id: str
    chapter_number: int
    chapter_title: str
    summary_text: str
    key_points: List[str]
    themes: List[str]
    characters_mentioned: List[str]
    word_count: int
    confidence_score: float


class QuestionGenerationAPIRequest(BaseModel):
    """Schema for question generation API requests."""
    audio_file_path: str
    book_title: Optional[str] = None
    chapter_id: str
    chapter_number: int
    current_position: Optional[float] = None
    num_questions: int = 5
    difficulty: str = "intermediate"  # beginner, intermediate, advanced, adaptive
    question_types: Optional[List[str]] = None  # comprehension, analysis, discussion, etc.
    reading_mode: str = "casual"  # educational, casual, child, professional, language_learning
    focus_areas: Optional[List[str]] = None


class QuestionItem(BaseModel):
    """Schema for individual question."""
    question_id: str
    question_text: str
    question_type: str
    difficulty: str
    suggested_answer: str
    answer_guidelines: List[str]
    follow_up_questions: List[str]
    related_themes: List[str]
    confidence_score: float


class QuestionSetResponse(BaseModel):
    """Schema for question set response."""
    set_id: str
    chapter_id: str
    chapter_title: str
    total_questions: int
    questions: List[QuestionItem]
    difficulty_distribution: Dict[str, int]
    type_distribution: Dict[str, int]
    reading_mode: str
    processing_time_seconds: float


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


def get_chapters_cache_key(file_path: str) -> str:
    """Generate cache key for chapter detection results."""
    file_stat = os.stat(file_path)
    content = f"{file_path}:{file_stat.st_size}:{file_stat.st_mtime}"
    return hashlib.md5(content.encode()).hexdigest()


def get_cached_chapters(cache_key: str) -> Optional[Dict]:
    """Retrieve cached chapter detection results."""
    cache_file = CHAPTERS_CACHE_DIR / f"{cache_key}.json"
    
    if not cache_file.exists():
        return None
        
    try:
        with open(cache_file, 'r') as f:
            cached_data = json.load(f)
            
        # Check if cache is expired (24 hours for chapter detection)
        cached_time = datetime.fromisoformat(cached_data['timestamp'])
        expiry_time = cached_time + timedelta(hours=24)
        
        if datetime.now() > expiry_time:
            cache_file.unlink()  # Delete expired cache
            return None
            
        return cached_data
    except Exception:
        return None


def save_chapters_cache(cache_key: str, chapters_data: Dict):
    """Save chapter detection results to cache."""
    cache_file = CHAPTERS_CACHE_DIR / f"{cache_key}.json"
    chapters_data['timestamp'] = datetime.now().isoformat()
    
    try:
        with open(cache_file, 'w') as f:
            json.dump(chapters_data, f, indent=2)
        logger.info(f"Cached chapter detection results: {cache_key}")
    except Exception as e:
        logger.error(f"Failed to cache chapters: {e}")


async def get_full_transcript(audio_file_path: str) -> Dict:
    """Get complete transcript for a file."""
    # Use full file transcription
    request = TranscriptionRequest(
        audio_file_path=audio_file_path,
        start_time=0.0,
        duration=None
    )
    
    return transcribe(request)


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


@app.post("/detect-chapters", response_model=ChapterDetectionResponse)
async def detect_chapters(request: ChapterDetectionRequest) -> ChapterDetectionResponse:
    """Detect chapters in an audiobook using AI analysis."""
    import time
    start_time = time.time()
    
    logger.info(f"Starting chapter detection for {request.audio_file_path}")
    
    # Validate file exists
    if not Path(request.audio_file_path).exists():
        raise HTTPException(status_code=404, detail="Audio file not found")
    
    # Check cache unless forced redetection
    cache_key = get_chapters_cache_key(request.audio_file_path)
    cached_result = None if request.force_redetect else get_cached_chapters(cache_key)
    
    if cached_result:
        processing_time = time.time() - start_time
        logger.info(f"Returning cached chapter detection results")
        
        return ChapterDetectionResponse(
            book_title=cached_result.get('book_title', request.book_title or 'Unknown'),
            audio_file_path=request.audio_file_path,
            total_chapters=cached_result['total_chapters'],
            total_duration=cached_result['total_duration'],
            detection_confidence=cached_result['detection_confidence'],
            chapters=cached_result['chapters'],
            cached=True,
            processing_time_seconds=processing_time
        )
    
    try:
        # Get full transcript
        logger.info("Generating full transcript for chapter detection...")
        transcript_result = await get_full_transcript(request.audio_file_path)
        
        if not transcript_result.segments:
            raise HTTPException(status_code=400, detail="No transcript segments found")
        
        # Run AI chapter detection
        logger.info("Running AI-powered chapter detection...")
        detector = ChapterDetectionEngine()
        detected_chapters = await detector.detect_chapters(
            request.audio_file_path,
            transcript_result.segments
        )
        
        if not detected_chapters:
            raise HTTPException(status_code=400, detail="No chapters could be detected")
        
        # Calculate overall confidence
        overall_confidence = sum(c.confidence for c in detected_chapters) / len(detected_chapters)
        
        # Prepare response data
        chapters_data = []
        for chapter in detected_chapters:
            chapters_data.append({
                "chapter_number": chapter.chapter_number,
                "title": chapter.title,
                "start_time": chapter.start_time,
                "end_time": chapter.end_time,
                "duration": chapter.duration,
                "confidence": chapter.confidence,
                "summary": chapter.summary,
                "key_topics": chapter.key_topics,
                "word_count": chapter.word_count,
                "speaker_changes": chapter.speaker_changes
            })
        
        # Cache results
        cache_data = {
            'book_title': request.book_title or Path(request.audio_file_path).stem,
            'audio_file_path': request.audio_file_path,
            'total_chapters': len(detected_chapters),
            'total_duration': transcript_result.duration,
            'detection_confidence': overall_confidence,
            'chapters': chapters_data,
        }
        save_chapters_cache(cache_key, cache_data)
        
        processing_time = time.time() - start_time
        logger.info(f"Chapter detection completed: {len(detected_chapters)} chapters in {processing_time:.2f}s")
        
        return ChapterDetectionResponse(
            book_title=cache_data['book_title'],
            audio_file_path=request.audio_file_path,
            total_chapters=len(detected_chapters),
            total_duration=transcript_result.duration,
            detection_confidence=overall_confidence,
            chapters=chapters_data,
            cached=False,
            processing_time_seconds=processing_time
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chapter detection failed: {e}")
        raise HTTPException(status_code=500, detail=f"Chapter detection failed: {str(e)}")


@app.post("/analyze-book")
async def analyze_full_book(
    request: FullBookAnalysisRequest,
    background_tasks: BackgroundTasks
) -> Dict[str, Any]:
    """Complete book analysis: transcription + chapter detection + metadata."""
    import time
    start_time = time.time()
    
    logger.info(f"Starting full book analysis for {request.audio_file_path}")
    
    # Validate file exists
    if not Path(request.audio_file_path).exists():
        raise HTTPException(status_code=404, detail="Audio file not found")
    
    try:
        # Step 1: Get full transcript
        logger.info("Phase 1: Full transcription...")
        transcript_result = await get_full_transcript(request.audio_file_path)
        
        # Step 2: Detect chapters
        logger.info("Phase 2: AI chapter detection...")
        chapter_request = ChapterDetectionRequest(
            audio_file_path=request.audio_file_path,
            book_title=request.book_title,
            force_redetect=request.force_reprocess
        )
        chapter_result = await detect_chapters(chapter_request)
        
        # Step 3: Generate book-level metadata
        logger.info("Phase 3: Book metadata generation...")
        book_metadata = await _generate_book_metadata(
            transcript_result.text,
            chapter_result.chapters,
            request.book_title
        )
        
        processing_time = time.time() - start_time
        logger.info(f"Full book analysis completed in {processing_time:.2f}s")
        
        return {
            "analysis_id": hashlib.md5(request.audio_file_path.encode()).hexdigest(),
            "book_title": book_metadata.get("title", request.book_title),
            "analysis_timestamp": datetime.now().isoformat(),
            "processing_time_seconds": processing_time,
            "audio_info": {
                "file_path": request.audio_file_path,
                "duration_seconds": transcript_result.duration,
                "total_words": len(transcript_result.text.split())
            },
            "transcript_info": {
                "total_segments": len(transcript_result.segments),
                "language_detected": "en",  # Could be enhanced with language detection
                "cached": transcript_result.cached
            },
            "chapter_info": {
                "total_chapters": chapter_result.total_chapters,
                "average_chapter_duration": chapter_result.total_duration / chapter_result.total_chapters,
                "detection_confidence": chapter_result.detection_confidence,
                "chapters": chapter_result.chapters
            },
            "book_metadata": book_metadata
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Full book analysis failed: {e}")
        raise HTTPException(status_code=500, detail=f"Book analysis failed: {str(e)}")


@app.get("/chapters/{book_id}")
async def get_book_chapters(book_id: str) -> Dict[str, Any]:
    """Get cached chapter information for a book."""
    # This would typically look up by book ID in a database
    # For now, we'll look for cached results by filename
    
    try:
        # Find cached chapter files
        cached_files = list(CHAPTERS_CACHE_DIR.glob(f"*{book_id}*.json"))
        
        if not cached_files:
            raise HTTPException(status_code=404, detail="No chapter data found for this book")
        
        # Return the most recent cache
        latest_cache = max(cached_files, key=lambda f: f.stat().st_mtime)
        
        with open(latest_cache, 'r') as f:
            cached_data = json.load(f)
        
        return {
            "book_id": book_id,
            "cached_at": cached_data.get("timestamp"),
            "total_chapters": cached_data.get("total_chapters", 0),
            "chapters": cached_data.get("chapters", [])
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to retrieve chapters for book {book_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve chapter data")


async def _generate_book_metadata(
    full_text: str, 
    chapters: List[Dict], 
    book_title: Optional[str]
) -> Dict[str, Any]:
    """Generate book-level metadata using LLM analysis."""
    try:
        # Prepare book summary from chapter summaries
        chapter_summaries = [ch.get("summary", "") for ch in chapters if ch.get("summary")]
        
        # Use LLM to generate book metadata
        prompt = f"""Analyze this audiobook and provide comprehensive metadata:

Book Title: {book_title or "Unknown"}
Number of Chapters: {len(chapters)}
Total Word Count: {len(full_text.split())}

Chapter Summaries:
{chr(10).join(f"Chapter {i+1}: {summary}" for i, summary in enumerate(chapter_summaries[:5]))}

Based on this information, provide:
1. Genre classification
2. Target audience
3. Reading difficulty level (1-10)
4. Overall book summary (3-4 sentences)
5. Key themes and topics
6. Estimated reading time

Respond in JSON format."""
        
        # This would call the LLM service - for now, return placeholder
        return {
            "genre": "Unknown",
            "target_audience": "General",
            "difficulty_level": 5,
            "summary": f"This audiobook contains {len(chapters)} chapters covering various topics.",
            "themes": ["General Content"],
            "estimated_reading_hours": len(full_text.split()) / 200 / 60  # Rough estimate
        }
        
    except Exception as e:
        logger.error(f"Book metadata generation failed: {e}")
        return {
            "genre": "Unknown",
            "summary": "Metadata generation unavailable",
            "themes": [],
            "estimated_reading_hours": 0
        }


@app.get("/config")
def get_config() -> Dict[str, Any]:
    """Return current configuration."""
    return context_config


@app.get("/stats")
async def get_service_stats() -> Dict[str, Any]:
    """Get service statistics and performance metrics."""
    try:
        # Count cached items
        transcript_cache_count = len(list(CACHE_DIR.glob("*.json")))
        chapters_cache_count = len(list(CHAPTERS_CACHE_DIR.glob("*.json")))
        
        # Cache directory sizes
        transcript_cache_size = sum(f.stat().st_size for f in CACHE_DIR.glob("*.json"))
        chapters_cache_size = sum(f.stat().st_size for f in CHAPTERS_CACHE_DIR.glob("*.json"))
        
        return {
            "service": "transcription_service",
            "version": "1.0.0",
            "uptime_info": "Service running",
            "cache_stats": {
                "transcript_cache": {
                    "count": transcript_cache_count,
                    "size_mb": transcript_cache_size / (1024 * 1024),
                    "directory": str(CACHE_DIR)
                },
                "chapters_cache": {
                    "count": chapters_cache_count,
                    "size_mb": chapters_cache_size / (1024 * 1024),
                    "directory": str(CHAPTERS_CACHE_DIR)
                }
            },
            "model_info": {
                "whisper_model": context_config['transcription']['model'],
                "language": context_config['transcription']['language'],
                "device": "cpu",
                "compute_type": "int8"
            },
            "capabilities": [
                "audio_transcription",
                "chapter_detection",
                "book_analysis",
                "context_extraction",
                "ai_metadata_generation",
                "smart_chapter_summaries"
            ]
        }
        
    except Exception as e:
        logger.error(f"Failed to get service stats: {e}")
        return {"error": "Failed to retrieve stats"}


@app.post("/generate-summaries", response_model=SummaryResponse)
async def generate_chapter_summaries_endpoint(request: SummaryGenerationRequest):
    """
    Generate AI-powered summaries for audiobook chapters.
    
    Supports multiple summary styles:
    - brief: 1-2 sentences, key points only
    - detailed: 3-5 sentences, comprehensive overview  
    - themes: Focus on themes, symbols, character development
    - key_points: Bullet point format with main events
    - question_based: Summary in Q&A format
    """
    start_time = datetime.now()
    logger.info(f"Generating chapter summaries for {request.audio_file_path}")
    
    try:
        # Validate summary style
        try:
            style = SummaryStyle(request.summary_style)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid summary style. Must be one of: {[s.value for s in SummaryStyle]}"
            )
        
        # First, ensure we have chapters detected
        chapter_cache_key = hashlib.md5(f"chapters:{request.audio_file_path}".encode()).hexdigest()
        chapter_cache_file = CHAPTERS_CACHE_DIR / f"{chapter_cache_key}.json"
        
        if not chapter_cache_file.exists():
            # Need to detect chapters first
            detection_request = ChapterDetectionRequest(
                audio_file_path=request.audio_file_path,
                book_title=request.book_title
            )
            await detect_chapters_endpoint(detection_request)
        
        # Load detected chapters
        with open(chapter_cache_file, 'r') as f:
            chapter_data = json.load(f)
        
        chapters = []
        for ch in chapter_data['chapters']:
            chapter = DetectedChapter(
                chapter_number=ch['chapter_number'],
                title=ch['title'], 
                start_time=ch['start_time'],
                end_time=ch['end_time'],
                duration=ch['duration'],
                confidence=ch['confidence'],
                summary=ch.get('summary', ''),
                key_topics=ch.get('key_topics', []),
                word_count=ch.get('word_count', 0),
                speaker_changes=ch.get('speaker_changes', 0)
            )
            chapters.append(chapter)
        
        # Get transcript for each chapter
        transcript_cache_key = get_cache_key(request.audio_file_path, 0.0, None)
        transcript_cache_file = CACHE_DIR / f"{transcript_cache_key}.json"
        
        if not transcript_cache_file.exists():
            raise HTTPException(
                status_code=400,
                detail="Transcript not found. Please transcribe the audio first using /transcribe endpoint."
            )
        
        with open(transcript_cache_file, 'r') as f:
            transcript_data = json.load(f)
        
        # Extract chapter texts from transcript
        chapter_texts = {}
        for chapter in chapters:
            if request.chapter_ids and f"chapter_{chapter.chapter_number}" not in request.chapter_ids:
                continue
                
            chapter_segments = [
                seg for seg in transcript_data['segments'] 
                if seg['start'] >= chapter.start_time and seg['end'] <= chapter.end_time
            ]
            chapter_text = " ".join(seg['text'] for seg in chapter_segments)
            chapter_texts[f"chapter_{chapter.chapter_number}"] = chapter_text
        
        # Generate summaries
        generator = ChapterSummaryGenerator()
        summary_request = SummaryRequest(
            book_id=hashlib.md5(request.audio_file_path.encode()).hexdigest(),
            book_title=request.book_title or "Unknown Book",
            chapter_ids=request.chapter_ids,
            summary_style=style,
            include_themes=request.include_themes,
            include_characters=request.include_characters,
            max_summary_length=request.max_summary_length
        )
        
        filtered_chapters = chapters
        if request.chapter_ids:
            filtered_chapters = [c for c in chapters if f"chapter_{c.chapter_number}" in request.chapter_ids]
        
        summaries = await generator.generate_book_summaries(
            summary_request, filtered_chapters, chapter_texts
        )
        
        # Format response
        summary_items = []
        for summary in summaries:
            summary_items.append({
                "chapter_id": summary.chapter_id,
                "chapter_number": summary.chapter_number,
                "chapter_title": summary.chapter_title,
                "summary_text": summary.summary_text,
                "key_points": summary.key_points,
                "themes": summary.themes,
                "characters_mentioned": summary.characters_mentioned,
                "word_count": summary.word_count,
                "confidence_score": summary.confidence_score,
                "metadata": summary.metadata
            })
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        return SummaryResponse(
            book_title=request.book_title or "Unknown Book",
            total_summaries=len(summary_items),
            summary_style=request.summary_style,
            summaries=summary_items,
            processing_time_seconds=processing_time,
            cached=False  # For now, we don't cache summaries
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating summaries: {e}")
        raise HTTPException(status_code=500, detail=f"Summary generation failed: {str(e)}")


@app.post("/summarize-chapter")
async def summarize_single_chapter(
    book_title: str,
    chapter_number: int, 
    summary_style: str = "detailed",
    audio_file_path: Optional[str] = None
):
    """
    Generate a summary for a specific chapter.
    
    This endpoint allows generating summaries for individual chapters
    without needing to process the entire book.
    """
    start_time = datetime.now()
    logger.info(f"Generating summary for Chapter {chapter_number} of {book_title}")
    
    try:
        # Validate summary style
        try:
            style = SummaryStyle(summary_style)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid summary style. Must be one of: {[s.value for s in SummaryStyle]}"
            )
        
        # For now, call the full summary endpoint with specific chapter
        if not audio_file_path:
            raise HTTPException(
                status_code=400,
                detail="audio_file_path is required for single chapter summarization"
            )
        
        request = SummaryGenerationRequest(
            audio_file_path=audio_file_path,
            book_title=book_title,
            chapter_ids=[f"chapter_{chapter_number}"],
            summary_style=summary_style
        )
        
        response = await generate_chapter_summaries_endpoint(request)
        
        if not response.summaries:
            raise HTTPException(
                status_code=404,
                detail=f"Chapter {chapter_number} not found or could not be summarized"
            )
        
        return {
            "chapter_summary": response.summaries[0],
            "processing_time_seconds": response.processing_time_seconds
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error summarizing chapter: {e}")
        raise HTTPException(status_code=500, detail=f"Chapter summarization failed: {str(e)}")


@app.get("/summary-styles")
def get_available_summary_styles():
    """Get list of available summary styles with descriptions."""
    return {
        "styles": [
            {
                "style": "brief",
                "description": "1-2 sentences focusing on key points only",
                "target_length": "~100 characters",
                "best_for": "Quick overview, mobile reading"
            },
            {
                "style": "detailed", 
                "description": "3-5 sentences with comprehensive overview",
                "target_length": "~300 characters",
                "best_for": "Balanced summary with context"
            },
            {
                "style": "themes",
                "description": "Focus on themes, symbols, and character development", 
                "target_length": "~250 characters",
                "best_for": "Literary analysis, educational use"
            },
            {
                "style": "key_points",
                "description": "Bullet point format with main events",
                "target_length": "~200 characters", 
                "best_for": "Study notes, quick reference"
            },
            {
                "style": "question_based",
                "description": "Q&A format covering main points",
                "target_length": "~300 characters",
                "best_for": "Interactive learning, comprehension check"
            }
        ]
    }


@app.post("/generate-questions", response_model=QuestionSetResponse)
async def generate_questions_endpoint(request: QuestionGenerationAPIRequest):
    """
    Generate personalized discussion questions for an audiobook chapter.
    
    Supports multiple difficulty levels and reading modes:
    - Difficulties: beginner, intermediate, advanced, adaptive
    - Reading modes: educational, casual, child, professional, language_learning
    - Question types: comprehension, analysis, discussion, creative, vocabulary, prediction, connection
    """
    start_time = datetime.now()
    logger.info(f"Generating questions for Chapter {request.chapter_number} of {request.book_title}")
    
    try:
        # Validate difficulty
        try:
            difficulty = QuestionDifficulty(request.difficulty)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid difficulty. Must be one of: {[d.value for d in QuestionDifficulty]}"
            )
        
        # Validate reading mode
        try:
            reading_mode = ReadingMode(request.reading_mode)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid reading mode. Must be one of: {[m.value for m in ReadingMode]}"
            )
        
        # Validate question types if provided
        question_types = None
        if request.question_types:
            question_types = []
            for qt in request.question_types:
                try:
                    question_types.append(QuestionType(qt))
                except ValueError:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Invalid question type: {qt}. Must be one of: {[t.value for t in QuestionType]}"
                    )
        
        # Get chapter text from transcript
        transcript_cache_key = get_cache_key(request.audio_file_path, 0.0, None)
        transcript_cache_file = CACHE_DIR / f"{transcript_cache_key}.json"
        
        if not transcript_cache_file.exists():
            raise HTTPException(
                status_code=400,
                detail="Transcript not found. Please transcribe the audio first using /transcribe endpoint."
            )
        
        with open(transcript_cache_file, 'r') as f:
            transcript_data = json.load(f)
        
        # Get chapters if available
        chapter_cache_key = hashlib.md5(f"chapters:{request.audio_file_path}".encode()).hexdigest()
        chapter_cache_file = CHAPTERS_CACHE_DIR / f"{chapter_cache_key}.json"
        
        chapter_text = ""
        chapter_summary = None
        
        if chapter_cache_file.exists():
            with open(chapter_cache_file, 'r') as f:
                chapter_data = json.load(f)
            
            # Find the requested chapter
            for ch in chapter_data['chapters']:
                if ch['chapter_number'] == request.chapter_number:
                    # Extract text for this chapter
                    chapter_segments = [
                        seg for seg in transcript_data['segments']
                        if seg['start'] >= ch['start_time'] and seg['end'] <= ch['end_time']
                    ]
                    chapter_text = " ".join(seg['text'] for seg in chapter_segments)
                    break
        
        if not chapter_text:
            # Fallback: use entire transcript if no chapters
            chapter_text = " ".join(seg['text'] for seg in transcript_data['segments'])
        
        # Try to get chapter summary if available (for enhanced question generation)
        # This would require checking if summaries have been generated
        
        # Create question generation request
        gen_request = QuestionGenerationRequest(
            book_id=hashlib.md5(request.audio_file_path.encode()).hexdigest(),
            book_title=request.book_title or "Unknown Book",
            chapter_id=request.chapter_id,
            chapter_number=request.chapter_number,
            current_position=request.current_position,
            num_questions=request.num_questions,
            difficulty=difficulty,
            question_types=question_types,
            reading_mode=reading_mode,
            focus_areas=request.focus_areas
        )
        
        # Generate questions
        generator = QuestionGenerator()
        question_set = await generator.generate_questions(
            gen_request,
            chapter_text,
            chapter_summary
        )
        
        # Format response
        question_items = []
        for q in question_set.questions:
            question_items.append(QuestionItem(
                question_id=q.question_id,
                question_text=q.question_text,
                question_type=q.question_type.value,
                difficulty=q.difficulty.value,
                suggested_answer=q.suggested_answer,
                answer_guidelines=q.answer_guidelines,
                follow_up_questions=q.follow_up_questions,
                related_themes=q.related_themes,
                confidence_score=q.confidence_score
            ))
        
        processing_time = (datetime.now() - start_time).total_seconds()
        
        return QuestionSetResponse(
            set_id=question_set.set_id,
            chapter_id=question_set.chapter_id,
            chapter_title=question_set.chapter_title,
            total_questions=question_set.total_questions,
            questions=question_items,
            difficulty_distribution=question_set.difficulty_distribution,
            type_distribution=question_set.type_distribution,
            reading_mode=question_set.reading_mode.value,
            processing_time_seconds=processing_time
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating questions: {e}")
        raise HTTPException(status_code=500, detail=f"Question generation failed: {str(e)}")


@app.get("/question-types")
def get_question_types():
    """Get available question types with descriptions."""
    return {
        "types": [
            {
                "type": "comprehension",
                "description": "Basic understanding questions about what happened",
                "example": "What did the main character do when...?",
                "difficulties": ["beginner", "intermediate", "advanced"]
            },
            {
                "type": "analysis",
                "description": "Analytical questions about why and how",
                "example": "Why do you think the character made that decision?",
                "difficulties": ["intermediate", "advanced"]
            },
            {
                "type": "discussion",
                "description": "Open-ended questions for discussion",
                "example": "What would you have done in that situation?",
                "difficulties": ["beginner", "intermediate", "advanced"]
            },
            {
                "type": "creative",
                "description": "Creative thinking and imagination questions",
                "example": "Rewrite the ending of this chapter.",
                "difficulties": ["intermediate", "advanced"]
            },
            {
                "type": "vocabulary",
                "description": "Language and vocabulary questions",
                "example": "What does this word mean in context?",
                "difficulties": ["beginner", "intermediate"]
            },
            {
                "type": "prediction",
                "description": "Questions about what might happen next",
                "example": "What do you think will happen in the next chapter?",
                "difficulties": ["beginner", "intermediate", "advanced"]
            },
            {
                "type": "connection",
                "description": "Questions connecting to earlier events or themes",
                "example": "How does this relate to what happened in Chapter 2?",
                "difficulties": ["intermediate", "advanced"]
            }
        ]
    }


@app.get("/reading-modes")
def get_reading_modes():
    """Get available reading modes with descriptions."""
    return {
        "modes": [
            {
                "mode": "educational",
                "description": "Academic focus with learning objectives",
                "tone": "Formal and instructional",
                "best_for": "Students, classroom settings",
                "question_focus": ["comprehension", "analysis", "vocabulary"]
            },
            {
                "mode": "casual",
                "description": "Fun and engaging for leisure reading",
                "tone": "Conversational and relaxed",
                "best_for": "Personal enjoyment, book clubs",
                "question_focus": ["discussion", "prediction", "creative"]
            },
            {
                "mode": "child",
                "description": "Age-appropriate for young readers",
                "tone": "Simple and friendly",
                "best_for": "Children, young learners",
                "question_focus": ["comprehension", "creative", "prediction"]
            },
            {
                "mode": "professional",
                "description": "Business and leadership development focus",
                "tone": "Professional and analytical",
                "best_for": "Professional development, business books",
                "question_focus": ["analysis", "discussion", "connection"]
            },
            {
                "mode": "language_learning",
                "description": "ESL and language practice focus",
                "tone": "Instructional with language support",
                "best_for": "Language learners, ESL students",
                "question_focus": ["vocabulary", "comprehension", "discussion"]
            }
        ]
    }


# Book Discovery and File Serving Endpoints
BOOK_FILES_DIR = Path("/app/book_files")

@app.get("/books/list")
def list_available_books():
    """Discover and list all available books from the book_files directory."""
    try:
        single_books = []
        chapter_books = []
        
        if not BOOK_FILES_DIR.exists():
            return {"single_books": [], "chapter_books": []}
        
        for item in BOOK_FILES_DIR.iterdir():
            if item.is_file() and item.suffix.lower() == '.mp3':
                # Single file book
                single_books.append({
                    "name": item.stem,
                    "filename": item.name,
                    "size": item.stat().st_size,
                    "path": str(item)
                })
            elif item.is_dir() and item.name != '__pycache__':
                # Check if directory contains MP3 files
                mp3_files = list(item.glob("*.mp3"))
                if mp3_files:
                    # Multi-chapter book
                    chapter_files = sorted([f.name for f in mp3_files])
                    chapter_books.append({
                        "name": item.name,
                        "chapter_count": len(mp3_files),
                        "chapters": chapter_files,
                        "path": str(item)
                    })
        
        logger.info(f"Discovered {len(single_books)} single books and {len(chapter_books)} chapter books")
        return {
            "single_books": single_books,
            "chapter_books": chapter_books
        }
        
    except Exception as e:
        logger.error(f"Error listing books: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to list books: {str(e)}")


@app.get("/books/play/{book_name}")
async def serve_single_book_audio(book_name: str):
    """Serve audio file for a single book."""
    from fastapi.responses import FileResponse
    
    try:
        # First try as direct file
        audio_file = BOOK_FILES_DIR / f"{book_name}.mp3"
        if audio_file.exists():
            return FileResponse(
                path=str(audio_file),
                media_type="audio/mpeg",
                filename=audio_file.name
            )
        
        # Try finding any MP3 with this name
        for file in BOOK_FILES_DIR.glob("*.mp3"):
            if book_name.lower() in file.stem.lower():
                return FileResponse(
                    path=str(file),
                    media_type="audio/mpeg", 
                    filename=file.name
                )
        
        raise HTTPException(status_code=404, detail="Audio file not found")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error serving audio file {book_name}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to serve audio: {str(e)}")


@app.get("/books/play/{book_name}/{chapter_file}")
async def serve_chapter_audio(book_name: str, chapter_file: str):
    """Serve audio file for a specific chapter."""
    from fastapi.responses import FileResponse
    
    try:
        book_dir = BOOK_FILES_DIR / book_name
        if not book_dir.exists():
            raise HTTPException(status_code=404, detail="Book directory not found")
        
        audio_file = book_dir / chapter_file
        if not audio_file.exists():
            raise HTTPException(status_code=404, detail="Chapter file not found")
        
        return FileResponse(
            path=str(audio_file),
            media_type="audio/mpeg",
            filename=audio_file.name
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error serving chapter audio {book_name}/{chapter_file}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to serve chapter audio: {str(e)}")


@app.post("/detect-chapters")
async def detect_chapters_web_api(request: dict):
    """Web API wrapper for chapter detection that works with book names."""
    try:
        book_name = request.get("book_name")
        chapter_name = request.get("chapter_name")
        
        if not book_name:
            raise HTTPException(status_code=400, detail="book_name is required")
        
        # Build file path
        if chapter_name:
            audio_file_path = str(BOOK_FILES_DIR / book_name / chapter_name)
        else:
            # Find the first MP3 file in the book directory
            book_dir = BOOK_FILES_DIR / book_name
            if book_dir.is_dir():
                mp3_files = list(book_dir.glob("*.mp3"))
                if not mp3_files:
                    raise HTTPException(status_code=404, detail="No MP3 files found in book")
                audio_file_path = str(mp3_files[0])
            else:
                # Try as single file
                audio_file = BOOK_FILES_DIR / f"{book_name}.mp3"
                if not audio_file.exists():
                    raise HTTPException(status_code=404, detail="Book not found")
                audio_file_path = str(audio_file)
        
        # Create detection request
        detection_request = ChapterDetectionRequest(
            audio_file_path=audio_file_path,
            book_title=book_name,
            force_redetect=request.get("force_redetect", False)
        )
        
        return await detect_chapters(detection_request)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in web API chapter detection: {e}")
        raise HTTPException(status_code=500, detail=f"Chapter detection failed: {str(e)}")


@app.post("/summarize-chapter")  
async def summarize_chapter_web_api(request: dict):
    """Web API wrapper for chapter summarization."""
    try:
        book_name = request.get("book_name")
        chapter_id = request.get("chapter_id") 
        style = request.get("style", "detailed")
        
        if not book_name or not chapter_id:
            raise HTTPException(status_code=400, detail="book_name and chapter_id are required")
        
        # Find book path
        book_dir = BOOK_FILES_DIR / book_name
        if book_dir.is_dir():
            mp3_files = list(book_dir.glob("*.mp3"))
            if not mp3_files:
                raise HTTPException(status_code=404, detail="No MP3 files found")
            audio_file_path = str(mp3_files[0])
        else:
            audio_file = BOOK_FILES_DIR / f"{book_name}.mp3"
            if not audio_file.exists():
                raise HTTPException(status_code=404, detail="Book not found")
            audio_file_path = str(audio_file)
        
        # Extract chapter number from chapter_id
        chapter_number = int(chapter_id.split("_")[-1]) if "_" in chapter_id else 1
        
        return await summarize_single_chapter(
            book_title=book_name,
            chapter_number=chapter_number,
            summary_style=style,
            audio_file_path=audio_file_path
        )
        
    except HTTPException:
        raise  
    except Exception as e:
        logger.error(f"Error in web API chapter summarization: {e}")
        raise HTTPException(status_code=500, detail=f"Summarization failed: {str(e)}")


@app.post("/generate-questions")
async def generate_questions_web_api(request: dict):
    """Web API wrapper for question generation."""
    try:
        book_name = request.get("book_name")
        chapter_id = request.get("chapter_id")
        difficulty = request.get("difficulty", "intermediate")
        reading_mode = request.get("reading_mode", "casual")
        num_questions = request.get("num_questions", 5)
        
        if not book_name or not chapter_id:
            raise HTTPException(status_code=400, detail="book_name and chapter_id are required")
        
        # Find book path
        book_dir = BOOK_FILES_DIR / book_name
        if book_dir.is_dir():
            mp3_files = list(book_dir.glob("*.mp3"))
            if not mp3_files:
                raise HTTPException(status_code=404, detail="No MP3 files found")
            audio_file_path = str(mp3_files[0])
        else:
            audio_file = BOOK_FILES_DIR / f"{book_name}.mp3"  
            if not audio_file.exists():
                raise HTTPException(status_code=404, detail="Book not found")
            audio_file_path = str(audio_file)
        
        # Extract chapter number from chapter_id
        chapter_number = int(chapter_id.split("_")[-1]) if "_" in chapter_id else 1
        
        # Create request
        gen_request = QuestionGenerationAPIRequest(
            audio_file_path=audio_file_path,
            book_title=book_name,
            chapter_id=chapter_id,
            chapter_number=chapter_number,
            num_questions=num_questions,
            difficulty=difficulty,
            reading_mode=reading_mode
        )
        
        return await generate_questions_endpoint(gen_request)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in web API question generation: {e}")
        raise HTTPException(status_code=500, detail=f"Question generation failed: {str(e)}")