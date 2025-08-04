// Production API configuration for BetterBooks
// Using our deployed GKE static IP address

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL', 
  defaultValue: 'http://34.28.246.242'
);

// Development/staging alternatives:
// const String apiBaseUrl = 'https://api.betterbooks.app'; // Future domain
// const String apiBaseUrl = 'http://localhost:8000'; // Local development