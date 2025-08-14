"""
Azure OpenAI Client for BetterBooks

This module provides a unified interface to Azure OpenAI Service for:
- Chapter summaries
- Question generation  
- Content analysis

Supports GPT-4 and GPT-3.5-turbo models with proper authentication,
error handling, and cost tracking.
"""

import os
import json
import asyncio
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

import aiohttp
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class LLMResponse:
    """Response from Azure OpenAI service."""
    content: str
    model: str
    tokens_used: int
    prompt_tokens: int
    completion_tokens: int
    cost_estimate: float
    response_time: float
    success: bool
    error_message: Optional[str] = None


@dataclass
class LLMConfig:
    """Configuration for Azure OpenAI."""
    endpoint: str
    api_key: str
    deployment_name: str
    api_version: str
    model_name: str
    max_tokens: int = 1000
    temperature: float = 0.3
    timeout: float = 30.0


class AzureLLMClient:
    """Azure OpenAI client with cost tracking and error handling."""
    
    def __init__(self, config: Optional[LLMConfig] = None):
        """Initialize Azure OpenAI client."""
        self.config = config or self._load_config_from_env()
        self.session: Optional[aiohttp.ClientSession] = None
        
        # Cost tracking (approximate USD pricing)
        self.pricing = {
            "gpt-4": {"input": 0.01, "output": 0.03},  # per 1K tokens
            "gpt-4-turbo": {"input": 0.01, "output": 0.03},
            "gpt-35-turbo": {"input": 0.0005, "output": 0.0015},
            "gpt-3.5-turbo": {"input": 0.0005, "output": 0.0015}
        }
        
        # Usage tracking
        self.total_tokens_used = 0
        self.total_cost_estimate = 0.0
        self.request_count = 0
        
    def _load_config_from_env(self) -> LLMConfig:
        """Load configuration from environment variables."""
        return LLMConfig(
            endpoint=os.getenv("AZURE_OPENAI_ENDPOINT", ""),
            api_key=os.getenv("AZURE_OPENAI_API_KEY", ""),
            deployment_name=os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4"),
            api_version=os.getenv("AZURE_OPENAI_API_VERSION", "2024-02-15-preview"),
            model_name=os.getenv("AZURE_OPENAI_MODEL_NAME", "gpt-4"),
            max_tokens=int(os.getenv("AZURE_OPENAI_MAX_TOKENS", "1000")),
            temperature=float(os.getenv("AZURE_OPENAI_TEMPERATURE", "0.3")),
            timeout=float(os.getenv("AZURE_OPENAI_TIMEOUT", "30.0"))
        )
    
    async def __aenter__(self):
        """Async context manager entry."""
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.session:
            await self.session.close()
            self.session = None
    
    async def complete(
        self,
        prompt: str,
        max_tokens: Optional[int] = None,
        temperature: Optional[float] = None,
        system_message: Optional[str] = None
    ) -> LLMResponse:
        """
        Complete a prompt using Azure OpenAI.
        
        Args:
            prompt: The user prompt
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature (0-1)
            system_message: Optional system message
            
        Returns:
            LLMResponse with content and metadata
        """
        if not self.config.endpoint or not self.config.api_key:
            return LLMResponse(
                content="",
                model=self.config.model_name,
                tokens_used=0,
                prompt_tokens=0,
                completion_tokens=0,
                cost_estimate=0.0,
                response_time=0.0,
                success=False,
                error_message="Azure OpenAI configuration missing"
            )
        
        start_time = datetime.now()
        
        # Prepare request
        url = f"{self.config.endpoint}/openai/deployments/{self.config.deployment_name}/chat/completions"
        
        messages = []
        if system_message:
            messages.append({"role": "system", "content": system_message})
        messages.append({"role": "user", "content": prompt})
        
        headers = {
            "Content-Type": "application/json",
            "api-key": self.config.api_key
        }
        
        data = {
            "messages": messages,
            "max_tokens": max_tokens or self.config.max_tokens,
            "temperature": temperature or self.config.temperature,
            "api-version": self.config.api_version
        }
        
        try:
            if not self.session:
                self.session = aiohttp.ClientSession()
                
            async with self.session.post(
                url,
                headers=headers,
                json=data,
                timeout=aiohttp.ClientTimeout(total=self.config.timeout)
            ) as response:
                response_time = (datetime.now() - start_time).total_seconds()
                
                if response.status == 200:
                    result = await response.json()
                    
                    # Extract response data
                    content = result["choices"][0]["message"]["content"]
                    usage = result.get("usage", {})
                    prompt_tokens = usage.get("prompt_tokens", 0)
                    completion_tokens = usage.get("completion_tokens", 0)
                    total_tokens = usage.get("total_tokens", prompt_tokens + completion_tokens)
                    
                    # Calculate cost estimate
                    cost_estimate = self._calculate_cost(prompt_tokens, completion_tokens)
                    
                    # Update tracking
                    self.total_tokens_used += total_tokens
                    self.total_cost_estimate += cost_estimate
                    self.request_count += 1
                    
                    logger.info(f"Azure OpenAI request successful: {total_tokens} tokens, ${cost_estimate:.4f}")
                    
                    return LLMResponse(
                        content=content,
                        model=self.config.model_name,
                        tokens_used=total_tokens,
                        prompt_tokens=prompt_tokens,
                        completion_tokens=completion_tokens,
                        cost_estimate=cost_estimate,
                        response_time=response_time,
                        success=True
                    )
                else:
                    error_text = await response.text()
                    logger.error(f"Azure OpenAI request failed: {response.status} - {error_text}")
                    
                    return LLMResponse(
                        content="",
                        model=self.config.model_name,
                        tokens_used=0,
                        prompt_tokens=0,
                        completion_tokens=0,
                        cost_estimate=0.0,
                        response_time=response_time,
                        success=False,
                        error_message=f"HTTP {response.status}: {error_text}"
                    )
                    
        except asyncio.TimeoutError:
            response_time = (datetime.now() - start_time).total_seconds()
            logger.error("Azure OpenAI request timed out")
            
            return LLMResponse(
                content="",
                model=self.config.model_name,
                tokens_used=0,
                prompt_tokens=0,
                completion_tokens=0,
                cost_estimate=0.0,
                response_time=response_time,
                success=False,
                error_message="Request timed out"
            )
            
        except Exception as e:
            response_time = (datetime.now() - start_time).total_seconds()
            logger.error(f"Azure OpenAI request error: {e}")
            
            return LLMResponse(
                content="",
                model=self.config.model_name,
                tokens_used=0,
                prompt_tokens=0,
                completion_tokens=0,
                cost_estimate=0.0,
                response_time=response_time,
                success=False,
                error_message=str(e)
            )
    
    def _calculate_cost(self, prompt_tokens: int, completion_tokens: int) -> float:
        """Calculate estimated cost for the request."""
        model_key = self.config.model_name.lower()
        
        # Map deployment names to pricing keys
        if "gpt-4" in model_key:
            pricing_key = "gpt-4"
        elif "gpt-35" in model_key or "gpt-3.5" in model_key:
            pricing_key = "gpt-35-turbo"
        else:
            pricing_key = "gpt-4"  # Default to higher pricing
        
        if pricing_key in self.pricing:
            input_cost = (prompt_tokens / 1000) * self.pricing[pricing_key]["input"]
            output_cost = (completion_tokens / 1000) * self.pricing[pricing_key]["output"]
            return input_cost + output_cost
        
        return 0.0
    
    def get_usage_stats(self) -> Dict[str, Any]:
        """Get current usage statistics."""
        return {
            "total_requests": self.request_count,
            "total_tokens_used": self.total_tokens_used,
            "total_cost_estimate": self.total_cost_estimate,
            "average_tokens_per_request": self.total_tokens_used / max(1, self.request_count),
            "average_cost_per_request": self.total_cost_estimate / max(1, self.request_count)
        }
    
    def reset_usage_stats(self):
        """Reset usage tracking."""
        self.total_tokens_used = 0
        self.total_cost_estimate = 0.0
        self.request_count = 0


# Convenience functions for easy integration
async def generate_text(
    prompt: str,
    max_tokens: int = 500,
    temperature: float = 0.3,
    system_message: Optional[str] = None
) -> str:
    """
    Simple text generation function.
    
    Args:
        prompt: The prompt to complete
        max_tokens: Maximum tokens to generate
        temperature: Sampling temperature
        system_message: Optional system message
        
    Returns:
        Generated text or empty string if failed
    """
    async with AzureLLMClient() as client:
        response = await client.complete(
            prompt=prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            system_message=system_message
        )
        return response.content if response.success else ""


async def generate_json_response(
    prompt: str,
    expected_fields: List[str],
    max_tokens: int = 500,
    temperature: float = 0.3
) -> Dict[str, Any]:
    """
    Generate a JSON response and parse it.
    
    Args:
        prompt: The prompt (should request JSON format)
        expected_fields: Expected JSON fields for validation
        max_tokens: Maximum tokens to generate
        temperature: Sampling temperature
        
    Returns:
        Parsed JSON dictionary or empty dict if failed
    """
    system_message = f"""You are a helpful assistant that responds in valid JSON format. 
Always include these fields in your response: {', '.join(expected_fields)}"""
    
    async with AzureLLMClient() as client:
        response = await client.complete(
            prompt=prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            system_message=system_message
        )
        
        if not response.success:
            return {}
        
        try:
            # Try to parse JSON from response
            json_data = json.loads(response.content)
            
            # Validate expected fields are present
            for field in expected_fields:
                if field not in json_data:
                    logger.warning(f"Expected field '{field}' not found in JSON response")
            
            return json_data
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse JSON response: {e}")
            logger.debug(f"Response content: {response.content}")
            return {}


def estimate_tokens(text: str) -> int:
    """
    Rough estimation of token count for text.
    
    Args:
        text: Input text
        
    Returns:
        Estimated token count (4 characters ≈ 1 token)
    """
    return len(text) // 4


def estimate_cost(input_text: str, output_text: str, model: str = "gpt-4") -> float:
    """
    Estimate cost for a text processing operation.
    
    Args:
        input_text: Input text
        output_text: Expected output text
        model: Model name for pricing
        
    Returns:
        Estimated cost in USD
    """
    client = AzureLLMClient()
    input_tokens = estimate_tokens(input_text)
    output_tokens = estimate_tokens(output_text)
    return client._calculate_cost(input_tokens, output_tokens)