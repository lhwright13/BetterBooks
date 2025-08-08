-- Migration: Add Performance Indexes
-- Created: 2025-01-08T00:00:00
-- Version: V003_20250103

-- +migrate Up
-- Embeddings table indexes
CREATE INDEX IF NOT EXISTS idx_embeddings_book_id ON embeddings(book_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_chapter_id ON embeddings(chapter_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_book_chapter ON embeddings(book_id, chapter_id);
CREATE INDEX IF NOT EXISTS idx_embeddings_content_type ON embeddings(content_type);
CREATE INDEX IF NOT EXISTS idx_embeddings_created_at ON embeddings(created_at);
CREATE INDEX IF NOT EXISTS idx_embeddings_updated_at ON embeddings(updated_at);
CREATE INDEX IF NOT EXISTS idx_embeddings_metadata_gin ON embeddings USING gin(metadata);

-- Users table indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username ON users(username) WHERE username IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_last_login ON users(last_login);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);

-- Sessions table indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON sessions(created_at);

-- Audit logs indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_action_time ON audit_logs(user_id, action, created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource_type, resource_id);

-- Books table indexes
CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
CREATE INDEX IF NOT EXISTS idx_books_author ON books(author);
CREATE INDEX IF NOT EXISTS idx_books_genre ON books(genre);
CREATE INDEX IF NOT EXISTS idx_books_language ON books(language);
CREATE INDEX IF NOT EXISTS idx_books_publication_date ON books(publication_date);
CREATE INDEX IF NOT EXISTS idx_books_active ON books(is_active);
CREATE INDEX IF NOT EXISTS idx_books_created_at ON books(created_at);

-- Book chapters indexes
CREATE INDEX IF NOT EXISTS idx_book_chapters_book_id ON book_chapters(book_id);
CREATE INDEX IF NOT EXISTS idx_book_chapters_number ON book_chapters(book_id, chapter_number);
CREATE INDEX IF NOT EXISTS idx_book_chapters_times ON book_chapters(start_time_seconds, end_time_seconds);

-- User reading progress indexes
CREATE INDEX IF NOT EXISTS idx_user_progress_user_book ON user_reading_progress(user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_last_accessed ON user_reading_progress(last_accessed);
CREATE INDEX IF NOT EXISTS idx_user_progress_completion ON user_reading_progress(completion_percentage);
CREATE INDEX IF NOT EXISTS idx_user_progress_completed ON user_reading_progress(is_completed);

-- User bookmarks indexes
CREATE INDEX IF NOT EXISTS idx_user_bookmarks_user_book ON user_bookmarks(user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_user_bookmarks_position ON user_bookmarks(book_id, position_seconds);
CREATE INDEX IF NOT EXISTS idx_user_bookmarks_created_at ON user_bookmarks(created_at);

-- +migrate Down
-- Drop all created indexes
DROP INDEX IF EXISTS idx_user_bookmarks_created_at;
DROP INDEX IF EXISTS idx_user_bookmarks_position;
DROP INDEX IF EXISTS idx_user_bookmarks_user_book;
DROP INDEX IF EXISTS idx_user_progress_completed;
DROP INDEX IF EXISTS idx_user_progress_completion;
DROP INDEX IF EXISTS idx_user_progress_last_accessed;
DROP INDEX IF EXISTS idx_user_progress_user_book;
DROP INDEX IF EXISTS idx_book_chapters_times;
DROP INDEX IF EXISTS idx_book_chapters_number;
DROP INDEX IF EXISTS idx_book_chapters_book_id;
DROP INDEX IF EXISTS idx_books_created_at;
DROP INDEX IF EXISTS idx_books_active;
DROP INDEX IF EXISTS idx_books_publication_date;
DROP INDEX IF EXISTS idx_books_language;
DROP INDEX IF EXISTS idx_books_genre;
DROP INDEX IF EXISTS idx_books_author;
DROP INDEX IF EXISTS idx_books_title;
DROP INDEX IF EXISTS idx_audit_logs_resource;
DROP INDEX IF EXISTS idx_audit_logs_user_action_time;
DROP INDEX IF EXISTS idx_audit_logs_created_at;
DROP INDEX IF EXISTS idx_audit_logs_action;
DROP INDEX IF EXISTS idx_audit_logs_user_id;
DROP INDEX IF EXISTS idx_sessions_created_at;
DROP INDEX IF EXISTS idx_sessions_token_hash;
DROP INDEX IF EXISTS idx_sessions_expires_at;
DROP INDEX IF EXISTS idx_sessions_user_id;
DROP INDEX IF EXISTS idx_users_active;
DROP INDEX IF EXISTS idx_users_last_login;
DROP INDEX IF EXISTS idx_users_created_at;
DROP INDEX IF EXISTS idx_users_role;
DROP INDEX IF EXISTS idx_users_username;
DROP INDEX IF EXISTS idx_users_email;
DROP INDEX IF EXISTS idx_embeddings_metadata_gin;
DROP INDEX IF EXISTS idx_embeddings_updated_at;
DROP INDEX IF EXISTS idx_embeddings_created_at;
DROP INDEX IF EXISTS idx_embeddings_content_type;
DROP INDEX IF EXISTS idx_embeddings_book_chapter;
DROP INDEX IF EXISTS idx_embeddings_chapter_id;
DROP INDEX IF EXISTS idx_embeddings_book_id;