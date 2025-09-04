/**
 * cover_image_service.dart - Cover image service using Azure cloud storage only
 * 
 * This service loads cover images exclusively from our Azure blob storage:
 * 1. Try backend cover image URL (Azure storage)
 * 2. Return placeholder if not available
 * 
 * Features:
 * - Azure-only cover loading
 * - Caching of successful URLs
 * - No external API dependencies
 * - Graceful fallbacks to placeholder
 */

import '../api_config.dart';
import 'cache_service.dart';
import 'log_service.dart';

class CoverImageService {
  
  /// Get cover image URL from Azure cloud storage only
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

    // Try backend cover only (Azure cloud storage)
    if (backendCoverUrl != null) {
      coverUrl = await _tryBackendCover(backendCoverUrl);
      if (coverUrl != null) {
        _cacheResult(cacheKey, coverUrl);
        return coverUrl;
      }
    }

    // No Azure cover found - cache null result and return null
    _cacheResult(cacheKey, null);
    LogService.debug('No Azure cover image found for: $bookTitle', 'CoverImageService');
    return null;
  }

  /// Try to load cover from backend
  static Future<String?> _tryBackendCover(String backendUrl) async {
    try {
      final fullUrl = backendUrl.startsWith('http') 
        ? backendUrl 
        : '$apiBaseUrl$backendUrl';

      // Backend handles redirects to Azure storage - trust the URL
      LogService.debug('Using backend cover image: $fullUrl', 'CoverImageService');
      return fullUrl;
    } catch (e) {
      LogService.debug('Backend cover image error: $e', 'CoverImageService');
      return null;
    }
  }

  // All external API fallbacks removed - using Azure cloud storage only

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
  static String? getFallbackCoverUrl(String bookTitle, {String? genre}) {
    // No external placeholder APIs - return null for proper error handling
    // The UI should handle null covers with proper placeholder widgets
    return null;
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