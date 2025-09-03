-- Fix Empty Books Database
-- Execute this SQL against the production PostgreSQL database to populate books
-- This combines the book insertions from V009 and V011 migrations

-- Check current state
SELECT 'Current books count:' as info, COUNT(*) as count FROM books;
SELECT 'Current categories:' as info, name FROM book_categories;

-- Insert The Great Gatsby (from V009)
INSERT INTO books (
    title, author, narrator, description, duration_minutes, price_usd, credit_price, 
    category_id, is_featured, is_bestseller, publication_date, file_path, total_chapters,
    cover_image_url, sample_audio_url, sample_duration, average_rating, review_count, purchase_count
) VALUES (
    'The Great Gatsby', 
    'F. Scott Fitzgerald', 
    'Professional Narrator',
    'The Great Gatsby is a 1925 novel by American writer F. Scott Fitzgerald. Set in the Jazz Age on prosperous Long Island and in New York City, the novel tells the story of Jay Gatsby and his pursuit of Daisy Buchanan. A masterpiece of American literature that captures the decadence and idealism of the Roaring Twenties.',
    540, 
    12.95, 
    1, 
    (SELECT id FROM book_categories WHERE name = 'Fiction'),
    true, 
    true, 
    '1925-04-10', 
    'The Great Gatsby', 
    9,
    '/books/cover/The Great Gatsby/GatsbyCover.jpg',
    '/books/The Great Gatsby/Chapter 1.mp3',
    180,
    4.2,
    1247,
    3521
) ON CONFLICT (title, author) DO NOTHING;

-- Insert The Odyssey (from V009)  
INSERT INTO books (
    title, author, narrator, description, duration_minutes, price_usd, credit_price,
    category_id, is_featured, is_bestseller, publication_date, file_path, total_chapters,
    cover_image_url, sample_audio_url, sample_duration, average_rating, review_count, purchase_count
) VALUES (
    'The Odyssey',
    'Homer', 
    'LibriVox Readers',
    'The Odyssey is one of the major ancient Greek epic poems attributed to Homer. It is, in part, a sequel to The Iliad, the other work ascribed to Homer. The Odyssey follows the Greek hero Odysseus, king of Ithaca, and his journey home after the fall of Troy.',
    1440,
    16.95,
    1,
    (SELECT id FROM book_categories WHERE name = 'Classics'),
    true,
    true,
    '0800-01-01',
    'The Odyssey',
    24,
    '/books/cover/The Odyssey/OdysseyCover.jpg',
    '/books/The Odyssey/odyssey_01_homer_64kb.mp3',
    180,
    4.4,
    892,
    2341
) ON CONFLICT (title, author) DO NOTHING;

-- Insert Alice's Adventures in Wonderland (from V011)
INSERT INTO books (
    title, author, narrator, description, duration_minutes, price_usd, credit_price,
    category_id, is_featured, is_new_release, publication_date, file_path, total_chapters,
    cover_image_url, sample_audio_url, sample_duration, average_rating, review_count, purchase_count
) VALUES (
    'Alice''s Adventures in Wonderland',
    'Lewis Carroll',
    'LibriVox Reader', 
    'Alice''s Adventures in Wonderland is an 1865 English children''s novel by Lewis Carroll. It tells of a young girl named Alice who falls through a rabbit hole into a subterranean fantasy world populated by peculiar, anthropomorphic creatures. The tale plays with logic, giving the story lasting popularity with adults as well as with children.',
    360,
    9.95,
    1,
    (SELECT id FROM book_categories WHERE name = 'Classics'),
    true,
    true,
    '1865-11-26',
    'Alice''s Adventures in Wonderland',
    12,
    '/books/cover/Alice''s Adventures in Wonderland/aliceinWonder.jpg',
    '/books/Alice''s Adventures in Wonderland/alices_adventures_01_carroll_64kb.mp3',
    180,
    4.3,
    2156,
    4892
) ON CONFLICT (title, author) DO NOTHING;

-- Insert Moby Dick (from V011)
INSERT INTO books (
    title, author, narrator, description, duration_minutes, price_usd, credit_price,
    category_id, is_featured, is_bestseller, publication_date, file_path, total_chapters,
    cover_image_url, sample_audio_url, sample_duration, average_rating, review_count, purchase_count
) VALUES (
    'Moby Dick',
    'Herman Melville',
    'LibriVox Readers',
    'Moby-Dick is an 1851 novel by Herman Melville. The book is the sailor Ishmael''s narrative of the obsessive quest of Ahab, captain of the whaling ship Pequod, for revenge on Moby Dick, the giant white sperm whale that on the ship''s previous voyage bit off Ahab''s leg at the knee.',
    2580,
    19.95,
    1,
    (SELECT id FROM book_categories WHERE name = 'Classics'),
    true,
    true,
    '1851-10-18',
    'Moby Dick',
    43,
    '/books/cover/Moby Dick/Moby_Dick_1002.jpg',
    '/books/Moby Dick/mobydick_000_melville_64kb.mp3',
    180,
    4.1,
    1823,
    3967
) ON CONFLICT (title, author) DO NOTHING;

-- Insert War and Peace (from V011)
INSERT INTO books (
    title, author, narrator, description, duration_minutes, price_usd, credit_price,
    category_id, is_featured, is_bestseller, publication_date, file_path, total_chapters,
    cover_image_url, sample_audio_url, sample_duration, average_rating, review_count, purchase_count
) VALUES (
    'War and Peace',
    'Leo Tolstoy',
    'LibriVox Readers',
    'War and Peace is a novel by the Russian author Leo Tolstoy, published serially, then in its entirety in 1869. It is regarded as one of Tolstoy''s finest literary achievements and remains an internationally praised classic of world literature. This is Volume 1 of the complete work.',
    4080,
    24.95,
    2,
    (SELECT id FROM book_categories WHERE name = 'Classics'),
    true,
    true,
    '1869-01-01',
    'War and Peace',
    68,
    '/books/cover/War and Peace/warandpeacecover.jpg',
    '/books/War and Peace/war_peace_v1_maude_translation_01_tolstoy_64kb.mp3',
    180,
    4.6,
    3421,
    7892
) ON CONFLICT (title, author) DO NOTHING;

-- Verify the results
SELECT 'Books created successfully:' as result, COUNT(*) as total_books FROM books;
SELECT title, author, price_usd, credit_price FROM books ORDER BY title;

-- Show success message
SELECT 'MVP BLOCKER RESOLVED: Books database populated!' as status;