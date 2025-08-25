# Bookstore Module

Core e-commerce functionality for the EchoWright audiobook platform. Provides comprehensive book catalog management, purchase system, user credits, reviews, recommendations, and download management similar to Audible's functionality.

## Features

### 📚 Book Catalog Management
- **Book Browsing** - Category-based navigation and discovery
- **Advanced Search** - Multi-criteria search with filters
- **Metadata Management** - Authors, narrators, genres, descriptions
- **Pricing & Promotions** - Dynamic pricing, discounts, promo codes
- **Content Ratings** - Age ratings and content warnings

### 💳 Purchase & Payment System
- **Credit System** - User credits for book purchases
- **Multiple Payment Methods** - Credit card, PayPal, Apple Pay integration
- **Gift Cards** - Purchasable and redeemable gift cards
- **Subscription Tiers** - Free, Premium, Educational pricing
- **Transaction History** - Complete purchase and credit records

### 👤 User Library Management
- **Personal Library** - Owned books collection
- **Wishlist** - Save books for later purchase
- **Download Management** - Track and manage audio file downloads
- **Listening Progress** - Chapter progress and bookmarks
- **Collections** - User-created book collections

### ⭐ Reviews & Social Features
- **Book Reviews** - User ratings and written reviews
- **Review Moderation** - Content filtering and reporting
- **Social Sharing** - Share books and reviews
- **Reading Lists** - Curated book recommendations

### 🤖 AI-Powered Recommendations
- **Personalized Suggestions** - ML-based book recommendations
- **Similar Books** - Content-based filtering
- **Trending Content** - Popular and bestselling books
- **Smart Collections** - Auto-generated themed collections

## Architecture

```mermaid
graph TD
    A[BookstoreService] --> B[Book Catalog]
    A --> C[Search & Discovery]
    
    D[PurchaseService] --> E[Payment Processing]
    D --> F[Transaction Records]
    
    G[CreditManager] --> H[User Credits]
    G --> I[Gift Cards]
    G --> J[Promo Codes]
    
    K[RecommendationEngine] --> L[User Preferences]
    K --> M[Content Analysis]
    K --> N[ML Models]
    
    O[Database Layer] --> P[PostgreSQL]
    O --> Q[Redis Cache]
```

## Quick Start

### Basic Setup

```python
from core.database.database_manager import DatabaseManager
from core.bookstore import BookstoreService, PurchaseService, CreditManager

# Initialize database connection
db_manager = DatabaseManager("postgresql://user:pass@localhost/echowright")

# Initialize bookstore services
bookstore = BookstoreService(db_manager)
purchase_service = PurchaseService(db_manager)
credit_manager = CreditManager(db_manager)
```

### Browse Books

```python
# Browse all books with pagination
books, total = await bookstore.browse_books(limit=20, offset=0)

# Browse by category
sci_fi_books, count = await bookstore.browse_books(
    category_id=category_id, 
    limit=10
)

# Get featured books
featured, count = await bookstore.browse_books(
    featured_only=True,
    limit=5
)

# Get bestsellers
bestsellers, count = await bookstore.browse_books(
    bestsellers_only=True,
    limit=10
)
```

### Search Functionality

```python
from core.bookstore.models import BookSearchFilter

# Create search filter
search_filter = BookSearchFilter(
    query="science fiction",
    author="isaac asimov",
    narrator="scott brick",
    min_price=Decimal("10.00"),
    max_price=Decimal("25.00"),
    min_rating=4.0,
    categories=["science-fiction", "classics"]
)

# Search books
results, total = await bookstore.search_books(
    search_filter=search_filter,
    limit=20,
    offset=0
)
```

## API Usage

### BookstoreService

#### Browse Books by Category

```python
# Get book categories
categories = await bookstore.get_categories()

# Browse category
books, total = await bookstore.browse_books(
    category_id=categories[0].id,
    limit=10
)

for book in books:
    print(f"{book.title} by {book.author}")
    print(f"Price: ${book.price}")
    print(f"Rating: {book.average_rating}/5")
```

#### Get Book Details

```python
# Get detailed book information
book = await bookstore.get_book_by_id(book_id)

print(f"Title: {book.title}")
print(f"Author: {book.author}")
print(f"Narrator: {book.narrator}")
print(f"Duration: {book.duration_minutes} minutes")
print(f"Description: {book.description}")
print(f"Sample URL: {book.sample_audio_url}")
```

#### Book Reviews

```python
# Get reviews for a book
reviews, total = await bookstore.get_book_reviews(
    book_id=book_id,
    limit=10,
    offset=0
)

# Add a review
await bookstore.add_review(
    user_id=user_id,
    book_id=book_id,
    rating=5,
    review_text="Excellent audiobook! Great narration."
)
```

### PurchaseService

#### Purchase Books

```python
# Check if user can afford book
can_purchase = await purchase_service.can_user_purchase(
    user_id=user_id,
    book_id=book_id
)

if can_purchase:
    # Purchase book using credits
    purchase = await purchase_service.purchase_book_with_credits(
        user_id=user_id,
        book_id=book_id
    )
    
    print(f"Purchase successful! Transaction ID: {purchase.transaction_id}")
else:
    print("Insufficient credits for purchase")
```

#### Payment Methods

```python
# Purchase with credit card
purchase = await purchase_service.purchase_book_with_card(
    user_id=user_id,
    book_id=book_id,
    payment_method_id="stripe_pm_123",
    billing_address=billing_address
)

# Purchase with PayPal
purchase = await purchase_service.purchase_book_with_paypal(
    user_id=user_id,
    book_id=book_id,
    paypal_order_id="paypal_order_123"
)
```

#### Gift Purchases

```python
# Purchase book as gift
gift_purchase = await purchase_service.gift_book(
    buyer_id=buyer_id,
    recipient_email="friend@example.com",
    book_id=book_id,
    gift_message="Happy Birthday!",
    payment_method_id="stripe_pm_123"
)
```

### CreditManager

#### Manage User Credits

```python
# Get user's credit balance
balance = await credit_manager.get_user_credit_balance(user_id)
print(f"Current balance: {balance} credits")

# Add credits to user account
await credit_manager.add_credits(
    user_id=user_id,
    amount=Decimal("25.00"),
    reason="Credit purchase",
    transaction_reference="stripe_pi_123"
)

# Deduct credits for purchase
await credit_manager.deduct_credits(
    user_id=user_id,
    amount=Decimal("15.99"),
    reason="Book purchase",
    book_id=book_id
)
```

#### Gift Cards

```python
# Purchase gift card
gift_card = await credit_manager.create_gift_card(
    purchaser_id=user_id,
    amount=Decimal("50.00"),
    recipient_email="friend@example.com",
    message="Enjoy some great audiobooks!"
)

# Redeem gift card
await credit_manager.redeem_gift_card(
    user_id=recipient_id,
    gift_card_code=gift_card.code
)
```

#### Promo Codes

```python
# Create promo code (admin function)
promo = await credit_manager.create_promo_code(
    code="NEWUSER20",
    credit_amount=Decimal("20.00"),
    usage_limit=1000,
    expiry_date=datetime(2025, 12, 31)
)

# Redeem promo code
await credit_manager.redeem_promo_code(
    user_id=user_id,
    promo_code="NEWUSER20"
)
```

### RecommendationEngine

#### Get Personalized Recommendations

```python
from core.bookstore.recommendation_engine import RecommendationEngine

rec_engine = RecommendationEngine(db_manager)

# Get recommendations based on user's purchase history
recommendations = await rec_engine.get_user_recommendations(
    user_id=user_id,
    limit=10
)

for book in recommendations:
    print(f"Recommended: {book.title}")
    print(f"Reason: {book.recommendation_reason}")
    print(f"Confidence: {book.confidence_score}")
```

#### Content-Based Recommendations

```python
# Get similar books
similar_books = await rec_engine.get_similar_books(
    book_id=book_id,
    limit=5
)

# Get trending books
trending = await rec_engine.get_trending_books(
    time_period="week",  # "day", "week", "month"
    limit=10
)
```

## Data Models

### BookCatalog

```python
@dataclass
class BookCatalog:
    id: UUID
    title: str
    author: str
    narrator: Optional[str]
    isbn: Optional[str]
    description: str
    category_id: UUID
    price: Decimal
    credit_price: Optional[Decimal]
    duration_minutes: int
    file_size_mb: int
    language: str
    publication_date: datetime
    average_rating: Optional[float]
    total_ratings: int
    cover_image_url: Optional[str]
    sample_audio_url: Optional[str]
    is_featured: bool
    is_bestseller: bool
    is_new_release: bool
    created_at: datetime
    updated_at: datetime
```

### UserPurchase

```python
@dataclass  
class UserPurchase:
    id: UUID
    user_id: UUID
    book_id: UUID
    purchase_date: datetime
    amount_paid: Decimal
    payment_method: str  # "credits", "stripe", "paypal", "apple_pay"
    transaction_id: str
    is_gift: bool
    gift_recipient_email: Optional[str]
    gift_message: Optional[str]
    download_count: int
    last_downloaded: Optional[datetime]
```

### BookReview

```python
@dataclass
class BookReview:
    id: UUID
    user_id: UUID
    book_id: UUID
    rating: int  # 1-5 stars
    review_text: Optional[str]
    is_verified_purchase: bool
    helpful_votes: int
    total_votes: int
    created_at: datetime
    updated_at: datetime
```

## Database Schema

### Core Tables

```sql
-- Book catalog with full metadata
CREATE TABLE book_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    author VARCHAR(200) NOT NULL,
    narrator VARCHAR(200),
    isbn VARCHAR(17),
    description TEXT,
    category_id UUID REFERENCES book_categories(id),
    price DECIMAL(10,2) NOT NULL,
    credit_price DECIMAL(10,2),
    duration_minutes INTEGER NOT NULL,
    file_size_mb INTEGER NOT NULL,
    language VARCHAR(10) DEFAULT 'en',
    publication_date DATE,
    average_rating DECIMAL(3,2),
    total_ratings INTEGER DEFAULT 0,
    cover_image_url TEXT,
    sample_audio_url TEXT,
    audio_file_url TEXT,
    is_featured BOOLEAN DEFAULT false,
    is_bestseller BOOLEAN DEFAULT false,
    is_new_release BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User purchases and transaction history
CREATE TABLE user_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    book_id UUID REFERENCES book_catalog(id),
    purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    amount_paid DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50) NOT NULL,
    transaction_id VARCHAR(200) NOT NULL,
    is_gift BOOLEAN DEFAULT false,
    gift_recipient_email VARCHAR(255),
    gift_message TEXT,
    download_count INTEGER DEFAULT 0,
    last_downloaded TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User credit system
CREATE TABLE user_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    current_balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    lifetime_earned DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    lifetime_spent DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Indexes for Performance

```sql
-- Optimize book browsing queries
CREATE INDEX idx_book_catalog_category ON book_catalog(category_id);
CREATE INDEX idx_book_catalog_featured ON book_catalog(is_featured) WHERE is_featured = true;
CREATE INDEX idx_book_catalog_bestseller ON book_catalog(is_bestseller) WHERE is_bestseller = true;
CREATE INDEX idx_book_catalog_rating ON book_catalog(average_rating DESC);
CREATE INDEX idx_book_catalog_price ON book_catalog(price);

-- Optimize user queries
CREATE INDEX idx_user_purchases_user ON user_purchases(user_id);
CREATE INDEX idx_user_purchases_book ON user_purchases(book_id);
CREATE INDEX idx_user_credits_user ON user_credits(user_id);
CREATE INDEX idx_book_reviews_book ON book_reviews(book_id);
```

## Configuration

### Environment Variables

```bash
# Payment Processing
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
PAYPAL_CLIENT_ID=your_paypal_client_id
PAYPAL_CLIENT_SECRET=your_paypal_client_secret

# Apple App Store
APPLE_APP_STORE_SHARED_SECRET=your_shared_secret
APPLE_APP_STORE_BUNDLE_ID=com.echowright.audiobooks

# Recommendation Engine
RECOMMENDATION_MODEL_PATH=/app/models/recommendation_model.pkl
ENABLE_ML_RECOMMENDATIONS=true

# File Storage
AUDIO_FILES_BASE_URL=https://cdn.echowright.com/audiobooks/
COVER_IMAGES_BASE_URL=https://cdn.echowright.com/covers/

# Email Notifications
SENDGRID_API_KEY=your_sendgrid_api_key
PURCHASE_NOTIFICATION_TEMPLATE_ID=d-1234567890abcdef
```

### Payment Configuration

```python
# Stripe configuration
STRIPE_CONFIG = {
    "publishable_key": os.getenv("STRIPE_PUBLISHABLE_KEY"),
    "secret_key": os.getenv("STRIPE_SECRET_KEY"),
    "webhook_secret": os.getenv("STRIPE_WEBHOOK_SECRET"),
    "currency": "USD"
}

# PayPal configuration  
PAYPAL_CONFIG = {
    "client_id": os.getenv("PAYPAL_CLIENT_ID"),
    "client_secret": os.getenv("PAYPAL_CLIENT_SECRET"),
    "environment": "sandbox",  # "live" for production
    "currency": "USD"
}
```

## Testing

### Unit Tests

```python
import pytest
from decimal import Decimal
from core.bookstore import BookstoreService, PurchaseService

@pytest.fixture
async def bookstore_service():
    db_manager = await create_test_db()
    return BookstoreService(db_manager)

@pytest.mark.asyncio
async def test_browse_books(bookstore_service):
    """Test book browsing functionality."""
    books, total = await bookstore_service.browse_books(limit=10)
    
    assert len(books) <= 10
    assert total >= len(books)
    assert all(isinstance(book.price, Decimal) for book in books)

@pytest.mark.asyncio
async def test_purchase_book_with_credits(purchase_service, sample_user, sample_book):
    """Test credit-based book purchase."""
    # Add credits to user
    await purchase_service.credit_manager.add_credits(
        sample_user.id, 
        Decimal("20.00"), 
        "Test credits"
    )
    
    # Purchase book
    purchase = await purchase_service.purchase_book_with_credits(
        sample_user.id,
        sample_book.id
    )
    
    assert purchase.user_id == sample_user.id
    assert purchase.book_id == sample_book.id
    assert purchase.payment_method == "credits"
```

### Integration Tests

```bash
# Run integration tests with test database
pytest tests/integration/test_bookstore_api.py -v

# Test payment processing (requires test API keys)
pytest tests/integration/test_payment_processing.py -v

# Test recommendation engine
pytest tests/integration/test_recommendations.py -v
```

### Load Testing

```bash
# Test book browsing performance
artillery run tests/load/browse_books.yml

# Test search performance
artillery run tests/load/search_books.yml

# Test purchase flow performance
artillery run tests/load/purchase_flow.yml
```

## Security & Privacy

### Data Protection
- **PCI DSS Compliance** - Credit card data handled by Stripe/PayPal
- **GDPR Compliance** - User data deletion and export capabilities
- **Data Encryption** - Sensitive data encrypted at rest and in transit
- **Access Controls** - Role-based permissions for admin functions

### Fraud Prevention
- **Purchase Limits** - Daily/monthly spending limits
- **Suspicious Activity Detection** - ML-based fraud detection
- **Payment Method Verification** - 3D Secure and address verification
- **Account Monitoring** - Unusual purchase pattern alerts

### Content Security
- **DRM Protection** - Audio files protected with digital rights management
- **Download Limits** - Restrict number of downloads per purchase
- **Geographic Restrictions** - Content availability by region
- **Piracy Detection** - Monitor for unauthorized distribution

## Performance Optimization

### Caching Strategy
- **Book Catalog** - Redis cache for frequently browsed books
- **User Libraries** - Cache user's owned books for fast access
- **Search Results** - Cache popular search queries
- **Recommendations** - Pre-compute recommendations for active users

### Database Optimization
- **Connection Pooling** - Efficient database connection management
- **Query Optimization** - Indexed queries for common operations
- **Read Replicas** - Separate read/write database instances
- **Partitioning** - Partition large tables by date or user segments

### CDN Integration
```python
# Audio file delivery optimization
AUDIO_CDN_CONFIG = {
    "base_url": "https://cdn.echowright.com",
    "signed_urls": True,  # Prevent unauthorized access
    "cache_duration": 86400,  # 24 hours
    "gzip_compression": True
}
```

## Monitoring & Analytics

### Business Metrics
- **Revenue Tracking** - Daily/monthly sales and revenue
- **Conversion Rates** - Browse to purchase conversion
- **Customer Lifetime Value** - Average spending per user
- **Popular Content** - Most purchased and highest-rated books
- **Credit Usage** - Credit purchase and redemption patterns

### Performance Metrics
- **API Response Times** - P95 latency for key endpoints
- **Database Performance** - Query execution times
- **Search Performance** - Search response times and relevance
- **Recommendation Quality** - Click-through rates on recommendations

### Error Monitoring
```python
# Error tracking setup
import sentry_sdk
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

sentry_sdk.init(
    dsn="your_sentry_dsn",
    integrations=[SqlalchemyIntegration()],
    traces_sample_rate=0.1
)
```

## Deployment

### Production Checklist
- [ ] Configure payment processors (Stripe, PayPal)
- [ ] Set up CDN for audio file delivery
- [ ] Enable SSL/TLS encryption
- [ ] Configure backup strategy
- [ ] Set up monitoring and alerting
- [ ] Test payment flows end-to-end
- [ ] Verify recommendation engine performance
- [ ] Configure fraud detection rules
- [ ] Test failover procedures

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookstore-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: bookstore-api
  template:
    metadata:
      labels:
        app: bookstore-api
    spec:
      containers:
      - name: bookstore-api
        image: echowright/bookstore-api:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        - name: STRIPE_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: payment-secrets
              key: stripe-secret
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi" 
            cpu: "1000m"
```

## Support & Troubleshooting

### Common Issues

**"Insufficient credits" Error**
```python
# Check user's credit balance
balance = await credit_manager.get_user_credit_balance(user_id)
print(f"User balance: {balance}")

# Check book price
book = await bookstore.get_book_by_id(book_id)
print(f"Book price: {book.credit_price or book.price}")
```

**Payment Processing Errors**
- Verify API keys are correct
- Check webhook endpoints are accessible
- Validate payment method details
- Review transaction logs

**Poor Recommendation Quality**
- Ensure sufficient user interaction data
- Retrain recommendation model
- Verify content similarity calculations
- Check for data quality issues

### Debug Commands

```bash
# Check database connectivity
python -c "from core.database import DatabaseManager; db = DatabaseManager(); print('DB OK')"

# Test payment processor
python -c "import stripe; stripe.api_key='sk_test_...'; print(stripe.Account.retrieve())"

# Verify recommendation engine
python -c "from core.bookstore.recommendation_engine import RecommendationEngine; print('Rec Engine OK')"
```

---

**Version**: 1.0.0  
**Last Updated**: 2025-01-25  
**Maintainers**: EchoWright Development Team