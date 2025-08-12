"""Performance tests using Locust for EchoWright platform."""

import json
import random
import time
from locust import HttpUser, task, between, events
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class EchoWrightUser(HttpUser):
    """Simulates a typical EchoWright platform user."""
    
    wait_time = between(1, 3)  # Wait 1-3 seconds between requests
    
    def on_start(self):
        """Initialize user session."""
        self.context_ids = []
        self.test_texts = [
            "Chapter 1: The hero begins their journey through the mystical lands.",
            "Chapter 2: Challenges arise as dark forces gather in the distance.",
            "Chapter 3: Allies are found in the most unexpected places.",
            "Chapter 4: The quest for the ancient artifact intensifies.",
            "Chapter 5: Secrets of the past are revealed through ancient texts.",
        ]
        self.prompts = [
            "Summarize this chapter in one sentence.",
            "What are the main themes in this text?",
            "Describe the mood and atmosphere.",
            "Who are the key characters mentioned?",
            "What conflicts are presented in this chapter?",
        ]
        
        # Authenticate or setup session if needed
        self.client.headers.update({
            "Content-Type": "application/json",
            "X-Request-ID": f"load-test-{random.randint(1000, 9999)}"
        })
    
    def on_stop(self):
        """Clean up user session."""
        # Clean up any created contexts
        for context_id in self.context_ids:
            try:
                self.client.delete(f"/api/v1/context/{context_id}")
            except Exception as e:
                logger.warning(f"Failed to cleanup context {context_id}: {e}")
    
    @task(10)
    def health_check(self):
        """Test health endpoint - high frequency."""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")
    
    @task(5)
    def detailed_health_check(self):
        """Test detailed health endpoint."""
        with self.client.get("/health/detailed", catch_response=True) as response:
            if response.status_code == 200:
                data = response.json()
                if data.get("status") == "healthy":
                    response.success()
                else:
                    response.failure("Service reported unhealthy")
            else:
                response.failure(f"Detailed health check failed: {response.status_code}")
    
    @task(8)
    def store_context(self):
        """Test context storage."""
        text = random.choice(self.test_texts)
        payload = {
            "text": text,
            "metadata": {
                "book_id": f"book_{random.randint(1, 100)}",
                "chapter": random.randint(1, 20),
                "load_test": True,
                "timestamp": time.time()
            }
        }
        
        with self.client.post("/api/v1/context/store", json=payload, catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    context_id = data.get("id")
                    if context_id:
                        self.context_ids.append(context_id)
                        response.success()
                    else:
                        response.failure("No context ID returned")
                except Exception as e:
                    response.failure(f"Invalid JSON response: {e}")
            else:
                response.failure(f"Context storage failed: {response.status_code}")
    
    @task(6)
    def search_context(self):
        """Test context search."""
        queries = [
            "hero journey adventure",
            "dark forces challenges",
            "ancient artifact quest",
            "mystical lands exploration",
            "allies friendship"
        ]
        
        payload = {
            "query": random.choice(queries),
            "limit": random.randint(3, 10),
            "threshold": round(random.uniform(0.5, 0.9), 2)
        }
        
        with self.client.post("/api/v1/context/search", json=payload, catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if "results" in data:
                        response.success()
                    else:
                        response.failure("No results field in response")
                except Exception as e:
                    response.failure(f"Invalid JSON response: {e}")
            else:
                response.failure(f"Context search failed: {response.status_code}")
    
    @task(7)
    def llm_completion(self):
        """Test LLM text completion."""
        prompt = random.choice(self.prompts)
        payload = {
            "prompt": prompt,
            "max_tokens": random.randint(50, 200)
        }
        
        with self.client.post("/api/v1/llm/complete", json=payload, catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if "text" in data and len(data["text"]) > 0:
                        response.success()
                    else:
                        response.failure("Empty or missing text in response")
                except Exception as e:
                    response.failure(f"Invalid JSON response: {e}")
            else:
                response.failure(f"LLM completion failed: {response.status_code}")
    
    @task(3)
    def tts_synthesis(self):
        """Test TTS synthesis."""
        texts = [
            "Hello, this is a test of the text-to-speech system.",
            "The quick brown fox jumps over the lazy dog.",
            "Welcome to EchoWright, your audiobook companion.",
            "Chapter summary: The hero discovers a hidden power.",
            "Thank you for using our text-to-speech service."
        ]
        
        payload = {
            "text": random.choice(texts),
            "voice": "default",
            "format": "mp3"
        }
        
        with self.client.post("/api/v1/tts/synthesize", json=payload, catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if "audio_url" in data:
                        response.success()
                    else:
                        response.failure("No audio URL in response")
                except Exception as e:
                    response.failure(f"Invalid JSON response: {e}")
            else:
                response.failure(f"TTS synthesis failed: {response.status_code}")
    
    @task(2)
    def list_llm_configs(self):
        """Test listing LLM configurations."""
        with self.client.get("/api/v1/llm/configs", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if "configs" in data:
                        response.success()
                    else:
                        response.failure("No configs field in response")
                except Exception as e:
                    response.failure(f"Invalid JSON response: {e}")
            else:
                response.failure(f"List configs failed: {response.status_code}")
    
    @task(2)
    def list_tts_voices(self):
        """Test listing TTS voices."""
        with self.client.get("/api/v1/tts/voices", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if "voices" in data:
                        response.success()
                    else:
                        response.failure("No voices field in response")
                except Exception as e:
                    response.failure(f"Invalid JSON response: {e}")
            else:
                response.failure(f"List voices failed: {response.status_code}")
    
    @task(1)
    def get_context_by_id(self):
        """Test retrieving context by ID."""
        if self.context_ids:
            context_id = random.choice(self.context_ids)
            with self.client.get(f"/api/v1/context/{context_id}", catch_response=True) as response:
                if response.status_code == 200:
                    try:
                        data = response.json()
                        if "id" in data and "text" in data:
                            response.success()
                        else:
                            response.failure("Missing required fields in response")
                    except Exception as e:
                        response.failure(f"Invalid JSON response: {e}")
                elif response.status_code == 404:
                    # Context might have been cleaned up, that's okay
                    response.success()
                else:
                    response.failure(f"Get context failed: {response.status_code}")
    
    @task(1)
    def cache_stats(self):
        """Test cache statistics endpoint."""
        with self.client.get("/api/v1/llm/cache/stats", catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    if "cache_enabled" in data:
                        response.success()
                    else:
                        response.failure("No cache_enabled field in response")
                except Exception as e:
                    response.failure(f"Invalid JSON response: {e}")
            else:
                response.failure(f"Cache stats failed: {response.status_code}")


class PowerUser(EchoWrightUser):
    """Simulates a power user with more intensive usage patterns."""
    
    wait_time = between(0.5, 1.5)  # Faster requests
    weight = 1  # Lower weight, fewer power users
    
    @task(15)
    def batch_context_operations(self):
        """Perform batch context operations."""
        # Store multiple contexts
        context_ids = []
        for i in range(3):
            text = f"Batch operation {i}: {random.choice(self.test_texts)}"
            payload = {
                "text": text,
                "metadata": {
                    "batch_id": f"batch_{random.randint(1000, 9999)}",
                    "index": i,
                    "power_user": True
                }
            }
            
            with self.client.post("/api/v1/context/store", json=payload, catch_response=True) as response:
                if response.status_code == 200:
                    try:
                        data = response.json()
                        context_id = data.get("id")
                        if context_id:
                            context_ids.append(context_id)
                            self.context_ids.append(context_id)
                    except Exception:
                        pass
        
        # Perform searches
        if context_ids:
            search_payload = {
                "query": "batch operation",
                "limit": 10,
                "threshold": 0.6
            }
            
            self.client.post("/api/v1/context/search", json=search_payload)
    
    @task(10)
    def intensive_llm_usage(self):
        """Intensive LLM usage with longer prompts."""
        long_prompts = [
            "Analyze the narrative structure, character development, and thematic elements in this chapter. Provide detailed insights into the author's writing style and literary techniques used.",
            "Compare and contrast the protagonist's journey in this chapter with classical hero's journey archetypes. Discuss the symbolic significance of key events and character interactions.",
            "Examine the world-building elements presented in this chapter. How does the author establish the setting, culture, and magical systems? What implications do these have for the overall narrative?"
        ]
        
        payload = {
            "prompt": random.choice(long_prompts),
            "max_tokens": random.randint(200, 500)
        }
        
        self.client.post("/api/v1/llm/complete", json=payload)


class ReadOnlyUser(EchoWrightUser):
    """Simulates users who primarily read/search without creating content."""
    
    weight = 3  # More read-only users
    
    def on_start(self):
        """Initialize read-only user."""
        super().on_start()
        # Read-only users don't create contexts
        self.context_ids = []
    
    @task(20)
    def health_check(self):
        """Health checks are primary activity."""
        super().health_check()
    
    @task(15)
    def search_context(self):
        """Heavy search usage."""
        super().search_context()
    
    @task(10)
    def llm_completion(self):
        """Moderate LLM usage."""
        super().llm_completion()
    
    @task(5)
    def list_resources(self):
        """List available resources."""
        # Alternate between listing configs and voices
        if random.choice([True, False]):
            self.client.get("/api/v1/llm/configs")
        else:
            self.client.get("/api/v1/tts/voices")
    
    # Disable context creation for read-only users
    def store_context(self):
        pass


# Custom events and statistics
@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when test starts."""
    logger.info("Starting EchoWright performance test")
    logger.info(f"Target host: {environment.host}")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when test stops."""
    logger.info("EchoWright performance test completed")
    
    # Log basic statistics
    stats = environment.stats.total
    logger.info(f"Total requests: {stats.num_requests}")
    logger.info(f"Failed requests: {stats.num_failures}")
    logger.info(f"Average response time: {stats.avg_response_time:.2f}ms")
    logger.info(f"95th percentile: {stats.get_response_time_percentile(0.95):.2f}ms")


# Custom task sets for specific scenarios
class ContextHeavyUser(HttpUser):
    """User focused on context operations."""
    
    wait_time = between(1, 2)
    weight = 1
    
    def on_start(self):
        self.context_ids = []
        self.client.headers.update({"Content-Type": "application/json"})
    
    @task(5)
    def store_context(self):
        """Store context frequently."""
        payload = {
            "text": f"Context heavy user content {random.randint(1, 1000)}",
            "metadata": {"user_type": "context_heavy"}
        }
        
        response = self.client.post("/api/v1/context/store", json=payload)
        if response.status_code == 200:
            try:
                context_id = response.json().get("id")
                if context_id:
                    self.context_ids.append(context_id)
            except Exception:
                pass
    
    @task(8)
    def search_context(self):
        """Search frequently."""
        queries = ["content", "user", "heavy", "context", "test"]
        payload = {
            "query": random.choice(queries),
            "limit": 5
        }
        
        self.client.post("/api/v1/context/search", json=payload)
    
    @task(2)
    def manage_contexts(self):
        """Update or delete contexts."""
        if self.context_ids:
            context_id = self.context_ids.pop()
            
            if random.choice([True, False]):
                # Update context
                payload = {
                    "metadata": {"updated": True, "timestamp": time.time()}
                }
                self.client.put(f"/api/v1/context/{context_id}", json=payload)
            else:
                # Delete context
                self.client.delete(f"/api/v1/context/{context_id}")


class LLMHeavyUser(HttpUser):
    """User focused on LLM operations."""
    
    wait_time = between(2, 4)  # Longer wait due to LLM processing time
    weight = 1
    
    def on_start(self):
        self.client.headers.update({"Content-Type": "application/json"})
    
    @task(10)
    def various_completions(self):
        """Generate various types of completions."""
        prompts = [
            "Write a short story about",
            "Explain the concept of",
            "Compare and contrast",
            "Analyze the following",
            "Create a summary of",
            "Describe in detail",
            "What are the implications of",
            "How would you approach"
        ]
        
        topics = [
            "artificial intelligence",
            "quantum computing",
            "space exploration",
            "literary themes",
            "historical events",
            "scientific discoveries"
        ]
        
        prompt = f"{random.choice(prompts)} {random.choice(topics)}"
        payload = {
            "prompt": prompt,
            "max_tokens": random.randint(100, 300)
        }
        
        self.client.post("/api/v1/llm/complete", json=payload)
    
    @task(3)
    def config_usage(self):
        """Use different configurations."""
        # First get available configs
        response = self.client.get("/api/v1/llm/configs")
        if response.status_code == 200:
            try:
                configs = response.json().get("configs", [])
                if configs:
                    config = random.choice(configs)
                    payload = {
                        "prompt": "Test with custom config",
                        "max_tokens": 100,
                        "config": config
                    }
                    self.client.post("/api/v1/llm/complete", json=payload)
            except Exception:
                pass