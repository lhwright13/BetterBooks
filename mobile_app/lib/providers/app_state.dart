/**
 * app_state.dart - Global state management for EchoWright mobile app
 * 
 * This is the central state management class that coordinates all app functionality
 * using the Provider pattern. It manages audiobook playback, AI persona interactions,
 * chat conversations, and communication with backend microservices.
 * 
 * Key responsibilities:
 * - Manage audiobook library and current playback state
 * - Handle AI persona selection and chat conversations
 * - Control audio playback with position tracking and controls
 * - Coordinate with backend services via API calls
 * - Provide reactive state updates to UI components
 * 
 * Architecture integration:
 * - Uses audioplayers package for cross-platform audio playback
 * - Communicates with API Gateway for all backend operations
 * - Manages context-aware AI conversations using book content
 * - Handles both text and voice-based AI interactions
 * 
 * State management:
 * - Books and chapters from the audiobook library
 * - Current playback position and audio controls
 * - AI personas loaded from backend configuration
 * - Chat message history for AI conversations
 * - Loading states and error handling
 */

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/book.dart';
import '../models/persona.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

/// Global application state manager using Provider pattern for reactive UI updates
/// Coordinates audiobook playback, AI interactions, and backend communication
class AppState extends ChangeNotifier {
  // Private state variables
  List<Book> _books = [];                    // Available audiobooks from backend
  List<Persona> _personas = [];              // AI personas for chat interactions
  List<ChatMessage> _chatMessages = [];      // Chat conversation history
  Book? _currentBook;                        // Currently selected/playing book
  Chapter? _currentChapter;                  // Current chapter (for multi-chapter books)
  Persona? _selectedPersona;                 // Active AI persona for conversations
  
  // Audio playback state
  final AudioPlayer _audioPlayer = AudioPlayer();  // Cross-platform audio player
  Duration _currentPosition = Duration.zero;        // Current playback position
  Duration _totalDuration = Duration.zero;          // Total audio duration
  bool _isPlaying = false;                          // Playback state
  bool _isLoading = false;                          // Loading indicator state
  String? _error;                                   // Error message display

  // Public getters for UI components
  List<Book> get books => _books;
  List<Persona> get personas => _personas;
  List<ChatMessage> get chatMessages => _chatMessages;
  Book? get currentBook => _currentBook;
  Chapter? get currentChapter => _currentChapter;
  Persona? get selectedPersona => _selectedPersona;
  AudioPlayer get audioPlayer => _audioPlayer;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AppState() {
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });
  }

  Future<void> loadBooks() async {
    _setLoading(true);
    try {
      _books = await ApiService.getBooks();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPersonas() async {
    try {
      _personas = await ApiService.getPersonas();
      if (_personas.isNotEmpty && _selectedPersona == null) {
        _selectedPersona = _personas.first;
      }
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void selectPersona(Persona persona) {
    _selectedPersona = persona;
    notifyListeners();
  }

  Future<void> playBook(Book book, [Chapter? chapter]) async {
    try {
      _currentBook = book;
      _currentChapter = chapter;
      
      String audioUrl;
      if (chapter != null) {
        audioUrl = chapter.audioUrl;
      } else if (book.audioUrl != null) {
        audioUrl = book.audioUrl!;
      } else {
        throw Exception('No audio URL available');
      }

      print('Attempting to play audio from: $audioUrl');
      
      // Stop any existing playback
      await _audioPlayer.stop();
      
      // Configure audio session for better iOS compatibility
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      
      await _audioPlayer.play(UrlSource(audioUrl));
      _error = null;
      notifyListeners();
    } catch (e) {
      print('Audio playback error: $e');
      _error = 'Audio playback failed: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentPosition = Duration.zero;
    notifyListeners();
  }

  Future<String> getCurrentContext() async {
    if (_currentBook == null) return '';
    try {
      return await ApiService.getContext(
        _currentBook!.title, 
        _currentChapter?.title,
        _currentPosition.inSeconds.toDouble(),
      );
    } catch (e) {
      return '';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Chat functionality
  void addChatMessage(String content, bool isUser, {bool isVoiceMessage = false}) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: isUser,
      timestamp: DateTime.now(),
      isVoiceMessage: isVoiceMessage,
    );
    _chatMessages.add(message);
    notifyListeners();
  }

  Future<String> sendTextMessage(String message) async {
    if (_selectedPersona == null) {
      throw Exception('Please select an AI persona first');
    }

    // Add user message to chat
    addChatMessage(message, true);

    try {
      // Get current context if available
      String contextualMessage = message;
      if (_currentBook != null) {
        final context = await getCurrentContext();
        if (context.isNotEmpty) {
          contextualMessage = "Context from current playback: $context\n\nUser question: $message";
        }
      }

      // Get AI response
      final response = await ApiService.sendMessage(
        contextualMessage,
        _selectedPersona!.name,
      );

      // Add AI response to chat
      addChatMessage(response, false);
      
      return response;
    } catch (e) {
      addChatMessage('Error: ${e.toString()}', false);
      rethrow;
    }
  }

  Future<String> processVoiceQuery(String voiceText) async {
    if (_selectedPersona == null) {
      throw Exception('Please select an AI persona first');
    }

    // Add voice query to chat
    addChatMessage(voiceText, true, isVoiceMessage: true);

    try {
      // Get current context if available
      String contextualMessage = voiceText;
      if (_currentBook != null) {
        final context = await getCurrentContext();
        if (context.isNotEmpty) {
          contextualMessage = "Context from current playback: $context\n\nUser question: $voiceText";
        }
      }

      // Get AI response
      final response = await ApiService.sendMessage(
        contextualMessage,
        _selectedPersona!.name,
      );

      // Add AI response to chat
      addChatMessage(response, false, isVoiceMessage: true);

      return response;
    } catch (e) {
      addChatMessage('Error: ${e.toString()}', false);
      rethrow;
    }
  }

  void clearChat() {
    _chatMessages.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}