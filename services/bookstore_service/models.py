"""
Bookstore Service Data Models
Pydantic models for API requests and responses
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
from decimal import Decimal
from enum import Enum

class PurchaseType(str, Enum):
    CREDIT = "credit"
    CASH = "cash"
    GIFT = "gift"
    SUBSCRIPTION = "subscription"

class BookCategory(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    display_order: int = 0
    is_active: bool = True
    book_count: Optional[int] = None  # Number of books in this category

class Book(BaseModel):
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
    price_usd: Decimal = Field(default=Decimal("14.95"))
    credit_price: int = 1
    category: Optional[BookCategory] = None
    is_featured: bool = False
    is_bestseller: bool = False
    is_new_release: bool = False
    publication_date: Optional[datetime] = None
    
    # Cloud storage fields
    blob_container: Optional[str] = None
    blob_path: Optional[str] = None
    cdn_url: Optional[str] = None
    
    # Metadata
    total_chapters: int = 1
    file_size_bytes: Optional[int] = None
    average_rating: Decimal = Field(default=Decimal("0.0"))
    review_count: int = 0
    purchase_count: int = 0
    
    # User-specific fields (set when fetching user library)
    purchase_date: Optional[datetime] = None
    download_url: Optional[str] = None  # Temporary download URL
    download_expires: Optional[datetime] = None
    
    class Config:
        from_attributes = True
        json_encoders = {
            Decimal: lambda v: float(v),
            datetime: lambda v: v.isoformat()
        }

class BookCatalogResponse(BaseModel):
    books: List[Book]
    total_count: int
    limit: int
    offset: int
    has_next: bool = False
    has_previous: bool = False
    
    def __init__(self, **data):
        super().__init__(**data)
        self.has_next = (self.offset + self.limit) < self.total_count
        self.has_previous = self.offset > 0

class BookSearchQuery(BaseModel):
    search_text: str = Field(min_length=1)
    category_id: Optional[str] = None
    limit: int = Field(default=20, le=100)
    offset: int = Field(default=0, ge=0)

class PurchaseRequest(BaseModel):
    user_id: str
    book_id: str
    purchase_type: PurchaseType
    credits_to_use: Optional[int] = None

class PurchaseResponse(BaseModel):
    success: bool
    message: str
    purchase_id: str
    book: Book
    credits_used: int = 0
    price_paid: Decimal = Field(default=Decimal("0.0"))
    remaining_credits: int
    download_url: Optional[str] = None
    download_expires: Optional[datetime] = None
    
    class Config:
        json_encoders = {
            Decimal: lambda v: float(v),
            datetime: lambda v: v.isoformat()
        }

class UserPurchase(BaseModel):
    id: str
    book: Book
    purchase_date: datetime
    purchase_type: PurchaseType
    price_paid: Decimal
    credits_used: int
    
    class Config:
        from_attributes = True
        json_encoders = {
            Decimal: lambda v: float(v),
            datetime: lambda v: v.isoformat()
        }

class UserLibrary(BaseModel):
    user_id: str
    books: List[Book]
    total_books: int
    recent_purchases: List[UserPurchase] = []

class CreditBalance(BaseModel):
    user_id: str
    total_credits: int
    used_credits: int
    available_credits: int
    last_updated: datetime
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class DownloadRequest(BaseModel):
    user_id: str
    book_id: str

class DownloadResponse(BaseModel):
    download_url: str
    expires_at: datetime
    file_size_bytes: Optional[int] = None
    chapters: Optional[List[Dict[str, Any]]] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class WishlistItem(BaseModel):
    id: str
    user_id: str
    book: Book
    added_at: datetime
    
    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

# Statistics models
class BookStats(BaseModel):
    book_id: str
    total_purchases: int
    total_downloads: int
    total_revenue: Decimal
    average_rating: Decimal
    recent_purchases: int  # Last 30 days
    
    class Config:
        json_encoders = {
            Decimal: lambda v: float(v)
        }

class UserStats(BaseModel):
    user_id: str
    total_purchases: int
    total_spent: Decimal
    credits_purchased: int
    favorite_category: Optional[str] = None
    last_purchase_date: Optional[datetime] = None
    
    class Config:
        json_encoders = {
            Decimal: lambda v: float(v),
            datetime: lambda v: v.isoformat() if v else None
        }