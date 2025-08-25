"""
Bookstore Package

Core components for EchoWright's audiobook store functionality:
- Book catalog management
- Purchase and credit system
- User library and wishlist
- Reviews and ratings
- Download management
- Recommendation engine
"""

from .models import (
    BookCatalog, BookCategory, UserPurchase, UserCredit, CreditTransaction,
    BookReview, UserWishlist, BookDownload, GiftCard, PromoCode
)
from .bookstore_service import BookstoreService
from .purchase_service import PurchaseService
from .credit_manager import CreditManager
from .recommendation_engine import RecommendationEngine

__all__ = [
    # Models
    'BookCatalog',
    'BookCategory', 
    'UserPurchase',
    'UserCredit',
    'CreditTransaction',
    'BookReview',
    'UserWishlist',
    'BookDownload',
    'GiftCard',
    'PromoCode',
    
    # Services
    'BookstoreService',
    'PurchaseService', 
    'CreditManager',
    'RecommendationEngine',
]