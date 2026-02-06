"""
Azure Storage Helper for API Gateway
Wrapper for serving files from Azure Blob Storage
"""

import os
import logging
from datetime import datetime, timedelta
from typing import Optional, List

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

    def _generate_sas_url(
        self,
        container_name: str,
        blob_name: str,
        expiry_hours: int
    ) -> Optional[str]:
        """Generate a SAS URL for a blob"""
        if not self.enabled:
            return None

        try:
            sas_token = generate_blob_sas(
                account_name=self.account_name,
                container_name=container_name,
                blob_name=blob_name,
                account_key=self.account_key,
                permission=BlobSasPermissions(read=True),
                expiry=datetime.utcnow() + timedelta(hours=expiry_hours)
            )

            if self.cdn_endpoint:
                return f"{self.cdn_endpoint}/{container_name}/{blob_name}?{sas_token}"
            return f"https://{self.account_name}.blob.core.windows.net/{container_name}/{blob_name}?{sas_token}"

        except Exception as e:
            logger.error(f"Failed to generate SAS URL for {container_name}/{blob_name}: {e}")
            return None

    def generate_audio_url(self, book_folder: str, filename: str) -> Optional[str]:
        """Generate a signed URL for an audio file"""
        blob_name = f"{book_folder}/{filename}"
        return self._generate_sas_url("audiobooks", blob_name, expiry_hours=1)

    def generate_cover_url(self, book_folder: str, filename: str) -> Optional[str]:
        """Generate a signed URL for a cover image"""
        blob_name = f"{book_folder}/{filename}"
        return self._generate_sas_url("covers", blob_name, expiry_hours=24)

    def generate_download_urls(self, file_paths: List[str], expiry_hours: int = 24) -> dict:
        """Generate download URLs for multiple files with longer expiry"""
        if not self.enabled:
            return {}

        urls = {}
        for file_path in file_paths:
            url = self._generate_sas_url("audiobooks", file_path, expiry_hours)
            if url:
                urls[file_path] = url

        return urls

    def check_file_exists(self, file_path: str) -> bool:
        """Check if a blob exists in Azure Storage"""
        if not self.enabled:
            return False

        try:
            blob_client = self.blob_service_client.get_blob_client(
                container="audiobooks",
                blob=file_path
            )
            return blob_client.exists()
        except Exception as e:
            logger.error(f"Failed to check if blob exists for {file_path}: {e}")
            return False

    def upload_audio_file(self, local_file_path: str, blob_path: str) -> bool:
        """Upload an audio file to Azure Blob Storage"""
        if not self.enabled:
            logger.warning("Azure Storage not enabled, cannot upload file")
            return False

        try:
            blob_client = self.blob_service_client.get_blob_client(
                container="audiobooks",
                blob=blob_path
            )

            with open(local_file_path, 'rb') as data:
                blob_client.upload_blob(
                    data,
                    content_type='audio/mpeg',
                    overwrite=True,
                    metadata={
                        'original_filename': os.path.basename(local_file_path),
                        'upload_timestamp': datetime.utcnow().isoformat()
                    }
                )

            logger.info(f"Successfully uploaded {local_file_path} to {blob_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to upload {local_file_path} to {blob_path}: {e}")
            return False

    def upload_cover_image(self, local_file_path: str, blob_path: str) -> bool:
        """Upload a cover image to Azure Blob Storage"""
        if not self.enabled:
            logger.warning("Azure Storage not enabled, cannot upload image")
            return False

        try:
            blob_client = self.blob_service_client.get_blob_client(
                container="covers",
                blob=blob_path
            )

            content_type = 'image/png' if local_file_path.lower().endswith('.png') else 'image/jpeg'

            with open(local_file_path, 'rb') as data:
                blob_client.upload_blob(
                    data,
                    content_type=content_type,
                    overwrite=True,
                    metadata={
                        'original_filename': os.path.basename(local_file_path),
                        'upload_timestamp': datetime.utcnow().isoformat()
                    }
                )

            logger.info(f"Successfully uploaded {local_file_path} to {blob_path}")
            return True

        except Exception as e:
            logger.error(f"Failed to upload {local_file_path} to {blob_path}: {e}")
            return False

    def get_stream_url(self, file_path: str, expiry_hours: int = 1) -> Optional[str]:
        """Get a streaming URL for audio files optimized for mobile playback"""
        return self._generate_sas_url("audiobooks", file_path, expiry_hours)

    def list_book_audio_files(self, book_folder: str) -> List[str]:
        """List all audio files for a specific book"""
        if not self.enabled:
            return []

        try:
            container_client = self.blob_service_client.get_container_client("audiobooks")
            blob_list = []

            for blob in container_client.list_blobs(name_starts_with=f"{book_folder}/"):
                if blob.name.lower().endswith('.mp3'):
                    blob_list.append(blob.name)

            return sorted(blob_list)

        except Exception as e:
            logger.error(f"Failed to list audio files for {book_folder}: {e}")
            return []

    def get_fallback_local_path(self, book_folder: str, filename: str) -> Optional[str]:
        """Get local file path as fallback when Azure is unavailable"""
        from storage_helper import get_fallback_local_path
        return get_fallback_local_path(book_folder, filename)
