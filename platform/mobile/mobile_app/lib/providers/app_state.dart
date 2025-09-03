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
import '../services/bookstore_adapter.dart';
import '../services/log_service.dart';
import '../services/optimized_api_service.dart';

/// Global application state manager using Provider pattern for reactive UI updates
/// Coordinates audiobook playback, AI interactions, and backend communication
class AppState extends ChangeNotifier {
  // Private state variables
  List<Book> _books = [];                    // Available audiobooks from backend
  List<Book> _purchasedBooks = [];           // User's purchased books (library)
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
  List<Book> get purchasedBooks => _purchasedBooks;
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

  Future<void> loadPurchasedBooks(String userId) async {
    _setLoading(true);
    try {
      final bookstoreAdapter = BookstoreAdapter();
      final catalogBooks = await bookstoreAdapter.getUserLibrary(userId);
      
      _purchasedBooks = catalogBooks.map((catalogBook) {
        return Book(
          id: catalogBook.id,
          title: catalogBook.title,
          author: catalogBook.author,
          audioUrl: catalogBook.sampleAudioUrl,
          coverUrl: catalogBook.coverImageUrl,
          duration: catalogBook.durationSeconds != null 
            ? Duration(seconds: catalogBook.durationSeconds!) 
            : null,
          chapters: [],
        );
      }).toList();
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      LogService.debug('Error loading purchased books: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPersonas() async {
    try {
      // Load book-specific personas if we have a current book
      if (_currentBook != null && _currentBook!.id.isNotEmpty) {
        LogService.debug('Loading personas for book: ${_currentBook!.title}');
        _personas = await OptimizedApiService.getBookPersonas(_currentBook!.id);
      } else {
        // Load all available personas if no specific book
        LogService.debug('Loading all available personas');
        _personas = await OptimizedApiService.getAllPersonas();
      }
      
      // Select default persona if available, otherwise first persona
      if (_personas.isNotEmpty) {
        final defaultPersona = _personas.firstWhere(
          (p) => p.isDefault,
          orElse: () => _personas.first,
        );
        if (_selectedPersona == null) {
          _selectedPersona = defaultPersona;
        }
      }
      
      _error = null;
      notifyListeners();
      LogService.debug('Loaded ${_personas.length} personas from API Gateway');
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      LogService.debug('Failed to load personas: $e');
      
      // Use basic fallback personas if API Gateway fails
      try {
        LogService.debug('Using fallback personas');
        _personas = [
          Persona(
            id: 'fallback-teacher',
            name: 'English Teacher',
            displayName: 'English Teacher',
            description: 'Encouraging guide for literary analysis and discussion',
            voice: 'en-US-Neural2-C',
            voiceConfig: {},
            generationConfig: {},
            ttsConfig: {},
            isGlobal: true,
            isDefault: true,
          ),
        ];
        if (_personas.isNotEmpty && _selectedPersona == null) {
          _selectedPersona = _personas.first;
        }
        _error = null;
        notifyListeners();
        LogService.debug('Loaded ${_personas.length} fallback personas');
      } catch (fallbackError) {
        LogService.debug('Fallback also failed: $fallbackError');
      }
    }
  }

  void selectPersona(Persona persona) {
    _selectedPersona = persona;
    notifyListeners();
  }

  /// Reload personas for the current book (useful after book changes)
  Future<void> reloadPersonasForCurrentBook() async {
    if (_currentBook != null) {
      LogService.debug('Reloading personas for current book: ${_currentBook!.title}');
      await loadPersonas();
    }
  }

  Future<void> playBook(Book book, [Chapter? chapter]) async {
    String? audioUrl;
    try {
      final bookChanged = _currentBook?.id != book.id;
      _currentBook = book;
      _currentChapter = chapter;
      
      // Load book-specific personas when switching to a new book
      if (bookChanged) {
        LogService.debug('Book changed, loading personas for: ${book.title}');
        loadPersonas(); // Don't await to avoid blocking audio playback
      }
      
      if (chapter != null) {
        audioUrl = chapter.audioUrl;
      } else if (book.audioUrl != null) {
        audioUrl = book.audioUrl!;
      } else {
        throw Exception('No audio URL available');
      }

      LogService.debug('Attempting to play audio from: $audioUrl');
      
      // Stop any existing playback
      await _audioPlayer.stop();
      
      // Configure audio session for better iOS compatibility
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      
      await _audioPlayer.play(UrlSource(audioUrl));
      _error = null;
      notifyListeners();
    } catch (e) {
      await _handleAudioError(e, audioUrl ?? '');
    }
  }

  Future<void> _handleAudioError(dynamic error, String audioUrl, {int retryCount = 0}) async {
    const int maxRetries = 3;
    const Duration retryDelay = Duration(seconds: 2);
    
    LogService.debug('Audio playback error (attempt ${retryCount + 1}): $error');
    
    // Determine error type and appropriate response
    String errorMessage;
    bool shouldRetry = false;
    
    if (error.toString().contains('404') || error.toString().contains('not found')) {
      errorMessage = 'Audio file not found. Please check your book selection.';
    } else if (error.toString().contains('network') || error.toString().contains('connection')) {
      errorMessage = 'Network error. Checking connection...';
      shouldRetry = true;
    } else if (error.toString().contains('codec') || error.toString().contains('format')) {
      errorMessage = 'Audio format not supported. Please try a different file.';
    } else if (error.toString().contains('permission')) {
      errorMessage = 'Permission denied. Please check app permissions.';
    } else {
      errorMessage = 'Audio playback failed. Retrying...';
      shouldRetry = true;
    }
    
    _error = errorMessage;
    notifyListeners();
    
    // Retry logic for recoverable errors
    if (shouldRetry && retryCount < maxRetries) {
      await Future.delayed(retryDelay * (retryCount + 1)); // Exponential backoff
      try {
        await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
        await _audioPlayer.play(UrlSource(audioUrl));
        _error = null; // Clear error on successful retry
        notifyListeners();
        LogService.debug('Audio playback recovered after ${retryCount + 1} retries');
      } catch (retryError) {
        await _handleAudioError(retryError, audioUrl, retryCount: retryCount + 1);
      }
    } else if (retryCount >= maxRetries) {
      _error = 'Audio playback failed after $maxRetries attempts. Please try again later.';
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
    if (_currentBook == null) {
      LogService.debug('DEBUG: No current book selected for context');
      return '';
    }
    
    try {
      LogService.debug('DEBUG: Requesting context for book: ${_currentBook!.title}');
      LogService.debug('DEBUG: Current chapter: ${_currentChapter?.title ?? "none"}');
      LogService.debug('DEBUG: Current position: ${_currentPosition.inSeconds}s');
      
      final context = await ApiService.getContext(
        _currentBook!.title, 
        _currentChapter?.title,
        _currentPosition.inSeconds.toDouble(),
      );
      
      LogService.debug('DEBUG: Context received: ${context.length} characters');
      if (context.length > 100) {
        LogService.debug('DEBUG: Context preview: ${context.substring(0, 100)}...');
      } else {
        LogService.debug('DEBUG: Full context: $context');
      }
      
      return context;
    } catch (e) {
      LogService.debug('DEBUG: Context extraction failed: $e');
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
          contextualMessage = "Context from current playbook: $context\n\nUser question: $message";
          LogService.debug('DEBUG: Sending contextual message to LLM (${contextualMessage.length} chars)');
        } else {
          LogService.debug('DEBUG: No context available, sending message without context');
        }
      } else {
        LogService.debug('DEBUG: No book playing, sending message without context');
      }

      // Get AI response via API Gateway
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
          LogService.debug('DEBUG: Sending contextual voice message to LLM (${contextualMessage.length} chars)');
        } else {
          LogService.debug('DEBUG: No context available for voice message, sending without context');
        }
      } else {
        LogService.debug('DEBUG: No book playing for voice message, sending without context');
      }

      // Get AI response via API Gateway
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