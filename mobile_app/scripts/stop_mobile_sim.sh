#!/bin/bash

# Stop Mobile Simulator Script for BetterBooks
# This script stops the Flutter app and iOS simulator

set -e

echo "🛑 Stopping BetterBooks Mobile Simulator..."

# Kill Flutter processes
echo "📱 Stopping Flutter app..."
pkill -f "flutter run" 2>/dev/null || true
pkill -f "dart.*flutter" 2>/dev/null || true

# Wait a moment for graceful shutdown
sleep 2

# Shutdown iPhone 16 simulator
echo "📱 Shutting down iPhone 16 simulator..."
xcrun simctl shutdown "iPhone 16" 2>/dev/null || true

# Close Simulator app
echo "📱 Closing iOS Simulator app..."
osascript -e 'tell application "Simulator" to quit' 2>/dev/null || true

# Kill any remaining simulator processes
pkill -f "Simulator" 2>/dev/null || true

echo "✅ Mobile simulator stopped successfully!"
echo ""
echo "💡 To restart, run: ./scripts/start_mobile_sim.sh"