"""
Azure Storage Helper for API Gateway
Simple wrapper for serving files from Azure Blob Storage
"""

import os
import logging
from datetime import datetime, timedelta
from typing import Optional

logger = logging.getLogger(__name__)

# Azure Storage imports with fallback
try:
    from azure.storage.blob import BlobServiceClient, generate_blob_sas, BlobSasPermissions
    AZURE_AVAILABLE = True
except ImportError:
    AZURE_AVAILABLE = False
    logger.warning("Azure Storage libraries not available. Will serve from local storage.")

class AzureStorageHelper:
    """Helper for Azure Blob Storage operations"""
    
    def __init__(self):
        self.account_name = os.getenv("AZURE_STORAGE_ACCOUNT_NAME")
        self.account_key = os.getenv("AZURE_STORAGE_ACCOUNT_KEY")
        self.cdn_endpoint = os.getenv("AZURE_CDN_ENDPOINT")
        
        self.enabled = (
            AZURE_AVAILABLE and 
            self.account_name and 
            self.account_key and
            self.account_key != "your-azure-storage-account-key-here"
        )
        
        if self.enabled:
            connection_string = f"DefaultEndpointsProtocol=https;AccountName={self.account_name};AccountKey={self.account_key};EndpointSuffix=core.windows.net"
            self.blob_service_client = BlobServiceClient.from_connection_string(connection_string)
            logger.info("Azure Storage configured and available")
        else:
            logger.info("Azure Storage not configured, will serve files locally")
    
    def generate_audio_url(self, book_folder: str, filename: str) -> Optional[str]:
        """Generate a signed URL for an audio file"""
        if not self.enabled:
            return None
            
        try:
            container_name = "audiobooks"
            blob_name = f"{book_folder}/{filename}"
            
            # Generate SAS token valid for 1 hour
            sas_token = generate_blob_sas(
                account_name=self.account_name,
                container_name=container_name,
                blob_name=blob_name,
                account_key=self.account_key,
                permission=BlobSasPermissions(read=True),
                expiry=datetime.utcnow() + timedelta(hours=1)
            )
            
            if self.cdn_endpoint:
                # Use CDN endpoint for better performance
                url = f"{self.cdn_endpoint}/{container_name}/{blob_name}?{sas_token}"
            else:
                # Use direct blob storage URL
                url = f"https://{self.account_name}.blob.core.windows.net/{container_name}/{blob_name}?{sas_token}"
            
            return url
            
        except Exception as e:
            logger.error(f"Failed to generate audio URL for {book_folder}/{filename}: {e}")
            return None
    
    def generate_cover_url(self, book_folder: str, filename: str) -> Optional[str]:
        """Generate a signed URL for a cover image"""
        if not self.enabled:
            return None
            
        try:
            container_name = "covers"
            blob_name = f"{book_folder}/{filename}"
            
            # Generate SAS token valid for 24 hours (covers can be cached longer)
            sas_token = generate_blob_sas(
                account_name=self.account_name,
                container_name=container_name,
                blob_name=blob_name,
                account_key=self.account_key,
                permission=BlobSasPermissions(read=True),
                expiry=datetime.utcnow() + timedelta(hours=24)
            )
            
            if self.cdn_endpoint:
                # Use CDN endpoint for better performance
                url = f"{self.cdn_endpoint}/{container_name}/{blob_name}?{sas_token}"
            else:
                # Use direct blob storage URL
                url = f"https://{self.account_name}.blob.core.windows.net/{container_name}/{blob_name}?{sas_token}"
            
            return url
            
        except Exception as e:
            logger.error(f"Failed to generate cover URL for {book_folder}/{filename}: {e}")
            return None
    
    def generate_download_urls(self, file_paths: list[str], expiry_hours: int = 24) -> dict[str, str]:
        """Generate download URLs for multiple files with longer expiry for downloaded content"""
        if not self.enabled:
            return {}
            
        urls = {}
        try:
            container_name = "audiobooks"
            expiry_time = datetime.utcnow() + timedelta(hours=expiry_hours)
            
            for file_path in file_paths:
                # file_path format: "The Great Gatsby/Chapter 1.mp3"
                blob_name = file_path
                
                sas_token = generate_blob_sas(
                    account_name=self.account_name,
                    container_name=container_name,
                    blob_name=blob_name,
                    account_key=self.account_key,
                    permission=BlobSasPermissions(read=True),
                    expiry=expiry_time
                )
                
                if self.cdn_endpoint:
                    url = f"{self.cdn_endpoint}/{container_name}/{blob_name}?{sas_token}"
                else:
                    url = f"https://{self.account_name}.blob.core.windows.net/{container_name}/{blob_name}?{sas_token}"
                
                urls[file_path] = url
                
        except Exception as e:
            logger.error(f"Failed to generate download URLs: {e}")
            
        return urls
    
    def check_blob_exists(self, file_path: str) -> bool:
        """Check if a blob exists in Azure Storage"""
        if not self.enabled:
            return False
            
        try:
            container_name = "audiobooks"
            blob_client = self.blob_service_client.get_blob_client(
                container=container_name, 
                blob=file_path
            )
            return blob_client.exists()
        except Exception as e:
            logger.error(f"Failed to check if blob exists for {file_path}: {e}")
            return False