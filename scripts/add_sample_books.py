#!/usr/bin/env python3
"""
Script to add sample book data for testing the iOS app
"""

import requests
import json

# API Configuration
API_BASE_URL = "http://localhost:8000"
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzIiLCJlbWFpbCI6InRlc3RAZXhhbXBsZS5jb20iLCJyb2xlIjoidXNlciIsImV4cCI6MTc1NTE1MDYzNiwidHlwZSI6ImFjY2VzcyJ9.gZjomBLq1_u9wKSjtJGJRG18DZZyoCeCEfV-zCTbGSU"

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

def test_books_list():
    """Test the books list endpoint"""
    try:
        response = requests.get(f"{API_BASE_URL}/books/list", headers=headers)
        print(f"Books list status: {response.status_code}")
        print(f"Books list response: {response.text}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error testing books list: {e}")
        return False

def test_health():
    """Test basic API health"""
    try:
        response = requests.get(f"{API_BASE_URL}/health")
        print(f"Health status: {response.status_code}")
        print(f"Health response: {response.text}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error testing health: {e}")
        return False

if __name__ == "__main__":
    print("Testing BetterBooks API...")
    
    print("\n1. Testing basic health:")
    test_health()
    
    print("\n2. Testing books list:")
    test_books_list()
    
    print("\nAPI test complete!")