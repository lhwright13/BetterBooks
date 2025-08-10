#!/usr/bin/env python3
"""
Test script to validate local backend functionality.

This script tests all the key components of the BetterBooks backend:
- Database connectivity (PostgreSQL primary/replica, PgBouncer)
- Service health checks
- Monitoring stack (Prometheus, Grafana, Jaeger)
- API endpoints
"""

import asyncio
import aiohttp
import psycopg
import time
import sys
from typing import Dict, List, Optional

# Configuration
SERVICES = {
    'postgres_primary': {'host': 'localhost', 'port': 5432},
    'postgres_replica': {'host': 'localhost', 'port': 5433}, 
    'pgbouncer': {'host': 'localhost', 'port': 6432},
    'pgbouncer_replica': {'host': 'localhost', 'port': 6433},
    'redis': {'host': 'localhost', 'port': 6379},
    'api_gateway': {'host': 'localhost', 'port': 8000},
    'context_service': {'host': 'localhost', 'port': 8001},
    'llm_gateway': {'host': 'localhost', 'port': 8002},
    'transcription_service': {'host': 'localhost', 'port': 8003},
    'tts_service': {'host': 'localhost', 'port': 8004},
    'prometheus': {'host': 'localhost', 'port': 9090},
    'grafana': {'host': 'localhost', 'port': 3000},
    'jaeger': {'host': 'localhost', 'port': 16686},
    'web_app': {'host': 'localhost', 'port': 8080},
}

class BackendTester:
    def __init__(self):
        self.results: Dict[str, bool] = {}
        self.session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=10)
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    def print_header(self, title: str):
        print(f"\n{'='*60}")
        print(f"🧪 {title}")
        print(f"{'='*60}")

    def print_test(self, name: str, status: bool, message: str = ""):
        icon = "✅" if status else "❌"
        print(f"{icon} {name:<40} {'PASS' if status else 'FAIL'}")
        if message:
            print(f"   💬 {message}")
        self.results[name] = status

    async def test_database_connectivity(self):
        """Test PostgreSQL primary and replica connectivity."""
        self.print_header("Database Connectivity Tests")
        
        # Test primary database
        try:
            conn = await psycopg.AsyncConnection.connect(
                "postgresql://betterbooks:betterbooks@localhost:5432/betterbooks",
                timeout=5
            )
            await conn.execute("SELECT 1")
            await conn.close()
            self.print_test("PostgreSQL Primary", True, "Direct connection successful")
        except Exception as e:
            self.print_test("PostgreSQL Primary", False, f"Connection failed: {str(e)}")

        # Test replica database
        try:
            conn = await psycopg.AsyncConnection.connect(
                "postgresql://betterbooks:betterbooks@localhost:5433/betterbooks",
                timeout=5
            )
            await conn.execute("SELECT 1")
            await conn.close()
            self.print_test("PostgreSQL Replica", True, "Direct connection successful")
        except Exception as e:
            self.print_test("PostgreSQL Replica", False, f"Connection failed: {str(e)}")

        # Test vector extension
        try:
            conn = await psycopg.AsyncConnection.connect(
                "postgresql://betterbooks:betterbooks@localhost:5432/betterbooks",
                timeout=5
            )
            result = await conn.execute("SELECT extname FROM pg_extension WHERE extname = 'vector'")
            extensions = await result.fetchall()
            await conn.close()
            
            if extensions:
                self.print_test("Vector Extension", True, "pgvector extension is installed")
            else:
                self.print_test("Vector Extension", False, "pgvector extension not found")
        except Exception as e:
            self.print_test("Vector Extension", False, f"Check failed: {str(e)}")

    async def test_connection_pooling(self):
        """Test PgBouncer connection pooling."""
        self.print_header("Connection Pooling Tests")
        
        # Test primary pgbouncer
        try:
            conn = await psycopg.AsyncConnection.connect(
                "postgresql://betterbooks:betterbooks@localhost:6432/betterbooks",
                timeout=5
            )
            await conn.execute("SELECT 1")
            await conn.close()
            self.print_test("PgBouncer Primary", True, "Connection pool accessible")
        except Exception as e:
            self.print_test("PgBouncer Primary", False, f"Pool connection failed: {str(e)}")

        # Test replica pgbouncer
        try:
            conn = await psycopg.AsyncConnection.connect(
                "postgresql://betterbooks:betterbooks@localhost:6433/betterbooks",
                timeout=5
            )
            await conn.execute("SELECT 1")
            await conn.close()
            self.print_test("PgBouncer Replica", True, "Read replica pool accessible")
        except Exception as e:
            self.print_test("PgBouncer Replica", False, f"Replica pool connection failed: {str(e)}")

    async def test_http_services(self):
        """Test HTTP service endpoints."""
        self.print_header("HTTP Service Tests")
        
        if not self.session:
            self.print_test("HTTP Session", False, "Session not initialized")
            return

        # Test service health endpoints
        services_to_test = [
            ('api_gateway', '/health'),
            ('context_service', '/health'),
            ('llm_gateway', '/health'),
            ('transcription_service', '/health'),
            ('tts_service', '/health'),
        ]

        for service_name, endpoint in services_to_test:
            if service_name not in SERVICES:
                continue
                
            config = SERVICES[service_name]
            url = f"http://{config['host']}:{config['port']}{endpoint}"
            
            try:
                async with self.session.get(url) as response:
                    if response.status == 200:
                        data = await response.json()
                        self.print_test(f"{service_name.replace('_', ' ').title()}", True, 
                                      f"Health check passed: {data.get('status', 'ok')}")
                    else:
                        self.print_test(f"{service_name.replace('_', ' ').title()}", False, 
                                      f"HTTP {response.status}")
            except Exception as e:
                self.print_test(f"{service_name.replace('_', ' ').title()}", False, 
                              f"Connection failed: {str(e)}")

    async def test_monitoring_stack(self):
        """Test monitoring and observability services."""
        self.print_header("Monitoring Stack Tests")
        
        if not self.session:
            return

        # Test Prometheus
        try:
            url = f"http://localhost:9090/-/healthy"
            async with self.session.get(url) as response:
                if response.status == 200:
                    self.print_test("Prometheus", True, "Metrics collection service running")
                else:
                    self.print_test("Prometheus", False, f"HTTP {response.status}")
        except Exception as e:
            self.print_test("Prometheus", False, f"Connection failed: {str(e)}")

        # Test Grafana
        try:
            url = f"http://localhost:3000/api/health"
            async with self.session.get(url) as response:
                if response.status == 200:
                    self.print_test("Grafana", True, "Dashboard service running")
                else:
                    self.print_test("Grafana", False, f"HTTP {response.status}")
        except Exception as e:
            self.print_test("Grafana", False, f"Connection failed: {str(e)}")

        # Test Jaeger
        try:
            url = f"http://localhost:16686/"
            async with self.session.get(url) as response:
                if response.status == 200:
                    self.print_test("Jaeger", True, "Distributed tracing UI running")
                else:
                    self.print_test("Jaeger", False, f"HTTP {response.status}")
        except Exception as e:
            self.print_test("Jaeger", False, f"Connection failed: {str(e)}")

    async def test_advanced_features(self):
        """Test advanced database features."""
        self.print_header("Advanced Features Tests")
        
        if not self.session:
            return

        # Test Context Service admin endpoints (if running)
        admin_endpoints = [
            ('/admin/indexes', 'Database Indexes'),
            ('/admin/migrations', 'Database Migrations'),
        ]

        for endpoint, feature_name in admin_endpoints:
            url = f"http://localhost:8001{endpoint}"
            try:
                async with self.session.get(url) as response:
                    if response.status == 200:
                        data = await response.json()
                        self.print_test(feature_name, True, f"Admin endpoint accessible")
                    else:
                        self.print_test(feature_name, False, f"HTTP {response.status}")
            except Exception as e:
                self.print_test(feature_name, False, f"Connection failed: {str(e)}")

    def print_summary(self):
        """Print test summary."""
        self.print_header("Test Summary")
        
        passed = sum(1 for result in self.results.values() if result)
        total = len(self.results)
        failed = total - passed
        
        print(f"📊 Total Tests: {total}")
        print(f"✅ Passed: {passed}")
        print(f"❌ Failed: {failed}")
        
        if failed == 0:
            print("\n🎉 All tests passed! Your local backend is ready to go!")
            print("\n🚀 Services Available:")
            print("   • Web Demo: http://localhost:8080")
            print("   • API Gateway: http://localhost:8000")
            print("   • Prometheus: http://localhost:9090")
            print("   • Grafana: http://localhost:3000 (admin/admin)")
            print("   • Jaeger: http://localhost:16686")
        else:
            print(f"\n⚠️  {failed} tests failed. Check the errors above.")
            print("\n💡 Common fixes:")
            print("   • Run: docker-compose down && docker-compose up --build")
            print("   • Check: docker-compose logs <service-name>")
            print("   • Verify: docker-compose ps")
        
        return failed == 0

    async def run_all_tests(self):
        """Run all tests."""
        print("🔧 BetterBooks Local Backend Test Suite")
        print(f"⏰ Started at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        await self.test_database_connectivity()
        await self.test_connection_pooling()
        await self.test_http_services()
        await self.test_monitoring_stack()
        await self.test_advanced_features()
        
        return self.print_summary()

async def main():
    """Main test runner."""
    try:
        async with BackendTester() as tester:
            success = await tester.run_all_tests()
            sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⏹️  Tests interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n💥 Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    # Install required packages if not available
    try:
        import aiohttp
        import psycopg
    except ImportError as e:
        print(f"❌ Missing required package: {e}")
        print("💡 Install with: pip install aiohttp psycopg[binary]")
        sys.exit(1)
    
    asyncio.run(main())