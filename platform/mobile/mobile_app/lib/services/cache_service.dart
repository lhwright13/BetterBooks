import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const Duration _defaultCacheDuration = Duration(hours: 1);
  static const Duration _aiResponseCacheDuration = Duration(hours: 24);
  
  static final Map<String, CacheEntry> _memoryCache = {};
  
  // Memory cache entry
  static void setMemoryCache(String key, dynamic value, {Duration? duration}) {
    final expiry = DateTime.now().add(duration ?? _defaultCacheDuration);
    _memoryCache[key] = CacheEntry(value: value, expiry: expiry);
  }
  
  static dynamic getMemoryCache(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    
    if (DateTime.now().isAfter(entry.expiry)) {
      _memoryCache.remove(key);
      return null;
    }
    
    return entry.value;
  }
  
  // Persistent cache for AI responses
  static Future<void> cacheAIResponse(String prompt, String persona, String response) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _generateAIKey(prompt, persona);
    final data = {
      'response': response,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(key, jsonEncode(data));
  }
  
  static Future<String?> getCachedAIResponse(String prompt, String persona) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _generateAIKey(prompt, persona);
    final cached = prefs.getString(key);
    
    if (cached == null) return null;
    
    final data = jsonDecode(cached);
    final timestamp = DateTime.parse(data['timestamp']);
    
    // Check if cache is still valid
    if (DateTime.now().difference(timestamp) > _aiResponseCacheDuration) {
      await prefs.remove(key);
      return null;
    }
    
    return data['response'];
  }
  
  // Book list caching
  static Future<void> cacheBookList(List<dynamic> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_books', jsonEncode(books));
    await prefs.setString('books_cache_time', DateTime.now().toIso8601String());
  }
  
  static Future<List<dynamic>?> getCachedBookList() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_books');
    final cacheTime = prefs.getString('books_cache_time');
    
    if (cached == null || cacheTime == null) return null;
    
    final timestamp = DateTime.parse(cacheTime);
    if (DateTime.now().difference(timestamp) > Duration(minutes: 30)) {
      return null; // Cache expired
    }
    
    return jsonDecode(cached);
  }
  
  static String _generateAIKey(String prompt, String persona) {
    final hash = '${prompt.hashCode}_${persona.hashCode}';
    return 'ai_cache_$hash';
  }
  
  // Clear all caches
  static Future<void> clearCache() async {
    _memoryCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => 
      key.startsWith('ai_cache_') || 
      key == 'cached_books' || 
      key == 'books_cache_time'
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

class CacheEntry {
  final dynamic value;
  final DateTime expiry;
  
  CacheEntry({required this.value, required this.expiry});
}