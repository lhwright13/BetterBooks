# Firebase Setup Guide for EchoWright iOS App

## Overview
This guide provides comprehensive instructions for setting up Firebase in the EchoWright Flutter iOS application. Firebase provides authentication, analytics, crash reporting, and other backend services.

## Prerequisites
- Firebase account (create at https://console.firebase.google.com)
- Xcode installed (version 14.0 or later)
- Flutter SDK (3.0.0 or later)
- CocoaPods installed
- Apple Developer account (for push notifications and App Check)

## Step 1: Firebase Console Setup

### 1.1 Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Create a project" or select existing project
3. Name your project: `echowright-prod` (for production)
4. Enable Google Analytics (recommended)
5. Select or create Google Analytics account

### 1.2 Add iOS App
1. In Firebase Console, click "Add app" → iOS icon
2. Enter iOS bundle ID: `com.betterbooks.app`
3. Enter app nickname: `EchoWright iOS`
4. Enter App Store ID (when available)
5. Download `GoogleService-Info.plist`

### 1.3 Enable Firebase Services
Navigate to each service in Firebase Console and enable:
- **Authentication** → Enable Email/Password, Google, Apple Sign-In
- **Firestore Database** → Create database in production mode
- **Storage** → Set up default bucket
- **Crashlytics** → Enable crash reporting
- **Analytics** → Already enabled
- **Cloud Messaging** → For push notifications
- **Remote Config** → For feature flags
- **App Check** → For API protection

## Step 2: iOS Project Configuration

### 2.1 Add GoogleService-Info.plist
```bash
# Place the downloaded file in the iOS Runner directory
cp ~/Downloads/GoogleService-Info.plist ios/Runner/

# Open Xcode
open ios/Runner.xcworkspace
```

In Xcode:
1. Right-click on Runner folder
2. Select "Add Files to Runner"
3. Select GoogleService-Info.plist
4. Ensure "Copy items if needed" is checked
5. Ensure "Runner" target is selected

### 2.2 Update Info.plist
Add Firebase URL schemes to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with REVERSED_CLIENT_ID from GoogleService-Info.plist -->
            <string>com.googleusercontent.apps.YOUR-REVERSED-CLIENT-ID</string>
        </array>
    </dict>
</array>

<!-- For Firebase Dynamic Links (optional) -->
<key>FirebaseDynamicLinksCustomDomains</key>
<array>
    <string>https://echowright.page.link</string>
</array>
```

### 2.3 Update AppDelegate.swift
The AppDelegate has been updated to initialize Firebase on app launch.

### 2.4 iOS Capabilities
In Xcode, select Runner target → Signing & Capabilities:

1. **Push Notifications**: 
   - Click "+ Capability"
   - Add "Push Notifications"

2. **Background Modes** (if needed):
   - Add "Background Modes"
   - Check "Remote notifications"
   - Check "Background fetch"

3. **Associated Domains** (for Dynamic Links):
   - Add "Associated Domains"
   - Add: `applinks:echowright.page.link`

## Step 3: Flutter Dependencies

### 3.1 Update pubspec.yaml
Dependencies have been added to pubspec.yaml for all Firebase services.

### 3.2 Install Dependencies
```bash
flutter pub get
cd ios && pod install --repo-update
```

## Step 4: Firebase Initialization

### 4.1 Main.dart Initialization
Firebase is initialized in main.dart before running the app.

### 4.2 Platform-Specific Configuration
iOS-specific Firebase configuration is handled automatically through the GoogleService-Info.plist file.

## Step 5: Environment Configuration

### 5.1 Development vs Production
Create separate Firebase projects for different environments:

```
echowright-dev    → Development/Testing
echowright-staging → Staging/QA
echowright-prod   → Production
```

### 5.2 Build Configurations
In Xcode, manage different GoogleService-Info.plist files:

1. Create folders:
   ```
   ios/Runner/Firebase/Dev/GoogleService-Info.plist
   ios/Runner/Firebase/Staging/GoogleService-Info.plist
   ios/Runner/Firebase/Prod/GoogleService-Info.plist
   ```

2. Add build phase script to copy correct file based on configuration

## Step 6: Testing Firebase Integration

### 6.1 Verify Connection
```dart
// Test Firebase connection
if (Firebase.apps.isNotEmpty) {
  print('Firebase is connected');
  print('Project ID: ${Firebase.app().options.projectId}');
}
```

### 6.2 Test Each Service

#### Analytics
```dart
await FirebaseAnalytics.instance.logEvent(
  name: 'test_event',
  parameters: {'test_param': 'test_value'},
);
```

#### Crashlytics
```dart
// Force a test crash
FirebaseCrashlytics.instance.crash();
```

#### Authentication
```dart
// Test anonymous auth
final userCredential = await FirebaseAuth.instance.signInAnonymously();
print('Signed in: ${userCredential.user?.uid}');
```

## Step 7: App Store Submission

### 7.1 Privacy Requirements
Update Info.plist with usage descriptions:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>This app collects data to improve your experience and show relevant content.</string>
```

### 7.2 Export Compliance
Add to Info.plist:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

## Step 8: Monitoring & Maintenance

### 8.1 Firebase Console Monitoring
- Check Crashlytics for crash reports
- Monitor Analytics for user engagement
- Review Performance metrics
- Check Authentication usage

### 8.2 Error Monitoring
Set up alerting for:
- Crash rate > 1%
- Failed authentication attempts
- API quota limits
- Billing alerts

## Troubleshooting

### Common Issues

1. **"No GoogleService-Info.plist found"**
   - Ensure file is added to Xcode project
   - Check target membership
   - Clean build folder: Cmd+Shift+K

2. **"Could not locate configuration file"**
   - Verify file is in ios/Runner/ directory
   - Check file is included in "Copy Bundle Resources"

3. **Authentication not working**
   - Verify URL schemes in Info.plist
   - Check bundle ID matches Firebase Console
   - Ensure capabilities are enabled

4. **Crashes not appearing in Crashlytics**
   - Run app without debugger attached
   - Wait 5 minutes for upload
   - Check dSYM upload

## Security Best Practices

1. **Never commit GoogleService-Info.plist to public repos**
   - Add to .gitignore if needed
   - Use environment-specific files

2. **Enable App Check**
   - Protects backend resources
   - Prevents API abuse

3. **Implement Security Rules**
   - Firestore security rules
   - Storage security rules
   - Proper authentication checks

## Support & Resources

- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Status](https://status.firebase.google.com/)
- [Firebase Support](https://firebase.google.com/support)

## Next Steps

1. Review [Firebase Dependencies Documentation](./firebase-dependencies.md)
2. Check [Firebase Cost Estimation](./firebase-costs.md)
3. Read [iOS-Specific Configuration](./firebase-ios-config.md)
4. See [Troubleshooting Guide](./firebase-troubleshooting.md)