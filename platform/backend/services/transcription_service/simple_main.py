"""Simple transcription service for testing the reorganized structure."""

import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Test that the core modules can be imported
try:
    from core.infrastructure.health_checks import HealthCheck
    from core.infrastructure.logging_config import setup_logging
    CORE_IMPORTS_SUCCESS = True
    print("✅ Core modules imported successfully!")
except ImportError as e:
    CORE_IMPORTS_SUCCESS = False
    print(f"❌ Core import failed: {e}")

app = FastAPI(title="Transcription Service - Structure Test")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"service": "transcription", "status": "running", "core_imports": CORE_IMPORTS_SUCCESS}

@app.get("/health")
def health():
    return {"status": "ok", "core_modules": CORE_IMPORTS_SUCCESS}

@app.get("/test-structure")  
def test_structure():
    """Test that our reorganized structure works."""
    
    results = {
        "structure_test": "running",
        "core_imports": CORE_IMPORTS_SUCCESS,
        "environment_check": {
            "pythonpath": os.environ.get("PYTHONPATH", "not set"),
            "working_directory": os.getcwd(),
            "core_directory_exists": os.path.exists("/app/core"),
        }
    }
    
    # Test individual module imports
    module_tests = {}
    
    try:
        from core.infrastructure import setup_logging
        module_tests["infrastructure"] = "✅ Success"
    except Exception as e:
        module_tests["infrastructure"] = f"❌ Failed: {e}"
    
    try:
        from core.ai import summary_types
        module_tests["ai"] = "✅ Success" 
    except Exception as e:
        module_tests["ai"] = f"❌ Failed: {e}"
        
    try:
        from core.database import database_manager
        module_tests["database"] = "✅ Success"
    except Exception as e:
        module_tests["database"] = f"❌ Failed: {e}"
    
    results["module_tests"] = module_tests
    return results

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)