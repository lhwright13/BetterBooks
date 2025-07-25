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
