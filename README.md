# BetterBooks

Monorepo for the BetterBooks audiobook platform. This repository contains the
mobile application and all backend microservices.

## Structure

- `mobile_app/` – Flutter application.
- `services/` – Backend services.
  - `api_gateway/` – Public REST API.
  - `context_service/` – Manages book context and embeddings.
  - `llm_gateway/` – Abstraction layer over the chosen language model.
  - `tts_service/` – Generates audio snippets.
- `proto/` – gRPC/Protobuf definitions.
- `infra/` – Terraform and Helm deployment configurations.

Each service is a small FastAPI application packaged with a Dockerfile and
currently exposes only a simple `/health` endpoint.

## Running the stack locally

This repository includes a `docker-compose.yml` file for spinning up all
services along with a Postgres database. Docker and Docker Compose must be
installed.

1. Export your Gemini API key so it can be passed into the language model
   service and then start the stack:

   ```bash
   export GEMINI_API_KEY=your-key
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

  Open <http://localhost:8080> in your browser to view the simple demo page.

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

