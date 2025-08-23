-- V006_20250123_email_verification_system.sql
-- Email Verification and Password Reset System Enhancement
-- 
-- This migration adds email verification and password reset capabilities
-- to the existing user authentication system. It extends the users table
-- with the necessary fields to support email verification workflows.
--
-- Features added:
-- - Email verification tokens with expiration
-- - Password reset tokens with expiration  
-- - Email verified status tracking
-- - Proper indexing for token lookups
--
-- Compatible with existing identity-separated schema (V005)

-- Add email verification columns to users table
ALTER TABLE users 
ADD COLUMN email_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN email_verification_token VARCHAR(255) NULL,
ADD COLUMN email_verification_expires_at TIMESTAMP WITH TIME ZONE NULL,
ADD COLUMN password_reset_token VARCHAR(255) NULL, 
ADD COLUMN password_reset_expires_at TIMESTAMP WITH TIME ZONE NULL;

-- Add indexes for efficient token lookups
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email_verification_token 
ON users(email_verification_token) 
WHERE email_verification_token IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_password_reset_token 
ON users(password_reset_token)
WHERE password_reset_token IS NOT NULL;

-- Add index for filtering verified users
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_email_verified
ON users(email_verified)
WHERE email_verified = TRUE;

-- Add index for expired tokens cleanup (useful for background jobs)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_verification_expires
ON users(email_verification_expires_at)
WHERE email_verification_expires_at IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_reset_expires
ON users(password_reset_expires_at)
WHERE password_reset_expires_at IS NOT NULL;

-- Update existing users to have email_verified = TRUE if they have identities
-- This assumes that users with existing identities have already verified their email through OAuth
UPDATE users 
SET email_verified = TRUE
WHERE id IN (
    SELECT DISTINCT user_id 
    FROM identities 
    WHERE verified = TRUE
);

-- Add comments for documentation
COMMENT ON COLUMN users.email_verified IS 'Whether the user has verified their email address';
COMMENT ON COLUMN users.email_verification_token IS 'Token sent in verification email, expires after 24 hours';
COMMENT ON COLUMN users.email_verification_expires_at IS 'Expiration timestamp for email verification token';
COMMENT ON COLUMN users.password_reset_token IS 'Token sent in password reset email, expires after 1 hour';
COMMENT ON COLUMN users.password_reset_expires_at IS 'Expiration timestamp for password reset token';

-- Create function to clean up expired tokens (for background maintenance)
CREATE OR REPLACE FUNCTION cleanup_expired_auth_tokens()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    cleaned_count INTEGER;
BEGIN
    -- Clean expired email verification tokens
    UPDATE users 
    SET email_verification_token = NULL,
        email_verification_expires_at = NULL
    WHERE email_verification_expires_at < NOW();
    
    -- Clean expired password reset tokens  
    UPDATE users
    SET password_reset_token = NULL,
        password_reset_expires_at = NULL
    WHERE password_reset_expires_at < NOW();
    
    GET DIAGNOSTICS cleaned_count = ROW_COUNT;
    
    -- Log cleanup operation
    INSERT INTO audit_logs (
        table_name, 
        operation, 
        details, 
        created_at
    ) VALUES (
        'users',
        'cleanup_expired_tokens',
        jsonb_build_object('cleaned_tokens', cleaned_count),
        NOW()
    );
    
    RETURN cleaned_count;
END;
$$;

-- Add trigger to automatically set updated_at when auth fields change
CREATE OR REPLACE FUNCTION update_user_timestamp()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only update timestamp if auth-related fields changed
    IF OLD.email_verified IS DISTINCT FROM NEW.email_verified 
       OR OLD.email_verification_token IS DISTINCT FROM NEW.email_verification_token
       OR OLD.password_reset_token IS DISTINCT FROM NEW.password_reset_token THEN
        NEW.updated_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_users_auth_timestamp ON users;
CREATE TRIGGER trigger_users_auth_timestamp
    BEFORE UPDATE ON users
    FOR EACH ROW 
    EXECUTE FUNCTION update_user_timestamp();

-- Add constraint to ensure tokens are unique when present
ALTER TABLE users 
ADD CONSTRAINT unique_email_verification_token 
UNIQUE (email_verification_token);

ALTER TABLE users
ADD CONSTRAINT unique_password_reset_token
UNIQUE (password_reset_token);

-- Add constraint to ensure token expiration is set when token is set
ALTER TABLE users
ADD CONSTRAINT check_email_verification_expiration
CHECK (
    (email_verification_token IS NULL AND email_verification_expires_at IS NULL)
    OR 
    (email_verification_token IS NOT NULL AND email_verification_expires_at IS NOT NULL)
);

ALTER TABLE users  
ADD CONSTRAINT check_password_reset_expiration
CHECK (
    (password_reset_token IS NULL AND password_reset_expires_at IS NULL)
    OR
    (password_reset_token IS NOT NULL AND password_reset_expires_at IS NOT NULL)
);

-- Create audit trigger for email verification events
CREATE OR REPLACE FUNCTION audit_email_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Log email verification events
    IF OLD.email_verified = FALSE AND NEW.email_verified = TRUE THEN
        INSERT INTO audit_logs (
            user_id,
            table_name,
            operation, 
            details,
            created_at
        ) VALUES (
            NEW.id,
            'users',
            'email_verified',
            jsonb_build_object(
                'email', NEW.email,
                'verified_at', NOW()
            ),
            NOW()
        );
    END IF;
    
    -- Log password reset events
    IF OLD.password_reset_token IS NULL AND NEW.password_reset_token IS NOT NULL THEN
        INSERT INTO audit_logs (
            user_id,
            table_name,
            operation,
            details,
            created_at
        ) VALUES (
            NEW.id,
            'users', 
            'password_reset_requested',
            jsonb_build_object(
                'email', NEW.email,
                'expires_at', NEW.password_reset_expires_at
            ),
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create audit trigger
DROP TRIGGER IF EXISTS trigger_audit_email_verification ON users;
CREATE TRIGGER trigger_audit_email_verification
    AFTER UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION audit_email_verification();

-- Grant necessary permissions
GRANT SELECT, UPDATE ON users TO betterbooks_api;
GRANT EXECUTE ON FUNCTION cleanup_expired_auth_tokens() TO betterbooks_api;

-- Update migration tracking
INSERT INTO schema_migrations (
    version, 
    description, 
    applied_at, 
    checksum
) VALUES (
    'V006_20250123_email_verification_system',
    'Add email verification and password reset system',
    NOW(),
    md5('V006_20250123_email_verification_system')
);

-- Performance optimization: Analyze tables after adding indexes
ANALYZE users;