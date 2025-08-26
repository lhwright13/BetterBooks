"""
Azure Storage Manager
Handles Azure Blob Storage operations
"""

import os
import asyncio
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Optional, List
import logging
from pathlib import Path
import json
import uuid

# Azure Storage imports (these would be installed in production)
try:
    from azure.storage.blob.aio import BlobServiceClient
    from azure.storage.blob import generate_blob_sas, BlobSasPermissions
    from azure.core.exceptions import ResourceNotFoundError
    AZURE_AVAILABLE = True
except ImportError:
    AZURE_AVAILABLE = False
    logging.warning("Azure Storage libraries not available. Using mock implementation.")

logger = logging.getLogger(__name__)

class MockBlobServiceClient:
    """Mock implementation for development/testing"""
    
    def __init__(self):
        self.containers = {}
    
    def get_container_client(self, container):
        if container not in self.containers:
            self.containers[container] = MockContainerClient(container)
        return self.containers[container]
    
    async def create_container(self, container):
        self.containers[container] = MockContainerClient(container)
    
    async def close(self):
        pass

class MockContainerClient:
    """Mock container client"""
    
    def __init__(self, container_name):
        self.container_name = container_name
        self.blobs = {}
    
    def get_blob_client(self, blob_name):
        return MockBlobClient(blob_name, self.blobs)
    
    async def list_blobs(self, name_starts_with=None):
        blobs = []
        for name, data in self.blobs.items():
            if not name_starts_with or name.startswith(name_starts_with):
                blob = type('MockBlob', (), {
                    'name': name,
                    'size': data.get('size', 0),
                    'last_modified': data.get('last_modified', datetime.now()),
                    'content_settings': data.get('content_settings', {})
                })()
                blobs.append(blob)
        return blobs

class MockBlobClient:
    """Mock blob client"""
    
    def __init__(self, blob_name, storage):
        self.blob_name = blob_name
        self.storage = storage
    
    async def upload_blob(self, data, content_type=None, **kwargs):
        self.storage[self.blob_name] = {
            'data': data,
            'content_type': content_type,
            'size': len(data) if isinstance(data, (bytes, str)) else 0,
            'last_modified': datetime.now(),
            'url': f"https://mock.blob.core.windows.net/audiobooks/{self.blob_name}"
        }
    
    async def get_blob_properties(self):
        if self.blob_name in self.storage:
            data = self.storage[self.blob_name]
            return type('Properties', (), {
                'size': data.get('size', 0),
                'last_modified': data.get('last_modified'),
                'content_settings': type('ContentSettings', (), {
                    'content_type': data.get('content_type')
                })()
            })()
        raise ResourceNotFoundError("Blob not found")
    
    @property
    def url(self):
        return f"https://mock.blob.core.windows.net/audiobooks/{self.blob_name}"

class AzureStorageManager:
    def __init__(self):
        self.connection_string = os.getenv(
            "AZURE_STORAGE_CONNECTION_STRING",
            "DefaultEndpointsProtocol=https;AccountName=mock;AccountKey=mock"
        )
        self.account_name = os.getenv("AZURE_STORAGE_ACCOUNT_NAME", "betterbookstorage")
        self.account_key = os.getenv("AZURE_STORAGE_ACCOUNT_KEY", "mock_key")
        self.container_name = "audiobooks"
        self.cdn_endpoint = os.getenv("AZURE_CDN_ENDPOINT", "https://betterbooks-cdn.azureedge.net")
        
        self.client = None
        self.container_client = None
    
    async def initialize(self):
        """Initialize Azure Storage client"""
        try:
            if AZURE_AVAILABLE:
                self.client = BlobServiceClient.from_connection_string(self.connection_string)
            else:
                logger.warning("Using mock Azure Storage client")
                self.client = MockBlobServiceClient()
            
            # Get container client
            self.container_client = self.client.get_container_client(self.container_name)
            
            # Create container if it doesn't exist (in production, this should be done separately)
            try:
                await self.container_client.create_container()
                logger.info(f"Created container: {self.container_name}")
            except Exception as e:
                logger.info(f"Container {self.container_name} already exists or creation failed: {e}")
            
            logger.info("Azure Storage initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize Azure Storage: {e}")
            raise
    
    async def health_check(self) -> Dict[str, Any]:
        """Check Azure Storage health"""
        try:
            # Try to list blobs (this tests connectivity)
            async for _ in self.container_client.list_blobs():
                break
            return {"status": "healthy", "connection": "ok"}
        except Exception as e:
            return {"status": "unhealthy", "error": str(e)}
    
    async def upload_book(
        self,
        book_id: str,
        file_data: bytes,
        filename: str,
        content_type: Optional[str] = None
    ) -> str:
        """Upload a book file to Azure Storage"""
        try:
            blob_name = f"{book_id}/{filename}"
            blob_client = self.container_client.get_blob_client(blob_name)
            
            await blob_client.upload_blob(
                file_data,
                content_type=content_type or "audio/mpeg",
                overwrite=True
            )
            
            logger.info(f"Uploaded book file: {blob_name}")
            return blob_client.url
            
        except Exception as e:
            logger.error(f"Error uploading book {book_id}: {e}")
            raise
    
    async def upload_book_file(
        self,
        book_id: str,
        file_data: bytes,
        filename: str,
        content_type: Optional[str] = None
    ) -> str:
        """Upload a specific file for a book (chapter, cover, etc.)"""
        try:
            # Organize files by type
            if filename.lower().endswith(('.jpg', '.jpeg', '.png')):
                blob_name = f"{book_id}/cover/{filename}"
            elif filename.lower().endswith(('.mp3', '.m4a', '.wav')):
                blob_name = f"{book_id}/chapters/{filename}"
            elif filename.lower().endswith('.json'):
                blob_name = f"{book_id}/metadata/{filename}"
            else:
                blob_name = f"{book_id}/files/{filename}"
            
            blob_client = self.container_client.get_blob_client(blob_name)
            
            await blob_client.upload_blob(
                file_data,
                content_type=content_type,
                overwrite=True
            )
            
            logger.info(f"Uploaded book file: {blob_name}")
            return blob_client.url
            
        except Exception as e:
            logger.error(f"Error uploading book file {book_id}/{filename}: {e}")
            raise
    
    async def generate_download_url(
        self,
        book_id: str,
        user_id: str,
        expires_hours: int = 24
    ) -> str:
        """Generate a secure download URL with SAS token"""
        try:
            if AZURE_AVAILABLE:
                # Generate SAS token for the book folder
                sas_token = generate_blob_sas(
                    account_name=self.account_name,
                    container_name=self.container_name,
                    blob_name=f"{book_id}",
                    account_key=self.account_key,
                    permission=BlobSasPermissions(read=True),
                    expiry=datetime.now(timezone.utc) + timedelta(hours=expires_hours)
                )
                
                # Use CDN URL if available
                if self.cdn_endpoint:
                    return f"{self.cdn_endpoint}/{self.container_name}/{book_id}?{sas_token}"
                else:
                    return f"https://{self.account_name}.blob.core.windows.net/{self.container_name}/{book_id}?{sas_token}"
            else:
                # Mock URL for development
                return f"https://mock.blob.core.windows.net/{self.container_name}/{book_id}?token=mock_sas_token&expires={expires_hours}h"
            
        except Exception as e:
            logger.error(f"Error generating download URL for {book_id}: {e}")
            raise
    
    async def get_file_metadata(self, book_id: str) -> Optional[Dict[str, Any]]:
        """Get metadata for a book's files"""
        try:
            files = []
            total_size = 0
            chapters = []
            
            # List all blobs for this book
            async for blob in self.container_client.list_blobs(name_starts_with=f"{book_id}/"):
                file_info = {
                    "name": blob.name.split('/')[-1],
                    "path": blob.name,
                    "size": blob.size,
                    "last_modified": blob.last_modified.isoformat() if hasattr(blob, 'last_modified') else None,
                    "content_type": getattr(blob.content_settings, 'content_type', None) if hasattr(blob, 'content_settings') else None
                }
                files.append(file_info)
                total_size += blob.size
                
                # If it's an audio file, add to chapters
                if blob.name.endswith(('.mp3', '.m4a', '.wav')):
                    chapter_info = {
                        "name": file_info["name"],
                        "path": blob.name,
                        "size": blob.size,
                        "download_url": f"https://{self.account_name}.blob.core.windows.net/{self.container_name}/{blob.name}"
                    }
                    chapters.append(chapter_info)
            
            if not files:
                return None
            
            return {
                "book_id": book_id,
                "total_files": len(files),
                "total_size": total_size,
                "files": files,
                "chapters": sorted(chapters, key=lambda x: x["name"])
            }
            
        except Exception as e:
            logger.error(f"Error getting file metadata for {book_id}: {e}")
            return None
    
    async def get_storage_stats(self) -> Dict[str, Any]:
        """Get storage usage statistics"""
        try:
            total_books = 0
            total_size = 0
            file_count = 0
            
            # Count all blobs
            async for blob in self.container_client.list_blobs():
                file_count += 1
                total_size += blob.size
                
                # Count unique books
                book_id = blob.name.split('/')[0]
                if book_id:
                    total_books += 1
            
            # Get unique book count
            book_ids = set()
            async for blob in self.container_client.list_blobs():
                book_id = blob.name.split('/')[0]
                if book_id:
                    book_ids.add(book_id)
            
            total_books = len(book_ids)
            
            return {
                "total_books": total_books,
                "total_files": file_count,
                "total_size_bytes": total_size,
                "total_size_gb": round(total_size / (1024**3), 2),
                "average_book_size_mb": round((total_size / total_books) / (1024**2), 2) if total_books > 0 else 0,
                "container_name": self.container_name,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting storage stats: {e}")
            return {
                "total_books": 0,
                "total_files": 0,
                "total_size_bytes": 0,
                "error": str(e)
            }
    
    async def delete_book(self, book_id: str) -> bool:
        """Delete all files for a book"""
        try:
            deleted_count = 0
            
            # Delete all blobs for this book
            async for blob in self.container_client.list_blobs(name_starts_with=f"{book_id}/"):
                blob_client = self.container_client.get_blob_client(blob.name)
                await blob_client.delete_blob()
                deleted_count += 1
            
            logger.info(f"Deleted {deleted_count} files for book {book_id}")
            return deleted_count > 0
            
        except Exception as e:
            logger.error(f"Error deleting book {book_id}: {e}")
            return False