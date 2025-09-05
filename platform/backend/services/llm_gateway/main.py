"""Tiny wrapper around the Azure OpenAI API used for text generation."""

import os
import sys
import types
import logging
from pathlib import Path
import redis

# Import core components
from core.infrastructure.logging_config import setup_logging, get_request_id
from core.infrastructure.logging_middleware import LoggingMiddleware
from core.infrastructure.metrics import setup_metrics, llm_tokens_used

# Try to import semantic cache, fallback gracefully if not available
try:
    from core.infrastructure.semantic_cache import SemanticCache, CacheType, cache_response
    SEMANTIC_CACHE_AVAILABLE = True
except ImportError as e:
    logger_temp = logging.getLogger(__name__)
    logger_temp.warning(f"Semantic cache not available: {e}")
    SemanticCache = None
    CacheType = None
    SEMANTIC_CACHE_AVAILABLE = False

try:  # pragma: no cover - library may not be installed during tests
    from openai import AzureOpenAI
except Exception:  # pragma: no cover - the library may be stubbed in tests
    AzureOpenAI = types.SimpleNamespace()  # type: ignore
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Import the prompt modification helper. When the service runs inside Docker the
# ``main.py`` file is executed directly (``uvicorn main:app``). In that case the
# module is executed as a script and relative imports fail. Fall back to
# absolute imports so local tests keep working.
try:  # pragma: no cover - import tested implicitly
    from .prompt_modifier import modify_prompt
except ImportError:  # pragma: no cover - running as a script
    from prompt_modifier import modify_prompt

try:  # pragma: no cover - import tested implicitly
    from .config import load_config
except ImportError:  # pragma: no cover - running as a script
    from config import load_config

cfg = load_config()
prompt_options = cfg.get("prompt_options", {})
base_preprompt = cfg.get("base_preprompt", "")

# Directory containing additional LLM configuration JSON files. When the service
# is packaged into a Docker image, the configs are mounted at /app/llm_configs.
# Try the mounted path first, then fall back to repository structure.
_app_configs = Path("/app/llm_configs")
if _app_configs.exists():
    CONFIG_DIR = _app_configs
else:
    _parents = Path(__file__).resolve().parents
    # Navigate to repository root then to config/production/llm_configs
    repo_root = _parents[4] if len(_parents) > 4 else _parents[-1]
    CONFIG_DIR = repo_root / "config" / "production" / "llm_configs"

# Validate Azure OpenAI configuration
api_key = cfg["api_key"]
azure_endpoint = cfg["azure_endpoint"]
deployment_name = cfg["deployment_name"]
api_version = cfg["api_version"]

if not api_key or api_key.strip() == "":
    raise ValueError("Valid AZURE_OPENAI_API_KEY environment variable is required")
if not azure_endpoint or azure_endpoint.strip() == "":
    raise ValueError("Valid AZURE_OPENAI_ENDPOINT environment variable is required")

# Set up structured logging
logger = setup_logging(
    service_name="llm_gateway",
    log_level=os.getenv("LOG_LEVEL", "INFO")
)

logger.info(f"Configuring Azure OpenAI Gateway with endpoint", 
           endpoint=azure_endpoint, 
           deployment=deployment_name,
           api_version=api_version)

# Initialize Azure OpenAI client
client = AzureOpenAI(
    api_key=api_key,
    api_version=api_version,
    azure_endpoint=azure_endpoint
)
model_name = cfg["model"]
gen_config_defaults = cfg.get("generation_config", {})

# FastAPI application instance
app = FastAPI()

# Add CORS middleware for web app access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8080"],  # Web app origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add logging middleware
app.add_middleware(LoggingMiddleware, logger=logger)

# Set up Prometheus metrics
metrics_collector = setup_metrics(app, "llm_gateway")

# Set up semantic cache
semantic_cache = None
if SEMANTIC_CACHE_AVAILABLE:
    redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
    try:
        redis_client = redis.from_url(redis_url, decode_responses=False)
        # Test Redis connection first
        redis_client.ping()
        semantic_cache = SemanticCache(redis_client)
        logger.info("Semantic cache initialized", redis_url=redis_url)
    except Exception as e:
        logger.warning(f"Failed to initialize semantic cache (Redis may not be available): {e}")
        semantic_cache = None

# Custom metrics for LLM Gateway
model_selection_counter = metrics_collector.create_counter(
    "model_selections_total",
    "Total model selections by configuration",
    ["config_name"]
)

prompt_length_histogram = metrics_collector.create_histogram(
    "prompt_length_chars",
    "Prompt length in characters",
    buckets=(10, 50, 100, 500, 1000, 5000, 10000)
)

cache_performance_counter = metrics_collector.create_counter(
    "cache_operations_total",
    "Total cache operations",
    ["operation", "result"]
)

@app.get("/health")
def health() -> dict:
    """Endpoint used to confirm the service is running."""
    return {"status": "ok"}


class CompletionRequest(BaseModel):
    """Schema for completion requests."""

    prompt: str
    max_tokens: int = 4000
    config: str | None = None


@app.post("/complete")
def complete(req: CompletionRequest) -> dict:
    """Call Azure OpenAI to generate a text completion with semantic caching."""
    
    # Track prompt length
    prompt_length_histogram.observe(len(req.prompt))

    # Load configuration based on the optional `config` parameter. Defaults
    # to the main configuration loaded at startup.
    cfg_local = cfg
    if req.config:
        cfg_path = CONFIG_DIR / f"{req.config}.json"
        if not cfg_path.exists():
            raise HTTPException(status_code=400, detail="Unknown config")
        cfg_local = load_config(cfg_path)
        # Track config usage
        model_selection_counter.labels(config_name=req.config).inc()
    else:
        model_selection_counter.labels(config_name="default").inc()

    local_prompt_options = cfg_local.get("prompt_options", {})
    local_base_preprompt = cfg_local.get("base_preprompt", "")

    prompt = modify_prompt(req.prompt, local_prompt_options)
    if local_base_preprompt:
        prompt = f"{local_base_preprompt}\n\n{prompt}"
    
    # Try semantic cache first
    if semantic_cache and SEMANTIC_CACHE_AVAILABLE:
        cache_key = {
            "prompt": prompt,
            "max_tokens": req.max_tokens,
            "config": req.config or "default",
            "model": cfg_local["model"]
        }
        
        cached_response = semantic_cache.get(
            CacheType.LLM_RESPONSE,
            cache_key,
            query_text=req.prompt
        )
        
        if cached_response:
            cache_performance_counter.labels(operation="get", result="hit").inc()
            logger.debug("Cache hit for LLM completion", config=req.config)
            return cached_response
        
        cache_performance_counter.labels(operation="get", result="miss").inc()
    
    try:
        # Validate local Azure OpenAI configuration
        local_api_key = cfg_local.get("api_key", "")
        local_endpoint = cfg_local.get("azure_endpoint", "")
        local_deployment = cfg_local.get("deployment_name", "")
        local_api_version = cfg_local.get("api_version", "")
        
        if not local_api_key or local_api_key.strip() == "":
            raise ValueError("Valid API key is required for this configuration")
        if not local_endpoint or local_endpoint.strip() == "":
            raise ValueError("Valid Azure endpoint is required for this configuration")
        
        # Create local client for this request if different from global
        local_client = client
        if (local_api_key != api_key or 
            local_endpoint != azure_endpoint or 
            local_api_version != api_version):
            local_client = AzureOpenAI(
                api_key=local_api_key,
                api_version=local_api_version,
                azure_endpoint=local_endpoint
            )
        
        gen_config_defaults_local = cfg_local.get("generation_config", {})
        
        # Map configuration to OpenAI parameters
        openai_params = {
            "model": local_deployment or deployment_name,
            "max_tokens": req.max_tokens,
            "temperature": gen_config_defaults_local.get("temperature", 0.7),
        }
        
        # Add optional parameters if present
        if "top_p" in gen_config_defaults_local:
            openai_params["top_p"] = gen_config_defaults_local["top_p"]
        if "frequency_penalty" in gen_config_defaults_local:
            openai_params["frequency_penalty"] = gen_config_defaults_local["frequency_penalty"]
        if "presence_penalty" in gen_config_defaults_local:
            openai_params["presence_penalty"] = gen_config_defaults_local["presence_penalty"]
        
        logger.debug("Generating completion", prompt_length=len(prompt), config=req.config)
        
        # Create messages array for OpenAI chat completion
        messages = [
            {"role": "user", "content": prompt}
        ]
        
        # Call Azure OpenAI
        response = local_client.chat.completions.create(
            messages=messages,
            **openai_params
        )
        
    except Exception as exc:  # pragma: no cover - requires actual API call
        logger.error(
            "Azure OpenAI generation failed",
            error=str(exc),
            config=req.config,
            request_id=get_request_id()
        )
        raise HTTPException(status_code=502, detail=str(exc))

    # Validate response structure
    if not response.choices or not response.choices[0].message or not response.choices[0].message.content:
        raise HTTPException(status_code=502, detail="Invalid response from Azure OpenAI")
    
    response_data = {"text": response.choices[0].message.content.strip()}
    
    # Cache the response for future use
    if semantic_cache and SEMANTIC_CACHE_AVAILABLE:
        cache_key = {
            "prompt": prompt,
            "max_tokens": req.max_tokens,
            "config": req.config or "default",
            "model": cfg_local["model"]
        }
        
        cache_success = semantic_cache.set(
            CacheType.LLM_RESPONSE,
            cache_key,
            response_data,
            query_text=req.prompt
        )
        
        if cache_success:
            cache_performance_counter.labels(operation="set", result="success").inc()
            logger.debug("Cached LLM response", config=req.config)
        else:
            cache_performance_counter.labels(operation="set", result="failure").inc()
            logger.warning("Failed to cache LLM response", config=req.config)
    
    return response_data


@app.get("/configs")
def list_configs() -> dict:
    """Return available configuration names found in ``llm_configs``."""

    configs = []
    if CONFIG_DIR.exists():
        configs = [p.stem for p in CONFIG_DIR.glob("*.json")]
    return {"configs": configs}


@app.get("/cache/stats")
def get_cache_stats() -> dict:
    """Get semantic cache performance statistics."""
    if not SEMANTIC_CACHE_AVAILABLE or not semantic_cache:
        return {
            "cache_enabled": False,
            "error": "Semantic cache not available",
            "reason": "Missing dependencies or Redis connection"
        }
    
    stats = semantic_cache.get_stats()
    return {
        "cache_enabled": True,
        "statistics": stats,
        "total_entries": sum(
            stat_data.get("hits", 0) + stat_data.get("misses", 0) 
            for stat_data in stats.values()
        )
    }


@app.post("/cache/clear")
def clear_cache(pattern: str = "*") -> dict:
    """Clear cache entries matching pattern."""
    if not SEMANTIC_CACHE_AVAILABLE or not semantic_cache:
        return {"error": "Cache not available"}
    
    try:
        cleared_count = semantic_cache.invalidate_pattern(pattern)
        logger.info(f"Cleared {cleared_count} cache entries", pattern=pattern)
        return {
            "success": True,
            "cleared_entries": cleared_count,
            "pattern": pattern
        }
    except Exception as e:
        logger.error(f"Failed to clear cache: {e}")
        return {"error": str(e)}


@app.post("/cache/warm")
def warm_cache() -> dict:
    """Warm cache with common prompts."""
    if not SEMANTIC_CACHE_AVAILABLE or not semantic_cache:
        return {"error": "Cache not available"}
    
    # Common prompts for warming
    warm_data = [
        {
            "key_data": {"prompt": "What is this chapter about?", "config": "default"},
            "content": {"text": "This chapter discusses..."},
            "query_text": "What is this chapter about?"
        },
        {
            "key_data": {"prompt": "Summarize this section", "config": "default"},
            "content": {"text": "The section covers..."},
            "query_text": "Summarize this section"
        },
        {
            "key_data": {"prompt": "Who are the main characters?", "config": "default"},
            "content": {"text": "The main characters include..."},
            "query_text": "Who are the main characters?"
        }
    ]
    
    try:
        warmed_count = semantic_cache.warm_cache(CacheType.LLM_RESPONSE, warm_data)
        logger.info(f"Warmed {warmed_count} cache entries")
        return {
            "success": True,
            "warmed_entries": warmed_count
        }
    except Exception as e:
        logger.error(f"Failed to warm cache: {e}")
        return {"error": str(e)}

