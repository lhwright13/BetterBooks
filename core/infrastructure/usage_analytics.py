"""
Usage Analytics System for EchoWright Platform

Comprehensive analytics tracking for AI-powered educational audiobook interactions.
Monitors user engagement, persona effectiveness, learning progress, and content
consumption patterns to provide insights for teachers and platform optimization.

Features:
- Real-time event tracking with batch processing
- Educational progress monitoring (comprehension, engagement)
- AI persona effectiveness measurement
- Content consumption analytics (listening patterns, replay frequency)
- Teacher insights dashboard data
- Privacy-compliant data collection
- Performance optimized with Redis buffering
- Prometheus metrics integration
"""

import asyncio
import json
import time
import logging
import hashlib
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional, Union, Callable
from enum import Enum
from dataclasses import dataclass, asdict, field
from uuid import uuid4
from contextlib import asynccontextmanager

import redis
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from pydantic import BaseModel, Field
import psycopg2
import psycopg2.extras

from core.infrastructure.metrics import Counter, Gauge, Histogram, Summary
from core.auth.auth import User

logger = logging.getLogger(__name__)


class EventType(Enum):
    """Types of analytics events tracked in the system."""
    
    # User engagement events
    USER_LOGIN = "user_login"
    USER_LOGOUT = "user_logout"
    SESSION_START = "session_start"
    SESSION_END = "session_end"
    
    # Content interaction events
    BOOK_START = "book_start"
    BOOK_PAUSE = "book_pause"
    BOOK_RESUME = "book_resume"
    BOOK_COMPLETE = "book_complete"
    CHAPTER_START = "chapter_start"
    CHAPTER_COMPLETE = "chapter_complete"
    CHAPTER_SKIP = "chapter_skip"
    CHAPTER_REPLAY = "chapter_replay"
    
    # AI interaction events
    AI_CONVERSATION_START = "ai_conversation_start"
    AI_CONVERSATION_END = "ai_conversation_end"
    AI_QUESTION_ASKED = "ai_question_asked"
    AI_RESPONSE_RECEIVED = "ai_response_received"
    PERSONA_SWITCHED = "persona_switched"
    VOICE_CHAT_START = "voice_chat_start"
    VOICE_CHAT_END = "voice_chat_end"
    
    # Educational progress events
    COMPREHENSION_CHECK = "comprehension_check"
    QUIZ_COMPLETED = "quiz_completed"
    NOTE_CREATED = "note_created"
    BOOKMARK_CREATED = "bookmark_created"
    SUMMARY_GENERATED = "summary_generated"
    
    # Social and sharing events
    REVIEW_POSTED = "review_posted"
    PERSONA_SHARED = "persona_shared"
    BOOK_RECOMMENDED = "book_recommended"
    
    # System events
    ERROR_OCCURRED = "error_occurred"
    PERFORMANCE_METRIC = "performance_metric"


class UserType(Enum):
    """Types of users for analytics segmentation."""
    GUEST = "guest"
    FREE_USER = "free_user"
    PREMIUM_USER = "premium_user"
    STUDENT = "student"
    TEACHER = "teacher"
    ADMIN = "admin"


class ContentType(Enum):
    """Types of content for analytics tracking."""
    AUDIOBOOK = "audiobook"
    CHAPTER = "chapter"
    PERSONA = "persona"
    QUIZ = "quiz"
    NOTE = "note"
    SUMMARY = "summary"


@dataclass
class AnalyticsEvent:
    """Individual analytics event with metadata."""
    
    # Core event information
    event_id: str = field(default_factory=lambda: str(uuid4()))
    event_type: EventType
    timestamp: datetime = field(default_factory=datetime.utcnow)
    
    # User context
    user_id: Optional[str] = None
    user_type: Optional[UserType] = None
    session_id: Optional[str] = None
    
    # Content context
    book_id: Optional[str] = None
    chapter_id: Optional[str] = None
    persona_id: Optional[str] = None
    content_type: Optional[ContentType] = None
    
    # Event-specific data
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    # Technical context
    user_agent: Optional[str] = None
    ip_address: Optional[str] = None
    platform: Optional[str] = None  # mobile, web, etc.
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert event to dictionary for storage/transmission."""
        return {
            "event_id": self.event_id,
            "event_type": self.event_type.value,
            "timestamp": self.timestamp.isoformat(),
            "user_id": self.user_id,
            "user_type": self.user_type.value if self.user_type else None,
            "session_id": self.session_id,
            "book_id": self.book_id,
            "chapter_id": self.chapter_id,
            "persona_id": self.persona_id,
            "content_type": self.content_type.value if self.content_type else None,
            "metadata": self.metadata,
            "user_agent": self.user_agent,
            "ip_address": self._hash_ip() if self.ip_address else None,
            "platform": self.platform
        }
    
    def _hash_ip(self) -> str:
        """Hash IP address for privacy compliance."""
        if not self.ip_address:
            return None
        return hashlib.sha256(self.ip_address.encode()).hexdigest()[:16]


@dataclass
class AnalyticsConfig:
    """Configuration for analytics collection."""
    enabled: bool = True
    batch_size: int = 100
    flush_interval: int = 60  # seconds
    buffer_size: int = 10000
    retention_days: int = 365
    privacy_mode: bool = True  # Hash sensitive data
    exclude_paths: List[str] = field(default_factory=lambda: ["/health", "/metrics"])
    exclude_user_agents: List[str] = field(default_factory=lambda: ["bot", "crawler", "monitor"])


class AnalyticsCollector:
    """
    High-performance analytics collector with batch processing and privacy compliance.
    
    Collects, processes, and stores user interaction events for the EchoWright
    platform with focus on educational effectiveness and AI persona optimization.
    """
    
    def __init__(
        self,
        redis_client: redis.Redis,
        postgres_connection_string: str,
        config: Optional[AnalyticsConfig] = None
    ):
        """
        Initialize analytics collector.
        
        Args:
            redis_client: Redis client for buffering and real-time aggregation
            postgres_connection_string: PostgreSQL connection for persistent storage
            config: Analytics configuration
        """
        self.redis = redis_client
        self.postgres_conn_str = postgres_connection_string
        self.config = config or AnalyticsConfig()
        
        # Event buffer for batch processing
        self.event_buffer: List[AnalyticsEvent] = []
        self.buffer_lock = asyncio.Lock()
        
        # Redis keys
        self.EVENTS_QUEUE_KEY = "analytics:events:queue"
        self.REAL_TIME_STATS_KEY = "analytics:realtime"
        self.USER_SESSIONS_KEY = "analytics:sessions"
        
        # Metrics for monitoring
        self._setup_metrics()
        
        # Background processing
        self._flush_task = None
        self._start_background_processing()
        
        logger.info("Analytics collector initialized", 
                   config=asdict(self.config))
    
    def _setup_metrics(self):
        """Set up Prometheus metrics for analytics monitoring."""
        self.events_collected = Counter(
            'analytics_events_collected_total',
            'Total analytics events collected',
            ['event_type', 'user_type', 'platform']
        )
        
        self.events_processed = Counter(
            'analytics_events_processed_total',
            'Total analytics events processed to database',
            ['status']  # success, error
        )
        
        self.buffer_size_gauge = Gauge(
            'analytics_buffer_size',
            'Current size of analytics event buffer'
        )
        
        self.processing_duration = Histogram(
            'analytics_processing_duration_seconds',
            'Time spent processing analytics events',
            buckets=(0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0)
        )
        
        # Educational analytics metrics
        self.user_engagement_score = Gauge(
            'user_engagement_score',
            'User engagement score (0-100)',
            ['user_type', 'time_period']
        )
        
        self.persona_effectiveness = Gauge(
            'persona_effectiveness_score',
            'AI persona effectiveness score (0-100)',
            ['persona_id', 'content_type']
        )
        
        self.learning_progress = Counter(
            'learning_progress_total',
            'Learning progress events',
            ['progress_type', 'user_type']  # chapter_complete, quiz_passed, etc.
        )
    
    def _start_background_processing(self):
        """Start background task for periodic event processing."""
        if self.config.enabled:
            self._flush_task = asyncio.create_task(self._periodic_flush())
    
    async def _periodic_flush(self):
        """Periodically flush event buffer to database."""
        while True:
            try:
                await asyncio.sleep(self.config.flush_interval)
                await self.flush_events()
            except Exception as e:
                logger.error(f"Error in periodic flush: {e}")
    
    async def collect_event(
        self,
        event_type: EventType,
        user: Optional[User] = None,
        request: Optional[Request] = None,
        **kwargs
    ) -> str:
        """
        Collect an analytics event.
        
        Args:
            event_type: Type of event being tracked
            user: User associated with the event (if any)
            request: HTTP request context (if any)
            **kwargs: Additional event metadata
            
        Returns:
            Event ID for tracking/correlation
        """
        if not self.config.enabled:
            return None
        
        # Create event
        event = AnalyticsEvent(
            event_type=event_type,
            user_id=user.id if user else None,
            user_type=self._determine_user_type(user),
            session_id=self._get_session_id(request, user),
            metadata=kwargs,
            user_agent=request.headers.get("User-Agent") if request else None,
            ip_address=request.client.host if request and hasattr(request, 'client') else None,
            platform=self._detect_platform(request)
        )
        
        # Add to buffer
        await self._add_to_buffer(event)
        
        # Update metrics
        self.events_collected.labels(
            event_type=event_type.value,
            user_type=event.user_type.value if event.user_type else "unknown",
            platform=event.platform or "unknown"
        ).inc()
        
        # Real-time aggregation in Redis
        await self._update_real_time_stats(event)
        
        return event.event_id
    
    def _determine_user_type(self, user: Optional[User]) -> Optional[UserType]:
        """Determine user type for analytics segmentation."""
        if not user:
            return UserType.GUEST
        
        # Map from auth UserRole to analytics UserType
        from core.auth.auth import UserRole
        role_mapping = {
            UserRole.ADMIN: UserType.ADMIN,
            UserRole.USER: UserType.FREE_USER,  # Default, can be upgraded
            UserRole.GUEST: UserType.GUEST,
        }
        
        base_type = role_mapping.get(user.role, UserType.FREE_USER)
        
        # TODO: Check subscription status to determine premium/student/teacher
        # For now, return base type
        return base_type
    
    def _get_session_id(self, request: Optional[Request], user: Optional[User]) -> Optional[str]:
        """Get or generate session ID for tracking user sessions."""
        if request and hasattr(request.state, 'session_id'):
            return request.state.session_id
        
        if user:
            # Generate deterministic session ID based on user and time window
            hour_window = int(time.time() // 3600)  # 1-hour sessions
            session_data = f"{user.id}:{hour_window}"
            return hashlib.md5(session_data.encode()).hexdigest()[:16]
        
        return None
    
    def _detect_platform(self, request: Optional[Request]) -> Optional[str]:
        """Detect platform from request headers."""
        if not request:
            return None
        
        user_agent = request.headers.get("User-Agent", "").lower()
        
        if "mobile" in user_agent or "android" in user_agent or "iphone" in user_agent:
            return "mobile"
        elif "web" in user_agent or "mozilla" in user_agent:
            return "web"
        elif "api" in user_agent or "python" in user_agent:
            return "api"
        
        return "unknown"
    
    async def _add_to_buffer(self, event: AnalyticsEvent):
        """Add event to processing buffer."""
        async with self.buffer_lock:
            self.event_buffer.append(event)
            self.buffer_size_gauge.set(len(self.event_buffer))
            
            # Auto-flush if buffer is full
            if len(self.event_buffer) >= self.config.batch_size:
                await self._flush_buffer()
    
    async def _update_real_time_stats(self, event: AnalyticsEvent):
        """Update real-time statistics in Redis."""
        try:
            # Update event counters
            pipe = self.redis.pipeline()
            
            # Overall event counts
            pipe.hincrby(f"{self.REAL_TIME_STATS_KEY}:events", event.event_type.value, 1)
            
            # User type breakdown
            if event.user_type:
                pipe.hincrby(f"{self.REAL_TIME_STATS_KEY}:users", event.user_type.value, 1)
            
            # Platform breakdown
            if event.platform:
                pipe.hincrby(f"{self.REAL_TIME_STATS_KEY}:platforms", event.platform, 1)
            
            # Hourly windows for trending
            hour_key = datetime.utcnow().strftime("%Y-%m-%d:%H")
            pipe.hincrby(f"{self.REAL_TIME_STATS_KEY}:hourly:{hour_key}", event.event_type.value, 1)
            
            # Set expiration on hourly keys (keep for 7 days)
            pipe.expire(f"{self.REAL_TIME_STATS_KEY}:hourly:{hour_key}", 7 * 24 * 3600)
            
            await pipe.execute()
            
        except Exception as e:
            logger.warning(f"Failed to update real-time stats: {e}")
    
    async def _flush_buffer(self):
        """Flush event buffer to database."""
        if not self.event_buffer:
            return
        
        start_time = time.time()
        
        try:
            events_to_process = self.event_buffer.copy()
            self.event_buffer.clear()
            self.buffer_size_gauge.set(0)
            
            await self._store_events_to_database(events_to_process)
            
            self.events_processed.labels(status="success").inc(len(events_to_process))
            
        except Exception as e:
            logger.error(f"Error flushing event buffer: {e}")
            self.events_processed.labels(status="error").inc(len(events_to_process))
            
            # Re-add events to buffer for retry (up to buffer limit)
            async with self.buffer_lock:
                retry_events = events_to_process[:self.config.buffer_size - len(self.event_buffer)]
                self.event_buffer.extend(retry_events)
                self.buffer_size_gauge.set(len(self.event_buffer))
        
        finally:
            duration = time.time() - start_time
            self.processing_duration.observe(duration)
    
    async def _store_events_to_database(self, events: List[AnalyticsEvent]):
        """Store events to PostgreSQL database."""
        if not events:
            return
        
        # Convert events to database format
        event_records = [event.to_dict() for event in events]
        
        # Batch insert to database
        try:
            import asyncpg
            conn = await asyncpg.connect(self.postgres_conn_str)
            
            try:
                # Prepare batch insert
                insert_query = """
                    INSERT INTO analytics_events (
                        event_id, event_type, timestamp, user_id, user_type,
                        session_id, book_id, chapter_id, persona_id, content_type,
                        metadata, user_agent, ip_address, platform
                    ) VALUES (
                        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
                    )
                """
                
                # Prepare data for batch insert
                batch_data = []
                for record in event_records:
                    batch_data.append((
                        record["event_id"],
                        record["event_type"],
                        record["timestamp"],
                        record["user_id"],
                        record["user_type"],
                        record["session_id"],
                        record["book_id"],
                        record["chapter_id"],
                        record["persona_id"],
                        record["content_type"],
                        json.dumps(record["metadata"]),
                        record["user_agent"],
                        record["ip_address"],
                        record["platform"]
                    ))
                
                # Execute batch insert
                await conn.executemany(insert_query, batch_data)
                
                logger.debug(f"Stored {len(events)} analytics events to database")
                
            finally:
                await conn.close()
                
        except Exception as e:
            logger.error(f"Database storage failed: {e}")
            raise
    
    async def flush_events(self):
        """Manually flush all pending events."""
        async with self.buffer_lock:
            await self._flush_buffer()
    
    # Analytics query methods
    
    async def get_user_engagement_metrics(
        self,
        user_id: str,
        time_range: timedelta = timedelta(days=7)
    ) -> Dict[str, Any]:
        """Get engagement metrics for a specific user."""
        end_time = datetime.utcnow()
        start_time = end_time - time_range
        
        try:
            import asyncpg
            conn = await asyncpg.connect(self.postgres_conn_str)
            
            try:
                # Query user engagement data
                query = """
                    SELECT 
                        event_type,
                        COUNT(*) as event_count,
                        AVG(EXTRACT(EPOCH FROM (timestamp - LAG(timestamp) OVER (ORDER BY timestamp)))) as avg_time_between_events
                    FROM analytics_events 
                    WHERE user_id = $1 
                        AND timestamp >= $2 
                        AND timestamp <= $3
                    GROUP BY event_type
                    ORDER BY event_count DESC
                """
                
                rows = await conn.fetch(query, user_id, start_time, end_time)
                
                engagement_data = {
                    "user_id": user_id,
                    "time_range_days": time_range.days,
                    "event_summary": [dict(row) for row in rows],
                    "total_events": sum(row["event_count"] for row in rows)
                }
                
                return engagement_data
                
            finally:
                await conn.close()
                
        except Exception as e:
            logger.error(f"Error getting user engagement metrics: {e}")
            return {"error": str(e)}
    
    async def get_persona_effectiveness(
        self,
        persona_id: str,
        time_range: timedelta = timedelta(days=30)
    ) -> Dict[str, Any]:
        """Get effectiveness metrics for an AI persona."""
        end_time = datetime.utcnow()
        start_time = end_time - time_range
        
        try:
            import asyncpg
            conn = await asyncpg.connect(self.postgres_conn_str)
            
            try:
                # Query persona interaction data
                query = """
                    SELECT 
                        COUNT(DISTINCT user_id) as unique_users,
                        COUNT(*) as total_interactions,
                        AVG(CASE 
                            WHEN event_type = 'ai_conversation_end' 
                            THEN CAST(metadata->>'duration_seconds' AS FLOAT)
                            ELSE NULL 
                        END) as avg_conversation_duration,
                        COUNT(CASE WHEN event_type = 'comprehension_check' THEN 1 END) as comprehension_checks,
                        COUNT(CASE WHEN event_type = 'quiz_completed' THEN 1 END) as quizzes_completed
                    FROM analytics_events 
                    WHERE persona_id = $1 
                        AND timestamp >= $2 
                        AND timestamp <= $3
                """
                
                row = await conn.fetchrow(query, persona_id, start_time, end_time)
                
                effectiveness_data = {
                    "persona_id": persona_id,
                    "time_range_days": time_range.days,
                    "unique_users": row["unique_users"] or 0,
                    "total_interactions": row["total_interactions"] or 0,
                    "avg_conversation_duration": row["avg_conversation_duration"] or 0,
                    "educational_engagement": {
                        "comprehension_checks": row["comprehension_checks"] or 0,
                        "quizzes_completed": row["quizzes_completed"] or 0
                    }
                }
                
                # Calculate effectiveness score (0-100)
                effectiveness_score = self._calculate_persona_score(effectiveness_data)
                effectiveness_data["effectiveness_score"] = effectiveness_score
                
                return effectiveness_data
                
            finally:
                await conn.close()
                
        except Exception as e:
            logger.error(f"Error getting persona effectiveness: {e}")
            return {"error": str(e)}
    
    def _calculate_persona_score(self, data: Dict[str, Any]) -> float:
        """Calculate persona effectiveness score (0-100)."""
        # Simple scoring algorithm - can be made more sophisticated
        score = 0.0
        
        # User engagement (40% of score)
        if data["unique_users"] > 0:
            score += min(data["unique_users"] * 2, 40)  # Max 40 points
        
        # Interaction frequency (30% of score) 
        if data["total_interactions"] > 0:
            score += min(data["total_interactions"] * 0.5, 30)  # Max 30 points
        
        # Educational engagement (30% of score)
        educational_total = data["educational_engagement"]["comprehension_checks"] + data["educational_engagement"]["quizzes_completed"]
        score += min(educational_total * 1.5, 30)  # Max 30 points
        
        return min(score, 100.0)
    
    async def get_real_time_stats(self) -> Dict[str, Any]:
        """Get real-time analytics statistics from Redis."""
        try:
            # Get current hour stats
            current_hour = datetime.utcnow().strftime("%Y-%m-%d:%H")
            
            pipe = self.redis.pipeline()
            pipe.hgetall(f"{self.REAL_TIME_STATS_KEY}:events")
            pipe.hgetall(f"{self.REAL_TIME_STATS_KEY}:users")
            pipe.hgetall(f"{self.REAL_TIME_STATS_KEY}:platforms")
            pipe.hgetall(f"{self.REAL_TIME_STATS_KEY}:hourly:{current_hour}")
            
            results = await pipe.execute()
            
            return {
                "events": results[0] or {},
                "users": results[1] or {},
                "platforms": results[2] or {},
                "current_hour": results[3] or {},
                "timestamp": datetime.utcnow().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Error getting real-time stats: {e}")
            return {"error": str(e)}
    
    async def cleanup(self):
        """Cleanup resources and flush remaining events."""
        if self._flush_task:
            self._flush_task.cancel()
            
        await self.flush_events()
        logger.info("Analytics collector cleanup complete")


class AnalyticsMiddleware(BaseHTTPMiddleware):
    """
    FastAPI middleware for automatic analytics event collection.
    
    Tracks API requests, response times, and user interactions automatically.
    """
    
    def __init__(
        self,
        app,
        analytics_collector: AnalyticsCollector,
        track_all_requests: bool = False
    ):
        """
        Initialize analytics middleware.
        
        Args:
            app: ASGI application
            analytics_collector: Configured AnalyticsCollector
            track_all_requests: Whether to track all HTTP requests (can be noisy)
        """
        super().__init__(app)
        self.collector = analytics_collector
        self.track_all_requests = track_all_requests
    
    async def dispatch(self, request: Request, call_next) -> Response:
        """Process request with analytics tracking."""
        start_time = time.time()
        
        # Extract user from request state (set by auth middleware)
        user = getattr(request.state, 'user', None)
        
        # Track request start (if configured)
        if self.track_all_requests:
            await self.collector.collect_event(
                EventType.PERFORMANCE_METRIC,
                user=user,
                request=request,
                metric_type="request_start",
                endpoint=request.url.path,
                method=request.method
            )
        
        try:
            # Process request
            response = await call_next(request)
            
            # Track successful requests
            duration = time.time() - start_time
            
            if self.track_all_requests or self._is_tracked_endpoint(request.url.path):
                await self.collector.collect_event(
                    EventType.PERFORMANCE_METRIC,
                    user=user,
                    request=request,
                    metric_type="request_complete",
                    endpoint=request.url.path,
                    method=request.method,
                    status_code=response.status_code,
                    duration_seconds=duration
                )
            
            return response
            
        except Exception as e:
            # Track errors
            duration = time.time() - start_time
            
            await self.collector.collect_event(
                EventType.ERROR_OCCURRED,
                user=user,
                request=request,
                error_type=type(e).__name__,
                error_message=str(e),
                endpoint=request.url.path,
                method=request.method,
                duration_seconds=duration
            )
            
            raise
    
    def _is_tracked_endpoint(self, path: str) -> bool:
        """Check if endpoint should be tracked for analytics."""
        tracked_patterns = ["/complete", "/tts", "/books/", "/personas/", "/auth/"]
        return any(pattern in path for pattern in tracked_patterns)


# Factory functions and utilities

def create_analytics_collector(
    redis_client: redis.Redis,
    postgres_connection_string: str,
    config: Optional[AnalyticsConfig] = None
) -> AnalyticsCollector:
    """
    Create analytics collector with EchoWright defaults.
    
    Args:
        redis_client: Configured Redis client
        postgres_connection_string: PostgreSQL connection string
        config: Custom analytics configuration
        
    Returns:
        Configured AnalyticsCollector instance
    """
    return AnalyticsCollector(redis_client, postgres_connection_string, config)


def setup_usage_analytics(
    app,
    redis_client: redis.Redis,
    postgres_connection_string: str,
    config: Optional[AnalyticsConfig] = None,
    track_all_requests: bool = False
) -> AnalyticsCollector:
    """
    Set up usage analytics for a FastAPI application.
    
    Args:
        app: FastAPI application instance
        redis_client: Configured Redis client
        postgres_connection_string: PostgreSQL connection string
        config: Analytics configuration
        track_all_requests: Whether to track all HTTP requests
        
    Returns:
        Configured AnalyticsCollector instance
    """
    # Create analytics collector
    collector = create_analytics_collector(redis_client, postgres_connection_string, config)
    
    # Add middleware
    app.add_middleware(AnalyticsMiddleware, 
                      analytics_collector=collector,
                      track_all_requests=track_all_requests)
    
    # Add analytics endpoints
    @app.get("/analytics/status")
    async def get_analytics_status():
        """Get analytics system status."""
        return {
            "enabled": collector.config.enabled,
            "buffer_size": len(collector.event_buffer),
            "buffer_limit": collector.config.batch_size,
            "redis_available": collector.redis.ping() if collector.redis else False
        }
    
    @app.get("/analytics/realtime")
    async def get_realtime_analytics():
        """Get real-time analytics data."""
        return await collector.get_real_time_stats()
    
    @app.get("/analytics/user/{user_id}/engagement")
    async def get_user_engagement(user_id: str, days: int = 7):
        """Get user engagement metrics."""
        return await collector.get_user_engagement_metrics(
            user_id, 
            timedelta(days=days)
        )
    
    @app.get("/analytics/persona/{persona_id}/effectiveness")
    async def get_persona_effectiveness(persona_id: str, days: int = 30):
        """Get persona effectiveness metrics."""
        return await collector.get_persona_effectiveness(
            persona_id,
            timedelta(days=days)
        )
    
    @app.post("/analytics/flush")
    async def flush_analytics():
        """Manually flush analytics buffer."""
        await collector.flush_events()
        return {"message": "Analytics buffer flushed"}
    
    logger.info("Usage analytics setup complete")
    return collector


# Database schema creation SQL
ANALYTICS_SCHEMA_SQL = """
-- Analytics events table
CREATE TABLE IF NOT EXISTS analytics_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(36) UNIQUE NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    user_id VARCHAR(36),
    user_type VARCHAR(20),
    session_id VARCHAR(32),
    book_id VARCHAR(100),
    chapter_id VARCHAR(100),
    persona_id VARCHAR(100),
    content_type VARCHAR(20),
    metadata JSONB,
    user_agent TEXT,
    ip_address VARCHAR(32),  -- Hashed for privacy
    platform VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_type ON analytics_events(event_type);
CREATE INDEX IF NOT EXISTS idx_analytics_events_timestamp ON analytics_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_analytics_events_persona_id ON analytics_events(persona_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_book_id ON analytics_events(book_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_session_id ON analytics_events(session_id);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_time ON analytics_events(user_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_analytics_events_persona_time ON analytics_events(persona_id, timestamp);

-- Partition by month for large datasets (optional)
-- CREATE TABLE analytics_events_y2024m01 PARTITION OF analytics_events
-- FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
"""