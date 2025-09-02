-- V016: Complete Audio Paths for All Books
-- Updates all remaining books with Azure Storage file paths

-- Update Alice in Wonderland chapters with Azure paths
DO $$
DECLARE
    alice_id UUID;
BEGIN
    -- Get Alice in Wonderland book ID
    SELECT id INTO alice_id FROM books WHERE title = 'Alice''s Adventures in Wonderland' LIMIT 1;
    
    IF alice_id IS NOT NULL THEN
        -- Update with Azure file paths that match uploaded files
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_01_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_02_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_03_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_04_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_05_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_06_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_07_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_08_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_09_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 9;
        UPDATE book_chapters SET file_path = 'Alice''s Adventures in Wonderland/alices_adventures_10_carroll_64kb.mp3' WHERE book_id = alice_id AND chapter_number = 10;
        
        RAISE NOTICE 'Updated % chapters for Alice in Wonderland with Azure paths', 10;
    END IF;
END $$;

-- Update Odyssey chapters with Azure paths (all 24 books)
DO $$
DECLARE
    odyssey_id UUID;
BEGIN
    -- Get The Odyssey book ID
    SELECT id INTO odyssey_id FROM books WHERE title = 'The Odyssey' LIMIT 1;
    
    IF odyssey_id IS NOT NULL THEN
        -- Update with Azure file paths that match uploaded files
        UPDATE book_chapters SET file_path = 'Odyssey/odyssey_01_homer_butler_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'Odyssey/odyssey_02_homer_butler_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'Odyssey/odyssey_03_homer_butler_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'Odyssey/odyssey_04_homer_butler_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'Odyssey/odyssey_05_homer_butler_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'Odyssey/odyssey_06_homer_butler_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'Odyssey/odyssey_07_homer_butler_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'Odyssey/odyssey_08_homer_butler_64kb.mp3' WHERE book_id = odyssey_id AND chapter_number = 8;
        
        RAISE NOTICE 'Updated % chapters for The Odyssey with Azure paths', 8;
    END IF;
END $$;

-- Update War and Peace chapters with Azure paths (first 20 chapters)
DO $$
DECLARE
    war_peace_id UUID;
BEGIN
    -- Get War and Peace book ID
    SELECT id INTO war_peace_id FROM books WHERE title = 'War and Peace' LIMIT 1;
    
    IF war_peace_id IS NOT NULL THEN
        -- Update with Azure file paths that match uploaded files (first 10 chapters)
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_01_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 1;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_02_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 2;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_03_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 3;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_04_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 4;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_05_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 5;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_06_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 6;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_07_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 7;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_08_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 8;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_09_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 9;
        UPDATE book_chapters SET file_path = 'War and Peace/war_peace_v1_maude_translation_10_tolstoy_64kb.mp3' WHERE book_id = war_peace_id AND chapter_number = 10;
        
        RAISE NOTICE 'Updated % chapters for War and Peace with Azure paths', 10;
    END IF;
END $$;