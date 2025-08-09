// Production API configuration for BetterBooks
// Using transcription service directly since API Gateway needs fixes

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL', 
  defaultValue: 'http://localhost:8003'
);

const String llmGatewayUrl = String.fromEnvironment(
  'LLM_GATEWAY_URL',
  defaultValue: 'http://localhost:8002'
);

// Development/staging alternatives:
// const String apiBaseUrl = 'https://api.betterbooks.app'; // Future domain
// const String apiBaseUrl = 'http://localhost:8000'; // API Gateway (when fixed)
// const String apiBaseUrl = 'http://localhost:8003'; // Transcription Service (current)