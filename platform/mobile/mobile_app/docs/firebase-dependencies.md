# Firebase Dependencies Documentation

## Overview
This document provides detailed information about each Firebase package used in the EchoWright app, including functionality, iOS-specific requirements, pricing, and whether each dependency is required or optional.

---

## Core Dependencies

### 1. firebase_core
**Package Name:** `firebase_core: ^3.8.0`  
**Purpose:** Core Firebase SDK initialization and configuration  
**What It Does:**
- Initializes Firebase app instance
- Manages Firebase project configuration
- Provides base functionality for all other Firebase services
- Handles platform-specific initialization

**iOS-Specific Notes:**
- Requires GoogleService-Info.plist in ios/Runner directory
- Must be added to Xcode project with proper target membership
- Minimum iOS deployment target: 12.0

**Pricing:** Free  
**Free Tier Limits:** Unlimited  
**Paid Tier Costs:** N/A  
**Required/Optional:** **REQUIRED** (base dependency for all Firebase services)

---

### 2. firebase_analytics
**Package Name:** `firebase_analytics: ^11.3.6`  
**Purpose:** User behavior tracking and app usage analytics  
**What It Does:**
- Tracks user events and screen views
- Provides user demographics and interests
- Measures app performance and user engagement
- Integrates with Google Analytics dashboard
- Supports custom events and user properties
- Provides conversion tracking and audience building

**iOS-Specific Notes:**
- Automatically collects app lifecycle events
- Requires App Tracking Transparency (ATT) for IDFA collection (iOS 14.5+)
- Add NSUserTrackingUsageDescription to Info.plist
- Analytics data may be delayed 24-48 hours

**Pricing:** Free  
**Free Tier Limits:** 
- Unlimited events
- 500 distinct events per app
- 25 user properties

**Paid Tier Costs:** 
- BigQuery export: ~$5/GB for queries
- Analytics 360 (enterprise): Custom pricing

**Required/Optional:** **REQUIRED** (for user insights and marketing)

---

### 3. firebase_crashlytics
**Package Name:** `firebase_crashlytics: ^4.2.0`  
**Purpose:** Real-time crash reporting and stability monitoring  
**What It Does:**
- Automatically captures app crashes and errors
- Provides detailed crash reports with stack traces
- Groups similar crashes for easier debugging
- Tracks crash-free users percentage
- Supports custom keys and logs
- Provides real-time alerts for new issues

**iOS-Specific Notes:**
- Requires dSYM files upload for symbolication
- Works with TestFlight and App Store builds
- Xcode build phase script needed for dSYM upload
- Crashes only visible when app runs without debugger

**Pricing:** Free  
**Free Tier Limits:** Unlimited crash reports  
**Paid Tier Costs:** N/A  
**Required/Optional:** **REQUIRED** (essential for app stability monitoring)

---

## Authentication & User Management

### 4. firebase_auth
**Package Name:** `firebase_auth: ^5.3.3`  
**Purpose:** User authentication and account management  
**What It Does:**
- Email/password authentication
- Social login (Google, Apple, Facebook)
- Phone number authentication
- Anonymous authentication
- Multi-factor authentication
- Account linking and management
- Password reset functionality

**iOS-Specific Notes:**
- Apple Sign-In requires capabilities in Xcode
- Add Sign in with Apple capability
- Configure OAuth redirect URLs in Info.plist
- Keychain sharing for credential persistence

**Pricing:** 
**Free Tier Limits:**
- Phone Auth: 10,000 SMS/month
- Other auth methods: Unlimited

**Paid Tier Costs:**
- Phone Auth: $0.01-$0.06 per SMS after free tier
- SAML/OIDC: Enterprise pricing

**Required/Optional:** **REQUIRED** (core user management)

---

## Database & Storage

### 5. cloud_firestore
**Package Name:** `cloud_firestore: ^5.5.1`  
**Purpose:** NoSQL cloud database for app data  
**What It Does:**
- Real-time data synchronization
- Offline data persistence
- Structured data storage (collections/documents)
- Complex queries and indexing
- Real-time listeners for data changes
- Batch writes and transactions

**iOS-Specific Notes:**
- Offline persistence enabled by default
- Cache size configurable (default 100MB)
- Background sync requires background modes
- Index creation may be needed for complex queries

**Pricing:**
**Free Tier Limits (per day):**
- 50,000 document reads
- 20,000 document writes
- 20,000 document deletes
- 1 GiB stored data
- 10 GiB network egress/month

**Paid Tier Costs:**
- Document reads: $0.06 per 100,000
- Document writes: $0.18 per 100,000
- Document deletes: $0.02 per 100,000
- Storage: $0.18/GiB/month
- Network egress: $0.12/GiB

**Required/Optional:** **REQUIRED** (main database)

---

### 6. firebase_storage
**Package Name:** `firebase_storage: ^12.3.7`  
**Purpose:** Cloud storage for user files and media  
**What It Does:**
- Upload/download files (images, audio, video)
- Resume interrupted uploads/downloads
- File metadata management
- Security rules for access control
- Integration with CDN for fast delivery
- Automatic file compression

**iOS-Specific Notes:**
- PHPhotoLibrary permission for photo access
- Background upload/download tasks supported
- NSAllowsArbitraryLoads may be needed for HTTP content
- Maximum file size: 5TB per object

**Pricing:**
**Free Tier Limits:**
- 5 GB stored
- 1 GB/day downloaded
- 20,000 upload operations/day
- 50,000 download operations/day

**Paid Tier Costs:**
- Storage: $0.026/GB/month
- Download: $0.12/GB
- Operations: $0.05 per 10,000

**Required/Optional:** **REQUIRED** (for audiobook files and covers)

---

## Messaging & Communication

### 7. firebase_messaging
**Package Name:** `firebase_messaging: ^15.1.5`  
**Purpose:** Push notifications and in-app messaging  
**What It Does:**
- Send push notifications to users
- Topic-based messaging
- Direct device messaging
- Silent/data notifications
- In-app messaging campaigns
- Message analytics and reporting

**iOS-Specific Notes:**
- Requires Push Notifications capability
- APNs certificate or key required
- Request notification permissions at runtime
- Background modes for silent notifications
- Provisional authorization available (iOS 12+)

**Pricing:** Free  
**Free Tier Limits:** Unlimited notifications  
**Paid Tier Costs:** N/A (except for Firebase Cloud Messaging server costs)  
**Required/Optional:** **OPTIONAL** (but recommended for engagement)

---

## Configuration & Optimization

### 8. firebase_remote_config
**Package Name:** `firebase_remote_config: ^5.1.5`  
**Purpose:** Dynamic app configuration without updates  
**What It Does:**
- Change app behavior without app updates
- A/B testing capabilities
- Feature flags and rollouts
- Personalized app experiences
- Server-side configuration
- Gradual feature rollouts

**iOS-Specific Notes:**
- Cached locally with configurable expiration
- Default values should be provided
- Network requests follow ATS rules
- Updates fetched on app launch

**Pricing:** Free  
**Free Tier Limits:**
- 2,000 parameters per project
- 500 conditions per project
- Unlimited fetches

**Paid Tier Costs:** N/A  
**Required/Optional:** **OPTIONAL** (useful for feature management)

---

### 9. firebase_performance
**Package Name:** `firebase_performance: ^0.10.1`  
**Purpose:** App performance monitoring and optimization  
**What It Does:**
- Automatic network request monitoring
- App startup time tracking
- Screen rendering performance
- Custom trace monitoring
- ANR (App Not Responding) detection
- Performance alerts and insights

**iOS-Specific Notes:**
- Automatically instruments URLSession
- Minimal impact on app size (~200KB)
- Can be disabled in debug builds
- Samples data to minimize overhead

**Pricing:** Free  
**Free Tier Limits:** Unlimited (with sampling)  
**Paid Tier Costs:** N/A  
**Required/Optional:** **OPTIONAL** (recommended for optimization)

---

### 10. firebase_app_check
**Package Name:** `firebase_app_check: ^0.3.1`  
**Purpose:** Protect backend resources from abuse  
**What It Does:**
- Verifies requests come from legitimate app
- Prevents API abuse and fraud
- Works with all Firebase services
- Custom backend integration available
- Device attestation
- Rate limiting support

**iOS-Specific Notes:**
- Uses DeviceCheck or App Attest (iOS 14+)
- Requires provisioning profile configuration
- Debug provider for development
- Production provider auto-configured

**Pricing:** Free  
**Free Tier Limits:**
- 10,000 verifications/month (DeviceCheck)
- 10,000 verifications/month (App Attest)

**Paid Tier Costs:**
- DeviceCheck: $0.00025 per verification after free tier
- App Attest: $0.00025 per verification after free tier

**Required/Optional:** **OPTIONAL** (but recommended for security)

---

## Additional Support Packages

### 11. firebase_dynamic_links
**Package Name:** `firebase_dynamic_links: ^6.0.8`  
**Purpose:** Deep linking and app sharing  
**What It Does:**
- Create shareable links to app content
- Survive app installation process
- Cross-platform link handling
- Marketing campaign tracking
- Social sharing optimization
- Deferred deep linking

**iOS-Specific Notes:**
- Requires Associated Domains capability
- Universal Links configuration
- Custom URL scheme in Info.plist
- App Store ID required for App Store redirects

**Pricing:** Free  
**Free Tier Limits:** Unlimited link creation and clicks  
**Paid Tier Costs:** N/A  
**Required/Optional:** **OPTIONAL** (useful for marketing and sharing)

---

### 12. firebase_in_app_messaging
**Package Name:** `firebase_in_app_messaging: ^0.8.1`  
**Purpose:** Targeted in-app message campaigns  
**What It Does:**
- Display targeted messages to active users
- Behavioral triggers for messages
- User segmentation
- A/B testing messages
- Campaign analytics
- Template-based designs

**iOS-Specific Notes:**
- Messages displayed over current content
- Respects app lifecycle
- Can be suppressed programmatically
- Works with Analytics events

**Pricing:** Free  
**Free Tier Limits:** Unlimited impressions  
**Paid Tier Costs:** N/A  
**Required/Optional:** **OPTIONAL** (for user engagement campaigns)

---

## Summary Table

| Package | Required | Monthly Cost (10K users) | Monthly Cost (50K users) |
|---------|----------|-------------------------|-------------------------|
| firebase_core | ✅ | $0 | $0 |
| firebase_analytics | ✅ | $0 | $0 |
| firebase_crashlytics | ✅ | $0 | $0 |
| firebase_auth | ✅ | $0-50 | $100-200 |
| cloud_firestore | ✅ | $50-100 | $200-500 |
| firebase_storage | ✅ | $20-50 | $100-300 |
| firebase_messaging | ⭕ | $0 | $0 |
| firebase_remote_config | ⭕ | $0 | $0 |
| firebase_performance | ⭕ | $0 | $0 |
| firebase_app_check | ⭕ | $0-10 | $20-50 |
| **TOTAL ESTIMATE** | | **$70-210/month** | **$420-1050/month** |

✅ = Required, ⭕ = Optional but Recommended

---

## Cost Optimization Tips

1. **Firestore Optimization:**
   - Use batch reads when possible
   - Implement proper caching strategies
   - Avoid unnecessary real-time listeners
   - Optimize query efficiency

2. **Storage Optimization:**
   - Compress images before upload
   - Use appropriate image formats
   - Implement CDN caching
   - Clean up unused files

3. **Authentication:**
   - Use social auth to avoid SMS costs
   - Implement rate limiting
   - Cache auth states locally

4. **General:**
   - Monitor usage in Firebase Console
   - Set up billing alerts
   - Use Firebase Emulator for development
   - Implement proper error handling to avoid retries

## Next Steps

- Set up billing alerts at 50%, 75%, and 90% of budget
- Configure Firebase Emulator for local development
- Implement proper error handling and retry logic
- Review security rules for all services
- Set up monitoring dashboards