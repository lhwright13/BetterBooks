#!/usr/bin/env bash
# Helper script to start the entire stack using Docker Compose.

# Exit immediately on errors and propagate errors through pipes.
set -euo pipefail

# Build images if necessary and then launch the services in the foreground.
docker-compose up --build
