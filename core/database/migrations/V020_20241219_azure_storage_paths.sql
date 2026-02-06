-- Migration V012: Add Azure Storage paths to books table
-- Created: 2024-12-19
-- Purpose: Support Azure Blob Storage for audio files and book covers

-- Add Azure storage path columns to books table
ALTER TABLE books ADD COLUMN IF NOT EXISTS azure_audio_path TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS azure_cover_path TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS storage_provider VARCHAR(20) DEFAULT 'local';

-- Add index for storage provider lookups
CREATE INDEX IF NOT EXISTS idx_books_storage_provider ON books(storage_provider);

-- Add storage metadata columns
ALTER TABLE books ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS audio_duration_seconds INTEGER;

-- Update existing books with Azure paths based on title
-- This maps existing books to their expected Azure Blob Storage paths
UPDATE books
SET
    azure_audio_path = title || '/',
    azure_cover_path = title || '/',
    storage_provider = 'azure'
WHERE title IN ('The Great Gatsby', 'Pride and Prejudice');

-- Create function to generate Azure URL for audio files
CREATE OR REPLACE FUNCTION get_audio_url(book_title TEXT, filename TEXT DEFAULT 'Chapter 1.mp3')
RETURNS TEXT AS $$
BEGIN
    -- This function can be extended to integrate with Azure Storage Helper
    -- For now, return a standardized path format
    RETURN '/audio/' || book_title || '/' || filename;
END;
$$ LANGUAGE plpgsql;

-- Create function to list available chapters for a book
CREATE OR REPLACE FUNCTION get_book_chapters(book_id UUID)
RETURNS TABLE(
    chapter_number INTEGER,
    filename TEXT,
    azure_path TEXT,
    estimated_duration INTEGER
) AS $$
DECLARE
    book_title TEXT;
BEGIN
    -- Get book title
    SELECT title INTO book_title FROM books WHERE id = book_id;

    IF book_title IS NULL THEN
        RETURN;
    END IF;

    -- Return standard chapter structure
    -- This is a placeholder - in practice, chapter info would come from Azure Storage
    FOR chapter_number IN 1..9 LOOP
        filename := 'Chapter ' || chapter_number || '.mp3';
        azure_path := book_title || '/' || filename;
        estimated_duration := 1800; -- 30 minutes default
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Update sample_audio_url for existing books to use new audio endpoints
UPDATE books
SET sample_audio_url = '/audio/stream/' || title || '/Chapter 1.mp3'
WHERE sample_audio_url IS NULL OR sample_audio_url = '';

-- Update cover_image_url for Azure compatibility (standardized format)
UPDATE books
SET cover_image_url = '/books/cover/' || title || '/cover.jpg'
WHERE cover_image_url IS NULL OR cover_image_url = '' OR cover_image_url NOT LIKE '/books/cover/%';

-- Add storage statistics table to track Azure usage
CREATE TABLE IF NOT EXISTS storage_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_files INTEGER DEFAULT 0,
    total_size_bytes BIGINT DEFAULT 0,
    azure_files INTEGER DEFAULT 0,
    local_files INTEGER DEFAULT 0,
    transfer_bytes BIGINT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(date)
);

-- Create index for storage stats lookups
CREATE INDEX IF NOT EXISTS idx_storage_stats_date ON storage_stats(date);

-- Insert initial storage stats record
INSERT INTO storage_stats (date, total_files, azure_files, local_files)
VALUES (CURRENT_DATE,
    (SELECT COUNT(*) FROM books WHERE azure_audio_path IS NOT NULL),
    (SELECT COUNT(*) FROM books WHERE storage_provider = 'azure'),
    (SELECT COUNT(*) FROM books WHERE storage_provider = 'local')
) ON CONFLICT (date) DO NOTHING;

-- Add comments for documentation
COMMENT ON COLUMN books.azure_audio_path IS 'Path to audio files in Azure Blob Storage (book_folder/)';
COMMENT ON COLUMN books.azure_cover_path IS 'Path to cover images in Azure Blob Storage (book_folder/)';
COMMENT ON COLUMN books.storage_provider IS 'Storage backend: azure, local, or hybrid';
COMMENT ON COLUMN books.file_size_bytes IS 'Total size of all audio files for this book';
COMMENT ON COLUMN books.audio_duration_seconds IS 'Total duration of audiobook in seconds';

COMMENT ON FUNCTION get_audio_url(TEXT, TEXT) IS 'Generate audio URL for mobile app compatibility';
COMMENT ON FUNCTION get_book_chapters(UUID) IS 'List all chapters for a book with Azure paths';
COMMENT ON TABLE storage_stats IS 'Track Azure Storage usage and file statistics';

-- Create view for books with storage information
CREATE OR REPLACE VIEW books_with_storage AS
SELECT
    b.*,
    CASE
        WHEN b.storage_provider = 'azure' AND b.azure_audio_path IS NOT NULL THEN
            '/audio/stream/' || b.title || '/Chapter 1.mp3'
        WHEN b.sample_audio_url IS NOT NULL THEN
            b.sample_audio_url
        ELSE
            '/audio/' || b.title || '/Chapter 1.mp3'
    END as computed_sample_url,
    CASE
        WHEN b.file_size_bytes IS NOT NULL THEN
            pg_size_pretty(b.file_size_bytes)
        ELSE
            'Unknown size'
    END as formatted_file_size,
    CASE
        WHEN b.audio_duration_seconds IS NOT NULL THEN
            INTERVAL '1 second' * b.audio_duration_seconds
        ELSE
            NULL
    END as formatted_duration
FROM books b;

COMMENT ON VIEW books_with_storage IS 'Books with computed storage URLs and formatted metadata';

-- Create migration log table if it doesn't exist
CREATE TABLE IF NOT EXISTS migration_log (
    version VARCHAR(10) PRIMARY KEY,
    description TEXT,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Migration completion log
INSERT INTO migration_log (version, description, applied_at)
VALUES ('V012', 'Azure Storage paths and audio streaming support', NOW())
ON CONFLICT (version) DO UPDATE SET
    applied_at = NOW(),
    description = EXCLUDED.description;