#!/bin/bash

# EchoWright TestFlight Build Script
# This script builds the iOS app for TestFlight distribution

set -e

echo "🚀 Building EchoWright for TestFlight..."

# Navigate to the mobile app directory
cd "$(dirname "$0")/.."

# Set production API endpoint - DIRECT AZURE CLOUD ACCESS
PRODUCTION_API="http://128.203.92.141:8000"
echo "🌐 Using production API: $PRODUCTION_API (Direct Azure Cloud - Updated IP)"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Install iOS dependencies
echo "📦 Installing iOS dependencies..."
cd ios && pod install --repo-update && cd ..

# Build iOS release version with production API
echo "📱 Building iOS release version for TestFlight..."
flutter build ios --release \
  --build-name=1.0.0 \
  --build-number=4 \
  --dart-define=API_BASE_URL="$PRODUCTION_API" \
  --no-codesign

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
echo "✅ TestFlight build ready!"
echo ""
echo "📱 App Configuration:"
echo "   App Name: EchoWright"
echo "   Bundle ID: com.betterbooks.app"
echo "   Version: 1.0.0 (Build 4)"
echo "   API Endpoint: $PRODUCTION_API"
echo "   Configuration: Release"
echo ""
echo "🔐 Before uploading to TestFlight:"
echo "1. Replace REPLACE_WITH_YOUR_APPLE_TEAM_ID in ios/ExportOptions.plist"
echo "2. Ensure your Apple Developer account has access to com.betterbooks.app"
echo "3. Configure code signing in Xcode"
echo "4. Verify backend is running at $PRODUCTION_API"
echo ""
echo "📋 Upload Instructions:"
echo "Option 1: Via Xcode UI"
echo "  1. Open Xcode > Window > Organizer"
echo "  2. Select 'Runner' archive and click 'Distribute App'"
echo "  3. Choose 'App Store Connect' > 'Upload'"
echo ""
echo "Option 2: Via Command Line (after updating ExportOptions.plist)"
echo "  xcodebuild -exportArchive \\"
echo "             -archivePath ios/build/Runner.xcarchive \\"
echo "             -exportPath ios/build/export \\"
echo "             -exportOptionsPlist ios/ExportOptions.plist"