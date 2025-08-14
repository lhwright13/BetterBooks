"""
Circuit Breaker Pattern Implementation

Provides resilience for external service calls by preventing cascading failures.
Implements the circuit breaker pattern with three states: CLOSED, OPEN, HALF_OPEN.

States:
- CLOSED: Normal operation, requests pass through
- OPEN: Service is failing, requests are blocked
- HALF_OPEN: Testing if service has recovered

Usage:
    from circuit_breaker import CircuitBreaker
    
    breaker = CircuitBreaker(
        failure_threshold=5,
        recovery_timeout=60,
        expected_exception=Exception
    )
    
    @breaker
    async def call_external_service():
        return await external_api.request()
"""

import asyncio
import functools
import logging
import time
from datetime import datetime, timedelta
from enum import Enum
from typing import Any, Callable, Optional, Type, Union
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


class CircuitState(Enum):
    """Circuit breaker states"""
    CLOSED = "closed"      # Normal operation
    OPEN = "open"          # Blocking requests
    HALF_OPEN = "half_open"  # Testing recovery


class CircuitBreakerError(Exception):
    """Raised when circuit breaker is open"""
    def __init__(self, message: str = "Circuit breaker is OPEN"):
        self.message = message
        super().__init__(self.message)


@dataclass
class CircuitBreakerStats:
    """Statistics for circuit breaker monitoring"""
    total_calls: int = 0
    successful_calls: int = 0
    failed_calls: int = 0
    rejected_calls: int = 0
    last_failure_time: Optional[datetime] = None
    last_success_time: Optional[datetime] = None
    state_changes: list = field(default_factory=list)
    
    def success_rate(self) -> float:
        """Calculate success rate"""
        if self.total_calls == 0:
            return 1.0
        return self.successful_calls / self.total_calls
    
    def reset(self):
        """Reset statistics"""
        self.total_calls = 0
        self.successful_calls = 0
        self.failed_calls = 0
        self.rejected_calls = 0


class CircuitBreaker:
    """
    Circuit Breaker implementation for fault tolerance
    
    Args:
        failure_threshold: Number of failures before opening circuit
        recovery_timeout: Seconds to wait before attempting recovery
        expected_exception: Exception types to catch (default: Exception)
        success_threshold: Successes needed in HALF_OPEN to close circuit
        name: Name for logging and monitoring
        fallback_function: Optional fallback when circuit is open
        on_state_change: Callback for state changes
    """
    
    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: float = 60,
        expected_exception: Type[Exception] = Exception,
        success_threshold: int = 2,
        name: Optional[str] = None,
        fallback_function: Optional[Callable] = None,
        on_state_change: Optional[Callable] = None
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        self.success_threshold = success_threshold
        self.name = name or "CircuitBreaker"
        self.fallback_function = fallback_function
        self.on_state_change = on_state_change
        
        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._success_count = 0
        self._last_failure_time: Optional[float] = None
        self._last_attempt_time: Optional[float] = None
        self._half_open_attempts = 0
        self._stats = CircuitBreakerStats()
        self._lock = asyncio.Lock()
    
    @property
    def state(self) -> CircuitState:
        """Get current circuit state"""
        return self._state
    
    @property
    def stats(self) -> CircuitBreakerStats:
        """Get circuit breaker statistics"""
        return self._stats
    
    def _should_attempt_reset(self) -> bool:
        """Check if enough time has passed to attempt reset"""
        if self._last_failure_time is None:
            return False
        return time.time() - self._last_failure_time >= self.recovery_timeout
    
    async def _set_state(self, new_state: CircuitState):
        """Set circuit state and trigger callbacks"""
        if new_state != self._state:
            old_state = self._state
            self._state = new_state
            self._stats.state_changes.append({
                'from': old_state.value,
                'to': new_state.value,
                'timestamp': datetime.now()
            })
            
            logger.info(f"{self.name}: State changed from {old_state.value} to {new_state.value}")
            
            if self.on_state_change:
                if asyncio.iscoroutinefunction(self.on_state_change):
                    await self.on_state_change(old_state, new_state)
                else:
                    self.on_state_change(old_state, new_state)
            
            # Reset counters on state change
            if new_state == CircuitState.CLOSED:
                self._failure_count = 0
                self._success_count = 0
                self._half_open_attempts = 0
            elif new_state == CircuitState.HALF_OPEN:
                self._half_open_attempts = 0
    
    async def _record_success(self):
        """Record successful call"""
        async with self._lock:
            self._stats.total_calls += 1
            self._stats.successful_calls += 1
            self._stats.last_success_time = datetime.now()
            
            if self._state == CircuitState.HALF_OPEN:
                self._success_count += 1
                self._half_open_attempts += 1
                
                if self._success_count >= self.success_threshold:
                    await self._set_state(CircuitState.CLOSED)
                    logger.info(f"{self.name}: Circuit closed after successful recovery")
            
            elif self._state == CircuitState.CLOSED:
                self._failure_count = 0  # Reset failure count on success
    
    async def _record_failure(self):
        """Record failed call"""
        async with self._lock:
            self._stats.total_calls += 1
            self._stats.failed_calls += 1
            self._stats.last_failure_time = datetime.now()
            self._last_failure_time = time.time()
            
            if self._state == CircuitState.CLOSED:
                self._failure_count += 1
                
                if self._failure_count >= self.failure_threshold:
                    await self._set_state(CircuitState.OPEN)
                    logger.warning(f"{self.name}: Circuit opened after {self._failure_count} failures")
            
            elif self._state == CircuitState.HALF_OPEN:
                self._half_open_attempts += 1
                await self._set_state(CircuitState.OPEN)
                logger.warning(f"{self.name}: Circuit reopened after failure in HALF_OPEN state")
    
    async def call(self, func: Callable, *args, **kwargs) -> Any:
        """
        Call function through circuit breaker
        
        Args:
            func: Function to call
            *args: Positional arguments for func
            **kwargs: Keyword arguments for func
            
        Returns:
            Result of func or fallback
            
        Raises:
            CircuitBreakerError: If circuit is open and no fallback
        """
        async with self._lock:
            # Check if circuit should transition from OPEN to HALF_OPEN
            if self._state == CircuitState.OPEN and self._should_attempt_reset():
                await self._set_state(CircuitState.HALF_OPEN)
                logger.info(f"{self.name}: Attempting recovery (HALF_OPEN)")
        
        # Circuit is OPEN - reject request
        if self._state == CircuitState.OPEN:
            self._stats.rejected_calls += 1
            
            if self.fallback_function:
                logger.debug(f"{self.name}: Circuit OPEN, using fallback")
                if asyncio.iscoroutinefunction(self.fallback_function):
                    return await self.fallback_function(*args, **kwargs)
                return self.fallback_function(*args, **kwargs)
            
            raise CircuitBreakerError(f"{self.name}: Circuit breaker is OPEN")
        
        # Circuit is HALF_OPEN - limit concurrent attempts based on success threshold
        if self._state == CircuitState.HALF_OPEN and self._half_open_attempts >= self.success_threshold:
            self._stats.rejected_calls += 1
            
            if self.fallback_function:
                logger.debug(f"{self.name}: Circuit HALF_OPEN, limiting requests")
                if asyncio.iscoroutinefunction(self.fallback_function):
                    return await self.fallback_function(*args, **kwargs)
                return self.fallback_function(*args, **kwargs)
            
            raise CircuitBreakerError(f"{self.name}: Circuit breaker is testing recovery")
        
        # Attempt the call
        try:
            if asyncio.iscoroutinefunction(func):
                result = await func(*args, **kwargs)
            else:
                result = func(*args, **kwargs)
            
            await self._record_success()
            return result
            
        except self.expected_exception as e:
            await self._record_failure()
            
            if self._state == CircuitState.OPEN and self.fallback_function:
                logger.debug(f"{self.name}: Using fallback after failure")
                if asyncio.iscoroutinefunction(self.fallback_function):
                    return await self.fallback_function(*args, **kwargs)
                return self.fallback_function(*args, **kwargs)
            
            raise e
    
    def __call__(self, func: Callable) -> Callable:
        """Decorator for wrapping functions with circuit breaker"""
        @functools.wraps(func)
        async def async_wrapper(*args, **kwargs):
            return await self.call(func, *args, **kwargs)
        
        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs):
            loop = asyncio.get_event_loop()
            return loop.run_until_complete(self.call(func, *args, **kwargs))
        
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper
    
    def reset(self):
        """Manually reset circuit breaker to CLOSED state"""
        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._success_count = 0
        self._half_open_attempts = 0
        self._last_failure_time = None
        logger.info(f"{self.name}: Circuit manually reset to CLOSED")
    
    def get_status(self) -> dict:
        """Get circuit breaker status for monitoring"""
        return {
            'name': self.name,
            'state': self._state.value,
            'failure_count': self._failure_count,
            'success_count': self._success_count,
            'stats': {
                'total_calls': self._stats.total_calls,
                'successful_calls': self._stats.successful_calls,
                'failed_calls': self._stats.failed_calls,
                'rejected_calls': self._stats.rejected_calls,
                'success_rate': self._stats.success_rate(),
                'last_failure': self._stats.last_failure_time.isoformat() if self._stats.last_failure_time else None,
                'last_success': self._stats.last_success_time.isoformat() if self._stats.last_success_time else None
            }
        }


class ExponentialBackoff:
    """
    Exponential backoff retry mechanism to use with circuit breaker
    
    Args:
        max_retries: Maximum number of retry attempts
        base_delay: Base delay in seconds
        max_delay: Maximum delay in seconds
        exponential_base: Base for exponential calculation
    """
    
    def __init__(
        self,
        max_retries: int = 3,
        base_delay: float = 1.0,
        max_delay: float = 60.0,
        exponential_base: float = 2.0
    ):
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.exponential_base = exponential_base
    
    async def retry(self, func: Callable, *args, **kwargs) -> Any:
        """
        Retry function with exponential backoff
        
        Args:
            func: Function to retry
            *args: Positional arguments
            **kwargs: Keyword arguments
            
        Returns:
            Result of successful function call
            
        Raises:
            Last exception if all retries fail
        """
        last_exception = None
        
        for attempt in range(self.max_retries):
            try:
                if asyncio.iscoroutinefunction(func):
                    return await func(*args, **kwargs)
                return func(*args, **kwargs)
                
            except Exception as e:
                last_exception = e
                
                if attempt < self.max_retries - 1:
                    delay = min(
                        self.base_delay * (self.exponential_base ** attempt),
                        self.max_delay
                    )
                    logger.debug(f"Retry attempt {attempt + 1}/{self.max_retries} after {delay}s delay")
                    await asyncio.sleep(delay)
                else:
                    logger.error(f"All {self.max_retries} retry attempts failed")
        
        raise last_exception
    
    def __call__(self, func: Callable) -> Callable:
        """Decorator for wrapping functions with retry logic"""
        @functools.wraps(func)
        async def async_wrapper(*args, **kwargs):
            return await self.retry(func, *args, **kwargs)
        
        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs):
            loop = asyncio.get_event_loop()
            return loop.run_until_complete(self.retry(func, *args, **kwargs))
        
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper


# Factory functions for common circuit breaker configurations

def create_http_circuit_breaker(
    name: str = "HTTP",
    failure_threshold: int = 5,
    recovery_timeout: float = 30
) -> CircuitBreaker:
    """Create circuit breaker for HTTP requests"""
    import aiohttp
    
    return CircuitBreaker(
        name=name,
        failure_threshold=failure_threshold,
        recovery_timeout=recovery_timeout,
        expected_exception=(
            aiohttp.ClientError,
            asyncio.TimeoutError,
            ConnectionError
        )
    )


def create_database_circuit_breaker(
    name: str = "Database",
    failure_threshold: int = 3,
    recovery_timeout: float = 10
) -> CircuitBreaker:
    """Create circuit breaker for database operations"""
    import asyncpg
    
    return CircuitBreaker(
        name=name,
        failure_threshold=failure_threshold,
        recovery_timeout=recovery_timeout,
        expected_exception=(
            asyncpg.PostgresError,
            asyncio.TimeoutError,
            ConnectionError
        )
    )


def create_llm_circuit_breaker(
    name: str = "LLM",
    failure_threshold: int = 3,
    recovery_timeout: float = 60
) -> CircuitBreaker:
    """Create circuit breaker for LLM API calls"""
    
    async def fallback_llm_response(*args, **kwargs):
        """Fallback response when LLM is unavailable"""
        return {
            'text': "I'm temporarily unavailable. Please try again in a moment.",
            'error': 'Circuit breaker activated',
            'fallback': True
        }
    
    return CircuitBreaker(
        name=name,
        failure_threshold=failure_threshold,
        recovery_timeout=recovery_timeout,
        fallback_function=fallback_llm_response,
        expected_exception=Exception
    )