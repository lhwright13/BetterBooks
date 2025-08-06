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
from pathlib import Path
from typing import List, Optional

import httpx
from fastapi import FastAPI, HTTPException, File, UploadFile, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from pydantic import BaseModel

# Import authentication components
from auth import User, get_current_user, get_optional_user, require_role, UserRole, check_rate_limit
from auth_routes import auth_router

# Base URLs for the other services. These can be overridden via environment
# variables when running inside Docker or a deployment environment.
CONTEXT_URL = os.getenv("CONTEXT_SERVICE_URL", "http://context_service:8000")
LLM_URL = os.getenv("LLM_GATEWAY_URL", "http://llm_gateway:8000")
TTS_URL = os.getenv("TTS_SERVICE_URL", "http://tts_service:8000")
TRANSCRIPTION_URL = os.getenv("TRANSCRIPTION_SERVICE_URL", "http://transcription_service:8003")

# Book files directory - will be mounted in Docker
BOOK_FILES_DIR = Path("/app/book_files")

# Main FastAPI application used by the unit tests and docker-compose setup
app = FastAPI(
    title="EchoWright API Gateway",
    description="Secure API Gateway for EchoWright Audiobook Platform",
    version="1.0.0"
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

@app.get("/health")
def health() -> dict:
    """Simple liveness probe used by tests and Kubernetes."""
    return {"status": "ok"}

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


import logging

# Create a logger
logger = logging.getLogger(__name__)

@app.post("/complete")
async def complete(
    prompt: Prompt,
    current_user: Optional[User] = Depends(get_optional_user)
) -> dict:
    """Proxy text completion requests to the LLM Gateway with authentication."""
    
    # Rate limiting for authenticated users
    if current_user:
        await check_rate_limit(current_user.id, "complete", limit=100, window=3600)  # 100 per hour
    else:
        # More restrictive rate limiting for unauthenticated users
        client_ip = "anonymous"  # In production, get real IP
        await check_rate_limit(client_ip, "complete_anon", limit=10, window=3600)  # 10 per hour
    
    # Add user context to request if authenticated
    request_data = prompt.model_dump(exclude_none=True)
    if current_user:
        request_data["user_id"] = current_user.id
        request_data["user_role"] = current_user.role.value

    resp = httpx.post(f"{LLM_URL}/complete", json=request_data, timeout=60.0)
    try:
        resp.raise_for_status()
    except httpx.HTTPStatusError as e:
        # Log the error
        logger.error(f"LLM Gateway returned an error: {e}")
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
    except httpx.HTTPStatusError as e:
        # Log the error
        logger.error(f"TTS Service returned an error: {e}")
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
        logger.error(f"Transcription Service returned an error: {e}")
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

