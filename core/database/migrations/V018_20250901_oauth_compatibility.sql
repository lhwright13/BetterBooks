-- Migration V018: OAuth Compatibility Enhancements
-- Adds password credentials table and ensures OAuth compatibility
-- Date: 2025-09-01

-- =====================================================
-- 1. ADD PASSWORD CREDENTIALS TABLE
-- =====================================================
-- Separate password storage from user table for OAuth compatibility

CREATE TABLE IF NOT EXISTS password_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used TIMESTAMP WITH TIME ZONE,
    
    -- One password per user
    UNIQUE(user_id)
);

-- =====================================================
-- 2. UPDATE USERS TABLE FOR OAUTH COMPATIBILITY
-- =====================================================
-- Make email nullable and add missing fields for OAuth

-- Add new columns if they don't exist
DO $$ 
BEGIN
    -- Add display_name if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'display_name') THEN
        ALTER TABLE users ADD COLUMN display_name VARCHAR(100);
    END IF;
    
    -- Add avatar_url if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'avatar_url') THEN
        ALTER TABLE users ADD COLUMN avatar_url TEXT;
    END IF;
    
    -- Add email_verified if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'email_verified') THEN
        ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT false;
    END IF;
    
    -- Add deleted_at if not exists (for soft delete)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'deleted_at') THEN
        ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- Make email nullable for OAuth providers (Apple Sign In private relay)
ALTER TABLE users ALTER COLUMN email DROP NOT NULL;

-- Make username nullable (can be auto-generated for OAuth users)
ALTER TABLE users ALTER COLUMN username DROP NOT NULL;

-- =====================================================
-- 3. UPDATE IDENTITIES TABLE FOR COMPATIBILITY
-- =====================================================
-- Ensure identities table has all required fields

DO $$
BEGIN
    -- Add is_verified if not exists (renamed from 'verified')
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'identities' AND column_name = 'is_verified') THEN
        -- Check if old 'verified' column exists
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'identities' AND column_name = 'verified') THEN
            ALTER TABLE identities RENAME COLUMN verified TO is_verified;
        ELSE
            ALTER TABLE identities ADD COLUMN is_verified BOOLEAN DEFAULT false;
        END IF;
    END IF;
    
    -- Add is_primary if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'identities' AND column_name = 'is_primary') THEN
        ALTER TABLE identities ADD COLUMN is_primary BOOLEAN DEFAULT false;
    END IF;
    
    -- Add provider_data if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'identities' AND column_name = 'provider_data') THEN
        ALTER TABLE identities ADD COLUMN provider_data JSONB DEFAULT '{}';
    END IF;
    
    -- Rename email_at_auth to provider_email if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'identities' AND column_name = 'email_at_auth') THEN
        ALTER TABLE identities RENAME COLUMN email_at_auth TO provider_email;
    END IF;
    
    -- Add provider_email if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'identities' AND column_name = 'provider_email') THEN
        ALTER TABLE identities ADD COLUMN provider_email VARCHAR(255);
    END IF;
    
    -- Rename provider_user_id to provider_id if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'identities' AND column_name = 'provider_user_id') THEN
        ALTER TABLE identities RENAME COLUMN provider_user_id TO provider_id;
    END IF;
END $$;

-- =====================================================
-- 4. UPDATE SESSIONS TABLE FOR JWT COMPATIBILITY
-- =====================================================
-- Add missing fields for comprehensive session management

DO $$
BEGIN
    -- Add token_type if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sessions' AND column_name = 'token_type') THEN
        ALTER TABLE sessions ADD COLUMN token_type VARCHAR(20) DEFAULT 'access';
    END IF;
    
    -- Add last_used if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sessions' AND column_name = 'last_used') THEN
        ALTER TABLE sessions ADD COLUMN last_used TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Add is_revoked if not exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sessions' AND column_name = 'is_revoked') THEN
        ALTER TABLE sessions ADD COLUMN is_revoked BOOLEAN DEFAULT false;
    END IF;
END $$;

-- =====================================================
-- 5. MIGRATE EXISTING PASSWORD DATA
-- =====================================================
-- Move password hashes from users table to password_credentials table

DO $$
BEGIN
    -- Only migrate if password_hash column exists in users table
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'users' AND column_name = 'password_hash') THEN
        
        -- Insert existing password hashes into password_credentials
        INSERT INTO password_credentials (user_id, password_hash, salt, created_at)
        SELECT 
            id as user_id,
            password_hash,
            'migrated_' || substr(md5(random()::text), 0, 25) as salt, -- Generate temporary salt
            created_at
        FROM users 
        WHERE password_hash IS NOT NULL
        ON CONFLICT (user_id) DO NOTHING;
        
        -- Create email identity for existing users with passwords
        INSERT INTO identities (user_id, provider, provider_id, provider_email, is_verified, is_primary)
        SELECT 
            id as user_id,
            'email' as provider,
            email as provider_id,
            email as provider_email,
            COALESCE(email_verified, false) as is_verified,
            true as is_primary
        FROM users 
        WHERE email IS NOT NULL
        ON CONFLICT (provider, provider_id) DO NOTHING;
        
        -- Drop the old password_hash column
        ALTER TABLE users DROP COLUMN IF EXISTS password_hash;
    END IF;
END $$;

-- =====================================================
-- 6. UPDATE CONSTRAINTS AND INDEXES
-- =====================================================

-- Update provider constraint to include 'email'
DO $$
BEGIN
    -- Drop old constraint if it exists
    IF EXISTS (SELECT 1 FROM information_schema.table_constraints 
               WHERE table_name = 'identities' AND constraint_name = 'identities_provider_check') THEN
        ALTER TABLE identities DROP CONSTRAINT identities_provider_check;
    END IF;
    
    -- Add new constraint with email provider
    ALTER TABLE identities ADD CONSTRAINT identities_provider_check 
        CHECK (provider IN ('apple', 'google', 'email', 'supabase'));
END $$;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_password_credentials_user ON password_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_identities_primary ON identities(user_id, is_primary) WHERE is_primary = true;
CREATE INDEX IF NOT EXISTS idx_sessions_token_type ON sessions(token_type);
CREATE INDEX IF NOT EXISTS idx_sessions_revoked ON sessions(is_revoked, expires_at) WHERE is_revoked = false;

-- =====================================================
-- 7. UPDATE TRIGGERS FOR NEW FIELDS
-- =====================================================

-- Ensure updated_at trigger exists for password_credentials
CREATE TRIGGER password_credentials_update_timestamp
    BEFORE UPDATE ON password_credentials
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =====================================================
-- 8. ENSURE ADMIN USER EXISTS WITH PROPER IDENTITY
-- =====================================================

DO $$
DECLARE
    admin_user_id UUID;
    admin_exists BOOLEAN := false;
BEGIN
    -- Check if admin user already exists
    SELECT EXISTS (
        SELECT 1 FROM users u
        JOIN identities i ON u.id = i.user_id
        WHERE u.role = 'admin' 
        AND i.provider = 'email'
        AND (u.deleted_at IS NULL OR u.deleted_at IS NULL)
    ) INTO admin_exists;
    
    -- Create admin user if none exists
    IF NOT admin_exists THEN
        -- Create admin user
        INSERT INTO users (email, username, display_name, role, is_active, email_verified)
        VALUES ('admin@echowright.com', 'admin', 'Administrator', 'admin', true, true)
        RETURNING id INTO admin_user_id;
        
        -- Create email identity for admin
        INSERT INTO identities (user_id, provider, provider_id, provider_email, is_verified, is_primary)
        VALUES (admin_user_id, 'email', 'admin@echowright.com', 'admin@echowright.com', true, true);
        
        -- Note: Password should be set separately through the application
        RAISE NOTICE 'Created admin user with ID: %', admin_user_id;
        RAISE NOTICE 'Remember to set admin password through the application!';
    END IF;
END $$;

-- =====================================================
-- 9. ADD HELPFUL FUNCTIONS
-- =====================================================

-- Function to get user's primary authentication method
CREATE OR REPLACE FUNCTION get_user_primary_auth(p_user_id UUID)
RETURNS TABLE(provider VARCHAR, provider_id VARCHAR, is_verified BOOLEAN) AS $$
BEGIN
    RETURN QUERY
    SELECT i.provider, i.provider_id, i.is_verified
    FROM identities i
    WHERE i.user_id = p_user_id AND i.is_primary = true;
END;
$$ LANGUAGE plpgsql;

-- Function to check if user has password authentication
CREATE OR REPLACE FUNCTION user_has_password(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM password_credentials 
        WHERE user_id = p_user_id
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON TABLE password_credentials IS 'Separate password storage for email authentication, compatible with OAuth';
COMMENT ON COLUMN users.email IS 'Nullable email for Apple Sign In private relay compatibility';
COMMENT ON COLUMN users.display_name IS 'User display name from OAuth provider or user preference';
COMMENT ON COLUMN identities.is_primary IS 'Primary authentication method for the user';
COMMENT ON COLUMN identities.provider_data IS 'Additional data from OAuth provider (profile info, etc.)';

-- Migration complete
\echo 'Migration V018 complete: OAuth compatibility enhancements added';
\echo 'Users can now authenticate via email/password, Google Sign In, or Apple Sign In';
\echo 'Existing password data has been migrated to separate credentials table';