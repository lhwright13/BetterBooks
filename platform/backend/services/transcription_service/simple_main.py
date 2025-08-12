"""Simple transcription service for testing the reorganized structure."""

import os
from typing import List, Dict, Any
from fastapi import FastAPI, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Test that the core modules can be imported
try:
    from core.infrastructure.health_checks import HealthCheck
    from core.infrastructure.logging_config import setup_logging
    from core.infrastructure.pagination import (
        PaginatedResponse, PaginationParams, get_pagination_params,
        create_paginator
    )
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

# Create paginator instance
paginator = create_paginator() if CORE_IMPORTS_SUCCESS else None

# Sample data models
class TranscriptionJob(BaseModel):
    id: int
    filename: str
    status: str
    duration: float
    created_at: str

class Chapter(BaseModel):
    id: int
    book_id: int
    title: str
    start_time: float
    end_time: float
    summary: str

# Mock data for demonstration
SAMPLE_JOBS = [
    TranscriptionJob(
        id=i,
        filename=f"audiobook_{i:03d}.mp3",
        status="completed" if i % 3 == 0 else "processing",
        duration=float(3600 + i * 120),
        created_at=f"2024-01-{(i % 30) + 1:02d}T10:00:00Z"
    ) for i in range(1, 151)  # 150 sample jobs
]

SAMPLE_CHAPTERS = [
    Chapter(
        id=i,
        book_id=(i // 10) + 1,
        title=f"Chapter {(i % 10) + 1}: The Story Continues",
        start_time=float(i * 600),
        end_time=float((i + 1) * 600),
        summary=f"This chapter covers important developments in the story, focusing on character growth and plot advancement. Chapter {i} explores themes of courage and determination."
    ) for i in range(1, 201)  # 200 sample chapters
]

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


@app.get("/jobs", response_model=PaginatedResponse[TranscriptionJob] if CORE_IMPORTS_SUCCESS else List[TranscriptionJob])
def list_transcription_jobs(
    request: Request,
    params: PaginationParams = Depends(get_pagination_params) if CORE_IMPORTS_SUCCESS else None
):
    """List transcription jobs with pagination."""
    if not CORE_IMPORTS_SUCCESS or not paginator:
        # Fallback to simple list if pagination not available
        return SAMPLE_JOBS[:20]
    
    # Apply filtering based on sort parameters
    jobs = SAMPLE_JOBS.copy()
    
    if params.sort_by == "status":
        jobs.sort(key=lambda x: x.status, reverse=(params.sort_order == "desc"))
    elif params.sort_by == "duration":
        jobs.sort(key=lambda x: x.duration, reverse=(params.sort_order == "desc"))
    elif params.sort_by == "created_at":
        jobs.sort(key=lambda x: x.created_at, reverse=(params.sort_order == "desc"))
    
    return paginator.paginate_list(jobs, params, request)


@app.get("/chapters", response_model=PaginatedResponse[Chapter] if CORE_IMPORTS_SUCCESS else List[Chapter])
def list_chapters(
    request: Request,
    book_id: int = None,
    params: PaginationParams = Depends(get_pagination_params) if CORE_IMPORTS_SUCCESS else None
):
    """List book chapters with pagination and optional filtering."""
    if not CORE_IMPORTS_SUCCESS or not paginator:
        # Fallback to simple list if pagination not available
        chapters = SAMPLE_CHAPTERS[:20]
        if book_id:
            chapters = [c for c in chapters if c.book_id == book_id]
        return chapters
    
    # Apply filtering
    chapters = SAMPLE_CHAPTERS.copy()
    if book_id:
        chapters = [c for c in chapters if c.book_id == book_id]
    
    # Apply sorting
    if params.sort_by == "title":
        chapters.sort(key=lambda x: x.title, reverse=(params.sort_order == "desc"))
    elif params.sort_by == "duration":
        chapters.sort(key=lambda x: x.end_time - x.start_time, reverse=(params.sort_order == "desc"))
    elif params.sort_by == "start_time":
        chapters.sort(key=lambda x: x.start_time, reverse=(params.sort_order == "desc"))
    
    return paginator.paginate_list(chapters, params, request)


@app.get("/pagination/demo")
def pagination_demo():
    """Demonstrate pagination capabilities."""
    if not CORE_IMPORTS_SUCCESS:
        return {"error": "Pagination modules not available"}
    
    return {
        "pagination_available": True,
        "sample_endpoints": {
            "/jobs": "Paginated transcription jobs",
            "/chapters": "Paginated book chapters with filtering"
        },
        "parameters": {
            "page": "Page number (default: 1)",
            "page_size": "Items per page (default: 20, max: 100)",
            "sort_by": "Field to sort by",
            "sort_order": "asc or desc (default: asc)"
        },
        "example_urls": [
            "/jobs?page=2&page_size=10",
            "/jobs?sort_by=status&sort_order=desc",
            "/chapters?book_id=5&page=1&page_size=5",
            "/chapters?sort_by=duration&sort_order=desc"
        ],
        "response_format": {
            "data": "Array of items",
            "meta": "Pagination metadata (current page, total items, etc.)",
            "links": "Navigation links (self, next, previous, first, last)"
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)