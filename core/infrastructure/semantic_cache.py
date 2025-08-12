"""
Semantic caching system for EchoWright AI responses and embeddings.

Implements intelligent caching strategies for:
- LLM responses with semantic similarity matching
- Vector embeddings with efficient retrieval
- Frequent database queries
- Audio processing results

Features:
- Redis-backed storage with TTL management
- Semantic similarity for cache hit detection
- Configurable cache policies per content type
- Performance monitoring and statistics
- Cache warming and preloading
"""

import json
import hashlib
import time
from typing import Dict, Any, Optional, List, Tuple, Union
from datetime import datetime, timedelta
from dataclasses import dataclass, asdict
from enum import Enum
import logging
import redis
import numpy as np
from sentence_transformers import SentenceTransformer
import pickle
import zlib
from functools import wraps

# Configure logging
logger = logging.getLogger(__name__)


class CacheType(Enum):
    """Cache content types with different strategies."""
    LLM_RESPONSE = "llm_response"
    EMBEDDING = "embedding"
    DATABASE_QUERY = "db_query"
    AUDIO_PROCESSING = "audio_processing"
    CHAPTER_DETECTION = "chapter_detection"
    SUMMARY = "summary"


@dataclass
class CacheConfig:
    """Cache configuration for different content types."""
    ttl_seconds: int
    max_size_mb: float
    similarity_threshold: float = 0.85
    compression_enabled: bool = True
    warming_enabled: bool = False


@dataclass
class CacheEntry:
    """Individual cache entry with metadata."""
    key: str
    content: Any
    content_type: CacheType
    timestamp: datetime
    access_count: int
    size_bytes: int
    semantic_hash: Optional[str] = None
    similarity_score: Optional[float] = None


@dataclass
class CacheStats:
    """Cache performance statistics."""
    hits: int = 0
    misses: int = 0
    evictions: int = 0
    total_size_bytes: int = 0
    avg_response_time_ms: float = 0.0
    semantic_matches: int = 0
    
    @property
    def hit_ratio(self) -> float:
        total = self.hits + self.misses
        return self.hits / total if total > 0 else 0.0


class SemanticCache:
    """
    High-performance semantic caching system.
    
    Provides intelligent caching with semantic similarity matching,
    compression, and automatic cache warming.
    """
    
    DEFAULT_CONFIGS = {
        CacheType.LLM_RESPONSE: CacheConfig(
            ttl_seconds=3600,  # 1 hour
            max_size_mb=50.0,
            similarity_threshold=0.85,
            compression_enabled=True,
            warming_enabled=True
        ),
        CacheType.EMBEDDING: CacheConfig(
            ttl_seconds=86400,  # 24 hours
            max_size_mb=100.0,
            similarity_threshold=0.95,
            compression_enabled=True,
            warming_enabled=False
        ),
        CacheType.DATABASE_QUERY: CacheConfig(
            ttl_seconds=1800,  # 30 minutes
            max_size_mb=25.0,
            similarity_threshold=0.98,
            compression_enabled=True,
            warming_enabled=True
        ),
        CacheType.AUDIO_PROCESSING: CacheConfig(
            ttl_seconds=7200,  # 2 hours
            max_size_mb=200.0,
            similarity_threshold=0.90,
            compression_enabled=True,
            warming_enabled=False
        ),
        CacheType.CHAPTER_DETECTION: CacheConfig(
            ttl_seconds=86400,  # 24 hours
            max_size_mb=30.0,
            similarity_threshold=0.92,
            compression_enabled=True,
            warming_enabled=True
        ),
        CacheType.SUMMARY: CacheConfig(
            ttl_seconds=7200,  # 2 hours
            max_size_mb=15.0,
            similarity_threshold=0.88,
            compression_enabled=True,
            warming_enabled=True
        ),
    }
    
    def __init__(
        self,
        redis_client: redis.Redis,
        sentence_model: str = "all-MiniLM-L6-v2",
        configs: Optional[Dict[CacheType, CacheConfig]] = None
    ):
        """
        Initialize semantic cache system.
        
        Args:
            redis_client: Configured Redis client
            sentence_model: SentenceTransformers model for semantic similarity
            configs: Custom cache configurations
        """
        self.redis = redis_client
        self.configs = configs or self.DEFAULT_CONFIGS
        self.stats = {cache_type: CacheStats() for cache_type in CacheType}
        
        # Load sentence transformer for semantic similarity
        try:
            self.sentence_model = SentenceTransformer(sentence_model)
            logger.info(f"Loaded sentence transformer: {sentence_model}")
        except Exception as e:
            logger.warning(f"Failed to load sentence transformer: {e}")
            self.sentence_model = None
        
        # Cache key prefixes
        self.KEY_PREFIX = "semantic_cache"
        self.METADATA_PREFIX = "cache_meta"
        self.STATS_KEY = "cache_stats"
        self.SIMILARITY_INDEX = "similarity_index"
        
        self._initialize_cache()
    
    def _initialize_cache(self) -> None:
        """Initialize cache system and load existing statistics."""
        try:
            # Load existing stats
            stats_data = self.redis.get(self.STATS_KEY)
            if stats_data:
                saved_stats = json.loads(stats_data)
                for cache_type_str, stats_dict in saved_stats.items():
                    cache_type = CacheType(cache_type_str)
                    if cache_type in self.stats:
                        self.stats[cache_type] = CacheStats(**stats_dict)
            
            logger.info("Semantic cache initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize cache: {e}")
    
    def _generate_cache_key(
        self, 
        content_type: CacheType, 
        key_data: Union[str, Dict[str, Any]]
    ) -> str:
        """Generate standardized cache key."""
        if isinstance(key_data, dict):
            key_str = json.dumps(key_data, sort_keys=True)
        else:
            key_str = str(key_data)
        
        key_hash = hashlib.sha256(key_str.encode()).hexdigest()[:16]
        return f"{self.KEY_PREFIX}:{content_type.value}:{key_hash}"
    
    def _generate_semantic_hash(self, text: str) -> str:
        """Generate semantic hash for similarity comparison."""
        if not self.sentence_model:
            return hashlib.sha256(text.encode()).hexdigest()[:16]
        
        try:
            embedding = self.sentence_model.encode(text)
            # Use quantized embedding for hash
            quantized = (embedding * 100).astype(np.int32)
            return hashlib.sha256(quantized.tobytes()).hexdigest()[:16]
        except Exception as e:
            logger.warning(f"Failed to generate semantic hash: {e}")
            return hashlib.sha256(text.encode()).hexdigest()[:16]
    
    def _calculate_similarity(self, text1: str, text2: str) -> float:
        """Calculate semantic similarity between texts."""
        if not self.sentence_model:
            return 1.0 if text1 == text2 else 0.0
        
        try:
            embeddings = self.sentence_model.encode([text1, text2])
            similarity = np.dot(embeddings[0], embeddings[1]) / (
                np.linalg.norm(embeddings[0]) * np.linalg.norm(embeddings[1])
            )
            return float(similarity)
        except Exception as e:
            logger.warning(f"Failed to calculate similarity: {e}")
            return 1.0 if text1 == text2 else 0.0
    
    def _compress_data(self, data: bytes) -> bytes:
        """Compress data using zlib."""
        return zlib.compress(data, level=6)
    
    def _decompress_data(self, data: bytes) -> bytes:
        """Decompress data using zlib."""
        return zlib.decompress(data)
    
    def _serialize_content(self, content: Any, compress: bool = True) -> bytes:
        """Serialize content for storage."""
        serialized = pickle.dumps(content)
        if compress:
            serialized = self._compress_data(serialized)
        return serialized
    
    def _deserialize_content(self, data: bytes, compressed: bool = True) -> Any:
        """Deserialize content from storage."""
        if compressed:
            data = self._decompress_data(data)
        return pickle.loads(data)
    
    def _find_similar_entries(
        self, 
        content_type: CacheType, 
        query_text: str,
        threshold: float
    ) -> List[Tuple[str, float]]:
        """Find semantically similar cache entries."""
        if not self.sentence_model:
            return []
        
        try:
            # Get all keys for this content type
            pattern = f"{self.KEY_PREFIX}:{content_type.value}:*"
            keys = self.redis.keys(pattern)
            
            similar_entries = []
            query_embedding = self.sentence_model.encode(query_text)
            
            for key in keys[:50]:  # Limit search for performance
                try:
                    metadata_key = key.decode().replace(self.KEY_PREFIX, self.METADATA_PREFIX)
                    metadata = self.redis.get(metadata_key)
                    if not metadata:
                        continue
                    
                    meta_dict = json.loads(metadata)
                    if 'query_text' in meta_dict:
                        stored_text = meta_dict['query_text']
                        similarity = self._calculate_similarity(query_text, stored_text)
                        
                        if similarity >= threshold:
                            similar_entries.append((key.decode(), similarity))
                            
                except Exception as e:
                    logger.warning(f"Error checking similarity for {key}: {e}")
                    continue
            
            # Sort by similarity score
            similar_entries.sort(key=lambda x: x[1], reverse=True)
            return similar_entries[:5]  # Return top 5 matches
            
        except Exception as e:
            logger.error(f"Error finding similar entries: {e}")
            return []
    
    def get(
        self, 
        content_type: CacheType,
        key_data: Union[str, Dict[str, Any]],
        query_text: Optional[str] = None
    ) -> Optional[Any]:
        """
        Get cached content with semantic similarity support.
        
        Args:
            content_type: Type of cached content
            key_data: Primary key data
            query_text: Text for semantic similarity matching
            
        Returns:
            Cached content or None if not found
        """
        start_time = time.time()
        cache_key = self._generate_cache_key(content_type, key_data)
        config = self.configs.get(content_type, self.DEFAULT_CONFIGS[content_type])
        
        try:
            # Try exact key match first
            data = self.redis.get(cache_key)
            if data:
                content = self._deserialize_content(data, config.compression_enabled)
                
                # Update access statistics
                self._update_access_stats(cache_key, content_type)
                self.stats[content_type].hits += 1
                
                response_time = (time.time() - start_time) * 1000
                self._update_response_time(content_type, response_time)
                
                logger.debug(f"Cache hit for {content_type.value}: {cache_key}")
                return content
            
            # Try semantic similarity matching if query text provided
            if query_text and self.sentence_model:
                similar_entries = self._find_similar_entries(
                    content_type, 
                    query_text, 
                    config.similarity_threshold
                )
                
                if similar_entries:
                    best_key, similarity = similar_entries[0]
                    data = self.redis.get(best_key)
                    
                    if data:
                        content = self._deserialize_content(data, config.compression_enabled)
                        
                        # Update statistics
                        self._update_access_stats(best_key, content_type)
                        self.stats[content_type].semantic_matches += 1
                        self.stats[content_type].hits += 1
                        
                        logger.info(
                            f"Semantic cache hit for {content_type.value}: "
                            f"similarity={similarity:.3f}"
                        )
                        return content
            
            # Cache miss
            self.stats[content_type].misses += 1
            return None
            
        except Exception as e:
            logger.error(f"Cache get error: {e}")
            self.stats[content_type].misses += 1
            return None
    
    def set(
        self,
        content_type: CacheType,
        key_data: Union[str, Dict[str, Any]],
        content: Any,
        query_text: Optional[str] = None,
        custom_ttl: Optional[int] = None
    ) -> bool:
        """
        Store content in cache with metadata.
        
        Args:
            content_type: Type of content being cached
            key_data: Primary key data
            content: Content to cache
            query_text: Text for semantic similarity indexing
            custom_ttl: Custom TTL override
            
        Returns:
            True if successfully cached
        """
        cache_key = self._generate_cache_key(content_type, key_data)
        config = self.configs.get(content_type, self.DEFAULT_CONFIGS[content_type])
        ttl = custom_ttl or config.ttl_seconds
        
        try:
            # Serialize and optionally compress content
            serialized = self._serialize_content(content, config.compression_enabled)
            
            # Check size limits
            size_mb = len(serialized) / (1024 * 1024)
            if size_mb > config.max_size_mb:
                logger.warning(
                    f"Content too large for cache: {size_mb:.2f}MB > {config.max_size_mb}MB"
                )
                return False
            
            # Store content with TTL
            self.redis.setex(cache_key, ttl, serialized)
            
            # Store metadata for semantic search
            metadata = {
                'content_type': content_type.value,
                'timestamp': datetime.now().isoformat(),
                'size_bytes': len(serialized),
                'ttl': ttl,
            }
            
            if query_text:
                metadata['query_text'] = query_text
                metadata['semantic_hash'] = self._generate_semantic_hash(query_text)
            
            metadata_key = cache_key.replace(self.KEY_PREFIX, self.METADATA_PREFIX)
            self.redis.setex(metadata_key, ttl, json.dumps(metadata))
            
            # Update statistics
            self.stats[content_type].total_size_bytes += len(serialized)
            
            logger.debug(f"Cached {content_type.value}: {cache_key} ({size_mb:.2f}MB)")
            return True
            
        except Exception as e:
            logger.error(f"Cache set error: {e}")
            return False
    
    def _update_access_stats(self, cache_key: str, content_type: CacheType) -> None:
        """Update access statistics for cache entry."""
        try:
            metadata_key = cache_key.replace(self.KEY_PREFIX, self.METADATA_PREFIX)
            metadata = self.redis.get(metadata_key)
            
            if metadata:
                meta_dict = json.loads(metadata)
                meta_dict['access_count'] = meta_dict.get('access_count', 0) + 1
                meta_dict['last_access'] = datetime.now().isoformat()
                
                # Update with same TTL
                ttl = self.redis.ttl(cache_key)
                if ttl > 0:
                    self.redis.setex(metadata_key, ttl, json.dumps(meta_dict))
                    
        except Exception as e:
            logger.warning(f"Failed to update access stats: {e}")
    
    def _update_response_time(self, content_type: CacheType, response_time_ms: float) -> None:
        """Update average response time statistics."""
        current_avg = self.stats[content_type].avg_response_time_ms
        hits = self.stats[content_type].hits
        
        if hits <= 1:
            self.stats[content_type].avg_response_time_ms = response_time_ms
        else:
            # Exponential moving average
            alpha = 0.1
            self.stats[content_type].avg_response_time_ms = (
                alpha * response_time_ms + (1 - alpha) * current_avg
            )
    
    def invalidate_pattern(self, pattern: str) -> int:
        """Invalidate cache entries matching pattern."""
        try:
            keys = self.redis.keys(f"{self.KEY_PREFIX}:{pattern}")
            if keys:
                # Also delete metadata
                metadata_keys = [
                    key.decode().replace(self.KEY_PREFIX, self.METADATA_PREFIX) 
                    for key in keys
                ]
                
                deleted = self.redis.delete(*keys, *metadata_keys)
                logger.info(f"Invalidated {deleted//2} cache entries matching {pattern}")
                return deleted // 2
            return 0
            
        except Exception as e:
            logger.error(f"Cache invalidation error: {e}")
            return 0
    
    def clear_expired(self) -> int:
        """Remove expired cache entries and update statistics."""
        try:
            expired_count = 0
            
            for content_type in CacheType:
                pattern = f"{self.KEY_PREFIX}:{content_type.value}:*"
                keys = self.redis.keys(pattern)
                
                for key in keys:
                    ttl = self.redis.ttl(key)
                    if ttl == -2:  # Key expired
                        metadata_key = key.decode().replace(self.KEY_PREFIX, self.METADATA_PREFIX)
                        self.redis.delete(key, metadata_key)
                        expired_count += 1
                        self.stats[content_type].evictions += 1
            
            if expired_count > 0:
                logger.info(f"Cleaned up {expired_count} expired cache entries")
            
            return expired_count
            
        except Exception as e:
            logger.error(f"Cache cleanup error: {e}")
            return 0
    
    def get_stats(self, content_type: Optional[CacheType] = None) -> Dict[str, Any]:
        """Get cache performance statistics."""
        if content_type:
            return {
                content_type.value: asdict(self.stats[content_type])
            }
        
        return {
            cache_type.value: asdict(stats) 
            for cache_type, stats in self.stats.items()
        }
    
    def save_stats(self) -> None:
        """Persist cache statistics to Redis."""
        try:
            stats_data = {
                cache_type.value: asdict(stats)
                for cache_type, stats in self.stats.items()
            }
            self.redis.setex(self.STATS_KEY, 86400, json.dumps(stats_data))
        except Exception as e:
            logger.error(f"Failed to save stats: {e}")
    
    def warm_cache(self, content_type: CacheType, warm_data: List[Dict[str, Any]]) -> int:
        """Warm cache with frequently accessed data."""
        config = self.configs.get(content_type, self.DEFAULT_CONFIGS[content_type])
        
        if not config.warming_enabled:
            return 0
        
        warmed_count = 0
        
        for item in warm_data:
            try:
                key_data = item.get('key_data')
                content = item.get('content')
                query_text = item.get('query_text')
                
                if key_data and content:
                    success = self.set(content_type, key_data, content, query_text)
                    if success:
                        warmed_count += 1
                        
            except Exception as e:
                logger.warning(f"Failed to warm cache entry: {e}")
        
        logger.info(f"Warmed {warmed_count} {content_type.value} cache entries")
        return warmed_count


def cache_response(
    content_type: CacheType,
    ttl: Optional[int] = None,
    key_generator: Optional[callable] = None
):
    """
    Decorator for automatic response caching.
    
    Args:
        content_type: Type of content being cached
        ttl: Custom TTL override
        key_generator: Function to generate cache key from args
    """
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            # Get cache instance from first argument (usually self)
            cache = getattr(args[0], 'cache', None) if args else None
            if not isinstance(cache, SemanticCache):
                return await func(*args, **kwargs)
            
            # Generate cache key
            if key_generator:
                key_data = key_generator(*args, **kwargs)
            else:
                key_data = f"{func.__name__}_{hash(str(args[1:]) + str(kwargs))}"
            
            # Extract query text for semantic matching
            query_text = kwargs.get('query') or kwargs.get('text') or kwargs.get('prompt')
            
            # Try cache first
            cached_result = cache.get(content_type, key_data, query_text)
            if cached_result is not None:
                return cached_result
            
            # Execute function and cache result
            result = await func(*args, **kwargs)
            cache.set(content_type, key_data, result, query_text, ttl)
            
            return result
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            cache = getattr(args[0], 'cache', None) if args else None
            if not isinstance(cache, SemanticCache):
                return func(*args, **kwargs)
            
            if key_generator:
                key_data = key_generator(*args, **kwargs)
            else:
                key_data = f"{func.__name__}_{hash(str(args[1:]) + str(kwargs))}"
            
            query_text = kwargs.get('query') or kwargs.get('text') or kwargs.get('prompt')
            
            cached_result = cache.get(content_type, key_data, query_text)
            if cached_result is not None:
                return cached_result
            
            result = func(*args, **kwargs)
            cache.set(content_type, key_data, result, query_text, ttl)
            
            return result
        
        # Return appropriate wrapper based on function type
        import asyncio
        import inspect
        
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper
    
    return decorator


# Utility functions for common caching patterns

def create_cache_instance(redis_url: str = "redis://localhost:6379/0") -> SemanticCache:
    """Create a semantic cache instance with default configuration."""
    redis_client = redis.from_url(redis_url, decode_responses=False)
    return SemanticCache(redis_client)


def cache_llm_response(cache: SemanticCache, prompt: str, response: str) -> bool:
    """Convenience function to cache LLM responses."""
    return cache.set(CacheType.LLM_RESPONSE, {"prompt": prompt}, response, prompt)


def cache_embedding(cache: SemanticCache, text: str, embedding: np.ndarray) -> bool:
    """Convenience function to cache text embeddings."""
    return cache.set(CacheType.EMBEDDING, {"text": text}, embedding, text)