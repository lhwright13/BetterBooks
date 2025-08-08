-- Migration: Add Book Tracking Tables
-- Created: 2025-01-08T00:00:00
-- Version: V002_20250102

-- +migrate Up
-- Books catalog table
CREATE TABLE IF NOT EXISTS books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    author VARCHAR(300),
    isbn VARCHAR(20) UNIQUE,
    description TEXT,
    cover_image_url TEXT,
    audio_file_path TEXT,
    duration_seconds INTEGER,
    language VARCHAR(10) DEFAULT 'en',
    genre VARCHAR(100),
    publication_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Book chapters table
CREATE TABLE IF NOT EXISTS book_chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    chapter_number INTEGER NOT NULL,
    title VARCHAR(300),
    start_time_seconds INTEGER NOT NULL DEFAULT 0,
    end_time_seconds INTEGER,
    transcript TEXT,
    summary TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(book_id, chapter_number)
);

-- User reading progress
CREATE TABLE IF NOT EXISTS user_reading_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    current_position_seconds INTEGER DEFAULT 0,
    total_listening_time INTEGER DEFAULT 0,
    completion_percentage DECIMAL(5,2) DEFAULT 0.00,
    last_accessed TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_completed BOOLEAN DEFAULT false,
    UNIQUE(user_id, book_id)
);

-- User bookmarks
CREATE TABLE IF NOT EXISTS user_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    position_seconds INTEGER NOT NULL,
    title VARCHAR(200),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- +migrate Down
-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS user_bookmarks;
DROP TABLE IF EXISTS user_reading_progress;
DROP TABLE IF EXISTS book_chapters;
DROP TABLE IF EXISTS books;