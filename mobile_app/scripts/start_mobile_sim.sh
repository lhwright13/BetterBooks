#!/bin/bash

# Start Mobile Simulator Script for BetterBooks
# This script starts the iOS simulator and runs the Flutter app

set -e

echo "🚀 Starting BetterBooks Mobile Simulator..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Check if we're in the mobile app directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Not in Flutter project directory. Please run from mobile_app/"
    exit 1
fi

# Boot iPhone 16 simulator
echo "📱 Booting iPhone 16 simulator..."
xcrun simctl boot "iPhone 16" 2>/dev/null || true

# Open Simulator app
echo "📱 Opening iOS Simulator..."
open -a Simulator

# Wait for simulator to be ready
echo "⏳ Waiting for simulator to boot..."
sleep 5

# Check if simulator is ready
while ! xcrun simctl list devices | grep "iPhone 16" | grep -q "Booted"; do
    echo "⏳ Still waiting for simulator..."
    sleep 2
done

echo "✅ iPhone 16 simulator is ready!"

# Install Flutter dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Start Flutter app
echo "🎯 Starting Flutter app on iOS simulator..."
echo ""
echo "🎮 Flutter Commands:"
echo "  r  - Hot reload"
echo "  R  - Hot restart" 
echo "  q  - Quit app"
echo ""

flutter run -d iPhone