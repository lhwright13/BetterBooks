"""Minimal semantic cache implementation for local development."""
import logging
import hashlib
import json
from enum import Enum
from typing import Any, Optional, Dict, List
from functools import wraps

logger = logging.getLogger(__name__)


class CacheType(Enum):
    """Cache type enumeration."""
    LLM_RESPONSE = "llm_response"
    TTS_RESPONSE = "tts_response"


class SemanticCache:
    """Basic semantic cache implementation (in-memory for local development)."""

    def __init__(self, redis_client: Any = None):
        """Initialize cache, optionally with Redis client (ignored for local dev)."""
        self._cache: Dict[str, Any] = {}
        self._stats: Dict[str, Dict[str, int]] = {
            "llm_response": {"hits": 0, "misses": 0},
            "tts_response": {"hits": 0, "misses": 0}
        }
        self._redis = redis_client  # Store but don't use for now
        logger.info("Semantic cache initialized (in-memory mode)")

    def _make_key(self, cache_type: CacheType, key_data: Dict[str, Any]) -> str:
        """Create a cache key from type and data."""
        key_str = f"{cache_type.value}:{json.dumps(key_data, sort_keys=True)}"
        return hashlib.md5(key_str.encode()).hexdigest()

    def get(self, cache_type: CacheType, key_data: Dict[str, Any], query_text: str = "") -> Optional[Any]:
        """Get value from cache."""
        key = self._make_key(cache_type, key_data)
        result = self._cache.get(key)
        if result:
            self._stats[cache_type.value]["hits"] += 1
            return result
        self._stats[cache_type.value]["misses"] += 1
        return None

    def set(self, cache_type: CacheType, key_data: Dict[str, Any], value: Any, query_text: str = "", ttl: int = 3600) -> bool:
        """Set value in cache."""
        key = self._make_key(cache_type, key_data)
        self._cache[key] = value
        logger.debug(f"Cache set: {key}")
        return True

    def get_stats(self) -> Dict[str, Dict[str, int]]:
        """Get cache statistics."""
        return self._stats

    def invalidate_pattern(self, pattern: str = "*") -> int:
        """Clear cache entries matching pattern."""
        if pattern == "*":
            count = len(self._cache)
            self._cache.clear()
            return count
        # Simple pattern matching for now
        count = 0
        keys_to_remove = [k for k in self._cache.keys() if pattern in k]
        for key in keys_to_remove:
            del self._cache[key]
            count += 1
        return count

    def warm_cache(self, cache_type: CacheType, warm_data: List[Dict[str, Any]]) -> int:
        """Warm cache with initial data."""
        count = 0
        for item in warm_data:
            key_data = item.get("key_data", {})
            content = item.get("content")
            query_text = item.get("query_text", "")
            if content:
                self.set(cache_type, key_data, content, query_text)
                count += 1
        return count


def cache_response(cache_type: CacheType, ttl: int = 3600):
    """Decorator for caching responses."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            return await func(*args, **kwargs)
        return wrapper
    return decorator
