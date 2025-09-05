#!/bin/bash

# EchoWright App Test Suite Runner
# This script runs comprehensive tests to verify all app functionality

echo "🧪 EchoWright App Test Suite"
echo "============================"
echo ""

# Make sure we're in the right directory
cd "$(dirname "$0")"

# Update dependencies
echo "📦 Installing test dependencies..."
flutter pub get

echo ""
echo "🔍 Running Unit Tests..."
echo "Testing core services, authentication, and download logic"
flutter test test/unit/services_test.dart --verbose

echo ""
echo "🎨 Running Widget Tests..." 
echo "Testing purchase flow and UI components"
flutter test test/widget/purchase_flow_test.dart --verbose
flutter test test/widget/navigation_test.dart --verbose

echo ""
echo "🔄 Running Integration Tests..."
echo "Testing complete user flows (requires device/emulator)"
flutter test test/integration/app_flow_test.dart --verbose

echo ""
echo "🎉 Test Suite Complete!"
echo ""
echo "📊 Test Results Summary:"
echo "- Unit tests verify core logic and services"
echo "- Widget tests verify UI components work correctly" 
echo "- Integration tests verify complete user flows"
echo ""
echo "🚀 To run individual test types:"
echo "  flutter test test/unit/         # Unit tests only"
echo "  flutter test test/widget/       # Widget tests only"
echo "  flutter test test/integration/  # Integration tests only"