-- V012: Add Book Chapters Data
-- Populates book_chapters table with chapter data for all 5 books

-- Insert chapters for The Great Gatsby (9 chapters)
DO $$
DECLARE
    gatsby_id UUID;
BEGIN
    -- Get The Great Gatsby book ID
    SELECT id INTO gatsby_id FROM books WHERE title = 'The Great Gatsby' LIMIT 1;
    
    IF gatsby_id IS NOT NULL THEN
        INSERT INTO book_chapters (book_id, chapter_number, title, file_path, duration_seconds) VALUES
            (gatsby_id, 1, 'Chapter 1', 'The Great Gatsby/Chapter 1.mp3', 1800),
            (gatsby_id, 2, 'Chapter 2', 'The Great Gatsby/Chapter 2.mp3', 1800),
            (gatsby_id, 3, 'Chapter 3', 'The Great Gatsby/Chapter 3.mp3', 1800),
            (gatsby_id, 4, 'Chapter 4', 'The Great Gatsby/Chapter 4.mp3', 1800),
            (gatsby_id, 5, 'Chapter 5', 'The Great Gatsby/Chapter 5.mp3', 1800),
            (gatsby_id, 6, 'Chapter 6', 'The Great Gatsby/Chapter 6.mp3', 1800),
            (gatsby_id, 7, 'Chapter 7', 'The Great Gatsby/Chapter 7.mp3', 1800),
            (gatsby_id, 8, 'Chapter 8', 'The Great Gatsby/Chapter 8.mp3', 1800),
            (gatsby_id, 9, 'Chapter 9', 'The Great Gatsby/Chapter 9.mp3', 1800);
        
        RAISE NOTICE 'Inserted % chapters for The Great Gatsby', 9;
    END IF;
END $$;

-- Insert chapters for Moby Dick (first 20 parts)
DO $$
DECLARE
    moby_id UUID;
    chapter_data RECORD;
    chapter_counter INTEGER := 1;
BEGIN
    -- Get Moby Dick book ID
    SELECT id INTO moby_id FROM books WHERE title = 'Moby Dick' LIMIT 1;
    
    IF moby_id IS NOT NULL THEN
        -- Array of Moby Dick chapter files with proper titles
        INSERT INTO book_chapters (book_id, chapter_number, title, file_path, duration_seconds) VALUES
            (moby_id, 1, 'Introduction', 'Moby Dick/mobydick_000_melville_64kb.mp3', 1200),
            (moby_id, 2, 'Chapters 1-2: Loomings, The Carpet-Bag', 'Moby Dick/mobydick_001_002_melville_64kb.mp3', 1200),
            (moby_id, 3, 'Chapter 3: The Spouter-Inn', 'Moby Dick/mobydick_003_melville_64kb.mp3', 1200),
            (moby_id, 4, 'Chapters 4-7: The Counterpane to The Chapel', 'Moby Dick/mobydick_004_007_melville_64kb.mp3', 1200),
            (moby_id, 5, 'Chapters 8-9: The Pulpit, The Sermon', 'Moby Dick/mobydick_008_009_melville_64kb.mp3', 1200),
            (moby_id, 6, 'Chapters 10-12: A Bosom Friend to Biographical', 'Moby Dick/mobydick_010_012_melville_64kb.mp3', 1200),
            (moby_id, 7, 'Chapters 13-15: Wheelbarrow to Chowder', 'Moby Dick/mobydick_013_015_melville_64kb.mp3', 1200),
            (moby_id, 8, 'Chapter 16: The Ship', 'Moby Dick/mobydick_016_melville_64kb.mp3', 1200),
            (moby_id, 9, 'Chapters 17-21: The Ramadan to Going Aboard', 'Moby Dick/mobydick_017_021_melville_64kb.mp3', 1200),
            (moby_id, 10, 'Chapters 22-25: Merry Christmas to Postscript', 'Moby Dick/mobydick_022_025_melville_64kb.mp3', 1200),
            (moby_id, 11, 'Chapters 26-27: Knights and Squires', 'Moby Dick/mobydick_026_027_melville_64kb.mp3', 1200),
            (moby_id, 12, 'Chapters 28-31: Ahab to Queen Mab', 'Moby Dick/mobydick_028_031_melville_64kb.mp3', 1200),
            (moby_id, 13, 'Chapter 32: Cetology', 'Moby Dick/mobydick_032_melville_64kb.mp3', 1200),
            (moby_id, 14, 'Chapters 33-35: The Specksnyder to The Quarter-Deck', 'Moby Dick/mobydick_033_035_melville_64kb.mp3', 1200),
            (moby_id, 15, 'Chapters 36-40: The Quarter-Deck to Midnight, Forecastle', 'Moby Dick/mobydick_036_040_melville_64kb.mp3', 1200),
            (moby_id, 16, 'Chapter 41: Moby Dick', 'Moby Dick/mobydick_041_melville_64kb.mp3', 1200),
            (moby_id, 17, 'Chapters 42-44: The Whiteness to The Chart', 'Moby Dick/mobydick_042_044_melville_64kb.mp3', 1200),
            (moby_id, 18, 'Chapters 45-47: The Affidavit to The Mat-Maker', 'Moby Dick/mobydick_045_047_melville_64kb.mp3', 1200),
            (moby_id, 19, 'Chapters 48-50: The First Lowering to Ahab''s Boat', 'Moby Dick/mobydick_048_050_melville_64kb.mp3', 1200),
            (moby_id, 20, 'Chapters 51-53: The Spirit-Spout to The Gam', 'Moby Dick/mobydick_051_053_melville_64kb.mp3', 1200);
        
        RAISE NOTICE 'Inserted % chapters for Moby Dick', 20;
    END IF;
END $$;

-- Insert chapters for The Odyssey (24 books)  
DO $$
DECLARE
    odyssey_id UUID;
    i INTEGER;
BEGIN
    -- Get The Odyssey book ID
    SELECT id INTO odyssey_id FROM books WHERE title = 'The Odyssey' LIMIT 1;
    
    IF odyssey_id IS NOT NULL THEN
        -- Insert 24 books (chapters) of The Odyssey
        FOR i IN 1..24 LOOP
            INSERT INTO book_chapters (book_id, chapter_number, title, file_path, duration_seconds) VALUES
                (odyssey_id, i, 'Book ' || i, 'Odyssey/odyssey_' || LPAD(i::text, 2, '0') || '_homer_butler_64kb.mp3', 3600);
        END LOOP;
        
        RAISE NOTICE 'Inserted % chapters for The Odyssey', 24;
    END IF;
END $$;

-- Insert chapters for Alice's Adventures in Wonderland (12 chapters)
DO $$
DECLARE
    alice_id UUID;
    alice_chapters TEXT[] := ARRAY[
        'Chapter I: Down the Rabbit-Hole',
        'Chapter II: The Pool of Tears', 
        'Chapter III: A Caucus-Race and a Long Tale',
        'Chapter IV: The Rabbit Sends in a Little Bill',
        'Chapter V: Advice from a Caterpillar',
        'Chapter VI: Pig and Pepper',
        'Chapter VII: A Mad Tea-Party',
        'Chapter VIII: The Queen''s Croquet-Ground',
        'Chapter IX: The Mock Turtle''s Story',
        'Chapter X: The Lobster Quadrille',
        'Chapter XI: Who Stole the Tarts?',
        'Chapter XII: Alice''s Evidence'
    ];
    i INTEGER;
BEGIN
    -- Get Alice book ID
    SELECT id INTO alice_id FROM books WHERE title = 'Alice''s Adventures in Wonderland' LIMIT 1;
    
    IF alice_id IS NOT NULL THEN
        FOR i IN 1..12 LOOP
            INSERT INTO book_chapters (book_id, chapter_number, title, file_path, duration_seconds) VALUES
                (alice_id, i, alice_chapters[i], 'Alice''s Adventures in Wonderland/alices_adventures_' || LPAD(i::text, 2, '0') || '_carroll_64kb.mp3', 1800);
        END LOOP;
        
        RAISE NOTICE 'Inserted % chapters for Alice''s Adventures in Wonderland', 12;
    END IF;
END $$;

-- Insert chapters for War and Peace (first 20 chapters of Volume 1)
DO $$
DECLARE
    war_peace_id UUID;
    i INTEGER;
BEGIN
    -- Get War and Peace book ID
    SELECT id INTO war_peace_id FROM books WHERE title = 'War and Peace' LIMIT 1;
    
    IF war_peace_id IS NOT NULL THEN
        -- Insert first 20 chapters of Volume 1
        FOR i IN 1..20 LOOP
            INSERT INTO book_chapters (book_id, chapter_number, title, file_path, duration_seconds) VALUES
                (war_peace_id, i, 'Volume 1, Chapter ' || i, 'War and Peace/war_peace_v1_maude_translation_' || LPAD(i::text, 2, '0') || '_tolstoy_64kb.mp3', 3600);
        END LOOP;
        
        RAISE NOTICE 'Inserted % chapters for War and Peace Volume 1', 20;
    END IF;
END $$;

-- Update book total_chapters field to match actual chapter count
UPDATE books SET total_chapters = (
    SELECT COUNT(*) FROM book_chapters WHERE book_chapters.book_id = books.id
) WHERE id IN (
    SELECT DISTINCT book_id FROM book_chapters
);

-- Update book duration_minutes based on chapter durations
UPDATE books SET duration_minutes = (
    SELECT SUM(duration_seconds) / 60 FROM book_chapters WHERE book_chapters.book_id = books.id
) WHERE id IN (
    SELECT DISTINCT book_id FROM book_chapters
);

-- Migration complete message
SELECT 'V012 Migration Complete: Added chapter data for all 5 books' as status;