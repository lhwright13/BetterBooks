"""
Shared Configuration Manager for EchoWright Services

Provides secure, centralized configuration management across all microservices.
Handles environment variables, validation, and secure secret loading.
"""

import os
import logging
from typing import Optional, Dict, Any, List
from pathlib import Path
import json
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)

class Environment(Enum):
    DEVELOPMENT = "development"
    STAGING = "staging" 
    PRODUCTION = "production"
    TESTING = "testing"

@dataclass
class SecurityConfig:
    """Security-related configuration"""
    jwt_secret_key: str
    encryption_key: Optional[str] = None
    cors_origins: List[str] = None
    rate_limit_per_minute: int = 60
    rate_limit_burst: int = 10
    enable_https_redirect: bool = False
    
    def __post_init__(self):
        if self.cors_origins is None:
            self.cors_origins = ["http://localhost:8080"]

@dataclass  
class DatabaseConfig:
    """Database configuration"""
    url: str
    pool_size: int = 20
    max_overflow: int = 10
    pool_timeout: int = 30
    echo_sql: bool = False

@dataclass
class AIConfig:
    """AI provider configuration"""
    gemini_api_key: Optional[str] = None
    openai_api_key: Optional[str] = None
    elevenlabs_api_key: Optional[str] = None
    assemblyai_api_key: Optional[str] = None
    default_model: str = "gpt-4o-mini"
    max_tokens: int = 4000
    temperature: float = 0.7
    enable_content_filtering: bool = True

@dataclass
class CacheConfig:
    """Caching configuration"""
    redis_url: str = "redis://redis:6379/0"
    ttl_hours: int = 24
    enabled: bool = True
    max_size_mb: int = 500

@dataclass
class LoggingConfig:
    """Logging configuration"""
    level: str = "INFO"
    format: str = "json"
    enable_metrics: bool = True
    enable_tracing: bool = False

class ConfigManager:
    """
    Centralized configuration manager for EchoWright services.
    
    Handles:
    - Environment variable loading and validation
    - Service-specific configuration
    - Secure secret management
    - Configuration validation and defaults
    """
    
    def __init__(self, service_name: str = "echowright"):
        self.service_name = service_name
        self.environment = Environment(os.getenv("ENVIRONMENT", "development"))
        self._config_cache: Dict[str, Any] = {}
        
        # Load configuration
        self._load_config()
        
    def _load_config(self):
        """Load and validate configuration from environment variables"""
        logger.info(f"Loading configuration for {self.service_name} in {self.environment.value} mode")
        
        # Validate critical configuration
        self._validate_required_config()
        
    def _validate_required_config(self):
        """Validate that required configuration is present"""
        required_vars = []
        optional_vars = ["GEMINI_API_KEY", "JWT_SECRET_KEY", "AZURE_OPENAI_API_KEY"]
        
        if self.environment == Environment.PRODUCTION:
            # In production, these are truly required
            required_vars.extend(["JWT_SECRET_KEY", "AZURE_OPENAI_API_KEY", "DATABASE_URL"])
        elif self.environment == Environment.DEVELOPMENT:
            # In development, provide defaults if missing
            if not os.getenv("JWT_SECRET_KEY"):
                os.environ["JWT_SECRET_KEY"] = "dev-secret-key-not-for-production-use"
                logger.warning("Using default JWT_SECRET_KEY for development - not secure for production!")
            
            if not os.getenv("AZURE_OPENAI_API_KEY"):
                os.environ["AZURE_OPENAI_API_KEY"] = "test-api-key"
                logger.warning("Using test AZURE_OPENAI_API_KEY for development - AI features may not work")
                
        missing_vars = []
        for var in required_vars:
            if not os.getenv(var):
                missing_vars.append(var)
                
        if missing_vars:
            raise ValueError(f"Missing required environment variables: {missing_vars}")
        
        # Log optional variables that are missing
        missing_optional = [var for var in optional_vars if not os.getenv(var)]
        if missing_optional and self.environment == Environment.DEVELOPMENT:
            logger.info(f"Optional environment variables not set: {missing_optional} (using defaults)")
    
    def get_security_config(self) -> SecurityConfig:
        """Get security configuration"""
        cors_origins_str = os.getenv("CORS_ORIGINS", "http://localhost:8080")
        cors_origins = [origin.strip() for origin in cors_origins_str.split(",")]
        
        return SecurityConfig(
            jwt_secret_key=self.get_required("JWT_SECRET_KEY"),
            encryption_key=os.getenv("ENCRYPTION_KEY"),
            cors_origins=cors_origins,
            rate_limit_per_minute=int(os.getenv("RATE_LIMIT_REQUESTS_PER_MINUTE", "60")),
            rate_limit_burst=int(os.getenv("RATE_LIMIT_BURST", "10")),
            enable_https_redirect=self.environment == Environment.PRODUCTION,
        )
    
    def get_database_config(self) -> DatabaseConfig:
        """Get database configuration"""
        return DatabaseConfig(
            url=self.get_required("DATABASE_URL"),
            pool_size=int(os.getenv("DB_POOL_SIZE", "20")),
            max_overflow=int(os.getenv("DB_MAX_OVERFLOW", "10")),
            pool_timeout=int(os.getenv("DB_POOL_TIMEOUT", "30")),
            echo_sql=os.getenv("DEBUG", "false").lower() == "true" and self.environment != Environment.PRODUCTION,
        )
    
    def get_ai_config(self) -> AIConfig:
        """Get AI provider configuration"""
        return AIConfig(
            gemini_api_key=os.getenv("GEMINI_API_KEY"),  # Now optional - kept for backward compatibility
            openai_api_key=self.get_required("AZURE_OPENAI_API_KEY"),  # Azure OpenAI is now primary
            elevenlabs_api_key=os.getenv("ELEVENLABS_API_KEY"),
            assemblyai_api_key=os.getenv("ASSEMBLYAI_API_KEY"),
            default_model=os.getenv("DEFAULT_LLM_MODEL", "gpt-4o-mini"),
            max_tokens=int(os.getenv("MAX_CONTEXT_TOKENS", "4000")),
            temperature=float(os.getenv("LLM_TEMPERATURE", "0.7")),
            enable_content_filtering=os.getenv("ENABLE_CONTENT_FILTERING", "true").lower() == "true",
        )
    
    def get_cache_config(self) -> CacheConfig:
        """Get caching configuration"""
        return CacheConfig(
            redis_url=os.getenv("REDIS_URL", "redis://redis:6379/0"),
            ttl_hours=int(os.getenv("CACHE_TTL_HOURS", "24")),
            enabled=os.getenv("ENABLE_RESPONSE_CACHING", "true").lower() == "true",
            max_size_mb=int(os.getenv("CACHE_MAX_SIZE_MB", "500")),
        )
    
    def get_logging_config(self) -> LoggingConfig:
        """Get logging configuration"""
        return LoggingConfig(
            level=os.getenv("LOG_LEVEL", "INFO"),
            format=os.getenv("LOG_FORMAT", "json"),
            enable_metrics=os.getenv("ENABLE_METRICS", "true").lower() == "true",
            enable_tracing=os.getenv("ENABLE_TRACING", "false").lower() == "true",
        )
    
    def get_required(self, key: str) -> str:
        """Get required environment variable or raise error"""
        value = os.getenv(key)
        if not value:
            raise ValueError(f"Required environment variable {key} is not set")
        return value
    
    def get_optional(self, key: str, default: str = None) -> Optional[str]:
        """Get optional environment variable with default"""
        return os.getenv(key, default)
    
    def get_int(self, key: str, default: int = 0) -> int:
        """Get integer environment variable with default"""
        try:
            return int(os.getenv(key, str(default)))
        except ValueError:
            logger.warning(f"Invalid integer value for {key}, using default {default}")
            return default
    
    def get_float(self, key: str, default: float = 0.0) -> float:
        """Get float environment variable with default"""
        try:
            return float(os.getenv(key, str(default)))
        except ValueError:
            logger.warning(f"Invalid float value for {key}, using default {default}")
            return default
    
    def get_bool(self, key: str, default: bool = False) -> bool:
        """Get boolean environment variable with default"""
        value = os.getenv(key, str(default)).lower()
        return value in ("true", "1", "yes", "on")
    
    def get_list(self, key: str, delimiter: str = ",", default: List[str] = None) -> List[str]:
        """Get list environment variable with default"""
        value = os.getenv(key)
        if not value:
            return default or []
        return [item.strip() for item in value.split(delimiter)]
    
    def is_development(self) -> bool:
        """Check if running in development mode"""
        return self.environment == Environment.DEVELOPMENT
    
    def is_production(self) -> bool:
        """Check if running in production mode"""
        return self.environment == Environment.PRODUCTION
    
    def is_testing(self) -> bool:
        """Check if running in testing mode"""
        return self.environment == Environment.TESTING
    
    def validate_api_keys(self) -> Dict[str, bool]:
        """Validate which API keys are available"""
        api_keys = {
            "gemini": bool(os.getenv("GEMINI_API_KEY")),
            "openai": bool(os.getenv("OPENAI_API_KEY")),
            "azure_openai": bool(os.getenv("AZURE_OPENAI_API_KEY")),
            "elevenlabs": bool(os.getenv("ELEVENLABS_API_KEY")),
            "assemblyai": bool(os.getenv("ASSEMBLYAI_API_KEY")),
        }
        
        logger.info(f"Available API keys: {[k for k, v in api_keys.items() if v]}")
        return api_keys
    
    def get_service_url(self, service: str) -> str:
        """Get URL for internal service communication"""
        # Check for explicit service URL environment variables first
        service_env_vars = {
            "api_gateway": "API_GATEWAY_URL",
            "context_service": "CONTEXT_SERVICE_URL", 
            "llm_gateway": "LLM_GATEWAY_URL",
            "tts_service": "TTS_SERVICE_URL",
            "transcription_service": "TRANSCRIPTION_SERVICE_URL"
        }
        
        # Use explicit URL if provided
        env_var = service_env_vars.get(service)
        if env_var and os.getenv(env_var):
            url = os.getenv(env_var)
            logger.debug(f"Using explicit URL for {service}: {url}")
            return url
        
        # Determine base host based on environment
        if self.environment == Environment.DEVELOPMENT and os.getenv("RUNNING_OUTSIDE_DOCKER"):
            base_host = "localhost"
        else:
            base_host = service  # Docker service name
            
        # Default port mappings
        default_ports = {
            "api_gateway": "8000",
            "context_service": "8001", 
            "llm_gateway": "8002",
            "tts_service": "8003",
            "transcription_service": "8004",
        }
        
        port = os.getenv(f"{service.upper()}_PORT", default_ports.get(service, "8000"))
        url = f"http://{base_host}:{port}"
        
        logger.debug(f"Generated service URL for {service}: {url}")
        return url
    
    def get_config_summary(self) -> Dict[str, Any]:
        """Get configuration summary for debugging (without secrets)"""
        return {
            "service_name": self.service_name,
            "environment": self.environment.value,
            "debug_mode": os.getenv("DEBUG", "false").lower() == "true",
            "log_level": os.getenv("LOG_LEVEL", "INFO"),
            "available_apis": self.validate_api_keys(),
            "cache_enabled": os.getenv("ENABLE_RESPONSE_CACHING", "true").lower() == "true",
            "metrics_enabled": os.getenv("ENABLE_METRICS", "true").lower() == "true",
        }

# Global configuration instance
config = ConfigManager()

def get_config() -> ConfigManager:
    """Get the global configuration instance"""
    return config