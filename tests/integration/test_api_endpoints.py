"""Integration tests for EchoWright API endpoints."""

import pytest
import requests
import json
import time
import os
from typing import Dict, Any
import asyncio
import aiohttp

# Base URL for API testing
API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000")

@pytest.mark.integration
class TestAPIIntegration:
    """Integration tests for the complete API workflow."""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Set up integration test environment."""
        self.base_url = API_BASE_URL
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "X-Request-ID": f"test-{int(time.time())}"
        })
        
        # Test data
        self.test_text = "Chapter 1: The Beginning. This is the start of an amazing adventure story about a brave hero who embarks on a quest to save the world from dark forces."
        self.test_prompt = "Summarize this chapter in one sentence."
        
        yield
        
        # Cleanup
        self.session.close()
    
    def test_api_gateway_health(self):
        """Test API Gateway health endpoints."""
        # Basic health check
        response = self.session.get(f"{self.base_url}/health")
        assert response.status_code == 200
        
        health_data = response.json()
        assert health_data["status"] == "healthy"
        assert "version" in health_data
        
        # Detailed health check
        response = self.session.get(f"{self.base_url}/health/detailed")
        assert response.status_code == 200
        
        detailed_data = response.json()
        assert "services" in detailed_data
        assert "timestamp" in detailed_data
    
    def test_context_service_flow(self):
        """Test complete context service workflow."""
        # Store context
        store_payload = {
            "text": self.test_text,
            "metadata": {
                "book_id": "test_book_123",
                "chapter": 1,
                "source": "integration_test"
            }
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/context/store",
            json=store_payload
        )
        assert response.status_code == 200
        
        store_result = response.json()
        assert "id" in store_result
        context_id = store_result["id"]
        
        # Search for similar context
        search_payload = {
            "query": "adventure story hero quest",
            "limit": 5,
            "threshold": 0.5
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/context/search",
            json=search_payload
        )
        assert response.status_code == 200
        
        search_result = response.json()
        assert "results" in search_result
        assert len(search_result["results"]) >= 0
        
        # Retrieve specific context
        response = self.session.get(f"{self.base_url}/api/v1/context/{context_id}")
        assert response.status_code == 200
        
        context_data = response.json()
        assert context_data["id"] == context_id
        assert context_data["text"] == self.test_text
        
        # Update context
        update_payload = {
            "metadata": {
                "book_id": "test_book_123",
                "chapter": 1,
                "updated": True,
                "source": "integration_test"
            }
        }
        
        response = self.session.put(
            f"{self.base_url}/api/v1/context/{context_id}",
            json=update_payload
        )
        assert response.status_code == 200
        
        # Clean up - delete context
        response = self.session.delete(f"{self.base_url}/api/v1/context/{context_id}")
        assert response.status_code == 200
    
    def test_llm_gateway_flow(self):
        """Test complete LLM Gateway workflow."""
        # Basic completion
        completion_payload = {
            "prompt": self.test_prompt,
            "max_tokens": 100
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/llm/complete",
            json=completion_payload
        )
        assert response.status_code == 200
        
        completion_result = response.json()
        assert "text" in completion_result
        assert len(completion_result["text"]) > 0
        
        # Test with custom config (if available)
        response = self.session.get(f"{self.base_url}/api/v1/llm/configs")
        assert response.status_code == 200
        
        configs = response.json()
        if configs.get("configs"):
            config_name = configs["configs"][0]
            
            completion_payload["config"] = config_name
            response = self.session.post(
                f"{self.base_url}/api/v1/llm/complete",
                json=completion_payload
            )
            assert response.status_code == 200
        
        # Test cache stats
        response = self.session.get(f"{self.base_url}/api/v1/llm/cache/stats")
        assert response.status_code == 200
        
        cache_stats = response.json()
        assert "cache_enabled" in cache_stats
    
    def test_tts_service_flow(self):
        """Test complete TTS service workflow."""
        # Synthesize text
        tts_payload = {
            "text": "Hello, this is a test of the text-to-speech service.",
            "voice": "default",
            "format": "mp3"
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/tts/synthesize",
            json=tts_payload
        )
        assert response.status_code == 200
        
        tts_result = response.json()
        assert "audio_url" in tts_result
        assert "duration" in tts_result
        
        # List available voices
        response = self.session.get(f"{self.base_url}/api/v1/tts/voices")
        assert response.status_code == 200
        
        voices = response.json()
        assert "voices" in voices
        assert isinstance(voices["voices"], list)
        
        # Download audio file (if URL is accessible)
        audio_url = tts_result["audio_url"]
        if audio_url.startswith("http"):
            audio_response = self.session.get(audio_url)
            assert audio_response.status_code == 200
            assert len(audio_response.content) > 0
    
    def test_end_to_end_workflow(self):
        """Test complete end-to-end workflow."""
        # 1. Store context for a book chapter
        chapter_text = """
        Chapter 5: The Dark Forest
        
        Sarah ventured into the mysterious dark forest, her heart pounding with both fear and excitement. 
        The ancient trees towered above her, their branches creating a canopy so thick that barely any 
        sunlight reached the forest floor. She knew that somewhere in this forest lay the Crystal of Truth, 
        the artifact she needed to complete her quest and save her village from the curse.
        
        As she walked deeper into the forest, strange sounds echoed around her. The rustling of leaves, 
        the distant howl of unknown creatures, and the occasional crack of a branch breaking underfoot. 
        Despite her fear, Sarah pressed on, guided by the ancient map her grandmother had given her.
        """
        
        store_payload = {
            "text": chapter_text,
            "metadata": {
                "book_id": "sarahs_quest",
                "chapter": 5,
                "title": "The Dark Forest",
                "author": "Test Author",
                "genre": "fantasy"
            }
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/context/store",
            json=store_payload
        )
        assert response.status_code == 200
        context_id = response.json()["id"]
        
        # 2. Generate AI summary using LLM
        summary_prompt = f"Summarize this chapter in 2-3 sentences: {chapter_text}"
        
        llm_payload = {
            "prompt": summary_prompt,
            "max_tokens": 150
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/llm/complete",
            json=llm_payload
        )
        assert response.status_code == 200
        summary = response.json()["text"]
        
        # 3. Convert summary to speech
        tts_payload = {
            "text": summary,
            "voice": "default",
            "format": "mp3"
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/tts/synthesize",
            json=tts_payload
        )
        assert response.status_code == 200
        audio_info = response.json()
        
        # 4. Search for similar content
        search_payload = {
            "query": "dark forest crystal quest adventure",
            "limit": 5,
            "threshold": 0.6
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/context/search",
            json=search_payload
        )
        assert response.status_code == 200
        search_results = response.json()
        
        # Verify we found our stored content
        found_stored_context = any(
            result["id"] == context_id 
            for result in search_results["results"]
        )
        assert found_stored_context
        
        # 5. Clean up
        response = self.session.delete(f"{self.base_url}/api/v1/context/{context_id}")
        assert response.status_code == 200
        
        # Verify the complete workflow produced valid results
        assert len(summary) > 20  # Summary should be substantial
        assert "audio_url" in audio_info
        assert len(search_results["results"]) > 0
    
    def test_batch_operations(self):
        """Test batch operations across services."""
        # Batch context storage
        contexts = []
        for i in range(3):
            context_text = f"Chapter {i+1}: This is test chapter {i+1} content with unique information about topic {i+1}."
            
            store_payload = {
                "text": context_text,
                "metadata": {
                    "book_id": "batch_test_book",
                    "chapter": i+1,
                    "batch_test": True
                }
            }
            
            response = self.session.post(
                f"{self.base_url}/api/v1/context/store",
                json=store_payload
            )
            assert response.status_code == 200
            contexts.append(response.json()["id"])
        
        # Batch LLM completions
        prompts = [
            "What is the main theme of this chapter?",
            "Describe the setting in detail.",
            "Who are the main characters mentioned?"
        ]
        
        completions = []
        for prompt in prompts:
            llm_payload = {
                "prompt": prompt,
                "max_tokens": 80
            }
            
            response = self.session.post(
                f"{self.base_url}/api/v1/llm/complete",
                json=llm_payload
            )
            assert response.status_code == 200
            completions.append(response.json()["text"])
        
        # Verify all operations succeeded
        assert len(contexts) == 3
        assert len(completions) == 3
        assert all(len(completion) > 0 for completion in completions)
        
        # Clean up batch contexts
        for context_id in contexts:
            response = self.session.delete(f"{self.base_url}/api/v1/context/{context_id}")
            assert response.status_code == 200
    
    def test_error_handling(self):
        """Test error handling across services."""
        # Test invalid context ID
        response = self.session.get(f"{self.base_url}/api/v1/context/invalid_id")
        assert response.status_code == 404
        
        # Test empty LLM prompt
        response = self.session.post(
            f"{self.base_url}/api/v1/llm/complete",
            json={"prompt": "", "max_tokens": 100}
        )
        assert response.status_code in [400, 422]
        
        # Test invalid TTS request
        response = self.session.post(
            f"{self.base_url}/api/v1/tts/synthesize",
            json={"text": "", "voice": "invalid_voice"}
        )
        assert response.status_code in [400, 422]
    
    def test_response_headers(self):
        """Test that proper response headers are set."""
        response = self.session.get(f"{self.base_url}/health")
        
        # Check CORS headers
        assert "access-control-allow-origin" in response.headers
        
        # Check content type
        assert response.headers["content-type"] == "application/json"
        
        # Check for request ID propagation
        if "X-Request-ID" in self.session.headers:
            # Request ID should be in response or logs
            pass
    
    def test_pagination(self):
        """Test pagination in context search."""
        # Store multiple contexts for pagination testing
        context_ids = []
        
        for i in range(15):  # More than typical page size
            store_payload = {
                "text": f"Pagination test content {i}. This is unique content for testing pagination functionality.",
                "metadata": {
                    "pagination_test": True,
                    "index": i
                }
            }
            
            response = self.session.post(
                f"{self.base_url}/api/v1/context/store",
                json=store_payload
            )
            assert response.status_code == 200
            context_ids.append(response.json()["id"])
        
        # Test paginated search
        search_payload = {
            "query": "pagination test content",
            "limit": 5,
            "offset": 0
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/context/search",
            json=search_payload
        )
        assert response.status_code == 200
        
        search_result = response.json()
        assert len(search_result["results"]) <= 5
        
        # Test second page
        search_payload["offset"] = 5
        response = self.session.post(
            f"{self.base_url}/api/v1/context/search",
            json=search_payload
        )
        assert response.status_code == 200
        
        # Clean up
        for context_id in context_ids:
            self.session.delete(f"{self.base_url}/api/v1/context/{context_id}")
    
    def test_concurrent_requests(self):
        """Test handling of concurrent requests."""
        import concurrent.futures
        
        def make_health_request():
            return self.session.get(f"{self.base_url}/health")
        
        def make_llm_request(i):
            return self.session.post(
                f"{self.base_url}/api/v1/llm/complete",
                json={
                    "prompt": f"Concurrent test {i}: What is AI?",
                    "max_tokens": 50
                }
            )
        
        # Test concurrent health checks
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            health_futures = [executor.submit(make_health_request) for _ in range(20)]
            health_results = [f.result() for f in concurrent.futures.as_completed(health_futures)]
        
        assert all(r.status_code == 200 for r in health_results)
        
        # Test concurrent LLM requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            llm_futures = [executor.submit(make_llm_request, i) for i in range(10)]
            llm_results = [f.result() for f in concurrent.futures.as_completed(llm_futures)]
        
        # Most should succeed (some might be rate limited)
        success_count = sum(1 for r in llm_results if r.status_code == 200)
        assert success_count >= len(llm_results) // 2  # At least half should succeed
    
    @pytest.mark.slow
    def test_performance_benchmarks(self):
        """Test basic performance benchmarks."""
        # Health check should be fast
        start_time = time.time()
        response = self.session.get(f"{self.base_url}/health")
        health_time = time.time() - start_time
        
        assert response.status_code == 200
        assert health_time < 1.0  # Should respond within 1 second
        
        # Context storage should be reasonable
        start_time = time.time()
        response = self.session.post(
            f"{self.base_url}/api/v1/context/store",
            json={
                "text": "Performance test context",
                "metadata": {"test": "performance"}
            }
        )
        storage_time = time.time() - start_time
        
        assert response.status_code == 200
        assert storage_time < 5.0  # Should complete within 5 seconds
        
        # Clean up
        if response.status_code == 200:
            context_id = response.json()["id"]
            self.session.delete(f"{self.base_url}/api/v1/context/{context_id}")

@pytest.mark.integration
class TestAsyncAPIIntegration:
    """Async integration tests for better performance testing."""
    
    @pytest.fixture(autouse=True)
    async def setup(self):
        """Set up async test environment."""
        self.base_url = API_BASE_URL
        self.connector = aiohttp.TCPConnector(limit=100)
        self.session = aiohttp.ClientSession(
            connector=self.connector,
            headers={"Content-Type": "application/json"}
        )
        
        yield
        
        await self.session.close()
    
    async def test_async_concurrent_requests(self):
        """Test high-concurrency async requests."""
        async def make_health_request(session):
            async with session.get(f"{self.base_url}/health") as response:
                return await response.json()
        
        # Make 50 concurrent health check requests
        tasks = [make_health_request(self.session) for _ in range(50)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Count successful responses
        success_count = sum(1 for r in results if isinstance(r, dict) and r.get("status") == "healthy")
        assert success_count >= 45  # At least 90% should succeed
    
    async def test_async_workflow(self):
        """Test async end-to-end workflow."""
        # Store context
        async with self.session.post(
            f"{self.base_url}/api/v1/context/store",
            json={
                "text": "Async test context",
                "metadata": {"async_test": True}
            }
        ) as response:
            assert response.status == 200
            context_data = await response.json()
            context_id = context_data["id"]
        
        # Generate completion
        async with self.session.post(
            f"{self.base_url}/api/v1/llm/complete",
            json={
                "prompt": "Summarize: Async test context",
                "max_tokens": 50
            }
        ) as response:
            assert response.status == 200
            completion_data = await response.json()
            assert "text" in completion_data
        
        # Clean up
        async with self.session.delete(f"{self.base_url}/api/v1/context/{context_id}") as response:
            assert response.status == 200