#!/usr/bin/env python3
"""
Execute SQL migrations manually by connecting to the production database
Since direct PostgreSQL connection is blocked, we'll use a different approach
"""

import os
import sys
import json
import requests

# First try to understand what's in the database
API_BASE = "http://128.203.92.141:8000"

def check_database_status():
    """Check what's in the database through API calls"""
    
    print("=== DATABASE STATUS CHECK ===")
    
    # 1. Test database connection
    print("1. Testing database connection...")
    response = requests.get(f"{API_BASE}/database/test")
    if response.status_code == 200:
        print(f"   ✅ Database connected: {response.json()}")
    else:
        print(f"   ❌ Database connection failed: {response.status_code}")
        return False
    
    # 2. Check books
    print("2. Checking books...")
    response = requests.get(f"{API_BASE}/bookstore/browse")
    if response.status_code == 200:
        books_data = response.json()
        print(f"   📚 Books in database: {books_data['total_count']}")
        if books_data['total_count'] > 0:
            print("   Books found:")
            for book in books_data.get('books', []):
                print(f"     - {book.get('title', 'Unknown')} by {book.get('author', 'Unknown')}")
    else:
        print(f"   ❌ Failed to fetch books: {response.status_code}")
    
    # 3. Check categories
    print("3. Checking categories...")
    response = requests.get(f"{API_BASE}/bookstore/categories") 
    if response.status_code == 200:
        categories_data = response.json()
        print(f"   📁 Categories: {len(categories_data.get('categories', []))}")
        for cat in categories_data.get('categories', []):
            print(f"     - {cat.get('name', 'Unknown')}: {cat.get('description', '')}")
    else:
        print(f"   ❌ Failed to fetch categories: {response.status_code}")
    
    # 4. Check personas
    print("4. Checking personas...")
    response = requests.get(f"{API_BASE}/configs")
    if response.status_code == 200:
        personas_data = response.json()
        print(f"   🎭 Personas: {len(personas_data.get('configs', []))}")
        for persona in personas_data.get('configs', []):
            print(f"     - {persona}")
    else:
        print(f"   ❌ Failed to fetch personas: {response.status_code}")
    
    print("\n=== DIAGNOSIS ===")
    
    # Get books count
    response = requests.get(f"{API_BASE}/bookstore/browse")
    books_count = 0
    if response.status_code == 200:
        books_count = response.json().get('total_count', 0)
    
    # Get categories count  
    response = requests.get(f"{API_BASE}/bookstore/categories")
    categories_count = 0
    if response.status_code == 200:
        categories_count = len(response.json().get('categories', []))
    
    print(f"Books: {books_count}, Categories: {categories_count}")
    
    if categories_count > 0 and books_count == 0:
        print("✅ Database migrations have run (categories exist)")
        print("❌ Book data migrations have NOT run (no books)")
        print("\n🔧 SOLUTION: Need to run book insertion migrations:")
        print("   - V009_20250125_basic_bookstore.sql (creates The Great Gatsby + Odyssey)")
        print("   - V011_20250825_add_new_books.sql (adds Alice, Moby Dick, War and Peace)")
        return True
    elif categories_count == 0:
        print("❌ Basic database migrations have NOT run")
        print("\n🔧 SOLUTION: Need to run all migrations from V009 onwards")
        return False
    else:
        print("✅ All migrations appear to be complete")
        return True

def display_migration_sql():
    """Display the SQL we need to execute"""
    
    print("\n=== REQUIRED SQL TO FIX EMPTY BOOKS ===")
    print("""
The following SQL from V009 and V011 migrations needs to be executed:

-- From V009_20250125_basic_bookstore.sql --
INSERT INTO books (title, author, narrator, description, duration_minutes, price_usd, credit_price, category_id, is_featured, is_bestseller, publication_date, file_path, total_chapters, cover_image_url, sample_audio_url, sample_duration, average_rating, review_count, purchase_count)
VALUES 
('The Great Gatsby', 'F. Scott Fitzgerald', 'Professional Narrator', 'The Great Gatsby is a 1925 novel by American writer F. Scott Fitzgerald...', 540, 12.95, 1, (SELECT id FROM book_categories WHERE name = 'Fiction'), true, true, '1925-04-10', 'The Great Gatsby', 9, '/books/cover/The Great Gatsby/GatsbyCover.jpg', '/books/The Great Gatsby/Chapter 1.mp3', 180, 4.2, 1247, 3521),

('The Odyssey', 'Homer', 'LibriVox Readers', 'The Odyssey is one of the major ancient Greek epic poems attributed to Homer...', 1440, 16.95, 1, (SELECT id FROM book_categories WHERE name = 'Epic Poetry'), true, true, '800-01-01', 'The Odyssey', 24, '/books/cover/The Odyssey/OdysseyCover.jpg', '/books/The Odyssey/odyssey_01_homer_64kb.mp3', 180, 4.4, 892, 2341);

-- From V011_20250825_add_new_books.sql --
INSERT INTO books (title, author, narrator, description, duration_minutes, price_usd, credit_price, category_id, is_featured, is_new_release, publication_date, file_path, total_chapters, cover_image_url, sample_audio_url, sample_duration, average_rating, review_count, purchase_count)
VALUES 
('Alice''s Adventures in Wonderland', 'Lewis Carroll', 'LibriVox Reader', 'Alice''s Adventures in Wonderland is an 1865 English children''s novel...', 360, 9.95, 1, (SELECT id FROM book_categories WHERE name = 'Classic Literature'), true, true, '1865-11-26', 'Alice''s Adventures in Wonderland', 12, '/books/cover/Alice''s Adventures in Wonderland/aliceinWonder.jpg', '/books/Alice''s Adventures in Wonderland/alices_adventures_01_carroll_64kb.mp3', 180, 4.3, 2156, 4892),

('Moby Dick', 'Herman Melville', 'LibriVox Readers', 'Moby-Dick is an 1851 novel by Herman Melville...', 2580, 19.95, 1, (SELECT id FROM book_categories WHERE name = 'Classic Literature'), true, true, '1851-10-18', 'Moby Dick', 43, '/books/cover/Moby Dick/Moby_Dick_1002.jpg', '/books/Moby Dick/mobydick_000_melville_64kb.mp3', 180, 4.1, 1823, 3967),

('War and Peace', 'Leo Tolstoy', 'LibriVox Readers', 'War and Peace is a novel by the Russian author Leo Tolstoy...', 4080, 24.95, 2, (SELECT id FROM book_categories WHERE name = 'Classic Literature'), true, true, '1869-01-01', 'War and Peace', 68, '/books/cover/War and Peace/warandpeacecover.jpg', '/books/War and Peace/war_peace_v1_maude_translation_01_tolstoy_64kb.mp3', 180, 4.6, 3421, 7892);

🔧 TO EXECUTE: This SQL needs to be run against the production PostgreSQL database
    """)

if __name__ == "__main__":
    if check_database_status():
        display_migration_sql()
    
    print(f"\n💡 RECOMMENDATION:")
    print(f"   1. Connect to the Azure PostgreSQL database directly")
    print(f"   2. Execute the book INSERT statements from the migration files") 
    print(f"   3. Verify with: curl http://128.203.92.141:8000/bookstore/browse")