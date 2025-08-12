"""Comprehensive unit tests for LLM Gateway service."""

import pytest
from unittest.mock import Mock, patch, MagicMock
from fastapi.testclient import TestClient
import json
import sys
from pathlib import Path

# Add service path for imports
service_path = Path(__file__).parent.parent.parent.parent / "platform" / "backend" / "services" / "llm_gateway"
sys.path.insert(0, str(service_path))

@pytest.mark.unit
class TestLLMGateway:
    """Test suite for LLM Gateway service."""
    
    @pytest.fixture(autouse=True)
    def setup(self, mock_gemini, mock_redis, mock_logger, test_config_file):
        """Set up test environment."""
        self.mock_gemini = mock_gemini
        self.mock_redis = mock_redis
        self.mock_logger = mock_logger
        self.test_config_file = test_config_file
        
        # Mock environment variables
        with patch.dict('os.environ', {
            'GEMINI_API_KEY': 'test-api-key-for-testing',
            'REDIS_URL': 'redis://localhost:6379/1',
            'LOG_LEVEL': 'DEBUG'
        }):
            # Mock semantic cache import to be optional
            with patch('core.infrastructure.semantic_cache.SemanticCache') as mock_cache:
                mock_cache_instance = MagicMock()
                mock_cache_instance.get.return_value = None  # Cache miss
                mock_cache_instance.set.return_value = True
                mock_cache.return_value = mock_cache_instance
                self.mock_cache = mock_cache_instance
                
                # Import after environment setup
                from main import app
                self.client = TestClient(app)
                self.app = app
    
    def test_health_endpoint(self):
        """Test health check endpoint."""
        response = self.client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
    
    def test_basic_completion(self, sample_llm_request):
        """Test basic text completion."""
        # Mock Gemini response
        mock_response = MagicMock()
        mock_response.text = "This is a test completion response."
        self.mock_gemini["instance"].generate_content.return_value = mock_response
        
        response = self.client.post("/complete", json=sample_llm_request)
        
        assert response.status_code == 200
        data = response.json()
        assert "text" in data
        assert data["text"] == "This is a test completion response."
        
        # Verify Gemini was called
        self.mock_gemini["instance"].generate_content.assert_called_once()
    
    def test_completion_with_config(self):
        """Test completion with custom configuration."""
        # Create a test config
        config_data = {
            "model": "gemini-pro",
            "api_key": "test-key",
            "generation_config": {
                "temperature": 0.8,
                "top_p": 0.9
            },
            "base_preprompt": "You are a helpful assistant."
        }
        
        config_path = Path(self.test_config_file).parent / "test_config.json"
        config_path.write_text(json.dumps(config_data))
        
        # Mock the CONFIG_DIR to point to our test directory
        with patch('main.CONFIG_DIR', Path(self.test_config_file).parent):
            request_data = {
                "prompt": "What is AI?",
                "max_tokens": 100,
                "config": "test_config"
            }
            
            mock_response = MagicMock()
            mock_response.text = "AI is artificial intelligence."
            self.mock_gemini["instance"].generate_content.return_value = mock_response
            
            response = self.client.post("/complete", json=request_data)
            
            assert response.status_code == 200
            data = response.json()
            assert "text" in data
    
    def test_completion_with_invalid_config(self):
        """Test completion with non-existent configuration."""
        request_data = {
            "prompt": "Test prompt",
            "config": "nonexistent_config"
        }
        
        response = self.client.post("/complete", json=request_data)
        
        assert response.status_code == 400
        data = response.json()
        assert "Unknown config" in data["detail"]
    
    def test_completion_with_cache_hit(self):
        """Test completion with cache hit."""
        # Mock cache hit
        cached_response = {"text": "Cached response"}
        self.mock_cache.get.return_value = cached_response
        
        request_data = {
            "prompt": "What is machine learning?",
            "max_tokens": 100
        }
        
        response = self.client.post("/complete", json=request_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["text"] == "Cached response"
        
        # Verify Gemini was NOT called (cache hit)
        self.mock_gemini["instance"].generate_content.assert_not_called()
    
    def test_completion_with_cache_miss(self):
        """Test completion with cache miss and caching result."""
        # Mock cache miss
        self.mock_cache.get.return_value = None
        
        mock_response = MagicMock()
        mock_response.text = "Fresh response from Gemini"
        self.mock_gemini["instance"].generate_content.return_value = mock_response
        
        request_data = {
            "prompt": "Explain quantum computing",
            "max_tokens": 200
        }
        
        response = self.client.post("/complete", json=request_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["text"] == "Fresh response from Gemini"
        
        # Verify response was cached
        self.mock_cache.set.assert_called_once()
    
    def test_gemini_api_error(self):
        """Test error handling when Gemini API fails."""
        self.mock_gemini["instance"].generate_content.side_effect = Exception("API rate limit exceeded")
        
        request_data = {
            "prompt": "Test prompt",
            "max_tokens": 100
        }
        
        response = self.client.post("/complete", json=request_data)
        
        assert response.status_code == 502
        data = response.json()
        assert "API rate limit exceeded" in data["detail"]
    
    def test_invalid_api_key(self):
        """Test handling of invalid API key."""
        with patch.dict('os.environ', {'GEMINI_API_KEY': ''}):
            # This should raise an error during app initialization
            with pytest.raises(ValueError, match="Valid GEMINI_API_KEY environment variable is required"):
                from main import app
    
    def test_empty_response_handling(self):
        """Test handling of empty or invalid responses."""
        # Mock response with no text
        mock_response = MagicMock()
        mock_response.text = None
        self.mock_gemini["instance"].generate_content.return_value = mock_response
        
        request_data = {
            "prompt": "Test prompt",
            "max_tokens": 100
        }
        
        response = self.client.post("/complete", json=request_data)
        
        assert response.status_code == 502
        data = response.json()
        assert "Invalid response" in data["detail"]
    
    def test_list_configs_endpoint(self):
        """Test listing available configurations."""
        # Create some test config files
        config_dir = Path(self.test_config_file).parent
        
        config1_data = {"model": "gemini-pro", "api_key": "test"}
        config2_data = {"model": "gemini-pro-vision", "api_key": "test"}
        
        (config_dir / "config1.json").write_text(json.dumps(config1_data))
        (config_dir / "config2.json").write_text(json.dumps(config2_data))
        
        with patch('main.CONFIG_DIR', config_dir):
            response = self.client.get("/configs")
            
            assert response.status_code == 200
            data = response.json()
            assert "configs" in data
            assert "config1" in data["configs"]
            assert "config2" in data["configs"]
    
    def test_cache_stats_endpoint(self):
        """Test cache statistics endpoint."""
        # Mock cache stats
        mock_stats = {
            "llm_response": {
                "hits": 50,
                "misses": 25,
                "size_mb": 12.5
            }
        }
        self.mock_cache.get_stats.return_value = mock_stats
        
        response = self.client.get("/cache/stats")
        
        assert response.status_code == 200
        data = response.json()
        assert data["cache_enabled"] == True
        assert "statistics" in data
        assert data["statistics"] == mock_stats
    
    def test_cache_stats_unavailable(self):
        """Test cache stats when cache is unavailable."""
        with patch('main.SEMANTIC_CACHE_AVAILABLE', False):
            response = self.client.get("/cache/stats")
            
            assert response.status_code == 200
            data = response.json()
            assert data["cache_enabled"] == False
            assert "error" in data
    
    def test_clear_cache_endpoint(self):
        """Test cache clearing endpoint."""
        self.mock_cache.invalidate_pattern.return_value = 15
        
        response = self.client.post("/cache/clear", params={"pattern": "test*"})
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] == True
        assert data["cleared_entries"] == 15
        assert data["pattern"] == "test*"
    
    def test_clear_cache_error(self):
        """Test cache clearing error handling."""
        self.mock_cache.invalidate_pattern.side_effect = Exception("Cache error")
        
        response = self.client.post("/cache/clear")
        
        assert response.status_code == 200
        data = response.json()
        assert "error" in data
    
    def test_warm_cache_endpoint(self):
        """Test cache warming endpoint."""
        self.mock_cache.warm_cache.return_value = 3
        
        response = self.client.post("/cache/warm")
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] == True
        assert data["warmed_entries"] == 3
    
    def test_prompt_modification(self):
        """Test prompt modification functionality."""
        # This would test the prompt_modifier module
        with patch('main.modify_prompt') as mock_modify:
            mock_modify.return_value = "Modified: What is AI?"
            
            mock_response = MagicMock()
            mock_response.text = "AI response"
            self.mock_gemini["instance"].generate_content.return_value = mock_response
            
            request_data = {
                "prompt": "What is AI?",
                "max_tokens": 100
            }
            
            response = self.client.post("/complete", json=request_data)
            
            assert response.status_code == 200
            mock_modify.assert_called_once()
    
    def test_base_preprompt_functionality(self):
        """Test base preprompt addition."""
        config_data = {
            "model": "gemini-pro",
            "api_key": "test-key",
            "base_preprompt": "You are a helpful AI assistant."
        }
        
        config_path = Path(self.test_config_file).parent / "preprompt_config.json"
        config_path.write_text(json.dumps(config_data))
        
        with patch('main.CONFIG_DIR', Path(self.test_config_file).parent):
            mock_response = MagicMock()
            mock_response.text = "Response with preprompt"
            self.mock_gemini["instance"].generate_content.return_value = mock_response
            
            request_data = {
                "prompt": "Hello",
                "config": "preprompt_config"
            }
            
            response = self.client.post("/complete", json=request_data)
            
            assert response.status_code == 200
            
            # Verify the preprompt was added to the call
            call_args = self.mock_gemini["instance"].generate_content.call_args
            prompt_used = call_args[0][0]
            assert "You are a helpful AI assistant." in prompt_used
    
    def test_safety_settings(self):
        """Test that safety settings are properly configured."""
        mock_response = MagicMock()
        mock_response.text = "Safe response"
        self.mock_gemini["instance"].generate_content.return_value = mock_response
        
        request_data = {
            "prompt": "Test prompt",
            "max_tokens": 100
        }
        
        response = self.client.post("/complete", json=request_data)
        
        assert response.status_code == 200
        
        # Verify safety settings were passed
        call_args = self.mock_gemini["instance"].generate_content.call_args
        kwargs = call_args[1]
        assert "safety_settings" in kwargs
    
    def test_generation_config(self):
        """Test generation configuration is properly applied."""
        mock_response = MagicMock()
        mock_response.text = "Configured response"
        self.mock_gemini["instance"].generate_content.return_value = mock_response
        
        request_data = {
            "prompt": "Test prompt",
            "max_tokens": 150
        }
        
        response = self.client.post("/complete", json=request_data)
        
        assert response.status_code == 200
        
        # Verify generation config was used
        call_args = self.mock_gemini["instance"].generate_content.call_args
        kwargs = call_args[1]
        assert "generation_config" in kwargs
        assert kwargs["generation_config"]["max_output_tokens"] == 150
    
    def test_metrics_collection(self):
        """Test that metrics are properly collected."""
        mock_response = MagicMock()
        mock_response.text = "Test response"
        self.mock_gemini["instance"].generate_content.return_value = mock_response
        
        # Make some requests
        for i in range(3):
            self.client.post("/complete", json={
                "prompt": f"Test prompt {i}",
                "max_tokens": 100
            })
        
        # Check metrics endpoint
        response = self.client.get("/metrics")
        assert response.status_code == 200
        metrics_text = response.text
        
        # Should contain LLM-specific metrics
        assert "llm_gateway" in metrics_text
        assert "prompt_length_chars" in metrics_text
        assert "model_selections_total" in metrics_text
    
    def test_concurrent_requests(self):
        """Test handling concurrent completion requests."""
        import concurrent.futures
        
        mock_response = MagicMock()
        mock_response.text = "Concurrent response"
        self.mock_gemini["instance"].generate_content.return_value = mock_response
        
        def make_request(i):
            return self.client.post("/complete", json={
                "prompt": f"Concurrent prompt {i}",
                "max_tokens": 50
            })
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(make_request, i) for i in range(10)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        
        assert all(r.status_code == 200 for r in results)
        assert all("text" in r.json() for r in results)
    
    def test_request_validation(self):
        """Test request validation."""
        # Test missing prompt
        response = self.client.post("/complete", json={
            "max_tokens": 100
        })
        assert response.status_code == 422
        
        # Test invalid max_tokens
        response = self.client.post("/complete", json={
            "prompt": "Test",
            "max_tokens": -1
        })
        assert response.status_code == 422
        
        # Test extremely long prompt
        response = self.client.post("/complete", json={
            "prompt": "x" * 1000000,  # Very long prompt
            "max_tokens": 100
        })
        # Should either handle gracefully or return appropriate error
        assert response.status_code in [200, 400, 413, 422]
    
    def test_cors_headers(self):
        """Test CORS headers are properly set."""
        response = self.client.options("/complete")
        assert response.status_code == 200
        assert "access-control-allow-origin" in response.headers
        assert "access-control-allow-methods" in response.headers
    
    def test_redis_connection_failure(self):
        """Test graceful handling of Redis connection failures."""
        with patch('redis.from_url') as mock_redis_from_url:
            mock_redis_from_url.side_effect = Exception("Redis connection failed")
            
            # App should still start without cache
            request_data = {
                "prompt": "Test prompt",
                "max_tokens": 100
            }
            
            mock_response = MagicMock()
            mock_response.text = "Response without cache"
            self.mock_gemini["instance"].generate_content.return_value = mock_response
            
            response = self.client.post("/complete", json=request_data)
            
            # Should work without cache
            assert response.status_code == 200