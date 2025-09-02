"""
API Gateway Startup Validation Script

Validates all critical dependencies, configurations, and connections
before starting the main FastAPI application. This helps catch
configuration issues early and provides clear error messages.
"""

import sys
import os
import logging
import asyncio
import importlib
from typing import List, Dict, Any, Tuple

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class StartupValidator:
    """Validates API Gateway startup requirements"""
    
    def __init__(self):
        self.errors: List[str] = []
        self.warnings: List[str] = []
        
    def validate_imports(self) -> bool:
        """Validate all critical imports work correctly"""
        logger.info("🔍 Validating imports...")
        
        critical_imports = [
            ('fastapi', 'fastapi'),
            ('uvicorn', 'uvicorn'),
            ('httpx', 'httpx'),
            ('redis', 'redis'),
            ('psycopg2', 'psycopg2'),
            ('PyJWT', 'jwt'),  # Package name vs import name
            ('bcrypt', 'bcrypt'),
            ('pydantic', 'pydantic'),
        ]
        
        for display_name, import_name in critical_imports:
            try:
                importlib.import_module(import_name)
                logger.info(f"✅ {display_name} - OK")
            except ImportError as e:
                error_msg = f"❌ {display_name} - FAILED: {e}"
                logger.error(error_msg)
                self.errors.append(error_msg)
        
        # Test core modules (these must be in PYTHONPATH)
        core_modules = [
            ('config_manager', 'core.shared.utils.config_manager'),
            ('auth module', 'core.auth.auth'),
            # Skip database.connection as it doesn't exist - we use db_utils directly
        ]
        
        for display_name, module_name in core_modules:
            try:
                importlib.import_module(module_name)
                logger.info(f"✅ {display_name} - OK")
            except ImportError as e:
                error_msg = f"❌ {display_name} - FAILED: {e}"
                logger.error(error_msg)
                self.errors.append(error_msg)
        
        return len(self.errors) == 0
    
    def validate_environment(self) -> bool:
        """Validate environment variables and configuration"""
        logger.info("🔍 Validating environment configuration...")
        
        # Check critical environment variables first
        required_env_vars = [
            ("GEMINI_API_KEY", "AI functionality"),
            ("JWT_SECRET_KEY", "Authentication"),
        ]
        
        for var_name, purpose in required_env_vars:
            value = os.getenv(var_name)
            if not value or value in ["your-key-here", "test-key", ""]:
                warning_msg = f"⚠️  {var_name} not properly configured - {purpose} may not work"
                logger.warning(warning_msg)
                self.warnings.append(warning_msg)
            else:
                logger.info(f"✅ {var_name} - Configured ({len(value)} chars)")
        
        # Check optional environment variables
        optional_env_vars = [
            ("DATABASE_URL", "Database connection"),
            ("AZURE_STORAGE_ACCOUNT_KEY", "Azure file storage"),
            ("AZURE_STORAGE_ACCOUNT_NAME", "Azure storage account"),
        ]
        
        for var_name, purpose in optional_env_vars:
            value = os.getenv(var_name)
            if not value or value.startswith("your-"):
                logger.info(f"⚠️  {var_name} not configured - {purpose} will use fallbacks")
            else:
                logger.info(f"✅ {var_name} - Configured")
        
        # Try to import and test config manager if available
        try:
            from core.shared.utils.config_manager import ConfigManager
            config = ConfigManager(service_name="api_gateway")
            
            # Test configuration loading
            security_config = config.get_security_config()
            logger.info(f"✅ Config Manager - JWT key length: {len(security_config.jwt_secret_key)} chars")
            
            # Check environment
            env = config.environment.value
            logger.info(f"✅ Environment: {env}")
            
            if config.is_development():
                self.warnings.append("Running in development mode - some defaults are insecure")
                
        except Exception as e:
            warning_msg = f"⚠️  Config Manager not available: {e} - Using basic environment variables"
            logger.warning(warning_msg)
            self.warnings.append(warning_msg)
            
        return True
    
    def validate_database_connection(self) -> bool:
        """Test database connectivity"""
        logger.info("🔍 Testing database connection...")
        
        try:
            # Import the actual db_utils function we use in the API Gateway
            from db_utils import get_db_connection
            
            # Test basic connection
            conn = get_db_connection()
            if conn:
                # Test a simple query
                with conn.cursor() as cursor:
                    cursor.execute("SELECT version();")
                    version = cursor.fetchone()
                    if version:
                        logger.info(f"✅ Database connection - PostgreSQL {version[0].split()[1]}")
                    else:
                        logger.info("✅ Database connection - PostgreSQL (version unknown)")
                conn.close()
                return True
            else:
                error_msg = "❌ Database connection failed - no connection returned"
                logger.error(error_msg)
                self.errors.append(error_msg)
                return False
                
        except Exception as e:
            error_msg = f"❌ Database connection failed: {e}"
            logger.error(error_msg)
            self.errors.append(error_msg)
            return False
    
    async def validate_redis_connection(self) -> bool:
        """Test Redis connectivity"""
        logger.info("🔍 Testing Redis connection...")
        
        try:
            import redis.asyncio as redis
            
            redis_url = os.getenv("REDIS_URL", "redis://redis:6379/2")
            r = redis.from_url(redis_url)
            
            # Test connection
            await r.ping()
            await r.close()
            logger.info(f"✅ Redis connection - {redis_url}")
            return True
            
        except Exception as e:
            error_msg = f"❌ Redis connection failed: {e}"
            logger.error(error_msg)
            self.errors.append(error_msg)
            return False
    
    async def validate_service_urls(self) -> bool:
        """Validate service URL configuration and basic connectivity"""
        logger.info("🔍 Testing service URL configuration...")
        
        try:
            from core.shared.utils.config_manager import get_config
            import httpx
            
            config = get_config()
            services = ["context_service", "llm_gateway", "tts_service", "transcription_service"]
            
            async with httpx.AsyncClient(timeout=5.0) as client:
                for service in services:
                    try:
                        url = config.get_service_url(service)
                        health_url = f"{url}/health"
                        
                        logger.info(f"🔍 Testing {service} at {health_url}")
                        response = await client.get(health_url)
                        
                        if response.status_code == 200:
                            logger.info(f"✅ {service} - Healthy")
                        else:
                            warning_msg = f"⚠️  {service} - Unhealthy (HTTP {response.status_code})"
                            logger.warning(warning_msg)
                            self.warnings.append(warning_msg)
                            
                    except httpx.ConnectError:
                        warning_msg = f"⚠️  {service} - Not reachable (service may not be running)"
                        logger.warning(warning_msg)
                        self.warnings.append(warning_msg)
                    except Exception as e:
                        warning_msg = f"⚠️  {service} - Connection test failed: {e}"
                        logger.warning(warning_msg)
                        self.warnings.append(warning_msg)
            
            return True  # Service connectivity warnings don't fail startup
            
        except Exception as e:
            error_msg = f"❌ Service URL validation failed: {e}"
            logger.error(error_msg)
            self.errors.append(error_msg)
            return False
    
    def validate_file_access(self) -> bool:
        """Validate file system access permissions"""
        logger.info("🔍 Validating file system access...")
        
        try:
            # Check book files directory
            book_files_dir = "/app/book_files"
            if os.path.exists(book_files_dir):
                if os.access(book_files_dir, os.R_OK):
                    logger.info(f"✅ Book files directory - Readable")
                else:
                    warning_msg = f"⚠️  Book files directory - Not readable"
                    logger.warning(warning_msg)
                    self.warnings.append(warning_msg)
            else:
                warning_msg = f"⚠️  Book files directory - Does not exist"
                logger.warning(warning_msg)
                self.warnings.append(warning_msg)
            
            # Check core modules directory
            core_dir = "/app/core"
            if os.path.exists(core_dir) and os.access(core_dir, os.R_OK):
                logger.info(f"✅ Core modules directory - Readable")
            else:
                error_msg = f"❌ Core modules directory - Not accessible"
                logger.error(error_msg)
                self.errors.append(error_msg)
                return False
            
            return True
            
        except Exception as e:
            error_msg = f"❌ File system access validation failed: {e}"
            logger.error(error_msg)
            self.errors.append(error_msg)
            return False
    
    async def run_all_validations(self) -> Tuple[bool, Dict[str, Any]]:
        """Run all startup validations"""
        logger.info("🚀 Starting API Gateway validation checks...")
        
        results = {
            "imports": self.validate_imports(),
            "environment": self.validate_environment(),
            "database": self.validate_database_connection(),
            "redis": await self.validate_redis_connection(), 
            "services": await self.validate_service_urls(),
            "filesystem": self.validate_file_access()
        }
        
        all_passed = all(results.values())
        
        # Print summary
        logger.info("\n" + "="*50)
        logger.info("📋 STARTUP VALIDATION SUMMARY")
        logger.info("="*50)
        
        for check, passed in results.items():
            status = "✅ PASS" if passed else "❌ FAIL"
            logger.info(f"{check.upper():15} {status}")
        
        if self.warnings:
            logger.info("\n⚠️  WARNINGS:")
            for warning in self.warnings:
                logger.info(f"  {warning}")
        
        if self.errors:
            logger.error("\n❌ ERRORS:")
            for error in self.errors:
                logger.error(f"  {error}")
            logger.error("\n🛑 Startup validation FAILED - Fix errors before continuing")
        else:
            logger.info("\n🎉 All critical checks passed - API Gateway ready to start!")
        
        return all_passed, results

async def main():
    """Run startup validation as standalone script"""
    validator = StartupValidator()
    passed, results = await validator.run_all_validations()
    
    if not passed:
        sys.exit(1)
    else:
        logger.info("✅ Startup validation completed successfully")

if __name__ == "__main__":
    asyncio.run(main())