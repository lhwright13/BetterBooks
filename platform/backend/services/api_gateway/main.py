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
import asyncio
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

def _format_datetime(dt):
    """Helper function to safely format datetime objects"""
    if dt is None:
        return None
    if isinstance(dt, str):
        return dt
    if hasattr(dt, 'isoformat'):
        return dt.isoformat()
    return str(dt)

def _generate_sample_audio_url_for_title(book_title: str) -> Optional[str]:
    """Generate sample audio URL based on book title for iOS compatibility - returns full Azure URL"""
    # Map book titles to first audio file names
    audio_files = {
        "Alice's Adventures in Wonderland": "alices_adventures_01_carroll_64kb.mp3",
        "Moby Dick": "mobydick_001_002_melville_64kb.mp3", 
        "The Great Gatsby": "gatsby_chapter_01.mp3",
        "War and Peace": "warandpeace_001_tolstoy_64kb.mp3"
    }
    
    # Get first audio file for this book
    filename = audio_files.get(book_title, "")
    if filename:
        # Try to generate Azure storage URL first
        azure_url = azure_storage.generate_audio_url(book_title, filename)
        if azure_url:
            return azure_url
        # Fallback to API endpoint that redirects to Azure
        return f"/books/{book_title}/{filename}"
    
    return None

def _get_book_duration_for_title(book_title: str) -> Optional[int]:
    """Get estimated book duration in seconds for iOS compatibility"""
    # Approximate durations based on typical audiobook lengths
    durations = {
        "Alice's Adventures in Wonderland": 4800,  # ~1.3 hours
        "Moby Dick": 86400,  # ~24 hours
        "The Great Gatsby": 18000,  # ~5 hours  
        "War and Peace": 216000  # ~60 hours
    }
    
    return durations.get(book_title, 3600)  # Default 1 hour

# Create FastAPI app
app = FastAPI(
    title="EchoWright API Gateway",
    description="API Gateway for EchoWright audiobook platform with authentication and bookstore",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Startup validation
@app.on_event("startup")
async def startup_validation():
    """Run startup validation checks"""
    try:
        from startup_check import StartupValidator
        validator = StartupValidator()
        passed, results = await validator.run_all_validations()
        
        if not passed:
            logger.error("🛑 API Gateway startup validation failed - some critical checks failed")
            # Don't exit in production, just log warnings
            if app_config.is_development():
                logger.error("Continuing startup in development mode despite validation failures")
        else:
            logger.info("🎉 API Gateway startup validation completed successfully")
            
    except Exception as e:
        logger.warning(f"Startup validation encountered an error: {e}")
        logger.warning("Continuing startup without validation checks")

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
from db_utils import (
    get_user_credits as db_get_user_credits, 
    get_user_library as db_get_user_library, 
    get_browse_books as db_get_browse_books, 
    get_book_details as db_get_book_details, 
    test_database_connection,
    create_purchase,
    check_user_owns_book,
    get_book_personas,
    get_persona_details,
    get_all_personas,
    create_persona,
    update_persona,
    delete_persona,
    add_persona_to_book,
    remove_persona_from_book,
    add_to_user_wishlist,
    remove_from_user_wishlist,
    get_user_wishlist,
    get_categories as db_get_categories
)
from azure_storage_helper import AzureStorageHelper
from user_context import get_current_user_id, require_authenticated_user

# Initialize Azure Storage helper
azure_storage = AzureStorageHelper()

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
    sample_audio_url: Optional[str] = None
    duration_seconds: Optional[int] = None

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

class DownloadFile(BaseModel):
    file_path: str
    download_url: str
    chapter_id: str
    chapter_title: str
    duration: Optional[int] = None

class BookDownloadResponse(BaseModel):
    book_id: str
    book_title: str
    files: List[DownloadFile]
    expires_at: str

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

# Persona-related models
class Persona(BaseModel):
    id: str
    name: str
    display_name: str
    description: str
    base_prompt: str
    voice_config: dict = {}
    generation_config: dict = {}
    tts_config: dict = {}
    is_global: bool = False
    created_at: str
    updated_at: str

class BookPersona(BaseModel):
    id: str
    persona_id: str
    persona_name: str
    persona_display_name: str
    persona_description: str
    is_default: bool = False
    custom_prompt: Optional[str] = None
    sort_order: int = 0

class PersonaResponse(BaseModel):
    persona: Persona

class BookPersonasResponse(BaseModel):
    personas: List[BookPersona]
    book_id: str
    book_title: str

@app.get("/bookstore/user/credits", response_model=CreditBalanceResponse)
async def get_user_credits(user_id: str = Depends(get_current_user_id)):
    """Get user credit balance from database"""
    try:
        credits_data = db_get_user_credits(user_id)
        
        if credits_data:
            return CreditBalanceResponse(**credits_data)
        else:
            logger.warning(f"No credit data found for user {user_id}, using defaults")
            return CreditBalanceResponse(
                total_credits=5,
                used_credits=0,
                available_credits=5
            )
    except Exception as e:
        logger.error(f"Error getting user credits: {e}")
        # Fallback response if database is unavailable
        return CreditBalanceResponse(
            total_credits=5,
            used_credits=0,
            available_credits=5
        )

@app.get("/bookstore/user/library", response_model=UserLibraryResponse) 
async def get_user_library(user_id: str = Depends(get_current_user_id)):
    """Get user library from database"""
    try:
        library_data = db_get_user_library(user_id)
        
        # Convert to response format
        books = [
            LibraryBook(
                id=str(book['id']),  # Convert UUID to string
                title=book['title'],
                author=book['author'] or 'Unknown Author',
                cover_image_url=book.get('cover_image_url', ''),
                progress=float(book.get('progress', 0.0)),
                purchased_at=_format_datetime(book.get('purchased_at')),
                sample_audio_url=_generate_sample_audio_url_for_title(book['title']),
                duration_seconds=_get_book_duration_for_title(book['title'])
            )
            for book in library_data['books']
        ]
        
        return UserLibraryResponse(
            books=books,
            total_books=library_data['total_books']
        )
    except Exception as e:
        logger.error(f"Error getting user library: {e}")
        # Return empty library on error
        return UserLibraryResponse(books=[], total_books=0)

@app.get("/bookstore/browse", response_model=BrowseResponse)
async def browse_books(
    featured: bool = False,
    bestsellers: bool = False,
    new_releases: bool = False,
    page: int = 1,
    limit: int = 20
):
    """Browse books in the bookstore with database-backed data"""
    try:
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
    except Exception as e:
        logger.error(f"Error browsing books: {e}")
        # Return empty results on error
        return BrowseResponse(
            books=[],
            total_count=0,
            page=page,
            page_size=limit,
            has_next_page=False
        )

@app.get("/bookstore/search", response_model=BrowseResponse)
async def search_books(
    q: str,
    page: int = 1,
    limit: int = 20
):
    """Search for books in the catalog by title, author, or keywords"""
    try:
        # Calculate offset for pagination
        offset = (page - 1) * limit
        
        # Use existing browse logic with search filter
        from db_utils import search_books as db_search_books
        search_data = db_search_books(query=q, limit=limit, offset=offset)
        
        # Convert to response format (same as browse)
        books = [
            BrowseBook(
                id=str(book['id']),
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
            for book in search_data['books']
        ]
        
        return BrowseResponse(
            books=books,
            total_count=search_data['total_books'],
            page=page,
            page_size=limit,
            has_next_page=(page * limit) < search_data['total_books']
        )
    except Exception as e:
        logger.error(f"Error searching books: {e}")
        # Return empty results on error
        return BrowseResponse(
            books=[],
            total_count=0,
            page=page,
            page_size=limit,
            has_next_page=False
        )

@app.get("/bookstore/featured", response_model=BrowseResponse)
async def get_featured_books(limit: int = 10):
    """Get a curated list of featured audiobooks"""
    try:
        # Use existing browse logic with featured filter
        browse_data = db_get_browse_books(limit=limit, offset=0, featured_only=True)
        
        # Convert to response format
        books = [
            BrowseBook(
                id=str(book['id']),
                title=book['title'],
                author=book['author'] or 'Unknown Author',
                cover_image_url=book.get('cover_image_url', ''),
                price_usd=float(book.get('price_usd', 9.99)),
                credit_price=int(book.get('credit_price', 1)),
                formatted_price=f"${float(book.get('price_usd', 9.99)):.2f}",
                formatted_duration="Unknown length",
                language="en",
                is_featured=True,  # All results are featured
                is_bestseller=bool(book.get('is_bestseller', False)),
                is_new_release=bool(book.get('is_new_release', False)),
                created_at="2025-01-01T00:00:00Z",
                updated_at="2025-01-01T00:00:00Z"
            )
            for book in browse_data['books']
        ]
        
        return BrowseResponse(
            books=books,
            total_count=browse_data['total_books'],
            page=1,
            page_size=limit,
            has_next_page=False
        )
    except Exception as e:
        logger.error(f"Error getting featured books: {e}")
        return BrowseResponse(
            books=[],
            total_count=0,
            page=1,
            page_size=limit,
            has_next_page=False
        )

@app.get("/bookstore/bestsellers", response_model=BrowseResponse)
async def get_bestselling_books(limit: int = 10):
    """Get the most popular audiobooks"""
    try:
        # Use existing browse logic with bestseller filter
        from db_utils import get_bestselling_books as db_get_bestselling_books
        browse_data = db_get_bestselling_books(limit=limit, offset=0)
        
        # Convert to response format
        books = [
            BrowseBook(
                id=str(book['id']),
                title=book['title'],
                author=book['author'] or 'Unknown Author',
                cover_image_url=book.get('cover_image_url', ''),
                price_usd=float(book.get('price_usd', 9.99)),
                credit_price=int(book.get('credit_price', 1)),
                formatted_price=f"${float(book.get('price_usd', 9.99)):.2f}",
                formatted_duration="Unknown length",
                language="en",
                is_featured=bool(book.get('is_featured', False)),
                is_bestseller=True,  # All results are bestsellers
                is_new_release=bool(book.get('is_new_release', False)),
                created_at="2025-01-01T00:00:00Z",
                updated_at="2025-01-01T00:00:00Z"
            )
            for book in browse_data['books']
        ]
        
        return BrowseResponse(
            books=books,
            total_count=browse_data['total_books'],
            page=1,
            page_size=limit,
            has_next_page=False
        )
    except Exception as e:
        logger.error(f"Error getting bestselling books: {e}")
        return BrowseResponse(
            books=[],
            total_count=0,
            page=1,
            page_size=limit,
            has_next_page=False
        )

@app.post("/bookstore/user/initialize-credits", response_model=CreditBalanceResponse)
async def initialize_user_credits(
    initial_credits: int = 5,
    user_id: str = Depends(get_current_user_id)
):
    """Initialize credits for a new user"""
    try:
        from db_utils import initialize_user_credits as db_initialize_credits
        
        # Check if user already has credits initialized
        existing_credits = db_get_user_credits(user_id)
        if existing_credits:
            raise HTTPException(
                status_code=400,
                detail="User already has credits initialized"
            )
        
        # Initialize credits
        credits_data = db_initialize_credits(user_id, initial_credits)
        
        return CreditBalanceResponse(
            total_credits=credits_data['total_credits'],
            used_credits=credits_data['used_credits'],
            available_credits=credits_data['available_credits']
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error initializing credits for user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to initialize credits")

@app.get("/bookstore/test")
async def test_bookstore_endpoints():
    """Test endpoint for debugging bookstore functionality"""
    try:
        # Test database connection
        from db_utils import get_db_connection
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) as book_count FROM books")
                book_count = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) as user_count FROM users")  
                user_count = cursor.fetchone()[0]
                
                cursor.execute("SELECT COUNT(*) as persona_count FROM personas")
                persona_count = cursor.fetchone()[0]
        
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "database": {
                "connected": True,
                "books": book_count,
                "users": user_count, 
                "personas": persona_count
            },
            "services": {
                "llm_gateway": LLM_URL,
                "context_service": CONTEXT_URL,
                "tts_service": TTS_URL
            },
            "version": "1.0.0"
        }
        
    except Exception as e:
        logger.error(f"Test endpoint error: {e}")
        return {
            "status": "error",
            "timestamp": datetime.now().isoformat(),
            "error": str(e),
            "database": {"connected": False},
            "version": "1.0.0"
        }

@app.get("/books")
async def list_all_books(limit: int = 50, offset: int = 0):
    """Simple book list endpoint - returns basic book information"""
    try:
        from db_utils import get_all_books
        books_data = get_all_books(limit=limit, offset=offset)
        
        # Convert to simple format
        books = [
            {
                "id": str(book['id']),
                "title": book['title'],
                "author": book['author'] or 'Unknown Author',
                "cover_image_url": book.get('cover_image_url', ''),
                "created_at": book.get('created_at', '').isoformat() if book.get('created_at') else None,
            }
            for book in books_data['books']
        ]
        
        return {
            "books": books,
            "total": books_data.get('total_books', len(books)),
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        logger.error(f"Error listing books: {e}")
        return {"books": [], "total": 0, "limit": limit, "offset": offset}

@app.get("/bookstore/categories", response_model=CategoriesResponse)
async def get_book_categories():
    """Get book categories for bookstore browsing"""
    try:
        # Get categories from database
        categories_data = db_get_categories()
        
        # Convert to response format
        categories = [
            BookCategory(
                id=str(category['id']),
                name=category['name'],
                description=category.get('description', ''),
                image_url=category.get('image_url'),
                display_order=category.get('display_order', 0),
                is_active=category.get('is_active', True),
                created_at=category.get('created_at', '2025-01-01T00:00:00Z'),
                updated_at=category.get('updated_at', '2025-01-01T00:00:00Z')
            )
            for category in categories_data['categories']
        ]
        
        return CategoriesResponse(categories=categories)
        
    except Exception as e:
        logger.error(f"Error getting categories: {e}")
        # Return fallback hardcoded categories on error
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

@app.post("/bookstore/purchase", response_model=PurchaseResponse)
async def purchase_book(request: PurchaseRequest, user_id: str = Depends(get_current_user_id)):
    """Purchase a book using credits with database persistence"""
    try:
        # Check if user already owns the book
        if check_user_owns_book(user_id, request.book_id):
            credits_data = db_get_user_credits(user_id)
            return PurchaseResponse(
                success=False,
                message="Book already owned",
                remaining_credits=credits_data.get('available_credits', 0) if credits_data else 0
            )
        
        # Get current credits before purchase
        credits_data = db_get_user_credits(user_id)
        if not credits_data:
            return PurchaseResponse(
                success=False,
                message="Unable to retrieve credit balance",
                remaining_credits=0
            )
        
        available_credits = credits_data.get('available_credits', 0)
        
        # Check if user has enough credits
        if available_credits < request.credits_to_use:
            return PurchaseResponse(
                success=False,
                message="Insufficient credits",
                remaining_credits=available_credits
            )
        
        # Attempt to create the purchase in database
        purchase_success = create_purchase(
            user_id=user_id,
            book_id=request.book_id,
            credits_used=request.credits_to_use,
            purchase_type="credit"
        )
        
        if purchase_success:
            # Get book title for response
            book_details = db_get_book_details(request.book_id)
            book_title = book_details['title'] if book_details else "Unknown Book"
            
            # Get updated credit balance
            updated_credits = db_get_user_credits(user_id)
            remaining_credits = updated_credits.get('available_credits', 0) if updated_credits else 0
            
            logger.info(f"Book {request.book_id} purchased by user {user_id}")
            
            return PurchaseResponse(
                success=True,
                message=f"Successfully purchased {book_title}",
                remaining_credits=remaining_credits
            )
        else:
            return PurchaseResponse(
                success=False,
                message="Purchase failed - please try again",
                remaining_credits=available_credits
            )
            
    except Exception as e:
        logger.error(f"Error purchasing book {request.book_id}: {e}")
        raise HTTPException(status_code=500, detail="Purchase failed")

# Persona endpoints
@app.get("/bookstore/books/{book_id}/personas", response_model=BookPersonasResponse)
async def get_book_personas_endpoint(book_id: str):
    """Get all personas available for a specific book"""
    try:
        personas_data = get_book_personas(book_id)
        if not personas_data:
            raise HTTPException(status_code=404, detail="Book not found")
        
        personas = [
            BookPersona(
                id=str(persona['id']),
                persona_id=str(persona['persona_id']),
                persona_name=persona['persona_name'],
                persona_display_name=persona['persona_display_name'],
                persona_description=persona['persona_description'],
                is_default=persona['is_default'],
                custom_prompt=persona.get('custom_prompt'),
                sort_order=persona['sort_order']
            )
            for persona in personas_data['personas']
        ]
        
        return BookPersonasResponse(
            personas=personas,
            book_id=personas_data['book_id'],
            book_title=personas_data['book_title']
        )
    except Exception as e:
        logger.error(f"Error getting personas for book {book_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get book personas")

@app.get("/personas/{persona_id}", response_model=PersonaResponse)
async def get_persona_endpoint(persona_id: str):
    """Get detailed information about a specific persona"""
    try:
        persona_data = get_persona_details(persona_id)
        if not persona_data:
            raise HTTPException(status_code=404, detail="Persona not found")
        
        persona = Persona(
            id=str(persona_data['id']),
            name=persona_data['name'],
            display_name=persona_data['display_name'],
            description=persona_data.get('description', ''),
            base_prompt=persona_data['base_prompt'],
            voice_config=persona_data.get('voice_config', {}),
            generation_config=persona_data.get('generation_config', {}),
            tts_config=persona_data.get('tts_config', {}),
            is_global=persona_data['is_global'],
            created_at=_format_datetime(persona_data['created_at']),
            updated_at=_format_datetime(persona_data['updated_at'])
        )
        
        return PersonaResponse(persona=persona)
    except Exception as e:
        logger.error(f"Error getting persona {persona_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get persona details")

@app.get("/personas")
async def list_personas_endpoint():
    """List all available personas"""
    try:
        personas_data = get_all_personas()
        
        personas = [
            {
                "id": str(persona['id']),
                "name": persona['name'],
                "display_name": persona['display_name'],
                "description": persona.get('description', ''),
                "is_global": persona['is_global'],
                "created_at": _format_datetime(persona['created_at']),
                "updated_at": _format_datetime(persona['updated_at'])
            }
            for persona in personas_data
        ]
        
        return {"personas": personas}
    except Exception as e:
        logger.error(f"Error listing personas: {e}")
        raise HTTPException(status_code=500, detail="Failed to list personas")

@app.get("/bookstore/books/{book_id}/download", response_model=BookDownloadResponse)
async def get_book_download_links(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Get download links for all chapters of a purchased book"""
    try:
        # Verify user owns this book
        user_owns_book = check_user_owns_book(user_id, book_id)
        if not user_owns_book:
            raise HTTPException(status_code=403, detail="Book not purchased by user")
        
        # Get book details with chapters
        book_data = db_get_book_details(book_id)
        if not book_data:
            raise HTTPException(status_code=404, detail="Book not found")
            
        # Extract file paths for download URL generation
        file_paths = []
        chapter_info = {}
        
        for chapter in book_data.get('chapters', []):
            if chapter.get('file_path'):
                file_path = chapter['file_path']
                file_paths.append(file_path)
                chapter_info[file_path] = {
                    'id': chapter['id'],
                    'title': chapter['title'],
                    'duration': chapter.get('duration')
                }
        
        if not file_paths:
            raise HTTPException(status_code=404, detail="No audio files found for this book")
        
        # Generate download URLs with 24-hour expiry
        download_urls = azure_storage.generate_download_urls(file_paths, expiry_hours=24)
        
        if not download_urls:
            # Fallback to local file URLs if Azure not available
            download_urls = {fp: f"/books/{fp}" for fp in file_paths}
        
        # Build response
        download_files = []
        for file_path, download_url in download_urls.items():
            chapter = chapter_info[file_path]
            download_files.append(DownloadFile(
                file_path=file_path,
                download_url=download_url,
                chapter_id=chapter['id'],
                chapter_title=chapter['title'],
                duration=chapter['duration']
            ))
        
        # Sort by chapter number for consistent ordering
        download_files.sort(key=lambda x: int(x.chapter_id) if x.chapter_id.isdigit() else 0)
        
        expires_at = datetime.utcnow().isoformat() + "Z"
        if azure_storage.enabled:
            from datetime import timedelta
            expires_at = (datetime.utcnow() + timedelta(hours=24)).isoformat() + "Z"
        
        return BookDownloadResponse(
            book_id=book_id,
            book_title=book_data.get('title', 'Unknown Book'),
            files=download_files,
            expires_at=expires_at
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting download links for book {book_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate download links")

# Wishlist endpoints
@app.post("/bookstore/user/wishlist/{book_id}")
async def add_to_wishlist(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Add a book to user's wishlist"""
    try:
        result = add_to_user_wishlist(user_id, book_id)
        return result
    except ValueError as e:
        if "not found" in str(e).lower():
            raise HTTPException(status_code=404, detail=str(e))
        elif "already in wishlist" in str(e).lower():
            raise HTTPException(status_code=409, detail=str(e))
        else:
            raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error adding book to wishlist: {e}")
        raise HTTPException(status_code=500, detail="Failed to add book to wishlist")

@app.delete("/bookstore/user/wishlist/{book_id}")
async def remove_from_wishlist(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Remove a book from user's wishlist"""
    try:
        result = remove_from_user_wishlist(user_id, book_id)
        return result
    except ValueError as e:
        if "not found" in str(e).lower():
            raise HTTPException(status_code=404, detail=str(e))
        else:
            raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error removing book from wishlist: {e}")
        raise HTTPException(status_code=500, detail="Failed to remove book from wishlist")

@app.get("/bookstore/user/wishlist")
async def get_user_wishlist_endpoint(
    page: int = 1, 
    limit: int = 20,
    user_id: str = Depends(get_current_user_id)
):
    """Get user's wishlist"""
    try:
        offset = (page - 1) * limit
        result = get_user_wishlist(user_id, limit, offset)
        
        # Format response similar to browse endpoint
        total_pages = (result['total_books'] + limit - 1) // limit if result['total_books'] > 0 else 0
        
        return {
            "books": result['books'],
            "pagination": {
                "page": page,
                "limit": limit,
                "total_books": result['total_books'],
                "total_pages": total_pages,
                "has_next": page < total_pages,
                "has_prev": page > 1
            }
        }
    except Exception as e:
        logger.error(f"Error getting user wishlist: {e}")
        raise HTTPException(status_code=500, detail="Failed to get user wishlist")

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
async def serve_book_file(book_folder: str, filename: str, request: Request):
    """Serve audiobook files with range support for streaming"""
    try:
        # Try Azure Storage first
        azure_url = azure_storage.generate_audio_url(book_folder, filename)
        if azure_url:
            logger.info(f"Redirecting to Azure Storage for {book_folder}/{filename}")
            return RedirectResponse(url=azure_url)
        
        # Fallback to local storage with range support
        file_path = BOOK_FILES_DIR / book_folder / filename
        
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="File not found")
        
        # Get file size
        file_size = file_path.stat().st_size
        
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
        
        # Parse range header
        range_header = request.headers.get('Range')
        
        if range_header:
            # Handle range requests for audio streaming
            range_match = None
            import re
            range_pattern = r'bytes=(\d*)-(\d*)'
            range_match = re.match(range_pattern, range_header)
            
            if range_match:
                start_str, end_str = range_match.groups()
                start = int(start_str) if start_str else 0
                end = int(end_str) if end_str else file_size - 1
                
                # Ensure valid range
                if start >= file_size:
                    raise HTTPException(status_code=416, detail="Range Not Satisfiable")
                
                if end >= file_size:
                    end = file_size - 1
                
                content_length = end - start + 1
                
                # Read the file chunk
                with open(file_path, 'rb') as f:
                    f.seek(start)
                    chunk_data = f.read(content_length)
                
                headers = {
                    "Content-Range": f"bytes {start}-{end}/{file_size}",
                    "Content-Length": str(content_length),
                    "Accept-Ranges": "bytes"
                }
                
                logger.info(f"Serving range {start}-{end} from local storage: {book_folder}/{filename}")
                return Response(
                    content=chunk_data,
                    status_code=206,
                    media_type=media_type,
                    headers=headers
                )
        
        # No range header, serve complete file
        headers = {
            "Accept-Ranges": "bytes",
            "Content-Length": str(file_size)
        }
        
        logger.info(f"Serving complete file from local storage: {book_folder}/{filename}")
        return FileResponse(
            path=file_path,
            media_type=media_type,
            filename=filename,
            headers=headers
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
    config: Optional[str] = None  # Changed from config_name to config to match LLM Gateway
    max_tokens: Optional[int] = None
    temperature: Optional[float] = None
    use_cache: Optional[bool] = True

@app.post("/complete")
async def complete_text(request: CompletionRequest):
    """Proxy text completion requests to LLM Gateway"""
    try:
        # Create LLM Gateway compatible request
        llm_request = {
            "prompt": request.prompt,
            "max_tokens": request.max_tokens or 4000
        }
        
        # Only include config if it's provided and not empty
        if request.config:
            llm_request["config"] = request.config
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{LLM_URL}/complete",
                json=llm_request
            )
            response.raise_for_status()
            return response.json()
    except Exception as llm_error:
        logger.warning(f"LLM service unavailable, providing fallback response: {llm_error}")
        
        # Provide a persona-appropriate fallback response
        persona = request.config or 'default'
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

class ContextRequest(BaseModel):
    book_name: str
    chapter_name: Optional[str] = None
    current_position: float  # Position in seconds

# Progress tracking models
class SaveProgressRequest(BaseModel):
    book_id: str
    position: float  # Position in seconds
    chapter_id: Optional[str] = None

class ProgressResponse(BaseModel):
    book_id: str
    position: float
    chapter_id: Optional[str] = None
    updated_at: str

class BookmarkRequest(BaseModel):
    book_id: str
    position: float  # Position in seconds
    note: Optional[str] = None

class BookmarkResponse(BaseModel):
    id: str
    book_id: str
    position: float
    note: Optional[str] = None
    created_at: str

# =====================================================
# USER PROGRESS TRACKING ENDPOINTS
# =====================================================

@app.post("/bookstore/user/progress", response_model=ProgressResponse)
async def save_user_progress(request: SaveProgressRequest, user_id: str = Depends(get_current_user_id)):
    """Save user's reading progress for a book"""
    try:
        from db_utils import save_user_reading_progress
        
        # Save progress to database
        success = save_user_reading_progress(
            user_id=user_id,
            book_id=request.book_id,
            position=request.position,
            chapter_id=request.chapter_id
        )
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to save progress")
        
        return ProgressResponse(
            book_id=request.book_id,
            position=request.position,
            chapter_id=request.chapter_id,
            updated_at=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"Error saving user progress: {e}")
        raise HTTPException(status_code=500, detail="Failed to save progress")

@app.get("/bookstore/user/progress/{book_id}", response_model=ProgressResponse)
async def get_user_progress(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Get user's reading progress for a book"""
    try:
        from db_utils import get_user_reading_progress
        
        progress = get_user_reading_progress(user_id=user_id, book_id=book_id)
        
        if not progress:
            # Return default progress if none saved
            return ProgressResponse(
                book_id=book_id,
                position=0.0,
                chapter_id=None,
                updated_at=datetime.now().isoformat()
            )
        
        return ProgressResponse(
            book_id=book_id,
            position=float(progress.get('position', 0.0)),
            chapter_id=progress.get('chapter_id'),
            updated_at=progress.get('updated_at', datetime.now()).isoformat() if progress.get('updated_at') else datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"Error getting user progress: {e}")
        raise HTTPException(status_code=500, detail="Failed to get progress")

@app.post("/bookstore/user/bookmarks", response_model=BookmarkResponse)
async def save_user_bookmark(request: BookmarkRequest, user_id: str = Depends(get_current_user_id)):
    """Save a bookmark for a user"""
    try:
        from db_utils import save_user_bookmark
        
        bookmark_id = save_user_bookmark(
            user_id=user_id,
            book_id=request.book_id,
            position=request.position,
            note=request.note
        )
        
        if not bookmark_id:
            raise HTTPException(status_code=500, detail="Failed to save bookmark")
        
        return BookmarkResponse(
            id=bookmark_id,
            book_id=request.book_id,
            position=request.position,
            note=request.note,
            created_at=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"Error saving bookmark: {e}")
        raise HTTPException(status_code=500, detail="Failed to save bookmark")

@app.get("/bookstore/user/bookmarks/{book_id}")
async def get_user_bookmarks(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Get all bookmarks for a book"""
    try:
        from db_utils import get_user_bookmarks
        
        bookmarks = get_user_bookmarks(user_id=user_id, book_id=book_id)
        
        return [
            BookmarkResponse(
                id=str(bookmark.get('id', '')),
                book_id=book_id,
                position=float(bookmark.get('position', 0.0)),
                note=bookmark.get('note'),
                created_at=bookmark.get('created_at', datetime.now()).isoformat() if bookmark.get('created_at') else datetime.now().isoformat()
            )
            for bookmark in bookmarks
        ]
        
    except Exception as e:
        logger.error(f"Error getting bookmarks: {e}")
        raise HTTPException(status_code=500, detail="Failed to get bookmarks")

# =====================================================
# CONTEXT SERVICE ENDPOINTS
# =====================================================

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

@app.post("/context")
async def get_positional_context(request: ContextRequest):
    """Get context for specific playback position in audiobook"""
    try:
        # Format position info for context
        position_minutes = int(request.current_position // 60)
        position_seconds = int(request.current_position % 60)
        
        context_parts = []
        context_parts.append(f"Book: {request.book_name}")
        
        if request.chapter_name:
            context_parts.append(f"Chapter: {request.chapter_name}")
            
        context_parts.append(f"Position: {position_minutes}:{position_seconds:02d}")
        
        # Create a simple context response
        # TODO: In the future, this could query the Context Service for actual book text
        context_text = f"Currently listening to {request.book_name}"
        if request.chapter_name:
            context_text += f" - {request.chapter_name}"
        context_text += f" at {position_minutes}:{position_seconds:02d}"
        
        return {
            "context_text": context_text,
            "book_name": request.book_name,
            "chapter_name": request.chapter_name,
            "position": request.current_position
        }
    except Exception as e:
        logger.error(f"Error getting positional context: {e}")
        raise HTTPException(status_code=500, detail="Context retrieval failed")

# Voice Chat Upload Endpoint

class VoiceChatRequest(BaseModel):
    transcription: str
    persona_config: Optional[str] = None
    book_id: Optional[str] = None
    current_position: Optional[float] = None

class VoiceChatResponse(BaseModel):
    transcription: str
    response_text: str
    response_audio: Optional[str] = None  # Base64 encoded audio response

@app.post("/voice-chat", response_model=VoiceChatResponse)
async def process_voice_chat(
    audio_file: UploadFile = File(...),
    persona_config: Optional[str] = None,
    book_id: Optional[str] = None,
    current_position: Optional[float] = None,
    user_id: str = Depends(get_current_user_id)
):
    """
    Process uploaded voice audio for chat with AI personas
    
    1. Transcribes the audio using Azure OpenAI Whisper
    2. Sends transcription to LLM Gateway for response
    3. Optionally converts response to speech using TTS
    """
    
    # Validate file type
    if not audio_file.content_type or not audio_file.content_type.startswith('audio/'):
        raise HTTPException(status_code=400, detail="File must be an audio file")
    
    # File size limit (10MB)
    MAX_FILE_SIZE = 10 * 1024 * 1024
    audio_content = await audio_file.read()
    if len(audio_content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="Audio file too large (max 10MB)")
    
    try:
        # Step 1: Transcribe audio using Azure OpenAI Whisper
        transcription = await _transcribe_audio(audio_content, audio_file.filename)
        
        if not transcription.strip():
            raise HTTPException(status_code=400, detail="Could not transcribe audio - no speech detected")
        
        # Step 2: Send transcription to LLM Gateway for response
        completion_request = {
            "messages": [
                {"role": "user", "content": transcription}
            ],
            "config": persona_config,
            "book_id": book_id,
            "current_position": current_position
        }
        
        async with httpx.AsyncClient() as client:
            llm_response = await client.post(
                f"{LLM_URL}/complete",
                json=completion_request,
                timeout=30.0
            )
            
            if llm_response.status_code != 200:
                logger.error(f"LLM Gateway error: {llm_response.text}")
                raise HTTPException(status_code=500, detail="Failed to get AI response")
            
            response_data = llm_response.json()
            response_text = response_data.get("content", "I'm sorry, I couldn't process your request.")
        
        # Step 3: Optionally generate TTS response
        response_audio = None
        if persona_config:  # Only generate TTS if persona is specified
            try:
                tts_request = {
                    "text": response_text,
                    "config": persona_config
                }
                
                async with httpx.AsyncClient() as client:
                    tts_response = await client.post(
                        f"{TTS_URL}/synthesize",
                        json=tts_request,
                        timeout=30.0
                    )
                    
                    if tts_response.status_code == 200:
                        tts_data = tts_response.json()
                        response_audio = tts_data.get("audio")
            except Exception as e:
                logger.warning(f"TTS generation failed: {e}")
                # Continue without audio - text response is still valid
        
        return VoiceChatResponse(
            transcription=transcription,
            response_text=response_text,
            response_audio=response_audio
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Voice chat processing error: {e}")
        raise HTTPException(status_code=500, detail="Voice chat processing failed")

async def _transcribe_audio(audio_content: bytes, filename: str) -> str:
    """Transcribe audio using Azure OpenAI Whisper API"""
    try:
        # Get Azure OpenAI credentials from config
        azure_openai_key = os.getenv("AZURE_OPENAI_API_KEY")
        azure_openai_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        
        if not azure_openai_key or not azure_openai_endpoint:
            raise HTTPException(status_code=500, detail="Azure OpenAI not configured")
        
        # Prepare audio file for API
        files = {
            'file': (filename or 'audio.wav', audio_content, 'audio/wav')
        }
        
        data = {
            'model': 'whisper-1',
            'response_format': 'text'
        }
        
        # Make request to Azure OpenAI Whisper API
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{azure_openai_endpoint}/openai/audio/transcriptions?api-version=2024-12-01-preview",
                headers={"api-key": azure_openai_key},
                files=files,
                data=data,
                timeout=30.0
            )
            
            if response.status_code != 200:
                logger.error(f"Whisper API error: {response.text}")
                raise HTTPException(status_code=500, detail="Audio transcription failed")
            
            return response.text.strip()
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail="Audio transcription failed")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)