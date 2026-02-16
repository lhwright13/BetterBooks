import os
import logging
from pathlib import Path
from typing import Optional, List, Protocol

logger = logging.getLogger(__name__)

STORAGE_BACKEND = os.getenv('STORAGE_BACKEND', 'auto').lower()


def get_book_files_directory() -> str:
    book_files_dir = os.getenv('BOOK_FILES_DIR')
    if book_files_dir:
        return book_files_dir

    if os.path.exists('/app/book_files'):
        return '/app/book_files'

    project_root = Path(__file__).resolve().parents[4]
    return str(project_root / 'book_files')


def get_fallback_local_path(book_folder: str, filename: str) -> Optional[str]:
    book_files_dir = get_book_files_directory()
    local_path = os.path.join(book_files_dir, book_folder, filename)

    if os.path.exists(local_path):
        return local_path

    logger.warning(f"No fallback file found for {book_folder}/{filename}. Tried: {local_path}")
    return None


class StorageHelper(Protocol):
    enabled: bool

    def generate_audio_url(self, book_folder: str, filename: str) -> Optional[str]: ...
    def generate_cover_url(self, book_folder: str, filename: str) -> Optional[str]: ...
    def generate_download_urls(self, file_paths: List[str], expiry_hours: int = 24) -> dict: ...
    def check_file_exists(self, file_path: str) -> bool: ...
    def upload_audio_file(self, local_file_path: str, target_path: str) -> bool: ...
    def upload_cover_image(self, local_file_path: str, target_path: str) -> bool: ...
    def get_stream_url(self, file_path: str, expiry_hours: int = 1) -> Optional[str]: ...
    def list_book_audio_files(self, book_folder: str) -> List[str]: ...
    def get_fallback_local_path(self, book_folder: str, filename: str) -> Optional[str]: ...


class LocalStorageHelper:

    def __init__(self):
        self.enabled = False
        self.book_files_dir = get_book_files_directory()
        logger.info(f"Local storage initialized: {self.book_files_dir}")

    def generate_audio_url(self, book_folder: str, filename: str) -> Optional[str]:
        return None

    def generate_cover_url(self, book_folder: str, filename: str) -> Optional[str]:
        return None

    def generate_download_urls(self, file_paths: List[str], expiry_hours: int = 24) -> dict:
        return {}

    def check_file_exists(self, file_path: str) -> bool:
        full_path = os.path.join(self.book_files_dir, file_path)
        return os.path.exists(full_path)

    def upload_audio_file(self, local_file_path: str, target_path: str) -> bool:
        import shutil
        try:
            dest = os.path.join(self.book_files_dir, target_path)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copy2(local_file_path, dest)
            return True
        except Exception as e:
            logger.error(f"Failed to copy file: {e}")
            return False

    def upload_cover_image(self, local_file_path: str, target_path: str) -> bool:
        return self.upload_audio_file(local_file_path, target_path)

    def get_stream_url(self, file_path: str, expiry_hours: int = 1) -> Optional[str]:
        return None

    def list_book_audio_files(self, book_folder: str) -> List[str]:
        folder_path = os.path.join(self.book_files_dir, book_folder)
        if not os.path.exists(folder_path):
            return []

        files = []
        for f in os.listdir(folder_path):
            if f.lower().endswith('.mp3'):
                files.append(f"{book_folder}/{f}")

        return sorted(files)

    def get_fallback_local_path(self, book_folder: str, filename: str) -> Optional[str]:
        return get_fallback_local_path(book_folder, filename)


def get_storage_helper() -> StorageHelper:
    if STORAGE_BACKEND == 's3':
        from s3_storage_helper import S3StorageHelper
        helper = S3StorageHelper()
        if helper.enabled:
            logger.info("Using S3 storage backend (explicit)")
            return helper
        logger.warning("S3 explicitly requested but not available, falling back")

    elif STORAGE_BACKEND == 'azure':
        from azure_storage_helper import AzureStorageHelper
        helper = AzureStorageHelper()
        if helper.enabled:
            logger.info("Using Azure storage backend (explicit)")
            return helper
        logger.warning("Azure explicitly requested but not available, falling back")

    elif STORAGE_BACKEND == 'local':
        logger.info("Using local storage backend (explicit)")
        return LocalStorageHelper()

    # Auto-detect: try S3, then Azure, then local
    try:
        from s3_storage_helper import S3StorageHelper
        s3_helper = S3StorageHelper()
        if s3_helper.enabled:
            logger.info("Using S3 storage backend (auto-detected)")
            return s3_helper
    except Exception as e:
        logger.debug(f"S3 not available: {e}")

    try:
        from azure_storage_helper import AzureStorageHelper
        azure_helper = AzureStorageHelper()
        if azure_helper.enabled:
            logger.info("Using Azure storage backend (auto-detected)")
            return azure_helper
    except Exception as e:
        logger.debug(f"Azure not available: {e}")

    logger.info("Using local storage backend (fallback)")
    return LocalStorageHelper()


_storage_helper: Optional[StorageHelper] = None


def get_storage() -> StorageHelper:
    global _storage_helper
    if _storage_helper is None:
        _storage_helper = get_storage_helper()
    return _storage_helper
