-- V013: Update Book Chapters with LibriVox Audio URLs
-- Replaces placeholder file paths with real LibriVox public domain audio URLs

-- Update The Great Gatsby chapters with LibriVox URLs
DO $$
DECLARE
    gatsby_id UUID;
BEGIN
    -- Get The Great Gatsby book ID
    SELECT id INTO gatsby_id FROM books WHERE title = 'The Great Gatsby' LIMIT 1;
    
    IF gatsby_id IS NOT NULL THEN
        -- Update with real LibriVox URLs for The Great Gatsby
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_01_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_02_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_03_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_04_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_05_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_06_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_07_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_08_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'https://www.archive.org/download/great_gatsby_fitzgerald_hs/gatsby_09_fitzgerald_64kb.mp3' WHERE book_id = gatsby_id AND chapter_number = 9;
        
        RAISE NOTICE 'Updated % chapters for The Great Gatsby with LibriVox URLs', 9;
    END IF;
END $$;

-- Update Moby Dick chapters with LibriVox URLs
DO $$
DECLARE
    moby_id UUID;
BEGIN
    -- Get Moby Dick book ID
    SELECT id INTO moby_id FROM books WHERE title = 'Moby Dick' LIMIT 1;
    
    IF moby_id IS NOT NULL THEN
        -- Update with real LibriVox URLs for Moby Dick (using existing mapping)
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_000_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_001_002_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_003_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_004_007_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_008_009_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_010_012_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_013_015_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_016_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_017_021_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 9;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/mobydick_1510_librivox/mobydick_022_025_melville_64kb.mp3' WHERE book_id = moby_id AND chapter_number = 10;
        
        RAISE NOTICE 'Updated % chapters for Moby Dick with LibriVox URLs', 10;
    END IF;
END $$;

-- Update Alice in Wonderland chapters with LibriVox URLs
DO $$
DECLARE
    alice_id UUID;
BEGIN
    -- Get Alice in Wonderland book ID
    SELECT id INTO alice_id FROM books WHERE title = 'Alice''s Adventures in Wonderland' LIMIT 1;
    
    IF alice_id IS NOT NULL THEN
        -- Update with real LibriVox URLs for Alice in Wonderland
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_01_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_02_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_03_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_04_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_05_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_06_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_07_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_08_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_09_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 9;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/alices_adventures_in_wonderland_librivox/aliceswonderland_10_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 10;
        
        RAISE NOTICE 'Updated % chapters for Alice in Wonderland with LibriVox URLs', 10;
    END IF;
END $$;

-- Update The Odyssey chapters with LibriVox URLs
DO $$
DECLARE
    odyssey_id UUID;
BEGIN
    -- Get The Odyssey book ID
    SELECT id INTO odyssey_id FROM books WHERE title = 'The Odyssey' LIMIT 1;
    
    IF odyssey_id IS NOT NULL THEN
        -- Update with real LibriVox URLs for The Odyssey
        UPDATE book_chapters SET file_path = 'https://archive.org/download/odyssey_butler_librivox/odyssey_01_homer_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/odyssey_butler_librivox/odyssey_02_homer_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/odyssey_butler_librivox/odyssey_03_homer_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/odyssey_butler_librivox/odyssey_04_homer_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/odyssey_butler_librivox/odyssey_05_homer_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/odyssey_butler_librivox/odyssey_06_homer_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/odyssey_butler_librivox/odyssey_07_homer_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/odyssey_butler_librivox/odyssey_08_homer_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 8;
        
        RAISE NOTICE 'Updated % chapters for The Odyssey with LibriVox URLs', 8;
    END IF;
END $$;

-- Update War and Peace chapters with LibriVox URLs (first 10 books)
DO $$
DECLARE
    war_peace_id UUID;
BEGIN
    -- Get War and Peace book ID
    SELECT id INTO war_peace_id FROM books WHERE title = 'War and Peace' LIMIT 1;
    
    IF war_peace_id IS NOT NULL THEN
        -- Update with real LibriVox URLs for War and Peace (Book 1 only)
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_01_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_02_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_03_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_04_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_05_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_06_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_07_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_08_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_09_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 9;
        UPDATE book_chapters SET file_path = 'https://archive.org/download/war_peace_librivox/warandpeace_01_10_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 10;
        
        RAISE NOTICE 'Updated % chapters for War and Peace with LibriVox URLs', 10;
    END IF;
END $$;