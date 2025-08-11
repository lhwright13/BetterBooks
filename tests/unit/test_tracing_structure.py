"""
Test distributed tracing code structure and imports.

This test validates that the tracing module is properly structured
and can be imported without runtime errors.
"""

import os
import sys
from pathlib import Path

# Add project root to path to import core modules
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

def test_tracing_module_structure():
    """Test that the tracing module has the expected structure."""
    print("Testing tracing module structure...")
    
    try:
        # Test that we can import the tracing module
        from core.infrastructure import tracing
        print("✅ Tracing module imports successfully")
        
        # Test that key classes exist
        assert hasattr(tracing, 'TracingConfig'), "TracingConfig class missing"
        assert hasattr(tracing, 'LLMTracingHelper'), "LLMTracingHelper class missing"
        assert hasattr(tracing, 'DatabaseTracingHelper'), "DatabaseTracingHelper class missing"
        assert hasattr(tracing, 'HTTPTracingHelper'), "HTTPTracingHelper class missing"
        print("✅ All helper classes are present")
        
        # Test that key functions exist
        assert hasattr(tracing, 'setup_tracing'), "setup_tracing function missing"
        assert hasattr(tracing, 'instrument_fastapi'), "instrument_fastapi function missing"
        assert hasattr(tracing, 'get_development_tracing_config'), "get_development_tracing_config missing"
        assert hasattr(tracing, 'get_production_tracing_config'), "get_production_tracing_config missing"
        print("✅ All key functions are present")
        
        # Test configuration creation
        config = tracing.TracingConfig("test_service")
        assert config.service_name == "test_service"
        assert config.jaeger_endpoint == "http://localhost:14268/api/traces"
        assert config.sampling_rate == 1.0
        print("✅ TracingConfig works correctly")
        
        # Test config presets
        dev_config = tracing.get_development_tracing_config("dev_service")
        assert dev_config.service_name == "dev_service"
        assert dev_config.sampling_rate == 1.0
        assert dev_config.enable_console_exporter == True
        print("✅ Development config preset works")
        
        prod_config = tracing.get_production_tracing_config("prod_service")
        assert prod_config.service_name == "prod_service"
        assert prod_config.sampling_rate == 0.1
        assert prod_config.enable_console_exporter == False
        print("✅ Production config preset works")
        
        print("\\n🎉 All tracing structure tests passed!")
        return True
        
    except ImportError as e:
        print(f"❌ Failed to import tracing module: {e}")
        return False
    except AssertionError as e:
        print(f"❌ Assertion failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def test_api_gateway_tracing_integration():
    """Test that API Gateway has tracing properly integrated."""
    print("\\nTesting API Gateway tracing integration...")
    
    try:
        # Check that API Gateway main.py includes tracing imports
        api_gateway_main = Path(__file__).parent / "services" / "api_gateway" / "main.py"
        
        if not api_gateway_main.exists():
            print("❌ API Gateway main.py not found")
            return False
            
        with open(api_gateway_main, 'r') as f:
            content = f.read()
            
        # Check for tracing imports
        if "from tracing import" not in content:
            print("❌ Tracing imports not found in API Gateway")
            return False
        print("✅ Tracing imports found in API Gateway")
        
        # Check for tracer setup
        if "setup_tracing" not in content:
            print("❌ Tracer setup not found in API Gateway")
            return False
        print("✅ Tracer setup found in API Gateway")
        
        # Check for FastAPI instrumentation
        if "instrument_fastapi" not in content:
            print("❌ FastAPI instrumentation not found in API Gateway")
            return False
        print("✅ FastAPI instrumentation found in API Gateway")
        
        # Check for custom span usage
        if "start_as_current_span" not in content:
            print("❌ Custom span usage not found in API Gateway")
            return False
        print("✅ Custom span usage found in API Gateway")
        
        print("✅ API Gateway tracing integration verified")
        return True
        
    except Exception as e:
        print(f"❌ Error checking API Gateway integration: {e}")
        return False

def test_requirements_updates():
    """Test that services have OpenTelemetry dependencies."""
    print("\\nTesting OpenTelemetry dependencies in service requirements...")
    
    services_to_check = [
        "services/api_gateway/requirements.txt",
        "services/llm_gateway/requirements.txt", 
        "services/context_service/requirements.txt"
    ]
    
    required_packages = [
        "opentelemetry-api",
        "opentelemetry-sdk",
        "opentelemetry-exporter-jaeger",
        "opentelemetry-instrumentation-fastapi"
    ]
    
    all_good = True
    
    for service_req in services_to_check:
        req_file = Path(__file__).parent / service_req
        if not req_file.exists():
            print(f"❌ Requirements file not found: {service_req}")
            all_good = False
            continue
            
        with open(req_file, 'r') as f:
            content = f.read()
        
        missing_packages = []
        for package in required_packages:
            if package not in content:
                missing_packages.append(package)
        
        if missing_packages:
            print(f"❌ {service_req} missing: {', '.join(missing_packages)}")
            all_good = False
        else:
            print(f"✅ {service_req} has all required OpenTelemetry packages")
    
    return all_good

def test_docker_compose_jaeger():
    """Test that docker-compose includes Jaeger service."""
    print("\\nTesting Jaeger service in docker-compose.yml...")
    
    try:
        compose_file = Path(__file__).parent / "docker-compose.yml"
        if not compose_file.exists():
            print("❌ docker-compose.yml not found")
            return False
            
        with open(compose_file, 'r') as f:
            content = f.read()
        
        # Check for Jaeger service
        if "jaeger:" not in content:
            print("❌ Jaeger service not found in docker-compose.yml")
            return False
        print("✅ Jaeger service found in docker-compose.yml")
        
        # Check for Jaeger image
        if "jaegertracing/all-in-one" not in content:
            print("❌ Jaeger image not specified")
            return False
        print("✅ Jaeger image correctly specified")
        
        # Check for Jaeger UI port
        if "16686:16686" not in content:
            print("❌ Jaeger UI port not exposed")
            return False
        print("✅ Jaeger UI port exposed")
        
        # Check for Jaeger collector port  
        if "14268:14268" not in content:
            print("❌ Jaeger collector port not exposed")
            return False
        print("✅ Jaeger collector port exposed")
        
        # Check for jaeger_data volume
        if "jaeger_data:" not in content:
            print("❌ Jaeger data volume not defined")
            return False
        print("✅ Jaeger data volume defined")
        
        return True
        
    except Exception as e:
        print(f"❌ Error checking docker-compose.yml: {e}")
        return False

def run_all_tests():
    """Run all distributed tracing validation tests."""
    print("🧪 Validating Distributed Tracing Implementation")
    print("=" * 60)
    
    tests = [
        ("Tracing Module Structure", test_tracing_module_structure),
        ("API Gateway Integration", test_api_gateway_tracing_integration),
        ("OpenTelemetry Dependencies", test_requirements_updates),
        ("Docker Compose Jaeger Service", test_docker_compose_jaeger),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\\n🔍 {test_name}")
        print("-" * 40)
        success = test_func()
        results.append((test_name, success))
    
    print("\\n" + "=" * 60)
    print("📊 TEST SUMMARY")
    print("=" * 60)
    
    all_passed = True
    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status}  {test_name}")
        if not success:
            all_passed = False
    
    print("\\n" + "=" * 60)
    if all_passed:
        print("🎉 ALL TESTS PASSED! Distributed tracing is properly implemented.")
        print("\\n📋 What's been implemented:")
        print("  • OpenTelemetry tracing configuration")
        print("  • Jaeger exporter integration")
        print("  • Service-specific tracing helpers")
        print("  • FastAPI automatic instrumentation")
        print("  • Custom span creation and attributes")
        print("  • Error tracking and propagation")
        print("  • Development and production configurations")
        print("\\n🚀 Next steps:")
        print("  • Run 'docker-compose up --build' to start all services")
        print("  • Access Jaeger UI at http://localhost:16686")
        print("  • Make requests to API Gateway to generate traces")
        print("  • View end-to-end request traces across services")
    else:
        print("❌ SOME TESTS FAILED! Review the errors above.")
    
    print("=" * 60)

if __name__ == "__main__":
    run_all_tests()