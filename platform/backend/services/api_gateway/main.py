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

import httpx
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
from db_utils import get_user_credits as db_get_user_credits, get_user_library as db_get_user_library, get_browse_books as db_get_browse_books, get_book_details as db_get_book_details, test_database_connection

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
    formatted_price: str = ""
    formatted_duration: str = "Unknown length"
    language: str = "en"
    is_featured: bool = False
    is_bestseller: bool = False
    is_new_release: bool = False
    created_at: str = "2025-01-01T00:00:00Z"
    updated_at: str = "2025-01-01T00:00:00Z"

class BrowseResponse(BaseModel):
    books: List[BrowseBook]
    total_count: int  # Match mobile app expectation
    page: int = 1
    page_size: int = 20
    has_next_page: bool = False

class PurchaseRequest(BaseModel):
    book_id: str
    credits_to_use: int = 1

class PurchaseResponse(BaseModel):
    success: bool
    message: str
    remaining_credits: int

class Chapter(BaseModel):
    id: str
    title: str
    audio_url: str
    chapter_number: int
    duration: Optional[int] = None

class DetailedBook(BaseModel):
    id: str
    title: str
    author: str
    description: Optional[str] = None
    cover_image_url: str
    price_usd: float = 9.99
    credit_price: int = 1
    is_featured: bool = False
    is_bestseller: bool = False
    is_new_release: bool = False
    chapters: List[Chapter] = []
    total_duration: Optional[int] = None

class BookCategory(BaseModel):
    id: str
    name: str
    description: str
    image_url: Optional[str] = None
    display_order: int
    is_active: bool = True
    created_at: str
    updated_at: str

class CategoriesResponse(BaseModel):
    categories: List[BookCategory]

@app.get("/bookstore/user/credits", response_model=CreditBalanceResponse)
async def get_user_credits():
    """Get user credit balance from database"""
    # Using demo user ID for now - in production this would come from auth
    demo_user_id = "550e8400-e29b-41d4-a716-446655440000"
    
    credits_data = db_get_user_credits(demo_user_id)
    
    # Update used credits based on in-memory purchases
    if demo_user_id in purchased_books:
        used_credits = len(purchased_books[demo_user_id])
        total_credits = credits_data.get('total_credits', 5)
        credits_data.update({
            'used_credits': used_credits,
            'available_credits': max(0, total_credits - used_credits)
        })
    
    return CreditBalanceResponse(**credits_data)

@app.get("/bookstore/user/library", response_model=UserLibraryResponse) 
async def get_user_library():
    """Get user library from database"""
    # Using demo user ID for now - in production this would come from auth  
    demo_user_id = "550e8400-e29b-41d4-a716-446655440000"
    
    # First try database
    library_data = db_get_user_library(demo_user_id)
    
    # If database returns empty but user has purchased books in-memory, use those
    if library_data['total_books'] == 0 and demo_user_id in purchased_books:
        # Get book details for purchased books
        browse_data = db_get_browse_books(limit=100, offset=0)
        available_books = {book['id']: book for book in browse_data['books']}
        
        purchased_book_details = []
        for book_id in purchased_books[demo_user_id]:
            if book_id in available_books:
                book_info = available_books[book_id]
                purchased_book_details.append({
                    'id': book_id,
                    'title': book_info['title'],
                    'author': book_info['author'],
                    'cover_image_url': book_info['cover_image_url'],
                    'progress': 0.0,
                    'purchased_at': '2025-01-20T10:00:00Z'
                })
        
        library_data = {
            'books': purchased_book_details,
            'total_books': len(purchased_book_details)
        }
    
    # Convert to response format
    books = [
        LibraryBook(
            id=str(book['id']),  # Convert UUID to string
            title=book['title'],
            author=book['author'] or 'Unknown Author',
            cover_image_url=book.get('cover_image_url', ''),
            progress=float(book.get('progress', 0.0)),
            purchased_at=book.get('purchased_at') if isinstance(book.get('purchased_at'), str) else None
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
            formatted_price=f"${float(book.get('price_usd', 9.99)):.2f}",
            formatted_duration="Unknown length",
            language="en",
            is_featured=bool(book.get('is_featured', False)),
            is_bestseller=bool(book.get('is_bestseller', False)),
            is_new_release=bool(book.get('is_new_release', False)),
            created_at="2025-01-01T00:00:00Z",
            updated_at="2025-01-01T00:00:00Z"
        )
        for book in browse_data['books']
    ]
    
    return BrowseResponse(
        books=books,
        total_count=browse_data['total_books'],  # Map total_books to total_count
        page=page,
        page_size=limit,
        has_next_page=(page * limit) < browse_data['total_books']
    )

@app.get("/bookstore/categories", response_model=CategoriesResponse)
async def get_book_categories():
    """Get book categories for bookstore browsing"""
    # Return hardcoded categories for now - in production this would come from database
    categories = [
        BookCategory(
            id="classics",
            name="Classics",
            description="Timeless literary works that have shaped culture and thought",
            image_url=None,
            display_order=1,
            is_active=True,
            created_at="2025-01-01T00:00:00Z",
            updated_at="2025-01-01T00:00:00Z"
        ),
        BookCategory(
            id="fiction",
            name="Fiction",
            description="Imaginative literature that tells compelling stories",
            image_url=None,
            display_order=2,
            is_active=True,
            created_at="2025-01-01T00:00:00Z",
            updated_at="2025-01-01T00:00:00Z"
        ),
        BookCategory(
            id="adventure",
            name="Adventure",
            description="Thrilling tales of exploration, danger, and discovery",
            image_url=None,
            display_order=3,
            is_active=True,
            created_at="2025-01-01T00:00:00Z",
            updated_at="2025-01-01T00:00:00Z"
        )
    ]
    
    return CategoriesResponse(categories=categories)

@app.get("/bookstore/books/{book_id}", response_model=DetailedBook)
async def get_book_details(book_id: str):
    """Get detailed book information including chapters"""
    try:
        book_data = db_get_book_details(book_id)
        if not book_data:
            raise HTTPException(status_code=404, detail="Book not found")
        
        # Convert chapters data to Chapter objects
        chapters = []
        if book_data.get('chapters'):
            for chapter_data in book_data['chapters']:
                chapters.append(Chapter(
                    id=chapter_data['id'],
                    title=chapter_data['title'],
                    audio_url=chapter_data['audio_url'],
                    chapter_number=chapter_data['chapter_number'],
                    duration=chapter_data.get('duration')
                ))
        
        return DetailedBook(
            id=book_data['id'],
            title=book_data['title'],
            author=book_data['author'],
            description=book_data.get('description'),
            cover_image_url=book_data['cover_image_url'],
            price_usd=float(book_data.get('price_usd', 9.99)),
            credit_price=int(book_data.get('credit_price', 1)),
            is_featured=bool(book_data.get('is_featured', False)),
            is_bestseller=bool(book_data.get('is_bestseller', False)),
            is_new_release=bool(book_data.get('is_new_release', False)),
            chapters=chapters,
            total_duration=book_data.get('total_duration')
        )
    except Exception as e:
        logger.error(f"Error getting book details for {book_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

# In-memory purchase tracking (for MVP without database)
purchased_books = {}  # user_id -> [book_ids]

@app.post("/bookstore/purchase", response_model=PurchaseResponse)
async def purchase_book(request: PurchaseRequest):
    """Purchase a book using credits"""
    try:
        # Using demo user ID for now - in production this would come from auth
        demo_user_id = "550e8400-e29b-41d4-a716-446655440000"
        
        # Get current credits
        credits_data = db_get_user_credits(demo_user_id)
        available_credits = credits_data.get('available_credits', 5)
        
        # Check if user has enough credits
        if available_credits < request.credits_to_use:
            return PurchaseResponse(
                success=False,
                message="Insufficient credits",
                remaining_credits=available_credits
            )
        
        # Check if book exists (from browse books)
        browse_data = db_get_browse_books(limit=100, offset=0)
        available_books = {book['id']: book for book in browse_data['books']}
        
        if request.book_id not in available_books:
            return PurchaseResponse(
                success=False,
                message="Book not found",
                remaining_credits=available_credits
            )
        
        # Add book to user's purchased books (in-memory for MVP)
        if demo_user_id not in purchased_books:
            purchased_books[demo_user_id] = []
        
        if request.book_id not in purchased_books[demo_user_id]:
            purchased_books[demo_user_id].append(request.book_id)
            remaining_credits = available_credits - request.credits_to_use
            
            logger.info(f"Book {request.book_id} purchased by user {demo_user_id}")
            
            return PurchaseResponse(
                success=True,
                message=f"Successfully purchased {available_books[request.book_id]['title']}",
                remaining_credits=remaining_credits
            )
        else:
            return PurchaseResponse(
                success=False,
                message="Book already owned",
                remaining_credits=available_credits
            )
            
    except Exception as e:
        logger.error(f"Error purchasing book {request.book_id}: {e}")
        raise HTTPException(status_code=500, detail="Purchase failed")

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
    except Exception as llm_error:
        logger.warning(f"LLM service unavailable, providing fallback response: {llm_error}")
        
        # Provide a persona-appropriate fallback response
        persona = getattr(request, 'config', None) or 'default'
        fallback_responses = {
            'Nick Carraway': "I'm afraid I'm having some difficulty connecting to my usual thoughts just now. Perhaps we could try this conversation again in a moment? The green light seems dimmer than usual tonight.",
            'English Teacher': "I apologize, but I'm experiencing some technical difficulties at the moment. Could you please repeat your question? I'd be happy to help you analyze this text once my connection is restored.",
            'Language Tutor': "Pardon me, I seem to be having connection issues. Could you try asking your question again? I'm here to help you learn!",
            'Omniscient Helper': "I'm experiencing some temporary difficulties accessing my full knowledge. Please try your question again in a moment."
        }
        
        fallback_text = fallback_responses.get(persona, "I'm having some technical difficulties. Please try your question again.")
        
        return {
            "text": fallback_text,
            "model": "fallback",
            "usage": {"prompt_tokens": len(request.prompt.split()), "completion_tokens": len(fallback_text.split())},
            "fallback": True
        }

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
        # Try to proxy to LLM service first
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{LLM_URL}/configs")
            response.raise_for_status()
            return response.json()
    except Exception as llm_error:
        logger.warning(f"LLM service unavailable, falling back to local configs: {llm_error}")
        
        # Fallback: serve persona configurations directly from JSON files
        try:
            import json
            config_dir = Path("/app/llm_configs")
            if not config_dir.exists():
                # Try repository structure
                repo_root = Path(__file__).resolve().parents[3]
                config_dir = repo_root / "config" / "production" / "llm_configs"
            
            personas = []
            if config_dir.exists():
                for config_file in config_dir.glob("*.json"):
                    try:
                        with open(config_file, 'r') as f:
                            config_data = json.load(f)
                            persona_name = config_file.stem
                            personas.append({
                                "name": persona_name,
                                "display_name": persona_name,
                                "description": _extract_description_from_preprompt(config_data.get("base_preprompt", "")),
                                "voice": config_data.get("tts_config", {}).get("voice", {}).get("name", "en-US-Neural2-C"),
                                "voice_config": config_data.get("tts_config", {})
                            })
                    except Exception as e:
                        logger.warning(f"Failed to load config {config_file}: {e}")
                        continue
            
            return {"configs": personas}
            
        except Exception as fallback_error:
            logger.error(f"Fallback config loading failed: {fallback_error}")
            raise HTTPException(status_code=500, detail="Failed to list configurations")

def _extract_description_from_preprompt(preprompt: str) -> str:
    """Extract a short description from the base preprompt"""
    if not preprompt:
        return "AI Assistant"
    
    # Extract first sentence or first 100 characters
    sentences = preprompt.split('.')
    if sentences:
        desc = sentences[0].strip()
        if len(desc) > 100:
            desc = desc[:97] + "..."
        return desc
    return "AI Assistant"

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