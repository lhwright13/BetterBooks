#!/usr/bin/env python3
"""
Test script for PostgreSQL database connectivity and OAuth compatibility

Tests:
1. Database connection
2. User model operations
3. Identity model operations (OAuth providers)
4. Session model operations
5. Authentication system
"""

import os
import sys
from pathlib import Path

# Add core to Python path
sys.path.insert(0, str(Path(__file__).parent / "core"))

# Set environment variables for testing
os.environ["DATABASE_URL"] = "postgresql://betterbooks:testpassword123@localhost:5432/betterbooks"
os.environ["JWT_SECRET_KEY"] = "test-secret-key-for-testing"

import logging
from datetime import datetime, timezone
from uuid import uuid4

# Import our database models directly (bypass conflicting __init__.py)
sys.path.insert(0, str(Path(__file__).parent / "core" / "database"))
from connection import get_database_manager, initialize_database, test_database_connection

sys.path.insert(0, str(Path(__file__).parent / "core" / "database" / "models"))
from user_model import UserModel, CreateUserRequest, UserRole
from identity_model import IdentityModel, CreateIdentityRequest, ProviderType
from session_model import SessionModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_database_connection_basic():
    """Test basic database connectivity"""
    logger.info("=== Testing Database Connection ===")
    
    try:
        initialize_database()
        success = test_database_connection()
        if success:
            logger.info("✅ Database connection successful")
            return True
        else:
            logger.error("❌ Database connection failed")
            return False
    except Exception as e:
        logger.error(f"❌ Database connection error: {e}")
        return False

def test_user_model():
    """Test user model CRUD operations"""
    logger.info("=== Testing User Model ===")
    
    try:
        user_model = UserModel()
        
        # Create test user
        user_data = CreateUserRequest(
            email="test@oauth.com",
            username="testuser",
            display_name="Test User",
            role=UserRole.USER,
            email_verified=False
        )
        
        user = user_model.create_user(user_data)
        logger.info(f"✅ Created user: {user.email} (ID: {user.id})")
        
        # Test get by ID
        retrieved_user = user_model.get_user_by_id(user.id)
        if retrieved_user and retrieved_user.email == user.email:
            logger.info("✅ User retrieval by ID successful")
        else:
            logger.error("❌ User retrieval by ID failed")
            return False
        
        # Test get by email
        email_user = user_model.get_user_by_email(user.email)
        if email_user and email_user.id == user.id:
            logger.info("✅ User retrieval by email successful")
        else:
            logger.error("❌ User retrieval by email failed")
            return False
        
        return True
        
    except Exception as e:
        logger.error(f"❌ User model test error: {e}")
        return False

def test_identity_model_oauth():
    """Test identity model with OAuth providers"""
    logger.info("=== Testing Identity Model (OAuth) ===")
    
    try:
        user_model = UserModel()
        identity_model = IdentityModel()
        
        # Create user for OAuth testing
        user_data = CreateUserRequest(
            email=None,  # Apple Sign In private relay - no email
            display_name="Apple User",
            role=UserRole.USER,
            email_verified=True
        )
        
        apple_user = user_model.create_user(user_data)
        logger.info(f"✅ Created Apple user: {apple_user.display_name} (ID: {apple_user.id})")
        
        # Create Apple identity
        apple_identity_data = CreateIdentityRequest(
            user_id=apple_user.id,
            provider=ProviderType.APPLE,
            provider_id="apple_user_12345",
            provider_email=None,  # Private relay
            provider_data={"name": {"firstName": "Apple", "lastName": "User"}},
            is_verified=True,
            is_primary=True
        )
        
        apple_identity = identity_model.create_identity(apple_identity_data)
        logger.info(f"✅ Created Apple identity for provider ID: {apple_identity.provider_id}")
        
        # Create Google user with email
        google_user_data = CreateUserRequest(
            email="google@test.com",
            display_name="Google User",
            role=UserRole.USER,
            email_verified=True
        )
        
        google_user = user_model.create_user(google_user_data)
        logger.info(f"✅ Created Google user: {google_user.email} (ID: {google_user.id})")
        
        # Create Google identity
        google_identity_data = CreateIdentityRequest(
            user_id=google_user.id,
            provider=ProviderType.GOOGLE,
            provider_id="google_user_67890",
            provider_email="google@test.com",
            provider_data={"picture": "https://example.com/avatar.jpg"},
            is_verified=True,
            is_primary=True
        )
        
        google_identity = identity_model.create_identity(google_identity_data)
        logger.info(f"✅ Created Google identity for provider ID: {google_identity.provider_id}")
        
        # Test provider lookup
        found_apple = identity_model.get_identity_by_provider(ProviderType.APPLE, "apple_user_12345")
        if found_apple and found_apple.user_id == apple_user.id:
            logger.info("✅ Apple identity lookup successful")
        else:
            logger.error("❌ Apple identity lookup failed")
            return False
        
        found_google = identity_model.get_identity_by_provider(ProviderType.GOOGLE, "google_user_67890")
        if found_google and found_google.user_id == google_user.id:
            logger.info("✅ Google identity lookup successful")
        else:
            logger.error("❌ Google identity lookup failed")
            return False
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Identity model OAuth test error: {e}")
        return False

def test_session_model():
    """Test session model for JWT token management"""
    logger.info("=== Testing Session Model ===")
    
    try:
        user_model = UserModel()
        session_model = SessionModel()
        
        # Create test user
        user_data = CreateUserRequest(
            email="session@test.com",
            username="sessionuser",
            display_name="Session User",
            role=UserRole.USER
        )
        
        user = user_model.create_user(user_data)
        logger.info(f"✅ Created session test user: {user.email}")
        
        # Create session
        from session_model import CreateSessionRequest
        from datetime import timedelta
        
        session_data = CreateSessionRequest(
            user_id=user.id,
            token_hash="test_token_hash_12345",
            token_type="access",
            expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
            user_agent="TestAgent/1.0",
            ip_address="127.0.0.1"
        )
        
        session = session_model.create_session(session_data)
        logger.info(f"✅ Created session: {session.id}")
        
        # Test session validation
        validated_session = session_model.validate_session("test_token_hash_12345")
        if validated_session and validated_session.user_id == user.id:
            logger.info("✅ Session validation successful")
        else:
            logger.error("❌ Session validation failed")
            return False
        
        # Test session revocation
        revoked = session_model.revoke_session(session.id)
        if revoked:
            logger.info("✅ Session revocation successful")
        else:
            logger.error("❌ Session revocation failed")
            return False
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Session model test error: {e}")
        return False

def test_authentication_system():
    """Test the complete authentication system"""
    logger.info("=== Testing Complete Authentication System ===")
    
    try:
        # Import authentication functions
        sys.path.insert(0, str(Path(__file__).parent / "platform/backend/services/api_gateway"))
        from auth_postgresql import (
            register_user_with_email, authenticate_user_with_email,
            authenticate_or_register_oauth_user, UserRegistration, UserLogin, 
            OAuthUserData, ProviderType
        )
        
        # Test email registration
        reg_data = UserRegistration(
            email="auth@test.com",
            username="authuser", 
            password="testpassword123",
            display_name="Auth Test User"
        )
        
        reg_response = register_user_with_email(reg_data)
        logger.info(f"✅ Email registration successful: {reg_response.user.email}")
        logger.info(f"✅ Access token generated: {reg_response.access_token[:20]}...")
        
        # Test email login
        login_data = UserLogin(
            email="auth@test.com",
            password="testpassword123"
        )
        
        login_response = authenticate_user_with_email(login_data)
        logger.info(f"✅ Email login successful: {login_response.user.email}")
        logger.info(f"✅ Login token generated: {login_response.access_token[:20]}...")
        
        # Test OAuth registration (Google)
        oauth_data = OAuthUserData(
            provider=ProviderType.GOOGLE,
            provider_id="google_oauth_test_123",
            provider_email="oauth@google.com",
            display_name="Google OAuth User",
            avatar_url="https://example.com/avatar.jpg",
            provider_data={"locale": "en", "verified_email": True}
        )
        
        oauth_response = authenticate_or_register_oauth_user(oauth_data)
        logger.info(f"✅ Google OAuth successful: {oauth_response.user.display_name}")
        logger.info(f"✅ OAuth token generated: {oauth_response.access_token[:20]}...")
        
        # Test OAuth registration (Apple - no email)
        apple_oauth_data = OAuthUserData(
            provider=ProviderType.APPLE,
            provider_id="apple_oauth_test_456",
            provider_email=None,  # Private relay
            display_name="Apple OAuth User",
            provider_data={"email_verified": True, "is_private_email": True}
        )
        
        apple_response = authenticate_or_register_oauth_user(apple_oauth_data)
        logger.info(f"✅ Apple OAuth successful: {apple_response.user.display_name}")
        logger.info(f"✅ Apple token generated: {apple_response.access_token[:20]}...")
        
        return True
        
    except Exception as e:
        logger.error(f"❌ Authentication system test error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all tests"""
    logger.info("🚀 Starting PostgreSQL OAuth Compatibility Tests")
    
    tests = [
        ("Database Connection", test_database_connection_basic),
        ("User Model", test_user_model),
        ("Identity Model (OAuth)", test_identity_model_oauth),
        ("Session Model", test_session_model),
        ("Authentication System", test_authentication_system)
    ]
    
    results = []
    for test_name, test_func in tests:
        logger.info(f"\n{'='*50}")
        try:
            success = test_func()
            results.append((test_name, success))
        except Exception as e:
            logger.error(f"❌ {test_name} failed with exception: {e}")
            results.append((test_name, False))
    
    # Summary
    logger.info(f"\n{'='*50}")
    logger.info("📊 TEST RESULTS SUMMARY")
    logger.info(f"{'='*50}")
    
    passed = 0
    total = len(results)
    
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        logger.info(f"{test_name}: {status}")
        if success:
            passed += 1
    
    logger.info(f"\n🎯 Overall: {passed}/{total} tests passed ({passed/total*100:.1f}%)")
    
    if passed == total:
        logger.info("🎉 All tests passed! OAuth-compatible database system is working correctly.")
        return True
    else:
        logger.error(f"💥 {total-passed} tests failed. Please check the errors above.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)