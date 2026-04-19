# BetterBooks

An AI-augmented audiobook platform. Listen to classic books and hold a conversation about the story with chapter-aware, persona-based AI characters - in text or real-time voice.

## Features

- Audiobook library with chapter navigation and progress tracking
- Text chat with book-aware AI personas (Ahab, Gatsby, Nick, Alice, ...) that know only what you have heard
- Real-time voice chat over WebSockets (Azure Speech STT + streaming Azure OpenAI + Azure TTS)
- Credit-based purchase flow and per-user library
- JWT authentication, password hashing, rate limiting
- Runs fully local against Ollama, or against Azure OpenAI for production voice
- Web client (single-page app) and a SwiftUI iOS client

## Architecture

```
 Web / iOS client
        |
        v
   API Gateway  ---> PostgreSQL (users, books, progress, chat logs)
   (port 8000)       Redis      (sessions, rate limits)
        |
        v
   LLM Gateway  ---> Ollama (local) or Azure OpenAI
   (port 8002)
        |
        v
   Voice service (WebSocket /ws/voice)
        |
        v
   Azure Speech STT / TTS   (optional, for voice mode)
```

## Quick Start

Requires Python 3.11+, Docker, and `ollama` (if you want the local AI path).

```bash
# 1. Clone and set up the virtualenv
git clone https://github.com/lhwright13/BetterBooks.git
cd BetterBooks
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 2. Create a local .env from the template
cp .env.example .env

# 3. Start Postgres and Redis
docker-compose up -d postgres redis

# 4. Pull a small local model (first run only)
ollama pull llama3.2

# 5. One-command dev launcher (API gateway, LLM gateway, web server)
bash scripts/demo.sh

# Visit http://localhost:3000
# Demo account: demo@betterbooks.app / demo1234
```

To seed the bookstore with the six demo titles:

```bash
python scripts/seed_demo.py
```

## Running the services by hand

```bash
export PYTHONPATH="$PWD"
export DATABASE_URL="postgresql://betterbooks:betterbooks@localhost:5432/betterbooks"
export JWT_SECRET_KEY="dev-secret"

# API Gateway
python -m uvicorn platform.backend.services.api_gateway.main:app --port 8000 &

# LLM Gateway (local Ollama)
USE_OLLAMA=true OLLAMA_URL=http://localhost:11434 OLLAMA_MODEL=llama3.2 \
  python -m uvicorn platform.backend.services.llm_gateway.main:app --port 8002 &

# Web server
python -m http.server 3000 --directory platform/frontend/simple_web
```

For Azure OpenAI instead of Ollama, set `USE_OLLAMA=false` and provide `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT_NAME`. Voice chat also needs `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION`.

## Project layout

```
BetterBooks/
  core/
    auth/                  JWT, password hashing, rate limiting
    database/              PostgreSQL schema and data access
    infrastructure/        Logging, metrics, caching helpers
  platform/
    backend/services/
      api_gateway/         Auth, bookstore, library, progress, voice WS
      llm_gateway/         Ollama / Azure OpenAI adapter
    frontend/simple_web/   Single-page web client
    mobile/ios_app/        SwiftUI iOS client
  tests/unit/              Pytest suite (151 tests)
  scripts/                 demo.sh launcher and seed_demo.py
  docs/                    Design notes and architecture
  book_files/              Audio and cover assets (gitignored)
  docker-compose.yml
```

## API surface

**Auth**: `POST /auth/signup`, `POST /auth/signin`

**Bookstore**: `GET /bookstore/browse`, `GET /bookstore/categories`, `GET /bookstore/user/credits`, `GET /bookstore/user/library`, `POST /bookstore/purchase`

**Player state**: `GET/POST /progress/{book_id}`, bookmarks, wishlist

**AI chat**: `POST /complete` (LLM Gateway), `GET /ai/personas/{book_id}`

**Voice (real-time)**: `WS /ws/voice` (bi-directional streaming), `GET /voice/config`, `POST /voice/transcribe`, `POST /voice/synthesize`

## Testing

```bash
source venv/bin/activate
python -m pytest tests/unit/ -v
```

151 tests covering auth, context engine, personas, DB utilities, and the voice service.

## Stack

- Python 3.11+, FastAPI, Uvicorn, WebSockets
- PostgreSQL, Redis
- Ollama (local) or Azure OpenAI
- Azure Speech (STT / streaming TTS)
- SwiftUI (iOS), vanilla HTML / CSS / JS (web)

## License

MIT. See [LICENSE](LICENSE).
