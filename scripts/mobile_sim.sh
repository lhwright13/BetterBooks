#!/bin/bash

# Mobile Simulator Control Script for EchoWright
# Usage: ./scripts/mobile_sim.sh [start|stop|restart]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MOBILE_APP_DIR="$PROJECT_ROOT/mobile_app"

# Check if mobile app directory exists
if [ ! -d "$MOBILE_APP_DIR" ]; then
    echo "❌ Mobile app directory not found: $MOBILE_APP_DIR"
    exit 1
fi

# Function to start simulator
start_sim() {
    echo "🚀 Starting EchoWright Mobile Simulator..."
    cd "$MOBILE_APP_DIR"
    ./scripts/start_mobile_sim.sh
}

# Function to stop simulator
stop_sim() {
    echo "🛑 Stopping EchoWright Mobile Simulator..."
    cd "$MOBILE_APP_DIR"
    ./scripts/stop_mobile_sim.sh
}

# Function to restart simulator
restart_sim() {
    echo "🔄 Restarting EchoWright Mobile Simulator..."
    stop_sim
    sleep 2
    start_sim
}

# Main script logic
case "${1:-start}" in
    "start")
        start_sim
        ;;
    "stop")
        stop_sim
        ;;
    "restart")
        restart_sim
        ;;
    *)
        echo "Usage: $0 [start|stop|restart]"
        echo ""
        echo "Commands:"
        echo "  start   - Start iOS simulator and Flutter app (default)"
        echo "  stop    - Stop Flutter app and iOS simulator"
        echo "  restart - Stop and start the simulator"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 stop"
        echo "  $0 restart"
        exit 1
        ;;
esac