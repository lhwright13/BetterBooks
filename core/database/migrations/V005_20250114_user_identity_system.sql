-- Migration V005: Complete User Identity and Payment System
-- Implements Apple App Store compliant schema with proper identity separation

-- =====================================================
-- 1. USERS TABLE (Identity-agnostic)
-- =====================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255), -- nullable for Apple private relay emails
    display_name VARCHAR(100),
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE -- soft delete for GDPR compliance
);

-- =====================================================
-- 2. IDENTITY PROVIDERS (Clean separation)
-- =====================================================

CREATE TABLE identities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL CHECK (provider IN ('apple', 'google', 'email', 'supabase')),
    provider_user_id VARCHAR(255) NOT NULL,
    email_at_auth VARCHAR(255), -- email at time of authentication
    verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one identity per provider per user
    UNIQUE(provider, provider_user_id),
    -- Prevent duplicate Apple/Google accounts per user
    UNIQUE(user_id, provider)
);

-- =====================================================
-- 3. SUBSCRIPTIONS (Multi-provider support)
-- =====================================================

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL CHECK (provider IN ('app_store', 'stripe')),
    status VARCHAR(50) NOT NULL CHECK (status IN ('active', 'cancelled', 'expired', 'grace_period', 'pending', 'paused')),
    product_id VARCHAR(255) NOT NULL, -- SKU from StoreKit or Stripe product ID
    price_id VARCHAR(255), -- Stripe price ID (null for App Store)
    
    -- Timing
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    cancel_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    
    -- Apple App Store specific fields
    original_transaction_id VARCHAR(255), -- Apple's permanent ID
    app_account_token UUID, -- Links Apple purchase to our user
    environment VARCHAR(20) CHECK (environment IN ('Production', 'Sandbox')), -- Apple environment
    
    -- Stripe specific fields
    stripe_subscription_id VARCHAR(255),
    stripe_customer_id VARCHAR(255),
    stripe_price_id VARCHAR(255),
    
    -- Metadata
    trial_start TIMESTAMP WITH TIME ZONE,
    trial_end TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(original_transaction_id), -- Apple transactions are unique
    UNIQUE(stripe_subscription_id) -- Stripe subscriptions are unique
);

-- =====================================================
-- 4. ENTITLEMENTS (Computed from subscriptions)
-- =====================================================

CREATE TABLE entitlements (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    feature VARCHAR(100) NOT NULL, -- 'premium_access', 'family_sharing', 'unlimited_books'
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE, -- null = permanent
    source VARCHAR(50) NOT NULL CHECK (source IN ('subscription', 'promotion', 'gift', 'trial')),
    source_id UUID, -- Reference to subscription or promotion
    active BOOLEAN DEFAULT true,
    
    PRIMARY KEY (user_id, feature),
    
    -- Index for expiration checks
    INDEX idx_entitlements_expires (expires_at, active) WHERE expires_at IS NOT NULL
);

-- =====================================================
-- 5. APPLE RECEIPTS (Audit trail)
-- =====================================================

CREATE TABLE apple_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    original_transaction_id VARCHAR(255) NOT NULL,
    transaction_id VARCHAR(255),
    environment VARCHAR(20) NOT NULL CHECK (environment IN ('Production', 'Sandbox')),
    
    -- Apple notification data
    notification_type VARCHAR(100), -- INITIAL_BUY, DID_RENEW, etc.
    subtype VARCHAR(100), -- RESUBSCRIBE, DOWNGRADE, etc.
    signed_payload TEXT NOT NULL, -- Full JWS from Apple
    
    -- Parsed transaction info
    product_id VARCHAR(255),
    purchase_date TIMESTAMP WITH TIME ZONE,
    expires_date TIMESTAMP WITH TIME ZONE,
    quantity INTEGER DEFAULT 1,
    
    -- Processing
    processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP WITH TIME ZONE,
    received_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure no duplicate processing
    UNIQUE(transaction_id, notification_type)
);

-- =====================================================
-- 6. STRIPE EVENTS (Audit trail)
-- =====================================================

CREATE TABLE stripe_events (
    id VARCHAR(255) PRIMARY KEY, -- Stripe event ID (evt_...)
    type VARCHAR(100) NOT NULL, -- customer.subscription.created, invoice.paid, etc.
    object_id VARCHAR(255), -- Subscription ID, Customer ID, etc.
    livemode BOOLEAN DEFAULT false,
    
    -- Event data
    payload JSONB NOT NULL, -- Full Stripe event payload
    api_version VARCHAR(50),
    
    -- Processing
    processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP WITH TIME ZONE,
    received_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Security
    signature_valid BOOLEAN DEFAULT false,
    idempotency_key VARCHAR(255) UNIQUE -- Prevent duplicate processing
);

-- =====================================================
-- 7. USER LIBRARY (Book access and progress)
-- =====================================================

CREATE TABLE user_library (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id VARCHAR(255) NOT NULL, -- References book from book_files
    
    -- Access info
    acquired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    access_type VARCHAR(50) DEFAULT 'purchase' CHECK (access_type IN ('purchase', 'subscription', 'trial', 'gift')),
    access_expires_at TIMESTAMP WITH TIME ZONE, -- null = permanent access
    
    -- Progress tracking
    last_position_seconds INTEGER DEFAULT 0,
    last_chapter INTEGER DEFAULT 1,
    completed BOOLEAN DEFAULT false,
    completion_date TIMESTAMP WITH TIME ZONE,
    
    -- Listening stats
    total_listening_time INTEGER DEFAULT 0, -- seconds
    play_count INTEGER DEFAULT 0,
    last_played_at TIMESTAMP WITH TIME ZONE,
    
    PRIMARY KEY (user_id, book_id)
);

-- =====================================================
-- 8. LISTENING HISTORY (Analytics and resume)
-- =====================================================

CREATE TABLE listening_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id VARCHAR(255) NOT NULL,
    chapter INTEGER,
    
    -- Session details
    start_position_seconds INTEGER NOT NULL,
    end_position_seconds INTEGER NOT NULL,
    duration_seconds INTEGER GENERATED ALWAYS AS (end_position_seconds - start_position_seconds) STORED,
    
    -- Metadata
    device_type VARCHAR(50), -- 'ios', 'web', 'android'
    playback_speed DECIMAL(3,2) DEFAULT 1.0,
    session_start TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_end TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 9. USER PREFERENCES
-- =====================================================

CREATE TABLE user_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- Audio preferences
    default_playback_speed DECIMAL(3,2) DEFAULT 1.0,
    preferred_narrator VARCHAR(100),
    auto_play_next_chapter BOOLEAN DEFAULT true,
    sleep_timer_minutes INTEGER,
    
    -- UI preferences
    theme VARCHAR(50) DEFAULT 'auto' CHECK (theme IN ('light', 'dark', 'auto')),
    notification_preferences JSONB DEFAULT '{}',
    
    -- Privacy
    analytics_enabled BOOLEAN DEFAULT true,
    marketing_emails BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Users
CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_created ON users(created_at);
CREATE INDEX idx_users_active ON users(deleted_at) WHERE deleted_at IS NULL;

-- Identities
CREATE INDEX idx_identities_user ON identities(user_id);
CREATE INDEX idx_identities_provider ON identities(provider, provider_user_id);
CREATE INDEX idx_identities_email ON identities(email_at_auth);

-- Subscriptions
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status) WHERE status = 'active';
CREATE INDEX idx_subscriptions_provider ON subscriptions(provider);
CREATE INDEX idx_subscriptions_expires ON subscriptions(current_period_end) WHERE current_period_end > NOW();
CREATE INDEX idx_subscriptions_apple_tx ON subscriptions(original_transaction_id) WHERE original_transaction_id IS NOT NULL;
CREATE INDEX idx_subscriptions_stripe ON subscriptions(stripe_subscription_id) WHERE stripe_subscription_id IS NOT NULL;

-- Entitlements
CREATE INDEX idx_entitlements_user ON entitlements(user_id);
CREATE INDEX idx_entitlements_feature ON entitlements(feature);
CREATE INDEX idx_entitlements_active ON entitlements(active, expires_at) WHERE active = true;

-- Apple receipts
CREATE INDEX idx_apple_receipts_user ON apple_receipts(user_id);
CREATE INDEX idx_apple_receipts_tx ON apple_receipts(original_transaction_id);
CREATE INDEX idx_apple_receipts_unprocessed ON apple_receipts(processed, received_at) WHERE processed = false;

-- Stripe events
CREATE INDEX idx_stripe_events_type ON stripe_events(type);
CREATE INDEX idx_stripe_events_object ON stripe_events(object_id);
CREATE INDEX idx_stripe_events_unprocessed ON stripe_events(processed, received_at) WHERE processed = false;

-- Library
CREATE INDEX idx_library_user ON user_library(user_id);
CREATE INDEX idx_library_book ON user_library(book_id);
CREATE INDEX idx_library_recent ON user_library(last_played_at DESC) WHERE last_played_at IS NOT NULL;
CREATE INDEX idx_library_completed ON user_library(completed, completion_date) WHERE completed = true;

-- Listening sessions
CREATE INDEX idx_sessions_user ON listening_sessions(user_id);
CREATE INDEX idx_sessions_book ON listening_sessions(book_id);
CREATE INDEX idx_sessions_recent ON listening_sessions(session_start DESC);

-- =====================================================
-- FUNCTIONS FOR ENTITLEMENT MANAGEMENT
-- =====================================================

-- Function to update entitlements based on active subscriptions
CREATE OR REPLACE FUNCTION update_user_entitlements(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    -- Clear existing subscription-based entitlements
    DELETE FROM entitlements 
    WHERE user_id = p_user_id 
    AND source = 'subscription';
    
    -- Add entitlements for active subscriptions
    INSERT INTO entitlements (user_id, feature, expires_at, source, source_id)
    SELECT 
        s.user_id,
        CASE 
            WHEN s.product_id LIKE '%family%' THEN 'family_sharing'
            WHEN s.product_id LIKE '%premium%' OR s.product_id LIKE '%yearly%' OR s.product_id LIKE '%monthly%' THEN 'premium_access'
            ELSE 'basic_access'
        END as feature,
        s.current_period_end as expires_at,
        'subscription' as source,
        s.id as source_id
    FROM subscriptions s
    WHERE s.user_id = p_user_id
    AND s.status = 'active'
    AND (s.current_period_end IS NULL OR s.current_period_end > NOW())
    ON CONFLICT (user_id, feature) DO UPDATE SET
        expires_at = EXCLUDED.expires_at,
        source_id = EXCLUDED.source_id,
        active = true;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user has active entitlement
CREATE OR REPLACE FUNCTION user_has_entitlement(p_user_id UUID, p_feature VARCHAR(100))
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM entitlements 
        WHERE user_id = p_user_id 
        AND feature = p_feature 
        AND active = true
        AND (expires_at IS NULL OR expires_at > NOW())
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- =====================================================

-- Trigger to update entitlements when subscriptions change
CREATE OR REPLACE FUNCTION trigger_update_entitlements()
RETURNS TRIGGER AS $$
BEGIN
    -- Update entitlements for the affected user
    PERFORM update_user_entitlements(COALESCE(NEW.user_id, OLD.user_id));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER subscriptions_update_entitlements
    AFTER INSERT OR UPDATE OR DELETE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION trigger_update_entitlements();

-- Trigger to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_update_timestamp
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER identities_update_timestamp
    BEFORE UPDATE ON identities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER subscriptions_update_timestamp
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER user_preferences_update_timestamp
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =====================================================
-- SAMPLE DATA FOR DEVELOPMENT
-- =====================================================

-- Create a test user with Apple identity
INSERT INTO users (id, display_name, email) VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'Test User', 'test@example.com');

INSERT INTO identities (user_id, provider, provider_user_id, email_at_auth) VALUES
('550e8400-e29b-41d4-a716-446655440000', 'apple', 'apple_user_123', 'test@privaterelay.appleid.com');

-- Create user preferences
INSERT INTO user_preferences (user_id) VALUES 
('550e8400-e29b-41d4-a716-446655440000');

-- =====================================================
-- PERMISSIONS AND SECURITY
-- =====================================================

-- Create API user (used by application)
-- Note: In production, create this with more restricted permissions
-- CREATE USER betterbooks_api WITH PASSWORD 'secure_password_here';
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO betterbooks_api;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO betterbooks_api;

-- Create read-only user for analytics
-- CREATE USER betterbooks_analytics WITH PASSWORD 'analytics_password_here';
-- GRANT SELECT ON users, listening_sessions, user_library TO betterbooks_analytics;

COMMENT ON TABLE users IS 'Core user accounts - identity agnostic';
COMMENT ON TABLE identities IS 'Links users to authentication providers (Apple, Google, etc.)';
COMMENT ON TABLE subscriptions IS 'Tracks subscriptions from both App Store and Stripe';
COMMENT ON TABLE entitlements IS 'Computed permissions based on subscriptions and promotions';
COMMENT ON TABLE apple_receipts IS 'Audit trail for all Apple App Store transactions';
COMMENT ON TABLE stripe_events IS 'Audit trail for all Stripe webhook events';
COMMENT ON TABLE user_library IS 'Books owned/accessed by users with progress tracking';
COMMENT ON TABLE listening_sessions IS 'Detailed listening analytics';
COMMENT ON TABLE user_preferences IS 'User-configurable settings and preferences';

-- Migration complete
\echo 'Migration V005 complete: User identity and payment system created';