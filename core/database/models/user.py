"""
User and Identity Data Models

Implements the new identity-separated schema for BetterBooks users.
Supports Apple App Store and Stripe subscription management.
"""

from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from enum import Enum
from dataclasses import dataclass
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, validator


class IdentityProvider(str, Enum):
    """Supported identity providers"""
    APPLE = "apple"
    GOOGLE = "google"
    EMAIL = "email"
    SUPABASE = "supabase"


class SubscriptionProvider(str, Enum):
    """Subscription providers"""
    APP_STORE = "app_store"
    STRIPE = "stripe"


class SubscriptionStatus(str, Enum):
    """Subscription status values"""
    ACTIVE = "active"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
    GRACE_PERIOD = "grace_period"
    PENDING = "pending"
    PAUSED = "paused"


class EntitlementSource(str, Enum):
    """Source of user entitlements"""
    SUBSCRIPTION = "subscription"
    PROMOTION = "promotion"
    GIFT = "gift"
    TRIAL = "trial"


class AccessType(str, Enum):
    """Types of book access"""
    PURCHASE = "purchase"
    SUBSCRIPTION = "subscription"
    TRIAL = "trial"
    GIFT = "gift"


# =====================================================
# BASE MODELS
# =====================================================

@dataclass
class User:
    """Core user model - identity agnostic"""
    id: UUID
    email: Optional[str] = None  # nullable for Apple private relay
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    deleted_at: Optional[datetime] = None
    
    @property
    def is_active(self) -> bool:
        """Check if user account is active"""
        return self.deleted_at is None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API responses"""
        return {
            "id": str(self.id),
            "email": self.email,
            "display_name": self.display_name,
            "avatar_url": self.avatar_url,
            "created_at": self.created_at.isoformat(),
            "is_active": self.is_active
        }


@dataclass
class Identity:
    """User identity from various providers"""
    id: UUID
    user_id: UUID
    provider: IdentityProvider
    provider_user_id: str
    email_at_auth: Optional[str] = None
    verified: bool = False
    created_at: datetime
    updated_at: datetime


@dataclass
class Subscription:
    """User subscription from App Store or Stripe"""
    id: UUID
    user_id: UUID
    provider: SubscriptionProvider
    status: SubscriptionStatus
    product_id: str
    price_id: Optional[str] = None
    
    # Timing
    current_period_start: Optional[datetime] = None
    current_period_end: Optional[datetime] = None
    cancel_at: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None
    
    # Apple specific
    original_transaction_id: Optional[str] = None
    app_account_token: Optional[UUID] = None
    environment: Optional[str] = None
    
    # Stripe specific
    stripe_subscription_id: Optional[str] = None
    stripe_customer_id: Optional[str] = None
    stripe_price_id: Optional[str] = None
    
    # Trial info
    trial_start: Optional[datetime] = None
    trial_end: Optional[datetime] = None
    
    created_at: datetime
    updated_at: datetime
    
    @property
    def is_active(self) -> bool:
        """Check if subscription is currently active"""
        if self.status != SubscriptionStatus.ACTIVE:
            return False
        
        if self.current_period_end:
            return datetime.now(timezone.utc) < self.current_period_end
        
        return True
    
    @property
    def is_trial(self) -> bool:
        """Check if subscription is in trial period"""
        if not self.trial_start or not self.trial_end:
            return False
        
        now = datetime.now(timezone.utc)
        return self.trial_start <= now <= self.trial_end


@dataclass
class Entitlement:
    """User entitlements (computed from subscriptions)"""
    user_id: UUID
    feature: str
    granted_at: datetime
    expires_at: Optional[datetime] = None
    source: EntitlementSource
    source_id: Optional[UUID] = None
    active: bool = True
    
    @property
    def is_valid(self) -> bool:
        """Check if entitlement is currently valid"""
        if not self.active:
            return False
        
        if self.expires_at:
            return datetime.now(timezone.utc) < self.expires_at
        
        return True


@dataclass 
class UserLibraryEntry:
    """Book in user's library"""
    user_id: UUID
    book_id: str
    acquired_at: datetime
    access_type: AccessType
    access_expires_at: Optional[datetime] = None
    
    # Progress
    last_position_seconds: int = 0
    last_chapter: int = 1
    completed: bool = False
    completion_date: Optional[datetime] = None
    
    # Stats
    total_listening_time: int = 0
    play_count: int = 0
    last_played_at: Optional[datetime] = None
    
    @property
    def has_access(self) -> bool:
        """Check if user still has access to this book"""
        if self.access_expires_at:
            return datetime.now(timezone.utc) < self.access_expires_at
        return True
    
    @property
    def progress_percentage(self) -> float:
        """Calculate listening progress percentage"""
        # This would need total book duration from book metadata
        # For now, return 0-100 based on completion status
        return 100.0 if self.completed else 0.0


# =====================================================
# PYDANTIC MODELS FOR API
# =====================================================

class UserCreate(BaseModel):
    """Create new user account"""
    email: Optional[EmailStr] = None
    display_name: Optional[str] = Field(None, max_length=100)
    avatar_url: Optional[str] = None
    
    @validator('display_name')
    def validate_display_name(cls, v):
        if v and len(v.strip()) == 0:
            return None
        return v


class UserUpdate(BaseModel):
    """Update user account"""
    display_name: Optional[str] = Field(None, max_length=100)
    avatar_url: Optional[str] = None


class IdentityCreate(BaseModel):
    """Link new identity to user"""
    provider: IdentityProvider
    provider_user_id: str
    email_at_auth: Optional[EmailStr] = None


class SubscriptionCreate(BaseModel):
    """Create subscription record"""
    provider: SubscriptionProvider
    product_id: str
    price_id: Optional[str] = None
    app_account_token: Optional[UUID] = None
    original_transaction_id: Optional[str] = None
    stripe_subscription_id: Optional[str] = None


class EntitlementResponse(BaseModel):
    """API response for user entitlements"""
    feature: str
    expires_at: Optional[datetime] = None
    source: EntitlementSource
    is_valid: bool
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class UserEntitlementsResponse(BaseModel):
    """Complete entitlements for a user"""
    user_id: UUID
    entitlements: List[EntitlementResponse]
    subscription: Optional[Dict[str, Any]] = None
    
    class Config:
        json_encoders = {
            UUID: str,
            datetime: lambda v: v.isoformat()
        }


class LibraryEntryResponse(BaseModel):
    """API response for library entry"""
    book_id: str
    acquired_at: datetime
    access_type: AccessType
    has_access: bool
    
    # Progress
    last_position_seconds: int
    last_chapter: int
    completed: bool
    progress_percentage: float
    
    # Stats
    total_listening_time: int
    play_count: int
    last_played_at: Optional[datetime] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class UserLibraryResponse(BaseModel):
    """User's complete library"""
    user_id: UUID
    books: List[LibraryEntryResponse]
    total_books: int
    total_listening_time: int
    
    class Config:
        json_encoders = {
            UUID: str
        }


# =====================================================
# PRODUCT CONFIGURATION
# =====================================================

class SubscriptionPlan:
    """Subscription plan definitions"""
    
    # App Store product IDs (configured in App Store Connect)
    IOS_MONTHLY = "com.betterbooks.monthly"
    IOS_YEARLY = "com.betterbooks.yearly" 
    IOS_FAMILY = "com.betterbooks.family"
    
    # Stripe price IDs (configured in Stripe Dashboard)
    STRIPE_MONTHLY = "price_monthly_999"
    STRIPE_YEARLY = "price_yearly_9999"
    STRIPE_FAMILY = "price_family_1999"
    
    @classmethod
    def get_features(cls, product_id: str) -> List[str]:
        """Get features for a product ID"""
        if "family" in product_id.lower():
            return ["premium_access", "family_sharing", "unlimited_books"]
        elif "yearly" in product_id.lower() or "monthly" in product_id.lower():
            return ["premium_access", "unlimited_books"]
        else:
            return ["basic_access"]
    
    @classmethod
    def is_premium_product(cls, product_id: str) -> bool:
        """Check if product ID is premium tier"""
        premium_products = [
            cls.IOS_MONTHLY, cls.IOS_YEARLY, cls.IOS_FAMILY,
            cls.STRIPE_MONTHLY, cls.STRIPE_YEARLY, cls.STRIPE_FAMILY
        ]
        return product_id in premium_products


# =====================================================
# HELPER FUNCTIONS
# =====================================================

def create_app_account_token() -> UUID:
    """Generate unique token for linking Apple purchases to users"""
    from uuid import uuid4
    return uuid4()


def parse_apple_environment(environment: str) -> str:
    """Normalize Apple environment string"""
    if environment.lower() in ['sandbox', 'xcode']:
        return 'Sandbox'
    return 'Production'


def get_entitlement_features(subscription: Subscription) -> List[str]:
    """Get entitlement features for a subscription"""
    return SubscriptionPlan.get_features(subscription.product_id)


def calculate_trial_period(days: int = 7) -> tuple[datetime, datetime]:
    """Calculate trial start and end dates"""
    start = datetime.now(timezone.utc)
    end = start.replace(hour=23, minute=59, second=59) + timedelta(days=days)
    return start, end