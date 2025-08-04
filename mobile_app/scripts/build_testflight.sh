#!/bin/bash

# BetterBooks TestFlight Build Script
# This script builds the iOS app for TestFlight distribution

set -e

echo "🚀 Building BetterBooks for TestFlight..."

# Navigate to the mobile app directory
cd "$(dirname "$0")/.."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build iOS release version
echo "📱 Building iOS release version..."
flutter build ios --release --no-codesign

# Create archive using xcodebuild
echo "📦 Creating Xcode archive..."
cd ios
xcodebuild -workspace Runner.xcworkspace \
           -scheme Runner \
           -configuration Release \
           -destination 'generic/platform=iOS' \
           -archivePath build/Runner.xcarchive \
           archive

echo "✅ Archive created successfully!"

# Instructions for manual upload
echo ""
echo "📋 Next steps for TestFlight deployment:"
echo "1. Open Xcode"
echo "2. Go to Window > Organizer"
echo "3. Select 'Runner' and click 'Distribute App'"
echo "4. Choose 'App Store Connect' > 'Upload'"
echo "5. Follow the prompts to upload to TestFlight"

echo ""
echo "Alternatively, use Xcode's command line tools:"
echo "xcodebuild -exportArchive \\"
echo "           -archivePath build/Runner.xcarchive \\"
echo "           -exportPath build/export \\"
echo "           -exportOptionsPlist ExportOptions.plist"

echo ""
echo "📱 App built with:"
echo "   Bundle ID: com.betterbooks.app"
echo "   Version: 1.0.0+1"
echo "   API Endpoint: http://34.111.209.241"