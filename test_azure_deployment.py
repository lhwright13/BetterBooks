#!/usr/bin/env python3
"""
Azure Deployment Test Script
Tests all API Gateway fixes on the deployed Azure backend
"""

import requests
import json
import time
import sys
from typing import Dict, Any, Optional
from datetime import datetime

# Azure deployment configuration
AZURE_BASE_URL = "http://128.203.92.141:8000"  # Current Azure external IP
TEST_TIMEOUT = 30  # seconds

class AzureDeploymentTester:
    def __init__(self):
        self.base_url = AZURE_BASE_URL
        self.session = requests.Session()
        self.session.timeout = TEST_TIMEOUT
        self.test_results = []
        self.errors = []
        
    def log_test(self, test_name: str, success: bool, details: str = "", response_time: float = 0):
        """Log test result"""
        status = "✅ PASS" if success else "❌ FAIL"
        result = {
            'test': test_name,
            'status': status,
            'success': success,
            'details': details,
            'response_time_ms': round(response_time * 1000, 2),
            'timestamp': datetime.now().isoformat()
        }
        self.test_results.append(result)
        
        # Print result immediately
        time_str = f"({result['response_time_ms']}ms)" if response_time > 0 else ""
        print(f"{status} {test_name} {time_str}")
        if details:
            print(f"    {details}")
        if not success:
            self.errors.append(f"{test_name}: {details}")
    
    def test_basic_connectivity(self) -> bool:
        """Test basic connectivity to Azure deployment"""
        print("\n🔍 Testing Basic Connectivity...")
        
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/health")
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                self.log_test(
                    "Health Check", 
                    True, 
                    f"Status: {data.get('status', 'unknown')}, Service: {data.get('service', 'unknown')}", 
                    response_time
                )
                return True
            else:
                self.log_test("Health Check", False, f"HTTP {response.status_code}: {response.text}", response_time)
                return False
                
        except Exception as e:
            self.log_test("Health Check", False, f"Connection error: {str(e)}")
            return False
    
    def test_root_endpoint(self) -> bool:
        """Test root endpoint"""
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/")
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                self.log_test("Root Endpoint", True, f"Message: {data.get('message', 'N/A')}", response_time)
                return True
            else:
                self.log_test("Root Endpoint", False, f"HTTP {response.status_code}", response_time)
                return False
        except Exception as e:
            self.log_test("Root Endpoint", False, f"Error: {str(e)}")
            return False
    
    def test_database_connection(self) -> bool:
        """Test database connectivity endpoint"""
        print("\n🔍 Testing Database Connection...")
        
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/database/test")
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                db_connected = data.get('database_connected', False)
                message = data.get('message', 'Unknown')
                
                self.log_test(
                    "Database Connection", 
                    db_connected, 
                    f"Connected: {db_connected}, Message: {message}", 
                    response_time
                )
                return db_connected
            else:
                self.log_test("Database Connection", False, f"HTTP {response.status_code}", response_time)
                return False
                
        except Exception as e:
            self.log_test("Database Connection", False, f"Error: {str(e)}")
            return False
    
    def test_user_credits(self) -> bool:
        """Test user credits endpoint (should work with demo user)"""
        print("\n🔍 Testing User Endpoints...")
        
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/bookstore/user/credits")
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                credits = data.get('available_credits', 0)
                total = data.get('total_credits', 0)
                
                self.log_test(
                    "User Credits", 
                    True, 
                    f"Available: {credits}/{total} credits", 
                    response_time
                )
                return True
            else:
                self.log_test("User Credits", False, f"HTTP {response.status_code}: {response.text}", response_time)
                return False
                
        except Exception as e:
            self.log_test("User Credits", False, f"Error: {str(e)}")
            return False
    
    def test_user_library(self) -> bool:
        """Test user library endpoint"""
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/bookstore/user/library")
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                book_count = len(data.get('books', []))
                total = data.get('total_books', 0)
                
                self.log_test(
                    "User Library", 
                    True, 
                    f"{book_count} books in library (total: {total})", 
                    response_time
                )
                return True
            else:
                self.log_test("User Library", False, f"HTTP {response.status_code}: {response.text}", response_time)
                return False
                
        except Exception as e:
            self.log_test("User Library", False, f"Error: {str(e)}")
            return False
    
    def test_book_browsing(self) -> bool:
        """Test book browsing endpoint"""
        print("\n🔍 Testing Book Endpoints...")
        
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/bookstore/browse")
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                book_count = len(data.get('books', []))
                total = data.get('total_count', 0)
                
                self.log_test(
                    "Book Browsing", 
                    True, 
                    f"{book_count} books available (total: {total})", 
                    response_time
                )
                return book_count > 0
            else:
                self.log_test("Book Browsing", False, f"HTTP {response.status_code}: {response.text}", response_time)
                return False
                
        except Exception as e:
            self.log_test("Book Browsing", False, f"Error: {str(e)}")
            return False
    
    def test_book_categories(self) -> bool:
        """Test book categories endpoint"""
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/bookstore/categories")
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                category_count = len(data.get('categories', []))
                
                self.log_test(
                    "Book Categories", 
                    True, 
                    f"{category_count} categories available", 
                    response_time
                )
                return True
            else:
                self.log_test("Book Categories", False, f"HTTP {response.status_code}: {response.text}", response_time)
                return False
                
        except Exception as e:
            self.log_test("Book Categories", False, f"Error: {str(e)}")
            return False
    
    def test_ai_configs(self) -> bool:
        """Test AI persona configurations endpoint"""
        print("\n🔍 Testing AI Integration...")
        
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/configs")
            response_time = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                config_count = len(data.get('configs', []))
                
                self.log_test(
                    "AI Configurations", 
                    True, 
                    f"{config_count} AI personas available", 
                    response_time
                )
                return True
            else:
                self.log_test("AI Configurations", False, f"HTTP {response.status_code}: {response.text}", response_time)
                return False
                
        except Exception as e:
            self.log_test("AI Configurations", False, f"Error: {str(e)}")
            return False
    
    def test_error_handling(self) -> bool:
        """Test error handling for non-existent endpoints"""
        print("\n🔍 Testing Error Handling...")
        
        try:
            start_time = time.time()
            response = self.session.get(f"{self.base_url}/nonexistent-endpoint")
            response_time = time.time() - start_time
            
            # Should return 404
            if response.status_code == 404:
                self.log_test(
                    "Error Handling", 
                    True, 
                    f"Correctly returns 404 for invalid endpoints", 
                    response_time
                )
                return True
            else:
                self.log_test("Error Handling", False, f"Expected 404, got {response.status_code}", response_time)
                return False
                
        except Exception as e:
            self.log_test("Error Handling", False, f"Error: {str(e)}")
            return False
    
    def run_all_tests(self) -> bool:
        """Run all tests and return overall success"""
        print(f"🚀 Starting Azure Deployment Tests")
        print(f"Target: {self.base_url}")
        print(f"Timeout: {TEST_TIMEOUT}s")
        print("=" * 60)
        
        # Run all tests
        tests = [
            self.test_basic_connectivity,
            self.test_root_endpoint,
            self.test_database_connection,
            self.test_user_credits,
            self.test_user_library,
            self.test_book_browsing,
            self.test_book_categories,
            self.test_ai_configs,
            self.test_error_handling,
        ]
        
        passed = 0
        total = len(tests)
        
        for test_func in tests:
            try:
                if test_func():
                    passed += 1
            except Exception as e:
                print(f"❌ CRITICAL ERROR in {test_func.__name__}: {e}")
                self.errors.append(f"{test_func.__name__}: CRITICAL ERROR - {e}")
        
        # Print summary
        print("\n" + "=" * 60)
        print(f"📊 TEST SUMMARY")
        print(f"Passed: {passed}/{total} tests")
        print(f"Success Rate: {(passed/total)*100:.1f}%")
        
        if self.errors:
            print(f"\n❌ ERRORS ({len(self.errors)}):")
            for error in self.errors:
                print(f"  • {error}")
        
        if passed == total:
            print("\n🎉 ALL TESTS PASSED - Azure deployment is fully functional!")
        elif passed >= total * 0.8:  # 80% pass rate
            print(f"\n⚠️  Most tests passed - deployment is mostly functional with {total-passed} issues")
        else:
            print(f"\n🚨 DEPLOYMENT HAS SERIOUS ISSUES - {total-passed} critical failures")
        
        return passed >= total * 0.8  # Consider 80%+ a success

def main():
    """Main test execution"""
    tester = AzureDeploymentTester()
    success = tester.run_all_tests()
    
    # Save detailed results
    results_file = f"azure_test_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(results_file, 'w') as f:
        json.dump({
            'summary': {
                'timestamp': datetime.now().isoformat(),
                'target_url': AZURE_BASE_URL,
                'total_tests': len(tester.test_results),
                'passed': sum(1 for r in tester.test_results if r['success']),
                'success_rate': sum(1 for r in tester.test_results if r['success']) / len(tester.test_results) * 100,
                'overall_success': success
            },
            'test_results': tester.test_results,
            'errors': tester.errors
        }, f, indent=2)
    
    print(f"\n📄 Detailed results saved to: {results_file}")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())