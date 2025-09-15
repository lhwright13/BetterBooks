# EchoWright Release Guide

## Overview
This document outlines the release process for the EchoWright mobile application.

## Version Information
- **Current Version**: 2.0.0+1
- **Bundle ID (iOS)**: com.betterbooks.app
- **Package Name (Android)**: com.echowright.app

## Build Configuration

### iOS Release Build
```bash
# Build for release (unsigned)
flutter build ios --release --no-codesign

# Build for release (with signing)
flutter build ios --release

# Build for TestFlight
flutter build ios --release --export-method=app-store
```

### Android Release Build
```bash
# Build APK
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

## Environment Configuration

The app uses environment-based configuration files:
- `.env.development` - Development environment
- `.env.staging` - Staging environment  
- `.env.production` - Production environment

### Production Configuration
The production environment points to:
- **API Base URL**: http://128.203.92.141:8000
- **Features Enabled**: Voice Chat, Offline Mode, Push Notifications
- **Security**: Certificate Pinning, Code Obfuscation

## Code Quality Checklist

### Pre-Release Checklist
- [x] Remove all debug code and print statements
- [x] Replace debug logging with production-ready LoggingService
- [x] Configure release build settings (minify, obfuscation)
- [x] Fix all critical build errors
- [ ] Remove TODO/FIXME/HACK comments
- [ ] Fix remaining code analysis warnings
- [ ] Test complete app flow on physical devices

### Performance Optimization
- [x] Enable code shrinking (minifyEnabled)
- [x] Enable resource shrinking (shrinkResources)
- [x] Configure ProGuard rules for Android
- [ ] Optimize bundle size (tree shaking, lazy loading)
- [ ] Implement image optimization

## Release Process

### 1. Version Bump
Update version in `pubspec.yaml`:
```yaml
version: 2.0.0+1  # version: major.minor.patch+buildNumber
```

### 2. Build Release Artifacts

#### iOS
1. Ensure signing certificates are configured in Xcode
2. Build the release IPA:
   ```bash
   flutter build ios --release
   ```
3. Archive in Xcode and upload to App Store Connect

#### Android
1. Generate signing key (first time only):
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Configure signing in `android/key.properties`
3. Build the release bundle:
   ```bash
   flutter build appbundle --release
   ```

### 3. Testing
- [ ] Test on physical iOS device
- [ ] Test on physical Android device
- [ ] Verify all critical features work
- [ ] Check performance and memory usage
- [ ] Validate crash reporting

### 4. App Store Submission

#### iOS App Store
1. Upload build via Xcode or Transporter
2. Complete app information in App Store Connect
3. Submit for review

#### Google Play Store
1. Upload AAB file to Play Console
2. Complete store listing
3. Submit for review

## Monitoring & Analytics

### Crash Reporting
- Firebase Crashlytics integration pending
- Sentry DSN to be configured

### Analytics
- Firebase Analytics integration pending
- Custom events to track user engagement

## Security Considerations

### Production Security Features
- [x] API communication over HTTPS (when configured)
- [x] Certificate pinning enabled (configuration pending)
- [x] Code obfuscation enabled for release builds
- [ ] Secure storage for sensitive data
- [ ] Biometric authentication support

## Support & Maintenance

### Post-Release Monitoring
1. Monitor crash reports daily
2. Track user reviews and ratings
3. Respond to critical issues within 24 hours
4. Plan regular maintenance updates

### Update Strategy
- **Hotfixes**: For critical bugs (x.x.1)
- **Minor Updates**: For features and improvements (x.1.0)
- **Major Updates**: For significant changes (2.0.0)

## Contact
For release-related questions, contact the development team.

---
*Last Updated: September 10, 2025*