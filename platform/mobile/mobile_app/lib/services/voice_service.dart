import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/api/api_client.dart';
import '../data/models/chat_models.dart';
import '../core/services/logging_service.dart';
import '../core/exceptions/api_exceptions.dart';

/// Voice chat state enum
enum VoiceChatState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

/// Simplified voice service stub for MVP testing
/// Voice features temporarily disabled due to iOS build dependencies
class VoiceService extends ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  // Mock state values for compatibility
  bool _speechEnabled = false;
  bool _isListening = false;
  String _wordsSpoken = "";
  double _confidenceLevel = 0;
  bool _isSpeaking = false;
  bool _ttsInitialized = false;
  VoiceChatState _state = VoiceChatState.idle;
  String? _currentPersonaVoice;
  String? _lastError;
  List<dynamic>? _availableVoices;

  // Getters
  bool get speechEnabled => _speechEnabled;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get wordsSpoken => _wordsSpoken;
  double get confidenceLevel => _confidenceLevel;
  VoiceChatState get state => _state;
  String? get lastError => _lastError;
  List<dynamic>? get availableVoices => _availableVoices;
  bool get isInitialized => true; // Always return true for now

  /// Initialize voice service (stubbed)
  Future<bool> initializeSpeech() async {
    LoggingService.info('Voice service stubbed - speech features disabled', tag: 'VoiceService');
    _speechEnabled = false; // Disabled
    notifyListeners();
    return false;
  }

  /// Initialize voice service (alias for initializeSpeech)
  Future<bool> initialize() async {
    return await initializeSpeech();
  }

  /// Start listening (stubbed)
  Future<void> startListening() async {
    LoggingService.info('Voice listening stubbed - not implemented', tag: 'VoiceService');
    _lastError = 'Voice features temporarily disabled';
    notifyListeners();
  }

  /// Stop listening (stubbed)
  Future<void> stopListening() async {
    LoggingService.info('Voice listening stop stubbed', tag: 'VoiceService');
    _isListening = false;
    notifyListeners();
  }

  /// Send voice message (stubbed - always returns error)
  Future<VoiceChatResponse?> sendVoiceMessage(String audioPath, {
    String? bookId,
    String? personaId,
    int? currentPosition,
  }) async {
    LoggingService.warning('Voice chat stubbed - feature disabled', tag: 'VoiceService');
    _lastError = 'Voice chat features temporarily disabled for iOS compatibility';
    return VoiceChatResponse(
      transcription: '',
      responseText: 'Voice chat is currently disabled for iOS compatibility. Please use text chat instead.',
      responseAudio: null,
    );
  }

  /// Speak text (stubbed)
  Future<void> speak(String text) async {
    LoggingService.info('TTS stubbed: $text', tag: 'VoiceService');
    // Do nothing - TTS disabled
  }

  /// Stop speaking (stubbed)
  Future<void> stopSpeaking() async {
    LoggingService.info('TTS stop stubbed', tag: 'VoiceService');
    _isSpeaking = false;
    notifyListeners();
  }

  /// Set persona voice (stubbed)
  void setPersonaVoice(String? voice) {
    LoggingService.info('Persona voice setting stubbed: $voice', tag: 'VoiceService');
    _currentPersonaVoice = voice;
  }

  /// Dispose resources
  @override
  void dispose() {
    LoggingService.info('Voice service disposed', tag: 'VoiceService');
    super.dispose();
  }

  /// Reset to idle state
  void resetState() {
    _state = VoiceChatState.idle;
    _isListening = false;
    _isSpeaking = false;
    _wordsSpoken = "";
    _confidenceLevel = 0;
    _lastError = null;
    notifyListeners();
  }
}