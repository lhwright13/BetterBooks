#!/usr/bin/env bash
#
# run_app.sh - Start the complete EchoWright audiobook companion platform
#
# This script provides a convenient way to launch the entire EchoWright backend
# infrastructure for local development. It handles Docker Compose orchestration
# and ensures all microservices are built and started correctly.
#
# Usage:
#   ./scripts/run_app.sh
#
# Prerequisites:
#   - Docker and Docker Compose installed
#   - GEMINI_API_KEY environment variable set
#   - Docker daemon running
#
# What it does:
#   1. Navigates to repository root directory
#   2. Builds all service Docker images (if needed)
#   3. Starts all services via docker-compose up
#   4. Runs in foreground with live log output
#
# Services started:
#   - PostgreSQL database with pgvector extension
#   - API Gateway (port 8000) - Central API entry point
#   - Context Service (port 8001) - Vector embeddings and search
#   - LLM Gateway (port 8002) - AI persona management
#   - TTS Service (port 8004) - Text-to-speech synthesis  
#   - Transcription Service (port 8003) - Audio transcription
#   - Web Demo App (port 8080) - HTML/JS demo interface
#
# Development notes:
#   - Press Ctrl+C to stop all services
#   - Book files should be placed in ./book_files/ directory
#   - LLM persona configs in ./llm_configs/ directory
#   - Service logs are color-coded by service name
#   - Database data persists between runs in Docker volume

# Exit immediately on errors and propagate errors through pipes
set -euo pipefail

# Determine the repository root and switch to it so docker-compose
# can locate the docker-compose.yml file even if the script was
# executed from another directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "Starting EchoWright audiobook companion platform..."
echo "Repository root: $(pwd)"
echo "Services will be available at:"
echo "  - API Gateway: http://localhost:8000"
echo "  - Web Demo: http://localhost:8080"
echo "  - PostgreSQL: localhost:5432"
echo ""

# Build images if necessary and then launch the services in the foreground
docker-compose up --build
