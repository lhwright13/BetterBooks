#!/usr/bin/env bash
#
# BetterBooks Demo Launcher
#
# Starts all services needed for a full BetterBooks demo with a single command.
# Usage:
#   scripts/demo.sh          - Start the demo
#   scripts/demo.sh stop     - Stop all demo services
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve project root (script lives in scripts/)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_FILE="$PROJECT_ROOT/.demo.pids"
LOG_DIR="$PROJECT_ROOT/.demo-logs"

# ---------------------------------------------------------------------------
# Color helpers (no emojis)
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
ok()      { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
err()     { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

# ---------------------------------------------------------------------------
# Stop mode
# ---------------------------------------------------------------------------
stop_demo() {
    info "Stopping BetterBooks demo services..."

    if [[ -f "$PID_FILE" ]]; then
        while IFS= read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null && ok "Stopped process $pid" || warn "Could not stop process $pid"
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    else
        warn "No PID file found at $PID_FILE"
    fi

    info "Stopping Docker containers (postgres, redis)..."
    cd "$PROJECT_ROOT"
    docker-compose down 2>/dev/null || docker compose down 2>/dev/null || warn "Could not stop Docker containers"

    ok "Demo stopped."
    exit 0
}

if [[ "${1:-}" == "stop" ]]; then
    stop_demo
fi

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
check_prerequisites() {
    local missing=0

    info "Checking prerequisites..."

    if ! command -v docker &>/dev/null; then
        err "docker is not installed. Install Docker Desktop: https://www.docker.com/products/docker-desktop/"
        missing=1
    fi

    if ! (docker-compose version &>/dev/null || docker compose version &>/dev/null); then
        err "docker-compose is not available. Install Docker Compose or upgrade Docker Desktop."
        missing=1
    fi

    if ! command -v python3 &>/dev/null; then
        err "python3 is not installed."
        missing=1
    fi

    if ! command -v ollama &>/dev/null; then
        err "ollama is not installed. Install from: https://ollama.ai"
        missing=1
    fi

    if [[ $missing -ne 0 ]]; then
        err "Missing prerequisites. Please install the above and try again."
        exit 1
    fi

    ok "All prerequisites found."
}

# ---------------------------------------------------------------------------
# Check for virtual environment
# ---------------------------------------------------------------------------
check_venv() {
    if [[ ! -d "$PROJECT_ROOT/venv" ]]; then
        err "Python virtual environment not found at $PROJECT_ROOT/venv"
        err "Create one with: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
        exit 1
    fi
    ok "Virtual environment found."
}

# ---------------------------------------------------------------------------
# Start infrastructure (Postgres + Redis)
# ---------------------------------------------------------------------------
start_infrastructure() {
    info "Starting PostgreSQL and Redis..."
    cd "$PROJECT_ROOT"

    if docker-compose version &>/dev/null; then
        docker-compose up -d postgres redis
    else
        docker compose up -d postgres redis
    fi

    info "Waiting for PostgreSQL to be healthy (up to 30 seconds)..."
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if docker-compose exec -T postgres pg_isready -U betterbooks &>/dev/null 2>&1 \
           || docker compose exec -T postgres pg_isready -U betterbooks &>/dev/null 2>&1; then
            ok "PostgreSQL is ready."
            return 0
        fi
        retries=$((retries - 1))
        sleep 1
    done

    err "PostgreSQL did not become healthy within 30 seconds."
    exit 1
}

# ---------------------------------------------------------------------------
# Run database seed
# ---------------------------------------------------------------------------
seed_database() {
    info "Seeding demo data..."
    cd "$PROJECT_ROOT"
    source "$PROJECT_ROOT/venv/bin/activate"
    python scripts/seed_demo.py
    ok "Database seeded."
}

# ---------------------------------------------------------------------------
# Check / start Ollama
# ---------------------------------------------------------------------------
setup_ollama() {
    info "Checking Ollama..."

    if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
        warn "Ollama is not running."
        warn "Please start Ollama in a separate terminal (run 'ollama serve') and re-run this script."
        exit 1
    fi

    ok "Ollama is running."

    # Check if the model is already pulled
    if ! curl -s http://localhost:11434/api/tags | grep -q "llama3.2"; then
        info "Pulling llama3.2 model (this may take a while on first run)..."
        ollama pull llama3.2
        ok "Model llama3.2 pulled."
    else
        ok "Model llama3.2 is available."
    fi
}

# ---------------------------------------------------------------------------
# Start backend services in background
# ---------------------------------------------------------------------------
start_services() {
    info "Starting backend services..."
    mkdir -p "$LOG_DIR"

    # Clear old PID file
    rm -f "$PID_FILE"

    # Activate venv for all python processes
    local venv_activate="source $PROJECT_ROOT/venv/bin/activate"

    # LLM Gateway (port 8002)
    info "Starting LLM Gateway on port 8002..."
    (
        cd "$PROJECT_ROOT/platform/backend/services/llm_gateway"
        source "$PROJECT_ROOT/venv/bin/activate"
        USE_OLLAMA=true \
        OLLAMA_URL=http://localhost:11434 \
        OLLAMA_MODEL=llama3.2 \
        PYTHONPATH="$PROJECT_ROOT" \
        python -m uvicorn main:app --host 0.0.0.0 --port 8002 \
            >"$LOG_DIR/llm_gateway.log" 2>&1
    ) &
    echo $! >> "$PID_FILE"

    # API Gateway (port 8000)
    info "Starting API Gateway on port 8000..."
    (
        cd "$PROJECT_ROOT/platform/backend/services/api_gateway"
        source "$PROJECT_ROOT/venv/bin/activate"
        DATABASE_URL="postgresql://betterbooks:betterbooks@localhost:5432/betterbooks" \
        JWT_SECRET_KEY="dev-secret" \
        PYTHONPATH="$PROJECT_ROOT" \
        python -m uvicorn main:app --host 0.0.0.0 --port 8000 \
            >"$LOG_DIR/api_gateway.log" 2>&1
    ) &
    echo $! >> "$PID_FILE"

    # Web server (port 3000)
    info "Starting web server on port 3000..."
    (
        cd "$PROJECT_ROOT/platform/frontend/simple_web"
        source "$PROJECT_ROOT/venv/bin/activate"
        python -m http.server 3000 \
            >"$LOG_DIR/web_server.log" 2>&1
    ) &
    echo $! >> "$PID_FILE"

    ok "Background services started. Logs are in $LOG_DIR/"
}

# ---------------------------------------------------------------------------
# Wait for health checks
# ---------------------------------------------------------------------------
wait_for_services() {
    info "Waiting for services to be ready..."

    # API Gateway health check
    local retries=20
    while [[ $retries -gt 0 ]]; do
        if curl -sf http://localhost:8000/health &>/dev/null; then
            ok "API Gateway is healthy."
            break
        fi
        retries=$((retries - 1))
        if [[ $retries -eq 0 ]]; then
            err "API Gateway did not start. Check $LOG_DIR/api_gateway.log"
            exit 1
        fi
        sleep 1
    done

    # LLM Gateway health check
    retries=20
    while [[ $retries -gt 0 ]]; do
        if curl -sf http://localhost:8002/health &>/dev/null; then
            ok "LLM Gateway is healthy."
            break
        fi
        retries=$((retries - 1))
        if [[ $retries -eq 0 ]]; then
            err "LLM Gateway did not start. Check $LOG_DIR/llm_gateway.log"
            exit 1
        fi
        sleep 1
    done

    # Web server check (no /health, just check the port)
    retries=10
    while [[ $retries -gt 0 ]]; do
        if curl -sf http://localhost:3000/ &>/dev/null; then
            ok "Web server is healthy."
            break
        fi
        retries=$((retries - 1))
        if [[ $retries -eq 0 ]]; then
            err "Web server did not start. Check $LOG_DIR/web_server.log"
            exit 1
        fi
        sleep 1
    done
}

# ---------------------------------------------------------------------------
# Print ready message
# ---------------------------------------------------------------------------
print_ready() {
    echo ""
    echo "=============================================="
    echo " BetterBooks Demo is Ready"
    echo "=============================================="
    echo ""
    echo " Web App:     http://localhost:3000"
    echo " API Gateway: http://localhost:8000"
    echo " LLM Gateway: http://localhost:8002"
    echo ""
    echo " Login:       demo@betterbooks.app / demo1234"
    echo ""
    echo " To stop:     $SCRIPT_DIR/demo.sh stop"
    echo " Logs:        $LOG_DIR/"
    echo ""
    echo "=============================================="
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo ""
    info "Starting BetterBooks demo..."
    echo ""

    check_prerequisites
    check_venv
    start_infrastructure
    seed_database
    setup_ollama
    start_services
    wait_for_services
    print_ready
}

main
