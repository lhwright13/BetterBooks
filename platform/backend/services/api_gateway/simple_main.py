#!/usr/bin/env python3
"""
Simplified API Gateway for BetterBooks - Focus on Bookstore functionality
Temporary version to get bookstore working while infrastructure issues are resolved
"""

import os
import logging
from datetime import datetime
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

# Simplified logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Import our simple bookstore routes
from simple_bookstore_routes import router as bookstore_router

# Book files directory - will be mounted in Docker
BOOK_FILES_DIR = Path("/app/book_files")

# Create FastAPI app
app = FastAPI(
    title="BetterBooks API Gateway",
    description="Simplified API Gateway for BetterBooks audiobook platform",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include bookstore routes
app.include_router(bookstore_router)

# Basic health check
@app.get("/health")
async def health_check():
    """Simple health check endpoint"""
    return {
        "status": "ok",
        "service": "api_gateway",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat(),
        "bookstore": "enabled",
        "book_files_dir": str(BOOK_FILES_DIR),
        "book_files_exists": BOOK_FILES_DIR.exists()
    }

# Serve book cover images
@app.get("/books/cover/{book_folder}/{filename}")
async def get_book_cover(book_folder: str, filename: str):
    """Serve book cover images"""
    try:
        file_path = BOOK_FILES_DIR / book_folder / filename
        if file_path.exists():
            return FileResponse(file_path)
        else:
            logger.warning(f"Cover image not found: {file_path}")
            raise HTTPException(status_code=404, detail="Cover image not found")
    except Exception as e:
        logger.error(f"Error serving cover image: {e}")
        raise HTTPException(status_code=500, detail="Error serving cover image")

# Serve book audio files (for samples)
@app.get("/books/{book_folder}/{filename}")
async def get_book_file(book_folder: str, filename: str):
    """Serve book audio files"""
    try:
        file_path = BOOK_FILES_DIR / book_folder / filename
        if file_path.exists():
            return FileResponse(
                file_path,
                media_type="audio/mpeg",
                headers={"Accept-Ranges": "bytes"}
            )
        else:
            logger.warning(f"Audio file not found: {file_path}")
            raise HTTPException(status_code=404, detail="Audio file not found")
    except Exception as e:
        logger.error(f"Error serving audio file: {e}")
        raise HTTPException(status_code=500, detail="Error serving audio file")

# List available books (for debugging)
@app.get("/debug/books")
async def list_available_books():
    """Debug endpoint to list available book files"""
    try:
        if not BOOK_FILES_DIR.exists():
            return {"error": "Book files directory not found", "path": str(BOOK_FILES_DIR)}
        
        books = {}
        for book_dir in BOOK_FILES_DIR.iterdir():
            if book_dir.is_dir() and book_dir.name not in ['.DS_Store', '__pycache__']:
                files = []
                for file_path in book_dir.iterdir():
                    if file_path.is_file():
                        files.append({
                            "name": file_path.name,
                            "size": file_path.stat().st_size,
                            "type": "audio" if file_path.suffix in ['.mp3', '.m4a', '.wav'] else "other"
                        })
                books[book_dir.name] = {
                    "folder": str(book_dir),
                    "files": files,
                    "file_count": len(files)
                }
        
        return {
            "book_files_dir": str(BOOK_FILES_DIR),
            "books": books,
            "book_count": len(books)
        }
    except Exception as e:
        logger.error(f"Error listing books: {e}")
        return {"error": str(e)}

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with basic information"""
    return {
        "service": "BetterBooks API Gateway",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "docs": "/docs", 
            "bookstore": "/bookstore/*",
            "covers": "/books/cover/{book_folder}/{filename}",
            "audio": "/books/{book_folder}/{filename}",
            "debug": "/debug/books"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)