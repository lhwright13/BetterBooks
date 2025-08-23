# EchoWright

EchoWright is an AI-powered audiobook companion platform that transforms the listening experience through intelligent features like chapter detection, personalized summaries, and educational question generation.

[![Build Status](https://github.com/username/echowright/workflows/CI/badge.svg)](https://github.com/username/echowright/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ✨ Features

- **🧠 AI-Powered Chapter Detection** - Automatically segments audiobooks with intelligent boundary detection
- **📚 Smart Summaries** - Multiple summary styles (brief, detailed, themes, key points, Q&A)
- **🤔 Personalized Questions** - Educational questions tailored to reading context and difficulty
- **🎭 AI Personas** - Configurable AI companions (Teacher, Tutor, Character-based)
- **🔍 Semantic Search** - Find content across books using natural language
- **📱 Cross-Platform** - Web demo and Flutter mobile app
- **🔧 Production-Ready** - Comprehensive monitoring, logging, and deployment tools

## 🚀 Quick Start

### Prerequisites

- **Docker & Docker Compose** - For running the full stack
- **Python 3.11+** - For development and testing
- **Node.js 18+** - For web application
- **Flutter 3.0+** - For mobile development

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/username/echowright.git
   cd echowright
   ```

2. **Set up environment configuration:**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys (see Security Setup below)
   ```

3. **Start the platform:**
   ```bash
   docker-compose up --build
   ```

   Or use the helper script:
   ```bash
   ./scripts/run_app.sh
   ```

4. **Access the services:**
   - **Web Demo:** http://localhost:8080
   - **API Gateway:** http://localhost:8000
   - **Grafana Dashboard:** http://localhost:3000 (admin/admin)
   - **Prometheus Metrics:** http://localhost:9090

## 🏗️ Project Structure

```
echowright/
├── core/                          # Core functionality modules
│   ├── ai/                       # AI-powered features
│   ├── database/                 # Database management and migrations
│   ├── infrastructure/           # Logging, metrics, health checks
│   └── shared/                   # Common utilities and models
├── platform/
│   ├── backend/services/         # Microservices
│   │   ├── api_gateway/         # Central API gateway (port 8000)
│   │   ├── context_service/     # Vector embeddings (port 8001)
│   │   ├── llm_gateway/         # AI persona management (port 8002)
│   │   ├── tts_service/         # Text-to-speech (port 8003)
│   │   └── transcription_service/ # Chapter detection (port 8004)
│   ├── frontend/web_app/        # Web demo interface
│   └── mobile/mobile_app/       # Flutter mobile application
├── config/                      # Configuration files
│   ├── docker/                  # Docker Compose configs
│   ├── local/                   # Development settings
│   ├── production/              # Production configs and LLM personas
│   └── helm/                    # Kubernetes deployment
├── docs/                        # Documentation
└── tests/                       # Test suites (unit, integration, performance)
```

## Documentation

### Getting Started
- [Security Setup Guide](docs/setup/SECURITY_SETUP.md) - API keys and security configuration
- [Local Development Guide](docs/setup/LOCAL_BACKEND_GUIDE.md) - Development environment setup
- [Deployment Guide](docs/setup/AZURE_DEPLOYMENT_GUIDE.md) - Production deployment

### Architecture & Design
- [System Architecture](docs/architecture/SYSTEM_ARCHITECTURE.md) - High-level system design
- [AI Features](docs/features/AI_FEATURES.md) - AI capabilities and implementation
- [Logging & Monitoring](docs/architecture/LOGGING_AND_MONITORING.md) - Observability implementation
- [Architecture Decision Records](docs/architecture/adr/README.md) - Key design decisions

### API & Integration
- [API Documentation](docs/api/README.md) - Complete API reference
- [Authentication Guide](docs/api/AUTHENTICATION_GUIDE.md) - API authentication
- [Customization Guide](docs/architecture/CUSTOMIZATION_GUIDE.md) - Extending the platform

### Operations & Deployment
- [Deployment Runbooks](docs/operations/runbooks/README.md) - Operational procedures
- [GitHub Actions Setup](docs/GITHUB_ACTIONS_SETUP.md) - CI/CD pipeline
- [Production Auth Setup](docs/PRODUCTION_AUTH_SETUP.md) - Production security

## Configuration

### Environment Variables

Key configuration variables (see `.env.example`):

```bash
# AI Services
GEMINI_API_KEY=your_gemini_api_key_here

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/echowright
REDIS_URL=redis://localhost:6379

# Security
JWT_SECRET_KEY=your_secure_random_key
API_RATE_LIMIT=100

# Monitoring
ENABLE_METRICS=true
JAEGER_ENDPOINT=http://localhost:14268/api/traces
```

### LLM Personas

AI personas are configured via JSON files in `config/production/llm_configs/`:
- `English Teacher.json` - Educational focus with literary analysis
- `Language Tutor.json` - Language learning and vocabulary
- `Omniscient Helper.json` - General audiobook assistance

## 🧪 Development

### Running Tests

**All tests:**
```bash
./scripts/run_tests.sh
```

**Unit tests only:**
```bash
pytest tests/unit/ -v
```

**Integration tests:**
```bash
pytest tests/integration/ -v
```

**Performance testing:**
```bash
cd tests/performance/
locust -f locustfile.py --host=http://localhost:8000
```

See [Testing Documentation](tests/README.md) for detailed test information.

### Mobile App Development

```bash
cd platform/mobile/mobile_app/
flutter pub get
flutter run
flutter test
```

See [Mobile App README](platform/mobile/mobile_app/README.md) for detailed setup.

### Database Management

```bash
# Apply migrations
python -c "from core.database import DatabaseMigrationManager; import asyncio; asyncio.run(DatabaseMigrationManager().apply_migrations())"

# Check migration status
python -c "from core.database import DatabaseMigrationManager; import asyncio; print(asyncio.run(DatabaseMigrationManager().get_migration_status()))"
```

See [Database Documentation](core/database/README.md) for detailed information.

## Deployment

### Docker Compose (Development)
```bash
docker-compose up --build
```

### Kubernetes (Production)
```bash
# Using Helm charts
helm install echowright config/helm/infra/helm/
```

### Azure Cloud
See [Azure Deployment Guide](docs/setup/AZURE_DEPLOYMENT_GUIDE.md) for complete production setup.

## Monitoring

### Health Checks
- Basic: `/health`
- Detailed: `/health/detailed` (includes system metrics)
- Readiness: `/health/ready` (Kubernetes readiness probe)
- Liveness: `/health/live` (Kubernetes liveness probe)

### Observability Stack
- **Prometheus** (http://localhost:9090) - Metrics collection
- **Grafana** (http://localhost:3000) - Dashboards and visualization
- **Jaeger** (http://localhost:16686) - Distributed tracing

## 🔮 Roadmap

See our [Development Roadmap](docs/project/DEVELOPMENT_ROADMAP.md) for planned features and enhancements.

**Current Focus:**
- Enhanced AI context management
- Advanced caching strategies
- Multi-modal AI interactions
- Cross-book intelligence

**Future Features:**
- Real-time voice conversations
- Advanced persona systems
- Multi-language support
- Offline capabilities

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: Browse the [docs/](docs/) directory
- **Issues**: [GitHub Issues](https://github.com/username/echowright/issues)
- **Discussions**: [GitHub Discussions](https://github.com/username/echowright/discussions)

## Acknowledgments

- **Google Gemini** - AI language model
- **Coqui TTS** - Text-to-speech synthesis
- **pgvector** - Vector similarity search
- **FastAPI** - Web framework
- **Flutter** - Mobile development

---

Built with ❤️ for audiobook enthusiasts and AI technology exploration.