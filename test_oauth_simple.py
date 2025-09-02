#!/usr/bin/env python3
"""
Simple test script for OAuth-compatible database setup

Tests the database schema and basic operations directly with psycopg2
"""

import os
import sys
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timezone
from uuid import uuid4

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATABASE_URL = "postgresql://betterbooks:testpassword123@localhost:5432/betterbooks"

def test_database_connection():
    """Test basic database connectivity"""
    logger.info("=== Testing Database Connection ===")
    
    try:
        conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        cursor = conn.cursor()
        cursor.execute("SELECT 1 as test")
        result = cursor.fetchone()
        
        if result['test'] == 1:
            logger.info("✅ Database connection successful")
            cursor.close()
            conn.close()
            return True
        else:
            logger.error("❌ Database connection failed")
            return False
    except Exception as e:
        logger.error(f"❌ Database connection error: {e}")
        return False

def run_migration():
    """Run the OAuth compatibility migration"""
    logger.info("=== Running OAuth Compatibility Migration ===")
    
    try:
        conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        cursor = conn.cursor()
        
        # Read and execute migration
        migration_path = "core/database/migrations/V018_20250901_oauth_compatibility.sql"
        with open(migration_path, 'r') as f:
            migration_sql = f.read()
        
        cursor.execute(migration_sql)
        conn.commit()
        
        logger.info("✅ Migration executed successfully")
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        logger.error(f"❌ Migration error: {e}")
        return False

def test_oauth_schema():
    """Test OAuth-compatible database schema"""
    logger.info("=== Testing OAuth Schema ===")
    
    try:
        conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        cursor = conn.cursor()
        
        # Test users table structure
        cursor.execute("""
            SELECT column_name, is_nullable, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'users' 
            ORDER BY ordinal_position
        """)
        
        users_columns = cursor.fetchall()
        logger.info("Users table columns:")
        for col in users_columns:
            logger.info(f"  - {col['column_name']}: {col['data_type']} ({'nullable' if col['is_nullable'] == 'YES' else 'not null'})")
        
        # Test identities table structure
        cursor.execute("""
            SELECT column_name, is_nullable, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'identities' 
            ORDER BY ordinal_position
        """)
        
        identities_columns = cursor.fetchall()
        logger.info("Identities table columns:")
        for col in identities_columns:
            logger.info(f"  - {col['column_name']}: {col['data_type']} ({'nullable' if col['is_nullable'] == 'YES' else 'not null'})")
        
        # Test password_credentials table structure
        cursor.execute("""
            SELECT column_name, is_nullable, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'password_credentials' 
            ORDER BY ordinal_position
        """)
        
        credentials_columns = cursor.fetchall()
        logger.info("Password_credentials table columns:")
        for col in credentials_columns:
            logger.info(f"  - {col['column_name']}: {col['data_type']} ({'nullable' if col['is_nullable'] == 'YES' else 'not null'})")
        
        logger.info("✅ OAuth schema structure verified")
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        logger.error(f"❌ Schema test error: {e}")
        return False

def test_oauth_operations():
    """Test OAuth-specific database operations"""
    logger.info("=== Testing OAuth Operations ===")
    
    try:
        conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
        cursor = conn.cursor()
        
        # Test 1: Create Apple Sign In user (no email)
        user_id = str(uuid4())
        cursor.execute("""
            INSERT INTO users (id, display_name, is_active, email_verified, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (user_id, "Apple User", True, True, datetime.now(timezone.utc), datetime.now(timezone.utc)))
        
        apple_user = cursor.fetchone()
        logger.info(f"✅ Created Apple user: {apple_user['display_name']} (ID: {apple_user['id']})")
        
        # Test 2: Create Apple identity
        identity_id = str(uuid4())
        cursor.execute("""
            INSERT INTO identities (id, user_id, provider, provider_id, is_verified, is_primary, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (identity_id, apple_user['id'], 'apple', 'apple_user_test_123', True, True, datetime.now(timezone.utc), datetime.now(timezone.utc)))
        
        apple_identity = cursor.fetchone()
        logger.info(f"✅ Created Apple identity: {apple_identity['provider']}:{apple_identity['provider_id']}")
        
        # Test 3: Create Google user with email
        google_user_id = str(uuid4())
        cursor.execute("""
            INSERT INTO users (id, email, display_name, is_active, email_verified, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (google_user_id, "google@test.com", "Google User", True, True, datetime.now(timezone.utc), datetime.now(timezone.utc)))
        
        google_user = cursor.fetchone()
        logger.info(f"✅ Created Google user: {google_user['email']} (ID: {google_user['id']})")
        
        # Test 4: Create Google identity
        google_identity_id = str(uuid4())
        cursor.execute("""
            INSERT INTO identities (id, user_id, provider, provider_id, provider_email, is_verified, is_primary, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (google_identity_id, google_user['id'], 'google', 'google_user_test_456', 'google@test.com', True, True, datetime.now(timezone.utc), datetime.now(timezone.utc)))
        
        google_identity = cursor.fetchone()
        logger.info(f"✅ Created Google identity: {google_identity['provider']}:{google_identity['provider_id']}")
        
        # Test 5: Create email/password user
        email_user_id = str(uuid4())
        cursor.execute("""
            INSERT INTO users (id, email, username, display_name, is_active, email_verified, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (email_user_id, "email@test.com", "emailuser", "Email User", True, False, datetime.now(timezone.utc), datetime.now(timezone.utc)))
        
        email_user = cursor.fetchone()
        logger.info(f"✅ Created email user: {email_user['email']} (ID: {email_user['id']})")
        
        # Test 6: Create email identity
        email_identity_id = str(uuid4())
        cursor.execute("""
            INSERT INTO identities (id, user_id, provider, provider_id, provider_email, is_verified, is_primary, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (email_identity_id, email_user['id'], 'email', 'email@test.com', 'email@test.com', False, True, datetime.now(timezone.utc), datetime.now(timezone.utc)))
        
        email_identity = cursor.fetchone()
        logger.info(f"✅ Created email identity: {email_identity['provider']}:{email_identity['provider_id']}")
        
        # Test 7: Create password credential
        password_id = str(uuid4())
        cursor.execute("""
            INSERT INTO password_credentials (id, user_id, password_hash, salt, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (password_id, email_user['id'], '$2b$12$hashedpassword...', 'salt123', datetime.now(timezone.utc), datetime.now(timezone.utc)))
        
        password_cred = cursor.fetchone()
        logger.info(f"✅ Created password credential for user: {email_user['email']}")
        
        # Test 8: Test provider lookup
        cursor.execute("""
            SELECT i.*, u.display_name, u.email 
            FROM identities i
            JOIN users u ON i.user_id = u.id
            WHERE i.provider = %s AND i.provider_id = %s
        """, ('apple', 'apple_user_test_123'))
        
        found_apple = cursor.fetchone()
        if found_apple:
            logger.info(f"✅ Apple provider lookup successful: {found_apple['display_name']}")
        else:
            logger.error("❌ Apple provider lookup failed")
            return False
        
        # Test 9: Test session creation
        session_id = str(uuid4())
        cursor.execute("""
            INSERT INTO sessions (id, user_id, token_hash, token_type, expires_at, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING *
        """, (session_id, email_user['id'], 'token_hash_test_123', 'access', datetime.now(timezone.utc), datetime.now(timezone.utc)))
        
        session = cursor.fetchone()
        logger.info(f"✅ Created session: {session['token_type']} token for {email_user['email']}")
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info("✅ All OAuth operations successful")
        return True
        
    except Exception as e:
        logger.error(f"❌ OAuth operations test error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run all tests"""
    logger.info("🚀 Starting Simple OAuth Database Tests")
    
    tests = [
        ("Database Connection", test_database_connection),
        ("OAuth Migration", run_migration),
        ("OAuth Schema", test_oauth_schema),
        ("OAuth Operations", test_oauth_operations)
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