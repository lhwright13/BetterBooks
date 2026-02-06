# BetterBooks

AI-powered audiobook platform with interactive chat features.

## Features

- Browse and purchase audiobooks
- AI chat with book personas (via Ollama or Azure OpenAI)
- Credit-based purchase system
- JWT authentication

## Quick Start

```bash
# 1. Start database
docker-compose up -d postgres redis

# 2. Run backend services
source venv/bin/activate

# Terminal 1 - API Gateway (port 8000)
cd platform/backend/services/api_gateway
DATABASE_URL="postgresql://betterbooks:betterbooks@localhost:5432/betterbooks" \
JWT_SECRET_KEY="dev-secret" \
PYTHONPATH="$PWD/../../../.." \
python -m uvicorn main:app --port 8000

# Terminal 2 - LLM Gateway (port 8002)
cd platform/backend/services/llm_gateway
USE_OLLAMA=true OLLAMA_URL="http://localhost:11434" OLLAMA_MODEL=tinyllama \
PYTHONPATH="$PWD/../../../.." \
python -m uvicorn main:app --port 8002

# 3. Open web app
cd platform/frontend/simple_web
python -m http.server 3000
# Then visit http://localhost:3000
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Web Browser   │────▶│   API Gateway   │────▶ PostgreSQL
│   (port 3000)   │     │   (port 8000)   │
└─────────────────┘     └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │   LLM Gateway   │────▶ Ollama/Azure
                        │   (port 8002)   │
                        └─────────────────┘
```

## Project Structure

```
BetterBooks/
├── core/                    # Shared Python modules
│   ├── auth/               # JWT authentication
│   ├── database/           # PostgreSQL models
│   └── infrastructure/     # Logging, caching
├── platform/
│   ├── backend/services/
│   │   ├── api_gateway/    # Main API
│   │   └── llm_gateway/    # AI chat
│   └── frontend/simple_web # Web app
├── book_files/             # Audio & covers
└── docker-compose.yml
```

## Stack

- **Backend**: Python 3.13, FastAPI, PostgreSQL
- **Frontend**: Vanilla HTML/CSS/JS
- **AI**: Ollama (local) or Azure OpenAI
