"""
Enhanced Bookstore API Routes
Proxies requests to the dedicated Bookstore Service and Storage Service
"""

import logging
import httpx
import os
from typing import List, Optional, Dict, Any
from datetime import datetime

from fastapi import APIRouter, HTTPException, Depends, Query, Form, File, UploadFile
from fastapi.responses import RedirectResponse, JSONResponse
from pydantic import BaseModel

logger = logging.getLogger(__name__)

# Service URLs
BOOKSTORE_URL = os.getenv("BOOKSTORE_SERVICE_URL", "http://bookstore_service:8004")
STORAGE_URL = os.getenv("STORAGE_SERVICE_URL", "http://storage_service:8005")

# Initialize router
router = APIRouter(prefix="/v2/bookstore", tags=["bookstore-v2"])

# HTTP client for service communication
http_client = httpx.AsyncClient(timeout=30.0)

# Models for API responses
class BookResponse(BaseModel):
    id: str
    title: str
    author: Optional[str] = None
    narrator: Optional[str] = None
    publisher: Optional[str] = None
    description: Optional[str] = None
    duration_minutes: Optional[int] = None
    language: str = "en"
    isbn: Optional[str] = None
    cover_image_url: Optional[str] = None
    sample_audio_url: Optional[str] = None
    sample_duration: int = 180
    price_usd: float
    credit_price: int
    category: Optional[Dict[str, Any]] = None
    is_featured: bool = False
    is_bestseller: bool = False
    is_new_release: bool = False
    publication_date: Optional[datetime] = None
    total_chapters: int = 1
    file_size_bytes: Optional[int] = None
    average_rating: float = 0.0
    review_count: int = 0
    purchase_count: int = 0

class CatalogResponse(BaseModel):
    books: List[BookResponse]
    total_count: int
    limit: int
    offset: int
    has_next: bool = False
    has_previous: bool = False

class PurchaseRequest(BaseModel):
    user_id: str
    book_id: str
    purchase_type: str = "credit"
    credits_to_use: Optional[int] = None

class PurchaseResponse(BaseModel):
    success: bool
    message: str
    purchase_id: str
    book: BookResponse
    credits_used: int = 0
    price_paid: float = 0.0
    remaining_credits: int
    download_url: Optional[str] = None

class UserLibraryResponse(BaseModel):
    user_id: str
    books: List[BookResponse]
    total_books: int

class CreditBalanceResponse(BaseModel):
    user_id: str
    total_credits: int
    used_credits: int
    available_credits: int

async def proxy_request(url: str, method: str = "GET", **kwargs):
    """Proxy request to backend service"""
    try:
        response = await http_client.request(method, url, **kwargs)
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error proxying to {url}: {e}")
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Error proxying to {url}: {e}")
        raise HTTPException(status_code=500, detail="Service unavailable")

# Book catalog endpoints
@router.get("/catalog", response_model=CatalogResponse)
async def get_book_catalog(
    category_id: Optional[str] = Query(None),
    featured: Optional[bool] = Query(None),
    bestseller: Optional[bool] = Query(None),
    new_release: Optional[bool] = Query(None),
    limit: int = Query(20, le=100),
    offset: int = Query(0, ge=0)
):
    """Get paginated book catalog with optional filtering"""
    params = {
        "limit": limit,
        "offset": offset
    }
    
    if category_id:
        params["category_id"] = category_id
    if featured is not None:
        params["featured"] = featured
    if bestseller is not None:
        params["bestseller"] = bestseller
    if new_release is not None:
        params["new_release"] = new_release
    
    url = f"{BOOKSTORE_URL}/books/catalog"
    return await proxy_request(url, params=params)

@router.get("/books/{book_id}", response_model=BookResponse)
async def get_book_details(book_id: str):
    """Get detailed information about a specific book"""
    url = f"{BOOKSTORE_URL}/books/{book_id}"
    return await proxy_request(url)

@router.post("/search", response_model=CatalogResponse)
async def search_books(
    search_text: str = Query(..., min_length=1),
    category_id: Optional[str] = Query(None),
    limit: int = Query(20, le=100),
    offset: int = Query(0, ge=0)
):
    """Search books by title, author, or description"""
    search_data = {
        "search_text": search_text,
        "limit": limit,
        "offset": offset
    }
    
    if category_id:
        search_data["category_id"] = category_id
    
    url = f"{BOOKSTORE_URL}/books/search"
    return await proxy_request(url, method="POST", json=search_data)

@router.get("/categories")
async def get_book_categories():
    """Get all book categories"""
    url = f"{BOOKSTORE_URL}/books/categories"
    return await proxy_request(url)

# Purchase endpoints
@router.post("/purchase", response_model=PurchaseResponse)
async def purchase_book(purchase: PurchaseRequest):
    """Purchase a book using credits or cash"""
    url = f"{BOOKSTORE_URL}/purchase"
    return await proxy_request(url, method="POST", json=purchase.dict())

# User library endpoints
@router.get("/library/{user_id}", response_model=UserLibraryResponse)
async def get_user_library(user_id: str):
    """Get user's purchased books"""
    url = f"{BOOKSTORE_URL}/library/{user_id}"
    return await proxy_request(url)

@router.get("/credits/{user_id}", response_model=CreditBalanceResponse)
async def get_credit_balance(user_id: str):
    """Get user's credit balance"""
    url = f"{BOOKSTORE_URL}/credits/{user_id}"
    return await proxy_request(url)

@router.post("/credits/{user_id}/add")
async def add_credits(user_id: str, credits: int):
    """Add credits to user account (admin function)"""
    url = f"{BOOKSTORE_URL}/credits/{user_id}/add"
    params = {"credits": credits}
    return await proxy_request(url, method="POST", params=params)

# Wishlist endpoints
@router.post("/wishlist/{user_id}/{book_id}")
async def add_to_wishlist(user_id: str, book_id: str):
    """Add book to user's wishlist"""
    url = f"{BOOKSTORE_URL}/wishlist/{user_id}/{book_id}"
    return await proxy_request(url, method="POST")

@router.delete("/wishlist/{user_id}/{book_id}")
async def remove_from_wishlist(user_id: str, book_id: str):
    """Remove book from user's wishlist"""
    url = f"{BOOKSTORE_URL}/wishlist/{user_id}/{book_id}"
    return await proxy_request(url, method="DELETE")

@router.get("/wishlist/{user_id}")
async def get_wishlist(user_id: str):
    """Get user's wishlist"""
    url = f"{BOOKSTORE_URL}/wishlist/{user_id}"
    return await proxy_request(url)

# Download endpoints (proxy to storage service)
@router.post("/download")
async def get_download_url(user_id: str, book_id: str):
    """Generate secure download URL for a book"""
    download_data = {
        "user_id": user_id,
        "book_id": book_id
    }
    url = f"{STORAGE_URL}/download"
    return await proxy_request(url, method="POST", json=download_data)

@router.get("/download/{book_id}")
async def redirect_download(book_id: str, user: str, token: str):
    """Redirect to actual download URL"""
    url = f"{STORAGE_URL}/download/{book_id}"
    params = {"user": user, "token": token}
    
    try:
        response = await http_client.get(url, params=params, follow_redirects=False)
        if response.status_code == 302:
            return RedirectResponse(url=response.headers.get("location"))
        else:
            return JSONResponse(
                status_code=response.status_code,
                content=response.json() if response.content else {"error": "Download failed"}
            )
    except Exception as e:
        logger.error(f"Error redirecting download: {e}")
        raise HTTPException(status_code=500, detail="Download failed")

# Management endpoints (admin only - would need auth middleware in production)
@router.post("/admin/upload")
async def upload_book_admin(
    book_id: str = Form(...),
    title: str = Form(...),
    file: UploadFile = File(...)
):
    """Upload a book file (admin function)"""
    url = f"{STORAGE_URL}/upload"
    
    files = {"file": (file.filename, file.file, file.content_type)}
    data = {"book_id": book_id, "title": title}
    
    try:
        response = await http_client.post(url, files=files, data=data)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        logger.error(f"Error uploading book: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

@router.get("/admin/stats/storage")
async def get_storage_stats():
    """Get storage usage statistics (admin function)"""
    url = f"{STORAGE_URL}/stats/storage"
    return await proxy_request(url)

@router.get("/admin/stats/bandwidth")
async def get_bandwidth_usage(
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None)
):
    """Get bandwidth usage statistics (admin function)"""
    params = {}
    if start_date:
        params["start_date"] = start_date
    if end_date:
        params["end_date"] = end_date
    
    url = f"{STORAGE_URL}/stats/bandwidth"
    return await proxy_request(url, params=params)

# Health check endpoints
@router.get("/health")
async def bookstore_health():
    """Check health of bookstore services"""
    try:
        bookstore_health = await proxy_request(f"{BOOKSTORE_URL}/health")
        storage_health = await proxy_request(f"{STORAGE_URL}/health")
        
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "services": {
                "bookstore": bookstore_health,
                "storage": storage_health
            }
        }
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "timestamp": datetime.utcnow().isoformat(),
                "error": str(e)
            }
        )

# Cleanup function for the HTTP client
async def cleanup_http_client():
    """Cleanup HTTP client on shutdown"""
    await http_client.aclose()

# Add this to your main app's shutdown event
# app.add_event_handler("shutdown", cleanup_http_client)