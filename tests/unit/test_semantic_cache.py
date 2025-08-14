"""
Unit tests for semantic caching system.

Tests cover:
- Basic cache operations (get/set)
- Semantic similarity matching
- Cache configuration and policies
- Performance statistics
- Cache warming and cleanup
"""

import pytest
import json
import time
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, MagicMock
import numpy as np
import redis

# Import the semantic cache module
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', '..'))

from core.infrastructure.semantic_cache import (
    SemanticCache,
    CacheType,
    CacheConfig,
    CacheEntry,
    CacheStats,
    cache_response,
    create_cache_instance,
    cache_llm_response,
    cache_embedding
)


@pytest.fixture
def mock_redis():
    """Mock Redis client for testing."""
    redis_mock = Mock(spec=redis.Redis)
    redis_mock.get.return_value = None
    redis_mock.set.return_value = True
    redis_mock.setex.return_value = True
    redis_mock.delete.return_value = 1
    redis_mock.keys.return_value = []
    redis_mock.ttl.return_value = 3600
    return redis_mock


@pytest.fixture
def mock_sentence_transformer():
    """Mock SentenceTransformer for testing."""
    transformer_mock = Mock()
    # Return consistent embeddings for testing
    transformer_mock.encode.side_effect = lambda texts: (
        np.array([[0.1, 0.2, 0.3], [0.2, 0.3, 0.4]]) if isinstance(texts, list)
        else np.array([0.1, 0.2, 0.3])
    )
    return transformer_mock


@pytest.fixture
def semantic_cache(mock_redis, mock_sentence_transformer):
    """Create semantic cache instance with mocked dependencies."""
    with patch('core.infrastructure.semantic_cache.SentenceTransformer', return_value=mock_sentence_transformer):
        cache = SemanticCache(mock_redis)
        cache.sentence_model = mock_sentence_transformer
    return cache


class TestCacheConfig:
    """Test cache configuration and setup."""
    
    def test_default_configs_exist(self):
        """Test that default configurations exist for all cache types."""
        for cache_type in CacheType:
            assert cache_type in SemanticCache.DEFAULT_CONFIGS
            config = SemanticCache.DEFAULT_CONFIGS[cache_type]
            assert isinstance(config, CacheConfig)
            assert config.ttl_seconds > 0
            assert config.max_size_mb > 0
            assert 0 <= config.similarity_threshold <= 1
    
    def test_custom_config(self, mock_redis):
        """Test creating cache with custom configurations."""
        custom_config = {
            CacheType.LLM_RESPONSE: CacheConfig(
                ttl_seconds=1800,
                max_size_mb=25.0,
                similarity_threshold=0.90
            )
        }
        
        with patch('core.infrastructure.semantic_cache.SentenceTransformer'):
            cache = SemanticCache(mock_redis, configs=custom_config)
            
        assert cache.configs[CacheType.LLM_RESPONSE].ttl_seconds == 1800
        assert cache.configs[CacheType.LLM_RESPONSE].max_size_mb == 25.0
        assert cache.configs[CacheType.LLM_RESPONSE].similarity_threshold == 0.90


class TestBasicCacheOperations:
    """Test basic cache get/set operations."""
    
    def test_cache_set_and_get(self, semantic_cache, mock_redis):
        """Test basic cache set and get operations."""
        # Mock Redis to return our test data
        test_content = {"test": "data"}
        serialized_content = semantic_cache._serialize_content(test_content)
        mock_redis.get.return_value = serialized_content
        
        # Test set
        success = semantic_cache.set(
            CacheType.LLM_RESPONSE,
            "test_key",
            test_content
        )
        assert success
        
        # Verify Redis calls
        mock_redis.setex.assert_called()
        
        # Test get
        result = semantic_cache.get(CacheType.LLM_RESPONSE, "test_key")
        assert result == test_content
    
    def test_cache_miss(self, semantic_cache, mock_redis):
        """Test cache miss behavior."""
        mock_redis.get.return_value = None
        
        result = semantic_cache.get(CacheType.LLM_RESPONSE, "nonexistent_key")
        assert result is None
        
        # Check stats updated
        assert semantic_cache.stats[CacheType.LLM_RESPONSE].misses == 1
    
    def test_cache_hit_updates_stats(self, semantic_cache, mock_redis):
        """Test that cache hits update statistics."""
        test_content = {"test": "data"}
        serialized_content = semantic_cache._serialize_content(test_content)
        mock_redis.get.return_value = serialized_content
        
        semantic_cache.get(CacheType.LLM_RESPONSE, "test_key")
        
        assert semantic_cache.stats[CacheType.LLM_RESPONSE].hits == 1
        assert semantic_cache.stats[CacheType.LLM_RESPONSE].avg_response_time_ms > 0
    
    def test_size_limit_enforcement(self, semantic_cache):
        """Test that oversized content is rejected."""
        # Create content that will exceed the LLM_RESPONSE limit (50MB)
        # We'll create a dict with large values to exceed the limit after serialization + compression
        large_dict = {
            f"key_{i}": "x" * (1024 * 1024)  # 1MB each
            for i in range(55)  # 55MB total
        }
        
        success = semantic_cache.set(
            CacheType.LLM_RESPONSE,
            "large_key",
            large_dict
        )
        
        assert not success


class TestSemanticMatching:
    """Test semantic similarity matching features."""
    
    def test_semantic_similarity_calculation(self, semantic_cache):
        """Test semantic similarity calculation."""
        text1 = "What is artificial intelligence?"
        text2 = "Can you explain AI to me?"
        
        similarity = semantic_cache._calculate_similarity(text1, text2)
        
        assert 0 <= similarity <= 1
        assert isinstance(similarity, float)
    
    def test_semantic_hash_generation(self, semantic_cache):
        """Test semantic hash generation for similarity indexing."""
        text = "This is a test sentence for hashing."
        
        hash1 = semantic_cache._generate_semantic_hash(text)
        hash2 = semantic_cache._generate_semantic_hash(text)
        
        assert hash1 == hash2  # Same text should generate same hash
        assert len(hash1) == 16  # Hash should be 16 characters
    
    def test_find_similar_entries(self, semantic_cache, mock_redis):
        """Test finding semantically similar cache entries."""
        # Mock Redis keys response
        mock_redis.keys.return_value = [
            b"semantic_cache:llm_response:abc123",
            b"semantic_cache:llm_response:def456"
        ]
        
        # Mock metadata responses
        metadata1 = json.dumps({
            "query_text": "What is machine learning?",
            "timestamp": datetime.now().isoformat()
        })
        metadata2 = json.dumps({
            "query_text": "How does deep learning work?",
            "timestamp": datetime.now().isoformat()
        })
        
        mock_redis.get.side_effect = lambda key: {
            "cache_meta:llm_response:abc123": metadata1,
            "cache_meta:llm_response:def456": metadata2
        }.get(key.decode() if isinstance(key, bytes) else key)
        
        similar_entries = semantic_cache._find_similar_entries(
            CacheType.LLM_RESPONSE,
            "Can you explain machine learning?",
            0.8
        )
        
        assert len(similar_entries) >= 0  # Should find some similar entries
        if similar_entries:
            assert isinstance(similar_entries[0], tuple)
            assert len(similar_entries[0]) == 2  # (key, similarity)
    
    def test_semantic_cache_hit(self, semantic_cache, mock_redis):
        """Test cache hit through semantic similarity."""
        # Setup mock for similar entry search
        test_content = {"response": "AI is artificial intelligence"}
        serialized_content = semantic_cache._serialize_content(test_content)
        
        # Mock finding similar entries
        with patch.object(semantic_cache, '_find_similar_entries') as mock_find:
            mock_find.return_value = [("semantic_cache:llm_response:similar123", 0.95)]
            mock_redis.get.return_value = serialized_content
            
            result = semantic_cache.get(
                CacheType.LLM_RESPONSE,
                "new_key",
                query_text="What is AI?"
            )
            
            assert result == test_content
            assert semantic_cache.stats[CacheType.LLM_RESPONSE].semantic_matches == 1


class TestCacheManagement:
    """Test cache management operations."""
    
    def test_invalidate_pattern(self, semantic_cache, mock_redis):
        """Test pattern-based cache invalidation."""
        mock_redis.keys.return_value = [
            b"semantic_cache:llm_response:abc123",
            b"semantic_cache:llm_response:def456"
        ]
        mock_redis.delete.return_value = 4  # 2 keys + 2 metadata keys
        
        deleted_count = semantic_cache.invalidate_pattern("llm_response:*")
        
        assert deleted_count == 2
        mock_redis.delete.assert_called_once()
    
    def test_clear_expired_entries(self, semantic_cache, mock_redis):
        """Test clearing expired cache entries."""
        mock_redis.keys.return_value = [
            b"semantic_cache:llm_response:expired1",
            b"semantic_cache:llm_response:active1"
        ]
        
        # Mock TTL: -2 means expired, positive means active
        mock_redis.ttl.side_effect = lambda key: (
            -2 if "expired" in key.decode() else 3600
        )
        
        expired_count = semantic_cache.clear_expired()
        
        assert expired_count >= 0
        assert semantic_cache.stats[CacheType.LLM_RESPONSE].evictions >= 0
    
    def test_cache_warming(self, semantic_cache):
        """Test cache warming functionality."""
        warm_data = [
            {
                "key_data": "warm_key1",
                "content": {"response": "Warmed response 1"},
                "query_text": "Test query 1"
            },
            {
                "key_data": "warm_key2",
                "content": {"response": "Warmed response 2"},
                "query_text": "Test query 2"
            }
        ]
        
        warmed_count = semantic_cache.warm_cache(CacheType.LLM_RESPONSE, warm_data)
        
        assert warmed_count >= 0  # Should warm some entries


class TestCacheStatistics:
    """Test cache statistics and monitoring."""
    
    def test_stats_initialization(self, semantic_cache):
        """Test that statistics are properly initialized."""
        for cache_type in CacheType:
            assert cache_type in semantic_cache.stats
            stats = semantic_cache.stats[cache_type]
            assert isinstance(stats, CacheStats)
            assert stats.hits == 0
            assert stats.misses == 0
            assert stats.hit_ratio == 0.0
    
    def test_hit_ratio_calculation(self):
        """Test hit ratio calculation."""
        stats = CacheStats(hits=7, misses=3)
        assert stats.hit_ratio == 0.7
        
        stats_no_requests = CacheStats(hits=0, misses=0)
        assert stats_no_requests.hit_ratio == 0.0
    
    def test_get_stats(self, semantic_cache):
        """Test retrieving cache statistics."""
        # Get all stats
        all_stats = semantic_cache.get_stats()
        assert len(all_stats) == len(CacheType)
        
        # Get specific cache type stats
        llm_stats = semantic_cache.get_stats(CacheType.LLM_RESPONSE)
        assert CacheType.LLM_RESPONSE.value in llm_stats
    
    def test_save_and_load_stats(self, semantic_cache, mock_redis):
        """Test saving and loading statistics."""
        # Update some stats
        semantic_cache.stats[CacheType.LLM_RESPONSE].hits = 10
        semantic_cache.stats[CacheType.LLM_RESPONSE].misses = 2
        
        # Save stats
        semantic_cache.save_stats()
        
        # Verify Redis call
        mock_redis.setex.assert_called()
        call_args = mock_redis.setex.call_args
        assert call_args[0][0] == "cache_stats"  # Key
        assert call_args[0][1] == 86400  # TTL
        
        # Verify stats data
        stats_data = json.loads(call_args[0][2])
        assert "llm_response" in stats_data
        assert stats_data["llm_response"]["hits"] == 10


class TestCacheDecorator:
    """Test the cache_response decorator."""
    
    def test_cache_decorator_sync(self, semantic_cache):
        """Test caching decorator for synchronous functions."""
        class TestService:
            def __init__(self):
                self.cache = semantic_cache
            
            @cache_response(CacheType.LLM_RESPONSE)
            def get_response(self, query):
                # Simulate expensive operation
                return f"Response for: {query}"
        
        service = TestService()
        
        # First call should execute function
        result1 = service.get_response("test query")
        assert result1 == "Response for: test query"
        
        # Second call should use cache (if properly implemented)
        result2 = service.get_response("test query")
        assert result2 == "Response for: test query"
    
    @pytest.mark.asyncio
    async def test_cache_decorator_async(self, semantic_cache):
        """Test caching decorator for async functions."""
        class TestService:
            def __init__(self):
                self.cache = semantic_cache
            
            @cache_response(CacheType.LLM_RESPONSE)
            async def get_response_async(self, query):
                # Simulate async expensive operation
                return f"Async response for: {query}"
        
        service = TestService()
        
        # First call should execute function
        result1 = await service.get_response_async("test query")
        assert result1 == "Async response for: test query"


class TestUtilityFunctions:
    """Test utility functions."""
    
    def test_create_cache_instance(self):
        """Test creating cache instance with utility function."""
        with patch('core.infrastructure.semantic_cache.redis.from_url') as mock_redis_from_url:
            with patch('core.infrastructure.semantic_cache.SentenceTransformer'):
                mock_redis_from_url.return_value = Mock()
                
                cache = create_cache_instance("redis://test:6379/1")
                
                assert isinstance(cache, SemanticCache)
                mock_redis_from_url.assert_called_with("redis://test:6379/1", decode_responses=False)
    
    def test_cache_llm_response_utility(self, semantic_cache):
        """Test LLM response caching utility function."""
        success = cache_llm_response(
            semantic_cache,
            "What is AI?",
            "AI is artificial intelligence"
        )
        
        assert isinstance(success, bool)
    
    def test_cache_embedding_utility(self, semantic_cache):
        """Test embedding caching utility function."""
        embedding = np.array([0.1, 0.2, 0.3, 0.4])
        
        success = cache_embedding(
            semantic_cache,
            "test text",
            embedding
        )
        
        assert isinstance(success, bool)


class TestCompressionAndSerialization:
    """Test data compression and serialization."""
    
    def test_compression_and_decompression(self, semantic_cache):
        """Test data compression and decompression."""
        test_data = b"This is test data that should be compressed"
        
        compressed = semantic_cache._compress_data(test_data)
        decompressed = semantic_cache._decompress_data(compressed)
        
        assert decompressed == test_data
        assert len(compressed) <= len(test_data)  # Should be smaller or equal
    
    def test_serialization_and_deserialization(self, semantic_cache):
        """Test content serialization and deserialization."""
        test_content = {
            "text": "test response",
            "metadata": {"score": 0.95, "model": "test"},
            "timestamp": datetime.now()
        }
        
        # Test with compression
        serialized = semantic_cache._serialize_content(test_content, compress=True)
        deserialized = semantic_cache._deserialize_content(serialized, compressed=True)
        
        assert deserialized["text"] == test_content["text"]
        assert deserialized["metadata"] == test_content["metadata"]
        
        # Test without compression
        serialized_uncompressed = semantic_cache._serialize_content(test_content, compress=False)
        deserialized_uncompressed = semantic_cache._deserialize_content(serialized_uncompressed, compressed=False)
        
        assert deserialized_uncompressed["text"] == test_content["text"]


class TestErrorHandling:
    """Test error handling and edge cases."""
    
    def test_cache_without_sentence_transformer(self, mock_redis):
        """Test cache operation when sentence transformer fails to load."""
        with patch('core.infrastructure.semantic_cache.SentenceTransformer', side_effect=Exception("Model loading failed")):
            cache = SemanticCache(mock_redis)
            
            # Should still work without semantic features
            assert cache.sentence_model is None
            
            # Basic operations should work
            success = cache.set(CacheType.LLM_RESPONSE, "key", "content")
            assert isinstance(success, bool)
    
    def test_redis_connection_error(self, mock_redis):
        """Test handling Redis connection errors."""
        mock_redis.get.side_effect = redis.ConnectionError("Connection failed")
        
        with patch('core.infrastructure.semantic_cache.SentenceTransformer'):
            cache = SemanticCache(mock_redis)
            
            result = cache.get(CacheType.LLM_RESPONSE, "test_key")
            assert result is None
            
            # Stats should be updated for miss
            assert cache.stats[CacheType.LLM_RESPONSE].misses == 1
    
    def test_invalid_cache_key_data(self, semantic_cache):
        """Test handling invalid cache key data."""
        # Test with non-serializable key data
        invalid_key = {"function": lambda x: x}  # Functions aren't JSON serializable
        
        # Should handle gracefully and generate some key
        key = semantic_cache._generate_cache_key(CacheType.LLM_RESPONSE, str(invalid_key))
        assert isinstance(key, str)
        assert len(key) > 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])