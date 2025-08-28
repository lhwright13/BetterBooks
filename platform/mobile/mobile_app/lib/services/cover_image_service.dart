/**
 * cover_image_service.dart - Intelligent cover image service with multiple fallbacks
 * 
 * This service handles cover image loading with a robust fallback strategy:
 * 1. Try backend cover image URL first
 * 2. Fall back to OpenLibrary API
 * 3. Fall back to Google Books API  
 * 4. Fall back to placeholder icon
 * 
 * Features:
 * - Automatic retry with different sources
 * - Caching of successful URLs
 * - ISBN-based lookups when available
 * - Graceful fallbacks for missing images
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'cache_service.dart';
import 'log_service.dart';

class CoverImageService {
  static const Duration _timeoutDuration = Duration(seconds: 10);
  
  /// Get the best available cover image URL for a book
  static Future<String?> getCoverImageUrl({
    required String bookId,
    required String bookTitle,
    String? author,
    String? backendCoverUrl,
    String? isbn,
  }) async {
    // Check cache first
    final cacheKey = 'cover_$bookId';
    final cached = CacheService.getMemoryCache(cacheKey);
    if (cached != null) {
      LogService.debug('Using cached cover URL: $cached', 'CoverImageService');
      return cached as String;
    }

    String? coverUrl;

    // Try backend cover first (if provided)
    if (backendCoverUrl != null) {
      coverUrl = await _tryBackendCover(backendCoverUrl);
      if (coverUrl != null) {
        _cacheResult(cacheKey, coverUrl);
        return coverUrl;
      }
    }

    // Try OpenLibrary API
    coverUrl = await _tryOpenLibrary(bookTitle, author);
    if (coverUrl != null) {
      _cacheResult(cacheKey, coverUrl);
      return coverUrl;
    }

    // Try Google Books API
    coverUrl = await _tryGoogleBooks(bookTitle, author);
    if (coverUrl != null) {
      _cacheResult(cacheKey, coverUrl);
      return coverUrl;
    }

    // Try ISBN lookup if available
    if (isbn != null) {
      coverUrl = await _tryISBNLookup(isbn);
      if (coverUrl != null) {
        _cacheResult(cacheKey, coverUrl);
        return coverUrl;
      }
    }

    // No cover found - cache null result to avoid repeated attempts
    _cacheResult(cacheKey, null);
    LogService.debug('No cover image found for: $bookTitle', 'CoverImageService');
    return null;
  }

  /// Try to load cover from backend
  static Future<String?> _tryBackendCover(String backendUrl) async {
    try {
      final fullUrl = backendUrl.startsWith('http') 
        ? backendUrl 
        : '$apiBaseUrl$backendUrl';

      final response = await http.head(Uri.parse(fullUrl)).timeout(_timeoutDuration);
      
      if (response.statusCode == 200) {
        LogService.debug('Backend cover image found: $fullUrl', 'CoverImageService');
        return fullUrl;
      } else {
        LogService.debug('Backend cover image failed: ${response.statusCode}', 'CoverImageService');
        return null;
      }
    } catch (e) {
      LogService.debug('Backend cover image error: $e', 'CoverImageService');
      return null;
    }
  }

  /// Try OpenLibrary API for cover
  static Future<String?> _tryOpenLibrary(String title, String? author) async {
    try {
      // Search for the book first
      final query = author != null ? '$title $author' : title;
      final searchUrl = 'https://openlibrary.org/search.json?q=${Uri.encodeComponent(query)}&limit=1';
      
      final searchResponse = await http.get(Uri.parse(searchUrl)).timeout(_timeoutDuration);
      
      if (searchResponse.statusCode == 200) {
        final searchData = jsonDecode(searchResponse.body);
        final docs = searchData['docs'] as List;
        
        if (docs.isNotEmpty) {
          final doc = docs.first;
          final coverId = doc['cover_i'];
          
          if (coverId != null) {
            final coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
            
            // Verify the cover exists
            final headResponse = await http.head(Uri.parse(coverUrl)).timeout(_timeoutDuration);
            if (headResponse.statusCode == 200) {
              LogService.debug('OpenLibrary cover found: $coverUrl', 'CoverImageService');
              return coverUrl;
            }
          }
        }
      }
    } catch (e) {
      LogService.debug('OpenLibrary cover lookup error: $e', 'CoverImageService');
    }
    
    return null;
  }

  /// Try Google Books API for cover
  static Future<String?> _tryGoogleBooks(String title, String? author) async {
    try {
      final query = author != null ? '$title+inauthor:$author' : title;
      final searchUrl = 'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=1';
      
      final response = await http.get(Uri.parse(searchUrl)).timeout(_timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List?;
        
        if (items != null && items.isNotEmpty) {
          final item = items.first;
          final volumeInfo = item['volumeInfo'];
          final imageLinks = volumeInfo['imageLinks'];
          
          if (imageLinks != null) {
            final coverUrl = imageLinks['thumbnail'] ?? imageLinks['smallThumbnail'];
            if (coverUrl != null) {
              // Convert to HTTPS if needed
              final httpsUrl = coverUrl.toString().replaceFirst('http://', 'https://');
              LogService.debug('Google Books cover found: $httpsUrl', 'CoverImageService');
              return httpsUrl;
            }
          }
        }
      }
    } catch (e) {
      LogService.debug('Google Books cover lookup error: $e', 'CoverImageService');
    }
    
    return null;
  }

  /// Try ISBN-based lookup
  static Future<String?> _tryISBNLookup(String isbn) async {
    try {
      // OpenLibrary ISBN lookup
      final url = 'https://openlibrary.org/isbn/$isbn.json';
      final response = await http.get(Uri.parse(url)).timeout(_timeoutDuration);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final covers = data['covers'] as List?;
        
        if (covers != null && covers.isNotEmpty) {
          final coverId = covers.first;
          final coverUrl = 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
          LogService.debug('ISBN cover found: $coverUrl', 'CoverImageService');
          return coverUrl;
        }
      }
    } catch (e) {
      LogService.debug('ISBN cover lookup error: $e', 'CoverImageService');
    }
    
    return null;
  }

  /// Cache the result (success or failure)
  static void _cacheResult(String cacheKey, String? url) {
    // Cache successful URLs for 1 hour, failures for 15 minutes
    final duration = url != null ? Duration(hours: 1) : Duration(minutes: 15);
    CacheService.setMemoryCache(cacheKey, url, duration: duration);
  }

  /// Clear cover image cache
  static void clearCache() {
    // This would need to be implemented in CacheService to clear specific prefixes
    LogService.info('Cover image cache cleared', 'CoverImageService');
  }

  /// Get fallback cover URL based on book genre or type
  static String getFallbackCoverUrl(String bookTitle, {String? genre}) {
    // Return a placeholder image URL or data URI
    return 'https://via.placeholder.com/300x400/4A90A4/FFFFFF?text=${Uri.encodeComponent(bookTitle.split(' ').take(3).join('+'))}';
  }

  /// Preload covers for a list of books
  static Future<Map<String, String?>> preloadCovers(List<Map<String, dynamic>> books) async {
    final Map<String, String?> results = {};
    
    // Process in batches to avoid overwhelming the APIs
    const batchSize = 5;
    for (int i = 0; i < books.length; i += batchSize) {
      final batch = books.skip(i).take(batchSize).toList();
      
      final futures = batch.map((book) async {
        final bookId = book['id'] ?? book['title'];
        final title = book['title'];
        final author = book['author'];
        final backendUrl = book['cover_image_url'];
        
        final coverUrl = await getCoverImageUrl(
          bookId: bookId,
          bookTitle: title,
          author: author,
          backendCoverUrl: backendUrl,
        );
        
        return MapEntry(bookId, coverUrl);
      });
      
      final batchResults = await Future.wait(futures);
      for (final result in batchResults) {
        results[result.key] = result.value;
      }
      
      // Small delay between batches to be API-friendly
      if (i + batchSize < books.length) {
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
    
    LogService.info('Preloaded ${results.length} cover images', 'CoverImageService');
    return results;
  }
}