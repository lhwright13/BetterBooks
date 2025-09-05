# EchoWright App Testing Guide 🧪

This testing suite provides comprehensive automated testing for the EchoWright mobile app, simulating exactly what you would do as a user clicking through the app.

## 🎯 What These Tests Do

The tests exercise the complete user journey that you would perform manually:

### 📱 **Complete User Flow Testing**
1. **Launch App** → Verify tabs load correctly
2. **Browse Books** → Navigate to Discover tab, find books
3. **Purchase Flow** → Click book → Click Purchase button → Verify purchase
4. **Library Access** → Go to Library tab → See purchased books
5. **Download Books** → Click Download → Watch progress → Verify completion
6. **Play Books** → Click book in library → Navigate to player → Test controls

### 🔧 **Technical Validation**
- Authentication token handling and refresh
- Download service with fallback audio URLs
- Navigation logic (purchased books → player, unpurchased → details)
- UI state management during async operations
- Error handling and user feedback

## 🚀 How to Run Tests

### Option 1: Run All Tests (Recommended)
```bash
cd platform/mobile/mobile_app
./run_tests.sh
```

### Option 2: Run Specific Test Types
```bash
# Unit tests only (core logic and services)
flutter test test/unit/

# Widget tests only (UI components and interactions)  
flutter test test/widget/

# Integration tests only (complete user flows)
flutter test test/integration/
```

### Option 3: Run Individual Test Files
```bash
# Test authentication and download services
flutter test test/unit/services_test.dart --verbose

# Test purchase flow UI
flutter test test/widget/purchase_flow_test.dart --verbose

# Test navigation between screens  
flutter test test/widget/navigation_test.dart --verbose

# Test complete app flow
flutter test test/integration/app_flow_test.dart --verbose
```

## 📊 Test Categories

### 🧮 **Unit Tests** (`test/unit/`)
Tests core business logic and services:
- ✅ Authentication token refresh mechanism
- ✅ Download service fallback URL generation
- ✅ API client methods and token management
- ✅ Book model state transitions (unpurchased → purchased → downloaded)
- ✅ Purchase flow state logic

### 🎨 **Widget Tests** (`test/widget/`)
Tests UI components and user interactions:
- ✅ Purchase button displays and responds to taps
- ✅ Loading states during purchase process
- ✅ Button state transitions (Purchase → Download → Listen Now)
- ✅ Navigation between screens
- ✅ Player controls functionality

### 🔄 **Integration Tests** (`test/integration/`)
Tests complete user journeys:
- ✅ Full app launch and tab navigation
- ✅ Book discovery and selection flow
- ✅ Complete purchase process with error handling
- ✅ Download functionality with progress tracking
- ✅ Library management and book playback
- ✅ Authentication state management

## 🎭 Test Scenarios Covered

### **Scenario 1: New User Book Purchase**
```
1. Launch app → See home screen with tabs
2. Go to Discover → Browse available books  
3. Tap book → Navigate to book details
4. Tap Purchase → Authenticate and purchase
5. Go to Library → See purchased book
6. Tap Download → Watch progress bar
7. Tap book → Navigate to player
```

### **Scenario 2: Existing User Playback**
```
1. Launch app → Restore authentication state
2. Go to Library → Load user's purchased books
3. Tap downloaded book → Open player directly
4. Test player controls → Play/pause/skip
```

### **Scenario 3: Error Handling**
```
1. Expired tokens → Automatic refresh
2. Network failures → Graceful fallbacks
3. Missing audio files → Create demo placeholders
4. Authentication errors → Clear user feedback
```

## 🔍 Reading Test Output

Look for these success indicators in test output:
```
✅ App launched successfully
✅ Purchase button found  
✅ Purchase loading state displayed
✅ Download process completed
✅ Navigated to player screen
✅ All navigation tabs working correctly
```

## 🛠 Test Features

### **Realistic User Simulation**
- Tests tap gestures, navigation, and form input
- Waits for async operations (API calls, downloads)
- Verifies UI state changes and feedback messages
- Tests error scenarios and recovery

### **Backend Integration Testing** 
- Real API calls to your Azure backend
- Authentication token management
- Download service with fallback handling
- Database operations (SQLite for downloads)

### **Comprehensive Coverage**
- Every user-facing feature is tested
- Both success and error paths covered
- UI state transitions verified
- Service layer functionality validated

## 🚨 Test Requirements

- **For Unit/Widget Tests**: No special setup required
- **For Integration Tests**: Requires iOS Simulator or Android Emulator running
- **Backend**: Tests work with your Azure deployment at `128.203.92.141:8000`

## 🎉 Benefits

Instead of manually clicking through the app every time you make changes, these tests:
- ✅ Automatically verify all functionality works
- ✅ Catch regressions before deployment  
- ✅ Test edge cases you might forget to check
- ✅ Provide confidence in purchase and download flows
- ✅ Validate authentication and token handling
- ✅ Ensure consistent user experience

Run these tests after any changes to ensure your app functionality remains intact!