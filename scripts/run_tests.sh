#!/usr/bin/env bash
set -euo pipefail

# Install lightweight dependencies required for the tests
pip install -r services/api_gateway/requirements.txt \
            -r services/context_service/requirements.txt \
            -r services/llm_gateway/requirements.txt \
            pgvector pytest

pytest -q
