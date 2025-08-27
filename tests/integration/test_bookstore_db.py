#!/usr/bin/env python3
"""
Simple test script to verify the bookstore database is working
"""

import asyncio
import os
import sys
sys.path.append('.')

import asyncpg
from core.bookstore.bookstore_service import BookstoreService
from core.bookstore.models import BookSearchFilter
from core.database.database_manager import DatabaseManager

async def test_bookstore():
    # Database connection
    DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://betterbooks:betterbooks@localhost:5432/betterbooks')
    
    try:
        db_manager = DatabaseManager(DATABASE_URL)
        bookstore_service = BookstoreService(db_manager)
        
        print("🔍 Testing Bookstore Database Connection...")
        
        # Test 1: Browse all books
        print("\n📚 Browsing all books:")
        books = await bookstore_service.browse_books(limit=10, offset=0)
        print(f"Found {len(books)} books:")
        for book in books:
            print(f"  - {book.title} by {book.author} (${book.price_usd})")
        
        # Test 2: Get categories
        print("\n🏷️  Getting categories:")
        categories = await bookstore_service.get_categories()
        print(f"Found {len(categories)} categories:")
        for category in categories:
            print(f"  - {category.name}: {category.description}")
        
        # Test 3: Search books
        print("\n🔍 Searching for 'Gatsby':")
        search_filter = BookSearchFilter(query="Gatsby")
        search_results = await bookstore_service.search_books(search_filter)
        print(f"Found {len(search_results)} books:")
        for book in search_results:
            print(f"  - {book.title} by {book.author}")
        
        # Test 4: Get featured books
        print("\n⭐ Getting featured books:")
        featured = await bookstore_service.browse_books(featured_only=True)
        print(f"Found {len(featured)} featured books:")
        for book in featured:
            print(f"  - {book.title} by {book.author} ⭐")
        
        print("\n✅ All tests passed! Bookstore database is working correctly.")
        
    except Exception as e:
        print(f"❌ Error testing bookstore: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    return True

if __name__ == "__main__":
    asyncio.run(test_bookstore())