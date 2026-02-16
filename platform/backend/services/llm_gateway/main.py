import os
import types
import logging
import asyncio
import json
from pathlib import Path

import httpx
import redis
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from core.infrastructure.logging_config import setup_logging, get_request_id
from core.infrastructure.logging_middleware import LoggingMiddleware
from core.infrastructure.metrics import setup_metrics

try:
    from core.infrastructure.semantic_cache import SemanticCache, CacheType
    SEMANTIC_CACHE_AVAILABLE = True
except ImportError:
    logging.getLogger(__name__).warning("Semantic cache not available")
    SemanticCache = None
    CacheType = None
    SEMANTIC_CACHE_AVAILABLE = False

try:  # pragma: no cover
    from openai import AzureOpenAI
except Exception:  # pragma: no cover
    AzureOpenAI = types.SimpleNamespace()  # type: ignore

try:  # pragma: no cover
    from .prompt_modifier import modify_prompt
except ImportError:  # pragma: no cover
    from prompt_modifier import modify_prompt

try:  # pragma: no cover
    from .config import load_config
except ImportError:  # pragma: no cover
    from config import load_config

cfg = load_config()
prompt_options = cfg.get("prompt_options", {})
base_preprompt = cfg.get("base_preprompt", "")

_app_configs = Path("/app/llm_configs")
if _app_configs.exists():
    CONFIG_DIR = _app_configs
else:
    _parents = Path(__file__).resolve().parents
    repo_root = _parents[4] if len(_parents) > 4 else _parents[-1]
    CONFIG_DIR = repo_root / "config" / "production" / "llm_configs"

USE_OLLAMA = os.getenv("USE_OLLAMA", "false").lower() == "true"
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://host.docker.internal:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2")

api_key = cfg.get("api_key", "")
azure_endpoint = cfg.get("azure_endpoint", "")
deployment_name = cfg.get("deployment_name", "")
api_version = cfg.get("api_version", "2024-12-01-preview")

if not USE_OLLAMA:
    if not api_key.strip():
        raise ValueError("Valid AZURE_OPENAI_API_KEY environment variable is required (or set USE_OLLAMA=true)")
    if not azure_endpoint.strip():
        raise ValueError("Valid AZURE_OPENAI_ENDPOINT environment variable is required (or set USE_OLLAMA=true)")

logger = setup_logging(
    service_name="llm_gateway",
    log_level=os.getenv("LOG_LEVEL", "INFO")
)

client = None
model_name = cfg.get("model", "gpt-4o-mini")
gen_config_defaults = cfg.get("generation_config", {})

if USE_OLLAMA:
    logger.info(f"Using Ollama for LLM completions (url={OLLAMA_URL}, model={OLLAMA_MODEL})")
else:
    logger.info(f"Configuring Azure OpenAI Gateway (endpoint={azure_endpoint}, deployment={deployment_name}, api_version={api_version})")
    client = AzureOpenAI(
        api_key=api_key,
        api_version=api_version,
        azure_endpoint=azure_endpoint
    )

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080", "http://127.0.0.1:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(LoggingMiddleware, logger=logger)

metrics_collector = setup_metrics(app, "llm_gateway")

semantic_cache = None
if SEMANTIC_CACHE_AVAILABLE:
    redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")
    try:
        redis_client = redis.from_url(redis_url, decode_responses=False)
        redis_client.ping()
        semantic_cache = SemanticCache(redis_client)
        logger.info(f"Semantic cache initialized (redis_url={redis_url})")
    except Exception as e:
        logger.warning(f"Failed to initialize semantic cache (Redis may not be available): {e}")
        semantic_cache = None

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

SSE_HEADERS = {
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
    "X-Accel-Buffering": "no",
}


def _resolve_azure_client(cfg_local: dict):
    local_api_key = cfg_local.get("api_key", api_key)
    local_endpoint = cfg_local.get("azure_endpoint", azure_endpoint)
    local_deployment = cfg_local.get("deployment_name", deployment_name)
    local_api_version = cfg_local.get("api_version", api_version)

    if not local_api_key.strip():
        raise HTTPException(status_code=500, detail="Valid API key is required")
    if not local_endpoint.strip():
        raise HTTPException(status_code=500, detail="Valid Azure endpoint is required")

    local_client = client
    if (local_api_key != api_key or
        local_endpoint != azure_endpoint or
        local_api_version != api_version):
        local_client = AzureOpenAI(
            api_key=local_api_key,
            api_version=local_api_version,
            azure_endpoint=local_endpoint
        )

    return local_client, local_deployment or deployment_name


def _load_request_config(config_name: str | None) -> dict:
    if not config_name:
        model_selection_counter.labels(config_name="default").inc()
        return cfg

    cfg_path = CONFIG_DIR / f"{config_name}.json"
    if not cfg_path.exists():
        raise HTTPException(status_code=400, detail="Unknown config")

    model_selection_counter.labels(config_name=config_name).inc()
    return load_config(cfg_path)


def _cache_response(prompt: str, req_prompt: str, max_tokens: int,
                    config_name: str | None, model: str, response_data: dict):
    if not semantic_cache or not SEMANTIC_CACHE_AVAILABLE:
        return

    cache_key = {
        "prompt": prompt,
        "max_tokens": max_tokens,
        "config": config_name or "default",
        "model": model,
    }

    success = semantic_cache.set(
        CacheType.LLM_RESPONSE, cache_key, response_data, query_text=req_prompt
    )
    if success:
        cache_performance_counter.labels(operation="set", result="success").inc()
        logger.debug(f"Cached LLM response (config={config_name})")
    else:
        cache_performance_counter.labels(operation="set", result="failure").inc()
        logger.warning(f"Failed to cache LLM response (config={config_name})")


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "llm_provider": "ollama" if USE_OLLAMA else "azure_openai",
        "model": OLLAMA_MODEL if USE_OLLAMA else deployment_name,
    }


def complete_with_ollama(prompt: str, max_tokens: int = 4000) -> str:
    try:
        with httpx.Client(timeout=120.0) as http_client:
            response = http_client.post(
                f"{OLLAMA_URL}/api/generate",
                json={
                    "model": OLLAMA_MODEL,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "num_predict": max_tokens,
                        "temperature": 0.7,
                    }
                }
            )
            response.raise_for_status()
            return response.json().get("response", "")
    except httpx.ConnectError as e:
        logger.error(f"Ollama connection failed: {e} (ollama_url={OLLAMA_URL})")
        raise HTTPException(
            status_code=503,
            detail=f"Ollama service not available at {OLLAMA_URL}. Is Ollama running?"
        )
    except httpx.TimeoutException as e:
        logger.error(f"Ollama request timed out: {e}")
        raise HTTPException(status_code=504, detail="Ollama request timed out")
    except Exception as e:
        logger.error(f"Ollama completion failed: {e}")
        raise HTTPException(status_code=502, detail=f"Ollama error: {e}")


class CompletionRequest(BaseModel):
    prompt: str
    max_tokens: int = 4000
    config: str | None = None


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    max_tokens: int = 1000
    temperature: float | None = None
    config: str | None = None
    stream: bool = False


@app.post("/complete")
def complete(req: CompletionRequest) -> dict:
    prompt_length_histogram.observe(len(req.prompt))

    cfg_local = _load_request_config(req.config)

    local_prompt_options = cfg_local.get("prompt_options", {})
    local_base_preprompt = cfg_local.get("base_preprompt", "")

    prompt = modify_prompt(req.prompt, local_prompt_options)
    if local_base_preprompt:
        prompt = f"{local_base_preprompt}\n\n{prompt}"

    if semantic_cache and SEMANTIC_CACHE_AVAILABLE:
        cache_key = {
            "prompt": prompt,
            "max_tokens": req.max_tokens,
            "config": req.config or "default",
            "model": OLLAMA_MODEL if USE_OLLAMA else cfg_local.get("model", model_name),
        }

        cached_response = semantic_cache.get(
            CacheType.LLM_RESPONSE, cache_key, query_text=req.prompt
        )

        if cached_response:
            cache_performance_counter.labels(operation="get", result="hit").inc()
            logger.debug(f"Cache hit for LLM completion (config={req.config})")
            return cached_response

        cache_performance_counter.labels(operation="get", result="miss").inc()

    if USE_OLLAMA:
        logger.debug(f"Using Ollama for completion (model={OLLAMA_MODEL}, prompt_length={len(prompt)})")
        response_data = {"text": complete_with_ollama(prompt, req.max_tokens).strip()}
        _cache_response(prompt, req.prompt, req.max_tokens, req.config, OLLAMA_MODEL, response_data)
        return response_data

    try:
        local_client, local_deployment = _resolve_azure_client(cfg_local)
        gen_config_local = cfg_local.get("generation_config", {})

        openai_params = {
            "model": local_deployment,
            "max_tokens": req.max_tokens,
            "temperature": gen_config_local.get("temperature", 0.7),
        }

        for param in ("top_p", "frequency_penalty", "presence_penalty"):
            if param in gen_config_local:
                openai_params[param] = gen_config_local[param]

        logger.debug(f"Generating completion (prompt_length={len(prompt)}, config={req.config})")

        response = local_client.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            **openai_params
        )

    except Exception as exc:  # pragma: no cover
        logger.error(f"Azure OpenAI generation failed: error={exc}, config={req.config}, request_id={get_request_id()}")
        raise HTTPException(status_code=502, detail=str(exc))

    if not response.choices or not response.choices[0].message or not response.choices[0].message.content:
        raise HTTPException(status_code=502, detail="Invalid response from Azure OpenAI")

    response_data = {"text": response.choices[0].message.content.strip()}
    _cache_response(prompt, req.prompt, req.max_tokens, req.config, cfg_local["model"], response_data)
    return response_data


def format_messages_for_ollama(messages: list[dict]) -> str:
    parts = []
    for msg in messages:
        role = msg["role"]
        content = msg["content"]
        if role == "system":
            parts.append(f"System: {content}")
        elif role == "user":
            parts.append(f"User: {content}")
        elif role == "assistant":
            parts.append(f"Assistant: {content}")
    parts.append("Assistant:")
    return "\n\n".join(parts)


async def stream_ollama_response(formatted_prompt: str, max_tokens: int, temperature: float):
    try:
        async with httpx.AsyncClient(timeout=120.0) as http_client:
            async with http_client.stream(
                "POST",
                f"{OLLAMA_URL}/api/generate",
                json={
                    "model": OLLAMA_MODEL,
                    "prompt": formatted_prompt,
                    "stream": True,
                    "options": {
                        "num_predict": max_tokens,
                        "temperature": temperature,
                    }
                }
            ) as response:
                response.raise_for_status()
                async for line in response.aiter_lines():
                    if not line:
                        continue
                    try:
                        chunk_data = json.loads(line)
                        token = chunk_data.get("response", "")
                        if token:
                            yield f"data: {json.dumps({'content': token, 'done': False})}\n\n"
                        if chunk_data.get("done", False):
                            yield f"data: {json.dumps({'content': '', 'done': True})}\n\n"
                    except json.JSONDecodeError:
                        continue
    except httpx.ConnectError as e:
        logger.error(f"Ollama streaming connection failed: {e}")
        yield f"data: {json.dumps({'error': f'Ollama service not available at {OLLAMA_URL}'})}\n\n"
    except Exception as e:
        logger.error(f"Ollama streaming failed: {e}")
        yield f"data: {json.dumps({'error': str(e)})}\n\n"


async def stream_azure_response(local_client, local_deployment: str, messages: list[dict],
                                 max_tokens: int, temperature: float):
    try:
        response = local_client.chat.completions.create(
            model=local_deployment,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
            stream=True
        )

        for chunk in response:
            if chunk.choices and len(chunk.choices) > 0:
                delta = chunk.choices[0].delta
                if delta and delta.content:
                    yield f"data: {json.dumps({'content': delta.content, 'done': False})}\n\n"
                if chunk.choices[0].finish_reason:
                    yield f"data: {json.dumps({'content': '', 'done': True})}\n\n"
            await asyncio.sleep(0)
    except Exception as e:
        logger.error(f"Azure OpenAI streaming failed: {e}")
        yield f"data: {json.dumps({'error': str(e)})}\n\n"


@app.post("/chat")
async def chat(req: ChatRequest):
    total_content_length = sum(len(m.content) for m in req.messages)
    prompt_length_histogram.observe(total_content_length)

    cfg_local = cfg
    if req.config:
        cfg_path = CONFIG_DIR / f"{req.config}.json"
        if cfg_path.exists():
            cfg_local = load_config(cfg_path)
            model_selection_counter.labels(config_name=req.config).inc()
        else:
            model_selection_counter.labels(config_name="default").inc()
    else:
        model_selection_counter.labels(config_name="default").inc()

    messages = [{"role": m.role, "content": m.content} for m in req.messages]

    temperature = req.temperature
    if temperature is None:
        gen_config = cfg_local.get("generation_config", {})
        temperature = gen_config.get("temperature", 0.7)

    if req.stream:
        if USE_OLLAMA:
            logger.debug(f"Streaming Ollama chat (model={OLLAMA_MODEL}, messages={len(messages)})")
            formatted_prompt = format_messages_for_ollama(messages)
            return StreamingResponse(
                stream_ollama_response(formatted_prompt, req.max_tokens, temperature),
                media_type="text/event-stream",
                headers=SSE_HEADERS,
            )

        local_client, local_deployment = _resolve_azure_client(cfg_local)
        logger.debug(f"Streaming Azure OpenAI chat (messages={len(messages)}, temperature={temperature})")
        return StreamingResponse(
            stream_azure_response(local_client, local_deployment, messages, req.max_tokens, temperature),
            media_type="text/event-stream",
            headers=SSE_HEADERS,
        )

    if USE_OLLAMA:
        logger.debug(f"Using Ollama for chat (model={OLLAMA_MODEL}, messages={len(messages)})")
        formatted_prompt = format_messages_for_ollama(messages)

        try:
            async with httpx.AsyncClient(timeout=120.0) as http_client:
                response = await http_client.post(
                    f"{OLLAMA_URL}/api/generate",
                    json={
                        "model": OLLAMA_MODEL,
                        "prompt": formatted_prompt,
                        "stream": False,
                        "options": {
                            "num_predict": req.max_tokens,
                            "temperature": temperature,
                        }
                    }
                )
                response.raise_for_status()
                result = response.json()
                response_text = result.get("response", "").strip()

                return {
                    "content": response_text,
                    "model": OLLAMA_MODEL,
                    "usage": {
                        "prompt_tokens": len(formatted_prompt.split()),
                        "completion_tokens": len(response_text.split()),
                    }
                }
        except httpx.ConnectError as e:
            logger.error(f"Ollama connection failed: {e}")
            raise HTTPException(status_code=503, detail=f"Ollama service not available at {OLLAMA_URL}")
        except Exception as e:
            logger.error(f"Ollama chat failed: {e}")
            raise HTTPException(status_code=502, detail=f"Ollama error: {e}")

    try:
        local_client, local_deployment = _resolve_azure_client(cfg_local)

        logger.debug(f"Azure OpenAI chat (messages={len(messages)}, temperature={temperature})")

        response = local_client.chat.completions.create(
            model=local_deployment,
            messages=messages,
            max_tokens=req.max_tokens,
            temperature=temperature,
        )

        if not response.choices or not response.choices[0].message:
            raise HTTPException(status_code=502, detail="Invalid response from Azure OpenAI")

        return {
            "content": response.choices[0].message.content.strip(),
            "model": local_deployment,
            "usage": {
                "prompt_tokens": response.usage.prompt_tokens if response.usage else 0,
                "completion_tokens": response.usage.completion_tokens if response.usage else 0,
            }
        }

    except Exception as exc:
        logger.error(f"Azure OpenAI chat failed: {exc}")
        raise HTTPException(status_code=502, detail=str(exc))


@app.get("/configs")
def list_configs() -> dict:
    configs = []
    if CONFIG_DIR.exists():
        configs = [p.stem for p in CONFIG_DIR.glob("*.json")]
    return {"configs": configs}


@app.get("/cache/stats")
def get_cache_stats() -> dict:
    if not SEMANTIC_CACHE_AVAILABLE or not semantic_cache:
        return {
            "cache_enabled": False,
            "error": "Semantic cache not available",
            "reason": "Missing dependencies or Redis connection",
        }

    stats = semantic_cache.get_stats()
    return {
        "cache_enabled": True,
        "statistics": stats,
        "total_entries": sum(
            stat_data.get("hits", 0) + stat_data.get("misses", 0)
            for stat_data in stats.values()
        ),
    }


@app.post("/cache/clear")
def clear_cache(pattern: str = "*") -> dict:
    if not SEMANTIC_CACHE_AVAILABLE or not semantic_cache:
        return {"error": "Cache not available"}

    try:
        cleared_count = semantic_cache.invalidate_pattern(pattern)
        logger.info(f"Cleared {cleared_count} cache entries (pattern={pattern})")
        return {
            "success": True,
            "cleared_entries": cleared_count,
            "pattern": pattern,
        }
    except Exception as e:
        logger.error(f"Failed to clear cache: {e}")
        return {"error": str(e)}


@app.post("/cache/warm")
def warm_cache() -> dict:
    if not SEMANTIC_CACHE_AVAILABLE or not semantic_cache:
        return {"error": "Cache not available"}

    warm_data = [
        {
            "key_data": {"prompt": "What is this chapter about?", "config": "default"},
            "content": {"text": "This chapter discusses..."},
            "query_text": "What is this chapter about?",
        },
        {
            "key_data": {"prompt": "Summarize this section", "config": "default"},
            "content": {"text": "The section covers..."},
            "query_text": "Summarize this section",
        },
        {
            "key_data": {"prompt": "Who are the main characters?", "config": "default"},
            "content": {"text": "The main characters include..."},
            "query_text": "Who are the main characters?",
        },
    ]

    try:
        warmed_count = semantic_cache.warm_cache(CacheType.LLM_RESPONSE, warm_data)
        logger.info(f"Warmed {warmed_count} cache entries")
        return {
            "success": True,
            "warmed_entries": warmed_count,
        }
    except Exception as e:
        logger.error(f"Failed to warm cache: {e}")
        return {"error": str(e)}
