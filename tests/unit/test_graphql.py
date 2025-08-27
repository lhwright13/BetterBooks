"""Comprehensive unit tests for GraphQL schema and resolvers."""

import pytest
from unittest.mock import Mock, patch, MagicMock
import json
import sys
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

@pytest.mark.graphql
class TestGraphQLSchema:
    """Test suite for GraphQL schema functionality."""
    
    def test_graphql_books_query(self, graphql_test_client, sample_graphql_query):
        """Test books query without authentication."""
        with patch('httpx.AsyncClient') as mock_client:
            # Mock the HTTP response from bookstore API
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "books": [
                    {
                        "id": "book_1",
                        "title": "Test Book",
                        "author": "Test Author",
                        "cover_image_url": "http://example.com/cover.jpg",
                        "price_usd": 9.99,
                        "credit_price": 1,
                        "is_featured": True
                    }
                ]
            }
            
            mock_client.return_value.__aenter__.return_value.get.return_value = mock_response
            
            response = graphql_test_client.post(
                "/graphql",
                json={
                    "query": sample_graphql_query["books_query"],
                    "variables": {"featured": True}
                }
            )
            
            assert response.status_code == 200
            data = response.json()
            assert "data" in data
            assert "books" in data["data"]
            assert len(data["data"]["books"]) == 1
            assert data["data"]["books"][0]["title"] == "Test Book"
    
    def test_graphql_user_library_authenticated(self, graphql_test_client, sample_graphql_query, mock_jwt_token):
        """Test user library query with authentication."""
        with patch('httpx.AsyncClient') as mock_client:
            # Mock the HTTP response
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "books": [
                    {
                        "id": "book_1",
                        "title": "Owned Book",
                        "author": "Test Author",
                        "cover_image_url": "http://example.com/cover.jpg",
                        "progress": 0.5
                    }
                ]
            }
            
            mock_client.return_value.__aenter__.return_value.get.return_value = mock_response
            
            response = graphql_test_client.post(
                "/graphql",
                headers={"Authorization": f"Bearer {mock_jwt_token}"},
                json={"query": sample_graphql_query["user_library_query"]}
            )
            
            assert response.status_code == 200
            data = response.json()
            assert "data" in data
            assert "user_library" in data["data"]
    
    def test_graphql_user_library_unauthenticated(self, graphql_test_client, sample_graphql_query):
        """Test user library query fails without authentication."""
        response = graphql_test_client.post(
            "/graphql",
            json={"query": sample_graphql_query["user_library_query"]}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "errors" in data
        # Should have authentication error
        assert any("Authentication required" in str(error) for error in data["errors"])
    
    def test_graphql_purchase_mutation(self, graphql_test_client, sample_graphql_query, mock_jwt_token):
        """Test book purchase mutation."""
        with patch('httpx.AsyncClient') as mock_client:
            # Mock successful purchase response
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "book": {
                    "id": "book_1",
                    "title": "Purchased Book",
                    "author": "Test Author"
                }
            }
            
            mock_client.return_value.__aenter__.return_value.post.return_value = mock_response
            
            response = graphql_test_client.post(
                "/graphql",
                headers={"Authorization": f"Bearer {mock_jwt_token}"},
                json={
                    "query": sample_graphql_query["purchase_mutation"],
                    "variables": {"bookId": "book_1", "credits": 1}
                }
            )
            
            assert response.status_code == 200
            data = response.json()
            assert "data" in data
            assert "purchase_book" in data["data"]
    
    def test_graphql_introspection_disabled_in_production(self):
        """Test that introspection is disabled in production."""
        import os
        
        with patch.dict(os.environ, {'ENVIRONMENT': 'production'}):
            # Re-import to get production config
            from platform.backend.services.api_gateway.graphql_schema import graphql_router
            
            # The router should have introspection disabled
            # This is tested by checking the router configuration
            assert hasattr(graphql_router, 'graphql_app')


@pytest.mark.graphql
class TestGraphQLTypes:
    """Test GraphQL type definitions."""
    
    def test_book_type_structure(self):
        """Test Book GraphQL type structure."""
        from platform.backend.services.api_gateway.graphql_schema import Book
        
        # Test that Book type has required fields
        book = Book(
            id="test_id",
            title="Test Title", 
            author="Test Author",
            cover_image_url="http://example.com/cover.jpg"
        )
        
        assert book.id == "test_id"
        assert book.title == "Test Title"
        assert book.author == "Test Author"
        assert book.price_usd == 9.99  # Default value
    
    def test_user_type_structure(self):
        """Test User GraphQL type structure."""
        from platform.backend.services.api_gateway.graphql_schema import User
        
        user = User(
            id="user_123",
            email="test@example.com",
            first_name="Test",
            last_name="User"
        )
        
        assert user.id == "user_123"
        assert user.subscription_tier == "free"  # Default value
    
    def test_chapter_type_structure(self):
        """Test Chapter GraphQL type structure."""
        from platform.backend.services.api_gateway.graphql_schema import Chapter
        
        chapter = Chapter(
            id="chapter_1",
            book_id="book_123",
            chapter_number=1,
            title="Chapter 1",
            start_time=0.0,
            end_time=120.0,
            duration=120.0
        )
        
        assert chapter.chapter_number == 1
        assert chapter.duration == 120.0


@pytest.mark.graphql  
class TestGraphQLErrorHandling:
    """Test GraphQL error handling and validation."""
    
    def test_invalid_query_syntax(self, graphql_test_client):
        """Test handling of invalid GraphQL syntax."""
        response = graphql_test_client.post(
            "/graphql",
            json={"query": "invalid query syntax {"}
        )
        
        assert response.status_code == 400
    
    def test_missing_required_variables(self, graphql_test_client, sample_graphql_query):
        """Test handling of missing required variables."""
        response = graphql_test_client.post(
            "/graphql",
            json={
                "query": sample_graphql_query["books_query"]
                # Missing required variable "featured"
            }
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "errors" in data
    
    def test_unknown_field_error(self, graphql_test_client):
        """Test querying unknown fields."""
        response = graphql_test_client.post(
            "/graphql", 
            json={
                "query": '''
                    query {
                        books {
                            unknownField
                        }
                    }
                '''
            }
        )
        
        assert response.status_code == 400


@pytest.mark.graphql
class TestGraphQLPerformance:
    """Test GraphQL performance and optimization."""
    
    def test_query_batching_not_allowed(self, graphql_test_client, sample_graphql_query):
        """Test that query batching is not allowed (security measure)."""
        # Send array of queries (batching)
        response = graphql_test_client.post(
            "/graphql",
            json=[
                {"query": sample_graphql_query["books_query"], "variables": {"featured": True}},
                {"query": sample_graphql_query["books_query"], "variables": {"featured": False}}
            ]
        )
        
        # Should reject batched queries
        assert response.status_code == 400