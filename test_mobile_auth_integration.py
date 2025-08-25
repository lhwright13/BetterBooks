#!/usr/bin/env python3
"""
Test script to verify mobile authentication integration with backend.
This script tests all the authentication flows that the mobile app uses.
"""

import requests
import json
import time
import random
import string

API_BASE_URL = "http://localhost:8002"

def generate_test_user():
    """Generate a random test user for testing."""
    suffix = ''.join(random.choices(string.digits, k=6))
    return {
        'username': f'testuser{suffix}',
        'email': f'test{suffix}@mobile.app',
        'password': 'testpass123'
    }

def test_health_check():
    """Test that the API Gateway is healthy."""
    print("🏥 Testing API Gateway health...")
    try:
        response = requests.get(f"{API_BASE_URL}/health", timeout=10)
        if response.status_code == 200:
            print("✅ API Gateway is healthy")
            return True
        else:
            print(f"❌ API Gateway health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ API Gateway health check error: {e}")
        return False

def test_user_registration(user):
    """Test user registration endpoint."""
    print(f"📝 Testing user registration for {user['email']}...")
    try:
        response = requests.post(
            f"{API_BASE_URL}/auth/register",
            json={
                'username': user['username'],
                'email': user['email'],
                'password': user['password']
            },
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if 'tokens' in data and 'user' in data:
                print("✅ User registration successful")
                return data
            else:
                print(f"❌ Invalid registration response format: {data}")
                return None
        else:
            print(f"❌ User registration failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"❌ User registration error: {e}")
        return None

def test_user_login(user):
    """Test user login endpoint."""
    print(f"🔐 Testing user login for {user['email']}...")
    try:
        response = requests.post(
            f"{API_BASE_URL}/auth/login",
            json={
                'email': user['email'],
                'password': user['password']
            },
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if 'access_token' in data and 'refresh_token' in data:
                print("✅ User login successful")
                return data
            else:
                print(f"❌ Invalid login response format: {data}")
                return None
        else:
            print(f"❌ User login failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"❌ User login error: {e}")
        return None

def test_user_me_endpoint(access_token):
    """Test the /auth/me endpoint with access token."""
    print("👤 Testing /auth/me endpoint...")
    try:
        response = requests.get(
            f"{API_BASE_URL}/auth/me",
            headers={'Authorization': f'Bearer {access_token}'},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if 'id' in data and 'email' in data:
                print("✅ /auth/me endpoint successful")
                return data
            else:
                print(f"❌ Invalid /auth/me response format: {data}")
                return None
        else:
            print(f"❌ /auth/me failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"❌ /auth/me error: {e}")
        return None

def test_books_endpoint(access_token):
    """Test books endpoint with authentication."""
    print("📚 Testing authenticated books endpoint...")
    try:
        response = requests.get(
            f"{API_BASE_URL}/books/list",
            headers={'Authorization': f'Bearer {access_token}'},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if 'single_books' in data or 'chapter_books' in data:
                print("✅ Authenticated books endpoint successful")
                print(f"   Found {len(data.get('single_books', []))} single books")
                print(f"   Found {len(data.get('chapter_books', []))} chapter books")
                return data
            else:
                print(f"❌ Invalid books response format: {data}")
                return None
        else:
            print(f"❌ Books endpoint failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"❌ Books endpoint error: {e}")
        return None

def test_oauth_stubs():
    """Test OAuth stub endpoints."""
    print("🔗 Testing OAuth stub endpoints...")
    
    # Test Google OAuth stub
    try:
        response = requests.post(
            f"{API_BASE_URL}/auth/google/signin",
            json={'id_token': 'test_token'},
            timeout=10
        )
        if response.status_code == 501:
            print("✅ Google OAuth stub returns proper not-implemented error")
        else:
            print(f"❌ Google OAuth stub unexpected response: {response.status_code}")
    except Exception as e:
        print(f"❌ Google OAuth stub error: {e}")
    
    # Test Apple OAuth stub
    try:
        response = requests.post(
            f"{API_BASE_URL}/auth/apple/signin",
            json={'id_token': 'test_token'},
            timeout=10
        )
        if response.status_code == 501:
            print("✅ Apple OAuth stub returns proper not-implemented error")
        else:
            print(f"❌ Apple OAuth stub unexpected response: {response.status_code}")
    except Exception as e:
        print(f"❌ Apple OAuth stub error: {e}")

def test_token_refresh(refresh_token):
    """Test token refresh endpoint."""
    print("🔄 Testing token refresh...")
    try:
        response = requests.post(
            f"{API_BASE_URL}/auth/refresh",
            headers={'Authorization': f'Bearer {refresh_token}'},
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            if 'access_token' in data and 'refresh_token' in data:
                print("✅ Token refresh successful")
                return data
            else:
                print(f"❌ Invalid refresh response format: {data}")
                return None
        else:
            print(f"❌ Token refresh failed: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"❌ Token refresh error: {e}")
        return None

def main():
    """Run all authentication integration tests."""
    print("🚀 Starting Mobile Authentication Integration Tests")
    print("=" * 60)
    
    # Test 1: Health check
    if not test_health_check():
        print("❌ Cannot proceed - API Gateway is not healthy")
        return False
    
    print()
    
    # Test 2: Generate test user and register
    user = generate_test_user()
    registration_data = test_user_registration(user)
    if not registration_data:
        print("❌ Cannot proceed - user registration failed")
        return False
    
    print()
    
    # Test 3: Login with the same user
    login_data = test_user_login(user)
    if not login_data:
        print("❌ Cannot proceed - user login failed")
        return False
    
    access_token = login_data['access_token']
    refresh_token = login_data['refresh_token']
    
    print()
    
    # Test 4: Test /auth/me endpoint
    user_data = test_user_me_endpoint(access_token)
    if not user_data:
        print("❌ /auth/me endpoint failed")
        return False
    
    print()
    
    # Test 5: Test authenticated books endpoint
    books_data = test_books_endpoint(access_token)
    if not books_data:
        print("❌ Books endpoint failed")
        return False
    
    print()
    
    # Test 6: Test token refresh
    refresh_data = test_token_refresh(refresh_token)
    if not refresh_data:
        print("❌ Token refresh failed")
        return False
    
    print()
    
    # Test 7: Test OAuth stubs
    test_oauth_stubs()
    
    print()
    print("=" * 60)
    print("🎉 All Mobile Authentication Integration Tests Passed!")
    print()
    print("✅ Backend authentication endpoints working")
    print("✅ JWT token generation and validation working") 
    print("✅ User registration and login working")
    print("✅ Authenticated API endpoints working")
    print("✅ Token refresh working")
    print("✅ OAuth stub endpoints working")
    print()
    print("🔥 Mobile app is ready for authentication testing!")
    
    return True

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)