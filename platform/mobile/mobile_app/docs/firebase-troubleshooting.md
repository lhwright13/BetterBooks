# Firebase Troubleshooting Guide

## Overview
This comprehensive troubleshooting guide covers common Firebase issues in Flutter iOS development, their solutions, and preventive measures.

---

## Quick Diagnostics Checklist

Before diving into specific issues, run through this checklist:

- [ ] GoogleService-Info.plist is in ios/Runner directory
- [ ] Bundle ID matches Firebase Console configuration
- [ ] Firebase SDK versions are compatible
- [ ] Pods are up to date (`pod install --repo-update`)
- [ ] Xcode project includes GoogleService-Info.plist
- [ ] FirebaseApp.configure() is called in AppDelegate
- [ ] Running on physical device (for some features)
- [ ] Using correct Firebase project (dev/staging/prod)

---

## Common Issues and Solutions

### 1. Configuration Issues

#### Issue: "Could not locate configuration file: 'GoogleService-Info.plist'"
**Error Message:**
```
[FirebaseCore][I-COR000012] Could not locate configuration file: 'GoogleService-Info.plist'.
```

**Solutions:**
1. Verify file location:
   ```bash
   ls -la ios/Runner/GoogleService-Info.plist
   ```

2. Add to Xcode project:
   - Open ios/Runner.xcworkspace
   - Right-click Runner folder → Add Files
   - Select GoogleService-Info.plist
   - Ensure "Copy items if needed" is checked

3. Check target membership:
   - Select GoogleService-Info.plist in Xcode
   - File inspector → Target Membership → ✅ Runner

4. Clean and rebuild:
   ```bash
   cd ios
   rm -rf ~/Library/Developer/Xcode/DerivedData
   flutter clean
   flutter pub get
   pod install
   flutter run
   ```

#### Issue: "The default Firebase app has not yet been configured"
**Error Message:**
```
The default Firebase app has not yet been configured. Add FirebaseApp.configure() to your application initialization.
```

**Solutions:**
1. Update AppDelegate.swift:
   ```swift
   import Firebase
   
   override func application(
     _ application: UIApplication,
     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
   ) -> Bool {
     FirebaseApp.configure()  // Add this line BEFORE GeneratedPluginRegistrant
     GeneratedPluginRegistrant.register(with: self)
     return super.application(application, didFinishLaunchingWithOptions: launchOptions)
   }
   ```

2. Ensure Firebase is initialized in Dart:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     runApp(MyApp());
   }
   ```

---

### 2. Build & Compilation Issues

#### Issue: "Module 'Firebase' not found"
**Solutions:**
1. Update Podfile minimum iOS version:
   ```ruby
   platform :ios, '12.0'
   ```

2. Reinstall pods:
   ```bash
   cd ios
   pod deintegrate
   pod cache clean --all
   rm -rf Pods Podfile.lock
   pod install --repo-update
   ```

3. Open .xcworkspace, not .xcodeproj:
   ```bash
   open ios/Runner.xcworkspace
   ```

#### Issue: "Undefined symbols for architecture arm64"
**Solutions:**
1. Add to Podfile post_install:
   ```ruby
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       target.build_configurations.each do |config|
         config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
       end
     end
   end
   ```

2. Set Build Settings:
   - Build Settings → Architectures → Build Active Architecture Only → Debug: Yes

#### Issue: "The sandbox is not in sync with the Podfile.lock"
**Solutions:**
```bash
cd ios
pod install
# If that doesn't work:
pod update
# If still failing:
rm -rf Pods Podfile.lock
pod install
```

---

### 3. Authentication Issues

#### Issue: "Sign in with Apple not working"
**Solutions:**
1. Enable capability in Xcode:
   - Signing & Capabilities → + → Sign in with Apple

2. Add to Info.plist:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.betterbooks.app</string>
       </array>
     </dict>
   </array>
   ```

3. Configure in Firebase Console:
   - Authentication → Sign-in method → Apple → Enable
   - Add Service ID and configure

#### Issue: "Google Sign-In: Error -4"
**Solutions:**
1. Add REVERSED_CLIENT_ID to URL schemes:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR-REVERSED-CLIENT-ID</string>
       </array>
     </dict>
   </array>
   ```

2. Verify bundle ID matches:
   - Xcode bundle ID == Firebase Console bundle ID

---

### 4. Push Notification Issues

#### Issue: "Push notifications not received"
**Diagnostic Steps:**
1. Check token retrieval:
   ```dart
   String? token = await FirebaseMessaging.instance.getToken();
   print('FCM Token: $token');
   ```

2. Verify APNs setup:
   - Firebase Console → Project Settings → Cloud Messaging
   - Check APNs Authentication Key is uploaded

3. Test with Firebase Console:
   - Cloud Messaging → Compose notification → Test on device

**Solutions:**
1. Request permission:
   ```dart
   final settings = await FirebaseMessaging.instance.requestPermission(
     alert: true,
     badge: true,
     sound: true,
   );
   ```

2. Handle background messages:
   ```dart
   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
   
   Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
     await Firebase.initializeApp();
     print('Background message: ${message.messageId}');
   }
   ```

3. Enable capabilities:
   - Push Notifications capability
   - Background Modes → Remote notifications

#### Issue: "Invalid APNs credentials"
**Solutions:**
1. Regenerate APNs key:
   - Apple Developer → Keys → Create new key
   - Enable Apple Push Notifications service

2. Upload to Firebase:
   - Use .p8 file (recommended over certificates)
   - Enter correct Key ID and Team ID

---

### 5. Crashlytics Issues

#### Issue: "Crashes not appearing in console"
**Solutions:**
1. Force a test crash:
   ```dart
   FirebaseCrashlytics.instance.crash();
   ```

2. Run without debugger:
   - Stop debugging in Xcode
   - Launch app from device home screen
   - Trigger crash
   - Relaunch app to upload reports

3. Check dSYM upload:
   ```bash
   # Add to Build Phases
   "${PODS_ROOT}/FirebaseCrashlytics/run"
   ```

4. Enable collection:
   ```dart
   await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
   ```

---

### 6. Firestore Issues

#### Issue: "Permission denied" errors
**Solutions:**
1. Check security rules:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

2. Verify authentication:
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   if (user == null) {
     print('User not authenticated');
   }
   ```

#### Issue: "Firestore offline persistence errors"
**Solutions:**
1. Enable offline persistence:
   ```dart
   FirebaseFirestore.instance.settings = const Settings(
     persistenceEnabled: true,
     cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
   );
   ```

2. Handle offline scenarios:
   ```dart
   try {
     await document.get(const GetOptions(source: Source.cache));
   } catch (e) {
     // Fallback to server
     await document.get(const GetOptions(source: Source.server));
   }
   ```

---

### 7. Performance Issues

#### Issue: "App size too large"
**Solutions:**
1. Use specific Firebase products:
   ```yaml
   # Instead of firebase: ^x.x.x
   firebase_core: ^3.8.0
   firebase_auth: ^5.3.3  # Only what you need
   ```

2. Enable ProGuard/R8 (Android):
   ```gradle
   minifyEnabled true
   shrinkResources true
   ```

3. Strip debug symbols (iOS):
   - Build Settings → Strip Debug Symbols → Release: Yes

#### Issue: "Slow Firebase initialization"
**Solutions:**
1. Lazy load services:
   ```dart
   class FirebaseService {
     static FirebaseAuth? _auth;
     static FirebaseAuth get auth {
       _auth ??= FirebaseAuth.instance;
       return _auth!;
     }
   }
   ```

2. Initialize in background:
   ```dart
   Future<void> initializeFirebase() async {
     await Future.wait([
       Firebase.initializeApp(),
       // Other initialization
     ]);
   }
   ```

---

## Platform-Specific Issues

### iOS Simulator Limitations
These features don't work on iOS Simulator:
- Push notifications (requires physical device)
- Sign in with Apple (limited functionality)
- Phone authentication
- App Check with DeviceCheck

**Solution:** Use physical device for testing these features

### M1 Mac Issues
**Issue:** "Building for iOS Simulator, but linking in dylib built for iOS"

**Solutions:**
1. Exclude arm64 for simulator:
   ```ruby
   # Podfile
   post_install do |installer|
     installer.pods_project.build_configurations.each do |config|
       config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
     end
   end
   ```

2. Run with Rosetta:
   - Finder → Applications → Xcode → Get Info → Open using Rosetta

---

## Debug Commands

### Useful Commands for Troubleshooting

```bash
# Clean everything
flutter clean
cd ios
rm -rf Pods Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData
pod cache clean --all
pod install --repo-update
cd ..
flutter pub get
flutter run

# Check Firebase configuration
flutter doctor -v

# Verify pod installation
cd ios
pod outdated
pod update

# Check for duplicate symbols
nm -gU ios/Pods/Firebase*/Frameworks/*.framework/*.framework/* | grep duplicate

# Test Firebase connection
flutter run --verbose | grep Firebase
```

---

## Prevention Best Practices

### 1. Version Management
```yaml
# pubspec.yaml - Pin versions
firebase_core: 3.8.0  # Not ^3.8.0
firebase_auth: 5.3.3
```

### 2. Environment Separation
```dart
class FirebaseConfig {
  static FirebaseOptions get currentPlatform {
    if (kDebugMode) {
      return FirebaseOptions(/* dev config */);
    } else {
      return FirebaseOptions(/* prod config */);
    }
  }
}
```

### 3. Error Handling
```dart
try {
  await Firebase.initializeApp();
} catch (e) {
  print('Firebase initialization error: $e');
  // Fallback behavior
}
```

### 4. Monitoring Setup
```dart
// Log all Firebase errors
FirebaseCrashlytics.instance.recordFlutterFatalError;
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
```

---

## Getting Help

### Resources
1. **Firebase Status:** https://status.firebase.google.com/
2. **FlutterFire GitHub:** https://github.com/firebase/flutterfire/issues
3. **Stack Overflow:** Tag with `firebase` and `flutter`
4. **Firebase Support:** https://firebase.google.com/support

### Information to Provide When Seeking Help
- Flutter version: `flutter --version`
- Firebase packages versions: `flutter pub deps`
- iOS version and device
- Complete error message and stack trace
- Minimal reproducible example
- GoogleService-Info.plist (redact sensitive data)

### Debug Logging
Enable verbose logging:
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  sslEnabled: true,
  timestampsInSnapshotsEnabled: true,
);

// For auth
FirebaseAuth.instance.setLanguageCode('en');
```

---

## Emergency Fixes

### Nuclear Option - Complete Reset
If nothing else works:
```bash
# Backup your work
git stash

# Remove everything
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData
flutter clean

# Rebuild iOS folder
rm -rf ios
flutter create --platform ios .

# Re-add Firebase configuration
# Copy back GoogleService-Info.plist
# Update AppDelegate.swift
# Re-add to Xcode project

# Reinstall
flutter pub get
cd ios
pod install
flutter run
```

---

## Conclusion

Most Firebase issues stem from:
1. **Configuration mismatches** - Bundle ID, environment
2. **Missing files** - GoogleService-Info.plist
3. **Outdated dependencies** - Pods, Flutter packages
4. **Platform limitations** - Simulator vs device

Always check the basics first before diving into complex solutions. When in doubt, clean everything and rebuild.