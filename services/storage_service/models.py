"""
Storage Service Data Models
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
from decimal import Decimal

class DownloadRequest(BaseModel):
    user_id: str
    book_id: str

class DownloadResponse(BaseModel):
    download_url: str
    expires_at: datetime
    file_size_bytes: Optional[int] = None
    chapters: Optional[List[Dict[str, Any]]] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class UploadRequest(BaseModel):
    book_id: str
    title: str
    files: List[str]  # File paths or base64 data

class UploadResponse(BaseModel):
    success: bool
    message: str
    book_id: str
    blob_url: str
    file_size: Optional[int] = None

class FileMetadata(BaseModel):
    book_id: str
    total_files: int
    total_size: int
    files: List[Dict[str, Any]]
    chapters: List[Dict[str, Any]]

class StorageStats(BaseModel):
    total_books: int
    total_files: int
    total_size_bytes: int
    total_size_gb: float
    average_book_size_mb: float
    container_name: str
    timestamp: str

class BandwidthUsage(BaseModel):
    period_start: datetime
    period_end: datetime
    total_downloads: int
    total_bytes_transferred: int
    total_gb_transferred: float
    unique_users: int
    top_books: List[Dict[str, Any]]
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class DownloadLog(BaseModel):
    id: str
    user_id: str
    book_id: str
    download_time: datetime
    file_size: int
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }