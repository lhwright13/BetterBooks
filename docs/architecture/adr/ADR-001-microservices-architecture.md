# ADR-001: Microservices Architecture

## Status
Accepted

## Date
2025-01-01

## Context
BetterBooks is an AI-powered audiobook companion platform that needs to handle multiple complex functionalities:
- Audio file streaming and processing
- AI text generation with multiple personas
- Vector embeddings and similarity search
- Text-to-speech synthesis
- Audio transcription and chapter detection
- Real-time user interactions

The platform needs to scale individual components independently, maintain high availability, and allow for technology diversity across different services.

## Decision Drivers
- **Scalability**: Different services have vastly different resource requirements (TTS is CPU-intensive, LLM is API-bound)
- **Technology Diversity**: Need to use best-in-class tools for each domain (pgvector for embeddings, Coqui for TTS)
- **Team Autonomy**: Enable parallel development across different service domains
- **Fault Isolation**: Failure in one service shouldn't bring down the entire platform
- **Deployment Flexibility**: Need to update services independently without full system redeployment

## Considered Options
1. **Monolithic Application** - Single FastAPI application with all functionality
2. **Microservices Architecture** - Separate services for each domain
3. **Serverless Functions** - FaaS approach with AWS Lambda/Azure Functions
4. **Modular Monolith** - Single deployable with strong module boundaries

## Decision Outcome
Chosen option: **Microservices Architecture**, because it provides the best balance of scalability, maintainability, and development velocity for our AI-intensive workloads.

### Positive Consequences
- Independent scaling of resource-intensive services (TTS, transcription)
- Technology flexibility (can use specialized tools per service)
- Fault isolation (LLM API failures don't affect audio streaming)
- Parallel development across team members
- Clear service boundaries and responsibilities
- Easy to add new AI models or services

### Negative Consequences
- Increased operational complexity
- Network latency between services
- Distributed system challenges (eventual consistency, distributed tracing)
- Higher initial development overhead
- Need for service discovery and API gateway

## Pros and Cons of the Options

### Option 1: Monolithic Application
- **Pros:**
  - Simple deployment and operations
  - No network overhead between components
  - Easier debugging and testing
  - Single codebase to maintain
- **Cons:**
  - Cannot scale components independently
  - Single point of failure
  - Technology lock-in
  - Difficult to optimize for different workload characteristics

### Option 2: Microservices Architecture
- **Pros:**
  - Independent scaling and deployment
  - Technology diversity (pgvector, Coqui TTS, Gemini API)
  - Fault isolation and resilience
  - Clear service boundaries
  - Parallel development
- **Cons:**
  - Operational complexity
  - Network latency
  - Distributed system challenges
  - Need for sophisticated monitoring

### Option 3: Serverless Functions
- **Pros:**
  - Automatic scaling
  - Pay-per-use pricing
  - No infrastructure management
- **Cons:**
  - Cold start latency issues
  - Vendor lock-in
  - Limited execution time (not suitable for TTS/transcription)
  - Difficult to maintain stateful connections

### Option 4: Modular Monolith
- **Pros:**
  - Simpler than microservices
  - Strong module boundaries
  - Potential to evolve to microservices
- **Cons:**
  - Still can't scale modules independently
  - Shared deployment cycle
  - Technology choices affect entire application

## Implementation Details

### Service Breakdown
- **API Gateway** (Port 8000): Central entry point, routing, authentication
- **Context Service** (Port 8001): Vector embeddings, similarity search
- **LLM Gateway** (Port 8002): AI text generation, persona management  
- **TTS Service** (Port 8004): Text-to-speech synthesis
- **Transcription Service** (Port 8003): Audio transcription, chapter detection

### Communication Pattern
- HTTP/REST for service-to-service communication
- API Gateway as single entry point for clients
- Redis for shared caching and session management
- PostgreSQL as shared database (with service-specific schemas)

## Links
- [ADR-002: FastAPI Framework Selection](ADR-002-fastapi-framework.md)
- [ADR-003: PostgreSQL with pgvector](ADR-003-postgresql-pgvector.md)
- [Docker Compose Configuration](/docker-compose.yml)

## Notes
Future considerations include moving to gRPC for internal service communication and implementing service mesh for advanced traffic management.