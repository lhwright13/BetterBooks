import logging
import hashlib
import json
from enum import Enum
from typing import Any, Optional, Dict, List

logger = logging.getLogger(__name__)


class CacheType(Enum):
    LLM_RESPONSE = "llm_response"
    TTS_RESPONSE = "tts_response"


class SemanticCache:

    def __init__(self, redis_client: Any = None):
        self._cache: Dict[str, Any] = {}
        self._stats: Dict[str, Dict[str, int]] = {
            "llm_response": {"hits": 0, "misses": 0},
            "tts_response": {"hits": 0, "misses": 0}
        }
        self._redis = redis_client
        logger.info("Semantic cache initialized (in-memory mode)")

    def _make_key(self, cache_type: CacheType, key_data: Dict[str, Any]) -> str:
        key_str = f"{cache_type.value}:{json.dumps(key_data, sort_keys=True)}"
        return hashlib.md5(key_str.encode()).hexdigest()

    def get(self, cache_type: CacheType, key_data: Dict[str, Any], query_text: str = "") -> Optional[Any]:
        key = self._make_key(cache_type, key_data)
        result = self._cache.get(key)
        if result:
            self._stats[cache_type.value]["hits"] += 1
            return result
        self._stats[cache_type.value]["misses"] += 1
        return None

    def set(self, cache_type: CacheType, key_data: Dict[str, Any], value: Any, query_text: str = "", ttl: int = 3600) -> bool:
        key = self._make_key(cache_type, key_data)
        self._cache[key] = value
        logger.debug(f"Cache set: {key}")
        return True

    def get_stats(self) -> Dict[str, Dict[str, int]]:
        return self._stats

    def invalidate_pattern(self, pattern: str = "*") -> int:
        if pattern == "*":
            count = len(self._cache)
            self._cache.clear()
            return count
        keys_to_remove = [k for k in self._cache if pattern in k]
        for key in keys_to_remove:
            del self._cache[key]
        return len(keys_to_remove)

    def warm_cache(self, cache_type: CacheType, warm_data: List[Dict[str, Any]]) -> int:
        count = 0
        for item in warm_data:
            content = item.get("content")
            if content:
                self.set(cache_type, item.get("key_data", {}), content, item.get("query_text", ""))
                count += 1
        return count
