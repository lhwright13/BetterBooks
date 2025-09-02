import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/persona.dart';
import 'cache_service.dart';

class OptimizedApiService {
  static const Duration _timeoutDuration = Duration(seconds: 30);
  static const Duration _shortTimeout = Duration(seconds: 10);
  
  // Connection pool simulation (reuse HTTP client)
  static final http.Client _client = http.Client();
  
  /// Optimized book loading with caching
  static Future<Map<String, dynamic>> getBooks({bool forceRefresh = false}) async {
    final cacheKey = 'books_list';
    
    // Check cache first unless forced refresh
    if (!forceRefresh) {
      final cached = await CacheService.getCachedBookList();
      if (cached != null) {
        print('DEBUG: Using cached book list (${cached.length} books)');
        return {'single_books': [], 'chapter_books': cached};
      }
    }
    
    try {
      print('DEBUG: Fetching fresh book list from API');
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/books'),
        headers: {'Accept': 'application/json'},
      ).timeout(_shortTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Cache the successful response
        await CacheService.cacheBookList(data['chapter_books'] ?? []);
        
        return data;
      } else {
        throw Exception('Failed to load books: ${response.statusCode}');
      }
    } catch (e) {
      // Try to return cached data on error
      final cached = await CacheService.getCachedBookList();
      if (cached != null) {
        print('DEBUG: API failed, using cached book list');
        return {'single_books': [], 'chapter_books': cached};
      }
      throw Exception('Network error: $e');
    }
  }
  
  /// Optimized AI chat with intelligent caching
  static Future<String> sendMessage(String message, String persona, {bool useCache = true}) async {
    // Check for cached response first
    if (useCache) {
      final cached = await CacheService.getCachedAIResponse(message, persona);
      if (cached != null) {
        print('DEBUG: Using cached AI response');
        return cached;
      }
    }
    
    // Optimize the message context for better performance
    final optimizedMessage = _optimizeMessageContext(message);
    
    try {
      final response = await _client.post(
        Uri.parse('$apiBaseUrl/llm/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'message': optimizedMessage,
          'persona': persona,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['response'] ?? data['message'] ?? 'No response received';
        
        // Cache successful AI responses
        await CacheService.cacheAIResponse(message, persona, aiResponse);
        
        return aiResponse;
      } else {
        throw Exception('Failed to get AI response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// Optimized TTS with response caching
  static Future<String> synthesizeSpeech(String text, String persona) async {
    final cacheKey = 'tts_${text.hashCode}_$persona';
    
    // Check memory cache for TTS audio (short-term)
    final cached = CacheService.getMemoryCache(cacheKey);
    if (cached != null) {
      print('DEBUG: Using cached TTS audio');
      return cached;
    }
    
    try {
      final response = await _client.post(
        Uri.parse('$apiBaseUrl/tts/synthesize'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'persona': persona,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioData = data['audio'] ?? '';
        
        // Cache TTS audio in memory (5 minutes)
        CacheService.setMemoryCache(cacheKey, audioData, duration: Duration(minutes: 5));
        
        return audioData;
      } else {
        throw Exception('Failed to synthesize speech: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// Batch request optimization for multiple operations
  static Future<Map<String, dynamic>> batchRequest(List<Map<String, dynamic>> requests) async {
    try {
      final response = await _client.post(
        Uri.parse('$apiBaseUrl/batch'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'requests': requests}),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Batch request failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// Optimized persona loading with caching
  static Future<List<Persona>> getPersonas() async {
    const cacheKey = 'personas_list';
    
    // Check memory cache first
    final cached = CacheService.getMemoryCache(cacheKey);
    if (cached != null) {
      return (cached as List).map((p) => Persona.fromJson(p)).toList();
    }
    
    try {
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/personas'),
        headers: {'Accept': 'application/json'},
      ).timeout(_shortTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final personas = (data['personas'] as List)
            .map((p) => Persona.fromJson(p))
            .toList();
        
        // Cache personas for 1 hour
        CacheService.setMemoryCache(cacheKey, data['personas'], duration: Duration(hours: 1));
        
        return personas;
      } else {
        throw Exception('Failed to load personas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  /// Optimize message context by removing redundant information
  static String _optimizeMessageContext(String message) {
    // Remove excessive whitespace
    String optimized = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Truncate very long contexts (keep last 2000 chars for relevance)
    if (optimized.length > 2000) {
      optimized = '...' + optimized.substring(optimized.length - 2000);
    }
    
    return optimized;
  }
  
  /// Get book-specific personas from API Gateway
  static Future<List<Persona>> getBookPersonas(String bookId) async {
    try {
      print('DEBUG: Fetching personas for book: $bookId');
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/bookstore/books/$bookId/personas'),
        headers: {'Accept': 'application/json'},
      ).timeout(_shortTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final personasList = data['personas'] as List;
        
        final personas = personasList.map((personaData) {
          return Persona.fromJson(personaData);
        }).toList();
        
        // Sort by sort_order and then by display name
        personas.sort((a, b) {
          if (a.sortOrder != b.sortOrder) {
            return a.sortOrder.compareTo(b.sortOrder);
          }
          return a.displayName.compareTo(b.displayName);
        });
        
        print('DEBUG: Loaded ${personas.length} personas for ${data['book_title']}');
        return personas;
      } else if (response.statusCode == 404) {
        print('DEBUG: Book not found or no personas available');
        return [];
      } else {
        throw Exception('Failed to load book personas: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error loading book personas: $e');
      // Return fallback personas for MVP
      return _getFallbackPersonas();
    }
  }

  /// Get all available personas (global and book-specific)
  static Future<List<Persona>> getAllPersonas() async {
    try {
      print('DEBUG: Fetching all personas');
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/personas'),
        headers: {'Accept': 'application/json'},
      ).timeout(_shortTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final personasList = data['personas'] as List;
        
        final personas = personasList.map((personaData) {
          return Persona.fromJson(personaData);
        }).toList();
        
        print('DEBUG: Loaded ${personas.length} total personas');
        return personas;
      } else {
        throw Exception('Failed to load personas: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Error loading personas: $e');
      // Return fallback personas for MVP
      return _getFallbackPersonas();
    }
  }

  /// Fallback personas for offline/error scenarios
  static List<Persona> _getFallbackPersonas() {
    return [
      Persona(
        id: 'fallback-nick',
        name: 'Nick Carraway',
        displayName: 'Nick Carraway',
        description: 'The narrator of The Great Gatsby - observant and literary',
        voice: 'en-US-Neural2-J',
        voiceConfig: {},
        generationConfig: {},
        ttsConfig: {},
        isGlobal: false,
        isDefault: true,
      ),
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
        isDefault: false,
      ),
      Persona(
        id: 'fallback-tutor',
        name: 'Language Tutor',
        displayName: 'Language Tutor',
        description: 'Patient instructor for language learning and practice',
        voice: 'en-US-Neural2-F',
        voiceConfig: {},
        generationConfig: {},
        ttsConfig: {},
        isGlobal: true,
        isDefault: false,
      ),
      Persona(
        id: 'fallback-helper',
        name: 'Omniscient Helper',
        displayName: 'Omniscient Helper',
        description: 'Knowledgeable assistant for general questions and guidance',
        voice: 'en-US-Neural2-A',
        voiceConfig: {},
        generationConfig: {},
        ttsConfig: {},
        isGlobal: true,
        isDefault: false,
      ),
    ];
  }

  /// Get connection health with quick timeout
  static Future<bool> isHealthy() async {
    try {
      final response = await _client.get(
        Uri.parse('$apiBaseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Cleanup method to dispose resources
  static void dispose() {
    _client.close();
  }
}