# BetterBooks API Documentation

Welcome to the BetterBooks API documentation. This directory contains comprehensive guides for integrating with the BetterBooks audiobook platform.

## Quick Start

### 1. Get Your API Access
```bash
# Register for an account
curl -X POST http://localhost:8000/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email": "you@example.com", "password": "secure123"}'

# Login to get your token
curl -X POST http://localhost:8000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email": "you@example.com", "password": "secure123"}'
```

### 2. Make Your First API Call
```bash
# Get AI completion
curl -X POST http://localhost:8000/complete \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"prompt": "Tell me about The Great Gatsby", "config": "default"}'
```

### 3. Explore Interactive Documentation
- **API Gateway**: http://localhost:8000/docs
- **Context Service**: http://localhost:8001/docs
- **LLM Gateway**: http://localhost:8002/docs

## Documentation Index

| Document | Description | Audience |
|----------|-------------|----------|
| [API Versioning Strategy](API_VERSIONING_STRATEGY.md) | How API versions work and migration guides | Developers |
| [Authentication Guide](AUTHENTICATION_GUIDE.md) | JWT authentication and role-based access | Developers |
| [Rate Limiting](RATE_LIMITING.md) | API quotas and usage limits | Developers |
| [Error Handling](ERROR_HANDLING.md) | Error codes and troubleshooting | Developers |
| [Webhooks](WEBHOOKS.md) | Event notifications and callbacks | Integrators |

## API Overview

### Base URLs
- **Local Development**: `http://localhost:8000`
- **Staging**: `https://staging-api.betterbooks.com`
- **Production**: `https://api.betterbooks.com`

### Current API Version
- **Version**: v1 (default)
- **Status**: Stable
- **OpenAPI Spec**: [`/openapi.json`](http://localhost:8000/openapi.json)

## Services Architecture

BetterBooks uses a microservices architecture with the following components:

### API Gateway (Port 8000)
**Purpose**: Central entry point for all client requests
- Authentication and authorization
- Request routing to backend services
- Rate limiting and monitoring
- CORS handling

**Key Endpoints**:
- `POST /auth/login` - User authentication
- `POST /complete` - AI text completion
- `GET /books/{id}` - Book information
- `POST /tts/synthesize` - Text-to-speech

### Context Service (Port 8001) 
**Purpose**: Vector embeddings and similarity search
- Semantic search through audiobook content
- Chapter and book context retrieval
- Vector similarity matching

**Key Endpoints**:
- `POST /search` - Semantic content search
- `GET /context/{book_id}` - Book context
- `POST /embeddings` - Create embeddings

### LLM Gateway (Port 8002)
**Purpose**: AI persona management and text generation
- Multiple AI personas (teacher, narrator, character)
- Gemini API integration
- Response caching and optimization

**Key Endpoints**:
- `POST /complete` - Generate AI responses
- `GET /personas` - List available personas
- `POST /chat` - Conversational interactions

### TTS Service (Port 8004)
**Purpose**: Text-to-speech synthesis
- Convert text to natural-sounding audio
- Multiple voice options
- Audio format optimization

**Key Endpoints**:
- `POST /synthesize` - Convert text to speech
- `GET /voices` - Available voices
- `GET /audio/{id}` - Download audio files

### Transcription Service (Port 8003)
**Purpose**: Audio processing and chapter detection
- Automatic chapter detection
- Audio transcription
- Content analysis and summarization

**Key Endpoints**:
- `POST /detect-chapters` - AI-powered chapter detection
- `POST /transcribe` - Audio transcription
- `POST /analyze` - Content analysis

## Authentication

BetterBooks uses JWT-based authentication with role-based access control:

### User Roles
- **`user`**: Basic access to reading features
- **`premium`**: Enhanced features and higher limits  
- **`moderator`**: Content management capabilities
- **`admin`**: Full system access

### Authentication Flow
1. Register or login to get JWT tokens
2. Include `Authorization: Bearer <token>` header in requests
3. Refresh tokens before expiration
4. Handle authentication errors gracefully

See the [Authentication Guide](AUTHENTICATION_GUIDE.md) for complete details.

## Request/Response Format

### Request Headers
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
Accept: application/json
API-Version: 1 (optional)
```

### Standard Response Format
```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2025-01-13T10:00:00Z",
    "version": "1.0.0",
    "request_id": "req_123456"
  }
}
```

### Error Response Format
```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "Human readable error message",
    "details": {
      "field": "Additional error context"
    }
  },
  "meta": {
    "timestamp": "2025-01-13T10:00:00Z",
    "request_id": "req_123456"
  }
}
```

## Rate Limiting

API requests are rate limited based on user type:

| User Type | Requests/Hour | LLM Requests/Hour |
|-----------|---------------|-------------------|
| Anonymous | 100 | 0 |
| User | 1,000 | 50 |
| Premium | 10,000 | 500 |
| Admin | Unlimited | Unlimited |

Rate limit headers are included in all responses:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1642093200
```

## Common Use Cases

### 1. AI-Powered Book Discussion
```python
# Get context about a book section
context = client.search_context("The Great Gatsby", query="What is the green light?")

# Generate AI discussion
response = client.complete(
    prompt=f"Discuss the symbolism of the green light in {context}",
    persona="literature_teacher"
)
```

### 2. Chapter Analysis
```python
# Detect chapters in audiobook
chapters = client.detect_chapters(book_id="gatsby", audio_file=audio_data)

# Generate chapter summaries  
for chapter in chapters:
    summary = client.complete(
        prompt=f"Summarize this chapter: {chapter.content}",
        persona="narrator"
    )
```

### 3. Voice Interaction
```python
# Convert user speech to text
transcript = client.transcribe(audio_data)

# Get AI response
response = client.complete(transcript, persona="socratic_teacher")

# Convert response to speech
audio = client.synthesize(response.text, voice="female_teacher")
```

## SDK and Client Libraries

### Official SDKs
- **Python**: `pip install betterbooks-client`
- **JavaScript/TypeScript**: `npm install @betterbooks/client`
- **Dart/Flutter**: Available in pub.dev

### Community SDKs
- **Go**: Community-maintained
- **Ruby**: Community-maintained
- **Java**: Community-maintained

### Generate Your Own SDK
```bash
# Export OpenAPI specs
python scripts/export-openapi-specs.py

# Generate client in your language
openapi-generator generate \
  -i api-docs/combined.openapi.json \
  -g python \
  -o ./sdk/python
```

## Testing and Development

### Local Development Setup
```bash
# Start all services
docker-compose up --build

# Run tests
pytest tests/integration/test_api.py

# Check API health
curl http://localhost:8000/health/detailed
```

### Staging Environment
```bash
# Point to staging
export API_BASE_URL=https://staging-api.betterbooks.com

# Use staging credentials
curl https://staging-api.betterbooks.com/auth/login \
  -d '{"email": "test@example.com", "password": "test123"}'
```

### Production Environment
- **Base URL**: `https://api.betterbooks.com`
- **Authentication**: Production JWT tokens required
- **Rate Limits**: Production limits enforced
- **Monitoring**: Full observability stack

## Support and Resources

### Getting Help
- **Documentation Issues**: Create issue in repository
- **API Support**: Email api-support@betterbooks.com
- **Community Forum**: discussions.betterbooks.com
- **Discord**: Join our developer community

### Useful Links
- **Status Page**: status.betterbooks.com
- **Changelog**: api.betterbooks.com/changelog
- **Developer Blog**: blog.betterbooks.com/dev
- **OpenAPI Specs**: Available at `/openapi.json` endpoints

### Service Status
Check current service status and uptime:
- **API Gateway**: [Status](http://localhost:8000/health)
- **All Services**: [Health Dashboard](http://localhost:8000/health/detailed)
- **Metrics**: [Prometheus](http://localhost:9090)

## Migration Guides

### Upgrading API Versions
When we release new API versions, migration guides will be available:
- **v1 → v2**: Coming soon
- **Breaking Changes**: 6 months notice
- **Deprecation Timeline**: 12 months support

### Best Practices
1. **Handle Errors Gracefully**: Always check response status
2. **Implement Retry Logic**: Use exponential backoff
3. **Cache Responses**: Reduce API calls where possible
4. **Monitor Usage**: Track your API usage and limits
5. **Keep SDKs Updated**: Use latest versions for bug fixes

## Contributing

### API Feedback
We welcome feedback on our API design:
- **Feature Requests**: Create GitHub issues
- **Bug Reports**: Include reproduction steps
- **Documentation**: Submit pull requests for improvements

### Beta Features
Early access to new API features:
- **Sign up**: beta@betterbooks.com
- **Feedback**: Share your experience
- **Testing**: Help us improve before general release