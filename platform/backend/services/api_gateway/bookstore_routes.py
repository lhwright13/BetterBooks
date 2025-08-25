"""
Bookstore API Routes

Comprehensive REST API endpoints for the EchoWright audiobook store.
Provides Audible-like functionality including browsing, purchasing,
wishlist, reviews, and download management.
"""

import logging
from typing import Dict, List, Optional, Any
from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, Query, Path, Body
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field

# Core services
from core.bookstore.bookstore_service import BookstoreService
from core.bookstore.purchase_service import PurchaseService
from core.bookstore.credit_manager import CreditManager
from core.bookstore.models import BookSearchFilter, PurchaseRequest, ReviewSubmission, WishlistAddRequest
from core.database.database_manager import DatabaseManager
from auth_routes import get_current_user  # Import from local auth module

logger = logging.getLogger(__name__)

# Initialize router
router = APIRouter(prefix="/bookstore", tags=["bookstore"])
security = HTTPBearer()


# =====================================================
# DEPENDENCY INJECTION
# =====================================================

def get_bookstore_service() -> BookstoreService:
    """Get bookstore service instance"""
    # Import db_manager from the main application
    import sys
    main_module = sys.modules.get('api_gateway.main') or sys.modules.get('main')
    if main_module and hasattr(main_module, 'db_manager'):
        db_manager = main_module.db_manager
        if db_manager:
            return BookstoreService(db_manager)
    raise HTTPException(status_code=503, detail="Database manager not available")


def get_purchase_service() -> PurchaseService:
    """Get purchase service instance"""
    import sys
    main_module = sys.modules.get('api_gateway.main') or sys.modules.get('main')
    if main_module and hasattr(main_module, 'db_manager'):
        db_manager = main_module.db_manager
        if db_manager:
            bookstore_service = BookstoreService(db_manager)
            return PurchaseService(db_manager, bookstore_service)
    raise HTTPException(status_code=503, detail="Database manager not available")


def get_credit_manager() -> CreditManager:
    """Get credit manager instance"""
    import sys
    main_module = sys.modules.get('api_gateway.main') or sys.modules.get('main')
    if main_module and hasattr(main_module, 'db_manager'):
        db_manager = main_module.db_manager
        if db_manager:
            return CreditManager(db_manager)
    raise HTTPException(status_code=503, detail="Database manager not available")


# =====================================================
# REQUEST/RESPONSE MODELS
# =====================================================

class BookResponse(BaseModel):
    """API response for book details"""
    id: str
    title: str
    author: Optional[str]
    narrator: Optional[str]
    publisher: Optional[str]
    description: Optional[str]
    cover_image_url: Optional[str]
    sample_audio_url: Optional[str]
    sample_duration: Optional[int]
    price_usd: float
    credit_price: int
    formatted_price: str
    duration_seconds: Optional[int]
    formatted_duration: str
    language: str
    genre: Optional[str]
    categories: List[str]
    tags: List[str]
    average_rating: float
    rating_count: int
    purchase_count: int
    is_featured: bool
    is_bestseller: bool
    bestseller_rank: Optional[int]
    has_sample: bool
    file_size_mb: Optional[float]
    content_rating: str
    release_date: Optional[str]


class BrowseResponse(BaseModel):
    """Response for book browsing endpoints"""
    books: List[BookResponse]
    total_count: int
    page: int
    limit: int
    has_more: bool


class CategoryResponse(BaseModel):
    """Response for category information"""
    id: str
    name: str
    parent_id: Optional[str]
    description: Optional[str]
    icon_name: Optional[str]
    display_order: int
    book_count: int
    subcategories: List['CategoryResponse'] = []


class PurchaseResponse(BaseModel):
    """Response for purchase operations"""
    success: bool
    purchase_id: str
    book_id: str
    book_title: str
    purchase_type: str
    credits_used: Optional[int] = None
    amount_paid: Optional[float] = None
    credits_remaining: Optional[int] = None
    status: str = "completed"
    is_gift: bool = False


class CreditBalanceResponse(BaseModel):
    """Response for credit balance information"""
    credits_available: int
    credits_used: int
    credits_gifted: int
    credits_received: int
    next_credit_date: Optional[str]
    monthly_credits: int
    credits_purchased: int
    total_spent: float


# =====================================================
# BOOK BROWSING ENDPOINTS
# =====================================================

@router.get("/browse", response_model=BrowseResponse)
async def browse_books(
    category_id: Optional[str] = Query(None, description="Filter by category ID"),
    featured: bool = Query(False, description="Show only featured books"),
    bestsellers: bool = Query(False, description="Show only bestsellers"),
    new_releases: bool = Query(False, description="Show only new releases"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Browse books with various filtering options
    """
    try:
        offset = (page - 1) * limit
        
        category_uuid = UUID(category_id) if category_id else None
        
        books, total_count = await bookstore.browse_books(
            category_id=category_uuid,
            featured_only=featured,
            bestsellers_only=bestsellers,
            new_releases_only=new_releases,
            limit=limit,
            offset=offset
        )
        
        book_responses = [BookResponse(**book.to_dict()) for book in books]
        
        return BrowseResponse(
            books=book_responses,
            total_count=total_count,
            page=page,
            limit=limit,
            has_more=(offset + limit) < total_count
        )
        
    except Exception as e:
        logger.error(f"Browse books failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to browse books")


@router.get("/search", response_model=BrowseResponse)
async def search_books(
    q: Optional[str] = Query(None, description="Search query"),
    categories: Optional[List[str]] = Query(None, description="Filter by category IDs"),
    min_price: Optional[float] = Query(None, ge=0, description="Minimum price"),
    max_price: Optional[float] = Query(None, ge=0, description="Maximum price"),
    min_rating: Optional[float] = Query(None, ge=0, le=5, description="Minimum rating"),
    content_rating: Optional[List[str]] = Query(None, description="Content ratings (G, PG, PG-13, R)"),
    has_sample: Optional[bool] = Query(None, description="Has audio sample"),
    narrator: Optional[str] = Query(None, description="Filter by narrator"),
    language: str = Query("en", description="Language code"),
    sort_by: str = Query("popularity", description="Sort order"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Search books with advanced filtering
    """
    try:
        search_filter = BookSearchFilter(
            query=q,
            categories=categories or [],
            min_price=min_price,
            max_price=max_price,
            min_rating=min_rating,
            content_rating=content_rating or [],
            has_sample=has_sample,
            narrator=narrator,
            language=language,
            sort_by=sort_by,
            page=page,
            limit=limit
        )
        
        books, total_count = await bookstore.search_books(search_filter)
        
        book_responses = [BookResponse(**book.to_dict()) for book in books]
        
        return BrowseResponse(
            books=book_responses,
            total_count=total_count,
            page=page,
            limit=limit,
            has_more=(page * limit) < total_count
        )
        
    except Exception as e:
        logger.error(f"Search books failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to search books")


@router.get("/book/{book_id}", response_model=BookResponse)
async def get_book_details(
    book_id: str = Path(..., description="Book ID"),
    user: Optional[User] = Depends(get_current_user),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Get detailed information for a specific book
    """
    try:
        book = await bookstore.get_book_details(UUID(book_id))
        
        if not book:
            raise HTTPException(status_code=404, detail="Book not found")
        
        # Track user interaction for recommendations
        if user:
            await bookstore.track_user_interaction(
                user.id, book.id, "viewed", source="details_page"
            )
        
        return BookResponse(**book.to_dict())
        
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid book ID format")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get book details failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get book details")


@router.get("/categories", response_model=List[CategoryResponse])
async def get_categories(
    include_counts: bool = Query(True, description="Include book counts"),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Get all book categories with hierarchy
    """
    try:
        categories = await bookstore.get_categories(include_book_counts=include_counts)
        
        return [CategoryResponse(**cat.to_dict()) for cat in categories]
        
    except Exception as e:
        logger.error(f"Get categories failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get categories")


@router.get("/featured", response_model=List[BookResponse])
async def get_featured_books(
    limit: int = Query(10, ge=1, le=50, description="Number of featured books"),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Get featured books for homepage
    """
    try:
        books = await bookstore.get_featured_books(limit=limit)
        
        return [BookResponse(**book.to_dict()) for book in books]
        
    except Exception as e:
        logger.error(f"Get featured books failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get featured books")


@router.get("/bestsellers", response_model=List[BookResponse])
async def get_bestsellers(
    limit: int = Query(50, ge=1, le=100, description="Number of bestsellers"),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Get current bestseller list
    """
    try:
        books = await bookstore.get_bestsellers(limit=limit)
        
        return [BookResponse(**book.to_dict()) for book in books]
        
    except Exception as e:
        logger.error(f"Get bestsellers failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get bestsellers")


@router.get("/new-releases", response_model=List[BookResponse])
async def get_new_releases(
    limit: int = Query(20, ge=1, le=50, description="Number of new releases"),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Get new book releases
    """
    try:
        books = await bookstore.get_new_releases(limit=limit)
        
        return [BookResponse(**book.to_dict()) for book in books]
        
    except Exception as e:
        logger.error(f"Get new releases failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get new releases")


@router.get("/recommendations", response_model=List[BookResponse])
async def get_recommendations(
    limit: int = Query(20, ge=1, le=50, description="Number of recommendations"),
    user: User = Depends(require_auth),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Get personalized book recommendations for user
    """
    try:
        books = await bookstore.get_recommendations_for_user(user.id, limit=limit)
        
        return [BookResponse(**book.to_dict()) for book in books]
        
    except Exception as e:
        logger.error(f"Get recommendations failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get recommendations")


# =====================================================
# PURCHASE ENDPOINTS
# =====================================================

@router.post("/purchase", response_model=PurchaseResponse)
async def purchase_book(
    purchase_request: PurchaseRequest,
    user: User = Depends(require_auth),
    purchase_service: PurchaseService = Depends(get_purchase_service)
):
    """
    Purchase a book with credits or money
    """
    try:
        result = await purchase_service.purchase_book(user.id, purchase_request)
        
        return PurchaseResponse(**result)
        
    except Exception as e:
        logger.error(f"Purchase failed: {e}")
        
        if "already own" in str(e).lower():
            raise HTTPException(status_code=409, detail="You already own this book")
        elif "insufficient credits" in str(e).lower():
            raise HTTPException(status_code=402, detail="Insufficient credits")
        else:
            raise HTTPException(status_code=500, detail="Purchase failed")


@router.post("/gift", response_model=PurchaseResponse)
async def gift_book(
    book_id: str,
    to_user_id: str,
    gift_message: Optional[str] = None,
    use_credits: bool = True,
    user: User = Depends(require_auth),
    purchase_service: PurchaseService = Depends(get_purchase_service)
):
    """
    Gift a book to another user
    """
    try:
        result = await purchase_service.gift_book(
            from_user_id=user.id,
            to_user_id=UUID(to_user_id),
            book_id=UUID(book_id),
            gift_message=gift_message,
            use_credits=use_credits
        )
        
        return PurchaseResponse(**result)
        
    except Exception as e:
        logger.error(f"Gift failed: {e}")
        raise HTTPException(status_code=500, detail="Gift failed")


# =====================================================
# CREDIT MANAGEMENT ENDPOINTS
# =====================================================

@router.get("/credits/balance", response_model=CreditBalanceResponse)
async def get_credit_balance(
    user: User = Depends(require_auth),
    purchase_service: PurchaseService = Depends(get_purchase_service)
):
    """
    Get user's current credit balance
    """
    try:
        user_credits = await purchase_service.get_user_credits(user.id)
        
        return CreditBalanceResponse(**user_credits.to_dict())
        
    except Exception as e:
        logger.error(f"Get credit balance failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get credit balance")


@router.get("/credits/history")
async def get_credit_history(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    user: User = Depends(require_auth),
    purchase_service: PurchaseService = Depends(get_purchase_service)
):
    """
    Get user's credit transaction history
    """
    try:
        offset = (page - 1) * limit
        transactions, total_count = await purchase_service.get_credit_transaction_history(
            user.id, limit=limit, offset=offset
        )
        
        return {
            "transactions": [t.to_dict() for t in transactions],
            "total_count": total_count,
            "page": page,
            "limit": limit,
            "has_more": (offset + limit) < total_count
        }
        
    except Exception as e:
        logger.error(f"Get credit history failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get credit history")


# =====================================================
# USER LIBRARY ENDPOINTS
# =====================================================

@router.get("/library/purchases")
async def get_user_purchases(
    include_gifts: bool = Query(True, description="Include gifted books"),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    user: User = Depends(require_auth),
    purchase_service: PurchaseService = Depends(get_purchase_service)
):
    """
    Get user's purchase history
    """
    try:
        offset = (page - 1) * limit
        purchases, total_count = await purchase_service.get_user_purchases(
            user.id, include_gifts=include_gifts, limit=limit, offset=offset
        )
        
        return {
            "purchases": [p.to_dict() for p in purchases],
            "total_count": total_count,
            "page": page,
            "limit": limit,
            "has_more": (offset + limit) < total_count
        }
        
    except Exception as e:
        logger.error(f"Get user purchases failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to get purchases")


@router.get("/library/owns/{book_id}")
async def check_book_ownership(
    book_id: str = Path(..., description="Book ID"),
    user: User = Depends(require_auth),
    purchase_service: PurchaseService = Depends(get_purchase_service)
):
    """
    Check if user owns a specific book
    """
    try:
        owns_book = await purchase_service.user_owns_book(user.id, UUID(book_id))
        
        return {"owns_book": owns_book}
        
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid book ID format")
    except Exception as e:
        logger.error(f"Check ownership failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to check ownership")


# =====================================================
# WISHLIST ENDPOINTS
# =====================================================

@router.get("/wishlist")
async def get_wishlist(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    user: User = Depends(require_auth)
):
    """
    Get user's wishlist
    """
    # TODO: Implement wishlist service
    return {"message": "Wishlist endpoint coming soon"}


@router.post("/wishlist/add")
async def add_to_wishlist(
    wishlist_request: WishlistAddRequest,
    user: User = Depends(require_auth)
):
    """
    Add book to user's wishlist
    """
    # TODO: Implement wishlist service
    return {"message": "Add to wishlist endpoint coming soon"}


@router.delete("/wishlist/remove/{book_id}")
async def remove_from_wishlist(
    book_id: str = Path(..., description="Book ID"),
    user: User = Depends(require_auth)
):
    """
    Remove book from user's wishlist
    """
    # TODO: Implement wishlist service
    return {"message": "Remove from wishlist endpoint coming soon"}


# =====================================================
# REVIEW ENDPOINTS
# =====================================================

@router.post("/reviews/create")
async def create_review(
    review: ReviewSubmission,
    user: User = Depends(require_auth)
):
    """
    Create a book review
    """
    # TODO: Implement review service
    return {"message": "Review creation endpoint coming soon"}


@router.get("/reviews/{book_id}")
async def get_book_reviews(
    book_id: str = Path(..., description="Book ID"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    sort_by: str = Query("helpful", description="Sort by: helpful, newest, rating")
):
    """
    Get reviews for a book
    """
    # TODO: Implement review service
    return {"message": "Book reviews endpoint coming soon"}


# =====================================================
# ADMIN ENDPOINTS (for testing and management)
# =====================================================

@router.post("/admin/allocate-credits/{user_id}")
async def admin_allocate_credits(
    user_id: str = Path(..., description="User ID"),
    credits: int = Body(..., description="Credits to allocate"),
    admin_user: User = Depends(require_auth),  # TODO: Add admin check
    credit_manager: CreditManager = Depends(get_credit_manager)
):
    """
    Admin endpoint to manually allocate credits
    """
    try:
        await credit_manager.add_credits_to_user(
            UUID(user_id), credits, "earned", "Manual admin allocation"
        )
        
        return {"success": True, "credits_allocated": credits}
        
    except Exception as e:
        logger.error(f"Admin credit allocation failed: {e}")
        raise HTTPException(status_code=500, detail="Credit allocation failed")


# =====================================================
# INTERACTION TRACKING
# =====================================================

@router.post("/track-interaction/{book_id}")
async def track_book_interaction(
    book_id: str = Path(..., description="Book ID"),
    interaction_type: str = Body(..., description="Interaction type"),
    duration_seconds: Optional[int] = Body(None, description="Duration in seconds"),
    source: str = Body("unknown", description="Source of interaction"),
    user: Optional[User] = Depends(get_current_user),
    bookstore: BookstoreService = Depends(get_bookstore_service)
):
    """
    Track user interaction with a book for recommendations
    """
    if not user:
        return {"success": False, "reason": "User not authenticated"}
    
    try:
        await bookstore.track_user_interaction(
            user.id, UUID(book_id), interaction_type, 
            source=source, duration_seconds=duration_seconds
        )
        
        return {"success": True}
        
    except Exception as e:
        logger.error(f"Interaction tracking failed: {e}")
        return {"success": False, "reason": "Tracking failed"}


# Update forward references for nested models
CategoryResponse.model_rebuild()