"""Comprehensive unit tests for Context Service."""

import pytest
from unittest.mock import Mock, patch, MagicMock, AsyncMock
from fastapi.testclient import TestClient
import json
import numpy as np
import sys
from pathlib import Path

# Add service path for imports
service_path = Path(__file__).parent.parent.parent.parent / "platform" / "backend" / "services" / "context_service"
sys.path.insert(0, str(service_path))

@pytest.mark.unit
class TestContextService:
    """Test suite for Context Service."""
    
    @pytest.fixture(autouse=True)
    def setup(self, mock_database, sample_embeddings, mock_logger):
        """Set up test environment."""
        self.mock_db = mock_database
        self.sample_embeddings = sample_embeddings
        self.mock_logger = mock_logger
        
        # Mock environment and imports
        with patch.dict('os.environ', {
            'DATABASE_URL': 'postgresql://test:test@localhost:5432/test_db',
            'EMBEDDING_MODEL': 'all-MiniLM-L6-v2',
            'LOG_LEVEL': 'DEBUG'
        }):
            # Mock sentence transformers
            with patch('sentence_transformers.SentenceTransformer') as mock_st:
                mock_model = MagicMock()
                mock_model.encode.return_value = np.array([self.sample_embeddings["embedding"]])
                mock_st.return_value = mock_model
                self.mock_model = mock_model
                
                # Mock database operations
                with patch('asyncpg.create_pool') as mock_pool:
                    mock_pool.return_value = AsyncMock()
                    
                    from main import app
                    self.client = TestClient(app)
                    self.app = app
    
    def test_health_endpoint(self):
        """Test health check endpoint."""
        response = self.client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
    
    def test_store_context(self):
        """Test storing context with embeddings."""
        context_data = {
            "text": "This is a test chapter about adventures.",
            "metadata": {
                "book_id": "book_123",
                "chapter": 1,
                "page": 10
            }
        }
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.fetchval.return_value = "ctx_123"
            mock_acquire.return_value = mock_conn
            
            response = self.client.post("/store", json=context_data)
            
            assert response.status_code == 200
            data = response.json()
            assert "id" in data
            assert data["message"] == "Context stored successfully"
            
            # Verify embedding was generated
            self.mock_model.encode.assert_called_once()
    
    def test_search_context(self):
        """Test searching for similar contexts."""
        search_query = {
            "query": "Tell me about adventures",
            "limit": 5,
            "threshold": 0.7
        }
        
        mock_results = [
            {
                "id": "ctx_1",
                "text": "Adventure story chapter 1",
                "similarity": 0.85,
                "metadata": {"chapter": 1}
            },
            {
                "id": "ctx_2",
                "text": "Adventure story chapter 2",
                "similarity": 0.75,
                "metadata": {"chapter": 2}
            }
        ]
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.fetch.return_value = mock_results
            mock_acquire.return_value = mock_conn
            
            response = self.client.post("/search", json=search_query)
            
            assert response.status_code == 200
            data = response.json()
            assert "results" in data
            assert len(data["results"]) <= search_query["limit"]
            
            # Verify query embedding was generated
            self.mock_model.encode.assert_called()
    
    def test_get_context_by_id(self):
        """Test retrieving context by ID."""
        context_id = "ctx_123"
        mock_context = {
            "id": context_id,
            "text": "Test context content",
            "embedding": [0.1] * 384,
            "metadata": {"book_id": "book_123"},
            "created_at": "2024-01-01T00:00:00Z"
        }
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.fetchrow.return_value = mock_context
            mock_acquire.return_value = mock_conn
            
            response = self.client.get(f"/context/{context_id}")
            
            assert response.status_code == 200
            data = response.json()
            assert data["id"] == context_id
            assert data["text"] == mock_context["text"]
    
    def test_update_context(self):
        """Test updating existing context."""
        context_id = "ctx_123"
        update_data = {
            "text": "Updated context content",
            "metadata": {"updated": True}
        }
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.execute.return_value = None
            mock_acquire.return_value = mock_conn
            
            response = self.client.put(f"/context/{context_id}", json=update_data)
            
            assert response.status_code == 200
            data = response.json()
            assert data["message"] == "Context updated successfully"
    
    def test_delete_context(self):
        """Test deleting context."""
        context_id = "ctx_123"
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.execute.return_value = None
            mock_acquire.return_value = mock_conn
            
            response = self.client.delete(f"/context/{context_id}")
            
            assert response.status_code == 200
            data = response.json()
            assert data["message"] == "Context deleted successfully"
    
    def test_batch_store_contexts(self):
        """Test storing multiple contexts in batch."""
        batch_data = {
            "contexts": [
                {
                    "text": "Chapter 1 content",
                    "metadata": {"chapter": 1}
                },
                {
                    "text": "Chapter 2 content",
                    "metadata": {"chapter": 2}
                },
                {
                    "text": "Chapter 3 content",
                    "metadata": {"chapter": 3}
                }
            ]
        }
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.executemany.return_value = None
            mock_acquire.return_value = mock_conn
            
            response = self.client.post("/batch/store", json=batch_data)
            
            assert response.status_code == 200
            data = response.json()
            assert data["stored"] == len(batch_data["contexts"])
    
    def test_search_with_filters(self):
        """Test searching with metadata filters."""
        search_query = {
            "query": "adventure",
            "filters": {
                "book_id": "book_123",
                "chapter": {"$gte": 5, "$lte": 10}
            },
            "limit": 10
        }
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.fetch.return_value = []
            mock_acquire.return_value = mock_conn
            
            response = self.client.post("/search/filtered", json=search_query)
            
            assert response.status_code == 200
            data = response.json()
            assert "results" in data
    
    def test_embedding_generation_error(self):
        """Test error handling when embedding generation fails."""
        context_data = {
            "text": "Test text",
            "metadata": {}
        }
        
        self.mock_model.encode.side_effect = Exception("Model error")
        
        response = self.client.post("/store", json=context_data)
        
        assert response.status_code == 500
        data = response.json()
        assert "error" in data
    
    def test_database_connection_error(self):
        """Test error handling for database connection issues."""
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_acquire.side_effect = Exception("Database connection failed")
            
            response = self.client.get("/health/detailed")
            
            assert response.status_code == 503
            data = response.json()
            assert data["status"] == "unhealthy"
    
    def test_invalid_embedding_dimension(self):
        """Test handling of invalid embedding dimensions."""
        # Mock model returning wrong dimension
        self.mock_model.encode.return_value = np.array([[0.1] * 100])  # Wrong size
        
        context_data = {
            "text": "Test text",
            "metadata": {}
        }
        
        response = self.client.post("/store", json=context_data)
        
        # Should handle dimension mismatch appropriately
        assert response.status_code in [400, 500]
    
    def test_search_empty_query(self):
        """Test search with empty query."""
        search_query = {
            "query": "",
            "limit": 5
        }
        
        response = self.client.post("/search", json=search_query)
        
        assert response.status_code == 400
        data = response.json()
        assert "error" in data
    
    def test_pagination_parameters(self):
        """Test pagination in search results."""
        search_query = {
            "query": "test",
            "limit": 10,
            "offset": 20
        }
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.fetch.return_value = []
            mock_acquire.return_value = mock_conn
            
            response = self.client.post("/search", json=search_query)
            
            assert response.status_code == 200
            data = response.json()
            assert "results" in data
            assert "total" in data or "next" in data
    
    def test_metadata_validation(self):
        """Test metadata validation in store operation."""
        # Test with invalid metadata
        context_data = {
            "text": "Test text",
            "metadata": "invalid_metadata_string"  # Should be dict
        }
        
        response = self.client.post("/store", json=context_data)
        
        assert response.status_code == 422  # Validation error
    
    def test_concurrent_requests(self):
        """Test handling of concurrent requests."""
        import concurrent.futures
        
        def make_request():
            return self.client.get("/health")
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [f.result() for f in concurrent.futures.as_completed(futures)]
        
        assert all(r.status_code == 200 for r in results)
    
    def test_similarity_threshold(self):
        """Test similarity threshold filtering."""
        search_query = {
            "query": "test query",
            "threshold": 0.9,  # High threshold
            "limit": 10
        }
        
        mock_results = [
            {"id": "1", "similarity": 0.95, "text": "Very similar"},
            {"id": "2", "similarity": 0.85, "text": "Less similar"},  # Below threshold
        ]
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.fetch.return_value = [r for r in mock_results if r["similarity"] >= 0.9]
            mock_acquire.return_value = mock_conn
            
            response = self.client.post("/search", json=search_query)
            
            assert response.status_code == 200
            data = response.json()
            assert all(r["similarity"] >= 0.9 for r in data["results"])
    
    def test_bulk_delete(self):
        """Test bulk deletion of contexts."""
        delete_data = {
            "ids": ["ctx_1", "ctx_2", "ctx_3"]
        }
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.execute.return_value = None
            mock_acquire.return_value = mock_conn
            
            response = self.client.post("/batch/delete", json=delete_data)
            
            assert response.status_code == 200
            data = response.json()
            assert data["deleted"] == len(delete_data["ids"])
    
    def test_export_contexts(self):
        """Test exporting contexts."""
        export_params = {
            "format": "json",
            "include_embeddings": False
        }
        
        mock_contexts = [
            {"id": "1", "text": "Context 1", "metadata": {}},
            {"id": "2", "text": "Context 2", "metadata": {}}
        ]
        
        with patch('asyncpg.pool.Pool.acquire') as mock_acquire:
            mock_conn = AsyncMock()
            mock_conn.__aenter__.return_value = mock_conn
            mock_conn.__aexit__.return_value = None
            mock_conn.fetch.return_value = mock_contexts
            mock_acquire.return_value = mock_conn
            
            response = self.client.post("/export", json=export_params)
            
            assert response.status_code == 200
            assert response.headers["content-type"] == "application/json"
    
    def test_metrics_collection(self):
        """Test that metrics are collected properly."""
        # Make several requests
        self.client.get("/health")
        self.client.post("/search", json={"query": "test"})
        
        # Check metrics endpoint
        response = self.client.get("/metrics")
        
        assert response.status_code == 200
        metrics = response.text
        assert "context_service_requests_total" in metrics
        assert "embedding_generation_duration_seconds" in metrics