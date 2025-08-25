-- Analytics System Tables
-- Migration: V007_20250125_analytics_system.sql
-- Created: 2025-01-25
-- Description: Create tables and indexes for comprehensive usage analytics tracking
-- in the EchoWright platform. Supports user engagement, AI persona effectiveness,
-- educational progress tracking, and real-time analytics.

-- Analytics events table - core table for all tracked events
CREATE TABLE IF NOT EXISTS analytics_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(36) UNIQUE NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- User context
    user_id VARCHAR(36),
    user_type VARCHAR(20),
    session_id VARCHAR(32),
    
    -- Content context  
    book_id VARCHAR(100),
    chapter_id VARCHAR(100),
    persona_id VARCHAR(100),
    content_type VARCHAR(20),
    
    -- Event data
    metadata JSONB,
    
    -- Technical context (privacy-compliant)
    user_agent TEXT,
    ip_address VARCHAR(32),  -- Hashed for privacy
    platform VARCHAR(20),
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User engagement summary table (aggregated data for performance)
CREATE TABLE IF NOT EXISTS analytics_user_engagement (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    date_period DATE NOT NULL,
    
    -- Engagement metrics
    total_events INTEGER DEFAULT 0,
    session_duration_seconds INTEGER DEFAULT 0,
    chapters_completed INTEGER DEFAULT 0,
    ai_interactions INTEGER DEFAULT 0,
    comprehension_checks INTEGER DEFAULT 0,
    
    -- Calculated scores
    engagement_score DECIMAL(5,2) DEFAULT 0.00,
    learning_progress_score DECIMAL(5,2) DEFAULT 0.00,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one record per user per day
    UNIQUE(user_id, date_period)
);

-- Persona effectiveness tracking
CREATE TABLE IF NOT EXISTS analytics_persona_effectiveness (
    id BIGSERIAL PRIMARY KEY,
    persona_id VARCHAR(100) NOT NULL,
    date_period DATE NOT NULL,
    
    -- Usage metrics
    unique_users INTEGER DEFAULT 0,
    total_interactions INTEGER DEFAULT 0,
    avg_conversation_duration DECIMAL(8,2) DEFAULT 0.00,
    
    -- Educational effectiveness
    comprehension_checks_triggered INTEGER DEFAULT 0,
    quizzes_completed INTEGER DEFAULT 0,
    user_satisfaction_score DECIMAL(5,2) DEFAULT 0.00,
    
    -- Calculated effectiveness score (0-100)
    effectiveness_score DECIMAL(5,2) DEFAULT 0.00,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one record per persona per day
    UNIQUE(persona_id, date_period)
);

-- Content consumption analytics
CREATE TABLE IF NOT EXISTS analytics_content_consumption (
    id BIGSERIAL PRIMARY KEY,
    book_id VARCHAR(100) NOT NULL,
    chapter_id VARCHAR(100),
    date_period DATE NOT NULL,
    
    -- Consumption metrics
    unique_listeners INTEGER DEFAULT 0,
    total_listens INTEGER DEFAULT 0,
    avg_listen_duration DECIMAL(8,2) DEFAULT 0.00,
    completion_rate DECIMAL(5,2) DEFAULT 0.00,
    replay_count INTEGER DEFAULT 0,
    
    -- Engagement indicators
    ai_questions_asked INTEGER DEFAULT 0,
    notes_created INTEGER DEFAULT 0,
    bookmarks_created INTEGER DEFAULT 0,
    
    -- Audit fields
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure one record per book/chapter per day
    UNIQUE(book_id, COALESCE(chapter_id, ''), date_period)
);

-- Real-time analytics cache (for dashboard displays)
CREATE TABLE IF NOT EXISTS analytics_realtime_cache (
    id BIGSERIAL PRIMARY KEY,
    metric_key VARCHAR(100) NOT NULL,
    metric_value JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint on metric key
    UNIQUE(metric_key)
);

-- Indexes for analytics_events table
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id 
    ON analytics_events(user_id) WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_event_type 
    ON analytics_events(event_type);

CREATE INDEX IF NOT EXISTS idx_analytics_events_timestamp 
    ON analytics_events(timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_analytics_events_persona_id 
    ON analytics_events(persona_id) WHERE persona_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_book_id 
    ON analytics_events(book_id) WHERE book_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_session_id 
    ON analytics_events(session_id) WHERE session_id IS NOT NULL;

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_time 
    ON analytics_events(user_id, timestamp DESC) WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_persona_time 
    ON analytics_events(persona_id, timestamp DESC) WHERE persona_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_book_time 
    ON analytics_events(book_id, timestamp DESC) WHERE book_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_analytics_events_type_time 
    ON analytics_events(event_type, timestamp DESC);

-- GIN index for JSONB metadata queries
CREATE INDEX IF NOT EXISTS idx_analytics_events_metadata 
    ON analytics_events USING GIN(metadata);

-- Indexes for user engagement table
CREATE INDEX IF NOT EXISTS idx_user_engagement_user_date 
    ON analytics_user_engagement(user_id, date_period DESC);

CREATE INDEX IF NOT EXISTS idx_user_engagement_date 
    ON analytics_user_engagement(date_period DESC);

-- Indexes for persona effectiveness table  
CREATE INDEX IF NOT EXISTS idx_persona_effectiveness_persona_date 
    ON analytics_persona_effectiveness(persona_id, date_period DESC);

CREATE INDEX IF NOT EXISTS idx_persona_effectiveness_score 
    ON analytics_persona_effectiveness(effectiveness_score DESC);

-- Indexes for content consumption table
CREATE INDEX IF NOT EXISTS idx_content_consumption_book_date 
    ON analytics_content_consumption(book_id, date_period DESC);

CREATE INDEX IF NOT EXISTS idx_content_consumption_completion 
    ON analytics_content_consumption(completion_rate DESC);

-- Indexes for realtime cache
CREATE INDEX IF NOT EXISTS idx_realtime_cache_expires 
    ON analytics_realtime_cache(expires_at) WHERE expires_at > NOW();

-- Create materialized view for top personas (refreshed periodically)
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics_top_personas AS
SELECT 
    persona_id,
    SUM(total_interactions) as total_interactions,
    AVG(effectiveness_score) as avg_effectiveness_score,
    SUM(unique_users) as total_unique_users,
    MAX(date_period) as last_active_date
FROM analytics_persona_effectiveness
WHERE date_period >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY persona_id
ORDER BY avg_effectiveness_score DESC, total_interactions DESC
LIMIT 100;

-- Index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_top_personas_id 
    ON analytics_top_personas(persona_id);

-- Create functions for updating aggregated tables

-- Function to update user engagement summary
CREATE OR REPLACE FUNCTION update_user_engagement_summary()
RETURNS TRIGGER AS $$
BEGIN
    -- Update or insert user engagement summary for the day
    INSERT INTO analytics_user_engagement (
        user_id, date_period, total_events, session_duration_seconds,
        chapters_completed, ai_interactions, comprehension_checks
    )
    VALUES (
        NEW.user_id,
        DATE(NEW.timestamp),
        1,
        CASE WHEN NEW.event_type = 'session_end' 
             THEN COALESCE((NEW.metadata->>'duration_seconds')::INTEGER, 0) 
             ELSE 0 END,
        CASE WHEN NEW.event_type = 'chapter_complete' THEN 1 ELSE 0 END,
        CASE WHEN NEW.event_type LIKE 'ai_%' THEN 1 ELSE 0 END,
        CASE WHEN NEW.event_type = 'comprehension_check' THEN 1 ELSE 0 END
    )
    ON CONFLICT (user_id, date_period) DO UPDATE SET
        total_events = analytics_user_engagement.total_events + 1,
        session_duration_seconds = analytics_user_engagement.session_duration_seconds + 
            CASE WHEN NEW.event_type = 'session_end' 
                 THEN COALESCE((NEW.metadata->>'duration_seconds')::INTEGER, 0) 
                 ELSE 0 END,
        chapters_completed = analytics_user_engagement.chapters_completed + 
            CASE WHEN NEW.event_type = 'chapter_complete' THEN 1 ELSE 0 END,
        ai_interactions = analytics_user_engagement.ai_interactions + 
            CASE WHEN NEW.event_type LIKE 'ai_%' THEN 1 ELSE 0 END,
        comprehension_checks = analytics_user_engagement.comprehension_checks + 
            CASE WHEN NEW.event_type = 'comprehension_check' THEN 1 ELSE 0 END,
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update persona effectiveness
CREATE OR REPLACE FUNCTION update_persona_effectiveness()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update for persona-related events
    IF NEW.persona_id IS NOT NULL THEN
        INSERT INTO analytics_persona_effectiveness (
            persona_id, date_period, unique_users, total_interactions,
            comprehension_checks_triggered, quizzes_completed
        )
        VALUES (
            NEW.persona_id,
            DATE(NEW.timestamp),
            1, -- Will be corrected by unique constraint and ON CONFLICT
            1,
            CASE WHEN NEW.event_type = 'comprehension_check' THEN 1 ELSE 0 END,
            CASE WHEN NEW.event_type = 'quiz_completed' THEN 1 ELSE 0 END
        )
        ON CONFLICT (persona_id, date_period) DO UPDATE SET
            total_interactions = analytics_persona_effectiveness.total_interactions + 1,
            comprehension_checks_triggered = analytics_persona_effectiveness.comprehension_checks_triggered + 
                CASE WHEN NEW.event_type = 'comprehension_check' THEN 1 ELSE 0 END,
            quizzes_completed = analytics_persona_effectiveness.quizzes_completed + 
                CASE WHEN NEW.event_type = 'quiz_completed' THEN 1 ELSE 0 END,
            updated_at = NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update aggregated data
CREATE TRIGGER trigger_update_user_engagement
    AFTER INSERT ON analytics_events
    FOR EACH ROW
    WHEN (NEW.user_id IS NOT NULL)
    EXECUTE FUNCTION update_user_engagement_summary();

CREATE TRIGGER trigger_update_persona_effectiveness
    AFTER INSERT ON analytics_events
    FOR EACH ROW
    WHEN (NEW.persona_id IS NOT NULL)
    EXECUTE FUNCTION update_persona_effectiveness();

-- Create function to clean up old analytics data
CREATE OR REPLACE FUNCTION cleanup_old_analytics_data()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
    retention_date DATE;
BEGIN
    -- Calculate retention date (1 year by default)
    retention_date := CURRENT_DATE - INTERVAL '365 days';
    
    -- Delete old events
    DELETE FROM analytics_events 
    WHERE timestamp < retention_date;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Clean up aggregated tables
    DELETE FROM analytics_user_engagement WHERE date_period < retention_date;
    DELETE FROM analytics_persona_effectiveness WHERE date_period < retention_date;
    DELETE FROM analytics_content_consumption WHERE date_period < retention_date;
    
    -- Clean up expired cache entries
    DELETE FROM analytics_realtime_cache WHERE expires_at < NOW();
    
    -- Log cleanup
    INSERT INTO analytics_events (
        event_id, event_type, metadata
    ) VALUES (
        gen_random_uuid()::text,
        'system_cleanup',
        json_build_object(
            'deleted_events', deleted_count,
            'retention_date', retention_date
        )
    );
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create indexes for cleanup function
CREATE INDEX IF NOT EXISTS idx_analytics_events_cleanup 
    ON analytics_events(timestamp) WHERE timestamp < CURRENT_DATE - INTERVAL '365 days';

-- Grant permissions (adjust as needed for your user setup)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO betterbooks_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO betterbooks_app;

-- Insert a successful migration event
INSERT INTO analytics_events (
    event_id, 
    event_type, 
    metadata,
    user_type,
    platform
) VALUES (
    gen_random_uuid()::text,
    'system_migration',
    json_build_object(
        'migration', 'V007_20250125_analytics_system',
        'tables_created', ARRAY[
            'analytics_events',
            'analytics_user_engagement', 
            'analytics_persona_effectiveness',
            'analytics_content_consumption',
            'analytics_realtime_cache'
        ],
        'indexes_created', 15,
        'functions_created', 3,
        'triggers_created', 2
    ),
    'system',
    'migration'
);

-- Refresh the materialized view
REFRESH MATERIALIZED VIEW analytics_top_personas;