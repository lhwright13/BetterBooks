-- V010: Cloud Storage Schema Updates
-- Adds cloud storage fields and tables for Azure Blob integration

-- Add cloud storage fields to books table
ALTER TABLE books ADD COLUMN IF NOT EXISTS blob_container VARCHAR(255);
ALTER TABLE books ADD COLUMN IF NOT EXISTS blob_path VARCHAR(500);
ALTER TABLE books ADD COLUMN IF NOT EXISTS cdn_url VARCHAR(500);
ALTER TABLE books ADD COLUMN IF NOT EXISTS file_uploaded_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE books ADD COLUMN IF NOT EXISTS storage_provider VARCHAR(50) DEFAULT 'azure';

-- Update existing books with placeholder storage info
UPDATE books SET 
    blob_container = 'audiobooks',
    blob_path = file_path,
    storage_provider = 'local'
WHERE blob_container IS NULL;

-- Create download_logs table for tracking bandwidth usage
CREATE TABLE IF NOT EXISTS download_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    download_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    file_size_bytes BIGINT DEFAULT 0,
    ip_address INET,
    user_agent TEXT,
    download_type VARCHAR(50) DEFAULT 'stream', -- 'stream', 'download', 'preview'
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for download_logs
CREATE INDEX IF NOT EXISTS idx_download_logs_user_id ON download_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_download_logs_book_id ON download_logs(book_id);
CREATE INDEX IF NOT EXISTS idx_download_logs_time ON download_logs(download_time);
CREATE INDEX IF NOT EXISTS idx_download_logs_success ON download_logs(success);

-- Create file_metadata table for detailed file information
CREATE TABLE IF NOT EXISTS file_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    file_type VARCHAR(50) NOT NULL, -- 'chapter', 'cover', 'sample', 'metadata'
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255),
    file_size_bytes BIGINT DEFAULT 0,
    mime_type VARCHAR(100),
    blob_container VARCHAR(255),
    blob_path VARCHAR(500),
    cdn_url VARCHAR(500),
    checksum VARCHAR(64), -- MD5 or SHA256 hash for integrity
    duration_seconds INTEGER, -- For audio files
    chapter_number INTEGER, -- For chapter files
    quality VARCHAR(20), -- 'low', 'medium', 'high' for audio quality
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_accessed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    access_count INTEGER DEFAULT 0,
    metadata_json JSONB, -- Additional metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for file_metadata
CREATE INDEX IF NOT EXISTS idx_file_metadata_book_id ON file_metadata(book_id);
CREATE INDEX IF NOT EXISTS idx_file_metadata_type ON file_metadata(file_type);
CREATE INDEX IF NOT EXISTS idx_file_metadata_chapter ON file_metadata(chapter_number) WHERE chapter_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_file_metadata_access_count ON file_metadata(access_count);

-- Create storage_stats table for monitoring
CREATE TABLE IF NOT EXISTS storage_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL UNIQUE,
    total_books INTEGER DEFAULT 0,
    total_files INTEGER DEFAULT 0,
    total_size_bytes BIGINT DEFAULT 0,
    total_downloads INTEGER DEFAULT 0,
    bandwidth_bytes BIGINT DEFAULT 0,
    unique_users INTEGER DEFAULT 0,
    storage_cost_usd DECIMAL(10,2) DEFAULT 0.0,
    bandwidth_cost_usd DECIMAL(10,2) DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for storage_stats
CREATE INDEX IF NOT EXISTS idx_storage_stats_date ON storage_stats(date);

-- Create user_download_quota table for rate limiting
CREATE TABLE IF NOT EXISTS user_download_quota (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    daily_download_limit INTEGER DEFAULT 10, -- Downloads per day
    monthly_bandwidth_limit BIGINT DEFAULT 1073741824, -- 1GB in bytes
    current_daily_downloads INTEGER DEFAULT 0,
    current_monthly_bandwidth BIGINT DEFAULT 0,
    last_daily_reset DATE DEFAULT CURRENT_DATE,
    last_monthly_reset DATE DEFAULT DATE_TRUNC('month', CURRENT_DATE)::DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for user_download_quota
CREATE INDEX IF NOT EXISTS idx_user_download_quota_user_id ON user_download_quota(user_id);

-- Function to update file metadata access tracking
CREATE OR REPLACE FUNCTION update_file_access() RETURNS TRIGGER AS $$
BEGIN
    UPDATE file_metadata 
    SET 
        last_accessed = NOW(),
        access_count = access_count + 1,
        updated_at = NOW()
    WHERE book_id = NEW.book_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update file access when downloads are logged
DROP TRIGGER IF EXISTS trigger_update_file_access ON download_logs;
CREATE TRIGGER trigger_update_file_access
    AFTER INSERT ON download_logs
    FOR EACH ROW EXECUTE FUNCTION update_file_access();

-- Function to reset daily download quotas
CREATE OR REPLACE FUNCTION reset_daily_quotas() RETURNS void AS $$
BEGIN
    UPDATE user_download_quota 
    SET 
        current_daily_downloads = 0,
        last_daily_reset = CURRENT_DATE,
        updated_at = NOW()
    WHERE last_daily_reset < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Function to reset monthly bandwidth quotas
CREATE OR REPLACE FUNCTION reset_monthly_quotas() RETURNS void AS $$
BEGIN
    UPDATE user_download_quota 
    SET 
        current_monthly_bandwidth = 0,
        last_monthly_reset = DATE_TRUNC('month', CURRENT_DATE)::DATE,
        updated_at = NOW()
    WHERE last_monthly_reset < DATE_TRUNC('month', CURRENT_DATE)::DATE;
END;
$$ LANGUAGE plpgsql;

-- Insert default download quotas for existing users
INSERT INTO user_download_quota (user_id, daily_download_limit, monthly_bandwidth_limit)
SELECT id, 10, 1073741824 -- 1GB default
FROM users 
WHERE id NOT IN (SELECT user_id FROM user_download_quota);

-- Create view for book storage summary
CREATE OR REPLACE VIEW book_storage_summary AS
SELECT 
    b.id,
    b.title,
    b.author,
    b.file_path,
    b.blob_container,
    b.blob_path,
    b.cdn_url,
    b.storage_provider,
    b.total_chapters,
    b.file_size_bytes as book_total_size,
    COUNT(fm.id) as file_count,
    COALESCE(SUM(fm.file_size_bytes), 0) as actual_total_size,
    COUNT(CASE WHEN fm.file_type = 'chapter' THEN 1 END) as chapter_files,
    COUNT(CASE WHEN fm.file_type = 'cover' THEN 1 END) as cover_files,
    MAX(fm.uploaded_at) as last_upload,
    COALESCE(SUM(fm.access_count), 0) as total_access_count
FROM books b
LEFT JOIN file_metadata fm ON b.id = fm.book_id
GROUP BY b.id, b.title, b.author, b.file_path, b.blob_container, 
         b.blob_path, b.cdn_url, b.storage_provider, b.total_chapters, b.file_size_bytes;

-- Update search vector function to include new fields
CREATE OR REPLACE FUNCTION update_book_search_vector() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := to_tsvector('english', 
        COALESCE(NEW.title, '') || ' ' || 
        COALESCE(NEW.author, '') || ' ' || 
        COALESCE(NEW.narrator, '') || ' ' ||
        COALESCE(NEW.publisher, '') || ' ' ||
        COALESCE(NEW.description, '')
    );
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON TABLE download_logs IS 'Tracks all book download/stream requests for bandwidth monitoring';
COMMENT ON TABLE file_metadata IS 'Detailed metadata for all book files in cloud storage';
COMMENT ON TABLE storage_stats IS 'Daily aggregated statistics for storage usage and costs';
COMMENT ON TABLE user_download_quota IS 'User-specific download quotas and rate limiting';
COMMENT ON VIEW book_storage_summary IS 'Summary view combining book info with storage metadata';

-- Create function to get user's library with download URLs (would be called by bookstore service)
CREATE OR REPLACE FUNCTION get_user_library_with_downloads(p_user_id UUID) 
RETURNS TABLE(
    book_id UUID,
    title TEXT,
    author TEXT,
    cover_url TEXT,
    download_url TEXT,
    file_size_bytes BIGINT,
    purchase_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        b.title,
        b.author,
        COALESCE(b.cdn_url, b.cover_image_url) as cover_url,
        CASE 
            WHEN b.cdn_url IS NOT NULL THEN b.cdn_url
            ELSE '/books/' || b.file_path || '/Chapter 1.mp3' -- Legacy path
        END as download_url,
        b.file_size_bytes,
        up.purchase_date
    FROM user_purchases up
    JOIN books b ON up.book_id = b.id
    WHERE up.user_id = p_user_id
    ORDER BY up.purchase_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Migration complete message
SELECT 'V010 Migration Complete: Cloud storage schema updated with Azure Blob integration' as status;