import os
import logging
import json
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)

_secrets_client = None
_secrets_cache: Dict[str, str] = {}


def _get_secrets_client():
    global _secrets_client
    if _secrets_client is None:
        try:
            import boto3
            _secrets_client = boto3.client('secretsmanager', region_name=os.getenv('AWS_REGION', 'us-east-1'))
        except ImportError:
            logger.debug("boto3 not available - AWS Secrets Manager disabled")
        except Exception as e:
            logger.debug(f"Could not initialize Secrets Manager client: {e}")
    return _secrets_client


def get_secret(key: str, default: Optional[str] = None) -> Optional[str]:
    env_value = os.getenv(key)
    if env_value:
        return env_value

    if key in _secrets_cache:
        return _secrets_cache[key]

    secret_name = os.getenv('AWS_SECRET_NAME', 'betterbooks/production')
    client = _get_secrets_client()

    if client:
        try:
            response = client.get_secret_value(SecretId=secret_name)
            secret_data = json.loads(response['SecretString'])
            _secrets_cache.update(secret_data)

            if key in secret_data:
                logger.debug(f"Retrieved {key} from AWS Secrets Manager")
                return secret_data[key]
        except Exception as e:
            logger.debug(f"Could not retrieve secret {key} from Secrets Manager: {e}")

    return default


class Environment(Enum):
    DEVELOPMENT = "development"
    STAGING = "staging"
    PRODUCTION = "production"
    TESTING = "testing"


@dataclass
class SecurityConfig:
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
    url: str
    pool_size: int = 20
    max_overflow: int = 10
    pool_timeout: int = 30
    echo_sql: bool = False

@dataclass
class AIConfig:
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
    redis_url: str = "redis://redis:6379/0"
    ttl_hours: int = 24
    enabled: bool = True
    max_size_mb: int = 500

@dataclass
class LoggingConfig:
    level: str = "INFO"
    format: str = "json"
    enable_metrics: bool = True
    enable_tracing: bool = False

class ConfigManager:

    def __init__(self, service_name: str = "echowright"):
        self.service_name = service_name
        self.environment = Environment(os.getenv("ENVIRONMENT", "development"))
        logger.info(f"Loading configuration for {self.service_name} in {self.environment.value} mode")
        self._validate_required_config()

    def _validate_required_config(self):
        required_vars = []

        if self.environment == Environment.PRODUCTION:
            required_vars.extend(["JWT_SECRET_KEY", "AZURE_OPENAI_API_KEY", "DATABASE_URL"])
        elif self.environment == Environment.DEVELOPMENT:
            if not os.getenv("JWT_SECRET_KEY"):
                os.environ["JWT_SECRET_KEY"] = "dev-secret-key-not-for-production-use"
                logger.warning("Using default JWT_SECRET_KEY for development - not secure for production!")
            if not os.getenv("AZURE_OPENAI_API_KEY"):
                os.environ["AZURE_OPENAI_API_KEY"] = "test-api-key"
                logger.warning("Using test AZURE_OPENAI_API_KEY for development - AI features may not work")

        missing_vars = [var for var in required_vars if not os.getenv(var)]
        if missing_vars:
            raise ValueError(f"Missing required environment variables: {missing_vars}")
    
    def get_security_config(self) -> SecurityConfig:
        cors_origins_str = os.getenv("CORS_ORIGINS", "http://localhost:3000,http://localhost:8080,http://127.0.0.1:3000")
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
        return DatabaseConfig(
            url=self.get_required("DATABASE_URL"),
            pool_size=int(os.getenv("DB_POOL_SIZE", "20")),
            max_overflow=int(os.getenv("DB_MAX_OVERFLOW", "10")),
            pool_timeout=int(os.getenv("DB_POOL_TIMEOUT", "30")),
            echo_sql=os.getenv("DEBUG", "false").lower() == "true" and self.environment != Environment.PRODUCTION,
        )
    
    def get_ai_config(self) -> AIConfig:
        return AIConfig(
            gemini_api_key=os.getenv("GEMINI_API_KEY"),
            openai_api_key=self.get_required("AZURE_OPENAI_API_KEY"),
            elevenlabs_api_key=os.getenv("ELEVENLABS_API_KEY"),
            assemblyai_api_key=os.getenv("ASSEMBLYAI_API_KEY"),
            default_model=os.getenv("DEFAULT_LLM_MODEL", "gpt-4o-mini"),
            max_tokens=int(os.getenv("MAX_CONTEXT_TOKENS", "4000")),
            temperature=float(os.getenv("LLM_TEMPERATURE", "0.7")),
            enable_content_filtering=os.getenv("ENABLE_CONTENT_FILTERING", "true").lower() == "true",
        )
    
    def get_cache_config(self) -> CacheConfig:
        return CacheConfig(
            redis_url=os.getenv("REDIS_URL", "redis://redis:6379/0"),
            ttl_hours=int(os.getenv("CACHE_TTL_HOURS", "24")),
            enabled=os.getenv("ENABLE_RESPONSE_CACHING", "true").lower() == "true",
            max_size_mb=int(os.getenv("CACHE_MAX_SIZE_MB", "500")),
        )
    
    def get_logging_config(self) -> LoggingConfig:
        return LoggingConfig(
            level=os.getenv("LOG_LEVEL", "INFO"),
            format=os.getenv("LOG_FORMAT", "json"),
            enable_metrics=os.getenv("ENABLE_METRICS", "true").lower() == "true",
            enable_tracing=os.getenv("ENABLE_TRACING", "false").lower() == "true",
        )
    
    def get_required(self, key: str) -> str:
        value = get_secret(key)
        if not value:
            raise ValueError(f"Required configuration {key} is not set (checked env vars and Secrets Manager)")
        return value

    def is_development(self) -> bool:
        return self.environment == Environment.DEVELOPMENT

    def validate_api_keys(self) -> Dict[str, bool]:
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
        service_env_vars = {
            "api_gateway": "API_GATEWAY_URL",
            "context_service": "CONTEXT_SERVICE_URL",
            "llm_gateway": "LLM_GATEWAY_URL",
            "tts_service": "TTS_SERVICE_URL",
            "transcription_service": "TRANSCRIPTION_SERVICE_URL"
        }

        env_var = service_env_vars.get(service)
        if env_var and os.getenv(env_var):
            return os.getenv(env_var)

        default_ports = {
            "api_gateway": "8000",
            "context_service": "8001",
            "llm_gateway": "8002",
            "tts_service": "8003",
            "transcription_service": "8004",
        }

        port = os.getenv(f"{service.upper()}_PORT", default_ports.get(service, "8000"))

        if os.getenv("RUNNING_OUTSIDE_DOCKER"):
            base_host = "localhost"
        elif self.environment == Environment.DEVELOPMENT:
            import socket
            try:
                socket.gethostbyname(service)
                base_host = service
            except socket.gaierror:
                base_host = "localhost"
        else:
            base_host = service

        return f"http://{base_host}:{port}"
    
    def get_config_summary(self) -> Dict[str, Any]:
        return {
            "service_name": self.service_name,
            "environment": self.environment.value,
            "debug_mode": os.getenv("DEBUG", "false").lower() == "true",
            "log_level": os.getenv("LOG_LEVEL", "INFO"),
            "available_apis": self.validate_api_keys(),
            "cache_enabled": os.getenv("ENABLE_RESPONSE_CACHING", "true").lower() == "true",
            "metrics_enabled": os.getenv("ENABLE_METRICS", "true").lower() == "true",
        }


config = ConfigManager()


def get_config() -> ConfigManager:
    return config