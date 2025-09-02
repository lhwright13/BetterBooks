-- V014: Fix Local Audio File Paths
-- Update book chapters to use correct local file paths that match existing book_files directory

-- Update The Great Gatsby chapters with correct local paths
DO $$
DECLARE
    gatsby_id UUID;
BEGIN
    -- Get The Great Gatsby book ID
    SELECT id INTO gatsby_id FROM books WHERE title = 'The Great Gatsby' LIMIT 1;
    
    IF gatsby_id IS NOT NULL THEN
        -- Update with local file paths that match the existing directory structure
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_01_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_02_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_03_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_04_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_05_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_06_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_07_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_08_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'The Great Gatsby/gatsby_09_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 9;
        
        RAISE NOTICE 'Updated % chapters for The Great Gatsby with local file paths', 9;
    END IF;
END $$;

-- Update Moby Dick chapters with correct local paths
DO $$
DECLARE
    moby_id UUID;
BEGIN
    -- Get Moby Dick book ID
    SELECT id INTO moby_id FROM books WHERE title = 'Moby Dick' LIMIT 1;
    
    IF moby_id IS NOT NULL THEN
        -- Update with local file paths that match existing files
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
        
        RAISE NOTICE 'Updated % chapters for Moby Dick with local file paths', 10;
    END IF;
END $$;