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

Each service currently provides a simple FastAPI stub with a `/health` endpoint
and a Dockerfile for containerization.

## Running the stack locally

This repository includes a `docker-compose.yml` file for spinning up all
services along with a Postgres database. Docker and Docker Compose must be
installed.

1. From the repository root run:

   ```bash
   docker-compose up --build
   ```

   The command builds the service images (if necessary) and starts the full
   stack.

2. Once running you can access the services on the following ports:

   - **API Gateway:** <http://localhost:8000>
   - **Context Service:** <http://localhost:8001>
   - **LLM Gateway:** <http://localhost:8002>
   - **TTS Service:** <http://localhost:8003>

   Postgres is exposed on port `5432` with the default credentials
   `betterbooks`/`betterbooks` and database name `betterbooks`.

3. Stop the stack with `Ctrl+C` and remove containers with:

   ```bash
   docker-compose down
   ```

