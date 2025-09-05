-- Migration: V019_20250904_add_wishlist_system.sql
-- Description: Add wishlist functionality for users to save books they want to purchase later
-- Date: 2025-09-04

-- Create user_wishlists table
CREATE TABLE IF NOT EXISTS user_wishlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    book_id UUID NOT NULL,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Foreign key constraints
    CONSTRAINT fk_user_wishlists_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_wishlists_book FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE,
    
    -- Prevent duplicate wishlist entries
    CONSTRAINT unique_user_book_wishlist UNIQUE (user_id, book_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_wishlists_user_id ON user_wishlists(user_id);
CREATE INDEX IF NOT EXISTS idx_user_wishlists_book_id ON user_wishlists(book_id);
CREATE INDEX IF NOT EXISTS idx_user_wishlists_added_at ON user_wishlists(added_at DESC);

-- Create a composite index for efficient wishlist queries
CREATE INDEX IF NOT EXISTS idx_user_wishlists_user_added ON user_wishlists(user_id, added_at DESC);

-- Add comments for documentation
COMMENT ON TABLE user_wishlists IS 'User wishlists - books that users want to purchase later';
COMMENT ON COLUMN user_wishlists.user_id IS 'Reference to the user who owns this wishlist item';
COMMENT ON COLUMN user_wishlists.book_id IS 'Reference to the book in the wishlist';
COMMENT ON COLUMN user_wishlists.added_at IS 'When the book was added to the wishlist';