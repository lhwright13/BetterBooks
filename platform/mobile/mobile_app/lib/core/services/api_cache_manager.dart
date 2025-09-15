import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'logging_service.dart';

/// Manages local caching of API responses for offline access
class ApiCacheManager {
  static final ApiCacheManager _instance = ApiCacheManager._internal();
  factory ApiCacheManager() => _instance;
  ApiCacheManager._internal();

  static const String _cacheDirectory = 'api_cache';
  static const Duration _defaultCacheDuration = Duration(hours: 1);
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB
  
  Directory? _cacheDir;
  final Map<String, CacheEntry> _memoryCache = {};
  final Map<String, Duration> _cacheDurations = {
    'bookstore/browse': Duration(minutes: 30),
    'bookstore/featured': Duration(hours: 2),
    'bookstore/bestsellers': Duration(hours: 6),
    'bookstore/categories': Duration(days: 1),
    'personas': Duration(days: 1),
  };

  /// Initialize the cache manager
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheDirectory');
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      // Clean up old cache entries
      await _cleanupOldEntries();
      
      logInfo('ApiCacheManager initialized at ${_cacheDir!.path}', 
        tag: 'ApiCache');
    } catch (e) {
      logError('Failed to initialize ApiCacheManager', tag: 'ApiCache', error: e);
    }
  }

  /// Cache an API response
  Future<void> cacheResponse({
    required String endpoint,
    required Map<String, String> headers,
    required String response,
    Duration? cacheDuration,
  }) async {
    if (_cacheDir == null) return;

    try {
      final cacheKey = _generateCacheKey(endpoint, headers);
      final duration = cacheDuration ?? _getCacheDurationForEndpoint(endpoint);
      final entry = CacheEntry(
        response: response,
        timestamp: DateTime.now(),
        duration: duration,
        endpoint: endpoint,
      );

      // Store in memory cache
      _memoryCache[cacheKey] = entry;

      // Store on disk
      final cacheFile = File('${_cacheDir!.path}/$cacheKey.json');
      await cacheFile.writeAsString(jsonEncode(entry.toJson()));

      logDebug('Cached response for $endpoint (${response.length} bytes)', 
        tag: 'ApiCache');

      // Check cache size and cleanup if needed
      await _enforceMaxCacheSize();
    } catch (e) {
      logError('Failed to cache response for $endpoint', tag: 'ApiCache', error: e);
    }
  }

  /// Retrieve a cached response if available and valid
  Future<String?> getCachedResponse({
    required String endpoint,
    required Map<String, String> headers,
  }) async {
    if (_cacheDir == null) return null;

    try {
      final cacheKey = _generateCacheKey(endpoint, headers);

      // Check memory cache first
      CacheEntry? entry = _memoryCache[cacheKey];
      
      // If not in memory, try disk
      if (entry == null) {
        final cacheFile = File('${_cacheDir!.path}/$cacheKey.json');
        if (await cacheFile.exists()) {
          final entryJson = await cacheFile.readAsString();
          entry = CacheEntry.fromJson(jsonDecode(entryJson));
          _memoryCache[cacheKey] = entry; // Store in memory for faster access
        }
      }

      if (entry == null) return null;

      // Check if entry is still valid
      final now = DateTime.now();
      final expiryTime = entry.timestamp.add(entry.duration);
      
      if (now.isAfter(expiryTime)) {
        // Entry expired, remove it
        await _removeCacheEntry(cacheKey);
        logDebug('Cache entry expired for $endpoint', tag: 'ApiCache');
        return null;
      }

      logDebug('Retrieved cached response for $endpoint (${entry.response.length} bytes)', 
        tag: 'ApiCache');
      
      return entry.response;
    } catch (e) {
      logError('Failed to retrieve cached response for $endpoint', 
        tag: 'ApiCache', error: e);
      return null;
    }
  }

  /// Check if a response is cached and valid
  Future<bool> isCached({
    required String endpoint,
    required Map<String, String> headers,
  }) async {
    final cachedResponse = await getCachedResponse(
      endpoint: endpoint,
      headers: headers,
    );
    return cachedResponse != null;
  }

  /// Clear specific endpoint from cache
  Future<void> clearEndpointCache(String endpoint) async {
    if (_cacheDir == null) return;

    try {
      final keysToRemove = <String>[];
      
      // Remove from memory cache
      for (final entry in _memoryCache.entries) {
        if (entry.value.endpoint.contains(endpoint)) {
          keysToRemove.add(entry.key);
        }
      }
      
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
        
        // Remove from disk
        final cacheFile = File('${_cacheDir!.path}/$key.json');
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
      }
      
      logInfo('Cleared cache for endpoint: $endpoint', tag: 'ApiCache');
    } catch (e) {
      logError('Failed to clear cache for $endpoint', tag: 'ApiCache', error: e);
    }
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    if (_cacheDir == null) return;

    try {
      _memoryCache.clear();
      
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
      
      logInfo('All cache cleared', tag: 'ApiCache');
    } catch (e) {
      logError('Failed to clear all cache', tag: 'ApiCache', error: e);
    }
  }

  /// Get cache statistics
  Future<CacheStatistics> getStatistics() async {
    if (_cacheDir == null) {
      return CacheStatistics(
        totalEntries: 0,
        totalSizeBytes: 0,
        memoryEntries: 0,
        oldestEntry: null,
        newestEntry: null,
      );
    }

    try {
      int totalSize = 0;
      int totalEntries = 0;
      DateTime? oldestTime;
      DateTime? newestTime;

      final files = await _cacheDir!.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          final stat = await file.stat();
          totalSize += stat.size;
          totalEntries++;
          
          if (oldestTime == null || stat.modified.isBefore(oldestTime)) {
            oldestTime = stat.modified;
          }
          if (newestTime == null || stat.modified.isAfter(newestTime)) {
            newestTime = stat.modified;
          }
        }
      }

      return CacheStatistics(
        totalEntries: totalEntries,
        totalSizeBytes: totalSize,
        memoryEntries: _memoryCache.length,
        oldestEntry: oldestTime,
        newestEntry: newestTime,
      );
    } catch (e) {
      logError('Failed to get cache statistics', tag: 'ApiCache', error: e);
      return CacheStatistics(
        totalEntries: 0,
        totalSizeBytes: 0,
        memoryEntries: 0,
        oldestEntry: null,
        newestEntry: null,
      );
    }
  }

  /// Generate a cache key from endpoint and headers
  String _generateCacheKey(String endpoint, Map<String, String> headers) {
    // Create a consistent key by combining endpoint with relevant headers
    final relevantHeaders = <String, String>{};
    
    // Only include headers that affect response content
    final importantHeaders = ['Authorization', 'Accept-Language', 'User-Agent'];
    for (final header in importantHeaders) {
      if (headers.containsKey(header)) {
        relevantHeaders[header] = headers[header]!;
      }
    }
    
    final keyData = '$endpoint${jsonEncode(relevantHeaders)}';
    final bytes = utf8.encode(keyData);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Get cache duration for specific endpoint
  Duration _getCacheDurationForEndpoint(String endpoint) {
    for (final pattern in _cacheDurations.keys) {
      if (endpoint.contains(pattern)) {
        return _cacheDurations[pattern]!;
      }
    }
    return _defaultCacheDuration;
  }

  /// Remove a specific cache entry
  Future<void> _removeCacheEntry(String cacheKey) async {
    try {
      _memoryCache.remove(cacheKey);
      
      final cacheFile = File('${_cacheDir!.path}/$cacheKey.json');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (e) {
      logError('Failed to remove cache entry: $cacheKey', tag: 'ApiCache', error: e);
    }
  }

  /// Clean up expired cache entries
  Future<void> _cleanupOldEntries() async {
    if (_cacheDir == null) return;

    try {
      final files = await _cacheDir!.list().toList();
      final now = DateTime.now();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final entryJson = await file.readAsString();
            final entry = CacheEntry.fromJson(jsonDecode(entryJson));
            
            if (now.isAfter(entry.timestamp.add(entry.duration))) {
              await file.delete();
              logDebug('Removed expired cache entry: ${file.path}', tag: 'ApiCache');
            }
          } catch (e) {
            // If we can't read the entry, delete it
            await file.delete();
            logDebug('Removed corrupted cache entry: ${file.path}', tag: 'ApiCache');
          }
        }
      }
      
      logInfo('Cache cleanup completed', tag: 'ApiCache');
    } catch (e) {
      logError('Failed to cleanup cache', tag: 'ApiCache', error: e);
    }
  }

  /// Enforce maximum cache size by removing oldest entries
  Future<void> _enforceMaxCacheSize() async {
    if (_cacheDir == null) return;

    try {
      final stats = await getStatistics();
      if (stats.totalSizeBytes <= _maxCacheSize) return;

      logInfo('Cache size (${stats.totalSizeBytes} bytes) exceeds limit ($_maxCacheSize bytes), cleaning up', 
        tag: 'ApiCache');

      // Get all files sorted by modification time (oldest first)
      final files = await _cacheDir!.list().toList();
      final fileStats = <FileSystemEntity, FileStat>{};
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          fileStats[file] = await file.stat();
        }
      }
      
      final sortedFiles = fileStats.entries.toList()
        ..sort((a, b) => a.value.modified.compareTo(b.value.modified));

      // Remove oldest files until we're under the limit
      int currentSize = stats.totalSizeBytes;
      for (final entry in sortedFiles) {
        if (currentSize <= _maxCacheSize * 0.8) break; // Remove to 80% of limit
        
        await entry.key.delete();
        currentSize -= entry.value.size;
        logDebug('Removed cache file for size limit: ${entry.key.path}', tag: 'ApiCache');
      }
      
      // Clear memory cache of deleted files
      _memoryCache.clear();
      
      logInfo('Cache size reduced to approximately $currentSize bytes', tag: 'ApiCache');
    } catch (e) {
      logError('Failed to enforce cache size limit', tag: 'ApiCache', error: e);
    }
  }

  /// Dispose resources
  void dispose() {
    _memoryCache.clear();
    logInfo('ApiCacheManager disposed', tag: 'ApiCache');
  }
}

/// Represents a cached API response
class CacheEntry {
  final String response;
  final DateTime timestamp;
  final Duration duration;
  final String endpoint;

  const CacheEntry({
    required this.response,
    required this.timestamp,
    required this.duration,
    required this.endpoint,
  });

  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      response: json['response'],
      timestamp: DateTime.parse(json['timestamp']),
      duration: Duration(milliseconds: json['duration']),
      endpoint: json['endpoint'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'response': response,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration.inMilliseconds,
      'endpoint': endpoint,
    };
  }
}

/// Cache statistics information
class CacheStatistics {
  final int totalEntries;
  final int totalSizeBytes;
  final int memoryEntries;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;

  const CacheStatistics({
    required this.totalEntries,
    required this.totalSizeBytes,
    required this.memoryEntries,
    this.oldestEntry,
    this.newestEntry,
  });

  String get formattedSize {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Global API cache manager instance
final apiCacheManager = ApiCacheManager();