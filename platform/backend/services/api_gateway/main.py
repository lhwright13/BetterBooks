#!/usr/bin/env python3

import asyncio
import base64
import json
import logging
import os
import re
import time
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional
from uuid import UUID

import httpx
import yaml
from fastapi import FastAPI, HTTPException, File, UploadFile, Depends, Request, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response, RedirectResponse, StreamingResponse
from pydantic import BaseModel

from core.shared.utils.config_manager import get_config
app_config = get_config()

from core.infrastructure.chat_logger import get_chat_logger


def validate_uuid(value: str, name: str = "id") -> None:
    try:
        UUID(value)
    except ValueError:
        raise HTTPException(status_code=404, detail=f"Invalid {name} format")


CONTEXT_URL = app_config.get_service_url("context_service")
LLM_URL = app_config.get_service_url("llm_gateway")
TTS_URL = app_config.get_service_url("tts_service")

_docker_path = Path("/app/book_files")
_local_path = Path(__file__).parent.parent.parent.parent.parent / "book_files"
BOOK_FILES_DIR = _docker_path if _docker_path.exists() else _local_path

logging_config = app_config.get_logging_config()
log_level = getattr(logging, logging_config.level.upper(), logging.INFO)
logging.basicConfig(
    level=log_level,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)
logger.info(f"API Gateway starting with configuration: {app_config.get_config_summary()}")

from storage_helper import get_storage
storage = get_storage()

from context import JsonContextRetriever
from personas import JsonPersonaManager
from chat import PromptBuilder

def _format_datetime(dt):
    if dt is None:
        return None
    if isinstance(dt, str):
        return dt
    return dt.isoformat() if hasattr(dt, 'isoformat') else str(dt)

def _generate_sample_audio_url_for_title(book_title: str) -> Optional[str]:
    audio_files = {
        "Alice's Adventures in Wonderland": "alices_adventures_01_carroll_64kb.mp3",
        "Moby Dick": "mobydick_001_002_melville_64kb.mp3", 
        "The Great Gatsby": "gatsby_chapter_01.mp3",
        "War and Peace": "warandpeace_001_tolstoy_64kb.mp3"
    }
    
    filename = audio_files.get(book_title, "")
    if not filename:
        return None
    cloud_url = storage.generate_audio_url(book_title, filename)
    if cloud_url:
        return cloud_url
    return f"/books/{book_title}/{filename}"

def _generate_azure_cover_url(book_title: str, fallback_url: str) -> str:
    if not book_title:
        return fallback_url

    cloud_url = storage.generate_cover_url(book_title, "cover.jpg")
    if cloud_url:
        return cloud_url

    default_url = f"/books/cover/{book_title}/cover.jpg"

    if not fallback_url:
        return default_url
    if fallback_url.startswith('http') or fallback_url.startswith('/books/cover/'):
        return fallback_url
    return default_url

def _get_book_duration_for_title(book_title: str) -> Optional[int]:
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

# Initialize Context Engine components
# These will be initialized on startup
context_retriever: JsonContextRetriever = None
persona_manager: JsonPersonaManager = None
prompt_builder: PromptBuilder = None

@app.on_event("startup")
async def startup_validation():
    global context_retriever, persona_manager, prompt_builder

    try:
        try:
            project_root = Path(__file__).resolve().parents[4]
            book_files_path = project_root / "book_files"
            config_path = project_root / "config"
        except IndexError:
            book_files_path = Path("/app/book_files")
            config_path = Path("/app/config")

        if not book_files_path.exists():
            book_files_path = Path("/app/book_files")
            config_path = Path("/app/config")

        context_retriever = JsonContextRetriever(str(book_files_path))
        persona_manager = JsonPersonaManager(str(book_files_path), str(config_path))
        prompt_builder = PromptBuilder(context_retriever, persona_manager)

        logger.info(f"Context Engine initialized with book_files: {book_files_path}")
    except Exception as e:
        logger.warning(f"Context Engine initialization failed: {e}")
        logger.warning("AI Chat features may not work correctly")

    try:
        from startup_check import StartupValidator
        validator = StartupValidator()
        passed, results = await validator.run_all_validations()

        if not passed:
            logger.error("API Gateway startup validation failed")
            if app_config.is_development():
                logger.error("Continuing startup in development mode despite validation failures")
        else:
            logger.info("API Gateway startup validation completed successfully")

    except Exception as e:
        logger.warning(f"Startup validation encountered an error: {e}")
        logger.warning("Continuing startup without validation checks")

    try:
        from voice_service import warm_models
        await warm_models()
    except Exception as e:
        logger.warning(f"Voice model warm-up failed: {e}")

security_config = app_config.get_security_config()
app.add_middleware(
    CORSMiddleware,
    allow_origins=security_config.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from core.infrastructure.logging_middleware import LoggingMiddleware
app.add_middleware(LoggingMiddleware, logger=logger)

from simple_auth_routes import router as auth_router
app.include_router(auth_router)


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
    add_to_user_wishlist,
    remove_from_user_wishlist,
    get_user_wishlist,
    get_categories as db_get_categories,
    search_books as db_search_books,
    get_bestselling_books as db_get_bestselling_books,
    initialize_user_credits as db_initialize_credits,
    get_db_connection,
    save_user_reading_progress,
    get_all_user_reading_progress,
    get_user_reading_progress,
    save_user_bookmark as db_save_user_bookmark,
    get_user_bookmarks as db_get_user_bookmarks,
)
from user_context import get_current_user_id

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

class Chapter(BaseModel):
    id: str
    title: str
    audio_url: str
    chapter_number: int
    duration: Optional[int] = None

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
    chapters: List[Chapter] = []
    audio_url: Optional[str] = None  # For compatibility with mobile app

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

def _generate_chapters_for_book(book_title: str, total_chapters: int = None) -> List[Chapter]:
    chapter_counts = {
        "The Great Gatsby": 9,
        "Pride and Prejudice": 61,
        "1984": 23,
        "Harry Potter and the Sorcerers Stone": 17,
        "To Kill a Mockingbird": 31,
        "Moby Dick": 135,
        "Alice's Adventures in Wonderland": 12,
        "War and Peace": 365
    }

    chapter_count = total_chapters or chapter_counts.get(book_title, 10)
    book_slug = book_title.lower().replace(' ', '_')

    return [
        Chapter(
            id=f"{book_slug}_ch_{i:02d}",
            title=f"Chapter {i}",
            audio_url=f"/audio/stream/{book_title}/Chapter {i}.mp3",
            chapter_number=i,
            duration=1800
        )
        for i in range(1, chapter_count + 1)
    ]

def _book_dict_to_browse_book(book, include_chapters=True, **overrides):
    price = float(book.get('price_usd', 9.99))
    result = BrowseBook(
        id=str(book['id']),
        title=book['title'],
        author=book['author'] or 'Unknown Author',
        cover_image_url=_generate_azure_cover_url(book['title'], book.get('cover_image_url', '')),
        price_usd=price,
        credit_price=int(book.get('credit_price', 1)),
        formatted_price=f"${price:.2f}",
        formatted_duration="Unknown length",
        language="en",
        is_featured=bool(book.get('is_featured', False)),
        is_bestseller=bool(book.get('is_bestseller', False)),
        is_new_release=bool(book.get('is_new_release', False)),
        created_at="2025-01-01T00:00:00Z",
        updated_at="2025-01-01T00:00:00Z",
        chapters=_generate_chapters_for_book(book['title'], book.get('total_chapters')) if include_chapters else [],
        audio_url=f"/audio/stream/{book['title']}/Chapter 1.mp3" if include_chapters else None,
    )
    for key, value in overrides.items():
        setattr(result, key, value)
    return result

def _build_browse_response(data, page, limit):
    return BrowseResponse(
        books=[_book_dict_to_browse_book(b) for b in data['books']],
        total_count=data['total_books'],
        page=page,
        page_size=limit,
        has_next_page=(page * limit) < data['total_books']
    )

def _empty_browse_response(page=1, limit=20):
    return BrowseResponse(
        books=[],
        total_count=0,
        page=page,
        page_size=limit,
        has_next_page=False
    )

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
                cover_image_url=_generate_azure_cover_url(book['title'], book.get('cover_image_url', '')),
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
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page")
):
    """Browse books in the bookstore with database-backed data"""
    try:
        offset = (page - 1) * limit
        browse_data = db_get_browse_books(limit=limit, offset=offset, featured_only=featured)
        return _build_browse_response(browse_data, page, limit)
    except Exception as e:
        logger.error(f"Error browsing books: {e}")
        return _empty_browse_response(page, limit)

@app.get("/bookstore/search", response_model=BrowseResponse)
async def search_books(
    q: str,
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page")
):
    """Search for books in the catalog by title, author, or keywords"""
    try:
        offset = (page - 1) * limit
        search_data = db_search_books(query=q, limit=limit, offset=offset)
        return _build_browse_response(search_data, page, limit)
    except Exception as e:
        logger.error(f"Error searching books: {e}")
        return _empty_browse_response(page, limit)

@app.get("/bookstore/featured", response_model=BrowseResponse)
async def get_featured_books(limit: int = Query(10, ge=1, le=100, description="Maximum items to return")):
    """Get a curated list of featured audiobooks"""
    try:
        browse_data = db_get_browse_books(limit=limit, offset=0, featured_only=True)
        books = [_book_dict_to_browse_book(b, is_featured=True) for b in browse_data['books']]
        return BrowseResponse(
            books=books,
            total_count=browse_data['total_books'],
            page=1,
            page_size=limit,
            has_next_page=False
        )
    except Exception as e:
        logger.error(f"Error getting featured books: {e}")
        return _empty_browse_response(1, limit)

@app.get("/bookstore/bestsellers", response_model=BrowseResponse)
async def get_bestselling_books(limit: int = Query(10, ge=1, le=100, description="Maximum items to return")):
    """Get the most popular audiobooks"""
    try:
        browse_data = db_get_bestselling_books(limit=limit, offset=0)
        books = [_book_dict_to_browse_book(b, include_chapters=False, is_bestseller=True) for b in browse_data['books']]
        return BrowseResponse(
            books=books,
            total_count=browse_data['total_books'],
            page=1,
            page_size=limit,
            has_next_page=False
        )
    except Exception as e:
        logger.error(f"Error getting bestselling books: {e}")
        return _empty_browse_response(1, limit)

@app.post("/bookstore/user/initialize-credits", response_model=CreditBalanceResponse)
async def initialize_user_credits(
    initial_credits: int = 5,
    user_id: str = Depends(get_current_user_id)
):
    """Initialize credits for a new user"""
    try:
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
async def list_all_books(
    limit: int = Query(50, ge=1, le=100, description="Maximum items to return"),
    offset: int = Query(0, ge=0, description="Number of items to skip")
):
    """Simple book list endpoint - returns basic book information"""
    try:
        books_data = get_browse_books(limit=limit, offset=offset)

        books = [
            {
                "id": str(book['id']),
                "title": book['title'],
                "author": book.get('author') or 'Unknown Author',
                "cover_image_url": book.get('cover_image_url', ''),
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
    validate_uuid(book_id, "book_id")
    try:
        book_data = db_get_book_details(book_id)
        if not book_data:
            raise HTTPException(status_code=404, detail="Book not found")
        
        chapters = [
            Chapter(
                id=ch['id'],
                title=ch['title'],
                audio_url=ch['audio_url'],
                chapter_number=ch['chapter_number'],
                duration=ch.get('duration')
            )
            for ch in book_data.get('chapters', [])
        ]
        
        return DetailedBook(
            id=book_data['id'],
            title=book_data['title'],
            author=book_data['author'],
            description=book_data.get('description'),
            cover_image_url=_generate_azure_cover_url(book_data['title'], book_data['cover_image_url']),
            price_usd=float(book_data.get('price_usd', 9.99)),
            credit_price=int(book_data.get('credit_price', 1)),
            is_featured=bool(book_data.get('is_featured', False)),
            is_bestseller=bool(book_data.get('is_bestseller', False)),
            is_new_release=bool(book_data.get('is_new_release', False)),
            chapters=chapters,
            total_duration=book_data.get('total_duration')
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting book details for {book_id}: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/bookstore/purchase", response_model=PurchaseResponse)
async def purchase_book(request: PurchaseRequest, user_id: str = Depends(get_current_user_id)):
    """Purchase a book using credits with database persistence"""
    try:
        if check_user_owns_book(user_id, request.book_id):
            credits_data = db_get_user_credits(user_id)
            return PurchaseResponse(
                success=False,
                message="Book already owned",
                remaining_credits=credits_data.get('available_credits', 0) if credits_data else 0
            )

        credits_data = db_get_user_credits(user_id)
        if not credits_data:
            return PurchaseResponse(
                success=False,
                message="Unable to retrieve credit balance",
                remaining_credits=0
            )
        
        available_credits = credits_data.get('available_credits', 0)

        if available_credits < request.credits_to_use:
            return PurchaseResponse(
                success=False,
                message="Insufficient credits",
                remaining_credits=available_credits
            )

        purchase_success = create_purchase(
            user_id=user_id,
            book_id=request.book_id,
            credits_used=request.credits_to_use,
            purchase_type="credit"
        )

        if purchase_success:
            book_details = db_get_book_details(request.book_id)
            book_title = book_details['title'] if book_details else "Unknown Book"
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

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error purchasing book {request.book_id}: {e}")
        raise HTTPException(status_code=500, detail="Purchase failed")

@app.get("/bookstore/books/{book_id}/personas", response_model=BookPersonasResponse)
async def get_book_personas_endpoint(book_id: str):
    """Get all personas available for a specific book"""
    validate_uuid(book_id, "book_id")
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
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting personas for book {book_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get book personas")

@app.get("/personas/{persona_id}", response_model=PersonaResponse)
async def get_persona_endpoint(persona_id: str):
    """Get detailed information about a specific persona"""
    validate_uuid(persona_id, "persona_id")
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
    except HTTPException:
        raise
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
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error listing personas: {e}")
        raise HTTPException(status_code=500, detail="Failed to list personas")

@app.get("/voice/config")
async def get_voice_config():
    """Get voice chat configuration for frontend"""
    try:
        # Look for voice config file in multiple locations
        project_root = Path(__file__).parent.parent.parent.parent.parent
        config_paths = [
            Path("/app/config/voice/voice_chat_config.yaml"),  # Docker container path
            Path("../../../config/voice/voice_chat_config.yaml"),  # Local development path
            project_root / "config" / "voice" / "voice_chat_config.yaml"  # Project root fallback
        ]
        
        config_data = {}
        config_loaded = False
        
        for config_path in config_paths:
            if config_path.exists():
                try:
                    with open(config_path, 'r', encoding='utf-8') as f:
                        config_data = yaml.safe_load(f)
                    config_loaded = True
                    logger.info(f"Loaded voice config from: {config_path}")
                    break
                except Exception as e:
                    logger.warning(f"Failed to load config from {config_path}: {e}")
                    continue
        
        if not config_loaded:
            # Fallback default configuration
            config_data = {
                "vad": {"sensitivity": "medium", "silence_timeout_ms": 2000},
                "conversation": {"max_length": 50, "continuous_listening": True},
                "tts": {"default_voice": "en-US-Neural2-J", "speech_rate": 1.0},
                "features": {"voice_chat_enabled": True, "persona_voice_switching": True}
            }
            logger.warning("Using fallback voice configuration")
        
        # Return frontend-relevant configuration only
        return {
            "vad_sensitivity": config_data.get("vad", {}).get("sensitivity", "medium"),
            "silence_timeout_ms": config_data.get("vad", {}).get("silence_timeout_ms", 2000),
            "max_conversation_length": config_data.get("conversation", {}).get("max_length", 50),
            "continuous_listening": config_data.get("conversation", {}).get("continuous_listening", True),
            "interrupt_enabled": config_data.get("conversation", {}).get("interrupt_enabled", True),
            "voice_chat_enabled": config_data.get("features", {}).get("voice_chat_enabled", True),
            "persona_voice_switching": config_data.get("features", {}).get("persona_voice_switching", True),
            "response_timeout_seconds": config_data.get("performance", {}).get("response_timeout_seconds", 30)
        }
    except Exception as e:
        logger.error(f"Error loading voice config: {e}")
        # Return safe defaults on error
        return {
            "vad_sensitivity": "medium",
            "silence_timeout_ms": 2000,
            "max_conversation_length": 50,
            "continuous_listening": True,
            "interrupt_enabled": True,
            "voice_chat_enabled": True,
            "persona_voice_switching": True,
            "response_timeout_seconds": 30
        }


class TranscriptionResponse(BaseModel):
    text: str
    confidence: float
    language: str = "en"

class SynthesisRequest(BaseModel):
    text: str
    voice: str = "default"
    speed: float = 1.0

@app.post("/voice/transcribe", response_model=TranscriptionResponse)
async def transcribe_audio_endpoint(
    audio: UploadFile = File(...),
    language: str = "en"
):
    """
    Transcribe audio to text using local Whisper.

    Accepts: wav, mp3, webm, ogg, flac, m4a
    Returns: transcribed text with confidence score
    """
    from voice_service import transcribe_audio

    content_type = audio.content_type or ""
    if not any(t in content_type for t in ["audio", "octet-stream"]):
        raise HTTPException(status_code=400, detail=f"Invalid file type: {content_type}. Must be audio.")

    # Read audio content
    audio_bytes = await audio.read()

    # Size limit: 25MB
    if len(audio_bytes) > 25 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Audio file too large (max 25MB)")

    try:
        text, confidence = await transcribe_audio(audio_bytes, audio.filename or "audio.wav", language)
        return TranscriptionResponse(text=text, confidence=confidence, language=language)
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")


@app.post("/voice/synthesize")
async def synthesize_speech_endpoint(request: SynthesisRequest):
    """
    Convert text to speech using Azure TTS.

    Returns: WAV audio file
    """
    from voice_service import synthesize_speech_azure, is_azure_tts_available

    if not request.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    if len(request.text) > 5000:
        raise HTTPException(status_code=400, detail="Text too long (max 5000 characters)")

    if not 0.5 <= request.speed <= 2.0:
        raise HTTPException(status_code=400, detail="Speed must be between 0.5 and 2.0")

    if not is_azure_tts_available():
        raise HTTPException(status_code=503, detail="Azure TTS not configured")

    try:
        audio_bytes = await synthesize_speech_azure(
            request.text,
            voice_name=request.voice if request.voice != "default" else "en-US-GuyNeural",
            rate=request.speed
        )
        return Response(
            content=audio_bytes,
            media_type="audio/wav",
            headers={"Content-Disposition": "attachment; filename=response.wav"}
        )
    except Exception as e:
        logger.error(f"TTS error: {e}")
        raise HTTPException(status_code=500, detail=f"Speech synthesis failed: {str(e)}")


# ---- WebSocket Streaming Voice Chat ----

@app.websocket("/ws/voice")
async def websocket_voice_chat(ws: WebSocket):
    """
    WebSocket endpoint for streaming voice chat.

    Protocol:
      Client -> Server:
        { "type": "config", "book_id": "...", "chapter": 1, "persona_id": "...", "timestamp": 0 }
        { "type": "audio_data", "data": "<base64 audio>" }

      Server -> Client:
        { "type": "transcription", "text": "user's words" }
        { "type": "llm_token", "content": "word " }
        { "type": "audio_chunk", "data": "<base64 WAV>", "format": "wav", "sequence": 0 }
        { "type": "done" }
        { "type": "error", "message": "..." }

    Authentication: pass token as query param ?token=... since browsers
    cannot set headers on WebSocket connections.
    """
    # Authenticate via query param
    token = ws.query_params.get("token")
    if token:
        try:
            from core.auth.auth import verify_token
            verify_token(token)
        except Exception:
            await ws.close(code=4001, reason="Invalid token")
            return

    await ws.accept()

    config = None

    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except (json.JSONDecodeError, ValueError):
                await ws.send_json({"type": "error", "message": "Invalid JSON"})
                continue

            msg_type = msg.get("type")

            if msg_type == "config":
                config = {
                    "book_id": msg.get("book_id"),
                    "chapter": msg.get("chapter", 1),
                    "persona_id": msg.get("persona_id"),
                    "timestamp": msg.get("timestamp", 0),
                }
                continue

            if msg_type == "audio_data":
                try:
                    audio_b64 = msg.get("data", "")
                    audio_bytes = base64.b64decode(audio_b64)
                except Exception:
                    await ws.send_json({"type": "error", "message": "Invalid audio data"})
                    continue
                await _handle_voice_interaction(ws, audio_bytes, config or {})
                continue

    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error(f"WebSocket voice error: {e}")
        try:
            await ws.send_json({"type": "error", "message": "Internal server error"})
        except Exception:
            pass


async def _ws_send(ws: WebSocket, lock: asyncio.Lock, data: dict):
    """Send JSON over WebSocket with a lock to prevent concurrent writes."""
    async with lock:
        await ws.send_json(data)


async def _handle_voice_interaction(ws: WebSocket, audio_bytes: bytes, config: dict):
    """Run the full STT -> LLM stream -> TTS stream pipeline over WebSocket."""
    from voice_service import (
        transcribe_audio, SentenceAccumulator,
        synthesize_speech_azure, is_azure_tts_available
    )

    book_id = config.get("book_id")
    chapter = config.get("chapter", 1)
    persona_id = config.get("persona_id")
    timestamp = config.get("timestamp", 0)

    # Lock to serialize all WebSocket writes (main loop + tts worker)
    ws_lock = asyncio.Lock()

    # 1) STT
    try:
        user_text, confidence = await transcribe_audio(audio_bytes, "recording.webm")
    except Exception as e:
        logger.error(f"Voice WS STT error: {e}")
        await _ws_send(ws, ws_lock, {"type": "error", "message": "Transcription failed"})
        return

    if not user_text.strip():
        await _ws_send(ws, ws_lock, {"type": "error", "message": "No speech detected"})
        return

    await _ws_send(ws, ws_lock, {"type": "transcription", "text": user_text})

    # 2) Build context via PromptBuilder (same as /ai/chat)
    messages = []
    voice_obj = None
    if prompt_builder and book_id and persona_id:
        try:
            built = await prompt_builder.build(
                book_id=book_id,
                chapter=chapter,
                timestamp_seconds=timestamp,
                persona_id=persona_id
            )
            if built:
                messages.append({"role": "system", "content": built.system_prompt})
                voice_obj = getattr(built.persona, "voice", None)
        except Exception as e:
            logger.warning(f"Voice WS context build failed: {e}")

    if not messages:
        messages.append({
            "role": "system",
            "content": "You are a helpful audiobook companion. Keep responses concise for voice."
        })

    messages.append({"role": "user", "content": user_text})

    # 3) Stream LLM tokens
    llm_request = {
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 500,
        "stream": True
    }

    accumulator = SentenceAccumulator()
    tts_available = is_azure_tts_available()
    audio_sequence = 0

    # Resolve voice settings from persona config
    tts_voice = "en-US-GuyNeural"
    tts_style = None
    tts_rate = 1.0
    if voice_obj:
        tts_voice = getattr(voice_obj, "voice_id", None) or tts_voice
        tts_style = getattr(voice_obj, "style", None)
        rate_val = getattr(voice_obj, "rate", None)
        if rate_val is not None:
            tts_rate = rate_val

    # TTS queue: sentences are enqueued by the LLM consumer and processed
    # sequentially by a dedicated worker so audio chunks arrive in order.
    # Each sentence is synthesized to a complete WAV blob before sending,
    # so the client receives self-contained audio files it can decode.
    tts_queue: asyncio.Queue[Optional[tuple[str, int]]] = asyncio.Queue()

    async def tts_worker():
        """Process TTS sentences one-by-one, sending complete WAV blobs."""
        try:
            while True:
                item = await tts_queue.get()
                if item is None:
                    break
                sentence, seq = item
                try:
                    wav_bytes = await synthesize_speech_azure(
                        sentence, tts_voice, tts_style, tts_rate
                    )
                    if wav_bytes:
                        chunk_b64 = base64.b64encode(wav_bytes).decode("ascii")
                        await _ws_send(ws, ws_lock, {
                            "type": "audio_chunk",
                            "data": chunk_b64,
                            "format": "wav",
                            "sequence": seq
                        })
                except asyncio.CancelledError:
                    return
                except Exception as e:
                    logger.error(f"Voice WS TTS error (seq={seq}): {e}")
        except asyncio.CancelledError:
            return

    # Start the TTS worker if Azure is available
    tts_task = None
    if tts_available:
        tts_task = asyncio.create_task(tts_worker())

    full_response = ""

    async def _cleanup_tts():
        if tts_task and not tts_task.done():
            tts_task.cancel()
            try:
                await tts_task
            except asyncio.CancelledError:
                pass

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream("POST", f"{LLM_URL}/chat", json=llm_request) as response:
                if response.status_code != 200:
                    await _ws_send(ws, ws_lock, {"type": "error", "message": "LLM service unavailable"})
                    await _cleanup_tts()
                    return

                async for line in response.aiter_lines():
                    if not line or not line.startswith("data:"):
                        continue

                    payload = line[5:].lstrip()
                    if not payload:
                        continue

                    try:
                        data = json.loads(payload)
                    except (json.JSONDecodeError, ValueError):
                        continue

                    # Handle LLM errors
                    error = data.get("error")
                    if error:
                        await _ws_send(ws, ws_lock, {"type": "error", "message": f"LLM error: {error}"})
                        await _cleanup_tts()
                        return

                    if data.get("done"):
                        break

                    content = data.get("content", "")
                    if not content:
                        continue

                    full_response += content

                    # Send token to client for live text display
                    await _ws_send(ws, ws_lock, {"type": "llm_token", "content": content})

                    # Buffer into sentences and enqueue for TTS
                    if tts_available:
                        sentences = accumulator.add(content)
                        for s in sentences:
                            await tts_queue.put((s, audio_sequence))
                            audio_sequence += 1

        # Flush remaining text from accumulator
        if tts_available:
            remainder = accumulator.flush()
            if remainder:
                await tts_queue.put((remainder, audio_sequence))
                audio_sequence += 1

        # Signal the TTS worker to stop and wait for it
        if tts_task:
            await tts_queue.put(None)
            await tts_task

    except WebSocketDisconnect:
        await _cleanup_tts()
        return
    except Exception as e:
        logger.error(f"Voice WS LLM stream error: {e}")
        await _cleanup_tts()
        try:
            await _ws_send(ws, ws_lock, {"type": "error", "message": "LLM streaming failed"})
        except Exception:
            pass
        return

    try:
        await _ws_send(ws, ws_lock, {"type": "done"})
    except Exception:
        pass


@app.get("/bookstore/books/{book_id}/download", response_model=BookDownloadResponse)
async def get_book_download_links(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Get download links for all chapters of a purchased book"""
    validate_uuid(book_id, "book_id")
    try:
        if not check_user_owns_book(user_id, book_id):
            raise HTTPException(status_code=403, detail="Book not purchased by user")

        book_data = db_get_book_details(book_id)
        if not book_data:
            raise HTTPException(status_code=404, detail="Book not found")
            
        file_paths = []
        chapter_info = {}
        for chapter in book_data.get('chapters', []):
            if chapter.get('file_path'):
                fp = chapter['file_path']
                file_paths.append(fp)
                chapter_info[fp] = {
                    'id': chapter['id'],
                    'title': chapter['title'],
                    'duration': chapter.get('duration')
                }

        if not file_paths:
            raise HTTPException(status_code=404, detail="No audio files found for this book")

        download_urls = storage.generate_download_urls(file_paths, expiry_hours=24)
        if not download_urls:
            download_urls = {fp: f"/books/{fp}" for fp in file_paths}

        download_files = [
            DownloadFile(
                file_path=fp,
                download_url=url,
                chapter_id=chapter_info[fp]['id'],
                chapter_title=chapter_info[fp]['title'],
                duration=chapter_info[fp]['duration']
            )
            for fp, url in download_urls.items()
        ]
        download_files.sort(key=lambda x: int(x.chapter_id) if x.chapter_id.isdigit() else 0)
        
        if storage.enabled:
            expires_at = (datetime.utcnow() + timedelta(hours=24)).isoformat() + "Z"
        else:
            expires_at = datetime.utcnow().isoformat() + "Z"
        
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

@app.post("/bookstore/user/wishlist/{book_id}")
async def add_to_wishlist(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Add a book to user's wishlist"""
    validate_uuid(book_id, "book_id")
    try:
        result = add_to_user_wishlist(user_id, book_id)
        return result
    except HTTPException:
        raise
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
    validate_uuid(book_id, "book_id")
    try:
        result = remove_from_user_wishlist(user_id, book_id)
        return result
    except HTTPException:
        raise
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
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
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
    except HTTPException:
        raise
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

@app.get("/books/{book_folder}/{filename}")
async def serve_book_file(book_folder: str, filename: str, request: Request):
    """Serve audiobook files with range support for streaming"""
    try:
        cloud_url = storage.generate_audio_url(book_folder, filename)
        if cloud_url:
            return RedirectResponse(url=cloud_url)

        file_path = BOOK_FILES_DIR / book_folder / filename
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="File not found")

        file_size = file_path.stat().st_size
        media_type = _audio_media_type(filename)
        range_header = request.headers.get('Range')

        if range_header:
            range_match = re.match(r'bytes=(\d*)-(\d*)', range_header)
            if range_match:
                start_str, end_str = range_match.groups()
                start = int(start_str) if start_str else 0
                end = int(end_str) if end_str else file_size - 1

                if start >= file_size:
                    raise HTTPException(status_code=416, detail="Range Not Satisfiable")
                end = min(end, file_size - 1)
                content_length = end - start + 1

                with open(file_path, 'rb') as f:
                    f.seek(start)
                    chunk_data = f.read(content_length)

                return Response(
                    content=chunk_data,
                    status_code=206,
                    media_type=media_type,
                    headers={
                        "Content-Range": f"bytes {start}-{end}/{file_size}",
                        "Content-Length": str(content_length),
                        "Accept-Ranges": "bytes"
                    }
                )

        return FileResponse(
            path=file_path,
            media_type=media_type,
            filename=filename,
            headers={"Accept-Ranges": "bytes", "Content-Length": str(file_size)}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error serving book file {book_folder}/{filename}: {e}")
        raise HTTPException(status_code=500, detail="Error serving file")

AUDIO_MEDIA_TYPES = {
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
    ".ogg": "audio/ogg",
    ".m4a": "audio/mp4",
}

def _audio_media_type(filename):
    ext = Path(filename).suffix.lower()
    return AUDIO_MEDIA_TYPES.get(ext, "audio/mpeg")

def _find_cover_image(book_folder: str) -> Optional[Path]:
    folder_path = BOOK_FILES_DIR / book_folder
    if not folder_path.exists():
        return None

    for ext in ['*.jpg', '*.jpeg', '*.png', '*.gif']:
        images = list(folder_path.glob(ext))
        for img in images:
            if 'cover' in img.name.lower():
                return img
        if images:
            return images[0]
    return None

IMAGE_MEDIA_TYPES = {".png": "image/png", ".gif": "image/gif"}

@app.get("/books/cover/{book_folder}/{filename}")
async def serve_cover_image(book_folder: str, filename: str):
    """Serve book cover images from Azure Storage or local fallback"""
    try:
        cloud_url = storage.generate_cover_url(book_folder, filename)
        if cloud_url:
            return RedirectResponse(url=cloud_url)

        file_path = BOOK_FILES_DIR / book_folder / filename
        if not file_path.exists():
            found_cover = _find_cover_image(book_folder)
            if found_cover:
                file_path = found_cover
                filename = found_cover.name
            else:
                raise HTTPException(status_code=404, detail="Cover image not found")

        ext = Path(filename).suffix.lower()
        media_type = IMAGE_MEDIA_TYPES.get(ext, "image/jpeg")

        return FileResponse(path=file_path, media_type=media_type, filename=filename)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error serving cover image {book_folder}/{filename}: {e}")
        raise HTTPException(status_code=500, detail="Error serving cover image")
class CompletionRequest(BaseModel):
    prompt: str
    config: Optional[str] = None  # Changed from config_name to config to match LLM Gateway
    max_tokens: Optional[int] = None
    temperature: Optional[float] = None
    use_cache: Optional[bool] = True


class AIChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class AIChatRequest(BaseModel):
    """Request to the /ai/chat endpoint for context-aware persona chat."""
    book_id: str                          # Which book the user is reading (e.g., "The Great Gatsby")
    chapter: int                          # Current chapter number
    timestamp_seconds: float              # Current position in chapter (seconds)
    persona_id: str                       # Which persona to chat with (e.g., "jay-gatsby", "english-teacher")
    message: str                          # User's question
    conversation_history: List[AIChatMessage] = []  # Previous messages in conversation
    stream: bool = False                  # Whether to stream the response via SSE


class AIChatResponse(BaseModel):
    """Response from the /ai/chat endpoint."""
    message: str                          # AI's response
    persona_id: str                       # Which persona responded
    persona_name: str                     # Display name for UI
    chapters_used: List[int]             # Which chapters were in context
    token_estimate: int                   # Estimated tokens used for context
    voice_config: Optional[dict] = None   # Voice settings for TTS


async def stream_llm_response(llm_url: str, llm_request: dict, built, chat_logger, request_id: str):
    full_response = ""
    llm_start_time = time.time()

    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            async with client.stream(
                "POST",
                f"{llm_url}/chat",
                json=llm_request
            ) as response:
                if response.status_code != 200:
                    error_msg = f"LLM service returned status {response.status_code}"
                    yield f"data: {json.dumps({'error': error_msg})}\n\n"
                    return

                async for line in response.aiter_lines():
                    if line:
                        yield f"{line}\n\n"
                        # Try to extract content for logging
                        if line.startswith("data: "):
                            try:
                                data = json.loads(line[6:])
                                if data.get("content"):
                                    full_response += data["content"]
                            except:
                                pass

        llm_latency_ms = (time.time() - llm_start_time) * 1000
        if full_response:
            chat_logger.log_response(
                request_id=request_id,
                response_text=full_response,
                latency_ms=llm_latency_ms,
                model="streamed"
            )
        chat_logger.log_complete(request_id)

    except Exception as e:
        logger.error(f"Streaming error: {e}")
        yield f"data: {json.dumps({'error': str(e)})}\n\n"


@app.post("/ai/chat")
async def ai_chat(request: AIChatRequest, user_id: str = Depends(get_current_user_id)):
    """
    Context-aware AI chat with book personas.

    This endpoint allows users to chat with AI personas (book characters or teachers)
    that have context about the book up to the user's current reading position.
    The AI will never reveal spoilers beyond where the user has read.

    Set stream=true to receive Server-Sent Events for real-time streaming.

    Example request:
    {
        "book_id": "The Great Gatsby",
        "chapter": 2,
        "timestamp_seconds": 300,
        "persona_id": "jay-gatsby",
        "message": "What do you think of the green light?",
        "stream": true
    }
    """
    global prompt_builder

    chat_logger = get_chat_logger()
    request_id = str(uuid.uuid4())[:8]
    llm_start_time = None

    if not prompt_builder:
        raise HTTPException(
            status_code=503,
            detail="AI Chat service not initialized. Please try again later."
        )

    try:
        chat_logger.log_request(
            request_id=request_id,
            user_message=request.message,
            book_id=request.book_id,
            chapter=request.chapter,
            timestamp_seconds=request.timestamp_seconds,
            persona_id=request.persona_id,
            user_id=user_id
        )

        built = await prompt_builder.build(
            book_id=request.book_id,
            chapter=request.chapter,
            timestamp_seconds=request.timestamp_seconds,
            persona_id=request.persona_id
        )

        if not built:
            chat_logger.log_error(request_id, f"Persona '{request.persona_id}' not found")
            raise HTTPException(
                status_code=404,
                detail=f"Persona '{request.persona_id}' not found for book '{request.book_id}'"
            )

        chat_logger.log_context(
            request_id=request_id,
            system_prompt=built.system_prompt,
            chapters_included=built.context.chapters_included,
            token_estimate=built.context.token_estimate,
            persona_name=built.persona.name,
            timestamp_seconds=request.timestamp_seconds
        )

        messages = [{"role": "system", "content": built.system_prompt}]
        for msg in request.conversation_history:
            messages.append({"role": msg.role, "content": msg.content})
        messages.append({"role": "user", "content": request.message})

        llm_request = {
            "messages": messages,
            "temperature": built.persona.temperature,
            "max_tokens": 1000,
            "stream": request.stream
        }

        if request.stream:
            logger.info(
                f"AI Chat (streaming): user={user_id}, book={request.book_id}, "
                f"persona={request.persona_id}, chapters={built.context.chapters_included}"
            )
            return StreamingResponse(
                stream_llm_response(LLM_URL, llm_request, built, chat_logger, request_id),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no"
                }
            )

        # Non-streaming response (original behavior)
        llm_start_time = time.time()
        model_used = None

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{LLM_URL}/chat",
                json=llm_request
            )

            if response.status_code != 200:
                logger.warning("LLM /chat failed, trying /complete endpoint")
                fallback_request = {
                    "prompt": f"{built.system_prompt}\n\nUser: {request.message}\n\nAssistant:",
                    "max_tokens": 1000
                }
                response = await client.post(
                    f"{LLM_URL}/complete",
                    json=fallback_request
                )

            if response.status_code != 200:
                chat_logger.log_error(request_id, "LLM service unavailable")
                raise HTTPException(
                    status_code=502,
                    detail="LLM service unavailable"
                )

            llm_response = response.json()

        llm_latency_ms = (time.time() - llm_start_time) * 1000

        response_text = (
            llm_response.get("content")
            or llm_response.get("text")
            or (llm_response.get("choices", [{}])[0].get("message", {}).get("content") if llm_response.get("choices") else None)
            or str(llm_response)
        )

        model_used = llm_response.get("model", "unknown")

        chat_logger.log_response(
            request_id=request_id,
            response_text=response_text,
            latency_ms=llm_latency_ms,
            model=model_used
        )

        voice_config = None
        if built.persona.voice:
            voice_config = {
                "provider": built.persona.voice.provider,
                "voice_id": built.persona.voice.voice_id,
                "style": built.persona.voice.style,
                "rate": built.persona.voice.rate,
                "pitch": built.persona.voice.pitch
            }

        logger.info(
            f"AI Chat: user={user_id}, book={request.book_id}, "
            f"persona={request.persona_id}, chapters={built.context.chapters_included}"
        )

        chat_logger.log_complete(request_id)

        return AIChatResponse(
            message=response_text,
            persona_id=built.persona.id,
            persona_name=built.persona.name,
            chapters_used=built.context.chapters_included,
            token_estimate=built.context.token_estimate,
            voice_config=voice_config
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"AI Chat error: {e}")
        chat_logger.log_error(request_id, str(e))
        raise HTTPException(status_code=500, detail="AI Chat processing failed")


@app.get("/ai/personas/{book_id}")
async def get_ai_personas(book_id: str):
    """
    Get available AI personas for a book.

    Returns both book-specific personas (characters) and global personas (teachers).
    """
    global persona_manager

    if not persona_manager:
        raise HTTPException(
            status_code=503,
            detail="AI Chat service not initialized"
        )

    try:
        personas = await persona_manager.get_personas_for_book(book_id)

        return {
            "book_id": book_id,
            "personas": [
                {
                    "id": p.id,
                    "name": p.name,
                    "type": p.type,
                    "description": p.description,
                    "is_book_specific": p.book_id is not None,
                    "voice": {
                        "provider": p.voice.provider,
                        "voice_id": p.voice.voice_id
                    } if p.voice else None
                }
                for p in personas
            ]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting personas for {book_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get personas")


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
    except HTTPException:
        raise
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
    if not preprompt:
        return "AI Assistant"
    
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

class ProgressResponse(BaseModel):
    book_id: str
    position: float
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

@app.post("/bookstore/user/progress", response_model=ProgressResponse)
async def save_user_progress(request: SaveProgressRequest, user_id: str = Depends(get_current_user_id)):
    """Save user's reading progress for a book"""
    try:
        success = save_user_reading_progress(
            user_id=user_id,
            book_id=request.book_id,
            position=request.position
        )

        if not success:
            raise HTTPException(status_code=500, detail="Failed to save progress")

        return ProgressResponse(
            book_id=request.book_id,
            position=request.position,
            updated_at=datetime.now().isoformat()
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error saving user progress: {e}")
        raise HTTPException(status_code=500, detail="Failed to save progress")

@app.get("/bookstore/user/progress")
async def get_all_user_progress(user_id: str = Depends(get_current_user_id)):
    """Get all reading progress for the current user"""
    try:
        progress_list = get_all_user_reading_progress(user_id=user_id)

        progress_dict = {
            p.get('book_id'): {
                "position": float(p.get('current_position_seconds', 0.0)),
                "updated_at": _format_datetime(p.get('updated_at')) or datetime.now().isoformat()
            }
            for p in progress_list
        }

        return {"progress": progress_dict}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting all user progress: {e}")
        raise HTTPException(status_code=500, detail="Failed to get progress")

@app.get("/bookstore/user/progress/{book_id}", response_model=ProgressResponse)
async def get_user_progress(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Get user's reading progress for a book"""
    validate_uuid(book_id, "book_id")
    try:
        progress = get_user_reading_progress(user_id=user_id, book_id=book_id)

        if not progress:
            # Return default progress if none saved
            return ProgressResponse(
                book_id=book_id,
                position=0.0,
                updated_at=datetime.now().isoformat()
            )

        updated_at = progress.get('updated_at')
        return ProgressResponse(
            book_id=book_id,
            position=float(progress.get('current_position_seconds', 0.0)),
            updated_at=_format_datetime(updated_at) or datetime.now().isoformat()
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user progress: {e}")
        raise HTTPException(status_code=500, detail="Failed to get progress")

@app.post("/bookstore/user/bookmarks", response_model=BookmarkResponse)
async def save_user_bookmark(request: BookmarkRequest, user_id: str = Depends(get_current_user_id)):
    """Save a bookmark for a user"""
    try:
        bookmark_id = db_save_user_bookmark(
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

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error saving bookmark: {e}")
        raise HTTPException(status_code=500, detail="Failed to save bookmark")

@app.get("/bookstore/user/bookmarks/{book_id}")
async def get_user_bookmarks(book_id: str, user_id: str = Depends(get_current_user_id)):
    """Get all bookmarks for a book"""
    validate_uuid(book_id, "book_id")
    try:
        bookmarks = db_get_user_bookmarks(user_id=user_id, book_id=book_id)
        
        return [
            BookmarkResponse(
                id=str(bookmark.get('id', '')),
                book_id=book_id,
                position=float(bookmark.get('position_seconds', 0.0)),
                note=bookmark.get('notes'),
                created_at=_format_datetime(bookmark.get('created_at')) or datetime.now().isoformat()
            )
            for bookmark in bookmarks
        ]

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting bookmarks: {e}")
        raise HTTPException(status_code=500, detail="Failed to get bookmarks")

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
    except HTTPException:
        raise
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Error retrieving context: {e}")
        raise HTTPException(status_code=500, detail="Context retrieval failed")

@app.post("/context")
async def get_positional_context(request: ContextRequest):
    """Get context for specific playback position in audiobook"""
    try:
        minutes = int(request.current_position // 60)
        seconds = int(request.current_position % 60)
        timestamp = f"{minutes}:{seconds:02d}"

        context_text = f"Currently listening to {request.book_name}"
        if request.chapter_name:
            context_text += f" - {request.chapter_name}"
        context_text += f" at {timestamp}"

        return {
            "context_text": context_text,
            "book_name": request.book_name,
            "chapter_name": request.chapter_name,
            "position": request.current_position
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting positional context: {e}")
        raise HTTPException(status_code=500, detail="Context retrieval failed")

@app.post("/admin/populate-books")
async def populate_sample_books():
    """Temporary endpoint to add sample books for MVP testing"""
    try:
        books_to_add = [
            {
                'id': str(uuid.uuid4()),
                'title': 'The Great Gatsby',
                'author': 'F. Scott Fitzgerald',
                'narrator': 'LibriVox Reader',
                'description': 'A classic American novel about the Jazz Age, love, and the American Dream.',
                'duration_minutes': 240,
                'price_usd': 12.95,
                'credit_price': 1,
                'category_id': 'fiction',
                'is_featured': True,
                'is_bestseller': True,
                'is_new_release': False,
                'publication_date': '1925-04-10',
                'file_path': 'The Great Gatsby',
                'total_chapters': 9,
                'cover_image_url': '/books/cover/The Great Gatsby/cover.jpg',
                'sample_audio_url': '/books/The Great Gatsby/gatsby_sample.mp3',
                'sample_duration': 180,
                'average_rating': 4.2,
                'review_count': 15432,
                'purchase_count': 8921
            },
            {
                'id': str(uuid.uuid4()),
                'title': 'Pride and Prejudice',
                'author': 'Jane Austen',
                'narrator': 'LibriVox Reader',
                'description': 'A romantic novel about Elizabeth Bennet and Mr. Darcy.',
                'duration_minutes': 720,
                'price_usd': 14.95,
                'credit_price': 1,
                'category_id': 'fiction',
                'is_featured': True,
                'is_bestseller': True,
                'is_new_release': False,
                'publication_date': '1813-01-28',
                'file_path': 'Pride and Prejudice',
                'total_chapters': 61,
                'cover_image_url': '/books/cover/Pride and Prejudice/cover.jpg',
                'sample_audio_url': '/books/Pride and Prejudice/pride_sample.mp3',
                'sample_duration': 180,
                'average_rating': 4.5,
                'review_count': 22341,
                'purchase_count': 12456
            },
            {
                'id': str(uuid.uuid4()),
                'title': '1984',
                'author': 'George Orwell',
                'narrator': 'LibriVox Reader',
                'description': 'A dystopian novel about totalitarianism and surveillance.',
                'duration_minutes': 720,
                'price_usd': 12.95,
                'credit_price': 1,
                'category_id': 'fiction',
                'is_featured': False,
                'is_bestseller': True,
                'is_new_release': False,
                'publication_date': '1949-06-08',
                'file_path': '1984',
                'total_chapters': 23,
                'cover_image_url': '/books/cover/1984/cover.jpg',
                'sample_audio_url': '/books/1984/1984_sample.mp3',
                'sample_duration': 180,
                'average_rating': 4.4,
                'review_count': 25678,
                'purchase_count': 15432
            },
            {
                'id': str(uuid.uuid4()),
                'title': 'Harry Potter and the Sorcerer\'s Stone',
                'author': 'J.K. Rowling',
                'narrator': 'LibriVox Reader',
                'description': 'The first book in the magical Harry Potter series.',
                'duration_minutes': 480,
                'price_usd': 15.95,
                'credit_price': 1,
                'category_id': 'fiction',
                'is_featured': True,
                'is_bestseller': True,
                'is_new_release': True,
                'publication_date': '1997-06-26',
                'file_path': 'Harry Potter and the Sorcerers Stone',
                'total_chapters': 17,
                'cover_image_url': '/books/cover/Harry Potter and the Sorcerers Stone/cover.jpg',
                'sample_audio_url': '/books/Harry Potter/hp1_sample.mp3',
                'sample_duration': 180,
                'average_rating': 4.8,
                'review_count': 45321,
                'purchase_count': 25678
            },
            {
                'id': str(uuid.uuid4()),
                'title': 'To Kill a Mockingbird',
                'author': 'Harper Lee',
                'narrator': 'LibriVox Reader',
                'description': 'A gripping tale of racial injustice and loss of innocence in the American South.',
                'duration_minutes': 480,
                'price_usd': 13.95,
                'credit_price': 1,
                'category_id': 'fiction',
                'is_featured': True,
                'is_bestseller': False,
                'is_new_release': False,
                'publication_date': '1960-07-11',
                'file_path': 'To Kill a Mockingbird',
                'total_chapters': 31,
                'cover_image_url': '/books/cover/To Kill a Mockingbird/cover.jpg',
                'sample_audio_url': '/books/To Kill a Mockingbird/mockingbird_sample.mp3',
                'sample_duration': 180,
                'average_rating': 4.7,
                'review_count': 18765,
                'purchase_count': 9432
            }
        ]
        
        added_books = []
        async with DatabaseManager() as db:
            for book in books_to_add:
                try:
                    await db.execute("""
                        INSERT INTO books (
                            id, title, author, narrator, description, duration_minutes,
                            price_usd, credit_price, category_id, is_featured, is_bestseller,
                            is_new_release, publication_date, file_path, total_chapters,
                            cover_image_url, sample_audio_url, sample_duration, average_rating,
                            review_count, purchase_count, created_at, updated_at
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23)
                        ON CONFLICT (title) DO NOTHING
                    """, 
                        book['id'], book['title'], book['author'], book['narrator'],
                        book['description'], book['duration_minutes'], book['price_usd'],
                        book['credit_price'], book['category_id'], book['is_featured'],
                        book['is_bestseller'], book['is_new_release'], book['publication_date'],
                        book['file_path'], book['total_chapters'], book['cover_image_url'],
                        book['sample_audio_url'], book['sample_duration'], book['average_rating'],
                        book['review_count'], book['purchase_count'], datetime.now(), datetime.now()
                    )
                    added_books.append(book['title'])
                except Exception as e:
                    logger.error(f"Failed to add book {book['title']}: {e}")
                    continue
        
        # Get total count of books now in database
        async with DatabaseManager() as db:
            result = await db.fetch_one("SELECT COUNT(*) as count FROM books")
            total_books = result['count'] if result else 0
        
        return {
            "message": f"Successfully populated {len(added_books)} books",
            "books_added": added_books,
            "total_books_in_database": total_books
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to populate books: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to populate books: {str(e)}")

@app.get("/audio/{book_title}/{filename}")
async def stream_audio_file(book_title: str, filename: str):
    """Stream audio file from Azure Blob Storage or local fallback"""
    try:
        # First try Azure Storage
        cloud_url = storage.generate_audio_url(book_title, filename)
        if cloud_url:
            logger.info(f"Redirecting to Azure Storage URL for {book_title}/{filename}")
            return RedirectResponse(url=cloud_url, status_code=302)

        # Fallback to local file
        local_path = storage.get_fallback_local_path(book_title, filename)
        if local_path and os.path.exists(local_path):
            logger.info(f"Serving local file: {local_path}")
            return FileResponse(
                path=local_path,
                media_type='audio/mpeg',
                filename=filename
            )

        # File not found
        logger.warning(f"Audio file not found: {book_title}/{filename}")
        raise HTTPException(status_code=404, detail=f"Audio file not found: {filename}")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error streaming audio file {book_title}/{filename}: {e}")
        raise HTTPException(status_code=500, detail="Error accessing audio file")

@app.get("/audio/stream/{book_title}/{filename}")
async def get_audio_stream_url(book_title: str, filename: str):
    """Get streaming URL for audio file (mobile app friendly)"""
    try:
        # Generate streaming URL from Azure
        stream_url = storage.get_stream_url(f"{book_title}/{filename}")
        if stream_url:
            return {
                "status": "success",
                "stream_url": stream_url,
                "expires_in_hours": 1,
                "book_title": book_title,
                "filename": filename
            }

        # Fallback to API endpoint
        fallback_url = f"{app_config.get_service_url('api_gateway')}/audio/{book_title}/{filename}"
        return {
            "status": "fallback",
            "stream_url": fallback_url,
            "expires_in_hours": 24,
            "book_title": book_title,
            "filename": filename,
            "note": "Using local file fallback"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating stream URL for {book_title}/{filename}: {e}")
        raise HTTPException(status_code=500, detail="Error generating stream URL")

@app.get("/books/{book_title}/chapters")
async def list_book_chapters(book_title: str):
    """List all audio chapters for a book"""
    def _build_chapter_list(filenames):
        return [
            {
                "chapter_number": i,
                "filename": name,
                "title": name.replace('.mp3', '').replace('_', ' ').title(),
                "stream_url": f"/audio/stream/{book_title}/{name}",
                "download_url": f"/audio/{book_title}/{name}"
            }
            for i, name in enumerate(filenames, 1)
        ]

    try:
        cloud_files = storage.list_book_audio_files(book_title)
        if cloud_files:
            filenames = [os.path.basename(f) for f in cloud_files]
            chapters = _build_chapter_list(filenames)
            return {"book_title": book_title, "total_chapters": len(chapters), "chapters": chapters, "source": "cloud_storage"}

        local_dir = Path(f"book_files/{book_title}")
        if local_dir.exists():
            filenames = [f.name for f in sorted(local_dir.glob("*.mp3"))]
            chapters = _build_chapter_list(filenames)
            return {"book_title": book_title, "total_chapters": len(chapters), "chapters": chapters, "source": "local_files"}

        return {"book_title": book_title, "total_chapters": 0, "chapters": [], "source": "none", "message": "No audio chapters found for this book"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error listing chapters for {book_title}: {e}")
        raise HTTPException(status_code=500, detail="Error listing book chapters")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)