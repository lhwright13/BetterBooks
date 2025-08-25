# Usage Analytics System

## Overview

The usage analytics system provides comprehensive tracking and insights for the EchoWright educational audiobook platform. It monitors user engagement, AI persona effectiveness, content consumption patterns, and learning progress.

## Architecture

```mermaid
graph TD
    A[User Actions] --> B[AnalyticsMiddleware]
    B --> C[Event Collection]
    C --> D[Redis Buffer]
    D --> E[Batch Processor]
    E --> F[PostgreSQL Storage]
    
    F --> G[Aggregation Triggers]
    G --> H[Summary Tables]
    H --> I[Analytics API]
    I --> J[Teacher Dashboard]
    I --> K[Admin Reports]
    
    L[Real-time Cache] --> M[Live Metrics]
    E --> L
```

## Key Features

### Event Tracking
- **User Engagement**: Session duration, interactions, progress
- **AI Conversations**: Persona effectiveness, response quality
- **Content Consumption**: Listening patterns, replay frequency
- **Educational Progress**: Comprehension checks, quiz completion
- **Teacher Insights**: Student performance, content effectiveness

### Privacy-Compliant Design
- User data hashing for anonymization
- COPPA/FERPA compliance for educational use
- Configurable data retention policies
- Opt-out mechanisms for privacy-sensitive users

### Real-Time Analytics
- Live dashboard metrics
- Streaming event processing
- WebSocket-based updates
- Cache-backed performance optimization

## Usage

### Basic Setup
```python
from core.infrastructure import setup_usage_analytics

# Initialize analytics system
analytics_collector = setup_usage_analytics(
    app, redis_client, database_url, config=analytics_config
)
```

### Event Collection
```python
from core.infrastructure import EventType, UserType, ContentType

# Track user interaction
await analytics_collector.collect_event(
    event_type=EventType.AI_CONVERSATION_START,
    user_id="user123",
    user_type=UserType.STUDENT,
    persona_id="shakespeare_tutor",
    metadata={
        "conversation_topic": "Romeo and Juliet",
        "difficulty_level": "intermediate",
        "chapter_id": "chapter_2"
    }
)

# Track content consumption  
await analytics_collector.collect_event(
    event_type=EventType.CHAPTER_COMPLETE,
    user_id="user123",
    book_id="great_gatsby",
    chapter_id="chapter_1",
    content_type=ContentType.AUDIOBOOK,
    metadata={
        "listen_duration": 1200,  # seconds
        "completion_percentage": 100,
        "replay_count": 0
    }
)
```

### Decorator Usage
```python
from core.infrastructure import track_analytics

@track_analytics(EventType.AI_RESPONSE_GENERATED)
async def generate_ai_response(user_id: str, prompt: str, persona_id: str):
    # Function execution automatically tracked
    response = await ai_service.generate(prompt)
    return response
```

## Event Types

### User Engagement Events
- `SESSION_START` / `SESSION_END` - User session tracking
- `BOOK_START` / `BOOK_COMPLETE` - Book-level engagement
- `CHAPTER_START` / `CHAPTER_COMPLETE` - Chapter-level progress
- `PAUSE` / `RESUME` - Playback control tracking

### AI Interaction Events  
- `AI_CONVERSATION_START` / `AI_CONVERSATION_END` - Persona interactions
- `AI_QUESTION_ASKED` - User questions to AI
- `AI_RESPONSE_GENERATED` - AI responses to users
- `PERSONA_SWITCH` - User changing AI personas

### Educational Events
- `COMPREHENSION_CHECK` - Quiz/assessment attempts
- `QUIZ_START` / `QUIZ_COMPLETE` - Detailed quiz tracking
- `NOTE_CREATED` / `NOTE_UPDATED` - User annotations
- `BOOKMARK_CREATED` - Content bookmarking

### Content Events
- `CONTENT_SEARCH` - Search queries and results
- `RECOMMENDATION_SHOWN` / `RECOMMENDATION_CLICKED` - Content discovery
- `REVIEW_CREATED` - User-generated reviews
- `RATING_SUBMITTED` - Content ratings

## Database Schema

### Core Events Table
```sql
CREATE TABLE analytics_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(36) UNIQUE,
    event_type VARCHAR(50),
    timestamp TIMESTAMPTZ,
    user_id VARCHAR(36),
    session_id VARCHAR(32),
    book_id VARCHAR(100),
    chapter_id VARCHAR(100), 
    persona_id VARCHAR(100),
    metadata JSONB
);
```

### Aggregated Views
- `analytics_user_engagement` - Daily user activity summaries
- `analytics_persona_effectiveness` - AI persona performance metrics
- `analytics_content_consumption` - Content popularity and engagement
- `analytics_realtime_cache` - Live dashboard data

## Configuration

### Environment Variables
```bash
# Analytics database
ANALYTICS_DATABASE_URL=postgresql://user:pass@localhost/betterbooks
ANALYTICS_REDIS_URL=redis://localhost:6379/1

# Processing settings
ANALYTICS_BATCH_SIZE=100
ANALYTICS_BATCH_INTERVAL=30
ANALYTICS_RETENTION_DAYS=365

# Privacy settings
ANALYTICS_HASH_USER_IDS=true
ANALYTICS_ENABLE_IP_TRACKING=false
ANALYTICS_COPPA_COMPLIANCE=true
```

### Analytics Config
```python
from core.infrastructure import AnalyticsConfig

config = AnalyticsConfig(
    batch_size=100,
    batch_interval_seconds=30,
    enable_real_time=True,
    hash_sensitive_data=True,
    retention_days=365,
    enable_teacher_insights=True
)
```

## Monitoring

### Prometheus Metrics
- `analytics_events_total{event_type, user_type}` - Total events collected
- `analytics_batch_processing_duration` - Batch processing performance
- `analytics_events_dropped_total` - Lost events due to errors
- `analytics_cache_hit_ratio` - Real-time cache effectiveness
- `analytics_db_write_duration` - Database write performance

### Health Checks
```python
# Check analytics system health
health_status = await analytics_collector.health_check()
```

## Analytics APIs

### Summary Endpoints
```python
# Get user engagement summary
GET /analytics/users/{user_id}/engagement?period=7d

# Get persona effectiveness metrics  
GET /analytics/personas/{persona_id}/effectiveness?period=30d

# Get content popularity metrics
GET /analytics/content/popular?limit=10&period=7d
```

### Teacher Dashboard APIs
```python
# Get student progress for teachers
GET /analytics/teachers/{teacher_id}/students/progress

# Get classroom analytics
GET /analytics/classrooms/{classroom_id}/engagement

# Get assignment completion rates
GET /analytics/assignments/{assignment_id}/completion
```

### Admin Reports
```python
# System-wide usage statistics
GET /analytics/admin/system/usage?period=30d

# User growth metrics
GET /analytics/admin/users/growth?period=90d

# Content performance reports
GET /analytics/admin/content/performance?period=30d
```

## Real-Time Features

### Live Metrics Dashboard
- Active users count
- Current AI conversations
- Popular content streams
- System performance indicators

### WebSocket Streaming
```python
# Subscribe to real-time analytics
@app.websocket("/analytics/live")
async def analytics_websocket(websocket: WebSocket):
    await analytics_collector.stream_metrics(websocket)
```

## Privacy & Compliance

### Data Protection
- User ID hashing using SHA-256
- IP address anonymization 
- Configurable data retention
- GDPR deletion support
- COPPA-compliant data collection

### Educational Compliance
- FERPA-compliant student data handling
- Teacher access controls
- Parent consent mechanisms
- Data export capabilities

## Testing

### Unit Tests
```bash
python -m pytest tests/infrastructure/test_usage_analytics.py -v
```

### Integration Tests  
```bash
python -m pytest tests/integration/test_analytics_collection.py
```

### Load Testing
```bash
# Test high-volume event collection
python scripts/test_analytics_load.py --events=10000 --concurrency=50
```

## Performance Optimization

### Batch Processing
- Configurable batch sizes
- Async batch writing
- Error retry mechanisms
- Dead letter queue handling

### Database Optimization
- Partitioned tables by date
- Optimized indexes for queries
- Materialized views for aggregations
- Automatic data archival

### Caching Strategy
- Redis-backed real-time metrics
- Aggregated data caching
- Query result caching
- Cache invalidation strategies

## Troubleshooting

### Common Issues

1. **High event volume causing delays**
   - Increase batch size
   - Add more Redis memory
   - Scale PostgreSQL connections

2. **Missing or incomplete data**
   - Check event collection middleware
   - Verify database connectivity
   - Review error logs for dropped events

3. **Slow dashboard loading**
   - Enable real-time caching
   - Optimize database queries
   - Review materialized view refresh

### Debug Commands
```bash
# Check analytics processing status
curl "http://localhost:8000/admin/analytics/status"

# View recent events for debugging
curl "http://localhost:8000/admin/analytics/events/recent?limit=10"

# Check batch processing health
curl "http://localhost:8000/admin/analytics/batch-processor/health"
```

## Future Enhancements

- Machine learning-based insights
- Predictive analytics for student success
- Advanced visualization components
- A/B testing infrastructure
- Custom event tracking for teachers