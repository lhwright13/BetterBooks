import os
import logging
from datetime import datetime
from typing import Optional, List

logger = logging.getLogger(__name__)

try:
    import boto3
    from botocore.exceptions import ClientError
    from botocore.config import Config
    S3_AVAILABLE = True
except ImportError:
    S3_AVAILABLE = False
    logger.warning("AWS S3 libraries not available. Will serve from local storage.")


class S3StorageHelper:

    def __init__(self):
        self.bucket_name = os.getenv("AWS_S3_BUCKET_NAME")
        self.region = os.getenv("AWS_REGION", "us-east-1")
        self.cloudfront_domain = os.getenv("AWS_CLOUDFRONT_DOMAIN")

        self.enabled = bool(
            S3_AVAILABLE and
            self.bucket_name and
            self.bucket_name != "your-s3-bucket-name-here"
        )

        if self.enabled:
            try:
                config = Config(
                    region_name=self.region,
                    signature_version='s3v4',
                    retries={'max_attempts': 3, 'mode': 'standard'}
                )
                self.s3_client = boto3.client('s3', config=config)
                self.s3_client.head_bucket(Bucket=self.bucket_name)
                logger.info(f"AWS S3 configured and available (bucket: {self.bucket_name})")
            except ClientError as e:
                logger.warning(f"AWS S3 bucket not accessible: {e}")
                self.enabled = False
            except Exception as e:
                logger.warning(f"AWS S3 initialization failed: {e}")
                self.enabled = False
        else:
            logger.info("AWS S3 not configured, will serve files locally")

    def _generate_presigned_url(self, key: str, expiry_seconds: int) -> Optional[str]:
        if not self.enabled:
            return None

        try:
            if self.cloudfront_domain:
                return f"https://{self.cloudfront_domain}/{key}"

            return self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': key},
                ExpiresIn=expiry_seconds
            )
        except Exception as e:
            logger.error(f"Failed to generate presigned URL for {key}: {e}")
            return None

    def generate_audio_url(self, book_folder: str, filename: str) -> Optional[str]:
        key = f"audiobooks/{book_folder}/{filename}"
        return self._generate_presigned_url(key, expiry_seconds=3600)

    def generate_cover_url(self, book_folder: str, filename: str) -> Optional[str]:
        key = f"covers/{book_folder}/{filename}"
        return self._generate_presigned_url(key, expiry_seconds=86400)

    def generate_download_urls(self, file_paths: List[str], expiry_hours: int = 24) -> dict:
        if not self.enabled:
            return {}

        urls = {}
        expiry_seconds = expiry_hours * 3600
        for file_path in file_paths:
            key = f"audiobooks/{file_path}"
            url = self._generate_presigned_url(key, expiry_seconds)
            if url:
                urls[file_path] = url
        return urls

    def check_file_exists(self, file_path: str) -> bool:
        if not self.enabled:
            return False

        try:
            key = f"audiobooks/{file_path}"
            self.s3_client.head_object(Bucket=self.bucket_name, Key=key)
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == '404':
                return False
            logger.error(f"Failed to check if file exists for {file_path}: {e}")
            return False
        except Exception as e:
            logger.error(f"Failed to check if file exists for {file_path}: {e}")
            return False

    def upload_audio_file(self, local_file_path: str, s3_path: str) -> bool:
        if not self.enabled:
            logger.warning("AWS S3 not enabled, cannot upload file")
            return False

        try:
            key = f"audiobooks/{s3_path}"
            self.s3_client.upload_file(
                local_file_path,
                self.bucket_name,
                key,
                ExtraArgs={
                    'ContentType': 'audio/mpeg',
                    'Metadata': {
                        'original_filename': os.path.basename(local_file_path),
                        'upload_timestamp': datetime.utcnow().isoformat()
                    }
                }
            )

            logger.info(f"Successfully uploaded {local_file_path} to s3://{self.bucket_name}/{key}")
            return True

        except Exception as e:
            logger.error(f"Failed to upload {local_file_path} to {s3_path}: {e}")
            return False

    def upload_cover_image(self, local_file_path: str, s3_path: str) -> bool:
        if not self.enabled:
            logger.warning("AWS S3 not enabled, cannot upload image")
            return False

        try:
            key = f"covers/{s3_path}"
            content_type = 'image/png' if local_file_path.lower().endswith('.png') else 'image/jpeg'
            self.s3_client.upload_file(
                local_file_path,
                self.bucket_name,
                key,
                ExtraArgs={
                    'ContentType': content_type,
                    'Metadata': {
                        'original_filename': os.path.basename(local_file_path),
                        'upload_timestamp': datetime.utcnow().isoformat()
                    }
                }
            )

            logger.info(f"Successfully uploaded {local_file_path} to s3://{self.bucket_name}/{key}")
            return True

        except Exception as e:
            logger.error(f"Failed to upload {local_file_path} to {s3_path}: {e}")
            return False

    def get_stream_url(self, file_path: str, expiry_hours: int = 1) -> Optional[str]:
        key = f"audiobooks/{file_path}"
        return self._generate_presigned_url(key, expiry_seconds=expiry_hours * 3600)

    def list_book_audio_files(self, book_folder: str) -> List[str]:
        if not self.enabled:
            return []

        try:
            prefix = f"audiobooks/{book_folder}/"
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix
            )

            files = []
            for obj in response.get('Contents', []):
                if obj['Key'].lower().endswith('.mp3'):
                    relative_path = obj['Key'][len('audiobooks/'):]
                    files.append(relative_path)

            return sorted(files)

        except Exception as e:
            logger.error(f"Failed to list audio files for {book_folder}: {e}")
            return []

    def get_fallback_local_path(self, book_folder: str, filename: str) -> Optional[str]:
        from storage_helper import get_fallback_local_path
        return get_fallback_local_path(book_folder, filename)
