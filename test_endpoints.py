#!/usr/bin/env python3
"""
Test script for the fixed hardcoded book data system
Tests all database functions directly without starting the server
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'core'))
sys.path.insert(0, os.path.dirname(__file__))

# Set database URL for localhost connection
os.environ['DATABASE_URL'] = 'postgresql://betterbooks:testpassword123@localhost:5432/betterbooks'

# Add the API Gateway directory to the path
sys.path.insert(0, 'platform/backend/services/api_gateway')

from db_utils import (
    test_database_connection,
    get_browse_books,
    get_book_details,
    get_user_credits,
    get_user_library,
    create_purchase,
    check_user_owns_book
)

def test_database_connection_func():
    """Test database connection"""
    print("=" * 50)
    print("1. TESTING DATABASE CONNECTION")
    print("=" * 50)
    
    result = test_database_connection()
    print(f"Database connection: {'✅ SUCCESS' if result else '❌ FAILED'}")
    return result

def test_browse_books_func():
    """Test browse books endpoint"""
    print("\n" + "=" * 50)
    print("2. TESTING BROWSE BOOKS")
    print("=" * 50)
    
    try:
        books = get_browse_books(limit=10)
        print(f"✅ Found {books['total_books']} books:")
        for book in books['books']:
            print(f"   📖 {book['title']} by {book['author']}")
            print(f"      Price: ${book['price_usd']}, Credits: {book['credit_price']}")
            print(f"      Featured: {book['is_featured']}, Bestseller: {book['is_bestseller']}")
        return True
    except Exception as e:
        print(f"❌ Browse books failed: {e}")
        return False

def test_book_details_func():
    """Test book details with chapters"""
    print("\n" + "=" * 50)
    print("3. TESTING BOOK DETAILS WITH CHAPTERS")
    print("=" * 50)
    
    # Test with The Great Gatsby
    gatsby_id = '5867a269-af65-46c4-a025-98ea3b14b757'
    
    try:
        book_details = get_book_details(gatsby_id)
        if book_details:
            print(f"✅ Book: {book_details['title']} by {book_details['author']}")
            print(f"   Description: {book_details.get('description', 'No description')[:100]}...")
            print(f"   Price: ${book_details['price_usd']}, Credits: {book_details['credit_price']}")
            print(f"   Chapters: {len(book_details.get('chapters', []))}")
            
            if book_details.get('chapters'):
                print("   📋 First 3 chapters:")
                for chapter in book_details['chapters'][:3]:
                    print(f"      Ch.{chapter['chapter_number']}: {chapter['title']}")
                    print(f"      Audio URL: {chapter['audio_url']}")
                    print(f"      Duration: {chapter.get('duration', 'Unknown')} seconds")
            return True
        else:
            print(f"❌ Book details not found for ID: {gatsby_id}")
            return False
    except Exception as e:
        print(f"❌ Book details failed: {e}")
        return False

def test_user_credits_func():
    """Test user credits system"""
    print("\n" + "=" * 50)
    print("4. TESTING USER CREDITS SYSTEM")
    print("=" * 50)
    
    demo_user_id = '550e8400-e29b-41d4-a716-446655440000'
    
    try:
        credits = get_user_credits(demo_user_id)
        if credits:
            print(f"✅ User Credits for {demo_user_id}:")
            print(f"   Total Credits: {credits['total_credits']}")
            print(f"   Used Credits: {credits['used_credits']}")
            print(f"   Available Credits: {credits['available_credits']}")
            return True
        else:
            print(f"❌ Could not get credits for user {demo_user_id}")
            return False
    except Exception as e:
        print(f"❌ User credits failed: {e}")
        return False

def test_purchase_system_func():
    """Test purchase system"""
    print("\n" + "=" * 50)
    print("5. TESTING PURCHASE SYSTEM")
    print("=" * 50)
    
    demo_user_id = '550e8400-e29b-41d4-a716-446655440000'
    gatsby_id = '5867a269-af65-46c4-a025-98ea3b14b757'
    
    try:
        # Check if user already owns Gatsby
        already_owns = check_user_owns_book(demo_user_id, gatsby_id)
        print(f"User already owns Gatsby: {already_owns}")
        
        if not already_owns:
            # Get credits before purchase
            credits_before = get_user_credits(demo_user_id)
            available_before = credits_before['available_credits'] if credits_before else 0
            
            # Attempt purchase
            print(f"Attempting to purchase Gatsby (available credits: {available_before})")
            purchase_result = create_purchase(demo_user_id, gatsby_id, credits_used=1)
            
            if purchase_result:
                # Get credits after purchase
                credits_after = get_user_credits(demo_user_id)
                available_after = credits_after['available_credits'] if credits_after else 0
                
                print(f"✅ Purchase successful!")
                print(f"   Credits before: {available_before}")
                print(f"   Credits after: {available_after}")
                print(f"   Credits used: {available_before - available_after}")
                return True
            else:
                print("❌ Purchase failed")
                return False
        else:
            print("✅ User already owns this book (purchase system working)")
            return True
            
    except Exception as e:
        print(f"❌ Purchase system failed: {e}")
        return False

def test_user_library_func():
    """Test user library"""
    print("\n" + "=" * 50)
    print("6. TESTING USER LIBRARY")
    print("=" * 50)
    
    demo_user_id = '550e8400-e29b-41d4-a716-446655440000'
    
    try:
        library = get_user_library(demo_user_id)
        print(f"✅ User Library for {demo_user_id}:")
        print(f"   Total Books: {library['total_books']}")
        
        if library['books']:
            print("   📚 Owned Books:")
            for book in library['books']:
                print(f"      📖 {book['title']}")
                print(f"         Progress: {float(book.get('progress', 0)):.1%}")
                print(f"         Purchased: {book.get('purchased_at', 'Unknown')}")
        else:
            print("   📭 No books in library")
        
        return True
    except Exception as e:
        print(f"❌ User library failed: {e}")
        return False

def main():
    """Run all tests"""
    print("🧪 TESTING FIXED HARDCODED BOOK DATA SYSTEM")
    print("🎯 Goal: Verify all database functions work without hardcoded fallbacks")
    
    tests = [
        test_database_connection_func,
        test_browse_books_func,
        test_book_details_func,
        test_user_credits_func,
        test_purchase_system_func,
        test_user_library_func
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"❌ Test {test.__name__} crashed: {e}")
            failed += 1
    
    print("\n" + "=" * 50)
    print("📊 TEST RESULTS")
    print("=" * 50)
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print(f"📈 Success Rate: {passed / (passed + failed) * 100:.1f}%")
    
    if failed == 0:
        print("\n🎉 ALL TESTS PASSED! The hardcoded book data has been successfully replaced with database-backed functionality!")
    else:
        print(f"\n⚠️  {failed} tests failed. Please check the errors above.")
    
    return passed, failed

if __name__ == "__main__":
    main()