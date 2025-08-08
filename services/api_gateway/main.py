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
from pathlib import Path
from typing import List, Optional

import httpx
from fastapi import FastAPI, HTTPException, File, UploadFile, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from pydantic import BaseModel

# Import logging components
from logging_config import setup_logging, get_request_id
from logging_middleware import LoggingMiddleware

# Import health check components
from health_checks import HealthCheck, create_health_endpoint, check_service_endpoint

# Import metrics components
from metrics import (
    setup_metrics, llm_requests_total, llm_request_duration_seconds,
    tts_requests_total, active_users, books_processed_total,
    cache_operations_total, cache_hit_ratio
)

# Import authentication components
from auth import User, get_current_user, get_optional_user, require_role, UserRole, check_rate_limit
from auth_routes import auth_router

# Import distributed tracing components
from tracing import (
    TracingConfig, setup_tracing, instrument_fastapi, instrument_external_libraries,
    get_development_tracing_config, LLMTracingHelper, HTTPTracingHelper, 
    create_span_with_context, add_span_attributes
)

# Base URLs for the other services. These can be overridden via environment
# variables when running inside Docker or a deployment environment.
CONTEXT_URL = os.getenv("CONTEXT_SERVICE_URL", "http://context_service:8000")
LLM_URL = os.getenv("LLM_GATEWAY_URL", "http://llm_gateway:8000")
TTS_URL = os.getenv("TTS_SERVICE_URL", "http://tts_service:8000")
TRANSCRIPTION_URL = os.getenv("TRANSCRIPTION_SERVICE_URL", "http://transcription_service:8003")

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

# Main FastAPI application used by the unit tests and docker-compose setup
app = FastAPI(
    title="EchoWright API Gateway",
    description="Secure API Gateway for EchoWright Audiobook Platform",
    version="1.0.0"
)

# Add logging middleware
app.add_middleware(LoggingMiddleware, logger=logger)

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
            resp = httpx.post(f"{LLM_URL}/complete", json=request_data, timeout=60.0)
            HTTPTracingHelper.add_http_response_attributes(http_span, resp.status_code)
            
            try:
                resp.raise_for_status()
                # Track successful LLM request
                duration = time.time() - start_time
                llm_requests_total.labels(model="gemini", status="success").inc()
                llm_request_duration_seconds.labels(model="gemini").observe(duration)
                
                # Add success attributes to span
                add_span_attributes(span, status="success", duration_seconds=duration)
                
            except httpx.HTTPStatusError as e:
                # Track failed LLM request
                llm_requests_total.labels(model="gemini", status="error").inc()
                # Log the error with structured fields
                logger.error(
                    "LLM Gateway error",
                    status_code=resp.status_code,
                    error_detail=resp.text,
                    request_id=get_request_id()
                )
                
                # Record error in span
                span.record_exception(e)
                add_span_attributes(span, status="error", error_code=resp.status_code)
                
                # Bubble up the error from the LLM Gateway so the client receives a
                # meaningful status code instead of a generic 500 from this service.
                detail = resp.json().get("detail", resp.text)
                raise HTTPException(status_code=resp.status_code, detail=detail)

        return resp.json()


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

