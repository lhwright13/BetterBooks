"""
FastAPI middleware for automatic request/response compression.

Provides intelligent compression for HTTP requests and responses to improve
API performance and reduce bandwidth usage.

Features:
- Automatic response compression (gzip, deflate, brotli)
- Request body compression support
- Content-type aware compression
- Size threshold configuration
- Performance metrics
- Compression ratio tracking
"""

import gzip
import zlib
import time
from typing import Optional, Set, Tuple, Dict, Any
from fastapi import Request, Response
from fastapi.responses import Response as FastAPIResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
import logging
import json

try:
    import brotli
    BROTLI_AVAILABLE = True
except ImportError:
    BROTLI_AVAILABLE = False

logger = logging.getLogger(__name__)


class CompressionMiddleware(BaseHTTPMiddleware):
    """
    Middleware for automatic request/response compression.
    
    Supports multiple compression algorithms with intelligent selection
    based on client capabilities and content characteristics.
    """
    
    # Content types that benefit from compression
    COMPRESSIBLE_TYPES = {
        "application/json",
        "application/javascript",
        "application/xml",
        "application/rss+xml",
        "application/atom+xml",
        "text/html",
        "text/css",
        "text/javascript", 
        "text/xml",
        "text/plain",
        "text/csv",
        "image/svg+xml"
    }
    
    # Content types to never compress
    INCOMPRESSIBLE_TYPES = {
        "image/jpeg",
        "image/png", 
        "image/gif",
        "image/webp",
        "audio/mpeg",
        "audio/wav",
        "video/mp4",
        "video/webm",
        "application/pdf",
        "application/zip",
        "application/gzip",
        "application/x-compressed"
    }
    
    def __init__(
        self,
        app: ASGIApp,
        minimum_size: int = 500,
        compression_level: int = 6,
        exclude_paths: Optional[Set[str]] = None,
        include_types: Optional[Set[str]] = None,
        exclude_types: Optional[Set[str]] = None
    ):
        """
        Initialize compression middleware.
        
        Args:
            app: ASGI application
            minimum_size: Minimum response size to compress (bytes)
            compression_level: Compression level (1-9, higher = better compression)
            exclude_paths: Paths to exclude from compression
            include_types: Additional content types to compress
            exclude_types: Content types to exclude from compression
        """
        super().__init__(app)
        self.minimum_size = minimum_size
        self.compression_level = max(1, min(9, compression_level))
        self.exclude_paths = exclude_paths or set()
        
        # Build final sets of compressible/incompressible types
        self.compressible_types = self.COMPRESSIBLE_TYPES.copy()
        if include_types:
            self.compressible_types.update(include_types)
        
        self.incompressible_types = self.INCOMPRESSIBLE_TYPES.copy()
        if exclude_types:
            self.incompressible_types.update(exclude_types)
        
        # Remove any conflicts (incompressible takes precedence)
        self.compressible_types -= self.incompressible_types
        
        # Track compression statistics
        self.stats = {
            "total_requests": 0,
            "compressed_responses": 0,
            "bytes_saved": 0,
            "avg_compression_ratio": 0.0,
            "compression_time_ms": 0.0,
            "algorithms_used": {"gzip": 0, "deflate": 0, "brotli": 0}
        }
        
        logger.info(
            "Compression middleware initialized",
            minimum_size=minimum_size,
            compression_level=compression_level,
            brotli_available=BROTLI_AVAILABLE
        )
    
    def _should_compress_path(self, path: str) -> bool:
        """Check if path should be compressed."""
        return path not in self.exclude_paths
    
    def _should_compress_content_type(self, content_type: str) -> bool:
        """Check if content type should be compressed."""
        if not content_type:
            return False
        
        # Extract base content type (remove charset, boundary, etc.)
        base_type = content_type.split(';')[0].strip().lower()
        
        # Check incompressible types first
        if base_type in self.incompressible_types:
            return False
        
        # Check compressible types
        return base_type in self.compressible_types
    
    def _get_accepted_encodings(self, request: Request) -> Set[str]:
        """Extract accepted encodings from request headers."""
        accept_encoding = request.headers.get("accept-encoding", "")
        if not accept_encoding:
            return set()
        
        encodings = set()
        for encoding in accept_encoding.split(','):
            encoding = encoding.strip().lower()
            # Handle quality values (q=0.5) by taking first part
            if ';' in encoding:
                encoding = encoding.split(';')[0].strip()
            encodings.add(encoding)
        
        return encodings
    
    def _select_compression_algorithm(self, accepted_encodings: Set[str]) -> Optional[str]:
        """Select best compression algorithm based on client support."""
        # Priority order: brotli > gzip > deflate
        if BROTLI_AVAILABLE and ("br" in accepted_encodings or "brotli" in accepted_encodings):
            return "brotli"
        elif "gzip" in accepted_encodings:
            return "gzip"
        elif "deflate" in accepted_encodings:
            return "deflate"
        return None
    
    def _compress_data(self, data: bytes, algorithm: str) -> Tuple[bytes, float]:
        """
        Compress data using specified algorithm.
        
        Returns:
            Tuple of (compressed_data, compression_ratio)
        """
        start_time = time.time()
        original_size = len(data)
        
        try:
            if algorithm == "brotli" and BROTLI_AVAILABLE:
                compressed_data = brotli.compress(
                    data, 
                    quality=self.compression_level,
                    mode=brotli.MODE_TEXT
                )
            elif algorithm == "gzip":
                compressed_data = gzip.compress(
                    data, 
                    compresslevel=self.compression_level
                )
            elif algorithm == "deflate":
                compressed_data = zlib.compress(
                    data, 
                    level=self.compression_level
                )
            else:
                return data, 1.0
            
            compressed_size = len(compressed_data)
            compression_ratio = compressed_size / original_size if original_size > 0 else 1.0
            
            # Update statistics
            compression_time = (time.time() - start_time) * 1000
            self.stats["compression_time_ms"] = (
                self.stats["compression_time_ms"] * 0.9 + compression_time * 0.1
            )
            self.stats["algorithms_used"][algorithm] += 1
            
            return compressed_data, compression_ratio
            
        except Exception as e:
            logger.warning(f"Compression failed with {algorithm}: {e}")
            return data, 1.0
    
    def _decompress_request_body(self, body: bytes, encoding: str) -> bytes:
        """Decompress request body if compressed."""
        try:
            if encoding == "gzip":
                return gzip.decompress(body)
            elif encoding == "deflate":
                return zlib.decompress(body)
            elif encoding == "brotli" and BROTLI_AVAILABLE:
                return brotli.decompress(body)
        except Exception as e:
            logger.warning(f"Request decompression failed: {e}")
        
        return body
    
    async def dispatch(self, request: Request, call_next) -> Response:
        """Process request and response with compression."""
        self.stats["total_requests"] += 1
        
        # Check if this path should be compressed
        if not self._should_compress_path(request.url.path):
            return await call_next(request)
        
        # Handle compressed request body
        if request.headers.get("content-encoding"):
            try:
                body = await request.body()
                encoding = request.headers.get("content-encoding").lower()
                decompressed_body = self._decompress_request_body(body, encoding)
                
                # Replace request body with decompressed version
                # Note: This is a simplified approach. In production, you might want
                # to use a more sophisticated method to replace the request body.
                request._body = decompressed_body
                
            except Exception as e:
                logger.warning(f"Failed to decompress request body: {e}")
        
        # Get client's accepted encodings
        accepted_encodings = self._get_accepted_encodings(request)
        compression_algorithm = self._select_compression_algorithm(accepted_encodings)
        
        # Process the request
        response = await call_next(request)
        
        # Skip compression if no algorithm available or it's not a compressible response
        if not compression_algorithm or not hasattr(response, 'body'):
            return response
        
        # Get response body
        response_body = b""
        async for chunk in response.body_iterator:
            response_body += chunk
        
        # Check if response should be compressed
        content_type = response.headers.get("content-type", "")
        content_length = len(response_body)
        
        should_compress = (
            content_length >= self.minimum_size and
            self._should_compress_content_type(content_type) and
            "content-encoding" not in response.headers  # Don't double-compress
        )
        
        if not should_compress:
            # Return original response
            return Response(
                content=response_body,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=response.media_type
            )
        
        # Compress the response
        compressed_body, compression_ratio = self._compress_data(
            response_body, 
            compression_algorithm
        )
        
        # Only use compression if it actually reduces size
        if len(compressed_body) >= len(response_body):
            logger.debug("Compression didn't reduce size, sending uncompressed")
            return Response(
                content=response_body,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=response.media_type
            )
        
        # Update statistics
        bytes_saved = len(response_body) - len(compressed_body)
        self.stats["compressed_responses"] += 1
        self.stats["bytes_saved"] += bytes_saved
        
        # Update average compression ratio
        old_avg = self.stats["avg_compression_ratio"]
        count = self.stats["compressed_responses"]
        self.stats["avg_compression_ratio"] = (
            (old_avg * (count - 1) + compression_ratio) / count
        )
        
        # Create compressed response with appropriate headers
        headers = dict(response.headers)
        headers["content-encoding"] = compression_algorithm
        headers["content-length"] = str(len(compressed_body))
        headers["vary"] = headers.get("vary", "") + ", Accept-Encoding"
        
        logger.debug(
            "Response compressed",
            algorithm=compression_algorithm,
            original_size=len(response_body),
            compressed_size=len(compressed_body),
            compression_ratio=f"{compression_ratio:.3f}",
            bytes_saved=bytes_saved
        )
        
        return Response(
            content=compressed_body,
            status_code=response.status_code,
            headers=headers,
            media_type=response.media_type
        )
    
    def get_stats(self) -> Dict[str, Any]:
        """Get compression statistics."""
        total_requests = self.stats["total_requests"]
        compressed_responses = self.stats["compressed_responses"]
        
        return {
            "total_requests": total_requests,
            "compressed_responses": compressed_responses,
            "compression_rate": (
                compressed_responses / total_requests 
                if total_requests > 0 else 0.0
            ),
            "bytes_saved": self.stats["bytes_saved"],
            "avg_compression_ratio": self.stats["avg_compression_ratio"],
            "avg_compression_time_ms": self.stats["compression_time_ms"],
            "algorithms_used": self.stats["algorithms_used"].copy(),
            "brotli_available": BROTLI_AVAILABLE
        }
    
    def reset_stats(self) -> None:
        """Reset compression statistics."""
        self.stats = {
            "total_requests": 0,
            "compressed_responses": 0,
            "bytes_saved": 0,
            "avg_compression_ratio": 0.0,
            "compression_time_ms": 0.0,
            "algorithms_used": {"gzip": 0, "deflate": 0, "brotli": 0}
        }
        logger.info("Compression statistics reset")


def add_compression_to_app(
    app,
    minimum_size: int = 500,
    compression_level: int = 6,
    exclude_paths: Optional[Set[str]] = None
) -> CompressionMiddleware:
    """
    Add compression middleware to FastAPI application.
    
    Args:
        app: FastAPI application instance
        minimum_size: Minimum response size to compress (bytes)
        compression_level: Compression level (1-9)
        exclude_paths: Paths to exclude from compression
        
    Returns:
        CompressionMiddleware instance for statistics access
    """
    middleware = CompressionMiddleware(
        app=app,
        minimum_size=minimum_size,
        compression_level=compression_level,
        exclude_paths=exclude_paths
    )
    
    app.add_middleware(CompressionMiddleware, **{
        "minimum_size": minimum_size,
        "compression_level": compression_level,
        "exclude_paths": exclude_paths
    })
    
    # Add stats endpoint
    @app.get("/compression/stats")
    def get_compression_stats():
        """Get compression middleware statistics."""
        return middleware.get_stats()
    
    @app.post("/compression/reset-stats") 
    def reset_compression_stats():
        """Reset compression statistics."""
        middleware.reset_stats()
        return {"message": "Compression statistics reset"}
    
    return middleware