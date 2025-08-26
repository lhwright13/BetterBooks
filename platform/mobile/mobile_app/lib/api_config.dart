/**
 * api_config.dart - API endpoint configuration for EchoWright mobile app
 * 
 * This file defines the base URL for connecting to the EchoWright backend services.
 * The backend consists of multiple microservices orchestrated by an API Gateway
 * that handles routing, authentication, and request proxying.
 * 
 * Key responsibilities:
 * - Configure API endpoints for different environments (dev, staging, prod)
 * - Handle platform-specific networking (iOS simulator vs Android emulator)
 * - Support build-time configuration via environment variables
 * 
 * Backend architecture:
 * - API Gateway (port 8000) - Main entry point for all client requests
 * - LLM Gateway (port 8002) - AI persona and text generation
 * - Context Service (port 8001) - Vector embeddings and book context
 * - TTS Service (port 8003) - Text-to-speech synthesis
 * - Transcription Service (port 8004) - Chapter detection and analysis
 * 
 * Environment configurations:
 * - Development: http://localhost:8000 (default)
 * - Production: http://34.111.209.241:8000 (Google Cloud instance)
 * - Staging: https://staging.echowright.app (future)
 * - Production Domain: https://api.echowright.app (future)
 */

/// Base URL of the API Gateway that routes requests to backend microservices
/// Can be overridden at build time with --dart-define=API_BASE_URL=<url>
/// 
/// Platform notes:
/// - iOS Simulator: Must use host machine's IP address (e.g., http://192.168.1.56:8000)
/// - Android Emulator: Would use 10.0.2.2 to reach host machine
/// - Physical devices: Must use actual IP address or domain name
// Dynamic API base URL configuration supporting multiple environments
// Defaults to localhost for development, but can be overridden via build args
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL', 
  defaultValue: 'http://localhost:8000' // API Gateway port
);
