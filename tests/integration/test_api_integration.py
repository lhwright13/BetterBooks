"""
Integration tests for EchoWright API endpoints
Tests real API behavior in staging/production environments
"""

import pytest
import requests
import json
import time
from typing import Dict, Any
import os


class TestAPIIntegration:
    """Test suite for API integration testing"""
    
    @pytest.fixture(autouse=True)
    def setup(self):
        """Setup test environment"""
        self.api_base_url = os.getenv('API_BASE_URL', 'http://localhost:8000')
        self.timeout = 30
        self.headers = {'Content-Type': 'application/json'}
        
        # Wait for services to be ready
        self._wait_for_services()
    
    def _wait_for_services(self, max_retries: int = 30, delay: int = 2):
        """Wait for all services to be ready"""
        services = [
            f"{self.api_base_url}/health",
            f"{self.api_base_url}/api/v1/context/health", 
            f"{self.api_base_url}/api/v1/llm/health",
            f"{self.api_base_url}/api/v1/tts/health",
            f"{self.api_base_url}/api/v1/transcription/health"
        ]
        
        for service_url in services:
            retries = 0
            while retries < max_retries:
                try:
                    response = requests.get(service_url, timeout=5)
                    if response.status_code == 200:
                        break
                except requests.RequestException:
                    pass
                
                retries += 1
                if retries < max_retries:
                    time.sleep(delay)
            else:
                pytest.fail(f"Service {service_url} did not become ready within {max_retries * delay}s")

    def test_health_endpoints(self):
        """Test basic health check endpoints"""
        endpoints = [
            f"{self.api_base_url}/health",
            f"{self.api_base_url}/health/detailed", 
            f"{self.api_base_url}/health/ready",
            f"{self.api_base_url}/health/live"
        ]
        
        for endpoint in endpoints:
            response = requests.get(endpoint, timeout=self.timeout)
            assert response.status_code == 200, f"Health check failed for {endpoint}"
            
            data = response.json()
            assert 'status' in data
            assert data['status'] in ['healthy', 'degraded']

    def test_service_routing(self):
        """Test API Gateway routing to backend services"""
        service_endpoints = [
            f"{self.api_base_url}/api/v1/context/health",
            f"{self.api_base_url}/api/v1/llm/health", 
            f"{self.api_base_url}/api/v1/tts/health",
            f"{self.api_base_url}/api/v1/transcription/health"
        ]
        
        for endpoint in service_endpoints:
            response = requests.get(endpoint, timeout=self.timeout)
            assert response.status_code == 200, f"Service routing failed for {endpoint}"
            
            data = response.json()
            assert 'status' in data

    def test_llm_chat_completion(self):
        """Test LLM Gateway chat completion functionality"""
        payload = {
            "messages": [
                {"role": "user", "content": "Hello, this is a test message for integration testing."}
            ],
            "persona": "test",
            "max_tokens": 100
        }
        
        response = requests.post(
            f"{self.api_base_url}/api/v1/llm/chat/completions",
            json=payload,
            headers=self.headers,
            timeout=self.timeout
        )
        
        assert response.status_code == 200, f"LLM chat completion failed: {response.text}"
        
        data = response.json()
        assert 'choices' in data
        assert len(data['choices']) > 0
        assert 'message' in data['choices'][0]
        assert 'content' in data['choices'][0]['message']
        assert len(data['choices'][0]['message']['content']) > 0

    def test_context_embedding_creation(self):
        """Test Context Service embedding creation"""
        payload = {
            "text": "This is a test document for integration testing of the embedding system.",
            "metadata": {
                "test": True,
                "timestamp": time.time()
            }
        }
        
        response = requests.post(
            f"{self.api_base_url}/api/v1/context/embeddings",
            json=payload,
            headers=self.headers,
            timeout=self.timeout
        )
        
        assert response.status_code == 200, f"Embedding creation failed: {response.text}"
        
        data = response.json()
        assert 'embedding_id' in data or 'id' in data
        assert 'embedding' in data or 'vector' in data

    def test_tts_synthesis(self):
        """Test TTS Service speech synthesis"""
        payload = {
            "text": "Hello world, this is a test for text to speech synthesis.",
            "voice": "default",
            "speed": 1.0
        }
        
        response = requests.post(
            f"{self.api_base_url}/api/v1/tts/synthesize",
            json=payload,
            headers=self.headers,
            timeout=self.timeout
        )
        
        assert response.status_code == 200, f"TTS synthesis failed: {response.text}"
        
        # Response could be JSON with audio data or direct audio content
        if response.headers.get('content-type', '').startswith('application/json'):
            data = response.json()
            assert 'audio_data' in data or 'audio_url' in data
        else:
            # Direct audio response
            assert len(response.content) > 0

    def test_transcription_summary_styles(self):
        """Test Transcription Service summary styles endpoint"""
        response = requests.get(
            f"{self.api_base_url}/api/v1/transcription/summary-styles",
            timeout=self.timeout
        )
        
        assert response.status_code == 200, f"Summary styles request failed: {response.text}"
        
        data = response.json()
        assert 'styles' in data
        assert len(data['styles']) > 0
        
        # Check for expected summary styles
        style_names = [style['name'] for style in data['styles']]
        expected_styles = ['brief', 'detailed', 'themes', 'key_points', 'question_based']
        for expected_style in expected_styles:
            assert expected_style in style_names

    def test_chapter_summary_generation(self):
        """Test chapter summary generation"""
        payload = {
            "chapters": [
                {
                    "title": "Test Chapter",
                    "content": "This is test content for integration testing. It discusses various themes and introduces characters for analysis by the AI system.",
                    "start_time": 0,
                    "end_time": 300,
                    "book_id": "integration-test-book"
                }
            ],
            "summary_styles": ["brief", "detailed"]
        }
        
        response = requests.post(
            f"{self.api_base_url}/api/v1/transcription/generate-summaries",
            json=payload,
            headers=self.headers,
            timeout=self.timeout
        )
        
        assert response.status_code == 200, f"Summary generation failed: {response.text}"
        
        data = response.json()
        assert 'summaries' in data
        assert len(data['summaries']) > 0

    def test_question_generation(self):
        """Test AI question generation"""
        payload = {
            "chapter_text": "This is test chapter content that discusses important themes and introduces key characters for the story.",
            "question_types": ["comprehension", "analysis"],
            "difficulty_level": "intermediate",
            "reading_mode": "educational",
            "num_questions": 3
        }
        
        response = requests.post(
            f"{self.api_base_url}/api/v1/transcription/generate-questions",
            json=payload,
            headers=self.headers,
            timeout=self.timeout
        )
        
        assert response.status_code == 200, f"Question generation failed: {response.text}"
        
        data = response.json()
        assert 'questions' in data
        assert len(data['questions']) > 0
        assert len(data['questions']) <= 3  # Should respect num_questions limit

    def test_metrics_endpoint(self):
        """Test Prometheus metrics endpoint"""
        response = requests.get(f"{self.api_base_url}/metrics", timeout=self.timeout)
        
        assert response.status_code == 200, f"Metrics endpoint failed: {response.text}"
        
        # Check that response contains Prometheus metrics format
        metrics_text = response.text
        assert 'http_requests_total' in metrics_text or 'http_request_duration_seconds' in metrics_text

    def test_error_handling(self):
        """Test API error handling"""
        # Test 404 for non-existent endpoint
        response = requests.get(f"{self.api_base_url}/nonexistent-endpoint", timeout=self.timeout)
        assert response.status_code == 404
        
        # Test 422 for invalid payload
        invalid_payload = {"invalid": "data"}
        response = requests.post(
            f"{self.api_base_url}/api/v1/llm/chat/completions",
            json=invalid_payload,
            headers=self.headers,
            timeout=self.timeout
        )
        assert response.status_code == 422

    def test_cors_headers(self):
        """Test CORS headers for web client compatibility"""
        response = requests.options(f"{self.api_base_url}/api/v1/llm/health", timeout=self.timeout)
        
        # Should have CORS headers
        assert 'Access-Control-Allow-Origin' in response.headers
        assert 'Access-Control-Allow-Methods' in response.headers

    def test_response_times(self):
        """Test response time performance"""
        start_time = time.time()
        response = requests.get(f"{self.api_base_url}/health", timeout=self.timeout)
        end_time = time.time()
        
        assert response.status_code == 200
        assert (end_time - start_time) < 1.0, "Health check took longer than 1 second"

    def test_concurrent_requests(self):
        """Test handling of concurrent requests"""
        import concurrent.futures
        
        def make_request():
            response = requests.get(f"{self.api_base_url}/health", timeout=self.timeout)
            return response.status_code
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        # All requests should succeed
        assert all(status == 200 for status in results), f"Some concurrent requests failed: {results}"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])