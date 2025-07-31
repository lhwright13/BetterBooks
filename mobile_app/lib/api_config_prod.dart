// Production API configuration for Muuchi
// This will be the actual domain once deployed

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL', 
  defaultValue: 'https://api.muuchi.app'
);

// Development/staging alternatives:
// const String apiBaseUrl = 'https://betterbooks-api-staging.example.com';
// const String apiBaseUrl = 'http://YOUR_LOCAL_IP:8000'; // For local testing