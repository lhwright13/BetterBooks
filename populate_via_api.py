#!/usr/bin/env python3
"""
Populate books database via API calls
Since we can't connect directly to PostgreSQL, we'll create books via API
"""

import json
import requests

API_BASE = "http://128.203.92.141:8000"

def populate_books():
    """Add books to the database via API calls"""
    
    # The 5 books from the migration files
    books_data = [
        {
            "title": "The Great Gatsby",
            "author": "F. Scott Fitzgerald", 
            "description": "The Great Gatsby is a 1925 novel by American writer F. Scott Fitzgerald. Set in the Jazz Age on prosperous Long Island and in New York City, the novel tells the story of Jay Gatsby and his pursuit of Daisy Buchanan.",
            "price_usd": 12.95,
            "credit_price": 1,
            "total_chapters": 9,
            "duration_minutes": 540,
            "publication_date": "1925-04-10"
        },
        {
            "title": "Alice's Adventures in Wonderland",
            "author": "Lewis Carroll",
            "description": "Alice's Adventures in Wonderland is an 1865 English children's novel by Lewis Carroll. It tells of a young girl named Alice who falls through a rabbit hole into a subterranean fantasy world populated by peculiar, anthropomorphic creatures.",
            "price_usd": 9.95,
            "credit_price": 1,
            "total_chapters": 12,
            "duration_minutes": 360,
            "publication_date": "1865-11-26"
        },
        {
            "title": "Moby Dick", 
            "author": "Herman Melville",
            "description": "Moby-Dick is an 1851 novel by Herman Melville. The book is the sailor Ishmael's narrative of the obsessive quest of Ahab, captain of the whaling ship Pequod, for revenge on Moby Dick, the giant white sperm whale.",
            "price_usd": 19.95,
            "credit_price": 1, 
            "total_chapters": 43,
            "duration_minutes": 2580,
            "publication_date": "1851-10-18"
        },
        {
            "title": "War and Peace",
            "author": "Leo Tolstoy",
            "description": "War and Peace is a novel by the Russian author Leo Tolstoy, published serially, then in its entirety in 1869. It is regarded as one of Tolstoy's finest literary achievements and remains an internationally praised classic of world literature.",
            "price_usd": 24.95,
            "credit_price": 2,
            "total_chapters": 68, 
            "duration_minutes": 4080,
            "publication_date": "1869-01-01"
        },
        {
            "title": "The Odyssey",
            "author": "Homer",
            "description": "The Odyssey is one of the major ancient Greek epic poems attributed to Homer. It is, in part, a sequel to The Iliad, the other work ascribed to Homer. The Odyssey follows the Greek hero Odysseus.",
            "price_usd": 16.95,
            "credit_price": 1,
            "total_chapters": 24,
            "duration_minutes": 1440,
            "publication_date": "800-01-01"
        }
    ]
    
    print(f"Attempting to populate {len(books_data)} books...")
    
    # First check if books already exist
    response = requests.get(f"{API_BASE}/bookstore/browse")
    if response.status_code == 200:
        existing_books = response.json()
        print(f"Currently {existing_books['total_count']} books in database")
        
        if existing_books['total_count'] >= 5:
            print("Books already populated!")
            return True
    
    # Since there's no direct "create book" endpoint, we need to use a different approach
    # Let's check what endpoints are available
    try:
        # This would need an admin endpoint to create books
        # For now, we'll just report what we would do
        print("\nWould populate these books:")
        for book in books_data:
            print(f"- {book['title']} by {book['author']} ({book['total_chapters']} chapters)")
        
        print(f"\nUnfortunately, there's no public API endpoint to create books.")
        print(f"The books need to be created via database migrations or admin tools.")
        print(f"Current API endpoints available:")
        
        # Check swagger docs
        response = requests.get(f"{API_BASE}/openapi.json")
        if response.status_code == 200:
            openapi_data = response.json()
            endpoints = []
            for path, methods in openapi_data['paths'].items():
                for method in methods.keys():
                    if 'book' in path.lower() and method.upper() == 'POST':
                        endpoints.append(f"{method.upper()} {path}")
            
            if endpoints:
                print("Book-related POST endpoints found:")
                for endpoint in endpoints:
                    print(f"  {endpoint}")
            else:
                print("No book creation endpoints found.")
        
        return False
        
    except Exception as e:
        print(f"Error trying to populate books: {e}")
        return False

if __name__ == "__main__":
    populate_books()