#!/usr/bin/env bash
# Install dependencies required to run the services and unit tests.

# Exit immediately if a command exits with a non-zero status, treat unset
# variables as an error and propagate errors through pipes.
set -euo pipefail

# Install Python dependencies for all services and test utilities in a single
# invocation of pip to avoid duplicate work.
pip install -r platform/backend/services/api_gateway/requirements.txt \
            -r platform/backend/services/context_service/requirements.txt \
            -r platform/backend/services/llm_gateway/requirements.txt \
            -r platform/backend/services/tts_service/requirements.txt \
            -r platform/backend/services/transcription_service/requirements.txt \
            pgvector pytest
