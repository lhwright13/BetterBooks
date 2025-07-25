#!/usr/bin/env bash
set -euo pipefail

# Install Python dependencies for all services and test utilities
pip install -r services/api_gateway/requirements.txt \
            -r services/context_service/requirements.txt \
            -r services/llm_gateway/requirements.txt \
            -r services/tts_service/requirements.txt \
            pgvector pytest
