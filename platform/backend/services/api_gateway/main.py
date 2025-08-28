#!/usr/bin/env python3
"""
API Gateway for EchoWright Audiobook Companion Platform

This service acts as the central entry point for all client applications (mobile app,
web demo) to access the distributed EchoWright backend services. It implements a simple
proxy pattern that forwards requests to appropriate microservices while providing
a unified API interface.

Key responsibilities:
- Centralized API entry point for all client applications
- Authentication and user management endpoints
- Request routing and proxying to backend microservices
- CORS handling for web client cross-origin requests
- Audiobook file management and streaming
- Error handling and status code propagation
"""

import os
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Optional

# import httpx  # Disabled until dependencies resolved
from fastapi import FastAPI, HTTPException, File, UploadFile, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response, RedirectResponse
from pydantic import BaseModel

# Import centralized configuration first
from core.shared.utils.config_manager import get_config
app_config = get_config()

# Service URLs from centralized configuration
CONTEXT_URL = app_config.get_service_url("context_service")
LLM_URL = app_config.get_service_url("llm_gateway") 
TTS_URL = app_config.get_service_url("tts_service")
TRANSCRIPTION_URL = app_config.get_service_url("transcription_service")

# Import GraphQL schema - temporarily disabled due to supabase dependency
# from graphql_schema import graphql_router
# from simple_bookstore_routes import router as bookstore_router  # Removed - was demo code
# from bookstore_routes import router as enhanced_bookstore_router  # Disabled - requires httpx
# from user_bookstore_routes import router as user_bookstore_router  # Temporarily disabled - depends on core.auth

# Book files directory - will be mounted in Docker
BOOK_FILES_DIR = Path("/app/book_files")

# Set up logging from centralized configuration
logging_config = app_config.get_logging_config()
log_level = getattr(logging, logging_config.level.upper(), logging.INFO)

if logging_config.format == "json":
    # Use structured JSON logging for production
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'  # Simplified for now
    )
else:
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

logger = logging.getLogger(__name__)
logger.info(f"API Gateway starting with configuration: {app_config.get_config_summary()}")

# Import Azure storage helper (config already imported above)
from azure_storage_helper import AzureStorageHelper
azure_storage = AzureStorageHelper()

# Create FastAPI app
app = FastAPI(
    title="EchoWright API Gateway",
    description="API Gateway for EchoWright audiobook platform with authentication and bookstore",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware with centralized configuration
security_config = app_config.get_security_config()
app.add_middleware(
    CORSMiddleware,
    allow_origins=security_config.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Import and include simple authentication routes
from simple_auth_routes import router as auth_router
app.include_router(auth_router)

# Include GraphQL endpoint - temporarily disabled
# app.include_router(graphql_router, prefix="/graphql")

# Include bookstore routes
# app.include_router(bookstore_router)  # Removed - was demo code
# app.include_router(enhanced_bookstore_router)  # Disabled - requires httpx
# app.include_router(user_bookstore_router)  # Temporarily disabled


# Database-backed user endpoints
from db_utils import get_user_credits as db_get_user_credits, get_user_library as db_get_user_library, get_browse_books as db_get_browse_books, test_database_connection

class CreditBalanceResponse(BaseModel):
    total_credits: int
    used_credits: int
    available_credits: int

class LibraryBook(BaseModel):
    id: str
    title: str
    author: str
    cover_image_url: str
    progress: float = 0.0
    purchased_at: Optional[str] = None

class UserLibraryResponse(BaseModel):
    books: List[LibraryBook]
    total_books: int

class BrowseBook(BaseModel):
    id: str
    title: str
    author: str
    cover_image_url: str
    price_usd: float = 9.99
    credit_price: int = 1
    is_featured: bool = False
    is_bestseller: bool = False
    is_new_release: bool = False

class BrowseResponse(BaseModel):
    books: List[BrowseBook]
    total_books: int
    page: int = 1
    page_size: int = 20

@app.get("/bookstore/user/credits", response_model=CreditBalanceResponse)
async def get_user_credits():
    """Get user credit balance from database"""
    # Using demo user ID for now - in production this would come from auth
    demo_user_id = "550e8400-e29b-41d4-a716-446655440000"
    
    credits_data = db_get_user_credits(demo_user_id)
    return CreditBalanceResponse(**credits_data)

@app.get("/bookstore/user/library", response_model=UserLibraryResponse) 
async def get_user_library():
    """Get user library from database"""
    # Using demo user ID for now - in production this would come from auth  
    demo_user_id = "550e8400-e29b-41d4-a716-446655440000"
    
    library_data = db_get_user_library(demo_user_id)
    
    # Convert to response format
    books = [
        LibraryBook(
            id=str(book['id']),  # Convert UUID to string
            title=book['title'],
            author=book['author'] or 'Unknown Author',
            cover_image_url=book.get('cover_image_url', ''),
            progress=float(book.get('progress', 0.0)),
            purchased_at=book.get('purchased_at').isoformat() if book.get('purchased_at') else None
        )
        for book in library_data['books']
    ]
    
    return UserLibraryResponse(
        books=books,
        total_books=library_data['total_books']
    )

@app.get("/bookstore/browse", response_model=BrowseResponse)
async def browse_books(
    featured: bool = False,
    bestsellers: bool = False,
    new_releases: bool = False,
    page: int = 1,
    limit: int = 20
):
    """Browse books in the bookstore with database-backed data"""
    
    # Calculate offset for pagination
    offset = (page - 1) * limit
    
    # For now, just handle featured filter - can extend for bestsellers/new_releases
    browse_data = db_get_browse_books(limit=limit, offset=offset, featured_only=featured)
    
    # Convert to response format
    books = [
        BrowseBook(
            id=str(book['id']),  # Convert UUID to string
            title=book['title'],
            author=book['author'] or 'Unknown Author',
            cover_image_url=book.get('cover_image_url', ''),
            price_usd=float(book.get('price_usd', 9.99)),
            credit_price=int(book.get('credit_price', 1)),
            is_featured=bool(book.get('is_featured', False)),
            is_bestseller=bool(book.get('is_bestseller', False)),
            is_new_release=bool(book.get('is_new_release', False))
        )
        for book in browse_data['books']
    ]
    
    return BrowseResponse(
        books=books,
        total_books=browse_data['total_books'],
        page=page,
        page_size=limit
    )

@app.get("/database/test")
async def test_database():
    """Test database connection"""
    is_connected = test_database_connection()
    return {
        "database_connected": is_connected,
        "message": "Database is working" if is_connected else "Database connection failed"
    }

# Basic health check
@app.get("/health")
async def health_check():
    """Basic health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "api_gateway",
        "version": "1.0.0"
    }

@app.get("/")
async def root():
    """Root endpoint"""
    return {"message": "EchoWright API Gateway", "status": "running"}

# File serving endpoints
@app.get("/books/{book_folder}/{filename}")
async def serve_book_file(book_folder: str, filename: str):
    """Serve audiobook files from Azure Storage or local fallback"""
    try:
        # Try Azure Storage first
        azure_url = azure_storage.generate_audio_url(book_folder, filename)
        if azure_url:
            logger.info(f"Redirecting to Azure Storage for {book_folder}/{filename}")
            return RedirectResponse(url=azure_url)
        
        # Fallback to local storage
        file_path = BOOK_FILES_DIR / book_folder / filename
        
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="File not found")
        
        # Determine media type based on file extension
        media_type = "audio/mpeg"
        if filename.endswith(".mp3"):
            media_type = "audio/mpeg"
        elif filename.endswith(".wav"):
            media_type = "audio/wav"
        elif filename.endswith(".ogg"):
            media_type = "audio/ogg"
        elif filename.endswith(".m4a"):
            media_type = "audio/mp4"
        
        logger.info(f"Serving from local storage: {book_folder}/{filename}")
        return FileResponse(
            path=file_path,
            media_type=media_type,
            filename=filename
        )
    except Exception as e:
        logger.error(f"Error serving book file {book_folder}/{filename}: {e}")
        raise HTTPException(status_code=500, detail="Error serving file")

@app.get("/books/cover/{book_folder}/{filename}")
async def serve_cover_image(book_folder: str, filename: str):
    """Serve book cover images from Azure Storage or local fallback"""
    try:
        # Try Azure Storage first
        azure_url = azure_storage.generate_cover_url(book_folder, filename)
        if azure_url:
            logger.info(f"Redirecting to Azure Storage for cover {book_folder}/{filename}")
            return RedirectResponse(url=azure_url)
        
        # Fallback to local storage
        file_path = BOOK_FILES_DIR / book_folder / filename
        
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="Cover image not found")
        
        # Determine media type based on file extension
        media_type = "image/jpeg"
        if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.gif')):
            if filename.lower().endswith('.png'):
                media_type = "image/png"
            elif filename.lower().endswith('.gif'):
                media_type = "image/gif"
        
        logger.info(f"Serving cover from local storage: {book_folder}/{filename}")
        return FileResponse(
            path=file_path,
            media_type=media_type,
            filename=filename
        )
    except Exception as e:
        logger.error(f"Error serving cover image {book_folder}/{filename}: {e}")
        raise HTTPException(status_code=500, detail="Error serving cover image")

# Proxy endpoints for other services
class CompletionRequest(BaseModel):
    prompt: str
    config_name: Optional[str] = None
    max_tokens: Optional[int] = None
    temperature: Optional[float] = None
    use_cache: Optional[bool] = True

@app.post("/complete")
async def complete_text(request: CompletionRequest):
    """Proxy text completion requests to LLM Gateway"""
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{LLM_URL}/complete",
                json=request.dict()
            )
            response.raise_for_status()
            return response.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Error completing text: {e}")
        raise HTTPException(status_code=500, detail="Text completion failed")

class TTSRequest(BaseModel):
    text: str
    voice: Optional[str] = None
    speed: Optional[float] = None

@app.post("/tts")
async def text_to_speech(request: TTSRequest):
    """Proxy text-to-speech requests to TTS Service"""
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{TTS_URL}/tts",
                json=request.dict()
            )
            response.raise_for_status()
            
            # Return audio content with appropriate headers
            return Response(
                content=response.content,
                media_type="audio/wav",
                headers={
                    "Content-Disposition": "attachment; filename=tts_output.wav"
                }
            )
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Error generating speech: {e}")
        raise HTTPException(status_code=500, detail="Text-to-speech failed")

@app.get("/configs")
async def list_configs():
    """Proxy request to list available AI persona configurations"""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{LLM_URL}/configs")
            response.raise_for_status()
            return response.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Error listing configs: {e}")
        raise HTTPException(status_code=500, detail="Failed to list configurations")

@app.get("/context")
async def get_context(query: str, book_id: Optional[str] = None):
    """Proxy context retrieval requests to Context Service"""
    try:
        params = {"query": query}
        if book_id:
            params["book_id"] = book_id
            
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(f"{CONTEXT_URL}/search", params=params)
            response.raise_for_status()
            return response.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Error retrieving context: {e}")
        raise HTTPException(status_code=500, detail="Context retrieval failed")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)