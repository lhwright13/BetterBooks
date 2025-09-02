-- V015: Update Book Chapters with Azure Storage File Paths
-- Sets file paths to match the actual files uploaded to Azure Storage

-- Update The Great Gatsby chapters with correct Azure paths
DO $$
DECLARE
    gatsby_id UUID;
BEGIN
    -- Get The Great Gatsby book ID
    SELECT id INTO gatsby_id FROM books WHERE title = 'The Great Gatsby' LIMIT 1;
    
    IF gatsby_id IS NOT NULL THEN
        -- Update with paths that match uploaded files
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 1.mp3' WHERE book_id = gatsby_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 2.mp3' WHERE book_id = gatsby_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 3.mp3' WHERE book_id = gatsby_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 4.mp3' WHERE book_id = gatsby_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 5.mp3' WHERE book_id = gatsby_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 6.mp3' WHERE book_id = gatsby_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 7.mp3' WHERE book_id = gatsby_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 8.mp3' WHERE book_id = gatsby_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/Chapter 9.mp3' WHERE book_id = gatsby_id AND chapter_number = 9;
        
        RAISE NOTICE 'Updated % chapters for The Great Gatsby with Azure paths', 9;
    END IF;
END $$;

-- Update Moby Dick chapters with Azure paths
DO $$
DECLARE
    moby_id UUID;
BEGIN
    -- Get Moby Dick book ID
    SELECT id INTO moby_id FROM books WHERE title = 'Moby Dick' LIMIT 1;
    
    IF moby_id IS NOT NULL THEN
        -- Update with paths that match uploaded files (using the first 10)
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_000_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_001_002_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_003_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_004_007_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_008_009_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_010_012_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_013_015_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_016_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_017_021_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 9;
        UPDATE book_chapters SET file_path = 'Moby Dick/mobydick_022_025_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 10;
        
        RAISE NOTICE 'Updated % chapters for Moby Dick with Azure paths', 10;
    END IF;
END $$;