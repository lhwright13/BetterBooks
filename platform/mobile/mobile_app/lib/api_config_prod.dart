// Production API configuration for EchoWright
// Routes all requests through API Gateway for proper load balancing and auth

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL', 
  defaultValue: 'https://api.echowright.app' // Production domain
);

// Fallback for development/testing
const String devApiBaseUrl = String.fromEnvironment(
  'DEV_API_BASE_URL',
  defaultValue: 'http://localhost:8000' // API Gateway
);

// Use appropriate base URL based on build configuration
const String effectiveApiBaseUrl = String.fromEnvironment('FLUTTER_FLAVOR') == 'dev' 
    ? devApiBaseUrl 
    : apiBaseUrl;

// All services route through API Gateway - no direct service URLs needed