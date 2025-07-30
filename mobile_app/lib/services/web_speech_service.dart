import 'dart:js' as js;
import 'dart:async';

class WebSpeechService {
  static js.JsObject? _recognition;
  static Completer<String>? _completer;
  static bool _isListening = false;

  static bool get isSupported {
    try {
      final hasWebkit = js.context.hasProperty('webkitSpeechRecognition');
      final hasStandard = js.context.hasProperty('SpeechRecognition');
      print('DEBUG: webkitSpeechRecognition: $hasWebkit, SpeechRecognition: $hasStandard');
      return hasWebkit || hasStandard;
    } catch (e) {
      print('DEBUG: Speech support check failed: $e');
      return false;
    }
  }

  static Future<String> startListening() async {
    if (!isSupported) {
      throw Exception('Speech recognition not supported');
    }

    if (_isListening) {
      throw Exception('Already listening');
    }

    _completer = Completer<String>();
    _isListening = true;

    try {
      // Create recognition object
      final recognitionClass = js.context['webkitSpeechRecognition'] ?? js.context['SpeechRecognition'];
      _recognition = js.JsObject(recognitionClass);

      _recognition!['continuous'] = false;
      _recognition!['interimResults'] = false;
      _recognition!['lang'] = 'en-US';

      _recognition!['onresult'] = js.allowInterop((event) {
        try {
          final results = event['results'];
          if (results != null && results['length'] > 0) {
            final result = results[results['length'] - 1];
            if (result['isFinal'] == true) {
              final transcript = result[0]['transcript'];
              if (transcript != null && transcript.toString().trim().isNotEmpty) {
                if (!_completer!.isCompleted) {
                  _completer!.complete(transcript.toString().trim());
                }
              }
            }
          }
        } catch (e) {
          if (!_completer!.isCompleted) {
            _completer!.completeError('Error processing speech: $e');
          }
        }
      });

      _recognition!['onerror'] = js.allowInterop((event) {
        final error = event['error'] ?? 'unknown error';
        if (!_completer!.isCompleted) {
          _completer!.completeError('Speech error: $error');
        }
      });

      _recognition!['onend'] = js.allowInterop((event) {
        _isListening = false;
        if (!_completer!.isCompleted) {
          _completer!.completeError('Speech ended without result');
        }
      });

      _recognition!.callMethod('start');
      return await _completer!.future;
    } catch (e) {
      _isListening = false;
      _completer = null;
      throw Exception('Speech recognition failed: $e');
    }
  }

  static void stop() {
    try {
      _recognition?.callMethod('stop');
    } catch (e) {
      // Ignore stop errors
    }
    _isListening = false;
  }

  static bool get isListening => _isListening;
}

class WebSpeechSynthesis {
  static bool get isSupported {
    try {
      return js.context['speechSynthesis'] != null;
    } catch (e) {
      return false;
    }
  }

  static Future<void> speak(String text) async {
    if (!isSupported) {
      throw Exception('Speech synthesis not supported');
    }

    try {
      final synthesis = js.context['speechSynthesis'];
      final utteranceClass = js.context['SpeechSynthesisUtterance'];
      final utterance = js.JsObject(utteranceClass, [text]);
      
      // Configure voice settings
      utterance['rate'] = 0.9;
      utterance['pitch'] = 1.0;
      utterance['volume'] = 0.8;

      final completer = Completer<void>();

      utterance['onend'] = js.allowInterop((event) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      utterance['onerror'] = js.allowInterop((event) {
        if (!completer.isCompleted) {
          completer.completeError('Speech synthesis error');
        }
      });

      synthesis.callMethod('speak', [utterance]);
      return completer.future;
    } catch (e) {
      throw Exception('Speech synthesis failed: $e');
    }
  }

  static void stop() {
    try {
      final synthesis = js.context['speechSynthesis'];
      synthesis?.callMethod('cancel');
    } catch (e) {
      // Ignore stop errors
    }
  }
}