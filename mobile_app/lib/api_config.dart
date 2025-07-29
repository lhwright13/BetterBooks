// Base URL of the API Gateway. Can be overridden with environment variable.
// iOS Simulator uses localhost, Android emulator uses 10.0.2.2
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
