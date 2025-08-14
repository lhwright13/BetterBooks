"""
API Gateway for EchoWright Audiobook Companion Platform

This service acts as the central entry point for all client applications (mobile app,
web demo) to access the distributed EchoWright backend services. It implements a simple
proxy pattern that forwards requests to appropriate microservices while providing
a unified API interface.

Key responsibilities:
- Centralized API entry point for all client applications
- Request routing and proxying to backend microservices
- CORS handling for web client cross-origin requests
- Audiobook file management and streaming
- Error handling and status code propagation
- Service endpoint abstraction and configuration

Architecture:
- Runs on port 8000 as the main API gateway
- Proxies requests to Context Service (port 8001)
- Proxies requests to LLM Gateway (port 8002) 
- Proxies requests to TTS Service (port 8003)
- Proxies requests to Transcription Service (port 8003)
- Serves audiobook files and cover images directly
- Handles file uploads for book management

Endpoints:
- /health: Service health check
- /complete: AI text completion via LLM Gateway
- /tts: Text-to-speech synthesis via TTS Service
- /configs: List available AI persona configurations
- /context: Retrieve contextual transcript information
- /books/*: Audiobook file management and streaming
- /books/cover/*: Book cover image serving

Service URLs are configurable via environment variables for deployment flexibility.
Book files are served from /app/book_files directory (mounted volume in Docker).
"""

import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Optional

import httpx
from fastapi import FastAPI, HTTPException, File, UploadFile, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from pydantic import BaseModel

# Import core infrastructure components
from core.infrastructure.logging_config import setup_logging, get_request_id
from core.infrastructure.logging_middleware import LoggingMiddleware
from core.infrastructure.health_checks import HealthCheck, create_health_endpoint, check_service_endpoint
from core.infrastructure.compression_middleware import CompressionMiddleware
from core.infrastructure.metrics import (
    setup_metrics, llm_requests_total, llm_request_duration_seconds,
    tts_requests_total, active_users, books_processed_total,
    cache_operations_total, cache_hit_ratio
)
from core.infrastructure.tracing import (
    TracingConfig, setup_tracing, instrument_fastapi, instrument_external_libraries,
    get_development_tracing_config, LLMTracingHelper, HTTPTracingHelper, 
    create_span_with_context, add_span_attributes
)
from core.infrastructure.circuit_breaker import (
    CircuitBreaker, CircuitBreakerError, ExponentialBackoff,
    create_http_circuit_breaker, create_llm_circuit_breaker
)
from core.infrastructure.error_handling import (
    setup_error_handling, ApplicationError, ValidationError,
    ExternalServiceError, TimeoutError, handle_external_service_error
)

# Import authentication components  
from core.auth.auth import User, get_current_user, get_optional_user, require_role, UserRole, check_rate_limit
from core.auth.auth_routes import auth_router

# Base URLs for the other services. These can be overridden via environment
# variables when running inside Docker or a deployment environment.
CONTEXT_URL = os.getenv("CONTEXT_SERVICE_URL", "http://context_service:8000")
LLM_URL = os.getenv("LLM_GATEWAY_URL", "http://llm_gateway:8000")
TTS_URL = os.getenv("TTS_SERVICE_URL", "http://tts_service:8000")
TRANSCRIPTION_URL = os.getenv("TRANSCRIPTION_SERVICE_URL", "http://transcription_service:8000")

# Book files directory - will be mounted in Docker
BOOK_FILES_DIR = Path("/app/book_files")

# Set up structured logging
logger = setup_logging(
    service_name="api_gateway",
    log_level=os.getenv("LOG_LEVEL", "INFO")
)

# Set up distributed tracing
environment = os.getenv("ENVIRONMENT", "development")
if environment == "development":
    tracing_config = get_development_tracing_config("api_gateway")
else:
    from tracing import get_production_tracing_config
    tracing_config = get_production_tracing_config("api_gateway")

tracer = setup_tracing(tracing_config)

# Instrument external libraries for automatic tracing
instrument_external_libraries()

# Initialize circuit breakers for external services
llm_circuit_breaker = create_llm_circuit_breaker(
    name="LLM_Gateway",
    failure_threshold=3,
    recovery_timeout=30
)

tts_circuit_breaker = CircuitBreaker(
    name="TTS_Service",
    failure_threshold=3,
    recovery_timeout=20,
    expected_exception=(httpx.HTTPStatusError, httpx.TimeoutException, ConnectionError)
)

context_circuit_breaker = CircuitBreaker(
    name="Context_Service",
    failure_threshold=5,
    recovery_timeout=15,
    expected_exception=(httpx.HTTPStatusError, httpx.TimeoutException, ConnectionError)
)

transcription_circuit_breaker = CircuitBreaker(
    name="Transcription_Service",
    failure_threshold=3,
    recovery_timeout=30,
    expected_exception=(httpx.HTTPStatusError, httpx.TimeoutException, ConnectionError)
)

# Exponential backoff for retries
retry_backoff = ExponentialBackoff(
    max_retries=3,
    base_delay=1.0,
    max_delay=10.0
)

# Main FastAPI application used by the unit tests and docker-compose setup
app = FastAPI(
    title="EchoWright API Gateway",
    description="Secure API Gateway for EchoWright Audiobook Platform",
    version="1.0.0"
)

# Add logging middleware
app.add_middleware(LoggingMiddleware, logger=logger)

# Add compression middleware  
compression_middleware = CompressionMiddleware(
    app,
    minimum_size=500,  # Compress responses >= 500 bytes
    compression_level=6,  # Balanced compression/speed
    exclude_paths={"/health", "/metrics"}  # Skip compression for monitoring endpoints
)
app.add_middleware(CompressionMiddleware, 
    minimum_size=500,
    compression_level=6, 
    exclude_paths={"/health", "/metrics"}
)

# Set up comprehensive error handling
error_handler = setup_error_handling(
    app,
    service_name="api_gateway",
    include_stack_trace=(os.getenv("ENVIRONMENT", "development") == "development")
)

# Security middleware - restrict hosts in production
if os.getenv("ENVIRONMENT", "development") == "production":
    app.add_middleware(
        TrustedHostMiddleware, 
        allowed_hosts=["api.echowright.com", "localhost"]
    )

# CORS configuration - restrict origins in production
cors_origins = [
    "http://localhost:8080",  # Web demo
    "http://localhost:3000",  # Alternative frontend
]

if os.getenv("ENVIRONMENT", "development") == "development":
    cors_origins.append("*")

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include authentication routes
app.include_router(auth_router)

# Set up comprehensive health checks
health_check = HealthCheck("api_gateway", "1.0.0")

# Add dependency checks
async def check_llm_gateway():
    return await check_service_endpoint(LLM_URL)

async def check_context_service():
    return await check_service_endpoint(CONTEXT_URL)

async def check_tts_service():
    return await check_service_endpoint(TTS_URL)

health_check.add_check("llm_gateway", check_llm_gateway)
health_check.add_check("context_service", check_context_service)
health_check.add_check("tts_service", check_tts_service)

# Create health endpoints
create_health_endpoint(app, health_check)

# Add compression statistics endpoint
@app.get("/compression/stats")
def get_compression_stats():
    """Get compression middleware statistics."""
    return compression_middleware.get_stats()

@app.post("/compression/reset")
def reset_compression_stats():
    """Reset compression statistics."""
    compression_middleware.reset_stats()
    return {"message": "Compression statistics reset"}

# Set up Prometheus metrics
metrics_collector = setup_metrics(app, "api_gateway")

# Instrument FastAPI with distributed tracing
instrument_fastapi(app, "api_gateway")

# Create custom metrics for API Gateway
auth_attempts = metrics_collector.create_counter(
    "auth_attempts_total",
    "Total authentication attempts",
    ["method", "status"]
)

rate_limit_hits = metrics_collector.create_counter(
    "rate_limit_hits_total",
    "Total rate limit hits",
    ["endpoint", "user_type"]
)

class Prompt(BaseModel):
    """Request body for the `/complete` endpoint."""

    prompt: str
    config: str | None = None


class Text(BaseModel):
    """Request body for the `/tts` endpoint."""

    text: str
    config: str | None = None


class ContextRequest(BaseModel):
    """Request body for the `/context` endpoint."""
    
    book_name: str
    chapter_name: str | None = None
    current_position: float



@app.post("/complete")
async def complete(
    prompt: Prompt,
    current_user: Optional[User] = Depends(get_optional_user)
) -> dict:
    """Proxy text completion requests to the LLM Gateway with authentication."""
    
    # Create a custom span for the complete operation
    with tracer.start_as_current_span("api_gateway.complete") as span:
        # Add span attributes for tracing context
        add_span_attributes(
            span,
            user_authenticated=str(current_user is not None),
            prompt_length=len(prompt.prompt),
            config=prompt.config or "default"
        )
        
        # Track request start time for metrics
        import time
        start_time = time.time()
        
        # Rate limiting for authenticated users
        if current_user:
            await check_rate_limit(current_user.id, "complete", limit=100, window=3600)  # 100 per hour
            logger.info("Authenticated user request", user_id=current_user.id, endpoint="complete")
            user_type = "authenticated"
            add_span_attributes(span, user_id=current_user.id, user_role=current_user.role.value)
        else:
            # More restrictive rate limiting for unauthenticated users
            client_ip = "anonymous"  # In production, get real IP
            await check_rate_limit(client_ip, "complete_anon", limit=10, window=3600)  # 10 per hour
            logger.info("Anonymous user request", endpoint="complete")
            user_type = "anonymous"
        
        # Add user context to request if authenticated
        request_data = prompt.model_dump(exclude_none=True)
        if current_user:
            request_data["user_id"] = current_user.id
            request_data["user_role"] = current_user.role.value

        # Create span for HTTP client request to LLM Gateway
        with HTTPTracingHelper.trace_http_client_request(tracer, "POST", f"{LLM_URL}/complete") as http_span:
            try:
                # Use circuit breaker for LLM Gateway call
                async def make_llm_request():
                    resp = httpx.post(f"{LLM_URL}/complete", json=request_data, timeout=60.0)
                    HTTPTracingHelper.add_http_response_attributes(http_span, resp.status_code)
                    resp.raise_for_status()
                    return resp
                
                # Execute with circuit breaker and retry logic
                resp = await retry_backoff.retry(
                    llm_circuit_breaker.call,
                    make_llm_request
                )
                
                # Track successful LLM request
                duration = time.time() - start_time
                llm_requests_total.labels(model="gemini", status="success").inc()
                llm_request_duration_seconds.labels(model="gemini").observe(duration)
                
                # Add success attributes to span
                add_span_attributes(span, status="success", duration_seconds=duration)
                
                return resp.json()
                
            except CircuitBreakerError as e:
                # Circuit breaker is open
                llm_requests_total.labels(model="gemini", status="circuit_open").inc()
                logger.warning(
                    "LLM Gateway circuit breaker open",
                    error=str(e),
                    request_id=get_request_id()
                )
                
                # If circuit breaker has fallback, it will be used
                if hasattr(e, 'fallback_response'):
                    return e.fallback_response
                    
                # Otherwise return service unavailable
                raise HTTPException(
                    status_code=503,
                    detail="LLM service temporarily unavailable. Please try again later."
                )
                
            except (httpx.HTTPStatusError, httpx.TimeoutException) as e:
                # Track failed LLM request
                llm_requests_total.labels(model="gemini", status="error").inc()
                
                if isinstance(e, httpx.HTTPStatusError):
                    # Log the error with structured fields
                    logger.error(
                        "LLM Gateway error",
                        status_code=e.response.status_code,
                        error_detail=e.response.text,
                        request_id=get_request_id()
                    )
                    
                    # Record error in span
                    span.record_exception(e)
                    add_span_attributes(span, status="error", error_code=e.response.status_code)
                    
                    # Bubble up the error from the LLM Gateway
                    detail = e.response.json().get("detail", e.response.text)
                    raise HTTPException(status_code=e.response.status_code, detail=detail)
                else:
                    # Timeout error
                    logger.error(
                        "LLM Gateway timeout",
                        error=str(e),
                        request_id=get_request_id()
                    )
                    raise HTTPException(status_code=504, detail="LLM Gateway request timeout")


@app.post("/tts")
async def tts(
    text: Text,
    current_user: Optional[User] = Depends(get_optional_user)
) -> dict:
    """Proxy text-to-speech synthesis requests to the TTS Service with authentication."""
    
    # Track request start time
    import time
    start_time = time.time()
    
    # Rate limiting for TTS (more expensive operation)
    if current_user:
        await check_rate_limit(current_user.id, "tts", limit=50, window=3600)  # 50 per hour
    else:
        client_ip = "anonymous"
        await check_rate_limit(client_ip, "tts_anon", limit=5, window=3600)  # 5 per hour
    
    # Add user context to request
    request_data = text.model_dump()
    if current_user:
        request_data["user_id"] = current_user.id
        request_data["user_role"] = current_user.role.value
        
    resp = httpx.post(
        f"{TTS_URL}/synthesize",
        json=request_data,
        timeout=30.0,
    )
    try:
        resp.raise_for_status()
        # Track successful TTS request
        duration = time.time() - start_time
        tts_requests_total.labels(voice="default", status="success").inc()
    except httpx.HTTPStatusError as e:
        # Track failed TTS request
        tts_requests_total.labels(voice="default", status="error").inc()
        # Log the error with structured fields
        logger.error(
            "TTS Service error",
            status_code=resp.status_code,
            error_detail=resp.text,
            request_id=get_request_id()
        )
        detail = resp.json().get("detail", resp.text)
        raise HTTPException(status_code=resp.status_code, detail=detail)

    return resp.json()


@app.get("/configs")
def list_configs() -> dict:
    """Return available LLM configuration names."""

    resp = httpx.get(f"{LLM_URL}/configs")
    return resp.json()


@app.get("/circuit-breakers/status")
async def get_circuit_breaker_status(
    current_user: User = Depends(require_role(UserRole.ADMIN))
) -> dict:
    """Get status of all circuit breakers (admin only)."""
    return {
        "circuit_breakers": {
            "llm_gateway": llm_circuit_breaker.get_status(),
            "tts_service": tts_circuit_breaker.get_status(),
            "context_service": context_circuit_breaker.get_status(),
            "transcription_service": transcription_circuit_breaker.get_status()
        },
        "timestamp": datetime.now().isoformat()
    }


@app.post("/circuit-breakers/{service}/reset")
async def reset_circuit_breaker(
    service: str,
    current_user: User = Depends(require_role(UserRole.ADMIN))
) -> dict:
    """Manually reset a circuit breaker (admin only)."""
    breakers = {
        "llm_gateway": llm_circuit_breaker,
        "tts_service": tts_circuit_breaker,
        "context_service": context_circuit_breaker,
        "transcription_service": transcription_circuit_breaker
    }
    
    if service not in breakers:
        raise HTTPException(status_code=404, detail=f"Circuit breaker for service '{service}' not found")
    
    breakers[service].reset()
    logger.info(f"Circuit breaker for {service} manually reset by admin", user_id=current_user.id)
    
    return {
        "message": f"Circuit breaker for {service} has been reset",
        "new_status": breakers[service].get_status()
    }


@app.post("/context/search")
async def search_context(
    query: dict,
    current_user: Optional[User] = Depends(get_optional_user)
) -> dict:
    """Forward vector similarity searches to the Context Service."""

    resp = httpx.post(f"{CONTEXT_URL}/search", json=query)
    return resp.json()


@app.post("/context")
async def get_context(
    request: ContextRequest,
    current_user: Optional[User] = Depends(get_optional_user)
) -> dict:
    """Get contextual transcript around current playback position."""
    resp = httpx.post(
        f"{TRANSCRIPTION_URL}/context", 
        json=request.model_dump(),
        timeout=60.0
    )
    try:
        resp.raise_for_status()
    except httpx.HTTPStatusError as e:
        logger.error(
            "Transcription Service error",
            status_code=resp.status_code,
            error_detail=resp.text,
            request_id=get_request_id()
        )
        detail = resp.json().get("detail", resp.text)
        raise HTTPException(status_code=resp.status_code, detail=detail)
    
    return resp.json()


# ==============================================
# TRANSCRIPTION ENDPOINTS
# ==============================================

class TranscriptionResponse(BaseModel):
    """Response model for transcription results."""
    text: str
    language: str
    service: str
    duration_ms: Optional[int] = None
    segments: Optional[List[str]] = None
    word_timestamps: Optional[List[dict]] = None

class AudioFormat(BaseModel):
    """Audio format specification."""
    sample_rate: int = 16000
    channels: int = 1
    bits_per_sample: int = 16

@app.get("/transcription/health")
async def transcription_health():
    """Check transcription service health."""
    try:
        with transcription_circuit_breaker:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(f"{TRANSCRIPTION_URL}/health")
                resp.raise_for_status()
                return resp.json()
    except CircuitBreakerError:
        raise HTTPException(status_code=503, detail="Transcription service unavailable - circuit breaker open")
    except Exception as e:
        logger.error(f"Transcription health check failed: {e}")
        raise HTTPException(status_code=503, detail="Transcription service unavailable")

@app.get("/transcription/config")
async def transcription_config():
    """Get transcription service configuration."""
    try:
        with transcription_circuit_breaker:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(f"{TRANSCRIPTION_URL}/config")
                resp.raise_for_status()
                return resp.json()
    except CircuitBreakerError:
        raise HTTPException(status_code=503, detail="Transcription service unavailable - circuit breaker open")
    except Exception as e:
        logger.error(f"Failed to get transcription config: {e}")
        raise HTTPException(status_code=503, detail="Transcription service unavailable")

@app.get("/transcription/supported-languages")
async def get_supported_languages():
    """Get list of supported languages for transcription."""
    try:
        with transcription_circuit_breaker:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(f"{TRANSCRIPTION_URL}/supported-languages")
                resp.raise_for_status()
                return resp.json()
    except CircuitBreakerError:
        raise HTTPException(status_code=503, detail="Transcription service unavailable - circuit breaker open")
    except Exception as e:
        logger.error(f"Failed to get supported languages: {e}")
        raise HTTPException(status_code=503, detail="Transcription service unavailable")

@app.post("/transcription/file", response_model=TranscriptionResponse)
async def transcribe_file(
    file: UploadFile = File(..., description="Audio file to transcribe"),
    language: Optional[str] = None,
    current_user: Optional[User] = Depends(get_optional_user)
):
    """Transcribe an uploaded audio file using Azure Speech Service."""
    logger.info(
        "File transcription requested",
        filename=file.filename,
        content_type=file.content_type,
        language=language,
        user_id=current_user.id if current_user else None,
        request_id=get_request_id()
    )
    
    # Validate file type
    allowed_types = [
        "audio/wav", "audio/mpeg", "audio/mp3", "audio/m4a", 
        "audio/ogg", "audio/flac", "audio/aac"
    ]
    
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400, 
            detail=f"Unsupported file type: {file.content_type}. Supported types: {', '.join(allowed_types)}"
        )
    
    try:
        with transcription_circuit_breaker:
            # Prepare files for multipart upload
            files_data = {"file": (file.filename, await file.read(), file.content_type)}
            params = {"language": language} if language else {}
            
            async with httpx.AsyncClient(timeout=300.0) as client:  # 5 minute timeout for file processing
                resp = await client.post(
                    f"{TRANSCRIPTION_URL}/transcribe/file",
                    files=files_data,
                    params=params
                )
                resp.raise_for_status()
                
            result = resp.json()
            logger.info(
                "File transcription completed",
                filename=file.filename,
                text_length=len(result.get("text", "")),
                duration_ms=result.get("duration_ms"),
                service=result.get("service"),
                request_id=get_request_id()
            )
            
            return result
            
    except CircuitBreakerError:
        logger.error("Transcription service circuit breaker open", request_id=get_request_id())
        raise HTTPException(status_code=503, detail="Transcription service temporarily unavailable")
    except httpx.TimeoutException:
        logger.error("Transcription service timeout", filename=file.filename, request_id=get_request_id())
        raise HTTPException(status_code=504, detail="Transcription service timeout - file may be too large")
    except httpx.HTTPStatusError as e:
        logger.error(
            "Transcription service error",
            status_code=e.response.status_code,
            error_detail=e.response.text,
            filename=file.filename,
            request_id=get_request_id()
        )
        detail = e.response.json().get("detail", e.response.text) if e.response.headers.get("content-type", "").startswith("application/json") else e.response.text
        raise HTTPException(status_code=e.response.status_code, detail=detail)
    except Exception as e:
        logger.error(f"Unexpected transcription error: {e}", filename=file.filename, request_id=get_request_id())
        raise HTTPException(status_code=500, detail="Internal transcription service error")

@app.post("/transcription/stream", response_model=TranscriptionResponse)
async def transcribe_stream(
    audio_format: AudioFormat = AudioFormat(),
    language: Optional[str] = None,
    current_user: Optional[User] = Depends(get_optional_user)
):
    """Transcribe audio from a raw stream (for real-time transcription)."""
    logger.info(
        "Stream transcription requested",
        audio_format=audio_format.dict(),
        language=language,
        user_id=current_user.id if current_user else None,
        request_id=get_request_id()
    )
    
    try:
        with transcription_circuit_breaker:
            # This endpoint expects raw audio data in the request body
            # For now, return a placeholder response
            return TranscriptionResponse(
                text="Stream transcription endpoint - implementation pending",
                language=language or "en-US",
                service="azure",
                duration_ms=0
            )
            
    except CircuitBreakerError:
        logger.error("Transcription service circuit breaker open", request_id=get_request_id())
        raise HTTPException(status_code=503, detail="Transcription service temporarily unavailable")
    except Exception as e:
        logger.error(f"Stream transcription error: {e}", request_id=get_request_id())
        raise HTTPException(status_code=500, detail="Stream transcription service error")

@app.post("/transcription/test", response_model=TranscriptionResponse)
async def test_transcription(current_user: Optional[User] = Depends(get_optional_user)):
    """Test transcription service connectivity."""
    try:
        with transcription_circuit_breaker:
            async with httpx.AsyncClient(timeout=30.0) as client:
                resp = await client.post(f"{TRANSCRIPTION_URL}/transcribe/test")
                resp.raise_for_status()
                
            result = resp.json()
            logger.info("Transcription test completed", result=result, request_id=get_request_id())
            return result
            
    except CircuitBreakerError:
        logger.error("Transcription service circuit breaker open", request_id=get_request_id())
        raise HTTPException(status_code=503, detail="Transcription service temporarily unavailable")
    except Exception as e:
        logger.error(f"Transcription test error: {e}", request_id=get_request_id())
        raise HTTPException(status_code=500, detail="Transcription test failed")


# ==============================================
# BOOK MANAGEMENT ENDPOINTS  
# ==============================================

@app.post("/books/upload")
async def upload_book(
    file: UploadFile = File(...),
    current_user: User = Depends(require_role(UserRole.ADMIN))
):
    """Upload a single MP3 audiobook file."""
    if not file.filename.endswith('.mp3'):
        raise HTTPException(status_code=400, detail="Only MP3 files are supported")
    
    # Ensure book files directory exists
    BOOK_FILES_DIR.mkdir(exist_ok=True)
    
    # Save the uploaded file
    file_path = BOOK_FILES_DIR / file.filename
    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)
    
    return {"message": f"Book '{file.filename}' uploaded successfully", "path": str(file_path)}


@app.post("/books/upload-chapters")
async def upload_chapters(
    book_name: str,
    files: List[UploadFile] = File(...),
    current_user: User = Depends(require_role(UserRole.ADMIN))
):
    """Upload multiple MP3 chapter files for a book."""
    # Validate all files are MP3
    for file in files:
        if not file.filename.endswith('.mp3'):
            raise HTTPException(status_code=400, detail=f"File '{file.filename}' is not an MP3")
    
    # Create book directory
    book_dir = BOOK_FILES_DIR / book_name
    book_dir.mkdir(parents=True, exist_ok=True)
    
    # Save all chapter files
    saved_files = []
    for file in files:
        file_path = book_dir / file.filename
        with open(file_path, "wb") as f:
            content = await file.read()
            f.write(content)
        saved_files.append(file.filename)
    
    return {
        "message": f"Book '{book_name}' with {len(files)} chapters uploaded successfully",
        "chapters": saved_files,
        "path": str(book_dir)
    }


@app.get("/books/list")
async def list_books(current_user: Optional[User] = Depends(get_optional_user)):
    """List all available audiobooks (single files and chapter folders)."""
    if not BOOK_FILES_DIR.exists():
        return {"books": [], "chapters": []}
    
    single_books = []
    chapter_books = []
    
    for item in BOOK_FILES_DIR.iterdir():
        if item.is_file() and item.suffix == '.mp3':
            single_books.append({
                "name": item.stem,
                "filename": item.name,
                "type": "single",
                "size": item.stat().st_size
            })
        elif item.is_dir():
            mp3_files = list(item.glob("*.mp3"))
            if mp3_files:
                chapter_books.append({
                    "name": item.name,
                    "type": "chapters",
                    "chapter_count": len(mp3_files),
                    "chapters": [f.name for f in sorted(mp3_files)]
                })
    
    return {"single_books": single_books, "chapter_books": chapter_books}


@app.delete("/books/{book_name}")
def delete_book(
    book_name: str,
    current_user: User = Depends(require_role(UserRole.ADMIN))
):
    """Delete a book (single file or chapter folder)."""
    # Try single file first
    single_file = BOOK_FILES_DIR / f"{book_name}.mp3"
    if single_file.exists():
        single_file.unlink()
        return {"message": f"Single book '{book_name}' deleted successfully"}
    
    # Try chapter folder
    chapter_dir = BOOK_FILES_DIR / book_name
    if chapter_dir.exists() and chapter_dir.is_dir():
        import shutil
        shutil.rmtree(chapter_dir)
        return {"message": f"Chapter book '{book_name}' deleted successfully"}
    
    raise HTTPException(status_code=404, detail="Book not found")


@app.get("/books/play/{filename}")
async def play_single_book(
    filename: str,
    current_user: Optional[User] = Depends(get_optional_user)
):
    """Serve a single MP3 book file."""
    file_path = BOOK_FILES_DIR / filename
    if not file_path.exists() or not file_path.suffix == '.mp3':
        raise HTTPException(status_code=404, detail="Book file not found")
    
    response = FileResponse(
        path=file_path,
        media_type="audio/mpeg",
        filename=filename
    )
    # Add CORS headers for mobile app compatibility
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "*"
    return response


@app.get("/books/play/{book_name}/{chapter_filename}")
async def play_chapter(
    book_name: str,
    chapter_filename: str,
    current_user: Optional[User] = Depends(get_optional_user)
):
    """Serve a chapter MP3 file from a chapter book."""
    file_path = BOOK_FILES_DIR / book_name / chapter_filename
    if not file_path.exists() or not file_path.suffix == '.mp3':
        raise HTTPException(status_code=404, detail="Chapter file not found")
    
    response = FileResponse(
        path=file_path,
        media_type="audio/mpeg",
        filename=chapter_filename
    )
    # Add CORS headers for mobile app compatibility
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "*"
    return response


@app.get("/books/cover/{book_name}")
def get_book_cover(book_name: str):
    """Serve a book cover image."""
    # Direct path to the Gatsby cover
    if book_name == "the Great Gatsby":
        file_path = BOOK_FILES_DIR / "the Great Gatsby" / "GatsbyCover.jpg"
        if file_path.exists():
            response = FileResponse(
                path=file_path,
                media_type="image/jpeg",
                filename="GatsbyCover.jpg"
            )
            # Add CORS headers for mobile app compatibility
            response.headers["Access-Control-Allow-Origin"] = "*"
            response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "*"
            return response
    
    # General logic for other books
    book_dir = BOOK_FILES_DIR / book_name
    if not book_dir.exists():
        raise HTTPException(status_code=404, detail=f"Book directory not found: {book_name}")
    
    # Try common image extensions
    for ext in ['.jpg', '.jpeg', '.png', '.webp']:
        # Try different common cover file names
        for cover_name in ['cover', 'Cover', f'{book_name}Cover', f'{book_name.replace(" ", "")}Cover']:
            file_path = book_dir / f"{cover_name}{ext}"
            if file_path.exists():
                media_type = {
                    '.jpg': 'image/jpeg',
                    '.jpeg': 'image/jpeg', 
                    '.png': 'image/png',
                    '.webp': 'image/webp'
                }.get(ext.lower(), 'image/jpeg')
                
                response = FileResponse(
                    path=file_path,
                    media_type=media_type,
                    filename=f"{cover_name}{ext}"
                )
                # Add CORS headers for mobile app compatibility
                response.headers["Access-Control-Allow-Origin"] = "*"
                response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, OPTIONS"
                response.headers["Access-Control-Allow-Headers"] = "*"
                return response
    
    raise HTTPException(status_code=404, detail="Book cover not found")

