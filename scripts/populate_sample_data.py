#!/usr/bin/env python3
"""
Sample Data Population Script for BetterBooks
Creates test users, purchases, and library entries for development
"""

import os
import sys
import uuid
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta
import logging

# Add the project root to the path so we can import core modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

logger = logging.getLogger(__name__)

def get_db_connection():
    """Get database connection using environment variables"""
    # Try to get database URL from environment first
    db_url = os.getenv('DATABASE_URL')
    if not db_url:
        # Fallback to local Docker connection for development
        db_url = "postgresql://betterbooks:testpassword123@localhost:5432/betterbooks"
    
    print(f"Connecting to database: {db_url.split('@')[1] if '@' in db_url else 'local'}")
    return psycopg2.connect(db_url)

def create_test_users():
    """Create test users with various credit balances"""
    test_users = [
        {
            'id': '550e8400-e29b-41d4-a716-446655440000',  # Demo user ID used in API
            'email': 'demo@betterbooks.com',
            'full_name': 'Demo User',
            'total_credits': 5,
            'used_credits': 0
        },
        {
            'id': str(uuid.uuid4()),
            'email': 'bookworm@example.com', 
            'full_name': 'Avid Reader',
            'total_credits': 10,
            'used_credits': 3
        },
        {
            'id': str(uuid.uuid4()),
            'email': 'newuser@example.com',
            'full_name': 'New User',
            'total_credits': 2,
            'used_credits': 0
        },
        {
            'id': str(uuid.uuid4()),
            'email': 'premium@example.com',
            'full_name': 'Premium Member',
            'total_credits': 25,
            'used_credits': 8
        }
    ]
    
    created_users = []
    
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                for user_data in test_users:
                    # Create user if not exists
                    cursor.execute("""
                        INSERT INTO users (id, email, full_name, created_at, updated_at)
                        VALUES (%s, %s, %s, NOW(), NOW())
                        ON CONFLICT (email) DO UPDATE SET 
                            full_name = EXCLUDED.full_name,
                            updated_at = NOW()
                        RETURNING id, email, full_name
                    """, (user_data['id'], user_data['email'], user_data['full_name']))
                    
                    user_result = cursor.fetchone()
                    if user_result:
                        created_users.append(dict(user_result))
                        
                        # Set up user credits
                        cursor.execute("""
                            INSERT INTO user_credits (user_id, total_credits, used_credits, last_updated)
                            VALUES (%s, %s, %s, NOW())
                            ON CONFLICT (user_id) DO UPDATE SET
                                total_credits = EXCLUDED.total_credits,
                                used_credits = EXCLUDED.used_credits,
                                last_updated = NOW()
                        """, (user_data['id'], user_data['total_credits'], user_data['used_credits']))
                
                conn.commit()
                print(f"Created/updated {len(created_users)} test users")
                for user in created_users:
                    print(f"  - {user['email']} ({user['full_name']})")
                
                return created_users
                
    except Exception as e:
        print(f"Error creating test users: {e}")
        return []

def create_sample_purchases(users):
    """Create sample purchases for test users"""
    if not users:
        print("No users provided for sample purchases")
        return
        
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Get available books
                cursor.execute("SELECT id, title, price_usd, credit_price FROM books LIMIT 5")
                books = cursor.fetchall()
                
                if not books:
                    print("No books found in database - run migrations first")
                    return
                
                purchase_count = 0
                
                # Demo user gets The Great Gatsby and Alice in Wonderland
                demo_user = next((u for u in users if u['email'] == 'demo@betterbooks.com'), None)
                if demo_user:
                    gatsby_book = next((b for b in books if 'Gatsby' in b['title']), None)
                    alice_book = next((b for b in books if 'Alice' in b['title']), None)
                    
                    for book in [gatsby_book, alice_book]:
                        if book:
                            cursor.execute("""
                                INSERT INTO user_purchases (user_id, book_id, purchase_type, credits_used, price_paid, purchase_date)
                                VALUES (%s, %s, 'credit', %s, %s, %s)
                                ON CONFLICT (user_id, book_id) DO NOTHING
                            """, (demo_user['id'], book['id'], book['credit_price'], book['price_usd'], 
                                 datetime.now() - timedelta(days=7)))
                            
                            # Add to user library
                            cursor.execute("""
                                INSERT INTO user_library (user_id, book_id, acquired_at, access_type, last_position_seconds)
                                VALUES (%s, %s, %s, 'purchase', %s)
                                ON CONFLICT (user_id, book_id) DO UPDATE SET
                                    last_position_seconds = EXCLUDED.last_position_seconds
                            """, (demo_user['id'], str(book['id']), 
                                 datetime.now() - timedelta(days=7), 
                                 3600))  # 1 hour progress
                            
                            purchase_count += 1
                
                # Bookworm user gets multiple books
                bookworm = next((u for u in users if u['email'] == 'bookworm@example.com'), None)
                if bookworm and len(books) >= 3:
                    for book in books[:3]:  # First 3 books
                        cursor.execute("""
                            INSERT INTO user_purchases (user_id, book_id, purchase_type, credits_used, price_paid, purchase_date)
                            VALUES (%s, %s, 'credit', %s, %s, %s)
                            ON CONFLICT (user_id, book_id) DO NOTHING
                        """, (bookworm['id'], book['id'], book['credit_price'], book['price_usd'], 
                             datetime.now() - timedelta(days=14)))
                        
                        # Add to user library with varying progress
                        progress = [0, 7200, 14400][books.index(book) % 3]  # 0, 2 hours, 4 hours
                        cursor.execute("""
                            INSERT INTO user_library (user_id, book_id, acquired_at, access_type, last_position_seconds)
                            VALUES (%s, %s, %s, 'purchase', %s)
                            ON CONFLICT (user_id, book_id) DO UPDATE SET
                                last_position_seconds = EXCLUDED.last_position_seconds
                        """, (bookworm['id'], str(book['id']), 
                             datetime.now() - timedelta(days=14),
                             progress))
                        
                        purchase_count += 1
                
                # Premium user gets expensive books
                premium = next((u for u in users if u['email'] == 'premium@example.com'), None)
                if premium:
                    # Get War and Peace (2 credits) and other books
                    war_peace = next((b for b in books if 'War and Peace' in b['title']), None)
                    moby_dick = next((b for b in books if 'Moby' in b['title']), None)
                    
                    for book in [war_peace, moby_dick]:
                        if book:
                            cursor.execute("""
                                INSERT INTO user_purchases (user_id, book_id, purchase_type, credits_used, price_paid, purchase_date)
                                VALUES (%s, %s, 'credit', %s, %s, %s)
                                ON CONFLICT (user_id, book_id) DO NOTHING
                            """, (premium['id'], book['id'], book['credit_price'], book['price_usd'], 
                                 datetime.now() - timedelta(days=30)))
                            
                            # Add to user library
                            cursor.execute("""
                                INSERT INTO user_library (user_id, book_id, acquired_at, access_type, last_position_seconds)
                                VALUES (%s, %s, %s, 'purchase', %s)
                                ON CONFLICT (user_id, book_id) DO UPDATE SET
                                    last_position_seconds = EXCLUDED.last_position_seconds
                            """, (premium['id'], str(book['id']), 
                                 datetime.now() - timedelta(days=30), 
                                 600))  # 10 minutes progress
                            
                            purchase_count += 1
                
                conn.commit()
                print(f"Created {purchase_count} sample purchases and library entries")
                
    except Exception as e:
        print(f"Error creating sample purchases: {e}")

def print_summary():
    """Print summary of data in database"""
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Books count
                cursor.execute("SELECT COUNT(*) as count FROM books")
                books_count = cursor.fetchone()['count']
                
                # Users count 
                cursor.execute("SELECT COUNT(*) as count FROM users")
                users_count = cursor.fetchone()['count']
                
                # Purchases count
                cursor.execute("SELECT COUNT(*) as count FROM user_purchases")
                purchases_count = cursor.fetchone()['count']
                
                # Library count
                cursor.execute("SELECT COUNT(*) as count FROM user_library")
                library_count = cursor.fetchone()['count']
                
                # Chapters count
                cursor.execute("SELECT COUNT(*) as count FROM book_chapters")
                chapters_count = cursor.fetchone()['count']
                
                print("\n" + "="*50)
                print("DATABASE SUMMARY")
                print("="*50)
                print(f"Books: {books_count}")
                print(f"Chapters: {chapters_count}")
                print(f"Users: {users_count}")
                print(f"Purchases: {purchases_count}")
                print(f"Library entries: {library_count}")
                print("="*50)
                
    except Exception as e:
        print(f"Error getting summary: {e}")

def main():
    """Main function to populate sample data"""
    print("Populating sample data for BetterBooks...")
    
    # Create test users
    users = create_test_users()
    
    # Create sample purchases
    create_sample_purchases(users)
    
    # Print summary
    print_summary()
    
    print("\nSample data population complete!")

if __name__ == "__main__":
    main()