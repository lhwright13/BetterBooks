#!/usr/bin/env python3
"""
Script to upload existing books from local storage to Azure Blob Storage
This script will:
1. Read books from the local book_files directory
2. Upload them to Azure Blob Storage
3. Update the database with cloud storage references
"""

import os
import asyncio
import asyncpg
import logging
from pathlib import Path
import hashlib
import json
from typing import Dict, List, Optional, Any
import mimetypes
from datetime import datetime, timezone

# Azure imports (mock if not available)
try:
    from azure.storage.blob.aio import BlobServiceClient
    AZURE_AVAILABLE = True
except ImportError:
    AZURE_AVAILABLE = False
    print("Azure Storage libraries not available. Install with: pip install azure-storage-blob")

# Configuration
BOOK_FILES_DIR = Path("/Users/lhwri/BetterBooks/book_files")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/betterbooks")
AZURE_CONNECTION_STRING = os.getenv("AZURE_STORAGE_CONNECTION_STRING", "")
CONTAINER_NAME = "audiobooks"
DRY_RUN = os.getenv("DRY_RUN", "false").lower() == "true"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class BookUploader:
    def __init__(self):
        self.db_pool = None
        self.blob_client = None
        self.container_client = None
        self.uploaded_files = []
        self.errors = []
    
    async def initialize(self):
        """Initialize database and Azure connections"""
        # Initialize database
        try:
            self.db_pool = await asyncpg.create_pool(DATABASE_URL)
            logger.info("✅ Database connection established")
        except Exception as e:
            logger.error(f"❌ Database connection failed: {e}")
            raise
        
        # Initialize Azure Storage
        if AZURE_AVAILABLE and AZURE_CONNECTION_STRING:
            try:
                self.blob_client = BlobServiceClient.from_connection_string(AZURE_CONNECTION_STRING)
                self.container_client = self.blob_client.get_container_client(CONTAINER_NAME)
                
                # Create container if it doesn't exist
                try:
                    await self.container_client.create_container()
                    logger.info(f"✅ Created container: {CONTAINER_NAME}")
                except Exception:
                    logger.info(f"✅ Container {CONTAINER_NAME} already exists")
                
            except Exception as e:
                logger.error(f"❌ Azure Storage connection failed: {e}")
                raise
        else:
            logger.warning("⚠️  Azure Storage not available - running in mock mode")
    
    async def get_books_from_db(self) -> List[Dict[str, Any]]:
        """Get books from database"""
        async with self.db_pool.acquire() as conn:
            books = await conn.fetch("""
                SELECT id, title, author, file_path, total_chapters, 
                       blob_container, blob_path, storage_provider
                FROM books 
                WHERE storage_provider = 'local' OR storage_provider IS NULL
                ORDER BY title
            """)
            return [dict(book) for book in books]
    
    def scan_book_directory(self, book_path: Path) -> Dict[str, List[Path]]:
        """Scan book directory and categorize files"""
        files = {
            'chapters': [],
            'covers': [],
            'metadata': [],
            'other': []
        }
        
        if not book_path.exists():
            logger.warning(f"⚠️  Directory not found: {book_path}")
            return files
        
        for file_path in book_path.iterdir():
            if file_path.is_file():
                filename = file_path.name.lower()
                
                if filename.endswith(('.mp3', '.m4a', '.wav', '.ogg')):
                    files['chapters'].append(file_path)
                elif filename.endswith(('.jpg', '.jpeg', '.png', '.gif')):
                    files['covers'].append(file_path)
                elif filename.endswith(('.json', '.txt', '.md')):
                    files['metadata'].append(file_path)
                else:
                    files['other'].append(file_path)
        
        # Sort chapters by name (should handle "Chapter 1", "Chapter 2", etc.)
        files['chapters'].sort(key=lambda x: x.name)
        
        return files
    
    def calculate_file_hash(self, file_path: Path) -> str:
        """Calculate MD5 hash of file for integrity checking"""
        hash_md5 = hashlib.md5()
        try:
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except Exception as e:
            logger.error(f"❌ Error calculating hash for {file_path}: {e}")
            return ""
    
    async def upload_file_to_azure(self, file_path: Path, blob_name: str) -> Optional[str]:
        """Upload a single file to Azure Blob Storage"""
        if DRY_RUN:
            logger.info(f"🔍 DRY RUN: Would upload {file_path} -> {blob_name}")
            return f"https://mock.blob.core.windows.net/{CONTAINER_NAME}/{blob_name}"
        
        if not AZURE_AVAILABLE or not self.container_client:
            logger.info(f"📁 MOCK: Uploading {file_path} -> {blob_name}")
            return f"https://mock.blob.core.windows.net/{CONTAINER_NAME}/{blob_name}"
        
        try:
            blob_client = self.container_client.get_blob_client(blob_name)
            
            # Determine content type
            content_type, _ = mimetypes.guess_type(str(file_path))
            if not content_type:
                content_type = "application/octet-stream"
            
            # Read and upload file
            with open(file_path, 'rb') as data:
                await blob_client.upload_blob(
                    data, 
                    content_type=content_type,
                    overwrite=True
                )
            
            logger.info(f"✅ Uploaded: {blob_name}")
            return blob_client.url
            
        except Exception as e:
            logger.error(f"❌ Failed to upload {blob_name}: {e}")
            return None
    
    async def process_book(self, book_data: Dict[str, Any]) -> bool:
        """Process and upload all files for a book"""
        book_id = str(book_data['id'])
        title = book_data['title']
        file_path = book_data.get('file_path', title)
        
        logger.info(f"\n📚 Processing: {title}")
        logger.info(f"   Book ID: {book_id}")
        logger.info(f"   File Path: {file_path}")
        
        # Scan local directory
        book_dir = BOOK_FILES_DIR / file_path
        files = self.scan_book_directory(book_dir)
        
        total_files = sum(len(file_list) for file_list in files.values())
        if total_files == 0:
            logger.warning(f"⚠️  No files found for {title}")
            return False
        
        logger.info(f"   Found {total_files} files:")
        logger.info(f"     - {len(files['chapters'])} chapters")
        logger.info(f"     - {len(files['covers'])} covers") 
        logger.info(f"     - {len(files['metadata'])} metadata files")
        logger.info(f"     - {len(files['other'])} other files")
        
        # Upload files to Azure
        uploaded_files = []
        total_size = 0
        
        for category, file_list in files.items():
            for file_path in file_list:
                # Generate blob name
                blob_name = f"{book_id}/{category}/{file_path.name}"
                
                # Upload file
                blob_url = await self.upload_file_to_azure(file_path, blob_name)
                if blob_url:
                    file_size = file_path.stat().st_size
                    file_hash = self.calculate_file_hash(file_path)
                    total_size += file_size
                    
                    file_info = {
                        'book_id': book_id,
                        'file_type': category[:-1] if category.endswith('s') else category,  # Remove plural
                        'filename': file_path.name,
                        'original_filename': file_path.name,
                        'file_size_bytes': file_size,
                        'mime_type': mimetypes.guess_type(str(file_path))[0] or 'application/octet-stream',
                        'blob_container': CONTAINER_NAME,
                        'blob_path': blob_name,
                        'cdn_url': blob_url,
                        'checksum': file_hash,
                        'chapter_number': self.extract_chapter_number(file_path.name) if category == 'chapters' else None
                    }
                    uploaded_files.append(file_info)
                else:
                    self.errors.append(f"Failed to upload {file_path}")
        
        if not uploaded_files:
            logger.error(f"❌ No files uploaded for {title}")
            return False
        
        # Update database
        success = await self.update_database(book_data, uploaded_files, total_size)
        if success:
            logger.info(f"✅ Completed {title}: {len(uploaded_files)} files, {total_size:,} bytes")
            self.uploaded_files.extend(uploaded_files)
        
        return success
    
    def extract_chapter_number(self, filename: str) -> Optional[int]:
        """Extract chapter number from filename"""
        import re
        
        # Try various patterns
        patterns = [
            r'chapter[\s_-]*(\d+)',
            r'ch[\s_-]*(\d+)',
            r'(\d+)\.mp3',
            r'(\d+)\.m4a',
            r'part[\s_-]*(\d+)',
        ]
        
        filename_lower = filename.lower()
        for pattern in patterns:
            match = re.search(pattern, filename_lower)
            if match:
                try:
                    return int(match.group(1))
                except ValueError:
                    continue
        
        return None
    
    async def update_database(self, book_data: Dict[str, Any], uploaded_files: List[Dict], total_size: int) -> bool:
        """Update database with cloud storage information"""
        if DRY_RUN:
            logger.info("🔍 DRY RUN: Would update database")
            return True
        
        try:
            async with self.db_pool.acquire() as conn:
                async with conn.transaction():
                    book_id = book_data['id']
                    
                    # Update books table
                    await conn.execute("""
                        UPDATE books SET
                            blob_container = $2,
                            blob_path = $3,
                            storage_provider = 'azure',
                            file_size_bytes = $4,
                            file_uploaded_at = NOW(),
                            updated_at = NOW()
                        WHERE id = $1
                    """, book_id, CONTAINER_NAME, f"{book_id}/", total_size)
                    
                    # Insert file metadata
                    for file_info in uploaded_files:
                        await conn.execute("""
                            INSERT INTO file_metadata (
                                book_id, file_type, filename, original_filename,
                                file_size_bytes, mime_type, blob_container, blob_path,
                                cdn_url, checksum, chapter_number
                            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                            ON CONFLICT (book_id, blob_path) DO UPDATE SET
                                file_size_bytes = EXCLUDED.file_size_bytes,
                                cdn_url = EXCLUDED.cdn_url,
                                checksum = EXCLUDED.checksum,
                                updated_at = NOW()
                        """, 
                        file_info['book_id'], file_info['file_type'], file_info['filename'],
                        file_info['original_filename'], file_info['file_size_bytes'],
                        file_info['mime_type'], file_info['blob_container'], file_info['blob_path'],
                        file_info['cdn_url'], file_info['checksum'], file_info['chapter_number'])
            
            logger.info("✅ Database updated successfully")
            return True
            
        except Exception as e:
            logger.error(f"❌ Database update failed: {e}")
            return False
    
    async def run(self):
        """Main execution function"""
        logger.info("🚀 Starting book upload to Azure Blob Storage")
        
        if DRY_RUN:
            logger.info("🔍 DRY RUN MODE - No actual changes will be made")
        
        try:
            # Initialize connections
            await self.initialize()
            
            # Get books from database
            books = await self.get_books_from_db()
            logger.info(f"📚 Found {len(books)} books to process")
            
            if not books:
                logger.info("✅ No books need uploading")
                return
            
            # Process each book
            success_count = 0
            for book_data in books:
                try:
                    success = await self.process_book(book_data)
                    if success:
                        success_count += 1
                except Exception as e:
                    logger.error(f"❌ Error processing {book_data.get('title', 'Unknown')}: {e}")
                    self.errors.append(f"Error processing {book_data.get('title', 'Unknown')}: {e}")
            
            # Summary
            logger.info(f"\n📊 Upload Summary:")
            logger.info(f"   Books processed: {len(books)}")
            logger.info(f"   Books successful: {success_count}")
            logger.info(f"   Books failed: {len(books) - success_count}")
            logger.info(f"   Total files uploaded: {len(self.uploaded_files)}")
            logger.info(f"   Total size: {sum(f.get('file_size_bytes', 0) for f in self.uploaded_files):,} bytes")
            
            if self.errors:
                logger.error(f"\n❌ Errors encountered:")
                for error in self.errors:
                    logger.error(f"   - {error}")
            else:
                logger.info("✅ All uploads completed successfully!")
        
        except Exception as e:
            logger.error(f"❌ Upload process failed: {e}")
            raise
        
        finally:
            # Cleanup
            if self.db_pool:
                await self.db_pool.close()
            if self.blob_client:
                await self.blob_client.close()

async def main():
    """Main entry point"""
    uploader = BookUploader()
    await uploader.run()

if __name__ == "__main__":
    asyncio.run(main())