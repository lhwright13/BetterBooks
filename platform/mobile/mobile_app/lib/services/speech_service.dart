/**
 * speech_service.dart - Speech recognition service for BetterBooks
 * 
 * This service integrates with the BetterBooks backend transcription API
 * powered by Azure Speech Service for accurate voice-to-text conversion.
 * 
 * Architecture Flow:
 * Mobile App -> API Gateway -> Transcription Service -> Azure Speech API
 * 
 * Key responsibilities:
 * - Record audio from device microphone
 * - Send audio files to backend transcription service
 * - Handle real-time speech recognition via API
 * - Provide graceful fallback to text input when needed
 * - Manage microphone permissions and audio recording
 * 
 * Backend Integration:
 * - Uses POST /transcription/file for audio file transcription
 * - Uses POST /transcription/test for connectivity testing
 * - Handles network errors and service unavailability
 * - Supports multiple languages via backend configuration
 */

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Speech recognition service integrated with BetterBooks backend
/// Provides voice-to-text functionality via Azure Speech Service
class SpeechService {
  static bool _isListening = false;
  static bool _isRecording = false;
  
  // Backend API configuration
  // Using direct transcription service for now (port 8003) until API Gateway is fixed
  static const String _baseUrl = 'http://localhost:8003'; // Direct transcription service
  static const String _transcriptionEndpoint = '/transcribe/file';
  static const String _testEndpoint = '/transcribe/test';
  static const String _healthEndpoint = '/health';
  
  // For development/testing - in production this would use device microphone
  static const bool _useSimulatedAudio = true;

  /// Check if speech recognition is supported
  /// Returns true if backend transcription service is available
  static Future<bool> get isSupported async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_healthEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['azure_speech'] == true;
      }
      return false;
    } catch (e) {
      print('Speech service health check failed: $e');
      return false;
    }
  }

  /// Test backend transcription service connectivity
  static Future<String> testConnection() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_testEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'] ?? 'Test successful but no text returned';
      } else {
        return 'Backend test failed with status: ${response.statusCode}';
      }
    } catch (e) {
      return 'Connection test failed: $e';
    }
  }

  /// Start voice recording and transcription
  /// Returns the transcribed text from Azure Speech Service
  static Future<String> startListening({String? language}) async {
    if (_isListening) {
      throw Exception('Already listening');
    }
    
    _isListening = true;
    _isRecording = true;
    
    try {
      // For development: simulate audio recording
      if (_useSimulatedAudio) {
        await Future.delayed(Duration(seconds: 2)); // Simulate recording time
        _isRecording = false;
        
        // Test the backend connection and return result
        final testResult = await testConnection();
        _isListening = false;
        return testResult;
      }
      
      // TODO: Implement real audio recording when ready
      // This would involve:
      // 1. Request microphone permission
      // 2. Start audio recording
      // 3. Save to temporary file
      // 4. Send to backend for transcription
      // 5. Return transcribed text
      
      _isListening = false;
      _isRecording = false;
      throw Exception('Real audio recording not yet implemented - using simulated mode');
      
    } catch (e) {
      _isListening = false;
      _isRecording = false;
      rethrow;
    }
  }

  /// Transcribe an audio file using the backend service
  /// This would be used when recording is implemented
  static Future<String> transcribeAudioFile(File audioFile, {String? language}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl$_transcriptionEndpoint'),
      );
      
      // Add the audio file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          filename: 'recording.wav',
        ),
      );
      
      // Add language parameter if specified
      if (language != null) {
        request.fields['language'] = language;
      }
      
      // Send the request
      final streamedResponse = await request.send().timeout(Duration(minutes: 2));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'] ?? '';
      } else {
        throw Exception('Transcription failed: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      throw Exception('Transcription error: $e');
    }
  }

  /// Stop current voice recognition session
  static Future<void> stopListening() async {
    _isListening = false;
    _isRecording = false;
    // TODO: Stop audio recording when implemented
  }

  /// Check if currently listening for voice input
  static bool get isListening => _isListening;

  /// Check if currently recording audio
  static bool get isRecording => _isRecording;

  /// Check microphone permission status
  /// Currently returns true for development mode
  static Future<bool> get hasPermission async {
    // TODO: Implement real permission check
    // For now, return true in development mode
    return _useSimulatedAudio;
  }

  /// Request microphone permission from user
  static Future<bool> requestPermission() async {
    // TODO: Implement permission request
    // For now, return true in development mode
    return _useSimulatedAudio;
  }

  /// Get list of supported languages from backend
  static Future<List<String>> getSupportedLanguages() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/transcription/supported-languages'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['supported_languages'] ?? []);
      }
      return ['en-US']; // Default fallback
    } catch (e) {
      print('Failed to get supported languages: $e');
      return ['en-US']; // Default fallback
    }
  }
}