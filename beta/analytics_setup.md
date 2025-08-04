# BetterBooks Analytics and Crash Reporting Setup

## Analytics Strategy

### Key Metrics to Track

#### User Engagement Metrics
- **Daily/Weekly/Monthly Active Users (DAU/WAU/MAU)**
- **Session Length**: Average time spent per session
- **Session Frequency**: How often users return
- **Feature Usage**: Which features are used most/least
- **Retention Rates**: 1-day, 7-day, 30-day retention
- **Churn Rate**: When and why users stop using the app

#### Product-Specific Metrics
- **AI Interaction Metrics**:
  - Chat sessions initiated
  - Messages per conversation
  - Voice vs text input usage
  - Persona preference distribution
  - Conversation completion rates

- **Audiobook Metrics**:
  - Books started vs completed
  - Chapter completion rates
  - Playback speed preferences
  - Skip/rewind patterns
  - Listening session duration

- **Performance Metrics**:
  - App launch time
  - API response times
  - Crash frequency and types
  - Battery usage impact
  - Memory consumption

#### Beta-Specific Metrics
- **Feedback Metrics**:
  - Survey response rates
  - Bug report frequency
  - Feature request volume
  - Discord engagement levels
  - Email open rates

- **Quality Metrics**:
  - App rating (TestFlight)
  - Net Promoter Score (NPS)
  - User satisfaction scores
  - Recommendation likelihood

## Implementation Plan

### 1. Firebase Analytics (Recommended)

#### Setup Firebase Project
```bash
# 1. Create Firebase project at console.firebase.google.com
# 2. Add iOS app with bundle ID: com.betterbooks.app
# 3. Download GoogleService-Info.plist
# 4. Add to iOS project in Xcode
```

#### Add Firebase Dependencies
Update `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_analytics: ^10.7.4
  firebase_crashlytics: ^3.4.8
  firebase_performance: ^0.9.3+8
```

#### Initialize Firebase in App
Update `lib/main.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp();
  
  // Configure Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = 
      FirebaseAnalyticsObserver(analytics: analytics);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [observer],
      // ... rest of app configuration
    );
  }
}
```

#### Create Analytics Service
Create `lib/services/analytics_service.dart`:
```dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  
  // User Properties
  static Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
    await _crashlytics.setUserIdentifier(userId);
  }
  
  static Future<void> setUserProperties({
    required String iOSVersion,
    required String deviceModel,
    required bool isBetaUser,
    String? preferredPersona,
  }) async {
    await _analytics.setUserProperty(name: 'ios_version', value: iOSVersion);
    await _analytics.setUserProperty(name: 'device_model', value: deviceModel);
    await _analytics.setUserProperty(name: 'is_beta_user', value: isBetaUser.toString());
    if (preferredPersona != null) {
      await _analytics.setUserProperty(name: 'preferred_persona', value: preferredPersona);
    }
  }
  
  // App Lifecycle Events
  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }
  
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
  
  // Book-Related Events
  static Future<void> logBookStarted(String bookId, String bookTitle) async {
    await _analytics.logEvent(
      name: 'book_started',
      parameters: {
        'book_id': bookId,
        'book_title': bookTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
  
  static Future<void> logChapterCompleted(
    String bookId, 
    String chapterId, 
    double completionPercentage
  ) async {
    await _analytics.logEvent(
      name: 'chapter_completed',
      parameters: {
        'book_id': bookId,
        'chapter_id': chapterId,
        'completion_percentage': completionPercentage,
      },
    );
  }
  
  // AI Interaction Events
  static Future<void> logChatSessionStarted(String persona) async {
    await _analytics.logEvent(
      name: 'chat_session_started',
      parameters: {
        'persona': persona,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
  
  static Future<void> logMessageSent({
    required String persona,
    required bool isVoiceInput,
    required int messageLength,
  }) async {
    await _analytics.logEvent(
      name: 'message_sent',
      parameters: {
        'persona': persona,
        'input_type': isVoiceInput ? 'voice' : 'text',
        'message_length': messageLength,
      },
    );
  }
  
  static Future<void> logAIResponseReceived({
    required String persona,
    required int responseTime,
    required bool wasSuccessful,
  }) async {
    await _analytics.logEvent(
      name: 'ai_response_received',
      parameters: {
        'persona': persona,
        'response_time_ms': responseTime,
        'was_successful': wasSuccessful,
      },
    );
  }
  
  // Feature Usage Events
  static Future<void> logFeatureUsed(String featureName) async {
    await _analytics.logEvent(
      name: 'feature_used',
      parameters: {'feature_name': featureName},
    );
  }
  
  static Future<void> logVoiceInputUsed(bool wasSuccessful) async {
    await _analytics.logEvent(
      name: 'voice_input_used',
      parameters: {'was_successful': wasSuccessful},
    );
  }
  
  // Beta-Specific Events
  static Future<void> logFeedbackSubmitted(String feedbackType) async {
    await _analytics.logEvent(
      name: 'feedback_submitted',
      parameters: {'feedback_type': feedbackType},
    );
  }
  
  static Future<void> logBugReported(String bugCategory) async {
    await _analytics.logEvent(
      name: 'bug_reported',
      parameters: {'bug_category': bugCategory},
    );
  }
  
  // Error and Crash Reporting
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      exception,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }
  
  static Future<void> log(String message) async {
    await _crashlytics.log(message);
  }
  
  // Custom Metrics
  static Future<void> logCustomEvent(
    String eventName,
    Map<String, dynamic> parameters,
  ) async {
    await _analytics.logEvent(
      name: eventName,
      parameters: parameters,
    );
  }
}
```

### 2. Performance Monitoring

#### Firebase Performance
Already included in dependencies above. Add performance traces:

```dart
// In lib/services/api_service.dart
import 'package:firebase_performance/firebase_performance.dart';

class ApiService {
  static Future<String> sendMessage(String message, String persona) async {
    final trace = FirebasePerformance.instance.newTrace('ai_completion_request');
    await trace.start();
    
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': message,
          'config': persona,
        }),
      ).timeout(_timeoutDuration);

      trace.setMetric('response_code', response.statusCode);
      trace.setMetric('response_time', DateTime.now().millisecondsSinceEpoch);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await trace.stop();
        return data['text'] ?? 'No response';
      } else {
        trace.setMetric('error', 1);
        await trace.stop();
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      trace.setMetric('error', 1);
      await trace.stop();
      
      // Log error to analytics
      await AnalyticsService.recordError(e, StackTrace.current);
      throw Exception('Network error: $e');
    }
  }
}
```

### 3. iOS Native Analytics Integration

#### Add Firebase iOS Configuration
Update `ios/Runner/Info.plist`:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

#### Update iOS AppDelegate
Update `ios/Runner/AppDelegate.swift`:
```swift
import UIKit
import Flutter
import Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 4. Analytics Integration in Key Screens

#### Update Main Screens with Analytics
Example for `lib/screens/chat_screen.dart`:

```dart
import '../services/analytics_service.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('chat_screen');
    AnalyticsService.logChatSessionStarted(selectedPersona);
  }
  
  void _sendMessage(String message, bool isVoiceInput) async {
    // Log message send
    await AnalyticsService.logMessageSent(
      persona: selectedPersona,
      isVoiceInput: isVoiceInput,
      messageLength: message.length,
    );
    
    final startTime = DateTime.now();
    
    try {
      final response = await ApiService.sendMessage(message, selectedPersona);
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // Log successful response
      await AnalyticsService.logAIResponseReceived(
        persona: selectedPersona,
        responseTime: responseTime,
        wasSuccessful: true,
      );
      
      // Update UI with response
      setState(() {
        messages.add(ChatMessage(text: response, isUser: false));
      });
      
    } catch (e) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // Log failed response
      await AnalyticsService.logAIResponseReceived(
        persona: selectedPersona,
        responseTime: responseTime,
        wasSuccessful: false,
      );
      
      // Log error for debugging
      await AnalyticsService.recordError(e, StackTrace.current);
      
      // Show error to user
      _showErrorDialog('Failed to send message: $e');
    }
  }
}
```

### 5. Beta Testing Analytics Dashboard

#### Firebase Console Setup
1. **Custom Events**: Monitor beta-specific events
2. **Funnels**: Track user onboarding completion
3. **Cohort Analysis**: Beta user retention over time
4. **Crash-Free Users**: Monitor app stability

#### Weekly Analytics Report
Create automated weekly report including:
- New beta users onboarded
- Active users (daily/weekly)
- Feature usage statistics
- Crash reports and resolution status
- Top user feedback themes
- API performance metrics

#### Analytics Export for Team
Set up BigQuery export for deeper analysis:
- User behavior patterns
- Feature correlation analysis
- Beta feedback sentiment analysis
- Performance trend analysis

### 6. Privacy and Compliance

#### Privacy Policy Updates
Ensure privacy policy covers:
- Analytics data collection
- Crash reporting data
- Beta user conversation logging
- Data retention policies
- User consent mechanisms

#### GDPR Compliance
- Provide opt-out mechanisms
- Clear data usage explanations
- User data deletion capabilities
- Consent tracking

#### User Consent Implementation
Add to app settings:
```dart
// In settings screen
SwitchListTile(
  title: Text('Analytics'),
  subtitle: Text('Help improve BetterBooks by sharing usage data'),
  value: analyticsEnabled,
  onChanged: (bool value) {
    setState(() {
      analyticsEnabled = value;
    });
    AnalyticsService.setAnalyticsEnabled(value);
  },
),
```

### 7. Testing and Validation

#### Analytics Testing Checklist
- [ ] Firebase project configured correctly
- [ ] GoogleService-Info.plist added to iOS project
- [ ] Custom events firing correctly
- [ ] Crash reporting capturing errors
- [ ] Performance traces recording
- [ ] User properties being set
- [ ] Privacy controls working
- [ ] Export to BigQuery functioning

#### Debug Analytics
Add debug mode for analytics validation:
```dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static bool _debugMode = kDebugMode;
  
  static Future<void> logEvent(String name, Map<String, dynamic> parameters) async {
    if (_debugMode) {
      print('Analytics Event: $name, Parameters: $parameters');
    }
    
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}
```

This comprehensive analytics setup provides detailed insights into beta user behavior, app performance, and areas for improvement while maintaining user privacy and regulatory compliance.