# EchoWright TestFlight Deployment Guide

## Prerequisites

### Apple Developer Account Setup
- [ ] Active Apple Developer Program membership
- [ ] Access to App Store Connect
- [ ] Bundle ID `com.betterbooks.app` registered
- [ ] Provisioning profiles configured

### Backend Requirements
- [ ] Production backend running at `http://34.111.209.241:8000`
- [ ] All microservices (API Gateway, LLM Gateway, TTS, Context Service) operational
- [ ] Database with book content populated
- [ ] API endpoints returning valid responses

## Pre-Deployment Configuration

### 1. Update Team ID
```bash
# Edit ios/ExportOptions.plist
# Replace: REPLACE_WITH_YOUR_APPLE_TEAM_ID
# With: Your actual Apple Developer Team ID (10-character alphanumeric)
```

### 2. Verify Code Signing
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner project → Signing & Capabilities
- Ensure correct Team and Bundle Identifier
- Verify provisioning profile is valid

### 3. Backend Verification
```bash
# Test API connectivity
curl -X GET http://34.111.209.241:8000/health
# Should return: {"status": "healthy"}
```

## Build Process

### Automated Build (Recommended)
```bash
# Run the automated build script
./scripts/build_testflight.sh
```

### Manual Build Steps
```bash
# Clean and prepare
flutter clean
flutter pub get
cd ios && pod install --repo-update && cd ..

# Build for TestFlight
flutter build ios --release \
  --build-name=1.0.0 \
  --build-number=2 \
  --dart-define=API_BASE_URL="http://34.111.209.241:8000" \
  --no-codesign

# Create Xcode archive
cd ios
xcodebuild -workspace Runner.xcworkspace \
           -scheme Runner \
           -configuration Release \
           -destination 'generic/platform=iOS' \
           -archivePath build/Runner.xcarchive \
           archive
```

## Upload to TestFlight

### Option 1: Xcode UI (Easiest)
1. Open Xcode
2. Window → Organizer
3. Select the `Runner` archive
4. Click "Distribute App"
5. Choose "App Store Connect"
6. Select "Upload"
7. Follow the prompts

### Option 2: Command Line
```bash
xcodebuild -exportArchive \
           -archivePath ios/build/Runner.xcarchive \
           -exportPath ios/build/export \
           -exportOptionsPlist ios/ExportOptions.plist \
           -allowProvisioningUpdates
```

## App Store Connect Configuration

### 1. App Information
- **App Name**: EchoWright
- **Bundle ID**: com.betterbooks.app
- **Category**: Books
- **Subcategory**: Reference

### 2. TestFlight Setup
1. Navigate to TestFlight tab in App Store Connect
2. Add Internal Testing group (if desired)
3. Configure External Testing:
   - Add test group name
   - Add testers via email or link
   - Provide test information

### 3. Required Information
- **What to Test**: "AI-powered audiobook companion with interactive personas"
- **App Description**: Use description from pubspec.yaml
- **Keywords**: audiobook, AI, companion, reading, books

## Testing Notes for Testers

```
Welcome to EchoWright TestFlight Beta!

EchoWright is an AI-powered audiobook companion that lets you interact with books through AI personas.

Key Features to Test:
✅ User authentication (Google/Apple Sign In)
✅ Book library browsing
✅ Audio playback controls
✅ AI persona chat interactions
✅ Voice mode for questions
✅ User profile management

Known Limitations:
⚠️ Demo content - not full production library
⚠️ AI responses may vary based on book context
⚠️ Voice features require microphone permission

Please report bugs via TestFlight feedback or email.
```

## Build Configuration Details

- **Version**: 1.0.0 (Build 2)
- **API Endpoint**: http://34.111.209.241:8000
- **Bundle ID**: com.betterbooks.app
- **Target iOS**: 12.0+
- **Architecture**: arm64, arm64e
- **Configuration**: Release

## Troubleshooting

### Build Failures
```bash
# If pod install fails
cd ios
pod deintegrate
pod install

# If archive fails due to signing
# Open Xcode and resolve signing issues manually
open ios/Runner.xcworkspace
```

### Upload Issues
- Verify Team ID matches Apple Developer account
- Check bundle ID is registered in App Store Connect
- Ensure app version/build number hasn't been used
- Verify all required metadata is complete

### Backend Connectivity
- Test API endpoint accessibility from iOS device/simulator
- Check firewall settings on Google Cloud instance
- Verify CORS headers if needed for web requests

## Post-Upload Checklist

- [ ] Upload successful in App Store Connect
- [ ] Build appears in TestFlight → iOS Builds
- [ ] All required compliance information provided
- [ ] Internal testing group configured (optional)
- [ ] External testing group ready for submission
- [ ] Test notes provided for beta testers
- [ ] Distribution method selected
- [ ] Beta review submitted (for external testing)

## Support Contacts

- **Technical Issues**: Check backend logs at Google Cloud Console
- **TestFlight Problems**: Apple Developer Support
- **App Store Connect**: App Store Connect Help

---

🚀 **Ready for TestFlight deployment!**