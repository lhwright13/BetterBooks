"""
Bookstore Data Models

Comprehensive data models for EchoWright's audiobook store system.
Supports Audible-like functionality including purchases, credits, reviews,
wishlist, downloads, and recommendation system.
"""

from datetime import datetime, timezone
from typing import Optional, List, Dict, Any, Union
from enum import Enum
from dataclasses import dataclass
from uuid import UUID
from decimal import Decimal

from pydantic import BaseModel, Field, validator


# =====================================================
# ENUMS
# =====================================================

class PurchaseType(str, Enum):
    """Types of book purchases"""
    CREDIT = "credit"
    CASH = "cash" 
    GIFT = "gift"
    SUBSCRIPTION = "subscription"


class PaymentProvider(str, Enum):
    """Payment processing providers"""
    STRIPE = "stripe"
    APPLE = "apple"
    SUBSCRIPTION = "subscription"


class CreditTransactionType(str, Enum):
    """Types of credit transactions"""
    EARNED = "earned"        # Monthly subscription credit
    SPENT = "spent"          # Used to purchase book
    PURCHASED = "purchased"  # Bought with money
    GIFTED = "gifted"        # Given to another user
    RECEIVED = "received"    # Received as gift
    EXPIRED = "expired"      # Credits expired


class DownloadStatus(str, Enum):
    """Download status for offline books"""
    PENDING = "pending"
    DOWNLOADING = "downloading" 
    COMPLETED = "completed"
    FAILED = "failed"


class InteractionType(str, Enum):
    """User interaction types for recommendations"""
    VIEWED = "viewed"
    SAMPLED = "sampled"
    WISHLISTED = "wishlisted"
    PURCHASED = "purchased"


class SimilarityType(str, Enum):
    """Book similarity calculation methods"""
    GENRE = "genre"
    AUTHOR = "author"
    COLLABORATIVE = "collaborative"
    CONTENT = "content"


class DiscountType(str, Enum):
    """Promotional discount types"""
    PERCENTAGE = "percentage"
    FIXED_AMOUNT = "fixed_amount"
    FREE_CREDITS = "free_credits"


# =====================================================
# BOOK CATALOG MODELS
# =====================================================

@dataclass
class BookCatalog:
    """Enhanced book model for store functionality"""
    # Basic book info (inherited from existing books table)
    id: UUID
    title: str
    author: Optional[str] = None
    isbn: Optional[str] = None
    description: Optional[str] = None
    cover_image_url: Optional[str] = None
    audio_file_path: Optional[str] = None
    duration_seconds: Optional[int] = None
    language: str = 'en'
    genre: Optional[str] = None
    publication_date: Optional[datetime] = None
    is_active: bool = True
    
    # Store-specific fields
    price_usd: Decimal = Decimal('14.95')
    credit_price: int = 1
    narrator: Optional[str] = None
    publisher: Optional[str] = None
    sample_audio_url: Optional[str] = None
    sample_duration: Optional[int] = None  # seconds
    release_date: Optional[datetime] = None
    bestseller_rank: Optional[int] = None
    categories: List[str] = None
    tags: List[str] = None
    average_rating: Decimal = Decimal('0.00')
    rating_count: int = 0
    purchase_count: int = 0
    is_featured: bool = False
    file_size_mb: Optional[Decimal] = None
    content_rating: str = 'G'  # G, PG, PG-13, R
    
    # Timestamps
    created_at: datetime
    updated_at: datetime
    
    def __post_init__(self):
        if self.categories is None:
            self.categories = []
        if self.tags is None:
            self.tags = []
    
    @property
    def formatted_price(self) -> str:
        """Format price for display"""
        return f"${self.price_usd:.2f}"
    
    @property
    def formatted_duration(self) -> str:
        """Format duration as HH:MM:SS"""
        if not self.duration_seconds:
            return "Unknown"
        
        hours = self.duration_seconds // 3600
        minutes = (self.duration_seconds % 3600) // 60
        seconds = self.duration_seconds % 60
        
        if hours > 0:
            return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
        else:
            return f"{minutes:02d}:{seconds:02d}"
    
    @property
    def is_bestseller(self) -> bool:
        """Check if book is a bestseller"""
        return self.bestseller_rank is not None and self.bestseller_rank <= 100
    
    @property
    def has_sample(self) -> bool:
        """Check if book has audio sample"""
        return self.sample_audio_url is not None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "title": self.title,
            "author": self.author,
            "narrator": self.narrator,
            "publisher": self.publisher,
            "description": self.description,
            "cover_image_url": self.cover_image_url,
            "sample_audio_url": self.sample_audio_url,
            "sample_duration": self.sample_duration,
            "price_usd": float(self.price_usd),
            "credit_price": self.credit_price,
            "formatted_price": self.formatted_price,
            "duration_seconds": self.duration_seconds,
            "formatted_duration": self.formatted_duration,
            "language": self.language,
            "genre": self.genre,
            "categories": self.categories,
            "tags": self.tags,
            "average_rating": float(self.average_rating),
            "rating_count": self.rating_count,
            "purchase_count": self.purchase_count,
            "is_featured": self.is_featured,
            "is_bestseller": self.is_bestseller,
            "bestseller_rank": self.bestseller_rank,
            "has_sample": self.has_sample,
            "file_size_mb": float(self.file_size_mb) if self.file_size_mb else None,
            "content_rating": self.content_rating,
            "release_date": self.release_date.isoformat() if self.release_date else None,
            "created_at": self.created_at.isoformat()
        }


@dataclass  
class BookCategory:
    """Book category hierarchy"""
    id: UUID
    name: str
    parent_id: Optional[UUID] = None
    description: Optional[str] = None
    icon_name: Optional[str] = None
    display_order: int = 0
    is_active: bool = True
    created_at: datetime
    updated_at: datetime
    
    # For API responses
    subcategories: List['BookCategory'] = None
    book_count: int = 0
    
    def __post_init__(self):
        if self.subcategories is None:
            self.subcategories = []
    
    @property
    def is_root_category(self) -> bool:
        """Check if this is a root category"""
        return self.parent_id is None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "name": self.name,
            "parent_id": str(self.parent_id) if self.parent_id else None,
            "description": self.description,
            "icon_name": self.icon_name,
            "display_order": self.display_order,
            "is_active": self.is_active,
            "is_root_category": self.is_root_category,
            "book_count": self.book_count,
            "subcategories": [cat.to_dict() for cat in self.subcategories]
        }


# =====================================================
# PURCHASE & LIBRARY MODELS
# =====================================================

@dataclass
class UserPurchase:
    """User book purchase record"""
    id: UUID
    user_id: UUID
    book_id: UUID
    purchase_date: datetime
    purchase_type: PurchaseType
    price_paid: Optional[Decimal] = None
    credits_used: int = 0
    transaction_id: Optional[str] = None
    gift_from_user_id: Optional[UUID] = None
    gift_message: Optional[str] = None
    payment_provider: Optional[PaymentProvider] = None
    refund_date: Optional[datetime] = None
    refund_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    # For API responses - populated by service
    book: Optional[BookCatalog] = None
    gift_from_user: Optional[str] = None  # display name
    
    @property
    def is_refunded(self) -> bool:
        """Check if purchase was refunded"""
        return self.refund_date is not None
    
    @property
    def is_gift(self) -> bool:
        """Check if purchase was a gift"""
        return self.gift_from_user_id is not None
    
    @property
    def was_purchased_with_credits(self) -> bool:
        """Check if purchased with credits"""
        return self.purchase_type == PurchaseType.CREDIT and self.credits_used > 0
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "book_id": str(self.book_id),
            "purchase_date": self.purchase_date.isoformat(),
            "purchase_type": self.purchase_type.value,
            "price_paid": float(self.price_paid) if self.price_paid else None,
            "credits_used": self.credits_used,
            "transaction_id": self.transaction_id,
            "is_gift": self.is_gift,
            "gift_from_user": self.gift_from_user,
            "gift_message": self.gift_message,
            "payment_provider": self.payment_provider.value if self.payment_provider else None,
            "is_refunded": self.is_refunded,
            "was_purchased_with_credits": self.was_purchased_with_credits,
            "book": self.book.to_dict() if self.book else None
        }


@dataclass
class UserCredit:
    """User credit balance and allocation"""
    id: UUID
    user_id: UUID
    credits_available: int = 0
    credits_used: int = 0
    credits_gifted: int = 0
    credits_received: int = 0
    next_credit_date: Optional[datetime] = None
    monthly_credits: int = 1
    credits_purchased: int = 0
    total_spent: Decimal = Decimal('0.00')
    created_at: datetime
    updated_at: datetime
    
    @property
    def total_credits_earned(self) -> int:
        """Total credits earned from all sources"""
        return self.credits_used + self.credits_available + self.credits_gifted
    
    @property
    def credits_from_subscription(self) -> int:
        """Credits earned from subscription (not purchased)"""
        return self.total_credits_earned - self.credits_purchased - self.credits_received
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "credits_available": self.credits_available,
            "credits_used": self.credits_used,
            "credits_gifted": self.credits_gifted,
            "credits_received": self.credits_received,
            "next_credit_date": self.next_credit_date.isoformat() if self.next_credit_date else None,
            "monthly_credits": self.monthly_credits,
            "credits_purchased": self.credits_purchased,
            "total_spent": float(self.total_spent),
            "total_credits_earned": self.total_credits_earned,
            "credits_from_subscription": self.credits_from_subscription
        }


@dataclass
class CreditTransaction:
    """Credit transaction history"""
    id: UUID
    user_id: UUID
    transaction_type: CreditTransactionType
    credits_change: int  # positive for gains, negative for spending
    balance_after: int
    book_id: Optional[UUID] = None
    subscription_id: Optional[UUID] = None
    gift_to_user_id: Optional[UUID] = None
    payment_transaction_id: Optional[str] = None
    description: Optional[str] = None
    expires_at: Optional[datetime] = None
    created_at: datetime
    
    # For API responses
    book_title: Optional[str] = None
    gift_to_user_name: Optional[str] = None
    
    @property
    def is_credit_gain(self) -> bool:
        """Check if this transaction added credits"""
        return self.credits_change > 0
    
    @property
    def is_credit_expense(self) -> bool:
        """Check if this transaction used credits"""
        return self.credits_change < 0
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "transaction_type": self.transaction_type.value,
            "credits_change": self.credits_change,
            "balance_after": self.balance_after,
            "book_id": str(self.book_id) if self.book_id else None,
            "book_title": self.book_title,
            "gift_to_user_id": str(self.gift_to_user_id) if self.gift_to_user_id else None,
            "gift_to_user_name": self.gift_to_user_name,
            "description": self.description,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "created_at": self.created_at.isoformat(),
            "is_credit_gain": self.is_credit_gain,
            "is_credit_expense": self.is_credit_expense
        }


# =====================================================
# SOCIAL FEATURES MODELS
# =====================================================

@dataclass
class BookReview:
    """User book review and rating"""
    id: UUID
    book_id: UUID
    user_id: UUID
    rating: int  # 1-5 stars
    review_title: Optional[str] = None
    review_text: Optional[str] = None
    helpful_count: int = 0
    total_votes: int = 0
    verified_purchase: bool = False
    spoiler_warning: bool = False
    is_approved: bool = True
    moderation_reason: Optional[str] = None
    moderator_id: Optional[UUID] = None
    created_at: datetime
    updated_at: datetime
    
    # For API responses
    user_name: Optional[str] = None
    user_avatar_url: Optional[str] = None
    book_title: Optional[str] = None
    user_voted_helpful: Optional[bool] = None  # for current user
    
    @property
    def helpfulness_percentage(self) -> float:
        """Calculate helpfulness percentage"""
        if self.total_votes == 0:
            return 0.0
        return (self.helpful_count / self.total_votes) * 100
    
    @property
    def has_review_text(self) -> bool:
        """Check if review has text content"""
        return bool(self.review_text and self.review_text.strip())
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "book_id": str(self.book_id),
            "book_title": self.book_title,
            "user_id": str(self.user_id),
            "user_name": self.user_name,
            "user_avatar_url": self.user_avatar_url,
            "rating": self.rating,
            "review_title": self.review_title,
            "review_text": self.review_text,
            "has_review_text": self.has_review_text,
            "helpful_count": self.helpful_count,
            "total_votes": self.total_votes,
            "helpfulness_percentage": self.helpfulness_percentage,
            "verified_purchase": self.verified_purchase,
            "spoiler_warning": self.spoiler_warning,
            "is_approved": self.is_approved,
            "user_voted_helpful": self.user_voted_helpful,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat()
        }


@dataclass
class UserWishlist:
    """User wishlist item"""
    id: UUID
    user_id: UUID
    book_id: UUID
    added_date: datetime
    priority: int = 0
    notes: Optional[str] = None
    price_alert_threshold: Optional[Decimal] = None
    created_at: datetime
    updated_at: datetime
    
    # For API responses
    book: Optional[BookCatalog] = None
    price_dropped: bool = False  # if current price < threshold
    
    @property
    def has_price_alert(self) -> bool:
        """Check if price alert is set"""
        return self.price_alert_threshold is not None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "book_id": str(self.book_id),
            "added_date": self.added_date.isoformat(),
            "priority": self.priority,
            "notes": self.notes,
            "price_alert_threshold": float(self.price_alert_threshold) if self.price_alert_threshold else None,
            "has_price_alert": self.has_price_alert,
            "price_dropped": self.price_dropped,
            "book": self.book.to_dict() if self.book else None
        }


# =====================================================
# DOWNLOAD MANAGEMENT MODELS
# =====================================================

@dataclass
class BookDownload:
    """User book download for offline access"""
    id: UUID
    user_id: UUID
    book_id: UUID
    device_id: str
    device_name: Optional[str] = None
    platform: Optional[str] = None  # 'ios', 'android', 'web'
    download_status: DownloadStatus = DownloadStatus.PENDING
    download_progress: Decimal = Decimal('0.00')
    download_started_at: Optional[datetime] = None
    download_completed_at: Optional[datetime] = None
    file_path: Optional[str] = None
    file_size_bytes: Optional[int] = None
    file_format: Optional[str] = None  # 'mp3', 'aac', 'opus'
    quality: Optional[str] = None  # 'low', 'medium', 'high'
    last_accessed_at: Optional[datetime] = None
    play_count: int = 0
    created_at: datetime
    updated_at: datetime
    
    # For API responses
    book: Optional[BookCatalog] = None
    
    @property
    def is_completed(self) -> bool:
        """Check if download is completed"""
        return self.download_status == DownloadStatus.COMPLETED
    
    @property
    def is_downloading(self) -> bool:
        """Check if currently downloading"""
        return self.download_status == DownloadStatus.DOWNLOADING
    
    @property
    def formatted_file_size(self) -> str:
        """Format file size for display"""
        if not self.file_size_bytes:
            return "Unknown"
        
        # Convert bytes to MB/GB
        mb = self.file_size_bytes / (1024 * 1024)
        if mb < 1024:
            return f"{mb:.1f} MB"
        else:
            gb = mb / 1024
            return f"{gb:.1f} GB"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "user_id": str(self.user_id),
            "book_id": str(self.book_id),
            "device_id": self.device_id,
            "device_name": self.device_name,
            "platform": self.platform,
            "download_status": self.download_status.value,
            "download_progress": float(self.download_progress),
            "download_started_at": self.download_started_at.isoformat() if self.download_started_at else None,
            "download_completed_at": self.download_completed_at.isoformat() if self.download_completed_at else None,
            "file_format": self.file_format,
            "quality": self.quality,
            "file_size_bytes": self.file_size_bytes,
            "formatted_file_size": self.formatted_file_size,
            "last_accessed_at": self.last_accessed_at.isoformat() if self.last_accessed_at else None,
            "play_count": self.play_count,
            "is_completed": self.is_completed,
            "is_downloading": self.is_downloading,
            "book": self.book.to_dict() if self.book else None
        }


# =====================================================
# PROMOTIONAL MODELS
# =====================================================

@dataclass
class GiftCard:
    """Gift card for purchasing books or credits"""
    id: UUID
    code: str
    value_usd: Decimal
    credits_value: int
    is_redeemed: bool = False
    redeemed_by_user_id: Optional[UUID] = None
    redeemed_at: Optional[datetime] = None
    purchased_by_user_id: Optional[UUID] = None
    gift_message: Optional[str] = None
    expires_at: Optional[datetime] = None
    created_at: datetime
    
    # For API responses
    redeemed_by_user_name: Optional[str] = None
    purchased_by_user_name: Optional[str] = None
    
    @property
    def is_expired(self) -> bool:
        """Check if gift card is expired"""
        return self.expires_at is not None and self.expires_at < datetime.now(timezone.utc)
    
    @property
    def is_available(self) -> bool:
        """Check if gift card can be redeemed"""
        return not self.is_redeemed and not self.is_expired
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "code": self.code,
            "value_usd": float(self.value_usd),
            "credits_value": self.credits_value,
            "is_redeemed": self.is_redeemed,
            "redeemed_at": self.redeemed_at.isoformat() if self.redeemed_at else None,
            "redeemed_by_user_name": self.redeemed_by_user_name,
            "purchased_by_user_name": self.purchased_by_user_name,
            "gift_message": self.gift_message,
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "is_expired": self.is_expired,
            "is_available": self.is_available,
            "created_at": self.created_at.isoformat()
        }


@dataclass
class PromoCode:
    """Promotional discount code"""
    id: UUID
    code: str
    discount_type: DiscountType
    discount_value: Decimal
    max_uses: Optional[int] = None
    current_uses: int = 0
    max_uses_per_user: int = 1
    is_active: bool = True
    starts_at: datetime
    expires_at: Optional[datetime] = None
    minimum_purchase: Decimal = Decimal('0.00')
    applicable_categories: List[str] = None
    description: Optional[str] = None
    created_at: datetime
    
    def __post_init__(self):
        if self.applicable_categories is None:
            self.applicable_categories = []
    
    @property
    def is_expired(self) -> bool:
        """Check if promo code is expired"""
        return self.expires_at is not None and self.expires_at < datetime.now(timezone.utc)
    
    @property
    def is_available(self) -> bool:
        """Check if promo code can be used"""
        return (self.is_active and 
                not self.is_expired and
                (self.max_uses is None or self.current_uses < self.max_uses))
    
    @property
    def uses_remaining(self) -> Optional[int]:
        """Calculate remaining uses"""
        if self.max_uses is None:
            return None
        return max(0, self.max_uses - self.current_uses)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "code": self.code,
            "discount_type": self.discount_type.value,
            "discount_value": float(self.discount_value),
            "max_uses": self.max_uses,
            "current_uses": self.current_uses,
            "uses_remaining": self.uses_remaining,
            "max_uses_per_user": self.max_uses_per_user,
            "is_active": self.is_active,
            "starts_at": self.starts_at.isoformat(),
            "expires_at": self.expires_at.isoformat() if self.expires_at else None,
            "minimum_purchase": float(self.minimum_purchase),
            "applicable_categories": self.applicable_categories,
            "description": self.description,
            "is_expired": self.is_expired,
            "is_available": self.is_available,
            "created_at": self.created_at.isoformat()
        }


# =====================================================
# REQUEST/RESPONSE MODELS
# =====================================================

class BookSearchFilter(BaseModel):
    """Filter criteria for book search"""
    query: Optional[str] = None
    categories: List[str] = []
    min_price: Optional[Decimal] = None
    max_price: Optional[Decimal] = None
    min_rating: Optional[float] = None
    content_rating: List[str] = []
    has_sample: Optional[bool] = None
    narrator: Optional[str] = None
    language: str = 'en'
    sort_by: str = 'popularity'  # 'popularity', 'price_low', 'price_high', 'rating', 'newest', 'title'
    page: int = 1
    limit: int = 20


class PurchaseRequest(BaseModel):
    """Request to purchase a book"""
    book_id: str
    use_credits: bool = True
    promo_code: Optional[str] = None
    gift_to_user_id: Optional[str] = None
    gift_message: Optional[str] = None


class ReviewSubmission(BaseModel):
    """Request to submit a book review"""
    book_id: str
    rating: int = Field(..., ge=1, le=5)
    review_title: Optional[str] = None
    review_text: Optional[str] = None
    spoiler_warning: bool = False
    
    @validator('review_text')
    def validate_review_text(cls, v):
        if v and len(v) > 5000:
            raise ValueError('Review text cannot exceed 5000 characters')
        return v


class WishlistAddRequest(BaseModel):
    """Request to add book to wishlist"""
    book_id: str
    priority: int = 0
    notes: Optional[str] = None
    price_alert_threshold: Optional[Decimal] = None