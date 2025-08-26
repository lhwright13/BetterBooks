-- V011: Add New Books to Bookstore
-- Adds Alice's Adventures in Wonderland, Moby Dick, and War and Peace

-- Insert the three new books into the catalog
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

    -- Insert Alice's Adventures in Wonderland
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
        'Alice''s Adventures in Wonderland',
        'Lewis Carroll',
        'LibriVox Reader',
        'Alice''s Adventures in Wonderland is an 1865 English children''s novel by Lewis Carroll. It tells of a young girl named Alice who falls through a rabbit hole into a subterranean fantasy world populated by peculiar, anthropomorphic creatures. The tale plays with logic, giving the story lasting popularity with adults as well as with children.',
        360, -- Approximately 6 hours (12 chapters * 30 minutes average)
        9.95,
        1,
        classic_id,
        true, -- featured
        true, -- new release
        '1865-11-26',
        'Alice''s Adventures in Wonderland',
        12,
        '/books/cover/Alice''s Adventures in Wonderland/aliceinWonder.jpg',
        '/books/Alice''s Adventures in Wonderland/alices_adventures_01_carroll_64kb.mp3',
        180,
        4.3,
        2156,
        4892
    );

    -- Insert Moby Dick
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
        'Moby Dick',
        'Herman Melville',
        'LibriVox Readers',
        'Moby-Dick is an 1851 novel by Herman Melville. The book is the sailor Ishmael''s narrative of the obsessive quest of Ahab, captain of the whaling ship Pequod, for revenge on Moby Dick, the giant white sperm whale that on the ship''s previous voyage bit off Ahab''s leg at the knee.',
        2580, -- Approximately 43 hours (43 chapters * 60 minutes average)
        19.95,
        1,
        classic_id,
        true, -- featured
        true, -- bestseller
        '1851-10-18',
        'Moby Dick',
        43,
        '/books/cover/Moby Dick/Moby_Dick_1002.jpg',
        '/books/Moby Dick/mobydick_000_melville_64kb.mp3',
        180,
        4.1,
        1823,
        3967
    );

    -- Insert War and Peace (Volume 1)
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
        'War and Peace',
        'Leo Tolstoy',
        'LibriVox Readers',
        'War and Peace is a novel by the Russian author Leo Tolstoy, published serially, then in its entirety in 1869. It is regarded as one of Tolstoy''s finest literary achievements and remains an internationally praised classic of world literature. This is Volume 1 of the complete work.',
        4080, -- Approximately 68 hours (68 chapters * 60 minutes average)
        24.95,
        2, -- 2 credits due to length
        classic_id,
        true, -- featured
        true, -- bestseller
        '1869-01-01',
        'War and Peace',
        68,
        '/books/cover/War and Peace/warandpeacecover.jpg',
        '/books/War and Peace/war_peace_v1_maude_translation_01_tolstoy_64kb.mp3',
        180,
        4.6,
        3421,
        7892
    );

END $$;

-- Update book categories with book counts
UPDATE book_categories SET 
    updated_at = NOW()
WHERE name IN ('Fiction', 'Classic Literature', 'Epic Poetry');

-- Migration complete message
SELECT 'V011 Migration Complete: Added Alice in Wonderland, Moby Dick, and War and Peace to bookstore' as status;