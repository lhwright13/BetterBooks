import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

// Temporary mock implementation for voice service
// TODO: Re-enable speech_to_text package when build issues are resolved
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  bool _isAvailable = false;
  bool _isListening = false;
  String _lastError = '';
  
  StreamController<String>? _speechController;
  StreamController<double>? _soundLevelController;
  StreamController<bool>? _statusController;

  Stream<String> get speechStream => _speechController?.stream ?? const Stream.empty();
  Stream<double> get soundLevelStream => _soundLevelController?.stream ?? const Stream.empty();
  Stream<bool> get statusStream => _statusController?.stream ?? const Stream.empty();

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get lastError => _lastError;

  Future<bool> initialize() async {
    try {
      _speechController = StreamController<String>.broadcast();
      _soundLevelController = StreamController<double>.broadcast();
      _statusController = StreamController<bool>.broadcast();

      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        _lastError = 'Microphone permission denied';
        return false;
      }

      // Mock initialization - always succeeds for now
      _isAvailable = true;
      return true;
    } catch (e) {
      _lastError = 'Failed to initialize voice recognition: $e';
      return false;
    }
  }

  Future<bool> startListening({
    String localeId = 'en_US',
    Duration? listenFor,
  }) async {
    if (!_isAvailable || _isListening) {
      return false;
    }

    try {
      // Mock implementation - simulate listening for 5 seconds
      _isListening = true;
      _statusController?.add(true);
      
      // Simulate speech recognition with a mock response
      Timer(Duration(seconds: 3), () {
        _speechController?.add("What are the main themes in this chapter?");
      });
      
      // Stop listening after 5 seconds
      Timer(Duration(seconds: 5), () {
        _isListening = false;
        _statusController?.add(false);
      });
      
      return true;
    } catch (e) {
      _lastError = 'Failed to start listening: $e';
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      _isListening = false;
      _statusController?.add(false);
    }
  }

  Future<void> cancelListening() async {
    if (_isListening) {
      _isListening = false;
      _statusController?.add(false);
    }
  }

  Future<List<dynamic>> get availableLocales async {
    // Return empty list for mock
    return [];
  }

  void dispose() {
    _speechController?.close();
    _soundLevelController?.close();
    _statusController?.close();
  }
}