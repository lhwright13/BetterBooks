# EchoWright

Monorepo for the EchoWright AI-powered audiobook companion platform. This repository contains the
mobile application and all backend microservices for intelligent audiobook interaction.

## Structure

- `mobile_app/` – Flutter application.
- `services/` – Backend services.
  - `api_gateway/` – Public REST API.
  - `context_service/` – Manages book context and embeddings.
  - `llm_gateway/` – Abstraction layer over the chosen language model.
  - `tts_service/` – Generates audio snippets.
- `proto/` – gRPC/Protobuf definitions.
- `infra/` – Terraform and Helm deployment configurations.
- `llm_configs/` – Example personas and model settings selectable in the demo UI.

Each service is a small FastAPI application packaged with a Dockerfile and
currently exposes only a simple `/health` endpoint.

## Running the stack locally

**🔐 Important: Complete security setup first!**
See [SECURITY_SETUP.md](SECURITY_SETUP.md) for detailed configuration instructions.

This repository includes a `docker-compose.yml` file for spinning up all
services along with a Postgres database. Docker and Docker Compose must be
installed.

### Quick Start:

1. **Set up environment configuration:**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys (see SECURITY_SETUP.md)
   ```

2. **Start the platform:**
   ```bash
   docker-compose up --build
   ```

   You can confirm the key is available inside the container with
   `docker-compose exec llm_gateway env | grep GEMINI_API_KEY`.

   The command builds the service images (if necessary) and starts the full
   stack. You can also start everything using the helper script:

   ```bash
   ./scripts/run_app.sh
   ```

   The LLM Gateway relies on the `google-generativeai` package. Ensure the
   image build has network access so the latest version can be installed.

2. Once running you can access the services on the following ports:

   - **API Gateway:** <http://localhost:8000>
   - **Context Service:** <http://localhost:8001>
   - **LLM Gateway:** <http://localhost:8002>
   - **TTS Service:** <http://localhost:8003>
  - **Web Demo:** <http://localhost:8080>

  Open <http://localhost:8080> in your browser to view the simple demo page. A drop-down lets you choose any configuration from `llm_configs/` before sending a prompt.

  Postgres runs from the `pgvector/pgvector:pg15` image so the `pgvector`
  extension is available. It is exposed on port `5432` with the default
  credentials `betterbooks`/`betterbooks` and database name `betterbooks`.

3. Stop the stack with `Ctrl+C` and remove containers with:

   ```bash
 docker-compose down
  ```

## Running tests

Python unit tests cover the FastAPI services. Install the required
dependencies and run `pytest` from the repository root:

```bash
pip install -r services/api_gateway/requirements.txt \
    -r services/context_service/requirements.txt \
    -r services/llm_gateway/requirements.txt \
    pgvector pytest
pytest -q
```

Alternatively run:

```bash
./scripts/run_tests.sh
```


The tests mock heavy external dependencies so no database, OpenAI key or
TTS model download is required.

## Customization

See [docs/CUSTOMIZATION_GUIDE.md](docs/CUSTOMIZATION_GUIDE.md) for information on extending the UI, experimenting with models, adjusting prompts, collecting data and more.

---

# EchoWright State-of-the-Art Implementation Roadmap
*A comprehensive, step-by-step guide to building cutting-edge audiobook AI capabilities*

## 🎯 **PHASE 1: Foundation Hardening & Security**
*Build rock-solid foundations before adding advanced features*

### Security & Production Readiness

#### 1.1 API Security Implementation
- [x] **Set up environment-based configuration**
  - ✅ Move all API keys to environment variables
  - ✅ Create `.env.example` files for each service
  - ✅ Implement proper secrets management structure
  - ✅ **Learning Focus**: Understanding security best practices in microservices
  - 📁 **Files Created**: `.env.example` files for all services, `config_manager.py`, `SECURITY_SETUP.md`

- [x] **Implement API authentication & authorization**
  - ✅ Add JWT-based authentication to API Gateway
  - ✅ Create user management system
  - ✅ Implement role-based access control (RBAC)
  - ✅ Add API rate limiting with Redis
  - **Learning Focus**: Modern authentication patterns
  - 📁 **Files Created**: `auth.py`, `auth_routes.py`, `rate_limiter.py`, Redis service in `docker-compose.yml`

- [ ] **Add comprehensive logging & monitoring**
  - Integrate structured logging (JSON format)
  - Set up health check endpoints for all services
  - Add Prometheus metrics collection
  - Implement distributed tracing with Jaeger
  - **Learning Focus**: Observability in distributed systems

#### 1.2 Database Optimization
- [ ] **Optimize PostgreSQL for production**
  - Add connection pooling with pgbouncer
  - Set up read replicas for scaling
  - Implement proper indexing strategy
  - Add database migrations system
  - **Learning Focus**: Database performance and scaling

- [ ] **Enhance vector search capabilities**
  - Optimize pgvector indexing (HNSW vs IVFFlat)
  - Implement hybrid search (semantic + keyword)
  - Add vector similarity caching
  - **Learning Focus**: Advanced vector database operations

### Advanced Error Handling & Resilience

#### 2.1 Service Resilience Patterns
- [ ] **Implement Circuit Breaker pattern**
  - Add circuit breakers for external API calls
  - Implement exponential backoff retry logic
  - Create fallback responses for service failures
  - **Learning Focus**: Microservices resilience patterns

- [ ] **Add comprehensive error handling**
  - Standardize error response formats across services
  - Implement proper error propagation
  - Add error tracking with Sentry
  - **Learning Focus**: Error management in distributed systems

#### 2.2 Performance Optimization
- [ ] **Implement caching strategies**
  - Add Redis for session management
  - Implement semantic response caching
  - Add CDN for audio file delivery
  - Cache embeddings and frequent queries
  - **Learning Focus**: Multi-layer caching strategies

- [ ] **Optimize API performance**
  - Add request/response compression
  - Implement API response pagination
  - Add database query optimization
  - **Learning Focus**: API performance optimization

### Testing & Documentation

#### 3.1 Comprehensive Testing Suite
- [ ] **Backend testing**
  - Unit tests for all services (pytest)
  - Integration tests for API endpoints
  - Performance tests with load testing
  - **Learning Focus**: Testing microservices architectures

- [ ] **Frontend testing**
  - Widget tests for Flutter components
  - Integration tests for user flows
  - Performance profiling
  - **Learning Focus**: Mobile app testing strategies

#### 3.2 Documentation & DevOps
- [ ] **Complete documentation**
  - API documentation with OpenAPI/Swagger
  - Architecture decision records (ADRs)
  - Deployment runbooks
  - **Learning Focus**: Technical documentation best practices

---

## 🚀 **PHASE 2: Advanced LLM Integration**
*Upgrade from basic Gemini to state-of-the-art multimodal AI*

### Multi-Model LLM Architecture

#### 4.1 LLM Gateway Enhancement
- [ ] **Implement multi-provider LLM routing**
  - Add OpenAI GPT-4o integration alongside Gemini
  - Create intelligent model selection logic
  - Implement cost-aware routing (cheap vs premium models)
  - Add model performance monitoring
  - **Learning Focus**: Multi-provider AI architectures

- [ ] **Add streaming response capabilities**
  - Implement Server-Sent Events (SSE) for real-time responses
  - Add WebSocket support for bidirectional communication
  - Create streaming response handlers in Flutter
  - **Learning Focus**: Real-time AI conversation patterns

#### 4.2 Context Window Management
- [ ] **Implement advanced context management**
  - Add conversation history compression
  - Implement sliding window context management
  - Create context relevance scoring
  - Add automatic context pruning
  - **Learning Focus**: Managing large language model context efficiently

### Enhanced Speech Processing

#### 5.1 Upgrade Speech-to-Text
- [ ] **Replace basic STT with AssemblyAI**
  - Integrate AssemblyAI Universal-Streaming
  - Implement real-time transcription with WebSockets
  - Add speaker diarization for multi-person scenarios
  - Implement confidence scoring and error handling
  - **Learning Focus**: Professional speech recognition systems

- [ ] **Add voice activity detection**
  - Implement VAD to optimize processing
  - Add silence detection and trimming
  - Create adaptive audio input sensitivity
  - **Learning Focus**: Audio signal processing fundamentals

#### 5.2 Advanced Text-to-Speech
- [ ] **Integrate ElevenLabs for character voices**
  - Set up ElevenLabs API integration
  - Create voice cloning for book characters
  - Implement voice switching based on speaker
  - Add emotion and tone control
  - **Learning Focus**: Advanced voice synthesis and cloning

- [ ] **Implement voice caching system**
  - Cache generated audio responses
  - Implement audio compression and optimization
  - Add pre-generation for common responses
  - **Learning Focus**: Audio file management and optimization

### Real-Time Audio Capabilities

#### 6.1 OpenAI Realtime API Integration
- [ ] **Implement GPT-4o Voice Mode**
  - Set up WebSocket connection to OpenAI Realtime API
  - Implement bidirectional audio streaming
  - Add voice conversation state management
  - Create seamless voice-to-voice interactions
  - **Learning Focus**: Cutting-edge real-time AI voice capabilities

#### 6.2 Audio Processing Pipeline
- [ ] **Build comprehensive audio pipeline**
  - Implement audio format conversion and optimization
  - Add noise reduction and audio enhancement
  - Create audio quality monitoring
  - Implement adaptive bitrate for mobile
  - **Learning Focus**: Professional audio processing techniques

### Context-Aware Intelligence

#### 7.1 Advanced RAG Implementation
- [ ] **Upgrade to sophisticated RAG system**
  - Implement semantic chunking strategies for audiobooks
  - Add hybrid search (semantic + keyword + metadata)
  - Create context-aware retrieval scoring
  - Implement query expansion and refinement
  - **Learning Focus**: Advanced retrieval-augmented generation

- [ ] **Add long-context model integration**
  - Integrate models with 1M+ token context windows
  - Implement full-book processing capabilities
  - Create narrative continuity tracking
  - **Learning Focus**: Working with ultra-long context AI models

---

## 🎭 **PHASE 3: Multi-Agent Persona System**
*Transform from simple chat to sophisticated multi-character interactions*

### Agent Architecture Foundation

#### 8.1 Multi-Agent Framework Setup
- [ ] **Implement CrewAI integration**
  - Set up CrewAI framework in your Python backend
  - Create agent orchestration service
  - Design agent communication protocols
  - Implement agent state management
  - **Learning Focus**: Multi-agent AI systems architecture

- [ ] **Design persona definition system**
  - Create character profile data models
  - Implement persona trait system
  - Add personality consistency mechanisms
  - Create character knowledge boundaries
  - **Learning Focus**: AI persona design and psychology

#### 8.2 Character Agent Implementation
- [ ] **Build individual character agents**
  - Narrator Agent (story guidance, context management)
  - Character Agents (individual book personas)
  - Teacher Agent (educational focus)
  - Author Agent (meta-literary discussions)
  - **Learning Focus**: Specialized AI agent development

### Advanced Memory Systems

#### 9.1 Hierarchical Memory Architecture
- [ ] **Implement multi-layer memory system**
  - Short-term memory (conversation context)
  - Character-specific memory (persona consistency)
  - Story progress memory (narrative tracking)
  - User preference memory (personalization)
  - **Learning Focus**: AI memory architectures and cognitive modeling

- [ ] **Add episodic memory capabilities**
  - Track conversation history and patterns
  - Implement memory consolidation algorithms
  - Create memory retrieval and association
  - Add memory forgetting and pruning
  - **Learning Focus**: Advanced AI memory systems

#### 9.2 Context Continuity Management
- [ ] **Build narrative continuity system**
  - Track story progression and plot points
  - Maintain character relationship dynamics
  - Implement timeline and event tracking
  - Create cross-chapter memory linking
  - **Learning Focus**: Narrative AI and story understanding

### Persona Interaction Engine

#### 10.1 Character Voice Implementation
- [ ] **Create distinct character voices**
  - Generate unique voices for each major character
  - Implement voice characteristic consistency
  - Add emotional state reflection in voice
  - Create accent and speech pattern variation
  - **Learning Focus**: Character voice design and audio personality

- [ ] **Build persona switching system**
  - Implement seamless persona transitions
  - Add context-aware persona selection
  - Create persona introduction mechanisms
  - Implement multi-persona conversations
  - **Learning Focus**: Dynamic AI personality management

#### 10.2 Educational Agent Specialization
- [ ] **Enhance educational capabilities**
  - Create curriculum-aligned educational content
  - Implement adaptive learning pathways
  - Add comprehension testing and feedback
  - Create literary analysis capabilities
  - **Learning Focus**: AI-powered educational technology

### Advanced Interaction Patterns

#### 11.1 Conversation Orchestration
- [ ] **Implement sophisticated conversation management**
  - Multi-turn conversation planning
  - Context-aware response generation
  - Conversation flow optimization
  - Interruption and resumption handling
  - **Learning Focus**: Advanced conversational AI design

- [ ] **Add emotional intelligence**
  - Emotion detection in user speech/text
  - Empathetic response generation
  - Mood-adaptive interaction styles
  - Emotional state tracking over time
  - **Learning Focus**: Emotional AI and empathetic computing

---

## 🔮 **PHASE 4: Cutting-Edge Features**
*Implement the most advanced 2024-2025 AI capabilities*

### Speech-to-Speech Revolution

#### 12.1 End-to-End Audio Processing
- [ ] **Implement native audio-to-audio AI**
  - Direct audio input to audio output processing
  - Eliminate text intermediary steps
  - Add real-time audio manipulation
  - Implement audio emotion recognition
  - **Learning Focus**: Next-generation voice AI architectures

- [ ] **Add voice conversation capabilities**
  - Natural conversation flow management
  - Voice-based turn-taking protocols
  - Audio-native interruption handling
  - Real-time voice emotion adaptation
  - **Learning Focus**: Human-like voice interaction design

#### 12.2 Zero-Shot Voice Capabilities
- [ ] **Implement instant voice cloning**
  - Create character voices from minimal audio samples
  - Implement real-time voice adaptation
  - Add cross-lingual voice transfer
  - Create voice style transfer capabilities
  - **Learning Focus**: Advanced voice cloning and synthesis

### Intelligent Adaptation

#### 13.1 Learning User Preferences
- [ ] **Implement user behavior analysis**
  - Reading pattern recognition
  - Preference learning algorithms
  - Adaptive content recommendation
  - Personalized interaction styles
  - **Learning Focus**: Personalization and recommendation systems

- [ ] **Add constitutional AI principles**
  - Implement ethical guardrails
  - Add bias detection and mitigation
  - Create responsible AI interactions
  - Implement content filtering systems
  - **Learning Focus**: AI ethics and safety implementation

#### 13.2 Advanced Analytics
- [ ] **Build comprehensive analytics system**
  - User engagement tracking
  - Learning progress assessment
  - Conversation quality metrics
  - Performance optimization insights
  - **Learning Focus**: AI system analytics and optimization

### Integration & Polish

#### 14.1 Mobile App Enhancement
- [ ] **Upgrade Flutter app with advanced features**
  - Implement new AI capabilities in mobile UI
  - Add sophisticated audio controls
  - Create persona selection interfaces
  - Implement voice conversation UI
  - **Learning Focus**: Advanced mobile app development for AI

- [ ] **Optimize mobile performance**
  - Implement intelligent caching strategies
  - Add offline capability planning
  - Optimize battery usage for AI features
  - Create adaptive quality settings
  - **Learning Focus**: Mobile AI app optimization

#### 14.2 Production Readiness
- [ ] **Prepare for scale**
  - Load testing with advanced features
  - Performance optimization across all services
  - Security review of new capabilities
  - Cost optimization strategies implementation
  - **Learning Focus**: Scaling AI applications for production

### Deployment & Testing

#### 15.1 Production Deployment
- [ ] **Deploy to production environment**
  - Set up production Kubernetes cluster
  - Implement CI/CD pipelines
  - Configure monitoring and alerting
  - Set up backup and disaster recovery
  - **Learning Focus**: Production AI system deployment

- [ ] **User acceptance testing**
  - Beta user testing program
  - Feedback collection and analysis
  - Performance monitoring in production
  - Issue identification and resolution
  - **Learning Focus**: AI product validation and iteration

---

## 📊 **Success Metrics & Learning Objectives**

### Technical Achievements
- **Latency**: Sub-400ms response times for voice interactions
- **Context**: 1M+ token processing capability for full books
- **Reliability**: 99.9% uptime with graceful degradation
- **Performance**: Support for 1000+ concurrent users

### Learning Outcomes
- **AI Architecture**: Understanding of modern LLM integration patterns
- **Voice Technology**: Mastery of speech processing and synthesis
- **System Design**: Experience with scalable AI microservices
- **Production Skills**: Knowledge of AI system deployment and monitoring

### Innovation Milestones
- **Multi-Modal AI**: Seamless voice and text interaction
- **Character AI**: Believable book character personas
- **Context Mastery**: Full audiobook understanding and continuity
- **Real-Time Processing**: Human-like conversation capabilities

---

## 🎓 **Learning Resources Per Phase**

### Phase 1 Resources
- **Books**: "Building Microservices" by Sam Newman
- **Courses**: FastAPI documentation, PostgreSQL performance tuning
- **Practice**: Set up monitoring dashboards, implement security patterns

### Phase 2 Resources
- **Papers**: "Attention Is All You Need", GPT-4 technical report
- **Documentation**: OpenAI API docs, AssemblyAI guides
- **Practice**: Build streaming chat interfaces, implement RAG systems

### Phase 3 Resources
- **Research**: Multi-agent system papers, persona consistency studies
- **Frameworks**: CrewAI documentation, LangChain multi-agent patterns
- **Practice**: Create conversational AI agents, implement memory systems

### Phase 4 Resources
- **Cutting-Edge**: Latest AI research papers, voice AI breakthrough studies
- **Experimental**: OpenVoice, voice cloning repositories
- **Practice**: Implement experimental features, contribute to open source

---

This roadmap transforms your current solid foundation into a state-of-the-art AI audiobook platform while ensuring you understand every component deeply. Each section builds logically on the previous, with clear learning objectives and practical implementation goals.

