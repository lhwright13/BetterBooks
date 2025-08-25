#!/usr/bin/env python3
"""
Script to test API endpoints for the EchoWright platform
"""

import requests
import json
import os
import sys

# API Configuration
API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000")
TOKEN = os.getenv("API_TEST_TOKEN")

if not TOKEN:
    print("❌ API_TEST_TOKEN environment variable not set")
    print("💡 Set a test token: export API_TEST_TOKEN=your-token-here")
    print("💡 Or run without authentication for public endpoints")
    TOKEN = None

headers = {
    "Content-Type": "application/json"
}

if TOKEN:
    headers["Authorization"] = f"Bearer {TOKEN}"

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
    print("Testing EchoWright API...")
    print(f"API Base URL: {API_BASE_URL}")
    print(f"Using authentication: {'Yes' if TOKEN else 'No'}")
    
    print("\n1. Testing basic health:")
    health_ok = test_health()
    
    print("\n2. Testing books list:")
    books_ok = test_books_list()
    
    print("\n" + "="*50)
    if health_ok and books_ok:
        print("✅ All API tests passed!")
    else:
        print("❌ Some API tests failed")
        sys.exit(1)
    
    print("\nAPI test complete!")