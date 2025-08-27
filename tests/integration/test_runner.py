#!/usr/bin/env python3
"""
Simple test runner to validate core EchoWright functionality
"""

import requests
import json
import sys
import time

def test_service_health():
    """Test that all core services are healthy"""
    services = [
        ("API Gateway", "http://localhost:8000/health"),
        ("Context Service", "http://localhost:8001/health"),
        ("LLM Gateway", "http://localhost:8002/health"),
        ("TTS Service", "http://localhost:8004/health"),
        ("Transcription Service", "http://localhost:8003/health"),
    ]
    
    print("🧪 Testing Service Health Endpoints...")
    all_healthy = True
    
    for service_name, url in services:
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                status = data.get("status", "unknown")
                print(f"  ✅ {service_name}: {status}")
            else:
                print(f"  ❌ {service_name}: HTTP {response.status_code}")
                all_healthy = False
        except Exception as e:
            print(f"  ❌ {service_name}: {str(e)}")
            all_healthy = False
    
    return all_healthy

def test_database_endpoints():
    """Test database-backed endpoints"""
    print("\n🧪 Testing Database Endpoints...")
    all_working = True
    
    endpoints = [
        ("User Credits", "http://localhost:8000/bookstore/user/credits"),
        ("User Library", "http://localhost:8000/bookstore/user/library"),
        ("Browse Books", "http://localhost:8000/bookstore/browse"),
        ("Database Test", "http://localhost:8000/database/test"),
    ]
    
    for endpoint_name, url in endpoints:
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"  ✅ {endpoint_name}: Working")
                if endpoint_name == "User Credits":
                    credits = data.get("available_credits", 0)
                    print(f"    Available credits: {credits}")
                elif endpoint_name == "Browse Books":
                    book_count = len(data.get("books", []))
                    print(f"    Books available: {book_count}")
            else:
                print(f"  ❌ {endpoint_name}: HTTP {response.status_code}")
                all_working = False
        except Exception as e:
            print(f"  ❌ {endpoint_name}: {str(e)}")
            all_working = False
    
    return all_working

def test_azure_storage_integration():
    """Test Azure Storage integration"""
    print("\n🧪 Testing Azure Storage Integration...")
    
    # Test file serving endpoint (should fall back to local storage)
    try:
        url = "http://localhost:8000/books/The%20Great%20Gatsby/Chapter%201.mp3"
        response = requests.get(url, timeout=5, stream=True)
        if response.status_code == 200:
            print("  ✅ Audio file serving: Working")
            print(f"    Content-Type: {response.headers.get('content-type', 'unknown')}")
            return True
        else:
            print(f"  ❌ Audio file serving: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"  ❌ Audio file serving: {str(e)}")
        return False

def main():
    """Run all tests"""
    print("🚀 EchoWright MVP Test Suite")
    print("=" * 50)
    
    start_time = time.time()
    tests_passed = 0
    total_tests = 3
    
    # Run tests
    if test_service_health():
        tests_passed += 1
    
    if test_database_endpoints():
        tests_passed += 1
        
    if test_azure_storage_integration():
        tests_passed += 1
    
    # Results
    end_time = time.time()
    duration = end_time - start_time
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {tests_passed}/{total_tests} passed")
    print(f"⏱️  Duration: {duration:.2f} seconds")
    
    if tests_passed == total_tests:
        print("🎉 All tests passed! MVP is functional.")
        return 0
    else:
        print("⚠️  Some tests failed. Check logs above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())