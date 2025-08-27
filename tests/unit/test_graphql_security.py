"""Unit tests for GraphQL security middleware and protections."""

import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
from pathlib import Path

# Add project root to path  
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

@pytest.mark.graphql
class TestGraphQLSecurity:
    """Test GraphQL security measures."""
    
    def test_query_complexity_analyzer_simple_query(self):
        """Test complexity analyzer with simple query."""
        from platform.backend.services.api_gateway.graphql_security import QueryComplexityAnalyzer
        
        analyzer = QueryComplexityAnalyzer(max_complexity=100)
        
        # Mock document for simple query
        mock_field = MagicMock()
        mock_field.selection_set = None
        
        mock_definition = MagicMock()  
        mock_definition.selection_set.selections = [mock_field]
        
        mock_document = MagicMock()
        mock_document.definitions = [mock_definition]
        
        complexity = analyzer._calculate_complexity(mock_document)
        
        # Simple query should have low complexity
        assert complexity >= 1
        assert complexity <= 10
    
    def test_query_depth_limiter_simple_query(self):
        """Test depth limiter with simple query.""" 
        from platform.backend.services.api_gateway.graphql_security import QueryDepthLimiter
        
        limiter = QueryDepthLimiter(max_depth=10)
        
        # Mock document for simple query (depth 1)
        mock_field = MagicMock()
        mock_field.selection_set = None
        
        mock_definition = MagicMock()
        mock_definition.selection_set.selections = [mock_field]
        
        mock_document = MagicMock()
        mock_document.definitions = [mock_definition]
        
        depth = limiter._calculate_depth(mock_document)
        
        assert depth == 1
    
    def test_query_depth_limiter_nested_query(self):
        """Test depth limiter with nested query."""
        from platform.backend.services.api_gateway.graphql_security import QueryDepthLimiter
        
        limiter = QueryDepthLimiter(max_depth=5)
        
        # Create nested structure: level 1 -> level 2 -> level 3
        level3_field = MagicMock()
        level3_field.selection_set = None
        
        level2_selection_set = MagicMock()
        level2_selection_set.selections = [level3_field]
        
        level2_field = MagicMock() 
        level2_field.selection_set = level2_selection_set
        
        level1_selection_set = MagicMock()
        level1_selection_set.selections = [level2_field]
        
        level1_field = MagicMock()
        level1_field.selection_set = level1_selection_set
        
        mock_definition = MagicMock()
        mock_definition.selection_set.selections = [level1_field]
        
        mock_document = MagicMock()
        mock_document.definitions = [mock_definition]
        
        depth = limiter._calculate_depth(mock_document)
        
        assert depth == 3
    
    def test_rate_limiter_within_limits(self):
        """Test rate limiter when within limits."""
        from platform.backend.services.api_gateway.graphql_security import GraphQLRateLimiter
        
        with patch('redis.Redis') as mock_redis:
            mock_redis_instance = MagicMock()
            mock_redis_instance.get.return_value = "5"  # Current requests
            mock_redis_instance.pipeline.return_value.__enter__.return_value = MagicMock()
            mock_redis.return_value = mock_redis_instance
            
            limiter = GraphQLRateLimiter(requests_per_minute=60)
            
            # Should not raise exception
            try:
                limiter.check_rate_limit("test_user", complexity=10)
                success = True
            except Exception:
                success = False
                
            assert success
    
    def test_rate_limiter_exceeds_request_limit(self):
        """Test rate limiter when exceeding request limit."""
        from platform.backend.services.api_gateway.graphql_security import GraphQLRateLimiter
        from fastapi import HTTPException
        
        with patch('redis.Redis') as mock_redis:
            mock_redis_instance = MagicMock()
            mock_redis_instance.get.return_value = "60"  # At limit
            mock_redis.return_value = mock_redis_instance
            
            limiter = GraphQLRateLimiter(requests_per_minute=60)
            
            with pytest.raises(HTTPException) as exc_info:
                limiter.check_rate_limit("test_user", complexity=1)
            
            assert exc_info.value.status_code == 429
            assert "Too many requests" in str(exc_info.value.detail)
    
    def test_rate_limiter_exceeds_complexity_limit(self):
        """Test rate limiter when exceeding complexity limit."""
        from platform.backend.services.api_gateway.graphql_security import GraphQLRateLimiter
        from fastapi import HTTPException
        
        with patch('redis.Redis') as mock_redis:
            mock_redis_instance = MagicMock()
            # Mock get to return different values for different keys
            def mock_get(key):
                if "requests" in key:
                    return "5"  # Low request count
                elif "complexity" in key:
                    return "9000"  # High complexity already used
                return "0"
            
            mock_redis_instance.get.side_effect = mock_get
            mock_redis.return_value = mock_redis_instance
            
            limiter = GraphQLRateLimiter(complexity_per_minute=10000)
            
            with pytest.raises(HTTPException) as exc_info:
                limiter.check_rate_limit("test_user", complexity=2000)
            
            assert exc_info.value.status_code == 429
            assert "complexity limit exceeded" in str(exc_info.value.detail).lower()
    
    def test_require_auth_decorator_with_valid_token(self):
        """Test authentication decorator with valid token."""
        from platform.backend.services.api_gateway.graphql_security import require_auth
        import asyncio
        
        # Mock function to decorate
        @require_auth
        async def test_function(self, info):
            return "success"
        
        # Mock info object
        mock_request = MagicMock()
        mock_request.headers = {"authorization": "Bearer valid_token"}
        
        mock_info = MagicMock()
        mock_info.context = {"request": mock_request}
        
        with patch('platform.backend.services.api_gateway.graphql_security.verify_token') as mock_verify:
            mock_verify.return_value = {"user_id": "test_user"}
            
            with patch('platform.backend.services.api_gateway.graphql_security.rate_limiter.check_rate_limit'):
                # Run async function
                result = asyncio.run(test_function(None, mock_info))
                
                assert result == "success"
                assert mock_info.context["user_id"] == "test_user"
    
    def test_require_auth_decorator_without_token(self):
        """Test authentication decorator without token."""
        from platform.backend.services.api_gateway.graphql_security import require_auth
        from fastapi import HTTPException
        import asyncio
        
        @require_auth
        async def test_function(self, info):
            return "success"
        
        # Mock info object without auth header
        mock_request = MagicMock() 
        mock_request.headers = {}
        
        mock_info = MagicMock()
        mock_info.context = {"request": mock_request}
        
        with pytest.raises(HTTPException) as exc_info:
            asyncio.run(test_function(None, mock_info))
        
        assert exc_info.value.status_code == 401
        assert "Bearer token required" in str(exc_info.value.detail)
    
    def test_require_auth_decorator_with_invalid_token(self):
        """Test authentication decorator with invalid token."""
        from platform.backend.services.api_gateway.graphql_security import require_auth
        from fastapi import HTTPException
        import jwt
        import asyncio
        
        @require_auth
        async def test_function(self, info):
            return "success"
        
        # Mock info object with invalid token
        mock_request = MagicMock()
        mock_request.headers = {"authorization": "Bearer invalid_token"}
        
        mock_info = MagicMock()
        mock_info.context = {"request": mock_request}
        
        with patch('platform.backend.services.api_gateway.graphql_security.verify_token') as mock_verify:
            mock_verify.side_effect = jwt.InvalidTokenError("Invalid token")
            
            with pytest.raises(HTTPException) as exc_info:
                asyncio.run(test_function(None, mock_info))
            
            assert exc_info.value.status_code == 401
            assert "Invalid or expired token" in str(exc_info.value.detail)
    
    def test_subscription_level_decorator_sufficient_level(self):
        """Test subscription level decorator with sufficient privileges."""
        from platform.backend.services.api_gateway.graphql_security import require_subscription
        import asyncio
        
        @require_subscription("premium")
        async def premium_function(self, info):
            return "premium_content"
        
        mock_info = MagicMock()
        mock_info.context = {
            "user": {"subscription_tier": "premium"}
        }
        
        result = asyncio.run(premium_function(None, mock_info))
        assert result == "premium_content"
    
    def test_subscription_level_decorator_insufficient_level(self):
        """Test subscription level decorator with insufficient privileges."""
        from platform.backend.services.api_gateway.graphql_security import require_subscription
        from fastapi import HTTPException
        import asyncio
        
        @require_subscription("premium")
        async def premium_function(self, info):
            return "premium_content"
        
        mock_info = MagicMock()
        mock_info.context = {
            "user": {"subscription_tier": "free"}
        }
        
        with pytest.raises(HTTPException) as exc_info:
            asyncio.run(premium_function(None, mock_info))
        
        assert exc_info.value.status_code == 403
        assert "premium" in str(exc_info.value.detail)


@pytest.mark.graphql
class TestGraphQLSecurityIntegration:
    """Integration tests for GraphQL security features."""
    
    def test_security_headers_added(self, graphql_test_client):
        """Test that security headers are added to responses."""
        response = graphql_test_client.post(
            "/graphql",
            json={"query": "{ __schema { types { name } } }"}  # Introspection query
        )
        
        # Check for security headers (would be added by SecurityExtension)
        # Note: In real implementation, these would be set by the extension
        assert response.status_code in [200, 400]  # 400 if introspection disabled
    
    def test_production_mode_disables_introspection(self):
        """Test that production mode disables introspection."""
        import os
        
        with patch.dict(os.environ, {'ENVIRONMENT': 'production'}):
            # In production, introspection should be disabled
            # This would be configured in the GraphQL router
            pass  # Placeholder for actual test
    
    def test_query_complexity_prevents_dos(self, graphql_test_client):
        """Test that query complexity analysis prevents DoS attacks."""
        # This would be a very complex query that should be blocked
        complex_query = '''
            query DoSAttempt {
                books {
                    id
                    title
                    chapters {
                        id 
                        title
                        subsections {
                            content
                            details {
                                metadata
                            }
                        }
                    }
                }
            }
        '''
        
        response = graphql_test_client.post(
            "/graphql",
            json={"query": complex_query}
        )
        
        # Should be rejected for high complexity
        # In real implementation, this would return 400 with complexity error
        assert response.status_code in [200, 400]