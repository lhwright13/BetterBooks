"""Simplified test version of LLM Gateway for Azure OpenAI testing."""

import os
import sys
import types
import logging
from pathlib import Path

# Simple logging setup for testing
def setup_logging(service_name="llm_gateway", log_level="INFO"):
    logger = logging.getLogger(service_name)
    logger.setLevel(getattr(logging, log_level))
    handler = logging.StreamHandler()
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    return logger

def get_request_id():
    return "test-request-id"

# Stub implementations for missing components
class LoggingMiddleware:
    def __init__(self, logger):
        self.logger = logger

class MetricsCollector:
    def create_counter(self, name, desc, labels=None):
        class Counter:
            def labels(self, **kwargs):
                class LabeledCounter:
                    def inc(self): pass
                return LabeledCounter()
        return Counter()
    
    def create_histogram(self, name, desc, buckets=None):
        class Histogram:
            def observe(self, value): pass
        return Histogram()

def setup_metrics(app, service_name):
    return MetricsCollector()

try:
    from openai import AzureOpenAI
except Exception:
    AzureOpenAI = types.SimpleNamespace()

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Import config and prompt modifier
try:
    from config import load_config
except ImportError:
    def load_config(path=None):
        return {
            "model": "gpt-4o-mini",
            "api_key": os.getenv("AZURE_OPENAI_API_KEY", "test-key"),
            "azure_endpoint": os.getenv("AZURE_OPENAI_ENDPOINT", "https://test.openai.azure.com/"),
            "deployment_name": os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4o-mini"),
            "api_version": os.getenv("AZURE_OPENAI_API_VERSION", "2024-10-01-preview"),
            "generation_config": {"temperature": 0.7, "max_tokens": 4000},
            "prompt_options": {},
            "base_preprompt": ""
        }

try:
    from prompt_modifier import modify_prompt
except ImportError:
    def modify_prompt(prompt, options):
        return prompt

# Load configuration
cfg = load_config()

# Validate Azure OpenAI configuration
api_key = cfg["api_key"]
azure_endpoint = cfg["azure_endpoint"]
deployment_name = cfg["deployment_name"]
api_version = cfg["api_version"]

if not api_key or api_key.strip() == "":
    raise ValueError("Valid AZURE_OPENAI_API_KEY environment variable is required")
if not azure_endpoint or azure_endpoint.strip() == "":
    raise ValueError("Valid AZURE_OPENAI_ENDPOINT environment variable is required")

# Set up logging
logger = setup_logging(service_name="llm_gateway", log_level=os.getenv("LOG_LEVEL", "INFO"))

logger.info(f"Configuring Azure OpenAI Gateway - endpoint: {azure_endpoint[:30] + '...' if len(azure_endpoint) > 30 else azure_endpoint}, deployment: {deployment_name}, api_version: {api_version}")

# Initialize Azure OpenAI client
client = AzureOpenAI(
    api_key=api_key,
    api_version=api_version,
    azure_endpoint=azure_endpoint
)
model_name = cfg["model"]
gen_config_defaults = cfg.get("generation_config", {})

# FastAPI application instance
app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Set up metrics (stub)
metrics_collector = setup_metrics(app, "llm_gateway")
model_selection_counter = metrics_collector.create_counter("model_selections_total", "Total model selections", ["config_name"])
prompt_length_histogram = metrics_collector.create_histogram("prompt_length_chars", "Prompt length in characters")

@app.get("/health")
def health() -> dict:
    """Endpoint used to confirm the service is running."""
    return {"status": "ok", "service": "llm_gateway", "provider": "azure_openai"}

class CompletionRequest(BaseModel):
    """Schema for completion requests."""
    prompt: str
    max_tokens: int = 4000
    config: str | None = None

@app.post("/complete")
def complete(req: CompletionRequest) -> dict:
    """Call Azure OpenAI to generate a text completion."""
    
    # Track metrics (stub)
    prompt_length_histogram.observe(len(req.prompt))
    model_selection_counter.labels(config_name=req.config or "default").inc()

    prompt = modify_prompt(req.prompt, cfg.get("prompt_options", {}))
    base_preprompt = cfg.get("base_preprompt", "")
    if base_preprompt:
        prompt = f"{base_preprompt}\n\n{prompt}"
    
    try:
        # Map configuration to OpenAI parameters
        openai_params = {
            "model": deployment_name,
            "max_tokens": req.max_tokens,
            "temperature": gen_config_defaults.get("temperature", 0.7),
        }
        
        # Add optional parameters if present
        if "top_p" in gen_config_defaults:
            openai_params["top_p"] = gen_config_defaults["top_p"]
        if "frequency_penalty" in gen_config_defaults:
            openai_params["frequency_penalty"] = gen_config_defaults["frequency_penalty"]
        if "presence_penalty" in gen_config_defaults:
            openai_params["presence_penalty"] = gen_config_defaults["presence_penalty"]
        
        logger.debug(f"Generating completion - prompt_length: {len(prompt)}, config: {req.config}")
        
        # Create messages array for OpenAI chat completion
        messages = [
            {"role": "user", "content": prompt}
        ]
        
        # Call Azure OpenAI
        response = client.chat.completions.create(
            messages=messages,
            **openai_params
        )
        
    except Exception as exc:
        logger.error(f"Azure OpenAI generation failed: {exc}")
        raise HTTPException(status_code=502, detail=str(exc))

    # Validate response structure
    if not response.choices or not response.choices[0].message or not response.choices[0].message.content:
        raise HTTPException(status_code=502, detail="Invalid response from Azure OpenAI")
    
    response_data = {"text": response.choices[0].message.content.strip()}
    logger.info(f"Azure OpenAI completion successful - prompt_length: {len(prompt)}, response_length: {len(response_data['text'])}")
    
    return response_data

@app.get("/configs")
def list_configs() -> dict:
    """Return available configuration names."""
    return {"configs": []}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)  # Use port 8002 to match docker-compose