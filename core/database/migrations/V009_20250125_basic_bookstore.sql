-- V009: Basic Bookstore Tables
-- Creates essential tables for bookstore functionality with real book data

-- Create books table (compatible with existing system)
CREATE TABLE IF NOT EXISTS books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    author VARCHAR(255),
    narrator VARCHAR(255),
    publisher VARCHAR(255),
    description TEXT,
    duration_minutes INTEGER,
    language VARCHAR(10) DEFAULT 'en',
    isbn VARCHAR(20),
    cover_image_url TEXT,
    sample_audio_url TEXT,
    sample_duration INTEGER DEFAULT 180, -- 3 minutes in seconds
    price_usd DECIMAL(6,2) DEFAULT 14.95,
    credit_price INTEGER DEFAULT 1,
    category_id UUID,
    is_featured BOOLEAN DEFAULT false,
    is_bestseller BOOLEAN DEFAULT false,
    is_new_release BOOLEAN DEFAULT false,
    publication_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Additional fields for audiobook files
    file_path TEXT, -- Path to the main book folder
    total_chapters INTEGER DEFAULT 1,
    file_size_bytes BIGINT,
    
    -- Search and statistics
    search_vector TSVECTOR,
    average_rating DECIMAL(3,2) DEFAULT 0.0,
    review_count INTEGER DEFAULT 0,
    purchase_count INTEGER DEFAULT 0
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
CREATE INDEX IF NOT EXISTS idx_books_author ON books(author);
CREATE INDEX IF NOT EXISTS idx_books_category ON books(category_id);
CREATE INDEX IF NOT EXISTS idx_books_featured ON books(is_featured) WHERE is_featured = true;
CREATE INDEX IF NOT EXISTS idx_books_bestseller ON books(is_bestseller) WHERE is_bestseller = true;
CREATE INDEX IF NOT EXISTS idx_books_new_release ON books(is_new_release) WHERE is_new_release = true;
CREATE INDEX IF NOT EXISTS idx_books_search ON books USING GIN(search_vector);

-- Create book categories table
CREATE TABLE IF NOT EXISTS book_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    image_url TEXT,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on category display order
CREATE INDEX IF NOT EXISTS idx_categories_order ON book_categories(display_order);

-- Add foreign key constraint
ALTER TABLE books ADD CONSTRAINT fk_books_category 
    FOREIGN KEY (category_id) REFERENCES book_categories(id);

-- Insert default categories
INSERT INTO book_categories (name, description, display_order) VALUES
('Fiction', 'Literary fiction and novels', 1),
('Classic Literature', 'Timeless literary works', 2),
('Epic Poetry', 'Epic poems and classical works', 3),
('Drama', 'Plays and dramatic works', 4),
('Romance', 'Love stories and romantic fiction', 5),
('Mystery', 'Mystery and suspense novels', 6)
ON CONFLICT (name) DO NOTHING;

-- Function to update search vector
CREATE OR REPLACE FUNCTION update_book_search_vector() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := to_tsvector('english', 
        COALESCE(NEW.title, '') || ' ' || 
        COALESCE(NEW.author, '') || ' ' || 
        COALESCE(NEW.narrator, '') || ' ' ||
        COALESCE(NEW.description, '')
    );
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for search vector updates
DROP TRIGGER IF EXISTS trigger_update_book_search_vector ON books;
CREATE TRIGGER trigger_update_book_search_vector
    BEFORE INSERT OR UPDATE ON books
    FOR EACH ROW EXECUTE FUNCTION update_book_search_vector();

-- Insert our actual books
DO $$
DECLARE
    fiction_id UUID;
    classic_id UUID;
    epic_id UUID;
BEGIN
    -- Get category IDs
    SELECT id INTO fiction_id FROM book_categories WHERE name = 'Fiction';
    SELECT id INTO classic_id FROM book_categories WHERE name = 'Classic Literature';
    SELECT id INTO epic_id FROM book_categories WHERE name = 'Epic Poetry';

    -- Insert The Great Gatsby
    INSERT INTO books (
        title, 
        author, 
        narrator,
        description, 
        duration_minutes,
        price_usd,
        credit_price,
        category_id,
        is_featured,
        is_bestseller,
        publication_date,
        file_path,
        total_chapters,
        cover_image_url,
        sample_audio_url,
        sample_duration,
        average_rating,
        review_count,
        purchase_count
    ) VALUES (
        'The Great Gatsby',
        'F. Scott Fitzgerald',
        'Professional Narrator',
        'The Great Gatsby is a 1925 novel by American writer F. Scott Fitzgerald. Set in the Jazz Age on prosperous Long Island and in New York City, the novel tells the story of Jay Gatsby and his pursuit of Daisy Buchanan. A masterpiece of American literature that captures the decadence and idealism of the Roaring Twenties.',
        540, -- Approximately 9 hours (9 chapters * 60 minutes average)
        12.95,
        1,
        fiction_id,
        true, -- featured
        true, -- bestseller
        '1925-04-10',
        'The Great Gatsby',
        9,
        '/books/cover/The Great Gatsby/GatsbyCover.jpg',
        '/books/The Great Gatsby/Chapter 1.mp3',
        180,
        4.2,
        1247,
        5632
    );

    -- Insert The Odyssey
    INSERT INTO books (
        title, 
        author, 
        narrator,
        description, 
        duration_minutes,
        price_usd,
        credit_price,
        category_id,
        is_featured,
        is_new_release,
        publication_date,
        file_path,
        total_chapters,
        cover_image_url,
        sample_audio_url,
        sample_duration,
        average_rating,
        review_count,
        purchase_count
    ) VALUES (
        'The Odyssey',
        'Homer',
        'Samuel Butler (Translation)',
        'The Odyssey is one of two major ancient Greek epic poems attributed to Homer. It is one of the oldest extant works of literature still widely read by modern audiences. The poem tells the story of Odysseus, king of Ithaca, who wanders for ten years trying to get home after the Trojan War.',
        1440, -- Approximately 24 hours (24 books * 60 minutes average)
        15.95,
        1,
        epic_id,
        true, -- featured
        false,
        '0800-01-01', -- Approximate ancient date
        'Odyssey',
        24,
        '/books/cover/Odyssey/odessey.jpeg',
        '/books/Odyssey/odyssey_01_homer_butler_64kb.mp3',
        180,
        4.5,
        892,
        3241
    );

END $$;

-- Create basic user purchases table for ownership tracking
CREATE TABLE IF NOT EXISTS user_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    purchase_type VARCHAR(20) NOT NULL DEFAULT 'credit', -- 'credit', 'cash', 'gift', 'subscription'
    price_paid DECIMAL(6,2),
    credits_used INTEGER DEFAULT 0,
    
    UNIQUE(user_id, book_id) -- Prevent duplicate purchases
);

CREATE INDEX IF NOT EXISTS idx_user_purchases_user ON user_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_user_purchases_book ON user_purchases(book_id);

-- Create basic user credits table
CREATE TABLE IF NOT EXISTS user_credits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    total_credits INTEGER DEFAULT 0,
    used_credits INTEGER DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_credits_user ON user_credits(user_id);

-- Create basic wishlist table
CREATE TABLE IF NOT EXISTS user_wishlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, book_id) -- Prevent duplicate wishlist items
);

CREATE INDEX IF NOT EXISTS idx_user_wishlist_user ON user_wishlist(user_id);

-- Function to initialize user credits (called when user is created)
CREATE OR REPLACE FUNCTION initialize_user_credits(p_user_id UUID, p_initial_credits INTEGER DEFAULT 2) 
RETURNS VOID AS $$
BEGIN
    INSERT INTO user_credits (user_id, total_credits, used_credits, last_updated)
    VALUES (p_user_id, p_initial_credits, 0, NOW())
    ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Grant access to existing users (give them 2 free credits to start)
DO $$
DECLARE
    user_record RECORD;
BEGIN
    FOR user_record IN SELECT id FROM users LOOP
        PERFORM initialize_user_credits(user_record.id, 2);
    END LOOP;
END $$;

COMMENT ON TABLE books IS 'Audiobook catalog with metadata and file references';
COMMENT ON TABLE book_categories IS 'Book categories for organization and browsing';
COMMENT ON TABLE user_purchases IS 'User book purchase history and ownership tracking';
COMMENT ON TABLE user_credits IS 'User credit balance for audiobook purchases';
COMMENT ON TABLE user_wishlist IS 'User wishlist for books they want to purchase';

-- Migration complete
SELECT 'V009 Migration Complete: Basic bookstore tables created with The Great Gatsby and The Odyssey' as status;