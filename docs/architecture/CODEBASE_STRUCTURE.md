# EchoWright Codebase Structure

This document describes the reorganized, logical structure of the EchoWright audiobook platform codebase.

## 📁 **Directory Structure Overview**

```
EchoWright/
├── core/                          # Core functionality modules
│   ├── ai/                        # AI-powered features
│   ├── database/                  # Database management
│   ├── infrastructure/            # Infrastructure utilities
│   └── shared/                    # Shared utilities and models
├── platform/                     # Application platforms
│   ├── backend/services/          # Microservices
│   ├── frontend/web_app/          # Web application
│   └── mobile/mobile_app/         # Flutter mobile app
├── config/                        # Configuration files
│   ├── docker/                    # Docker & orchestration configs
│   ├── local/                     # Local development configs
│   ├── production/               # Production configurations
│   └── helm/                     # Kubernetes deployment configs
├── docs/                          # Documentation
│   ├── api/                       # API documentation
│   ├── architecture/              # System architecture docs
│   └── deployment/                # Deployment guides
├── tests/                         # Test suites
│   ├── unit/                      # Unit tests
│   └── integration/               # Integration tests
├── book_files/                    # Sample audiobook content
└── scripts/                       # Utility scripts
```

## 🧠 **Core Modules (`/core/`)**

### **AI Module (`/core/ai/`)**
Contains all AI-powered functionality:

- **`chapter_detection.py`** - Multi-modal chapter detection using semantic analysis, audio features, and LLM validation
- **`chapter_summaries.py`** - AI-powered chapter summarization with 5 different styles
- **`question_generation.py`** - Educational question generation with adaptive difficulty
- **`summary_types.py`** - Data models and enums for AI features
- **`chapter_storage.py`** - Database integration for AI features
- **`summary_storage.py`** - Storage utilities for summaries and questions

**Key Features:**
- Multi-style summarization (brief, detailed, themes, key points, Q&A)
- Adaptive question generation with 7 question types
- Confidence scoring for all AI-generated content
- LLM integration with fallback mechanisms

### **Database Module (`/core/database/`)**
Database management and optimization:

- **`database_manager.py`** - Async connection pooling and management
- **`database_migrations.py`** - Migration system with version control
- **`database_indexes.py`** - Index optimization strategies
- **`migrations/`** - SQL migration files

**Key Features:**
- Connection pooling with PgBouncer integration
- Automated migration system
- Vector search optimization (HNSW/IVFFlat indexes)
- Read replica support

### **Infrastructure Module (`/core/infrastructure/`)**
Operational and infrastructure utilities:

- **`health_checks.py`** - Comprehensive health check system
- **`logging_config.py`** - Structured JSON logging
- **`logging_middleware.py`** - Request correlation and middleware
- **`metrics.py`** - Prometheus metrics collection
- **`tracing.py`** - Distributed tracing with Jaeger

**Key Features:**
- Multi-level health checks (/health, /health/detailed, /health/ready, /health/live)
- Structured logging with correlation IDs
- Comprehensive metrics for all services
- Distributed tracing across microservices

### **Shared Module (`/core/shared/`)**
Common utilities and models:

- **`utils/config_manager.py`** - Environment-based configuration management
- **`models/`** - Shared data models (to be populated)

## 🏗️ **Platform Structure (`/platform/`)**

### **Backend Services (`/platform/backend/services/`)**
Microservices architecture:

```
services/
├── api_gateway/           # Central API gateway and routing
├── context_service/       # Vector embeddings and similarity search
├── llm_gateway/          # AI persona management and text completion
├── transcription_service/ # Audio transcription and AI features
└── tts_service/          # Text-to-speech synthesis
```

**Key Changes:**
- Removed duplicated `shared/` directories from each service
- Services now import from centralized `/core/` modules
- Cleaner service-specific code without infrastructure duplication

### **Frontend Applications**
- **`/platform/frontend/web_app/`** - Web-based demo interface
- **`/platform/mobile/mobile_app/`** - Flutter mobile application

## ⚙️ **Configuration Structure (`/config/`)**

### **Docker Configuration (`/config/docker/`)**
- **`docker-compose.yml`** - Complete development environment orchestration
- **`prometheus.yml`** - Metrics collection configuration

### **Local Development (`/config/local/`)**
- **`postgresql_primary.conf`** - Primary database configuration
- **`pgbouncer_primary.ini`** - Connection pooling configuration
- **`context_config.yaml`** - AI service configuration

### **Production Configuration (`/config/production/`)**
- **`llm_configs/`** - AI persona configurations
- Production-ready service configurations

### **Helm Charts (`/config/helm/`)**
Kubernetes deployment configurations for all services.

## 📖 **Documentation Structure (`/docs/`)**

### **API Documentation (`/docs/api/`)**
- **`CHAPTER_DETECTION_IMPLEMENTATION.md`** - AI features documentation
- OpenAPI/Swagger specifications (to be added)

### **Architecture Documentation (`/docs/architecture/`)**
- **`CODEBASE_STRUCTURE.md`** - This document
- **`CUSTOMIZATION_GUIDE.md`** - Platform customization guide
- **`LOGGING_AND_MONITORING.md`** - Observability documentation

### **Deployment Documentation (`/docs/deployment/`)**
- **`SECURITY_SETUP.md`** - Security configuration guide
- **`LOCAL_BACKEND_GUIDE.md`** - Local development setup
- **`IOS_DEPLOYMENT_GUIDE.md`** - iOS deployment instructions

## 🧪 **Testing Structure (`/tests/`)**

### **Unit Tests (`/tests/unit/`)**
- **`test_chapter_*.py`** - AI feature unit tests
- **`test_database_*.py`** - Database utility tests
- **`test_tracing_*.py`** - Infrastructure tests

### **Integration Tests (`/tests/integration/`)**
- **`test_local_backend.py`** - End-to-end backend testing
- Service integration tests

## 🚀 **Key Benefits of New Structure**

### **1. Logical Organization**
- **Separation of Concerns**: AI features, infrastructure, and application code are clearly separated
- **Reduced Duplication**: Single source of truth for shared functionality
- **Clear Dependencies**: Easy to understand relationships between modules

### **2. Scalability**
- **Modular Design**: Easy to add new AI features or infrastructure components
- **Clean Imports**: Organized import structure reduces complexity
- **Configuration Management**: Centralized configuration for different environments

### **3. Development Experience**
- **Better IDE Support**: Proper Python package structure with `__init__.py` files
- **Easier Testing**: Organized test structure with unit/integration separation
- **Documentation**: Co-located documentation with clear structure

### **4. Production Readiness**
- **Docker Optimization**: Clean Dockerfile structure with proper layer caching
- **Configuration Management**: Environment-specific configurations
- **Observability**: Integrated logging, metrics, and tracing

## 🔧 **Import Patterns**

### **For Services:**
```python
# Core AI functionality
from core.ai import ChapterDetector, ChapterSummarizer
from core.ai.chapter_detection import detect_chapters_for_audiobook

# Infrastructure
from core.infrastructure import setup_logging, setup_metrics
from core.infrastructure.health_checks import create_health_endpoint

# Database
from core.database import get_database_manager, database_connection

# Shared utilities
from core.shared.utils import ConfigManager, get_config
```

### **For Tests:**
```python
# Test AI components
from core.ai.chapter_detection import ChapterDetectionEngine
from core.ai.summary_types import SummaryStyle

# Test infrastructure
from core.infrastructure.health_checks import HealthCheckManager
```

## 📋 **Migration Guide**

### **From Old Structure:**
1. **Imports**: Update all imports to use `core.*` pattern
2. **Configuration**: Move configs from root to appropriate `/config/` subdirectories
3. **Tests**: Move tests from root to `/tests/unit/` or `/tests/integration/`
4. **Docker**: Update Dockerfiles to use new structure
5. **Documentation**: Update references to reflect new paths

### **Docker Development:**
The new `docker-compose.yml` mounts `/core/` as a volume, allowing real-time development without rebuilds.

### **Production Deployment:**
For production, copy core modules into service containers instead of mounting volumes.

---

This structure provides a robust foundation for the EchoWright platform while maintaining clear separation of concerns and enabling efficient development workflows.