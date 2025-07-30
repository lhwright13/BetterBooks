# BetterBooks iOS Deployment Guide

This guide covers deploying the BetterBooks Flutter app to iOS devices and the App Store.

## Prerequisites

1. **Apple Developer Account** ($99/year) - Required for App Store distribution
2. **Xcode** - Latest version installed
3. **Flutter** - Properly configured for iOS development
4. **macOS** - Required for iOS development

## 1. Project Configuration ✅

The following has been configured for you:

- **Bundle Identifier**: `com.betterbooks.app`
- **App Name**: BetterBooks
- **App Icons**: Complete icon set in all required sizes
- **Permissions**: Microphone, Speech Recognition, Network access
- **Background Audio**: Configured for audiobook playback
- **Export Compliance**: ITSAppUsesNonExemptEncryption = false

## 2. Code Signing Setup

### Option A: Automatic Signing (Recommended)
1. Open `Runner.xcworkspace` in Xcode
2. Select the **Runner** project → **Runner** target
3. Go to **Signing & Capabilities**
4. Check **Automatically manage signing**
5. Select your **Team** (Apple Developer Account)
6. Xcode will automatically create certificates and provisioning profiles

### Option B: Manual Signing
1. Create certificates in [Apple Developer Console](https://developer.apple.com)
2. Create App ID with bundle identifier: `com.betterbooks.app`
3. Create provisioning profiles for development and distribution
4. Download and install certificates/profiles
5. Configure in Xcode under Signing & Capabilities

## 3. Build for Release

### Using the Provided Script
```bash
cd /Users/lhwri/BetterBooks
chmod +x deployment/testflight-build.sh
./deployment/testflight-build.sh
```

### Manual Build Commands
```bash
cd mobile_app/

# Clean previous builds
flutter clean
flutter pub get

# Build for iOS release with production API
flutter build ipa --release --dart-define=API_BASE_URL=https://api.betterbooks.app

# Or build with custom API endpoint
flutter build ipa --release --dart-define=API_BASE_URL=https://your-domain.com
```

## 4. TestFlight Distribution

### Upload via Xcode
1. Build succeeded → Open `build/ios/archive/Runner.xcarchive`
2. Xcode Organizer opens automatically
3. Click **Distribute App**
4. Choose **App Store Connect**
5. Follow the upload wizard

### Upload via Transporter
1. Download [Transporter](https://apps.apple.com/app/transporter/id1450874784) from Mac App Store
2. Drag `build/ios/ipa/betterbooks.ipa` into Transporter
3. Click **Deliver**

### Upload via Command Line
```bash
# Install if needed
brew install altool

# Upload IPA
xcrun altool --upload-app --type ios -f build/ios/ipa/betterbooks.ipa --username your@email.com --password your-app-specific-password
```

## 5. App Store Connect Configuration

### Required Information
- **App Name**: BetterBooks
- **Category**: Books or Entertainment
- **Age Rating**: 4+ (No mature content)
- **Description**: 
  ```
  Experience audiobooks like never before with BetterBooks - your AI-powered reading companion.
  
  ✨ Features:
  • Interactive AI personas that bring stories to life
  • Chat with characters like Nick Carraway from The Great Gatsby
  • Ask questions about plot, themes, and literary analysis
  • Voice interaction for hands-free learning
  • High-quality audiobook streaming
  
  Transform your reading experience with intelligent conversations about literature.
  ```

### Screenshots Required
- **iPhone**: 6.7", 6.5", 5.5" display sizes
- **iPad**: 12.9", 11" display sizes
- Show key features: book library, AI chat, audio player

### Privacy Information
- **Data Collection**: User interactions for AI responses
- **Permissions Used**: Microphone (voice input), Speech Recognition

## 6. TestFlight Setup

1. **App Store Connect** → Your App → **TestFlight**
2. Click the build that was uploaded
3. Add **What to Test** notes:
   ```
   Welcome to BetterBooks TestFlight!
   
   Test Features:
   • Browse The Great Gatsby audiobook
   • Chat with Nick Carraway persona
   • Try voice input for questions
   • Test background audio playback
   
   Known Issues:
   • iOS speech recognition is placeholder (web feature)
   • Voice synthesis uses system TTS
   
   Feedback: Please report any crashes or UI issues
   ```

4. **Add Testers**:
   - Internal: Your team members
   - External: Up to 10,000 beta testers

## 7. Production API Setup

Before release, ensure your backend is deployed:

### Backend Requirements
- **API Gateway**: Accessible at production URL
- **SSL Certificate**: HTTPS required for App Store
- **Rate Limiting**: Prevent abuse
- **API Keys**: Secure Gemini API key storage
- **Monitoring**: Error tracking and analytics

### Update API Configuration
The app is configured to use environment variables:
```dart
// Production API
flutter build ipa --dart-define=API_BASE_URL=https://api.betterbooks.app

// Staging API  
flutter build ipa --dart-define=API_BASE_URL=https://staging.betterbooks.app
```

## 8. Release Checklist

### Pre-Release
- [ ] All features tested on physical iOS device
- [ ] App icons and launch screen verified
- [ ] Backend API deployed and accessible
- [ ] Privacy policy and terms of service ready
- [ ] App Store screenshots captured
- [ ] TestFlight beta testing completed

### Release Day
- [ ] Final build uploaded via TestFlight
- [ ] App metadata submitted for review
- [ ] Release notes prepared
- [ ] Marketing materials ready
- [ ] Support documentation updated

## 9. Common Issues & Solutions

### Code Signing Errors
```bash
# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset keychain
security delete-keychain ios-build.keychain
```

### Build Failures
```bash
# Clean everything
flutter clean
cd ios && rm Podfile.lock && rm -rf Pods/
cd .. && flutter pub get
cd ios && pod install --repo-update
```

### Archive Upload Issues
- Check bundle identifier matches App Store Connect
- Verify all required icons are present
- Ensure Info.plist values are correct

## 10. Maintenance

### Regular Updates
- Update Flutter SDK and dependencies
- Monitor crash reports in App Store Connect
- Respond to user reviews within 24-48 hours
- Release bug fixes promptly

### Analytics
Track key metrics:
- Daily/Monthly active users
- Session length (audiobook listening time)
- AI chat interactions
- User retention rates

---

## Quick Commands Reference

```bash
# Development build for simulator
flutter run -d "iPhone 16 Pro"

# Release build for device testing
flutter build ios --release

# Create IPA for distribution
flutter build ipa --release --dart-define=API_BASE_URL=https://api.betterbooks.app

# Check code signing
security find-identity -v -p codesigning

# View certificates
security find-certificate -a -p
```

This guide covers the complete iOS deployment process for BetterBooks. The app is now configured and ready for distribution through TestFlight and the App Store.