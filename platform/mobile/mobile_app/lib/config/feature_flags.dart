/**
 * feature_flags.dart - Feature flags for MVP validation
 * 
 * This file controls which features are enabled during the MVP testing phase.
 * Features that are broken, incomplete, or not essential for core validation
 * are disabled to provide a focused user experience.
 */

class FeatureFlags {
  // Core MVP features - keep enabled
  static const bool enableBookstore = true;
  static const bool enableLibrary = true;
  static const bool enableBasicAuth = true;
  static const bool enableAudioPlayback = true;
  
  // Advanced features - disable for MVP
  static const bool enableVoiceMode = false;  // Speech-to-text disabled
  static const bool enableSubscriptions = false;  // Payment system not ready
  static const bool enableSocialFeatures = false;  // Not essential for MVP
  static const bool enableAdvancedAI = false;  // Focus on basic AI only
  
  // UI features
  static const bool showBetaWarnings = true;  // Show "Beta" labels
  static const bool enableAdvancedPlayer = false;  // Use simple player only
  
  // Development features
  static const bool enableDebugMode = false;  // Disabled for production
  static const bool useMockData = false;  // Use real API data
}