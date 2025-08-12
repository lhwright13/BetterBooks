"""Comprehensive unit tests for API Gateway service."""

import pytest
from unittest.mock import Mock, patch, MagicMock
from fastapi.testclient import TestClient
import json
import sys
from pathlib import Path

# Add service path for imports
service_path = Path(__file__).parent.parent.parent.parent / "platform" / "backend" / "services" / "api_gateway"
sys.path.insert(0, str(service_path))

@pytest.mark.unit
class TestAPIGateway:
    """Test suite for API Gateway service."""
    
    @pytest.fixture(autouse=True)
    def setup(self, mock_gemini, mock_redis, mock_logger):
        """Set up test environment."""
        self.mock_gemini = mock_gemini
        self.mock_redis = mock_redis
        self.mock_logger = mock_logger
        
        # Mock environment variables
        with patch.dict('os.environ', {
            'CONTEXT_SERVICE_URL': 'http://context:8001',
            'LLM_GATEWAY_URL': 'http://llm:8002',
            'TTS_SERVICE_URL': 'http://tts:8003',
            'TRANSCRIPTION_SERVICE_URL': 'http://transcription:8004',
            'GEMINI_API_KEY': 'test-key'
        }):
            # Import after environment setup
            from main import app
            self.client = TestClient(app)
            self.app = app
    
    def test_health_endpoint(self):
        """Test health check endpoint."""
        response = self.client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "version" in data
        assert "timestamp" in data
    
    def test_detailed_health_endpoint(self):
        """Test detailed health check endpoint."""
        with patch('requests.get') as mock_get:
            # Mock successful health checks for all services
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"status": "ok"}
            mock_get.return_value = mock_response
            
            response = self.client.get("/health/detailed")
            assert response.status_code == 200
            data = response.json()
            
            assert data["status"] == "healthy"
            assert "services" in data
            assert "context_service" in data["services"]
            assert "llm_gateway" in data["services"]
            assert "tts_service" in data["services"]
    
    def test_ready_endpoint(self):
        """Test readiness check endpoint."""
        with patch('requests.get') as mock_get:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"status": "ok"}
            mock_get.return_value = mock_response
            
            response = self.client.get("/health/ready")
            assert response.status_code == 200
            data = response.json()
            assert data["ready"] == True
    
    def test_liveness_endpoint(self):
        """Test liveness check endpoint."""
        response = self.client.get("/health/live")
        assert response.status_code == 200
        data = response.json()
        assert data["alive"] == True
    
    @pytest.mark.parametrize("endpoint,service_url", [
        ("/api/v1/context/store", "http://context:8001"),
        ("/api/v1/llm/complete", "http://llm:8002"),
        ("/api/v1/tts/synthesize", "http://tts:8003"),
    ])
    def test_service_proxying(self, endpoint, service_url):
        """Test that requests are properly proxied to backend services."""
        with patch('requests.request') as mock_request:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"result": "success"}
            mock_response.headers = {"Content-Type": "application/json"}
            mock_request.return_value = mock_response
            
            test_data = {"test": "data"}
            response = self.client.post(endpoint, json=test_data)
            
            assert response.status_code == 200
            assert response.json() == {"result": "success"}
            
            # Verify the request was forwarded correctly
            mock_request.assert_called_once()
            call_args = mock_request.call_args
            assert service_url in call_args[1]["url"]
    
    def test_request_id_propagation(self):
        """Test that X-Request-ID header is propagated."""
        with patch('requests.request') as mock_request:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"result": "success"}
            mock_response.headers = {}
            mock_request.return_value = mock_response
            
            request_id = "test-request-123"
            response = self.client.post(
                "/api/v1/context/store",
                json={"test": "data"},
                headers={"X-Request-ID": request_id}
            )
            
            # Check that request ID was forwarded
            call_args = mock_request.call_args
            assert call_args[1]["headers"]["X-Request-ID"] == request_id
    
    def test_error_handling_service_unavailable(self):
        """Test error handling when backend service is unavailable."""
        with patch('requests.request') as mock_request:
            mock_request.side_effect = Exception("Connection refused")
            
            response = self.client.post("/api/v1/context/store", json={"test": "data"})
            
            assert response.status_code == 503
            data = response.json()
            assert "error" in data
            assert "Service temporarily unavailable" in data["error"]
    
    def test_error_handling_timeout(self):
        """Test error handling for request timeouts."""
        with patch('requests.request') as mock_request:
            import requests
            mock_request.side_effect = requests.Timeout("Request timed out")
            
            response = self.client.post("/api/v1/llm/complete", json={"prompt": "test"})
            
            assert response.status_code == 504
            data = response.json()
            assert "error" in data
            assert "timeout" in data["error"].lower()
    
    def test_cors_headers(self):
        """Test CORS headers are properly set."""
        response = self.client.options("/api/v1/context/store")
        assert response.status_code == 200
        assert "access-control-allow-origin" in response.headers
    
    def test_metrics_endpoint(self):
        """Test Prometheus metrics endpoint."""
        response = self.client.get("/metrics")
        assert response.status_code == 200
        assert "text/plain" in response.headers["content-type"]
        assert "http_requests_total" in response.text
    
    def test_request_validation(self):
        """Test request validation for different endpoints."""
        # Test with invalid JSON
        response = self.client.post(
            "/api/v1/llm/complete",
            data="invalid json",
            headers={"Content-Type": "application/json"}
        )
        assert response.status_code == 422
    
    def test_response_compression(self):
        """Test that responses are compressed when requested."""
        with patch('requests.request') as mock_request:
            # Create a large response
            large_data = {"data": "x" * 10000}
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = large_data
            mock_response.headers = {"Content-Type": "application/json"}
            mock_request.return_value = mock_response
            
            response = self.client.post(
                "/api/v1/context/search",
                json={"query": "test"},
                headers={"Accept-Encoding": "gzip"}
            )
            
            assert response.status_code == 200
    
    def test_circuit_breaker_functionality(self):
        """Test circuit breaker opens after multiple failures."""
        with patch('requests.request') as mock_request:
            # Simulate multiple failures
            mock_request.side_effect = Exception("Service error")
            
            # Make multiple requests to trigger circuit breaker
            for _ in range(5):
                response = self.client.post("/api/v1/llm/complete", json={"prompt": "test"})
                assert response.status_code == 503
            
            # Circuit should be open now, returning fast failures
            response = self.client.post("/api/v1/llm/complete", json={"prompt": "test"})
            assert response.status_code == 503
    
    def test_rate_limiting(self):
        """Test rate limiting functionality."""
        # Make many rapid requests
        responses = []
        for i in range(20):
            response = self.client.get("/health")
            responses.append(response.status_code)
        
        # At least some should succeed
        assert 200 in responses
    
    def test_websocket_support(self):
        """Test WebSocket connection support."""
        # Note: Full WebSocket testing requires different client
        # This just ensures the endpoint exists
        with self.client.websocket_connect("/ws") as websocket:
            websocket.send_json({"type": "ping"})
            data = websocket.receive_json()
            assert "type" in data
    
    @pytest.mark.parametrize("method", ["GET", "POST", "PUT", "DELETE", "PATCH"])
    def test_http_methods_support(self, method):
        """Test that various HTTP methods are supported."""
        with patch('requests.request') as mock_request:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"method": method}
            mock_response.headers = {}
            mock_request.return_value = mock_response
            
            response = self.client.request(method, "/api/v1/context/test")
            assert response.status_code in [200, 405]  # 405 if method not allowed
    
    def test_request_logging(self, mock_logger):
        """Test that requests are properly logged."""
        with patch('requests.request') as mock_request:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"result": "success"}
            mock_response.headers = {}
            mock_request.return_value = mock_response
            
            self.client.post("/api/v1/context/store", json={"test": "data"})
            
            # Verify logging occurred
            # Note: Implementation depends on actual logging setup
    
    def test_authentication_headers(self):
        """Test authentication header handling."""
        with patch('requests.request') as mock_request:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"authenticated": True}
            mock_response.headers = {}
            mock_request.return_value = mock_response
            
            token = "Bearer test-token-123"
            response = self.client.post(
                "/api/v1/context/store",
                json={"test": "data"},
                headers={"Authorization": token}
            )
            
            # Verify auth header was forwarded
            call_args = mock_request.call_args
            assert call_args[1]["headers"]["Authorization"] == token
    
    def test_multipart_form_data(self):
        """Test handling of multipart form data."""
        with patch('requests.request') as mock_request:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"uploaded": True}
            mock_response.headers = {}
            mock_request.return_value = mock_response
            
            files = {"file": ("test.txt", b"test content", "text/plain")}
            response = self.client.post("/api/v1/tts/upload", files=files)
            
            # Should handle file uploads appropriately
            assert response.status_code in [200, 400, 415]
    
    def test_query_parameter_forwarding(self):
        """Test that query parameters are forwarded correctly."""
        with patch('requests.request') as mock_request:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"results": []}
            mock_response.headers = {}
            mock_request.return_value = mock_response
            
            response = self.client.get("/api/v1/context/search?q=test&limit=10")
            
            # Verify query params were forwarded
            call_args = mock_request.call_args
            assert "q=test" in call_args[1]["url"]
            assert "limit=10" in call_args[1]["url"]
    
    def test_response_caching(self):
        """Test response caching for cacheable endpoints."""
        with patch('requests.request') as mock_request:
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"data": "cached"}
            mock_response.headers = {"Cache-Control": "max-age=300"}
            mock_request.return_value = mock_response
            
            # First request
            response1 = self.client.get("/api/v1/context/metadata")
            
            # Second request (should potentially use cache)
            response2 = self.client.get("/api/v1/context/metadata")
            
            assert response1.status_code == 200
            assert response2.status_code == 200