"""
Simple Bookstore API Routes - Working with hardcoded data from actual books
Provides basic functionality while database issues are resolved
"""

import logging
from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, Query
from pydantic import BaseModel

logger = logging.getLogger(__name__)

# Initialize router
router = APIRouter(prefix="/bookstore", tags=["bookstore"])

# Simple response models
class SimpleBookResponse(BaseModel):
    id: str
    title: str
    author: Optional[str] = None
    narrator: Optional[str] = None
    description: Optional[str] = None
    cover_image_url: Optional[str] = None
    sample_audio_url: Optional[str] = None
    price_usd: float
    credit_price: int
    formatted_price: str
    duration_hours: float
    formatted_duration: str
    is_featured: bool = False
    is_bestseller: bool = False
    is_new_release: bool = False
    average_rating: Optional[float] = None
    review_count: int = 0

class SimpleBrowseResponse(BaseModel):
    books: List[SimpleBookResponse]
    total_count: int
    page: int
    page_size: int
    has_next_page: bool

class SimpleCategoryResponse(BaseModel):
    id: str
    name: str
    description: str
    book_count: int

# Helper function for browsing books
def _browse_books_helper(
    category_id: Optional[str] = None,
    featured_only: bool = False,
    bestsellers_only: bool = False,
    new_releases_only: bool = False,
    page: int = 1,
    page_size: int = 20
) -> SimpleBrowseResponse:
    """Helper function for browsing books with filtering and pagination"""
    try:
        # Apply filters
        filtered_books = SAMPLE_BOOKS.copy()
        
        if featured_only:
            filtered_books = [book for book in filtered_books if book.is_featured]
        if bestsellers_only:
            filtered_books = [book for book in filtered_books if book.is_bestseller]
        if new_releases_only:
            filtered_books = [book for book in filtered_books if book.is_new_release]
        
        # Apply pagination
        start_idx = (page - 1) * page_size
        end_idx = start_idx + page_size
        paginated_books = filtered_books[start_idx:end_idx]
        
        return SimpleBrowseResponse(
            books=paginated_books,
            total_count=len(filtered_books),
            page=page,
            page_size=page_size,
            has_next_page=len(filtered_books) > end_idx
        )
        
    except Exception as e:
        logger.error(f"Error browsing books: {e}")
        return SimpleBrowseResponse(
            books=[],
            total_count=0,
            page=page,
            page_size=page_size,
            has_next_page=False
        )

# Hardcoded data based on our actual books
SAMPLE_BOOKS = [
    SimpleBookResponse(
        id="gatsby-001",
        title="The Great Gatsby",
        author="F. Scott Fitzgerald",
        narrator="Professional Narrator",
        description="The Great Gatsby is a 1925 novel by American writer F. Scott Fitzgerald. Set in the Jazz Age on prosperous Long Island and in New York City, the novel tells the story of Jay Gatsby and his pursuit of Daisy Buchanan. A masterpiece of American literature that captures the decadence and idealism of the Roaring Twenties.",
        cover_image_url="/books/cover/The Great Gatsby/GatsbyCover.jpg",
        sample_audio_url="/books/The Great Gatsby/Chapter 1.mp3",
        price_usd=12.95,
        credit_price=1,
        formatted_price="$12.95",
        duration_hours=9.0,
        formatted_duration="9h 0m",
        is_featured=True,
        is_bestseller=True,
        is_new_release=False,
        average_rating=4.2,
        review_count=1247
    ),
    SimpleBookResponse(
        id="odyssey-001",
        title="The Odyssey",
        author="Homer",
        narrator="Samuel Butler (Translation)",
        description="The Odyssey is one of two major ancient Greek epic poems attributed to Homer. It is one of the oldest extant works of literature still widely read by modern audiences. The poem tells the story of Odysseus, king of Ithaca, who wanders for ten years trying to get home after the Trojan War.",
        cover_image_url="/books/cover/Odyssey/odessey.jpeg",
        sample_audio_url="/books/Odyssey/odyssey_01_homer_butler_64kb.mp3",
        price_usd=15.95,
        credit_price=1,
        formatted_price="$15.95",
        duration_hours=24.0,
        formatted_duration="24h 0m",
        is_featured=True,
        is_bestseller=False,
        is_new_release=False,
        average_rating=4.5,
        review_count=892
    ),
    SimpleBookResponse(
        id="alice-001",
        title="Alice's Adventures in Wonderland",
        author="Lewis Carroll",
        narrator="LibriVox Reader",
        description="Alice's Adventures in Wonderland is an 1865 English children's novel by Lewis Carroll. It tells of a young girl named Alice who falls through a rabbit hole into a subterranean fantasy world populated by peculiar, anthropomorphic creatures. The tale plays with logic, giving the story lasting popularity with adults as well as with children.",
        cover_image_url="/books/cover/Alice's Adventures in Wonderland/aliceinWonder.jpg",
        sample_audio_url="/books/Alice's Adventures in Wonderland/alices_adventures_01_carroll_64kb.mp3",
        price_usd=9.95,
        credit_price=1,
        formatted_price="$9.95",
        duration_hours=6.0,
        formatted_duration="6h 0m",
        is_featured=True,
        is_bestseller=False,
        is_new_release=True,
        average_rating=4.3,
        review_count=2156
    ),
    SimpleBookResponse(
        id="moby-001",
        title="Moby Dick",
        author="Herman Melville",
        narrator="LibriVox Readers",
        description="Moby-Dick is an 1851 novel by Herman Melville. The book is the sailor Ishmael's narrative of the obsessive quest of Ahab, captain of the whaling ship Pequod, for revenge on Moby Dick, the giant white sperm whale that on the ship's previous voyage bit off Ahab's leg at the knee.",
        cover_image_url="/books/cover/Moby Dick/Moby_Dick_1002.jpg",
        sample_audio_url="/books/Moby Dick/mobydick_000_melville_64kb.mp3",
        price_usd=19.95,
        credit_price=1,
        formatted_price="$19.95",
        duration_hours=43.0,
        formatted_duration="43h 0m",
        is_featured=True,
        is_bestseller=True,
        is_new_release=False,
        average_rating=4.1,
        review_count=1823
    ),
    SimpleBookResponse(
        id="war-peace-001",
        title="War and Peace",
        author="Leo Tolstoy",
        narrator="LibriVox Readers",
        description="War and Peace is a novel by the Russian author Leo Tolstoy, published serially, then in its entirety in 1869. It is regarded as one of Tolstoy's finest literary achievements and remains an internationally praised classic of world literature. This is Volume 1 of the complete work.",
        cover_image_url="/books/cover/War and Peace/warandpeacecover.jpg",
        sample_audio_url="/books/War and Peace/war_peace_v1_maude_translation_01_tolstoy_64kb.mp3",
        price_usd=24.95,
        credit_price=2,
        formatted_price="$24.95",
        duration_hours=68.0,
        formatted_duration="68h 0m",
        is_featured=True,
        is_bestseller=True,
        is_new_release=False,
        average_rating=4.6,
        review_count=3421
    )
]

SAMPLE_CATEGORIES = [
    SimpleCategoryResponse(id="fiction", name="Fiction", description="Literary fiction and novels", book_count=1),
    SimpleCategoryResponse(id="classics", name="Classic Literature", description="Timeless literary works", book_count=4),
    SimpleCategoryResponse(id="epic", name="Epic Poetry", description="Epic poems and classical works", book_count=1),
    SimpleCategoryResponse(id="drama", name="Drama", description="Plays and dramatic works", book_count=0),
    SimpleCategoryResponse(id="romance", name="Romance", description="Love stories and romantic fiction", book_count=0),
    SimpleCategoryResponse(id="mystery", name="Mystery", description="Mystery and suspense novels", book_count=0),
]

@router.get("/test")
async def test_endpoint():
    """Test endpoint to verify bookstore routes are working"""
    return {
        "status": "ok",
        "message": "Bookstore API is working!",
        "book_count": len(SAMPLE_BOOKS),
        "category_count": len(SAMPLE_CATEGORIES),
        "available_endpoints": [
            "GET /bookstore/test",
            "GET /bookstore/browse",
            "GET /bookstore/categories",
            "GET /bookstore/search",
            "GET /bookstore/books/{book_id}"
        ]
    }

@router.get("/browse", response_model=SimpleBrowseResponse)
async def browse_books(
    category_id: Optional[str] = Query(None, description="Filter by category ID"),
    featured_only: bool = Query(False, description="Show only featured books"),
    bestsellers_only: bool = Query(False, description="Show only bestsellers"),
    new_releases_only: bool = Query(False, description="Show only new releases"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
):
    """Browse books with filtering and pagination"""
    return _browse_books_helper(category_id, featured_only, bestsellers_only, new_releases_only, page, page_size)

@router.get("/categories", response_model=List[SimpleCategoryResponse])
async def get_categories():
    """Get all available book categories"""
    return SAMPLE_CATEGORIES

@router.get("/search", response_model=SimpleBrowseResponse)
async def search_books(
    q: str = Query(..., description="Search query"),
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
):
    """Search books by title, author, or description"""
    try:
        # Simple search implementation
        query = q.lower()
        filtered_books = []
        
        for book in SAMPLE_BOOKS:
            if (query in book.title.lower() or 
                (book.author and query in book.author.lower()) or
                (book.description and query in book.description.lower())):
                filtered_books.append(book)
        
        # Apply pagination
        start_idx = (page - 1) * page_size
        end_idx = start_idx + page_size
        paginated_books = filtered_books[start_idx:end_idx]
        
        return SimpleBrowseResponse(
            books=paginated_books,
            total_count=len(filtered_books),
            page=page,
            page_size=page_size,
            has_next_page=len(filtered_books) > end_idx
        )
        
    except Exception as e:
        logger.error(f"Error searching books: {e}")
        return SimpleBrowseResponse(
            books=[],
            total_count=0,
            page=page,
            page_size=page_size,
            has_next_page=False
        )

@router.get("/books/{book_id}", response_model=SimpleBookResponse)
async def get_book_details(book_id: str):
    """Get detailed information about a specific book"""
    for book in SAMPLE_BOOKS:
        if book.id == book_id:
            return book
    
    from fastapi import HTTPException
    raise HTTPException(status_code=404, detail="Book not found")

@router.get("/featured", response_model=SimpleBrowseResponse)
async def get_featured_books(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=50, description="Items per page"),
):
    """Get featured books"""
    return _browse_books_helper(featured_only=True, page=page, page_size=page_size)

@router.get("/bestsellers", response_model=SimpleBrowseResponse)
async def get_bestsellers(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(10, ge=1, le=50, description="Items per page"),
):
    """Get bestseller books"""
    return _browse_books_helper(bestsellers_only=True, page=page, page_size=page_size)

# Health check endpoint
@router.get("/health")
async def bookstore_health():
    """Health check for bookstore service"""
    return {
        "status": "healthy",
        "service": "bookstore",
        "book_count": len(SAMPLE_BOOKS),
        "category_count": len(SAMPLE_CATEGORIES),
        "timestamp": datetime.utcnow().isoformat()
    }