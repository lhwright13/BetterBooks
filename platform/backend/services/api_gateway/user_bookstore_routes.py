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

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize router
router = APIRouter(prefix="/bookstore/user", tags=["user-bookstore"])

# Mock data for development (replace with real DB calls later)
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

def get_current_user_id():
    """Mock function to get current user ID - replace with real auth later"""
    return "default"

@router.get("/credits", response_model=CreditBalanceResponse)
async def get_credit_balance(user_id: str = Depends(get_current_user_id)):
    """Get user's credit balance"""
    try:
        credits = MOCK_USER_CREDITS.get(user_id, MOCK_USER_CREDITS["default"])
        
        return CreditBalanceResponse(
            total_credits=credits["total_credits"],
            used_credits=credits["used_credits"],
            available_credits=credits["available_credits"],
            last_updated=datetime.now()
        )
    except Exception as e:
        logger.error(f"Error getting credit balance: {e}")
        raise HTTPException(status_code=500, detail="Failed to get credit balance")

@router.get("/library", response_model=UserLibraryResponse)
async def get_user_library(user_id: str = Depends(get_current_user_id)):
    """Get user's purchased books"""
    try:
        # Get user's owned book IDs
        owned_book_ids = MOCK_USER_LIBRARY.get(user_id, [])
        
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
        logger.error(f"Error getting user library: {e}")
        raise HTTPException(status_code=500, detail="Failed to get user library")

@router.post("/purchase", response_model=PurchaseResponse)
async def purchase_book(
    purchase_request: PurchaseRequest,
    user_id: str = Depends(get_current_user_id)
):
    """Purchase a book with credits"""
    try:
        book_id = purchase_request.book_id
        
        # Check if user already owns the book
        owned_books = MOCK_USER_LIBRARY.get(user_id, [])
        if book_id in owned_books:
            raise HTTPException(status_code=400, detail="You already own this book")
        
        # Check credit balance
        credits = MOCK_USER_CREDITS.get(user_id, MOCK_USER_CREDITS["default"])
        if credits["available_credits"] < 1:
            raise HTTPException(status_code=400, detail="Insufficient credits")
        
        # Process purchase (mock)
        # In real implementation: update database, deduct credits, add to library
        
        # Update mock data
        MOCK_USER_LIBRARY.setdefault(user_id, []).append(book_id)
        MOCK_USER_CREDITS[user_id] = {
            "total_credits": credits["total_credits"],
            "used_credits": credits["used_credits"] + 1,
            "available_credits": credits["available_credits"] - 1
        }
        
        return PurchaseResponse(
            success=True,
            message=f"Successfully purchased book with 1 credit",
            book_id=book_id,
            credits_used=1,
            remaining_credits=credits["available_credits"] - 1,
            download_url=f"/books/{book_id}/Chapter 1.mp3"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error purchasing book: {e}")
        raise HTTPException(status_code=500, detail="Purchase failed")

@router.post("/initialize-credits")
async def initialize_user_credits(user_id: str = Depends(get_current_user_id)):
    """Initialize credits for new user (5 free credits)"""
    try:
        if user_id not in MOCK_USER_CREDITS:
            MOCK_USER_CREDITS[user_id] = {
                "total_credits": 5,
                "used_credits": 0,
                "available_credits": 5
            }
            
        return {"message": "User credits initialized", "credits": 5}
        
    except Exception as e:
        logger.error(f"Error initializing credits: {e}")
        raise HTTPException(status_code=500, detail="Failed to initialize credits")