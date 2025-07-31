/**
 * api_service.dart - HTTP client service for Muuchi backend communication
 * 
 * This file provides the primary interface between the Flutter mobile app and
 * the Muuchi backend services. It handles all HTTP communication including
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

/// Service class for all HTTP communication with Muuchi backend services
/// Provides methods for books, personas, chat, TTS, and context operations
class ApiService {
  static const Duration _timeoutDuration = Duration(seconds: 30); // Network timeout for all requests

  /// Tests connectivity to the Muuchi backend API Gateway
  /// Returns true if the health endpoint responds successfully
  /// Used to verify network connectivity before making other API calls
  static Future<bool> testConnection() async {
    try {
      print('Testing connection to: $apiBaseUrl/health');
      final response = await http.get(
        Uri.parse('$apiBaseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);
      
      print('Health check response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  /// Fetches the complete audiobook catalog from the backend
  /// Returns a list of Book objects with streaming URLs and metadata
  /// Handles both single-file audiobooks and multi-chapter books
  static Future<List<Book>> getBooks() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/list'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final books = <Book>[];
        
        print('API Response: $data');
        
        // Handle single-file audiobooks (e.g., standalone MP3 files)
        if (data['single_books'] != null) {
          for (final bookData in data['single_books']) {
            books.add(Book.fromJson({
              'id': bookData,
              'title': bookData.replaceAll('.mp3', ''), // Clean filename for display
              'audio_url': '$apiBaseUrl/books/play/$bookData', // Direct streaming URL
            }));
          }
        }
        
        // Handle multi-chapter audiobooks (e.g., The Great Gatsby with Chapter 1.mp3, etc.)
        if (data['chapter_books'] != null) {
          for (final bookData in data['chapter_books']) {
            final bookName = bookData['name'] as String;
            final chapterFiles = bookData['chapters'] as List<dynamic>;
            
            // Convert chapter file list to Chapter objects with streaming URLs
            final chapters = chapterFiles.map((chapterFile) {
              final chapterFileName = chapterFile.toString();
              // Extract chapter number from filename (e.g., "Chapter 1.mp3" -> 1)
              final chapterNum = int.tryParse(
                chapterFileName.split(' ').last.replaceAll('.mp3', '')
              ) ?? 0;
              return Chapter(
                id: chapterFileName,
                title: chapterFileName.replaceAll('.mp3', ''),
                // URL encode components for safe HTTP URLs
                audioUrl: '$apiBaseUrl/books/play/${Uri.encodeComponent(bookName)}/${Uri.encodeComponent(chapterFileName)}',
                chapterNumber: chapterNum,
              );
            }).toList();
            
            books.add(Book(
              id: bookName,
              title: bookName,
              chapters: chapters,
            ));
          }
        }
        
        return books;
      } else {
        throw Exception('Failed to load books: ${response.statusCode}');
      }
    } catch (e) {
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'book_name': bookName,
          'chapter_name': chapterName,
          'current_position': currentPosition,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['context'] ?? '';
      } else {
        throw Exception('Failed to get context: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}