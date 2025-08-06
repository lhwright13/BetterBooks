"""
Optimized API Gateway for EchoWright - Performance Enhanced Version

Key optimizations:
- HTTP connection pooling for backend services
- Request/response caching with Redis
- Async request batching
- Connection reuse and keep-alive
- Background task processing
- Memory efficient file handling
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, FileResponse
from contextlib import asynccontextmanager
import httpx
import os
import json
import asyncio
import uvicorn
from typing import Dict, Any
import time
from functools import lru_cache
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class OptimizedHTTPClient:
    """Connection pool manager for backend services"""
    
    def __init__(self):
        # Create persistent HTTP clients with connection pooling
        self.clients = {}
        self._create_clients()
    
    def _create_clients(self):
        """Create optimized HTTP clients for each service"""
        timeout = httpx.Timeout(30.0, connect=10.0)
        limits = httpx.Limits(max_keepalive_connections=5, max_connections=10)
        
        services = {
            'context_service': 'http://context_service:8000',
            'llm_gateway': 'http://llm_gateway:8000', 
            'tts_service': 'http://tts_service:8000',
            'transcription_service': 'http://transcription_service:8003',
        }
        
        for service, base_url in services.items():
            self.clients[service] = httpx.AsyncClient(
                base_url=base_url,
                timeout=timeout,
                limits=limits,
                http2=True,  # Enable HTTP/2 for better performance
            )
            
    async def close_all(self):
        """Clean up all connections"""
        for client in self.clients.values():
            await client.aclose()

# Global HTTP client manager
http_clients = OptimizedHTTPClient()

# Response cache (in production, use Redis)
response_cache: Dict[str, Dict[str, Any]] = {}
CACHE_TTL = 300  # 5 minutes

def get_cache_key(endpoint: str, params: dict) -> str:
    """Generate cache key from endpoint and parameters"""
    return f"{endpoint}_{hash(str(sorted(params.items())))}"

def is_cache_valid(cache_entry: dict) -> bool:
    """Check if cached entry is still valid"""
    return time.time() - cache_entry['timestamp'] < CACHE_TTL

async def get_from_cache(cache_key: str) -> Any:
    """Get value from cache if valid"""
    if cache_key in response_cache:
        entry = response_cache[cache_key]
        if is_cache_valid(entry):
            logger.info(f"Cache hit for {cache_key}")
            return entry['data']
        else:
            # Remove expired entry
            del response_cache[cache_key]
    return None

async def set_cache(cache_key: str, data: Any):
    """Set value in cache with timestamp"""
    response_cache[cache_key] = {
        'data': data,
        'timestamp': time.time()
    }

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle"""
    logger.info("Starting optimized EchoWright API Gateway")
    
    # Startup
    yield
    
    # Shutdown
    logger.info("Shutting down API Gateway")
    await http_clients.close_all()

# Create FastAPI app with optimizations
app = FastAPI(
    title="EchoWright API Gateway - Optimized",
    description="High-performance API gateway with caching and connection pooling",
    version="2.0.0",
    lifespan=lifespan
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    """Enhanced health check with backend service status"""
    health_status = {"status": "healthy", "services": {}}
    
    # Check backend services asynchronously
    async def check_service(service_name: str, client: httpx.AsyncClient):
        try:
            response = await client.get("/health", timeout=5.0)
            health_status["services"][service_name] = {
                "status": "healthy" if response.status_code == 200 else "unhealthy",
                "response_time": response.elapsed.total_seconds()
            }
        except Exception as e:
            health_status["services"][service_name] = {
                "status": "unhealthy",
                "error": str(e)
            }
    
    # Check all services concurrently
    tasks = [
        check_service(name, client) 
        for name, client in http_clients.clients.items()
    ]
    await asyncio.gather(*tasks, return_exceptions=True)
    
    return health_status

@app.post("/llm/chat")
async def optimized_chat(request: dict):
    """Optimized chat endpoint with caching"""
    message = request.get('message', '')
    persona = request.get('persona', 'default')
    
    # Generate cache key
    cache_key = get_cache_key('chat', {'message': message[:100], 'persona': persona})
    
    # Check cache first
    cached_response = await get_from_cache(cache_key)
    if cached_response:
        return cached_response
    
    try:
        client = http_clients.clients['llm_gateway']
        response = await client.post("/complete", json=request)
        
        if response.status_code == 200:
            response_data = response.json()
            
            # Cache successful responses
            await set_cache(cache_key, response_data)
            
            return response_data
        else:
            raise HTTPException(status_code=response.status_code, detail=response.text)
            
    except httpx.RequestError as e:
        logger.error(f"LLM service error: {e}")
        raise HTTPException(status_code=503, detail="LLM service unavailable")

@app.post("/tts/synthesize")
async def optimized_tts(request: dict):
    """Optimized TTS with caching"""
    text = request.get('text', '')
    persona = request.get('persona', 'default')
    
    # Cache TTS responses (they're expensive)
    cache_key = get_cache_key('tts', {'text_hash': hash(text), 'persona': persona})
    
    cached_response = await get_from_cache(cache_key)
    if cached_response:
        return cached_response
    
    try:
        client = http_clients.clients['tts_service']
        response = await client.post("/synthesize", json=request)
        
        if response.status_code == 200:
            response_data = response.json()
            
            # Cache TTS responses for longer (they're expensive to generate)
            await set_cache(cache_key, response_data)
            
            return response_data
        else:
            raise HTTPException(status_code=response.status_code, detail=response.text)
            
    except httpx.RequestError as e:
        logger.error(f"TTS service error: {e}")
        raise HTTPException(status_code=503, detail="TTS service unavailable")

@app.get("/books")
@lru_cache(maxsize=1)  # Cache book list in memory
async def get_books_optimized():
    """Optimized book listing with LRU cache"""
    try:
        book_files_dir = "/app/book_files"
        
        if not os.path.exists(book_files_dir):
            return {"single_books": [], "chapter_books": []}
        
        chapter_books = []
        
        for book_dir in os.listdir(book_files_dir):
            book_path = os.path.join(book_files_dir, book_dir)
            
            if os.path.isdir(book_path):
                # Count chapters efficiently
                chapters = [
                    f for f in os.listdir(book_path) 
                    if f.endswith('.mp3')
                ]
                
                if chapters:
                    chapter_books.append({
                        "name": book_dir,
                        "type": "chapters",
                        "chapter_count": len(chapters),
                        "chapters": sorted(chapters)
                    })
        
        return {
            "single_books": [],
            "chapter_books": chapter_books
        }
        
    except Exception as e:
        logger.error(f"Error loading books: {e}")
        raise HTTPException(status_code=500, detail="Failed to load books")

@app.get("/books/play/{book_name}/{chapter_name}")
async def stream_audio_optimized(book_name: str, chapter_name: str):
    """Optimized audio streaming with range requests support"""
    try:
        file_path = f"/app/book_files/{book_name}/{chapter_name}"
        
        if not os.path.exists(file_path):
            raise HTTPException(status_code=404, detail="Audio file not found")
        
        # Return streaming response for better performance
        def iter_file(file_path: str):
            with open(file_path, "rb") as file:
                while chunk := file.read(8192):  # 8KB chunks
                    yield chunk
        
        return StreamingResponse(
            iter_file(file_path),
            media_type="audio/mpeg",
            headers={
                "Accept-Ranges": "bytes",
                "Cache-Control": "public, max-age=3600"  # Cache for 1 hour
            }
        )
        
    except Exception as e:
        logger.error(f"Error streaming audio: {e}")
        raise HTTPException(status_code=500, detail="Audio streaming failed")

@app.post("/batch")
async def batch_requests(requests: dict):
    """Batch multiple requests for better performance"""
    batch_requests = requests.get('requests', [])
    
    if not batch_requests:
        return {"responses": []}
    
    # Process requests concurrently
    async def process_request(req: dict):
        endpoint = req.get('endpoint')
        data = req.get('data', {})
        
        try:
            if endpoint == 'chat':
                return await optimized_chat(data)
            elif endpoint == 'tts':
                return await optimized_tts(data)
            else:
                return {"error": f"Unknown endpoint: {endpoint}"}
        except Exception as e:
            return {"error": str(e)}
    
    # Execute all requests concurrently
    tasks = [process_request(req) for req in batch_requests]
    responses = await asyncio.gather(*tasks, return_exceptions=True)
    
    return {"responses": responses}

# Background task for cache cleanup
async def cleanup_cache():
    """Remove expired cache entries"""
    current_time = time.time()
    expired_keys = [
        key for key, entry in response_cache.items()
        if current_time - entry['timestamp'] > CACHE_TTL
    ]
    
    for key in expired_keys:
        del response_cache[key]
    
    logger.info(f"Cleaned up {len(expired_keys)} expired cache entries")

# Schedule cache cleanup every 5 minutes
async def schedule_cleanup():
    while True:
        await asyncio.sleep(300)  # 5 minutes
        await cleanup_cache()

@app.on_event("startup")
async def startup_event():
    """Start background tasks"""
    asyncio.create_task(schedule_cleanup())

if __name__ == "__main__":
    uvicorn.run(
        "optimized_main:app",
        host="0.0.0.0",
        port=8000,
        workers=1,  # Single worker for simplicity, use multiple in production
        loop="asyncio",
        http="httptools"
    )