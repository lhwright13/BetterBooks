#!/bin/bash

# Muuchi TestFlight Build Script

echo "🍎 Building Muuchi for TestFlight..."

# Navigate to mobile app directory
cd mobile_app

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build for iOS release
echo "📱 Building iOS release..."
flutter build ipa --release --dart-define=API_BASE_URL=https://api.muuchi.app

echo "✅ Build complete!"
echo ""
echo "📂 IPA Location: build/ios/ipa/muuchi.ipa"
echo ""
echo "Next steps:"
echo "1. Open Xcode Organizer (Window > Organizer)"
echo "2. Select Archives tab"
echo "3. Find your app and click 'Distribute App'"
echo "4. Choose 'App Store Connect'"
echo "5. Upload for TestFlight"
echo ""
echo "Or use Transporter app to upload the IPA directly"