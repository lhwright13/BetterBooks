/**
 * api_service.dart - HTTP client service for EchoWright backend communication
 * 
 * This file provides the primary interface between the Flutter mobile app and
 * the EchoWright backend services. It handles all HTTP communication including
 * book loading, persona management, AI chat, TTS synthesis, and context retrieval.
 * 
 * Key responsibilities:
 * - Communicate with API Gateway for all backend operations
 * - Handle book catalog and audiobook streaming URLs
 * - Manage AI persona configurations and selection
 * - Send chat messages to LLM Gateway via API Gateway
 * - Request text-to-speech synthesis from TTS Service
 * - Retrieve contextual information from Context Service
 * - Handle network errors and timeouts gracefully
 * 
 * Backend integration:
 * - All requests go through API Gateway (port 8000)
 * - API Gateway proxies to appropriate microservices
 * - Book streaming URLs point to audio file endpoints
 * - Chat completion uses LLM Gateway with persona configs
 * - TTS synthesis uses TTS Service with voice configurations
 * - Context queries use Context Service with position data
 * 
 * Network architecture:
 * - Uses standard HTTP REST API calls
 * - JSON request/response format for all endpoints
 * - 30-second timeout for all network operations
 * - Proper error handling with descriptive messages
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/book.dart';
import '../models/persona.dart';
import 'log_service.dart';

/// Service class for all HTTP communication with EchoWright backend services
/// Provides methods for books, personas, chat, TTS, and context operations
class ApiService {
  static const Duration _timeoutDuration = Duration(seconds: 30); // Network timeout for all requests
  static String? _authToken; // Store auth token for API calls

  /// Set authentication token for API requests
  /// Should be called after successful login/authentication
  static void setAuthToken(String token) {
    _authToken = token;
    LogService.auth('Auth token set');
  }

  /// Clear authentication token 
  /// Should be called on logout or token expiry
  static void clearAuthToken() {
    _authToken = null;
    LogService.auth('Auth token cleared');
  }

  /// Get current authentication token
  /// Returns null if no token is set
  static String? getAuthToken() {
    return _authToken;
  }

  /// Check if user is authenticated (has valid token)
  static bool get isAuthenticated => _authToken != null;

  /// Get authentication headers including Bearer token if available
  static Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Check authentication status by validating token with backend
  static Future<bool> authenticate() async {
    try {
      // Check if we have a stored token first
      if (_authToken == null) {
        LogService.auth('No auth token available');
        return false;
      }

      // Validate token with backend
      final response = await http.get(
        Uri.parse('$apiBaseUrl/auth/me'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        LogService.auth('Authentication token validated');
        return true;
      } else {
        LogService.auth('Auth token invalid: ${response.statusCode}', isError: true);
        _authToken = null; // Clear invalid token
        return false;
      }
    } catch (e) {
      LogService.auth('Auth error: $e', isError: true);
      return false;
    }
  }

  /// Tests connectivity to the EchoWright backend API Gateway
  /// Returns true if the health endpoint responds successfully
  /// Used to verify network connectivity before making other API calls
  static Future<bool> testConnection() async {
    try {
      LogService.api('GET', '$apiBaseUrl/health');
      final response = await http.get(
        Uri.parse('$apiBaseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);
      
      LogService.api('GET', '$apiBaseUrl/health', statusCode: response.statusCode);
      return response.statusCode == 200;
    } catch (e) {
      LogService.api('GET', '$apiBaseUrl/health', error: e.toString());
      return false;
    }
  }

  /// Fetches the complete audiobook catalog from the backend
  /// Returns a list of Book objects with streaming URLs and metadata
  /// Handles both single-file audiobooks and multi-chapter books
  static Future<List<Book>> getBooks() async {
    try {
      // Ensure we're authenticated before making the request
      if (_authToken == null) {
        await authenticate();
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/browse?limit=10'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final books = <Book>[];
        
        LogService.debug('API Response: $data', 'getBooks');
        
        // Parse the books from browse endpoint format
        if (data['books'] != null) {
          final booksData = data['books'] as List<dynamic>;
          
          for (final bookData in booksData) {
            final book = bookData as Map<String, dynamic>;
            final bookId = book['id'] as String;
            final title = book['title'] as String;
            
            // Special handling for The Great Gatsby - add chapters
            if (bookId == '5867a269-af65-46c4-a025-98ea3b14b757') {
              final chapters = <Chapter>[];
              for (int i = 1; i <= 9; i++) {
                chapters.add(Chapter(
                  id: 'gatsby-chapter-$i',
                  title: 'Chapter $i',
                  audioUrl: '$apiBaseUrl/books/The%20Great%20Gatsby/Chapter%20$i.mp3',
                  chapterNumber: i,
                  duration: Duration(minutes: 30), // Estimate
                ));
              }
              
              books.add(Book(
                id: bookId,
                title: title,
                author: book['author'],
                chapters: chapters,
                coverUrl: book['cover_image_url'] != null 
                  ? '$apiBaseUrl${book['cover_image_url']}' 
                  : null,
              ));
            } else {
              // For other books, create a simple book without chapters for now
              books.add(Book(
                id: bookId,
                title: title,
                author: book['author'],
                coverUrl: book['cover_image_url'] != null 
                  ? '$apiBaseUrl${book['cover_image_url']}' 
                  : null,
              ));
            }
          }
        }
        
        LogService.info('Loaded ${books.length} books from backend', 'getBooks');
        return books;
      } else {
        throw Exception('Failed to load books: ${response.statusCode}');
      }
    } catch (e) {
      LogService.api('GET', '$apiBaseUrl/bookstore/browse', error: e.toString());
      throw Exception('Network error: $e');
    }
  }

  /// Loads available AI personas from the LLM Gateway
  /// Returns a list of Persona objects for user selection in chat
  /// Each persona has different personality and conversation style
  static Future<List<Persona>> getPersonas() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/configs'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['configs'] as List)
            .map((configName) => Persona(
              name: configName.toString(),
              displayName: configName.toString(),
              description: 'AI assistant persona: $configName',
              voice: 'en-US-Neural2-C',
              voiceConfig: {},
            ))
            .toList();
      } else {
        throw Exception('Failed to load personas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Sends a chat message to the specified AI persona
  /// Returns the AI's response text via LLM Gateway
  /// Uses the persona's configuration for response style and voice
  static Future<String> sendMessage(String message, String persona) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/complete'),
        headers: _getHeaders(),
        body: jsonEncode({
          'prompt': message,
          'config': persona,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] ?? 'No response';
      } else {
        throw Exception('Failed to send message: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Converts text to speech using the TTS Service
  /// Returns base64-encoded audio data for playback
  /// Uses persona's voice configuration for natural speech synthesis
  static Future<String> synthesizeSpeech(String text, String persona) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/tts'),
        headers: _getHeaders(),
        body: jsonEncode({
          'text': text,
          'config': persona,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['audio'] ?? '';
      } else {
        throw Exception('Failed to synthesize speech: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Retrieves contextual information about the current reading position
  /// Uses Context Service to provide relevant book content for AI conversations
  /// Position-aware context helps personas give more relevant responses
  static Future<String> getContext(String bookName, String? chapterName, double currentPosition) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/context'),
        headers: _getHeaders(),
        body: jsonEncode({
          'book_name': bookName,
          'chapter_name': chapterName,
          'current_position': currentPosition,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['context_text'] ?? '';
      } else {
        throw Exception('Failed to get context: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Detects chapters in an audiobook using AI chapter detection
  /// Returns a list of DetectedChapter objects with timestamps and metadata
  /// Used to automatically segment long audiobooks into logical chapters
  static Future<List<DetectedChapter>> detectChapters(String bookName, String? chapterName) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/detect-chapters'),
        headers: _getHeaders(),
        body: jsonEncode({
          'book_name': bookName,
          'chapter_name': chapterName,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final chapters = data['chapters'] as List<dynamic>?;
        
        if (chapters != null) {
          return chapters.map((chapterData) => DetectedChapter.fromJson(chapterData)).toList();
        }
        
        return [];
      } else {
        throw Exception('Failed to detect chapters: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Chapter detection error: $e');
    }
  }

  /// Generates a summary for a specific chapter using AI
  /// Returns a ChapterSummary object with different summary styles and metadata
  /// Supports multiple summary styles: brief, detailed, themes, key_points, etc.
  static Future<ChapterSummary> generateChapterSummary(
    String bookName,
    String chapterId,
    String style,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/summarize-chapter'),
        headers: _getHeaders(),
        body: jsonEncode({
          'book_name': bookName,
          'chapter_id': chapterId,
          'style': style,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summaryData = data['summary'];
        
        if (summaryData != null) {
          return ChapterSummary.fromJson(summaryData);
        }
        
        throw Exception('No summary data in response');
      } else {
        throw Exception('Failed to generate summary: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Summary generation error: $e');
    }
  }

  /// Generates discussion questions for a chapter using AI
  /// Returns a list of ChapterQuestion objects for educational engagement
  /// Supports different difficulty levels and reading modes
  static Future<List<ChapterQuestion>> generateChapterQuestions(
    String bookName,
    String chapterId,
    String difficulty,
    String readingMode, {
    int numQuestions = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/generate-questions'),
        headers: _getHeaders(),
        body: jsonEncode({
          'book_name': bookName,
          'chapter_id': chapterId,
          'difficulty': difficulty,
          'reading_mode': readingMode,
          'num_questions': numQuestions,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final questions = data['questions'] as List<dynamic>?;
        
        if (questions != null) {
          return questions.map((questionData) => ChapterQuestion.fromJson(questionData)).toList();
        }
        
        return [];
      } else {
        throw Exception('Failed to generate questions: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Question generation error: $e');
    }
  }

  /// Get user's credit balance
  static Future<Map<String, dynamic>> getCreditBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/user/credits'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get credit balance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Credit balance error: $e');
    }
  }

  /// Get user's purchased books library
  static Future<Map<String, dynamic>> getUserLibrary() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/user/library'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get user library: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('User library error: $e');
    }
  }

  /// Purchase a book with credits
  static Future<Map<String, dynamic>> purchaseBook(String bookId) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/bookstore/user/purchase'),
        headers: _getHeaders(),
        body: jsonEncode({
          'book_id': bookId,
          'use_credits': true,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorBody = response.body;
        throw Exception('Purchase failed: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      throw Exception('Purchase error: $e');
    }
  }

  /// Initialize credits for a new user
  static Future<Map<String, dynamic>> initializeCredits() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/bookstore/user/initialize-credits'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to initialize credits: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Credit initialization error: $e');
    }
  }
}