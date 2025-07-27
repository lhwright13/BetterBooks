#!/usr/bin/env bash
# Install dependencies required to run the services and unit tests.

# Exit immediately if a command exits with a non-zero status, treat unset
# variables as an error and propagate errors through pipes.
set -euo pipefail

# Install Python dependencies for all services and test utilities in a single
# invocation of pip to avoid duplicate work.
pip install -r services/api_gateway/requirements.txt \
            -r services/context_service/requirements.txt \
            -r services/llm_gateway/requirements.txt \
            -r services/tts_service/requirements.txt \
            pgvector pytest
