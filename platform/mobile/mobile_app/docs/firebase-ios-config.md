# Firebase iOS-Specific Configuration Guide

## Overview
This document covers iOS-specific Firebase configuration requirements, Xcode settings, capabilities, and platform-specific implementation details for the EchoWright app.

---

## iOS Platform Requirements

### Minimum Requirements
- **iOS Deployment Target:** 12.0 or higher
- **Xcode Version:** 14.0 or higher
- **Swift Version:** 5.0 or higher
- **CocoaPods:** 1.12.0 or higher

### Recommended Setup
- **iOS Target:** 14.0 (for App Clips and App Tracking Transparency)
- **Xcode:** Latest stable version
- **macOS:** Monterey or later

---

## Xcode Project Configuration

### 1. Bundle Identifier
```
Product Bundle Identifier: com.betterbooks.app
```

Ensure consistency across:
- Xcode project settings
- Firebase Console
- Apple Developer Portal
- App Store Connect

### 2. GoogleService-Info.plist Setup

#### Adding to Xcode Project
1. Open `ios/Runner.xcworkspace` in Xcode
2. Right-click on `Runner` folder
3. Select "Add Files to 'Runner'"
4. Choose `GoogleService-Info.plist`
5. Ensure settings:
   - ✅ Copy items if needed
   - ✅ Create folder references
   - ✅ Add to targets: Runner

#### Build Phases Configuration
Add Run Script phase for environment-specific configs:

```bash
# Build Phase Script for Multiple Environments
# Name: "Firebase Configuration"
# Location: After "Copy Bundle Resources"

# Script:
if [ "${CONFIGURATION}" == "Debug" ]; then
    cp "${PROJECT_DIR}/Runner/Firebase/Dev/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
elif [ "${CONFIGURATION}" == "Release" ]; then
    cp "${PROJECT_DIR}/Runner/Firebase/Prod/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
fi
```

---

## Info.plist Configuration

### 1. Firebase URL Schemes
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Google Sign-In -->
            <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
            <!-- Firebase Dynamic Links -->
            <string>com.betterbooks.app</string>
        </array>
    </dict>
</array>
```

### 2. App Transport Security
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <!-- Firebase Storage -->
        <key>firebasestorage.googleapis.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### 3. Privacy Permissions
```xml
<!-- Push Notifications -->
<key>NSUserNotificationUsageDescription</key>
<string>Enable notifications to receive updates about your audiobooks and new releases.</string>

<!-- Microphone (for voice features) -->
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for voice commands and AI chat.</string>

<!-- Photo Library (for profile images) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Allow access to choose a profile picture from your photo library.</string>

<!-- Camera (optional) -->
<key>NSCameraUsageDescription</key>
<string>Allow access to take a profile picture.</string>

<!-- App Tracking Transparency -->
<key>NSUserTrackingUsageDescription</key>
<string>This app collects data to provide personalized recommendations and improve your experience.</string>

<!-- Background Audio -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

---

## iOS Capabilities Configuration

### Required Capabilities

#### 1. Push Notifications
**Location:** Signing & Capabilities → + Capability → Push Notifications

**Purpose:** Firebase Cloud Messaging
**Setup:**
1. Enable in Xcode
2. Create APNs Key in Apple Developer Portal
3. Upload to Firebase Console

#### 2. Background Modes
**Location:** Signing & Capabilities → + Capability → Background Modes

**Enable:**
- ✅ Audio, AirPlay, and Picture in Picture
- ✅ Background fetch
- ✅ Remote notifications

#### 3. Associated Domains (for Dynamic Links)
**Location:** Signing & Capabilities → + Capability → Associated Domains

**Add:**
```
applinks:echowright.page.link
applinks:echowright.app.link
```

#### 4. Sign in with Apple
**Location:** Signing & Capabilities → + Capability → Sign in with Apple

**Purpose:** Apple Sign-In authentication

#### 5. Keychain Sharing (Optional)
**Location:** Signing & Capabilities → + Capability → Keychain Sharing

**Keychain Groups:**
```
$(AppIdentifierPrefix)com.betterbooks.app
```

---

## AppDelegate.swift Configuration

### Complete AppDelegate Implementation
```swift
import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Set up push notifications
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        application.registerForRemoteNotifications()
        
        // Set Firebase Messaging delegate
        Messaging.messaging().delegate = self
        
        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Push Notification Handling
    
    override func application(_ application: UIApplication, 
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Send token to Flutter
        let tokenDict = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: tokenDict
        )
    }
}
```

---

## Build Settings

### 1. Other Linker Flags
**Target:** Runner → Build Settings → Other Linker Flags
```
-ObjC
$(inherited)
```

### 2. Enable Bitcode
**Target:** Runner → Build Settings → Enable Bitcode
```
NO (Firebase doesn't support bitcode)
```

### 3. Swift Language Version
**Target:** Runner → Build Settings → Swift Language Version
```
Swift 5
```

---

## CocoaPods Configuration

### Podfile Customization
```ruby
platform :ios, '12.0'

# Add to the top of Podfile
$FirebaseSDKVersion = '10.25.0'  # Pin Firebase version

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Firebase specific settings
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      
      # Disable arm64 for simulator builds (M1 Macs)
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

### Pod Installation
```bash
cd ios
pod deintegrate
pod cache clean --all
pod install --repo-update
```

---

## APNs Configuration for Push Notifications

### 1. Create APNs Key
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles
3. Keys → Create a new key
4. Enable "Apple Push Notifications service (APNs)"
5. Download the .p8 file

### 2. Upload to Firebase
1. Firebase Console → Project Settings → Cloud Messaging
2. iOS app configuration → APNs Authentication Key
3. Upload .p8 file
4. Enter Key ID and Team ID

### 3. Testing Push Notifications
```swift
// Test notification payload
{
  "aps": {
    "alert": {
      "title": "Test Notification",
      "body": "This is a test Firebase notification"
    },
    "badge": 1,
    "sound": "default"
  },
  "custom_data": {
    "type": "test"
  }
}
```

---

## Troubleshooting iOS-Specific Issues

### Common Problems and Solutions

#### 1. "No valid 'aps-environment' entitlement string found"
**Solution:** Regenerate provisioning profiles with Push Notification capability

#### 2. "Missing Push Notification Entitlement"
**Solution:** 
- Ensure Push Notifications capability is enabled
- Check provisioning profile includes push entitlement

#### 3. "Could not build module 'Firebase'"
**Solution:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod cache clean --all
pod install --repo-update
```

#### 4. "The default Firebase app has not been configured"
**Solution:** Ensure FirebaseApp.configure() is called before any Firebase usage

#### 5. Simulator vs Device Issues
- Push notifications don't work on simulator
- Use physical device for testing:
  - Push notifications
  - Sign in with Apple
  - App Check with DeviceCheck

---

## Performance Optimization

### 1. Reduce App Size
```ruby
# Podfile optimization
pod 'Firebase/Analytics'
pod 'Firebase/Crashlytics'
pod 'Firebase/Auth'
# Only include what you need
```

### 2. Lazy Loading
```swift
// Lazy load Firebase services
class FirebaseManager {
    static let shared = FirebaseManager()
    
    private lazy var analytics = Analytics.self
    private lazy var crashlytics = Crashlytics.crashlytics()
    
    private init() {
        // Initialize only when needed
    }
}
```

### 3. Debug vs Release
```swift
#if DEBUG
    // Disable Crashlytics in debug
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
#else
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
#endif
```

---

## App Store Submission Checklist

### Firebase-Related Requirements
- [ ] Remove all debug code and logging
- [ ] Ensure GoogleService-Info.plist uses production config
- [ ] Test with production Firebase project
- [ ] Verify push notifications work with production certificates
- [ ] Check crash-free rate in Crashlytics (should be >99%)
- [ ] Implement App Tracking Transparency properly
- [ ] Add all privacy usage descriptions
- [ ] Test on multiple iOS versions (12.0+)
- [ ] Verify no Firebase API keys are hardcoded
- [ ] Enable App Check for production

### Privacy & Security
- [ ] Implement proper data deletion for GDPR
- [ ] Add privacy policy URL in App Store Connect
- [ ] Document data collection in App Privacy details
- [ ] Implement user consent for analytics
- [ ] Enable SSL pinning for sensitive APIs

---

## Maintenance & Updates

### Regular Tasks
1. **Monthly:** Update Firebase SDK versions
2. **Quarterly:** Review security rules
3. **Before Major iOS Release:** Test with iOS beta
4. **Annually:** Renew APNs certificates/keys

### Monitoring
- Set up Crashlytics alerts for crash rate > 1%
- Monitor app startup time in Performance Monitoring
- Track user engagement in Analytics
- Review push notification delivery rates

---

## Additional Resources

- [Firebase iOS Setup Guide](https://firebase.google.com/docs/ios/setup)
- [FlutterFire iOS Documentation](https://firebase.flutter.dev/docs/installation/ios)
- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)
- [App Tracking Transparency](https://developer.apple.com/documentation/apptrackingtransparency)
- [iOS App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)