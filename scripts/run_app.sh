#!/usr/bin/env bash
# Helper script to start the entire stack using Docker Compose.

# Exit immediately on errors and propagate errors through pipes.
set -euo pipefail

# Determine the repository root and switch to it so docker-compose
# can locate the docker-compose.yml file even if the script was
# executed from another directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Build images if necessary and then launch the services in the foreground.
docker-compose up --build
