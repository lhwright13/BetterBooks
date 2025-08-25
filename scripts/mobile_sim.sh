#!/bin/bash

# Mobile Simulator Control Script for EchoWright
# Usage: ./scripts/mobile_sim.sh [start|stop|restart|build]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MOBILE_APP_DIR="$PROJECT_ROOT/platform/mobile/mobile_app"

# Check if mobile app directory exists
if [ ! -d "$MOBILE_APP_DIR" ]; then
    echo "❌ Mobile app directory not found: $MOBILE_APP_DIR"
    exit 1
fi

# Function to start simulator
start_sim() {
    echo "🚀 Starting EchoWright Mobile Simulator..."
    cd "$MOBILE_APP_DIR"
    
    # Check if start script exists
    if [ ! -f "scripts/start_mobile_sim.sh" ]; then
        echo "❌ Mobile start script not found"
        echo "💡 Try running: flutter run -d iPhone"
        exit 1
    fi
    
    ./scripts/start_mobile_sim.sh
}

# Function to stop simulator
stop_sim() {
    echo "🛑 Stopping EchoWright Mobile Simulator..."
    cd "$MOBILE_APP_DIR"
    
    # Check if stop script exists
    if [ ! -f "scripts/stop_mobile_sim.sh" ]; then
        echo "⚠️  Stop script not found, using basic cleanup..."
        pkill -f "flutter run" 2>/dev/null || true
        xcrun simctl shutdown "iPhone 16" 2>/dev/null || true
        return
    fi
    
    ./scripts/stop_mobile_sim.sh
}

# Function to restart simulator
restart_sim() {
    echo "🔄 Restarting EchoWright Mobile Simulator..."
    stop_sim
    sleep 3
    start_sim
}

# Function to build for TestFlight
build_testflight() {
    echo "📱 Building EchoWright for TestFlight..."
    cd "$MOBILE_APP_DIR"
    
    # Check if build script exists
    if [ ! -f "scripts/build_testflight.sh" ]; then
        echo "❌ TestFlight build script not found"
        echo "💡 Try running: flutter build ios --release"
        exit 1
    fi
    
    ./scripts/build_testflight.sh
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
    "build")
        build_testflight
        ;;
    *)
        echo "Usage: $0 [start|stop|restart|build]"
        echo ""
        echo "Commands:"
        echo "  start   - Start iOS simulator and Flutter app (default)"
        echo "  stop    - Stop Flutter app and iOS simulator"
        echo "  restart - Stop and start the simulator"
        echo "  build   - Build iOS app for TestFlight distribution"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 stop"
        echo "  $0 restart"
        echo "  $0 build"
        echo ""
        echo "Direct Flutter commands:"
        echo "  cd platform/mobile/mobile_app && flutter run"
        echo "  cd platform/mobile/mobile_app && flutter build ios"
        exit 1
        ;;
esac