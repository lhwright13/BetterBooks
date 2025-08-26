"""
Bookstore Service Main Application
FastAPI service for book catalog and purchase management
"""

import asyncio
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import uvicorn
import os
from typing import List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
import psycopg2.pool
from datetime import datetime, timezone
import uuid
from decimal import Decimal

from .models import (
    Book, BookCatalogResponse, PurchaseRequest, PurchaseResponse,
    UserLibrary, CreditBalance, BookCategory, BookSearchQuery
)
from .database import DatabaseManager
from .service import BookstoreService

# Initialize FastAPI with lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("🚀 Bookstore Service starting...")
    
    # Initialize database connection
    db_manager = DatabaseManager()
    await db_manager.initialize()
    app.state.db = db_manager
    
    # Initialize bookstore service
    app.state.bookstore = BookstoreService(db_manager)
    
    print("✅ Bookstore Service ready!")
    yield
    
    # Shutdown
    print("🛑 Bookstore Service shutting down...")
    await db_manager.close()

app = FastAPI(
    title="BetterBooks Bookstore Service",
    description="Manages book catalog, purchases, and user libraries",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency to get bookstore service
def get_bookstore_service() -> BookstoreService:
    return app.state.bookstore

# Health check endpoints
@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "bookstore", "timestamp": datetime.now(timezone.utc)}

@app.get("/health/detailed")
async def detailed_health_check():
    try:
        # Test database connection
        db_status = await app.state.db.health_check()
        
        return {
            "status": "healthy",
            "service": "bookstore",
            "timestamp": datetime.now(timezone.utc),
            "dependencies": {
                "database": db_status
            }
        }
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "bookstore",
                "error": str(e),
                "timestamp": datetime.now(timezone.utc)
            }
        )

# Book catalog endpoints
@app.get("/books/catalog", response_model=BookCatalogResponse)
async def get_book_catalog(
    category_id: Optional[str] = None,
    featured: Optional[bool] = None,
    bestseller: Optional[bool] = None,
    new_release: Optional[bool] = None,
    limit: int = 20,
    offset: int = 0,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Get paginated book catalog with optional filtering"""
    try:
        books, total_count = await bookstore.get_catalog(
            category_id=category_id,
            featured=featured,
            bestseller=bestseller,
            new_release=new_release,
            limit=limit,
            offset=offset
        )
        
        return BookCatalogResponse(
            books=books,
            total_count=total_count,
            limit=limit,
            offset=offset
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get catalog: {str(e)}")

@app.get("/books/{book_id}", response_model=Book)
async def get_book_details(
    book_id: str,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Get detailed information about a specific book"""
    try:
        book = await bookstore.get_book_by_id(book_id)
        if not book:
            raise HTTPException(status_code=404, detail="Book not found")
        return book
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get book details: {str(e)}")

@app.post("/books/search", response_model=BookCatalogResponse)
async def search_books(
    query: BookSearchQuery,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Search books by title, author, or description"""
    try:
        books, total_count = await bookstore.search_books(
            search_text=query.search_text,
            category_id=query.category_id,
            limit=query.limit,
            offset=query.offset
        )
        
        return BookCatalogResponse(
            books=books,
            total_count=total_count,
            limit=query.limit,
            offset=query.offset
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to search books: {str(e)}")

@app.get("/books/categories", response_model=List[BookCategory])
async def get_book_categories(
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Get all book categories"""
    try:
        categories = await bookstore.get_categories()
        return categories
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get categories: {str(e)}")

# Purchase endpoints
@app.post("/purchase", response_model=PurchaseResponse)
async def purchase_book(
    purchase: PurchaseRequest,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Purchase a book using credits or cash"""
    try:
        result = await bookstore.purchase_book(
            user_id=purchase.user_id,
            book_id=purchase.book_id,
            purchase_type=purchase.purchase_type,
            credits_to_use=purchase.credits_to_use
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Purchase failed: {str(e)}")

# User library endpoints
@app.get("/library/{user_id}", response_model=UserLibrary)
async def get_user_library(
    user_id: str,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Get user's purchased books"""
    try:
        library = await bookstore.get_user_library(user_id)
        return library
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get user library: {str(e)}")

@app.get("/credits/{user_id}", response_model=CreditBalance)
async def get_credit_balance(
    user_id: str,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Get user's credit balance"""
    try:
        balance = await bookstore.get_credit_balance(user_id)
        return balance
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get credit balance: {str(e)}")

@app.post("/credits/{user_id}/add")
async def add_credits(
    user_id: str,
    credits: int,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Add credits to user account (admin function)"""
    try:
        await bookstore.add_credits(user_id, credits)
        return {"message": f"Added {credits} credits to user {user_id}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to add credits: {str(e)}")

# Wishlist endpoints
@app.post("/wishlist/{user_id}/{book_id}")
async def add_to_wishlist(
    user_id: str,
    book_id: str,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Add book to user's wishlist"""
    try:
        await bookstore.add_to_wishlist(user_id, book_id)
        return {"message": "Book added to wishlist"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to add to wishlist: {str(e)}")

@app.delete("/wishlist/{user_id}/{book_id}")
async def remove_from_wishlist(
    user_id: str,
    book_id: str,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Remove book from user's wishlist"""
    try:
        await bookstore.remove_from_wishlist(user_id, book_id)
        return {"message": "Book removed from wishlist"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to remove from wishlist: {str(e)}")

@app.get("/wishlist/{user_id}", response_model=List[Book])
async def get_wishlist(
    user_id: str,
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """Get user's wishlist"""
    try:
        wishlist = await bookstore.get_wishlist(user_id)
        return wishlist
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get wishlist: {str(e)}")

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8004"))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)