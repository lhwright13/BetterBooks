# BetterBooks Mobile App - TestFlight Deployment Guide

This guide covers deploying the BetterBooks iOS app to TestFlight for beta testing.

## App Configuration

### Current Settings
- **App Name**: BetterBooks
- **Bundle ID**: `com.betterbooks.app`
- **Version**: 1.0.0+1
- **API Endpoint**: `http://34.111.209.241` (Production GKE cluster)

### Features
- AI-powered audiobook companion
- Interactive chat with book personas
- Text-to-speech synthesis
- Contextual book discussions
- Audio playback with voice control

## Prerequisites

### Apple Developer Account Setup
1. **Apple Developer Account**: Ensure you have an active Apple Developer Program membership
2. **App Store Connect**: Access to App Store Connect with appropriate permissions
3. **Code Signing**: Valid iOS Distribution certificate and provisioning profile
4. **Team ID**: Your Apple Developer Team ID (update in `ios/ExportOptions.plist`)

### Development Environment
- macOS with Xcode 15+
- Flutter SDK (current: >=3.1.0)
- CocoaPods installed
- Valid iOS device or simulator for testing

## Build Process

### Quick Build (Automated)
```bash
./scripts/build_testflight.sh
```

### Manual Build Steps

1. **Clean and Setup**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Build iOS Release**
   ```bash
   flutter build ios --release --no-codesign
   ```

3. **Create Xcode Archive**
   ```bash
   cd ios
   xcodebuild -workspace Runner.xcworkspace \
              -scheme Runner \
              -configuration Release \
              -destination 'generic/platform=iOS' \
              -archivePath build/Runner.xcarchive \
              archive
   ```

## TestFlight Upload

### Method 1: Xcode Organizer (Recommended)
1. Open Xcode
2. Go to **Window > Organizer**
3. Select **Runner** from archives
4. Click **Distribute App**
5. Choose **App Store Connect** > **Upload**
6. Follow prompts to upload to TestFlight

### Method 2: Command Line Export
```bash
xcodebuild -exportArchive \
           -archivePath build/Runner.xcarchive \
           -exportPath build/export \
           -exportOptionsPlist ExportOptions.plist
```

### Method 3: Xcode Cloud (Future)
Configure Xcode Cloud for automated builds and TestFlight uploads.

## App Store Connect Configuration

### App Information
- **Name**: BetterBooks
- **Subtitle**: AI Audiobook Companion
- **Category**: Books
- **Content Rating**: 4+ (suitable for all ages)

### Required Assets
- App Icon (1024x1024)
- Screenshots (iPhone 6.7", 6.5", 5.5")
- Privacy Policy URL
- Support URL

### TestFlight Settings
1. **Test Information**
   - What to Test: "Core app functionality, AI chat, audio playback"
   - Test Notes: Include API endpoint and known limitations

2. **Internal Testing**
   - Add internal testers (Apple Developer team members)
   - Test core functionality before external beta

3. **External Testing**
   - Create external test groups
   - Add beta review information
   - Monitor crash reports and feedback

## Backend Dependencies

### Production API (Required)
- **Endpoint**: `http://34.111.209.241`
- **Services**: API Gateway, LLM Gateway, TTS Service, Context Service
- **Status**: Backend deployed but API Gateway timeout issues exist

### API Gateway Endpoints
- `/health` - Service health check ✅
- `/books/list` - Book catalog ✅ (empty, no books uploaded)
- `/complete` - AI chat completion ⚠️ (timeout issues)
- `/tts` - Text-to-speech synthesis ⚠️ (timeout issues)
- `/configs` - Available personas ⚠️ (empty, config mounting issues)

## Known Issues & Limitations

### Backend Issues
1. **API Gateway Timeouts**: Direct service access works, but API Gateway has timeout issues
2. **Empty Book Catalog**: No audiobooks uploaded to production yet
3. **Missing Configurations**: LLM persona configs not properly mounted

### Mobile App Limitations
1. **Network Errors**: Will show connection errors due to backend issues
2. **Limited Testing**: Requires manual testing of core features
3. **Audio Permissions**: iOS simulator limitations for microphone testing

## Testing Strategy

### Pre-TestFlight Testing
1. **iOS Simulator**: Basic UI and navigation
2. **Physical Device**: Full audio and microphone functionality
3. **Network Testing**: API connectivity and error handling
4. **Performance**: Memory usage and battery impact

### TestFlight Beta Testing
1. **Internal Team**: Core functionality validation
2. **Limited External**: 5-10 beta testers
3. **Expanded Beta**: Up to 100 external testers
4. **Feedback Collection**: Regular surveys and analytics

## Deployment Checklist

### Pre-Build
- [ ] API endpoint configured correctly
- [ ] Bundle ID matches App Store Connect
- [ ] Version number incremented
- [ ] Code signing certificates valid
- [ ] Privacy permissions documented

### Build & Upload
- [ ] Flutter build successful
- [ ] Xcode archive created without errors
- [ ] Upload to App Store Connect completed
- [ ] TestFlight processing successful

### Post-Upload
- [ ] Internal testing completed
- [ ] External beta group configured
- [ ] Test notes and instructions provided
- [ ] Crash reporting configured
- [ ] Analytics tracking enabled

## Troubleshooting

### Common Build Issues
1. **Code Signing**: Verify certificates and provisioning profiles
2. **Dependencies**: Run `flutter clean && flutter pub get`
3. **Xcode Version**: Ensure Xcode is up to date
4. **Simulator Issues**: Test on physical device when possible

### Upload Failures
1. **Bundle ID Mismatch**: Verify App Store Connect configuration
2. **Invalid Archive**: Check Xcode organizer for errors
3. **Missing Metadata**: Ensure Info.plist is complete
4. **Review Guidelines**: Check for policy violations

## Support & Monitoring

### Crash Reporting
- Xcode Organizer crash logs
- TestFlight feedback reports
- iOS Analytics (future)

### Performance Monitoring
- App Store Connect analytics
- TestFlight beta metrics
- User feedback surveys

### Backend Monitoring
- Google Cloud monitoring
- Kubernetes pod health
- API response times

## Next Steps

1. **Fix Backend Issues**: Resolve API Gateway timeout problems
2. **Upload Content**: Add audiobook files to production
3. **Configure Personas**: Mount LLM configuration files properly
4. **TestFlight Launch**: Begin internal testing
5. **Beta Expansion**: Gradual rollout to external testers
6. **App Store Submission**: Prepare for public release

---

**Built with Flutter 🚀 | Powered by Google Cloud ☁️ | Enhanced by AI 🤖**