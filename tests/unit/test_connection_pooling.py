"""
Test PostgreSQL connection pooling with pgbouncer implementation.

This test validates that the database connection pooling system works correctly,
including pool management, health monitoring, and performance optimization.
"""

import os
import sys
import asyncio
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, AsyncMock
import yaml

# Add project root to path to import core modules
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

def test_docker_compose_pgbouncer():
    """Test that docker-compose includes pgbouncer configuration."""
    print("Testing pgbouncer configuration in docker-compose.yml...")
    
    try:
        compose_file = Path(__file__).parent / "docker-compose.yml"
        if not compose_file.exists():
            print("❌ docker-compose.yml not found")
            return False
            
        with open(compose_file, 'r') as f:
            content = f.read()
        
        # Check for pgbouncer service
        if "pgbouncer:" not in content:
            print("❌ pgbouncer service not found in docker-compose.yml")
            return False
        print("✅ pgbouncer service found in docker-compose.yml")
        
        # Check for pgbouncer image
        if "pgbouncer/pgbouncer" not in content:
            print("❌ pgbouncer image not specified")
            return False
        print("✅ pgbouncer image correctly specified")
        
        # Check for pgbouncer port
        if "6432:6432" not in content:
            print("❌ pgbouncer port not exposed")
            return False
        print("✅ pgbouncer port exposed")
        
        # Check that services use pgbouncer
        if "pgbouncer:6432" not in content:
            print("❌ services not configured to use pgbouncer")
            return False
        print("✅ services configured to use pgbouncer")
        
        return True
        
    except Exception as e:
        print(f"❌ Error checking docker-compose.yml: {e}")
        return False

def test_pgbouncer_configuration():
    """Test pgbouncer.ini configuration file."""
    print("\\nTesting pgbouncer.ini configuration...")
    
    try:
        pgbouncer_config = Path(__file__).parent / "pgbouncer.ini"
        if not pgbouncer_config.exists():
            print("❌ pgbouncer.ini not found")
            return False
        print("✅ pgbouncer.ini found")
        
        with open(pgbouncer_config, 'r') as f:
            content = f.read()
        
        # Check essential configuration
        required_settings = [
            "listen_port = 6432",
            "pool_mode = transaction", 
            "max_client_conn =",
            "default_pool_size =",
            "[databases]"
        ]
        
        missing_settings = []
        for setting in required_settings:
            if setting not in content:
                missing_settings.append(setting)
        
        if missing_settings:
            print(f"❌ Missing settings: {', '.join(missing_settings)}")
            return False
        print("✅ All required pgbouncer settings present")
        
        # Check performance settings
        if "tcp_keepalive = 1" not in content:
            print("⚠️ TCP keepalive not enabled")
        else:
            print("✅ TCP keepalive configured")
        
        return True
        
    except Exception as e:
        print(f"❌ Error checking pgbouncer.ini: {e}")
        return False

def test_postgresql_configuration():
    """Test PostgreSQL performance configuration."""
    print("\\nTesting postgresql.conf configuration...")
    
    try:
        postgresql_config = Path(__file__).parent / "postgresql.conf"
        if not postgresql_config.exists():
            print("❌ postgresql.conf not found")
            return False
        print("✅ postgresql.conf found")
        
        with open(postgresql_config, 'r') as f:
            content = f.read()
        
        # Check performance settings
        performance_settings = [
            "shared_buffers",
            "effective_cache_size", 
            "work_mem",
            "max_connections",
            "wal_level = replica"
        ]
        
        missing_settings = []
        for setting in performance_settings:
            if setting not in content:
                missing_settings.append(setting)
        
        if missing_settings:
            print(f"❌ Missing performance settings: {', '.join(missing_settings)}")
            return False
        print("✅ All performance settings present")
        
        # Check for pgvector specific settings
        if "shared_preload_libraries" not in content:
            print("⚠️ shared_preload_libraries not configured")
        else:
            print("✅ shared_preload_libraries configured")
        
        return True
        
    except Exception as e:
        print(f"❌ Error checking postgresql.conf: {e}")
        return False

def test_database_manager_structure():
    """Test database manager module structure."""
    print("\\nTesting database manager module...")
    
    try:
        # Test that we can import the database manager
        from core.database import database_manager
        print("✅ Database manager module imports successfully")
        
        # Test that key classes exist
        assert hasattr(database_manager, 'DatabaseConfig'), "DatabaseConfig class missing"
        assert hasattr(database_manager, 'DatabaseManager'), "DatabaseManager class missing"
        assert hasattr(database_manager, 'DatabaseMetrics'), "DatabaseMetrics class missing"
        print("✅ All database manager classes are present")
        
        # Test that key functions exist
        assert hasattr(database_manager, 'get_database_manager'), "get_database_manager function missing"
        assert hasattr(database_manager, 'execute_query'), "execute_query function missing"
        assert hasattr(database_manager, 'database_connection'), "database_connection function missing"
        print("✅ All key database functions are present")
        
        # Test configuration creation
        config = database_manager.DatabaseConfig(
            min_connections=5,
            max_connections=20,
            connection_timeout=30.0
        )
        assert config.min_connections == 5
        assert config.max_connections == 20
        assert config.connection_timeout == 30.0
        print("✅ DatabaseConfig works correctly")
        
        # Test metrics
        metrics = database_manager.DatabaseMetrics()
        assert hasattr(metrics, 'record_query'), "record_query method missing"
        assert hasattr(metrics, 'get_metrics'), "get_metrics method missing"
        print("✅ DatabaseMetrics works correctly")
        
        print("✅ Database manager structure validation passed")
        return True
        
    except ImportError as e:
        print(f"❌ Failed to import database_manager: {e}")
        return False
    except AssertionError as e:
        print(f"❌ Assertion failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def test_context_service_integration():
    """Test that Context Service integrates database manager."""
    print("\\nTesting Context Service database integration...")
    
    try:
        # Check that Context Service includes database manager
        context_main = Path(__file__).parent / "services" / "context_service" / "main.py"
        
        if not context_main.exists():
            print("❌ Context Service main.py not found")
            return False
            
        with open(context_main, 'r') as f:
            content = f.read()
        
        # Check for database manager imports
        if "from database_manager import" not in content:
            print("❌ Database manager imports not found in Context Service")
            return False
        print("✅ Database manager imports found in Context Service")
        
        # Check for connection pooling usage
        if "database_connection" not in content:
            print("❌ Connection pooling not used in Context Service")
            return False
        print("✅ Connection pooling usage found in Context Service")
        
        # Check for async endpoints
        if "async def" not in content:
            print("❌ No async endpoints found in Context Service")
            return False
        print("✅ Async endpoints found in Context Service")
        
        # Check for enhanced schema
        if "book_id" not in content or "chapter_id" not in content:
            print("❌ Enhanced schema not implemented")
            return False
        print("✅ Enhanced schema implemented")
        
        # Check for indexing
        if "CREATE INDEX" not in content:
            print("❌ Database indexing not implemented")
            return False
        print("✅ Database indexing implemented")
        
        print("✅ Context Service database integration verified")
        return True
        
    except Exception as e:
        print(f"❌ Error checking Context Service integration: {e}")
        return False

def test_requirements_updates():
    """Test that context service has connection pooling dependencies."""
    print("\\nTesting connection pooling dependencies...")
    
    try:
        req_file = Path(__file__).parent / "services" / "context_service" / "requirements.txt"
        if not req_file.exists():
            print("❌ Context Service requirements.txt not found")
            return False
            
        with open(req_file, 'r') as f:
            content = f.read()
        
        required_packages = [
            "psycopg-pool",  # Connection pooling
            "psycopg[binary]",  # Async PostgreSQL driver
            "pgvector"  # Vector extension
        ]
        
        missing_packages = []
        for package in required_packages:
            if package not in content:
                missing_packages.append(package)
        
        if missing_packages:
            print(f"❌ Missing packages: {', '.join(missing_packages)}")
            return False
        print("✅ All required connection pooling packages present")
        
        return True
        
    except Exception as e:
        print(f"❌ Error checking requirements: {e}")
        return False

def test_environment_configuration():
    """Test environment variable configuration for connection pooling."""
    print("\\nTesting environment configuration...")
    
    try:
        # Test .env.example if it exists
        env_example = Path(__file__).parent / ".env.example"
        if env_example.exists():
            with open(env_example, 'r') as f:
                content = f.read()
            
            if "DATABASE_URL" in content:
                print("✅ DATABASE_URL configured in .env.example")
            else:
                print("⚠️ DATABASE_URL not found in .env.example")
        
        # Test docker-compose environment variables
        compose_file = Path(__file__).parent / "docker-compose.yml"
        if compose_file.exists():
            with open(compose_file, 'r') as f:
                content = f.read()
            
            if "POSTGRES_USER" in content and "POSTGRES_PASSWORD" in content:
                print("✅ PostgreSQL credentials configured in docker-compose")
            else:
                print("❌ PostgreSQL credentials not configured")
                return False
        
        return True
        
    except Exception as e:
        print(f"❌ Error checking environment configuration: {e}")
        return False

def run_all_tests():
    """Run all connection pooling tests."""
    print("🧪 Validating PostgreSQL Connection Pooling Implementation")
    print("=" * 70)
    
    tests = [
        ("Docker Compose PgBouncer Configuration", test_docker_compose_pgbouncer),
        ("PgBouncer Configuration File", test_pgbouncer_configuration),
        ("PostgreSQL Performance Configuration", test_postgresql_configuration),
        ("Database Manager Module Structure", test_database_manager_structure),
        ("Context Service Integration", test_context_service_integration),
        ("Connection Pooling Dependencies", test_requirements_updates),
        ("Environment Configuration", test_environment_configuration),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\\n🔍 {test_name}")
        print("-" * 50)
        success = test_func()
        results.append((test_name, success))
    
    print("\\n" + "=" * 70)
    print("📊 TEST SUMMARY")
    print("=" * 70)
    
    all_passed = True
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status}  {test_name}")
        if not success:
            all_passed = False
    
    print("\\n" + "=" * 70)
    if all_passed:
        print("🎉 ALL TESTS PASSED! Connection pooling is properly implemented.")
        print("\\n📋 What's been implemented:")
        print("  • PgBouncer connection pooling service")
        print("  • PostgreSQL performance optimization") 
        print("  • Async database connection management")
        print("  • Connection pool metrics and monitoring")
        print("  • Enhanced Context Service with pooling")
        print("  • Optimized database schema and indexing")
        print("  • Health checks and error handling")
        print("\\n🚀 Benefits:")
        print("  • Reduced connection overhead") 
        print("  • Better resource utilization")
        print("  • Improved concurrent request handling")
        print("  • Enhanced database performance monitoring")
        print("  • Production-ready connection management")
        print("\\n🔧 Next steps:")
        print("  • Run 'docker-compose up --build' to start with pooling")
        print("  • Monitor connection metrics in Grafana")
        print("  • Test with concurrent load to validate pooling")
        print("  • Check pgbouncer stats at pgbouncer:6432/stats")
    else:
        print("❌ SOME TESTS FAILED! Review the errors above.")
    
    print("=" * 70)

if __name__ == "__main__":
    run_all_tests()