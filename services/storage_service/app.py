"""
Storage Service Main Application
FastAPI service for cloud storage management
"""

import asyncio
from fastapi import FastAPI, HTTPException, Depends, status, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from contextlib import asynccontextmanager
import uvicorn
import os
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone, timedelta
import uuid
import logging
from pathlib import Path

from .models import (
    DownloadRequest, DownloadResponse, UploadRequest, UploadResponse,
    StorageStats, FileMetadata, BandwidthUsage
)
from .azure_storage import AzureStorageManager
from .database import StorageDatabase

logger = logging.getLogger(__name__)

# Initialize FastAPI with lifespan
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("🚀 Storage Service starting...")
    
    # Initialize Azure Storage
    storage_manager = AzureStorageManager()
    await storage_manager.initialize()
    app.state.storage = storage_manager
    
    # Initialize database
    db = StorageDatabase()
    await db.initialize()
    app.state.db = db
    
    print("✅ Storage Service ready!")
    yield
    
    # Shutdown
    print("🛑 Storage Service shutting down...")
    await db.close()

app = FastAPI(
    title="BetterBooks Storage Service",
    description="Manages cloud storage for audiobook files",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoints
@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "storage", "timestamp": datetime.now(timezone.utc)}

@app.get("/health/detailed")
async def detailed_health_check():
    try:
        # Test Azure connection
        storage_status = await app.state.storage.health_check()
        db_status = await app.state.db.health_check()
        
        return {
            "status": "healthy",
            "service": "storage",
            "timestamp": datetime.now(timezone.utc),
            "dependencies": {
                "azure_storage": storage_status,
                "database": db_status
            }
        }
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "service": "storage",
                "error": str(e),
                "timestamp": datetime.now(timezone.utc)
            }
        )

# Download endpoints
@app.post("/download", response_model=DownloadResponse)
async def get_download_url(request: DownloadRequest):
    """Generate secure download URL for a book"""
    try:
        # Verify user owns the book (this would check with bookstore service)
        # For now, we'll assume the request is valid
        
        download_url = await app.state.storage.generate_download_url(
            book_id=request.book_id,
            user_id=request.user_id,
            expires_hours=24
        )
        
        # Get file metadata
        metadata = await app.state.storage.get_file_metadata(request.book_id)
        
        # Log download request
        await app.state.db.log_download(
            user_id=request.user_id,
            book_id=request.book_id,
            file_size=metadata.get('size', 0) if metadata else 0
        )
        
        return DownloadResponse(
            download_url=download_url,
            expires_at=datetime.now(timezone.utc) + timedelta(hours=24),
            file_size_bytes=metadata.get('size', 0) if metadata else None,
            chapters=metadata.get('chapters', []) if metadata else None
        )
    
    except Exception as e:
        logger.error(f"Error generating download URL: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to generate download URL: {str(e)}")

@app.get("/download/{book_id}")
async def redirect_download(
    book_id: str,
    user: str,
    token: str
):
    """Redirect to actual download URL (used by mobile apps)"""
    try:
        # Validate token (simplified for demo)
        if token != "temp_token":
            raise HTTPException(status_code=403, detail="Invalid download token")
        
        download_url = await app.state.storage.generate_download_url(
            book_id=book_id,
            user_id=user,
            expires_hours=1  # Short expiry for direct downloads
        )
        
        return RedirectResponse(url=download_url, status_code=302)
    
    except Exception as e:
        logger.error(f"Error redirecting download: {e}")
        raise HTTPException(status_code=500, detail=f"Download failed: {str(e)}")

# Upload endpoints (admin/management)
@app.post("/upload", response_model=UploadResponse)
async def upload_book(
    book_id: str = Form(...),
    title: str = Form(...),
    file: UploadFile = File(...)
):
    """Upload a book file to cloud storage"""
    try:
        # Validate file type
        if not file.filename.endswith(('.mp3', '.m4a', '.zip')):
            raise HTTPException(status_code=400, detail="Invalid file type")
        
        # Upload to Azure
        blob_url = await app.state.storage.upload_book(
            book_id=book_id,
            file_data=await file.read(),
            filename=file.filename,
            content_type=file.content_type
        )
        
        # Store metadata
        await app.state.db.store_file_metadata(
            book_id=book_id,
            title=title,
            filename=file.filename,
            file_size=file.size,
            blob_url=blob_url,
            content_type=file.content_type
        )
        
        return UploadResponse(
            success=True,
            message="Book uploaded successfully",
            book_id=book_id,
            blob_url=blob_url,
            file_size=file.size
        )
    
    except Exception as e:
        logger.error(f"Error uploading book: {e}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

@app.post("/upload/batch")
async def upload_book_batch(
    book_id: str = Form(...),
    title: str = Form(...),
    files: List[UploadFile] = File(...)
):
    """Upload multiple files for a book (chapters, cover, etc.)"""
    try:
        results = []
        total_size = 0
        
        for file in files:
            # Upload each file
            blob_url = await app.state.storage.upload_book_file(
                book_id=book_id,
                file_data=await file.read(),
                filename=file.filename,
                content_type=file.content_type
            )
            
            results.append({
                "filename": file.filename,
                "blob_url": blob_url,
                "size": file.size
            })
            total_size += file.size or 0
        
        # Update book metadata
        await app.state.db.update_book_files(
            book_id=book_id,
            files=results,
            total_size=total_size
        )
        
        return {
            "success": True,
            "message": f"Uploaded {len(files)} files for book {title}",
            "book_id": book_id,
            "files": results,
            "total_size": total_size
        }
    
    except Exception as e:
        logger.error(f"Error uploading book batch: {e}")
        raise HTTPException(status_code=500, detail=f"Batch upload failed: {str(e)}")

# Management endpoints
@app.get("/books/{book_id}/metadata", response_model=FileMetadata)
async def get_book_metadata(book_id: str):
    """Get metadata for a book's files"""
    try:
        metadata = await app.state.storage.get_file_metadata(book_id)
        if not metadata:
            raise HTTPException(status_code=404, detail="Book not found")
        
        return FileMetadata(**metadata)
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting book metadata: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get metadata: {str(e)}")

@app.get("/stats/storage", response_model=StorageStats)
async def get_storage_stats():
    """Get storage usage statistics"""
    try:
        stats = await app.state.storage.get_storage_stats()
        return StorageStats(**stats)
    
    except Exception as e:
        logger.error(f"Error getting storage stats: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get stats: {str(e)}")

@app.get("/stats/bandwidth", response_model=BandwidthUsage)
async def get_bandwidth_usage(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    """Get bandwidth usage statistics"""
    try:
        usage = await app.state.db.get_bandwidth_usage(start_date, end_date)
        return BandwidthUsage(**usage)
    
    except Exception as e:
        logger.error(f"Error getting bandwidth usage: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get bandwidth usage: {str(e)}")

# Cleanup endpoints
@app.post("/cleanup/expired-urls")
async def cleanup_expired_urls():
    """Clean up expired download URLs"""
    try:
        count = await app.state.db.cleanup_expired_downloads()
        return {"message": f"Cleaned up {count} expired download records"}
    
    except Exception as e:
        logger.error(f"Error cleaning up expired URLs: {e}")
        raise HTTPException(status_code=500, detail=f"Cleanup failed: {str(e)}")

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8005"))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)