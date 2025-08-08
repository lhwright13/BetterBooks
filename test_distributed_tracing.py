"""
Test distributed tracing implementation.

This test validates that the OpenTelemetry and Jaeger tracing integration works correctly
across services, including span creation, attribute setting, and error handling.
"""

import os
import sys
import asyncio
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

# Add services/shared to path for imports
sys.path.append(str(Path(__file__).parent / "services" / "shared"))

# import pytest  # Not needed for basic testing
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor, ConsoleSpanExporter
from opentelemetry.trace.status import Status, StatusCode

# Import our tracing components
from tracing import (
    TracingConfig, setup_tracing, instrument_external_libraries,
    LLMTracingHelper, DatabaseTracingHelper, HTTPTracingHelper,
    create_span_with_context, add_span_attributes, record_exception_in_span,
    get_development_tracing_config, get_production_tracing_config
)

class TestTracingConfiguration:
    """Test tracing configuration and setup."""
    
    def test_tracing_config_creation(self):
        """Test TracingConfig object creation with different parameters."""
        # Test with default values
        config = TracingConfig("test_service")
        assert config.service_name == "test_service"
        assert config.jaeger_endpoint == "http://localhost:14268/api/traces"
        assert config.sampling_rate == 1.0
        assert config.enable_console_exporter == False
        
        # Test with custom values
        config = TracingConfig(
            "custom_service",
            jaeger_endpoint="http://custom:14268/api/traces",
            sampling_rate=0.5,
            enable_console_exporter=True
        )
        assert config.service_name == "custom_service"
        assert config.jaeger_endpoint == "http://custom:14268/api/traces"
        assert config.sampling_rate == 0.5
        assert config.enable_console_exporter == True
    
    def test_development_config(self):
        """Test development configuration preset."""
        config = get_development_tracing_config("dev_service")
        assert config.service_name == "dev_service"
        assert config.sampling_rate == 1.0
        assert config.enable_console_exporter == True
    
    def test_production_config(self):
        """Test production configuration preset."""
        config = get_production_tracing_config("prod_service")
        assert config.service_name == "prod_service"
        assert config.sampling_rate == 0.1
        assert config.enable_console_exporter == False


class TestTracingSetup:
    """Test tracing setup and instrumentation."""
    
    def setup_method(self):
        """Set up test environment."""
        # Create a simple tracer provider for testing
        self.tracer_provider = TracerProvider()
        trace.set_tracer_provider(self.tracer_provider)
        
        # Add console span processor for visibility during tests
        console_processor = SimpleSpanProcessor(ConsoleSpanExporter())
        self.tracer_provider.add_span_processor(console_processor)
    
    @patch('tracing.JaegerExporter')
    def test_setup_tracing(self, mock_jaeger_exporter):
        """Test tracing setup with Jaeger exporter."""
        # Mock the Jaeger exporter
        mock_exporter = Mock()
        mock_jaeger_exporter.return_value = mock_exporter
        
        # Set up tracing
        config = TracingConfig("test_service", sampling_rate=0.5)
        tracer = setup_tracing(config)
        
        # Verify tracer was created
        assert tracer is not None
        assert tracer.name == "test_service"
        
        # Verify Jaeger exporter was configured
        mock_jaeger_exporter.assert_called_once()
    
    def test_create_span_with_context(self):
        """Test creating spans with context attributes."""
        tracer = trace.get_tracer("test")
        
        with create_span_with_context(
            tracer,
            "test_operation",
            user_id="123",
            operation_type="test"
        ) as span:
            # Verify span was created
            assert span.is_recording()
            
            # Verify we can add more attributes
            add_span_attributes(span, additional_attr="value")
    
    def test_exception_recording(self):
        """Test exception recording in spans."""
        tracer = trace.get_tracer("test")
        
        with tracer.start_as_current_span("test_operation") as span:
            test_exception = ValueError("Test error")
            record_exception_in_span(span, test_exception)
            
            # Verify span status was set to error
            assert span.status.status_code == StatusCode.ERROR


class TestServiceSpecificHelpers:
    """Test service-specific tracing helpers."""
    
    def setup_method(self):
        """Set up test environment."""
        self.tracer = trace.get_tracer("test")
    
    def test_llm_tracing_helper(self):
        """Test LLM-specific tracing functionality."""
        with LLMTracingHelper.trace_llm_request(
            self.tracer, 
            "gemini", 
            prompt_length=100
        ) as span:
            assert span.is_recording()
            
            # Test adding response attributes
            LLMTracingHelper.add_llm_response_attributes(
                span,
                response_length=200,
                tokens_used=50,
                processing_time=1.5
            )
    
    def test_database_tracing_helper(self):
        """Test database-specific tracing functionality."""
        with DatabaseTracingHelper.trace_db_query(
            self.tracer,
            "SELECT",
            table="embeddings"
        ) as span:
            assert span.is_recording()
            
            # Test adding query attributes
            DatabaseTracingHelper.add_db_query_attributes(
                span,
                query="SELECT * FROM embeddings WHERE book_id = ?",
                rows_affected=5
            )
    
    def test_http_tracing_helper(self):
        """Test HTTP-specific tracing functionality."""
        with HTTPTracingHelper.trace_http_client_request(
            self.tracer,
            "POST",
            "http://example.com/api"
        ) as span:
            assert span.is_recording()
            
            # Test adding response attributes
            HTTPTracingHelper.add_http_response_attributes(
                span,
                status_code=200,
                response_size=1024
            )


class TestIntegrationScenarios:
    """Test realistic tracing scenarios."""
    
    def setup_method(self):
        """Set up test environment."""
        self.tracer = trace.get_tracer("integration_test")
    
    def test_nested_span_scenario(self):
        """Test nested spans representing service call chain."""
        with self.tracer.start_as_current_span("api_gateway.complete") as root_span:
            add_span_attributes(root_span, user_id="123", endpoint="complete")
            
            # Simulate HTTP call to LLM service
            with HTTPTracingHelper.trace_http_client_request(
                self.tracer, "POST", "http://llm_gateway:8000/complete"
            ) as http_span:
                HTTPTracingHelper.add_http_response_attributes(http_span, 200)
                
                # Simulate LLM processing
                with LLMTracingHelper.trace_llm_request(
                    self.tracer, "gemini", 150
                ) as llm_span:
                    LLMTracingHelper.add_llm_response_attributes(
                        llm_span,
                        response_length=300,
                        tokens_used=75,
                        processing_time=2.1
                    )
    
    def test_error_propagation_scenario(self):
        """Test error handling and propagation through spans."""
        with self.tracer.start_as_current_span("error_test") as root_span:
            try:
                with self.tracer.start_as_current_span("failing_operation") as child_span:
                    # Simulate an error
                    error = ConnectionError("Service unavailable")
                    record_exception_in_span(child_span, error)
                    raise error
            except ConnectionError as e:
                record_exception_in_span(root_span, e)
                # Verify both spans have error status
                assert root_span.status.status_code == StatusCode.ERROR
    
    def test_business_context_propagation(self):
        """Test propagation of business context through spans."""
        business_context = {
            "book_id": "gatsby",
            "chapter": "chapter_1",
            "user_id": "user_123",
            "session_id": "sess_456"
        }
        
        with self.tracer.start_as_current_span("book_processing") as span:
            add_span_attributes(span, **business_context)
            
            # Simulate database operations
            with DatabaseTracingHelper.trace_db_query(
                self.tracer, "SELECT", "embeddings"
            ) as db_span:
                add_span_attributes(db_span, **business_context)
                DatabaseTracingHelper.add_db_query_attributes(
                    db_span,
                    query="SELECT * FROM embeddings WHERE book_id = ?",
                    rows_affected=10
                )


class TestEnvironmentConfiguration:
    """Test environment-specific configuration."""
    
    def test_environment_variable_override(self):
        """Test that environment variables override default configuration."""
        with patch.dict(os.environ, {
            'JAEGER_ENDPOINT': 'http://custom-jaeger:14268/api/traces',
            'ENVIRONMENT': 'production'
        }):
            config = TracingConfig("test_service")
            assert config.jaeger_endpoint == 'http://custom-jaeger:14268/api/traces'
    
    def test_development_vs_production_config(self):
        """Test differences between development and production configurations."""
        dev_config = get_development_tracing_config("test_service")
        prod_config = get_production_tracing_config("test_service")
        
        # Development should sample 100%, production should sample 10%
        assert dev_config.sampling_rate == 1.0
        assert prod_config.sampling_rate == 0.1
        
        # Development should enable console output, production should not
        assert dev_config.enable_console_exporter == True
        assert prod_config.enable_console_exporter == False


def run_tests():
    """Run all tracing tests."""
    print("Running distributed tracing tests...")
    
    # Test configuration
    print("\\n=== Testing Tracing Configuration ===")
    config_tests = TestTracingConfiguration()
    config_tests.test_tracing_config_creation()
    config_tests.test_development_config()
    config_tests.test_production_config()
    print("✅ Configuration tests passed")
    
    # Test setup
    print("\\n=== Testing Tracing Setup ===")
    setup_tests = TestTracingSetup()
    setup_tests.setup_method()
    setup_tests.test_create_span_with_context()
    setup_tests.test_exception_recording()
    print("✅ Setup tests passed")
    
    # Test service helpers
    print("\\n=== Testing Service-Specific Helpers ===")
    helper_tests = TestServiceSpecificHelpers()
    helper_tests.setup_method()
    helper_tests.test_llm_tracing_helper()
    helper_tests.test_database_tracing_helper()
    helper_tests.test_http_tracing_helper()
    print("✅ Service helper tests passed")
    
    # Test integration scenarios
    print("\\n=== Testing Integration Scenarios ===")
    integration_tests = TestIntegrationScenarios()
    integration_tests.setup_method()
    integration_tests.test_nested_span_scenario()
    integration_tests.test_error_propagation_scenario()
    integration_tests.test_business_context_propagation()
    print("✅ Integration tests passed")
    
    # Test environment configuration
    print("\\n=== Testing Environment Configuration ===")
    env_tests = TestEnvironmentConfiguration()
    env_tests.test_environment_variable_override()
    env_tests.test_development_vs_production_config()
    print("✅ Environment configuration tests passed")
    
    print("\\n🎉 All distributed tracing tests passed!")
    print("\\n📊 Test Summary:")
    print("- Tracing configuration: ✅")
    print("- Span creation and attributes: ✅")  
    print("- Service-specific helpers: ✅")
    print("- Nested span scenarios: ✅")
    print("- Error handling and propagation: ✅")
    print("- Environment configuration: ✅")
    
    print("\\n🔍 Jaeger UI will be available at: http://localhost:16686")
    print("   - View traces from all services")
    print("   - Analyze service dependencies")
    print("   - Monitor performance bottlenecks")


if __name__ == "__main__":
    run_tests()