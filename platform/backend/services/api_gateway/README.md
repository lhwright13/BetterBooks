# API Gateway

FastAPI application serving as the public REST API and coordinating requests between the internal services. Provides comprehensive authentication, advanced infrastructure features, and request proxying for the EchoWright platform.

## Features

### Core Infrastructure
- **JWT Authentication** - Secure user authentication with email verification
- **User Management** - Registration, login, profile management with OAuth support
- **Advanced Rate Limiting** - Subscription-tiered limits with cost-based throttling
- **Usage Analytics** - Real-time event tracking and educational insights
- **Audio Pipeline** - WebSocket streaming, TTS synthesis, voice chat support
- **Request Proxying** - Routes requests to appropriate microservices
- **Circuit Breakers** - Fault tolerance for external service calls
- **Health Monitoring** - Comprehensive health checks and metrics
- **CORS Support** - Cross-origin resource sharing for web clients

### EchoWright-Specific Features
- **AI Persona Management** - Interactive educational AI characters
- **Real-Time Audio Streaming** - WebSocket-based TTS and voice conversations
- **Educational Analytics** - Student progress and teacher insights tracking
- **Semantic Caching** - AI-aware caching for improved performance
- **Subscription Tiers** - Free, Premium, Educational, and Admin access levels

## Running Locally

```bash
uvicorn main:app --reload
```

## Authentication Endpoints

### User Registration
```bash
curl -X POST localhost:8000/auth/register \
 -H "Content-Type: application/json" \
 -d '{
 "username": "john_doe",
 "email": "john@example.com", 
 "password": "secure_password123"
 }'
```

### User Login
```bash
curl -X POST localhost:8000/auth/login \
 -H "Content-Type: application/json" \
 -d '{
 "email": "john@example.com",
 "password": "secure_password123"
 }'
```

### Get User Profile
```bash
curl -X GET localhost:8000/auth/me \
 -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Token Refresh
```bash
curl -X POST localhost:8000/auth/refresh \
 -H "Authorization: Bearer YOUR_REFRESH_TOKEN"
```

## API Endpoints

### AI Services (Authenticated)

```bash
# Complete a prompt using the LLM
curl -X POST localhost:8000/complete \
 -H "Content-Type: application/json" \
 -H "Authorization: Bearer YOUR_JWT_TOKEN" \
 -d '{"prompt":"Tell me a joke"}'

# Convert text to speech
curl -X POST localhost:8000/tts \
 -H "Content-Type: application/json" \
 -H "Authorization: Bearer YOUR_JWT_TOKEN" \
 -d '{"text":"Hello"}'
```

### Book Management

```bash
# List available books
curl -X GET localhost:8000/books/list \
 -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Stream book chapter
curl -X GET localhost:8000/books/play/The%20Great%20Gatsby/Chapter%201.mp3 \
 -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Rate Limiting

The API Gateway implements subscription-tiered rate limiting with different limits based on user subscription levels:

### Subscription Tiers
- **FREE**: Basic limits for trial users
- **PREMIUM**: Higher limits for paying customers
- **EDUCATIONAL**: Special rates for students and teachers 
- **ADMIN**: Unrestricted access for platform administration

### Rate Limits by Operation Type

| Operation | FREE | PREMIUM | EDUCATIONAL | ADMIN |
|-----------|------|---------|-------------|-------|
| LLM Interactions | 20/hour | 200/hour | 100/hour | Unlimited |
| TTS Generation | 50/hour | 500/hour | 200/hour | Unlimited |
| Audio Streaming | 10/hour | 100/hour | 50/hour | Unlimited |
| Embedding Generation | 100/hour | 1000/hour | 500/hour | Unlimited |
| General API | 1000/hour | 5000/hour | 2000/hour | Unlimited |

### Authentication-Specific Limits
- **Registration**: 5 requests per hour per email
- **Login**: 10 requests per 15 minutes per email
- **Password Reset**: 3 requests per hour per email
- **Email Verification**: 3 requests per hour per user

## Authentication Flow

1. **Registration** - User creates account with email/password
2. **Login** - Returns JWT access token (30 min) and refresh token (7 days)
3. **API Calls** - Include `Authorization: Bearer <access_token>` header
4. **Token Refresh** - Use refresh token to get new access token when expired
5. **Logout** - Blacklists current access token

## Environment Variables

### Core Service Configuration
```bash
# Authentication & JWT
JWT_SECRET_KEY=your_secure_secret_key_here
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Email Service
SENDGRID_API_KEY=your_sendgrid_key
EMAIL_FROM_ADDRESS=noreply@echowright.com
FRONTEND_BASE_URL=https://app.echowright.com

# External Services
AZURE_OPENAI_API_KEY=your_azure_openai_api_key
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o-mini
REDIS_URL=redis://localhost:6379
DATABASE_URL=postgresql://user:pass@localhost/betterbooks

# Admin Access
DEFAULT_ADMIN_PASSWORD=your_admin_password
```

### Infrastructure Components
```bash
# Rate Limiting
RATE_LIMITER_REDIS_URL=redis://localhost:6379/2
RATE_LIMITER_ENABLED=true
RATE_LIMITER_DEFAULT_TIER=FREE

# Usage Analytics
ANALYTICS_DATABASE_URL=postgresql://user:pass@localhost/betterbooks
ANALYTICS_REDIS_URL=redis://localhost:6379/1
ANALYTICS_BATCH_SIZE=100
ANALYTICS_RETENTION_DAYS=365

# Audio Pipeline
AUDIO_PIPELINE_REDIS_URL=redis://localhost:6379/3
AUDIO_PIPELINE_ENABLED=true
TTS_SERVICE_URL=http://localhost:8003
VOICE_ACTIVITY_DETECTION=webrtcvad
```

## New Infrastructure Endpoints

### Real-Time Audio Streaming
```bash
# WebSocket TTS streaming
wscat -c "ws://localhost:8000/audio/stream/session123"

# WebSocket voice chat with AI persona
wscat -c "ws://localhost:8000/audio/voice-chat/shakespeare_tutor"
```

### Analytics Endpoints
```bash
# Get user engagement metrics
curl -X GET "localhost:8000/analytics/users/user123/engagement?period=7d" \
 -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Get persona effectiveness
curl -X GET "localhost:8000/analytics/personas/shakespeare_tutor/effectiveness?period=30d" \
 -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Get popular content
curl -X GET "localhost:8000/analytics/content/popular?limit=10&period=7d" \
 -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Rate Limiting Status
```bash
# Check current rate limit status
curl -X GET "localhost:8000/admin/rate-limit-status?user_id=user123" \
 -H "Authorization: Bearer YOUR_ADMIN_TOKEN"

# Reset rate limits (admin only)
curl -X POST "localhost:8000/admin/rate-limit-reset?user_id=user123" \
 -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

## Health Checks

### Standard Health Endpoints
- **Basic**: `GET /health`
- **Detailed**: `GET /health/detailed` (includes system metrics)
- **Authentication**: `GET /auth/health`
- **Ready**: `GET /health/ready` (Kubernetes readiness probe)
- **Live**: `GET /health/live` (Kubernetes liveness probe)

### Infrastructure Health Checks 
- **Rate Limiter**: `GET /admin/rate-limiter/health`
- **Analytics**: `GET /admin/analytics/health`
- **Audio Pipeline**: `GET /admin/audio/health`
- **Metrics**: `GET /metrics` (Prometheus format)

## Architecture Integration

The API Gateway now integrates with three major infrastructure components:

```mermaid
graph TD
 A[Mobile/Web Client] --> B[API Gateway]
 B --> C[Rate Limiter]
 B --> D[Analytics Collector] 
 B --> E[Audio Processor]

 C --> F[Redis DB 2]
 D --> G[Redis DB 1]
 D --> H[PostgreSQL]
 E --> I[Redis DB 3]
 E --> J[TTS Service]

 B --> K[LLM Gateway]
 B --> L[Context Service]
 B --> M[TTS Service]

 N[WebSocket Connections] --> E
 O[Real-time Analytics] --> D
 P[Subscription Tiers] --> C
```

### Database Usage
- **Redis DB 0**: Authentication and general caching
- **Redis DB 1**: Analytics event buffering and real-time metrics
- **Redis DB 2**: Rate limiting counters and sliding windows
- **Redis DB 3**: Audio pipeline caching and streaming buffers
- **PostgreSQL**: User data, analytics events, and aggregated metrics

## Testing & Development

### Testing Infrastructure Components
```bash
# Test rate limiting
curl -X POST "localhost:8000/admin/test-rate-limit" \
 -H "Content-Type: application/json" \
 -d '{"user_id": "test_user", "operation": "LLM_INTERACTION", "count": 25}'

# Test analytics collection
curl -X POST "localhost:8000/admin/test-analytics" \
 -H "Content-Type: application/json" \
 -d '{"event_type": "AI_CONVERSATION_START", "user_id": "test_user"}'

# Test audio streaming
curl -X POST "localhost:8000/admin/test-audio-tts" \
 -H "Content-Type: application/json" \
 -d '{"text": "Hello from EchoWright!", "voice": "neural_sarah"}'
```

### Database Migrations
```bash
# Run analytics migration
psql -d betterbooks -f core/database/migrations/V007_20250125_analytics_system.sql

# Verify migration
psql -d betterbooks -c "SELECT COUNT(*) FROM analytics_events;"
```

See [Authentication Testing Script](../../../../test_mobile_auth_integration.py) for comprehensive integration tests.
