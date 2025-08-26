"""
User Bookstore API Routes
Handles user-specific bookstore operations: credits, purchases, and library
"""

import os
import logging
from datetime import datetime
from typing import List, Optional, Dict, Any
from uuid import UUID

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel

from core.auth.auth import get_current_user, User
from core.database.database_manager import DatabaseManager
from core.auth.user_manager import UserManager

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize router
router = APIRouter(prefix="/bookstore/user", tags=["user-bookstore"])

# Initialize database connection
try:
    db_manager = DatabaseManager()
    user_manager = UserManager(db_manager)
    logger.info("Database user management initialized for bookstore routes")
except Exception as e:
    logger.warning(f"Failed to initialize database for bookstore routes: {e}")
    db_manager = None
    user_manager = None

# Fallback mock data for development (if database unavailable)
MOCK_USER_CREDITS = {
    "user123": {"total_credits": 5, "used_credits": 2, "available_credits": 3},
    "default": {"total_credits": 5, "used_credits": 0, "available_credits": 5}
}

MOCK_USER_LIBRARY = {
    "user123": ["great-gatsby-001"],  # User only owns Great Gatsby
    "default": []  # New users own no books
}

# Response models
class CreditBalanceResponse(BaseModel):
    total_credits: int
    used_credits: int
    available_credits: int
    last_updated: datetime

class LibraryBookResponse(BaseModel):
    id: str
    title: str
    author: Optional[str] = None
    narrator: Optional[str] = None
    description: Optional[str] = None
    cover_image_url: Optional[str] = None
    purchase_date: datetime
    download_url: Optional[str] = None

class UserLibraryResponse(BaseModel):
    books: List[LibraryBookResponse]
    total_count: int

class PurchaseRequest(BaseModel):
    book_id: str
    use_credits: bool = True

class PurchaseResponse(BaseModel):
    success: bool
    message: str
    book_id: str
    credits_used: int
    remaining_credits: int
    download_url: Optional[str] = None

@router.get("/credits", response_model=CreditBalanceResponse)
async def get_credit_balance(current_user: User = Depends(get_current_user)):
    """Get user's credit balance"""
    try:
        if user_manager:
            # Use database-backed credit system
            credits = await user_manager.get_user_credit_balance(current_user.id)
            
            return CreditBalanceResponse(
                total_credits=credits["total_credits"],
                used_credits=credits["used_credits"],
                available_credits=credits["available_credits"],
                last_updated=datetime.fromisoformat(credits["last_updated"].replace('Z', '+00:00'))
            )
        else:
            # Fallback to mock data
            credits = MOCK_USER_CREDITS.get(current_user.id, MOCK_USER_CREDITS["default"])
            
            return CreditBalanceResponse(
                total_credits=credits["total_credits"],
                used_credits=credits["used_credits"],
                available_credits=credits["available_credits"],
                last_updated=datetime.now()
            )
    except Exception as e:
        logger.error(f"Error getting credit balance for user {current_user.id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get credit balance")

@router.get("/library", response_model=UserLibraryResponse)
async def get_user_library(
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(get_current_user)
):
    """Get user's purchased books"""
    try:
        if user_manager:
            # Use database-backed library system
            library_data = await user_manager.get_user_library(
                user_id=current_user.id,
                limit=limit,
                offset=offset
            )
            
            book_responses = []
            for book in library_data["books"]:
                book_responses.append(LibraryBookResponse(
                    id=book["id"],
                    title=book["title"],
                    author=book["author"],
                    narrator=book["narrator"],
                    description=book["description"],
                    cover_image_url=book["cover_image_url"],
                    purchase_date=datetime.fromisoformat(book["purchase_date"].replace('Z', '+00:00')),
                    download_url=f"/api/books/{book['id']}/download" if book["id"] else None
                ))
            
            return UserLibraryResponse(
                books=book_responses,
                total_count=library_data["total_count"]
            )
        else:
            # Fallback to mock data
            # Get user's owned book IDs
            owned_book_ids = MOCK_USER_LIBRARY.get(current_user.id, [])
            
            # Mock book data - in real implementation, fetch from database
            all_books = {
                "great-gatsby-001": {
                    "id": "great-gatsby-001",
                    "title": "The Great Gatsby",
                    "author": "F. Scott Fitzgerald",
                    "narrator": "Jake Gyllenhaal",
                    "description": "A classic American novel set in the Jazz Age",
                "cover_image_url": "/books/cover/The Great Gatsby/great-gatsby-cover.jpg",
                "purchase_date": datetime(2024, 1, 15),
                "download_url": "/books/The Great Gatsby/Chapter 1.mp3"
            },
            "alice-001": {
                "id": "alice-001",
                "title": "Alice's Adventures in Wonderland",
                "author": "Lewis Carroll",
                "narrator": "Scarlett Johansson",
                "description": "A young girl falls down a rabbit hole into a fantasy world",
                "cover_image_url": "/books/cover/Alice's Adventures in Wonderland/aliceinWonder.jpg",
                "purchase_date": datetime(2024, 2, 1),
                "download_url": "/books/Alice's Adventures in Wonderland/Chapter 1.mp3"
            },
            "moby-dick-001": {
                "id": "moby-dick-001", 
                "title": "Moby Dick",
                "author": "Herman Melville",
                "narrator": "Benedict Cumberbatch",
                "description": "The epic tale of Captain Ahab's quest for the white whale",
                "cover_image_url": "/books/cover/Moby Dick/moby-dick-cover.jpg",
                "purchase_date": datetime(2024, 2, 10),
                "download_url": "/books/Moby Dick/Chapter 1.mp3"
            }
        }
        
        # Build response with only owned books
        library_books = []
        for book_id in owned_book_ids:
            if book_id in all_books:
                book_data = all_books[book_id]
                library_books.append(LibraryBookResponse(**book_data))
        
        return UserLibraryResponse(
            books=library_books,
            total_count=len(library_books)
        )
        
    except Exception as e:
        logger.error(f"Error getting user library for user {current_user.id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get user library")

@router.post("/purchase", response_model=PurchaseResponse)
async def purchase_book(
    purchase_request: PurchaseRequest,
    current_user: User = Depends(get_current_user)
):
    """Purchase a book (0 credits as per requirement - all books are free)"""
    try:
        book_id = purchase_request.book_id
        
        if user_manager:
            # Use database-backed purchase system
            try:
                purchase_result = await user_manager.purchase_book_for_user(
                    user_id=current_user.id,
                    book_id=book_id,
                    purchase_type="credit"  # Still track as "credit" purchase but costs 0
                )
                
                # Get updated credit balance
                credits = await user_manager.get_user_credit_balance(current_user.id)
                
                return PurchaseResponse(
                    success=purchase_result["success"],
                    message="Book added to your library! (Free with EchoWright)",
                    book_id=book_id,
                    credits_used=0,  # All books cost 0 credits
                    remaining_credits=credits["available_credits"],
                    download_url=f"/api/books/{book_id}/download"
                )
                
            except ValueError as e:
                if "already owns" in str(e):
                    raise HTTPException(status_code=400, detail="You already own this book")
                elif "not found" in str(e):
                    raise HTTPException(status_code=404, detail="Book not found")
                else:
                    raise HTTPException(status_code=400, detail=str(e))
        else:
            # Fallback to mock system
            # Check if user already owns the book
            owned_books = MOCK_USER_LIBRARY.get(current_user.id, [])
            if book_id in owned_books:
                raise HTTPException(status_code=400, detail="You already own this book")
            
            # Process purchase (all books are free)
            MOCK_USER_LIBRARY.setdefault(current_user.id, []).append(book_id)
            
            # Get current credits (no change since books cost 0)
            credits = MOCK_USER_CREDITS.get(current_user.id, MOCK_USER_CREDITS["default"])
            
            return PurchaseResponse(
                success=True,
                message="Book added to your library! (Free with EchoWright)",
                book_id=book_id,
                credits_used=0,  # All books cost 0 credits
                remaining_credits=credits["available_credits"],
                download_url=f"/books/{book_id}/Chapter 1.mp3"
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error purchasing book {book_id} for user {current_user.id}: {e}")
        raise HTTPException(status_code=500, detail="Purchase failed")

@router.post("/initialize-credits")
async def initialize_user_credits(current_user: User = Depends(get_current_user)):
    """Initialize credits for user (starts with 0 credits as per requirement)"""
    try:
        if user_manager:
            # Credits are automatically initialized when user is created with 0 credits
            credits = await user_manager.get_user_credit_balance(current_user.id)
            return {
                "message": "Credits initialized (all books are free with EchoWright)",
                "credits": credits
            }
        else:
            # Fallback to mock (start with 0 credits)
            if current_user.id not in MOCK_USER_CREDITS:
                MOCK_USER_CREDITS[current_user.id] = {
                    "total_credits": 0,
                    "used_credits": 0,
                    "available_credits": 0
            }
            
            return {"message": "Credits initialized (all books are free)", "credits": MOCK_USER_CREDITS[current_user.id]}
        
    except Exception as e:
        logger.error(f"Error initializing credits for user {current_user.id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to initialize credits")

# Admin endpoints for user account inspection
@router.get("/check-ownership/{book_id}")
async def check_book_ownership(
    book_id: str,
    current_user: User = Depends(get_current_user)
):
    """Check if current user owns a specific book"""
    try:
        if user_manager:
            owns_book = await user_manager.check_user_owns_book(current_user.id, book_id)
            return {
                "user_id": current_user.id,
                "book_id": book_id,
                "owns_book": owns_book
            }
        else:
            # Fallback to mock data
            owned_books = MOCK_USER_LIBRARY.get(current_user.id, [])
            return {
                "user_id": current_user.id,
                "book_id": book_id,
                "owns_book": book_id in owned_books
            }
    except Exception as e:
        logger.error(f"Error checking book ownership: {e}")
        raise HTTPException(status_code=500, detail="Failed to check book ownership")