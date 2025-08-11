#!/usr/bin/env bash
# Run the Python unit tests in a clean environment.

# Exit on errors and fail on unset variables.
set -euo pipefail

# Install only the dependencies required for the tests (lighter than the full
# runtime set because the TTS service is mocked).
pip install -r platform/backend/services/api_gateway/requirements.txt \
            -r platform/backend/services/context_service/requirements.txt \
            -r platform/backend/services/llm_gateway/requirements.txt \
            pgvector pytest

# Execute pytest in quiet mode
pytest -q
