# BetterBooks

An audiobook app with AI characters you can talk to while you listen.

You're halfway through Moby Dick and want to ask Ahab why he's so obsessed with the whale. You tap his face and ask. He answers. He only knows what's happened up to the chapter you're on, so he can't spoil anything past that point. You can do this in text or by voice, in real time.

That's the whole idea.

## What's in here

A FastAPI backend (API gateway + LLM gateway), a PostgreSQL schema, a small web client, and a SwiftUI iOS client. The LLM gateway talks to either a local Ollama model or Azure OpenAI. Voice mode streams audio through Azure Speech in both directions over a WebSocket.

Six public-domain books are wired up out of the box: Gatsby, Moby Dick, Alice, War and Peace, the Odyssey, and Pride and Prejudice. Each has a handful of persona definitions (characters, a teacher, a language tutor) that shape the system prompt.

## Running it

You need Python 3.11+, Docker, and optionally Ollama if you want to run the AI locally.

```bash
git clone https://github.com/lhwright13/BetterBooks.git
cd BetterBooks
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env

docker-compose up -d postgres redis
ollama pull llama3.2          # skip if you're using Azure OpenAI
bash scripts/demo.sh
```

Visit `http://localhost:3000`. Log in with `demo@betterbooks.app` / `demo1234`.

To populate the bookstore, run `python scripts/seed_demo.py`.

Audio files are not in the repo (they're either copyrighted or large). LibriVox has public-domain recordings of every seeded title; drop the MP3s into `book_files/<Book>/` and the app will find them.

## Running the services by hand

```bash
export PYTHONPATH="$PWD"
export DATABASE_URL="postgresql://betterbooks:betterbooks@localhost:5432/betterbooks"
export JWT_SECRET_KEY="dev-secret"

python -m uvicorn platform.backend.services.api_gateway.main:app --port 8000 &

USE_OLLAMA=true OLLAMA_URL=http://localhost:11434 OLLAMA_MODEL=llama3.2 \
  python -m uvicorn platform.backend.services.llm_gateway.main:app --port 8002 &

python -m http.server 3000 --directory platform/frontend/simple_web
```

For Azure OpenAI, set `USE_OLLAMA=false` and provide `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT_NAME`. Voice mode also needs `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION`.

## Layout

```
core/
  auth/                 JWT, password hashing, rate limiting
  database/             PostgreSQL schema and data access
  infrastructure/       Logging, metrics, caching helpers
platform/
  backend/services/
    api_gateway/        Auth, bookstore, library, progress, voice WS
    llm_gateway/        Ollama / Azure OpenAI adapter
  frontend/simple_web/  Single-page web client
  mobile/ios_app/       SwiftUI iOS client
tests/unit/             Pytest suite (151 tests)
scripts/                demo.sh launcher and seed_demo.py
book_files/             Persona JSON and transcripts (audio is gitignored)
docker-compose.yml
```

## API

Auth: `POST /auth/signup`, `POST /auth/signin`

Bookstore: `GET /bookstore/browse`, `/bookstore/categories`, `/bookstore/user/credits`, `/bookstore/user/library`, `POST /bookstore/purchase`

Player state: `GET /POST /progress/{book_id}`, plus bookmarks and wishlist

AI chat: `POST /complete` (LLM gateway), `GET /ai/personas/{book_id}`

Voice: `WS /ws/voice` (bi-directional streaming), `GET /voice/config`, `POST /voice/transcribe`, `POST /voice/synthesize`

## Tests

```bash
source venv/bin/activate
python -m pytest tests/unit/ -v
```

151 tests, mostly around auth, the context engine (chapter-aware retrieval and spoiler boundaries), persona loading, DB utilities, and the voice service.

## Stack

Python 3.11+, FastAPI, Uvicorn, WebSockets. PostgreSQL and Redis. Ollama or Azure OpenAI. Azure Speech for STT and streaming TTS. SwiftUI for iOS; plain HTML/CSS/JS for the web client.

## License

MIT. See [LICENSE](LICENSE).
