"""
Test Circuit Breaker Implementation
"""

import asyncio
import pytest
from unittest.mock import AsyncMock, MagicMock
from datetime import datetime

from core.infrastructure.circuit_breaker import (
    CircuitBreaker,
    CircuitState,
    CircuitBreakerError,
    ExponentialBackoff,
    create_http_circuit_breaker,
    create_database_circuit_breaker,
    create_llm_circuit_breaker
)


@pytest.mark.asyncio
async def test_circuit_breaker_closed_state():
    """Test circuit breaker in closed state allows calls"""
    breaker = CircuitBreaker(failure_threshold=3)
    
    async def successful_call():
        return "success"
    
    result = await breaker.call(successful_call)
    assert result == "success"
    assert breaker.state == CircuitState.CLOSED
    assert breaker.stats.successful_calls == 1
    assert breaker.stats.failed_calls == 0


@pytest.mark.asyncio
async def test_circuit_breaker_opens_after_failures():
    """Test circuit breaker opens after threshold failures"""
    breaker = CircuitBreaker(failure_threshold=3)
    
    async def failing_call():
        raise Exception("Service error")
    
    # First 2 failures - circuit stays closed
    for i in range(2):
        with pytest.raises(Exception):
            await breaker.call(failing_call)
        assert breaker.state == CircuitState.CLOSED
    
    # Third failure - circuit opens
    with pytest.raises(Exception):
        await breaker.call(failing_call)
    assert breaker.state == CircuitState.OPEN
    assert breaker.stats.failed_calls == 3


@pytest.mark.asyncio
async def test_circuit_breaker_rejects_when_open():
    """Test circuit breaker rejects calls when open"""
    breaker = CircuitBreaker(failure_threshold=1)
    
    async def failing_call():
        raise Exception("Service error")
    
    # Open the circuit
    with pytest.raises(Exception):
        await breaker.call(failing_call)
    assert breaker.state == CircuitState.OPEN
    
    # Subsequent calls should be rejected
    with pytest.raises(CircuitBreakerError):
        await breaker.call(failing_call)
    assert breaker.stats.rejected_calls == 1


@pytest.mark.asyncio
async def test_circuit_breaker_half_open_recovery():
    """Test circuit breaker recovery through half-open state"""
    breaker = CircuitBreaker(
        failure_threshold=1,
        recovery_timeout=0.1,  # 100ms for testing
        success_threshold=2
    )
    
    call_count = 0
    
    async def variable_call():
        nonlocal call_count
        call_count += 1
        if call_count <= 1:
            raise Exception("Service error")
        return "success"
    
    # Open the circuit
    with pytest.raises(Exception):
        await breaker.call(variable_call)
    assert breaker.state == CircuitState.OPEN
    
    # Wait for recovery timeout
    await asyncio.sleep(0.15)
    
    # First successful call in half-open
    result = await breaker.call(variable_call)
    assert result == "success"
    assert breaker.state == CircuitState.HALF_OPEN
    
    # Second successful call closes circuit
    result = await breaker.call(variable_call)
    assert result == "success"
    assert breaker.state == CircuitState.CLOSED


@pytest.mark.asyncio
async def test_circuit_breaker_fallback():
    """Test circuit breaker with fallback function"""
    async def fallback(*args, **kwargs):
        return "fallback_response"
    
    breaker = CircuitBreaker(
        failure_threshold=1,
        fallback_function=fallback
    )
    
    async def failing_call():
        raise Exception("Service error")
    
    # Open the circuit
    with pytest.raises(Exception):
        await breaker.call(failing_call)
    assert breaker.state == CircuitState.OPEN
    
    # Should use fallback when open
    result = await breaker.call(failing_call)
    assert result == "fallback_response"


@pytest.mark.asyncio
async def test_circuit_breaker_decorator():
    """Test circuit breaker as decorator"""
    breaker = CircuitBreaker(failure_threshold=2)
    
    call_count = 0
    
    @breaker
    async def decorated_function(value):
        nonlocal call_count
        call_count += 1
        if call_count <= 2:
            raise Exception("Error")
        return f"result_{value}"
    
    # First two calls fail
    with pytest.raises(Exception):
        await decorated_function("test1")
    with pytest.raises(Exception):
        await decorated_function("test2")
    
    # Circuit is now open
    assert breaker.state == CircuitState.OPEN
    
    # Next call is rejected
    with pytest.raises(CircuitBreakerError):
        await decorated_function("test3")


@pytest.mark.asyncio
async def test_circuit_breaker_state_change_callback():
    """Test state change callbacks"""
    state_changes = []
    
    def on_state_change(old_state, new_state):
        state_changes.append((old_state, new_state))
    
    breaker = CircuitBreaker(
        failure_threshold=1,
        on_state_change=on_state_change
    )
    
    async def failing_call():
        raise Exception("Error")
    
    # Trigger state change
    with pytest.raises(Exception):
        await breaker.call(failing_call)
    
    assert len(state_changes) == 1
    assert state_changes[0] == (CircuitState.CLOSED, CircuitState.OPEN)


@pytest.mark.asyncio
async def test_circuit_breaker_statistics():
    """Test circuit breaker statistics tracking"""
    breaker = CircuitBreaker(failure_threshold=5)
    
    async def variable_call(should_fail=False):
        if should_fail:
            raise Exception("Error")
        return "success"
    
    # Some successful calls
    for _ in range(3):
        await breaker.call(variable_call, should_fail=False)
    
    # Some failed calls
    for _ in range(2):
        with pytest.raises(Exception):
            await breaker.call(variable_call, should_fail=True)
    
    stats = breaker.stats
    assert stats.total_calls == 5
    assert stats.successful_calls == 3
    assert stats.failed_calls == 2
    assert stats.success_rate() == 0.6


@pytest.mark.asyncio
async def test_circuit_breaker_manual_reset():
    """Test manual reset of circuit breaker"""
    breaker = CircuitBreaker(failure_threshold=1)
    
    async def failing_call():
        raise Exception("Error")
    
    # Open the circuit
    with pytest.raises(Exception):
        await breaker.call(failing_call)
    assert breaker.state == CircuitState.OPEN
    
    # Manual reset
    breaker.reset()
    assert breaker.state == CircuitState.CLOSED
    assert breaker._failure_count == 0


@pytest.mark.asyncio
async def test_exponential_backoff():
    """Test exponential backoff retry mechanism"""
    backoff = ExponentialBackoff(
        max_retries=3,
        base_delay=0.01,  # 10ms for testing
        max_delay=0.1
    )
    
    call_count = 0
    
    async def variable_call():
        nonlocal call_count
        call_count += 1
        if call_count < 3:
            raise Exception("Temporary error")
        return "success"
    
    result = await backoff.retry(variable_call)
    assert result == "success"
    assert call_count == 3


@pytest.mark.asyncio
async def test_exponential_backoff_decorator():
    """Test exponential backoff as decorator"""
    backoff = ExponentialBackoff(max_retries=3, base_delay=0.01)
    
    call_count = 0
    
    @backoff
    async def decorated_function():
        nonlocal call_count
        call_count += 1
        if call_count < 2:
            raise Exception("Error")
        return "success"
    
    result = await decorated_function()
    assert result == "success"
    assert call_count == 2


@pytest.mark.asyncio
async def test_exponential_backoff_max_retries():
    """Test exponential backoff respects max retries"""
    backoff = ExponentialBackoff(max_retries=2, base_delay=0.01)
    
    async def always_failing():
        raise Exception("Permanent error")
    
    with pytest.raises(Exception) as exc_info:
        await backoff.retry(always_failing)
    
    assert str(exc_info.value) == "Permanent error"


def test_http_circuit_breaker_factory():
    """Test HTTP circuit breaker factory"""
    breaker = create_http_circuit_breaker(name="TestHTTP")
    assert breaker.name == "TestHTTP"
    assert breaker.failure_threshold == 5
    assert breaker.recovery_timeout == 30


def test_database_circuit_breaker_factory():
    """Test database circuit breaker factory"""
    breaker = create_database_circuit_breaker(name="TestDB")
    assert breaker.name == "TestDB"
    assert breaker.failure_threshold == 3
    assert breaker.recovery_timeout == 10


def test_llm_circuit_breaker_factory():
    """Test LLM circuit breaker factory"""
    breaker = create_llm_circuit_breaker(name="TestLLM")
    assert breaker.name == "TestLLM"
    assert breaker.failure_threshold == 3
    assert breaker.recovery_timeout == 60
    assert breaker.fallback_function is not None


@pytest.mark.asyncio
async def test_circuit_breaker_get_status():
    """Test getting circuit breaker status"""
    breaker = CircuitBreaker(name="TestBreaker", failure_threshold=3)
    
    async def test_call():
        return "success"
    
    await breaker.call(test_call)
    
    status = breaker.get_status()
    assert status['name'] == "TestBreaker"
    assert status['state'] == 'closed'
    assert status['stats']['total_calls'] == 1
    assert status['stats']['successful_calls'] == 1
    assert status['stats']['success_rate'] == 1.0