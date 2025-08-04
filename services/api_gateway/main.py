"""
API Gateway for Muuchi Audiobook Companion Platform

This service acts as the central entry point for all client applications (mobile app,
web demo) to access the distributed Muuchi backend services. It implements a simple
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
from typing import List

import httpx
from fastapi import FastAPI, HTTPException, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel

# Base URLs for the other services. These can be overridden via environment
# variables when running inside Docker or a deployment environment.
CONTEXT_URL = os.getenv("CONTEXT_SERVICE_URL", "http://context_service:8000")
LLM_URL = os.getenv("LLM_GATEWAY_URL", "http://llm_gateway:8000")
TTS_URL = os.getenv("TTS_SERVICE_URL", "http://tts_service:8000")
TRANSCRIPTION_URL = os.getenv("TRANSCRIPTION_SERVICE_URL", "http://transcription_service:8003")

# Book files directory - will be mounted in Docker
BOOK_FILES_DIR = Path("/app/book_files")

# Main FastAPI application used by the unit tests and docker-compose setup
app = FastAPI()

# Allow requests from the web demo running on a different port. Without CORS
# the browser would block calls from the 8080 UI to the gateway on 8000.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

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
def complete(prompt: Prompt) -> dict:
    """Proxy text completion requests to the LLM Gateway."""

    resp = httpx.post(f"{LLM_URL}/complete", json=prompt.model_dump(exclude_none=True), timeout=60.0)
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
def tts(text: Text) -> dict:
    """Proxy text-to-speech synthesis requests to the TTS Service."""
    resp = httpx.post(
        f"{TTS_URL}/synthesize",
        json=text.model_dump(),
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
def search_context(query: dict) -> dict:
    """Forward vector similarity searches to the Context Service."""

    resp = httpx.post(f"{CONTEXT_URL}/search", json=query)
    return resp.json()


@app.post("/context")
def get_context(request: ContextRequest) -> dict:
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
async def upload_book(file: UploadFile = File(...)):
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
async def upload_chapters(book_name: str, files: List[UploadFile] = File(...)):
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
def list_books():
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
def delete_book(book_name: str):
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
def play_single_book(filename: str):
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
def play_chapter(book_name: str, chapter_filename: str):
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

