-- Bookstore System Migration
-- Migration: V008_20250125_bookstore_system.sql
-- Created: 2025-01-25
-- Description: Complete audiobook store system with purchase tracking, credits, 
-- wishlist, reviews, downloads, and Audible-like functionality for EchoWright

-- +migrate Up

-- =====================================================
-- ENHANCED BOOK CATALOG
-- =====================================================

-- Add bookstore-specific columns to existing books table
ALTER TABLE books ADD COLUMN IF NOT EXISTS price_usd DECIMAL(6,2) DEFAULT 14.95;
ALTER TABLE books ADD COLUMN IF NOT EXISTS credit_price INTEGER DEFAULT 1;
ALTER TABLE books ADD COLUMN IF NOT EXISTS narrator VARCHAR(200);
ALTER TABLE books ADD COLUMN IF NOT EXISTS publisher VARCHAR(200);
ALTER TABLE books ADD COLUMN IF NOT EXISTS sample_audio_url TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS sample_duration INTEGER; -- seconds
ALTER TABLE books ADD COLUMN IF NOT EXISTS release_date DATE;
ALTER TABLE books ADD COLUMN IF NOT EXISTS bestseller_rank INTEGER;
ALTER TABLE books ADD COLUMN IF NOT EXISTS categories JSONB DEFAULT '[]';
ALTER TABLE books ADD COLUMN IF NOT EXISTS tags JSONB DEFAULT '[]';
ALTER TABLE books ADD COLUMN IF NOT EXISTS average_rating DECIMAL(3,2) DEFAULT 0.00;
ALTER TABLE books ADD COLUMN IF NOT EXISTS rating_count INTEGER DEFAULT 0;
ALTER TABLE books ADD COLUMN IF NOT EXISTS purchase_count INTEGER DEFAULT 0;
ALTER TABLE books ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false;
ALTER TABLE books ADD COLUMN IF NOT EXISTS file_size_mb DECIMAL(8,2);
ALTER TABLE books ADD COLUMN IF NOT EXISTS content_rating VARCHAR(20) DEFAULT 'G'; -- G, PG, PG-13, R

-- Add indexes for bookstore queries
CREATE INDEX IF NOT EXISTS idx_books_price ON books(price_usd);
CREATE INDEX IF NOT EXISTS idx_books_rating ON books(average_rating DESC);
CREATE INDEX IF NOT EXISTS idx_books_bestseller ON books(bestseller_rank) WHERE bestseller_rank IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_books_featured ON books(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_books_release_date ON books(release_date DESC);
CREATE INDEX IF NOT EXISTS idx_books_categories ON books USING GIN(categories);
CREATE INDEX IF NOT EXISTS idx_books_tags ON books USING GIN(tags);

-- =====================================================
-- BOOK CATEGORIES
-- =====================================================

CREATE TABLE IF NOT EXISTS book_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    parent_id UUID REFERENCES book_categories(id) ON DELETE SET NULL,
    description TEXT,
    icon_name VARCHAR(50),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create hierarchical index for categories
CREATE INDEX IF NOT EXISTS idx_book_categories_parent ON book_categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_book_categories_order ON book_categories(display_order);

-- =====================================================
-- USER PURCHASES & LIBRARY
-- =====================================================

CREATE TABLE IF NOT EXISTS user_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    purchase_type VARCHAR(20) NOT NULL, -- 'credit', 'cash', 'gift', 'subscription'
    price_paid DECIMAL(6,2), -- actual price paid (may differ from list price)
    credits_used INTEGER DEFAULT 0,
    transaction_id VARCHAR(100), -- Stripe/Apple transaction ID
    gift_from_user_id UUID REFERENCES users(id),
    gift_message TEXT,
    
    -- Purchase metadata
    payment_provider VARCHAR(20), -- 'stripe', 'apple', 'subscription'
    refund_date TIMESTAMP WITH TIME ZONE,
    refund_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one purchase per user per book (but allow gifts)
    UNIQUE(user_id, book_id)
);

CREATE INDEX IF NOT EXISTS idx_user_purchases_user ON user_purchases(user_id, purchase_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_purchases_book ON user_purchases(book_id);
CREATE INDEX IF NOT EXISTS idx_user_purchases_type ON user_purchases(purchase_type);
CREATE INDEX IF NOT EXISTS idx_user_purchases_gift_from ON user_purchases(gift_from_user_id) WHERE gift_from_user_id IS NOT NULL;

-- =====================================================
-- CREDIT SYSTEM
-- =====================================================

CREATE TABLE IF NOT EXISTS user_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    credits_available INTEGER DEFAULT 0,
    credits_used INTEGER DEFAULT 0,
    credits_gifted INTEGER DEFAULT 0, -- credits given to others
    credits_received INTEGER DEFAULT 0, -- credits received as gifts
    
    -- Credit allocation tracking
    next_credit_date DATE, -- when next subscription credit is due
    monthly_credits INTEGER DEFAULT 1, -- credits per month based on subscription
    
    -- Credit purchase tracking
    credits_purchased INTEGER DEFAULT 0,
    total_spent DECIMAL(10,2) DEFAULT 0.00, -- total money spent on credits
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Credit transaction history
CREATE TABLE IF NOT EXISTS credit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_type VARCHAR(20) NOT NULL, -- 'earned', 'spent', 'purchased', 'gifted', 'expired'
    credits_change INTEGER NOT NULL, -- positive for gains, negative for spending
    balance_after INTEGER NOT NULL,
    
    -- Transaction context
    book_id UUID REFERENCES books(id), -- if spent on a book
    subscription_id UUID, -- if earned from subscription
    gift_to_user_id UUID REFERENCES users(id), -- if gifted to someone
    payment_transaction_id VARCHAR(100), -- if purchased with money
    
    description TEXT,
    expires_at TIMESTAMP WITH TIME ZONE, -- for expiring credits
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_credit_transactions_user ON credit_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_type ON credit_transactions(transaction_type);

-- =====================================================
-- WISHLIST
-- =====================================================

CREATE TABLE IF NOT EXISTS user_wishlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    added_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    priority INTEGER DEFAULT 0, -- user-defined priority
    notes TEXT,
    price_alert_threshold DECIMAL(6,2), -- notify when book price drops below this
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, book_id)
);

CREATE INDEX IF NOT EXISTS idx_user_wishlist_user ON user_wishlist(user_id, priority DESC, added_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_wishlist_book ON user_wishlist(book_id);

-- =====================================================
-- REVIEWS & RATINGS
-- =====================================================

CREATE TABLE IF NOT EXISTS book_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_title VARCHAR(200),
    review_text TEXT,
    
    -- Review metadata
    helpful_count INTEGER DEFAULT 0,
    total_votes INTEGER DEFAULT 0, -- for calculating helpfulness percentage
    verified_purchase BOOLEAN DEFAULT false,
    spoiler_warning BOOLEAN DEFAULT false,
    
    -- Moderation
    is_approved BOOLEAN DEFAULT true,
    moderation_reason TEXT,
    moderator_id UUID REFERENCES users(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, book_id) -- one review per user per book
);

CREATE INDEX IF NOT EXISTS idx_book_reviews_book ON book_reviews(book_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_book_reviews_user ON book_reviews(user_id);
CREATE INDEX IF NOT EXISTS idx_book_reviews_rating ON book_reviews(book_id, rating DESC);
CREATE INDEX IF NOT EXISTS idx_book_reviews_helpful ON book_reviews(book_id, helpful_count DESC);

-- Review helpfulness votes
CREATE TABLE IF NOT EXISTS review_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES book_reviews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_helpful BOOLEAN NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(review_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_review_votes_review ON review_votes(review_id);

-- =====================================================
-- DOWNLOAD MANAGEMENT
-- =====================================================

CREATE TABLE IF NOT EXISTS book_downloads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    device_id VARCHAR(100) NOT NULL, -- unique device identifier
    device_name VARCHAR(100), -- human-readable device name
    platform VARCHAR(20), -- 'ios', 'android', 'web'
    
    -- Download tracking
    download_status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'downloading', 'completed', 'failed'
    download_progress DECIMAL(5,2) DEFAULT 0.00, -- percentage 0-100
    download_started_at TIMESTAMP WITH TIME ZONE,
    download_completed_at TIMESTAMP WITH TIME ZONE,
    
    -- File information
    file_path TEXT, -- local storage path on device
    file_size_bytes BIGINT,
    file_format VARCHAR(10), -- 'mp3', 'aac', 'opus'
    quality VARCHAR(20), -- 'low', 'medium', 'high'
    
    -- Usage tracking
    last_accessed_at TIMESTAMP WITH TIME ZONE,
    play_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, book_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_book_downloads_user_device ON book_downloads(user_id, device_id);
CREATE INDEX IF NOT EXISTS idx_book_downloads_status ON book_downloads(download_status);
CREATE INDEX IF NOT EXISTS idx_book_downloads_completed ON book_downloads(download_completed_at DESC) WHERE download_status = 'completed';

-- =====================================================
-- RECOMMENDATION SYSTEM
-- =====================================================

-- Store user behavior for recommendations
CREATE TABLE IF NOT EXISTS user_book_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL, -- 'viewed', 'sampled', 'wishlisted', 'purchased'
    interaction_count INTEGER DEFAULT 1,
    last_interaction_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Context
    source VARCHAR(50), -- 'browse', 'search', 'recommendation', 'category'
    duration_seconds INTEGER, -- time spent on book page or listening to sample
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, book_id, interaction_type)
);

CREATE INDEX IF NOT EXISTS idx_user_interactions_user ON user_book_interactions(user_id, last_interaction_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_interactions_book ON user_book_interactions(book_id, interaction_type);

-- Book similarity for recommendations
CREATE TABLE IF NOT EXISTS book_similarities (
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    similar_book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    similarity_score DECIMAL(5,4) NOT NULL, -- 0.0000 to 1.0000
    similarity_type VARCHAR(20) NOT NULL, -- 'genre', 'author', 'collaborative', 'content'
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    PRIMARY KEY (book_id, similar_book_id),
    CHECK (book_id != similar_book_id)
);

CREATE INDEX IF NOT EXISTS idx_book_similarities_score ON book_similarities(book_id, similarity_score DESC);

-- =====================================================
-- GIFT CARDS & PROMOTIONS
-- =====================================================

CREATE TABLE IF NOT EXISTS gift_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(20) NOT NULL UNIQUE,
    value_usd DECIMAL(6,2) NOT NULL,
    credits_value INTEGER NOT NULL,
    
    -- Gift card status
    is_redeemed BOOLEAN DEFAULT false,
    redeemed_by_user_id UUID REFERENCES users(id),
    redeemed_at TIMESTAMP WITH TIME ZONE,
    
    -- Gift card metadata
    purchased_by_user_id UUID REFERENCES users(id),
    gift_message TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gift_cards_code ON gift_cards(code);
CREATE INDEX IF NOT EXISTS idx_gift_cards_purchased_by ON gift_cards(purchased_by_user_id);

-- Promotional codes
CREATE TABLE IF NOT EXISTS promo_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    discount_type VARCHAR(20) NOT NULL, -- 'percentage', 'fixed_amount', 'free_credits'
    discount_value DECIMAL(6,2) NOT NULL,
    
    -- Usage limits
    max_uses INTEGER,
    current_uses INTEGER DEFAULT 0,
    max_uses_per_user INTEGER DEFAULT 1,
    
    -- Validity
    is_active BOOLEAN DEFAULT true,
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    
    -- Restrictions
    minimum_purchase DECIMAL(6,2) DEFAULT 0.00,
    applicable_categories JSONB DEFAULT '[]', -- empty = all categories
    
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Track promo code usage
CREATE TABLE IF NOT EXISTS promo_code_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promo_code_id UUID NOT NULL REFERENCES promo_codes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purchase_id UUID REFERENCES user_purchases(id),
    discount_applied DECIMAL(6,2) NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(promo_code_id, user_id)
);

-- =====================================================
-- SAMPLE BOOK CATEGORIES
-- =====================================================

INSERT INTO book_categories (name, description, icon_name, display_order) VALUES
('Fiction', 'Novels, short stories, and fictional narratives', 'book', 1),
('Non-Fiction', 'Biographies, history, science, and factual content', 'school', 2),
('Mystery & Thriller', 'Suspenseful stories and crime fiction', 'search', 3),
('Romance', 'Love stories and romantic fiction', 'favorite', 4),
('Science Fiction & Fantasy', 'Futuristic and fantasy worlds', 'rocket_launch', 5),
('Biography & Memoir', 'Life stories of real people', 'person', 6),
('Business & Economics', 'Professional development and economics', 'trending_up', 7),
('Self-Help & Personal Development', 'Improvement and motivation', 'psychology', 8),
('Health & Wellness', 'Fitness, nutrition, and mental health', 'spa', 9),
('History', 'Historical events and periods', 'history_edu', 10),
('True Crime', 'Real criminal cases and investigations', 'gavel', 11),
('Young Adult', 'Books for teen and young adult readers', 'school', 12);

-- Add subcategories
INSERT INTO book_categories (name, parent_id, description, icon_name, display_order) 
SELECT 'Literary Fiction', id, 'High-quality literary works', 'auto_stories', 1
FROM book_categories WHERE name = 'Fiction';

INSERT INTO book_categories (name, parent_id, description, icon_name, display_order)
SELECT 'Contemporary Romance', id, 'Modern romantic stories', 'favorite', 1
FROM book_categories WHERE name = 'Romance';

-- =====================================================
-- FUNCTIONS FOR MAINTAINING BOOK STATISTICS
-- =====================================================

-- Function to update book rating statistics
CREATE OR REPLACE FUNCTION update_book_rating_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update average rating and count for the book
    UPDATE books SET
        average_rating = (
            SELECT COALESCE(AVG(rating::decimal), 0)
            FROM book_reviews 
            WHERE book_id = COALESCE(NEW.book_id, OLD.book_id)
            AND is_approved = true
        ),
        rating_count = (
            SELECT COUNT(*)
            FROM book_reviews 
            WHERE book_id = COALESCE(NEW.book_id, OLD.book_id)
            AND is_approved = true
        ),
        updated_at = NOW()
    WHERE id = COALESCE(NEW.book_id, OLD.book_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Triggers for maintaining book statistics
CREATE TRIGGER trigger_update_book_rating_stats
    AFTER INSERT OR UPDATE OR DELETE ON book_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_book_rating_stats();

-- Function to update review helpfulness
CREATE OR REPLACE FUNCTION update_review_helpfulness()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE book_reviews SET
        helpful_count = (
            SELECT COUNT(*) FROM review_votes 
            WHERE review_id = COALESCE(NEW.review_id, OLD.review_id) 
            AND is_helpful = true
        ),
        total_votes = (
            SELECT COUNT(*) FROM review_votes 
            WHERE review_id = COALESCE(NEW.review_id, OLD.review_id)
        ),
        updated_at = NOW()
    WHERE id = COALESCE(NEW.review_id, OLD.review_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating review helpfulness
CREATE TRIGGER trigger_update_review_helpfulness
    AFTER INSERT OR UPDATE OR DELETE ON review_votes
    FOR EACH ROW
    EXECUTE FUNCTION update_review_helpfulness();

-- Function to update user credit balance
CREATE OR REPLACE FUNCTION update_user_credits()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user credits based on transaction
    UPDATE user_credits SET
        credits_available = NEW.balance_after,
        credits_used = CASE 
            WHEN NEW.transaction_type = 'spent' THEN credits_used + ABS(NEW.credits_change)
            ELSE credits_used 
        END,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;
    
    -- Create user credits record if it doesn't exist
    INSERT INTO user_credits (user_id, credits_available)
    VALUES (NEW.user_id, NEW.balance_after)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updating user credits
CREATE TRIGGER trigger_update_user_credits
    AFTER INSERT ON credit_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_credits();

-- =====================================================
-- CLEANUP AND MAINTENANCE FUNCTIONS
-- =====================================================

-- Function to clean up expired promo codes
CREATE OR REPLACE FUNCTION cleanup_expired_promos()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    UPDATE promo_codes 
    SET is_active = false 
    WHERE expires_at < NOW() AND is_active = true;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log cleanup
    INSERT INTO analytics_events (
        event_id, event_type, metadata
    ) VALUES (
        gen_random_uuid()::text,
        'system_cleanup_promos',
        json_build_object('expired_promos', deleted_count)
    );
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to update bestseller rankings
CREATE OR REPLACE FUNCTION update_bestseller_rankings()
RETURNS VOID AS $$
BEGIN
    -- Update rankings based on recent purchase activity (last 30 days)
    WITH recent_purchases AS (
        SELECT 
            book_id,
            COUNT(*) as purchase_count,
            RANK() OVER (ORDER BY COUNT(*) DESC) as rank
        FROM user_purchases 
        WHERE purchase_date >= NOW() - INTERVAL '30 days'
        GROUP BY book_id
    )
    UPDATE books SET
        bestseller_rank = recent_purchases.rank,
        updated_at = NOW()
    FROM recent_purchases
    WHERE books.id = recent_purchases.book_id
    AND recent_purchases.rank <= 100; -- Top 100 bestsellers
    
    -- Clear bestseller ranking for books not in top 100
    UPDATE books 
    SET bestseller_rank = NULL, updated_at = NOW()
    WHERE bestseller_rank > 100 OR bestseller_rank IS NULL;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_user_purchases_user_book ON user_purchases(user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_books_category_rating ON books(((categories->>0)), average_rating DESC);
CREATE INDEX IF NOT EXISTS idx_books_price_rating ON books(price_usd, average_rating DESC);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_type ON credit_transactions(user_id, transaction_type, created_at DESC);

-- Text search index for book search
CREATE INDEX IF NOT EXISTS idx_books_search_text ON books USING gin(
    to_tsvector('english', 
        COALESCE(title, '') || ' ' || 
        COALESCE(author, '') || ' ' || 
        COALESCE(narrator, '') || ' ' ||
        COALESCE(description, '')
    )
);

-- +migrate Down
-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS promo_code_usage CASCADE;
DROP TABLE IF EXISTS promo_codes CASCADE;
DROP TABLE IF EXISTS gift_cards CASCADE;
DROP TABLE IF EXISTS book_similarities CASCADE;
DROP TABLE IF EXISTS user_book_interactions CASCADE;
DROP TABLE IF EXISTS book_downloads CASCADE;
DROP TABLE IF EXISTS review_votes CASCADE;
DROP TABLE IF EXISTS book_reviews CASCADE;
DROP TABLE IF EXISTS user_wishlist CASCADE;
DROP TABLE IF EXISTS credit_transactions CASCADE;
DROP TABLE IF EXISTS user_credits CASCADE;
DROP TABLE IF EXISTS user_purchases CASCADE;
DROP TABLE IF EXISTS book_categories CASCADE;

-- Remove columns added to books table
ALTER TABLE books DROP COLUMN IF EXISTS price_usd;
ALTER TABLE books DROP COLUMN IF EXISTS credit_price;
ALTER TABLE books DROP COLUMN IF EXISTS narrator;
ALTER TABLE books DROP COLUMN IF EXISTS publisher;
ALTER TABLE books DROP COLUMN IF EXISTS sample_audio_url;
ALTER TABLE books DROP COLUMN IF EXISTS sample_duration;
ALTER TABLE books DROP COLUMN IF EXISTS release_date;
ALTER TABLE books DROP COLUMN IF EXISTS bestseller_rank;
ALTER TABLE books DROP COLUMN IF EXISTS categories;
ALTER TABLE books DROP COLUMN IF EXISTS tags;
ALTER TABLE books DROP COLUMN IF EXISTS average_rating;
ALTER TABLE books DROP COLUMN IF EXISTS rating_count;
ALTER TABLE books DROP COLUMN IF EXISTS purchase_count;
ALTER TABLE books DROP COLUMN IF EXISTS is_featured;
ALTER TABLE books DROP COLUMN IF EXISTS file_size_mb;
ALTER TABLE books DROP COLUMN IF EXISTS content_rating;