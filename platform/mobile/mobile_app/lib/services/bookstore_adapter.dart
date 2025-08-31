/// Adapter service that connects the bookstore UI to the real Azure backend
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/bookstore_models.dart';
import 'cache_service.dart';
import 'log_service.dart';
import 'api_service.dart';

/// Adapter class that connects to the real Azure backend bookstore API
class BookstoreAdapter {
  static const Duration _timeoutDuration = Duration(seconds: 30);

  /// Get headers for HTTP requests including auth if available
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    final authToken = ApiService.getAuthToken();
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    
    return headers;
  }

  /// Browse books with filtering options
  Future<BrowseResponse> browseBooks({
    bool? featuredOnly,
    bool? bestsellersOnly,
    bool? newReleasesOnly,
    String? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    // Check cache first
    final cacheKey = 'browse_${featuredOnly}_${bestsellersOnly}_${newReleasesOnly}_${categoryId}_${page}_$pageSize';
    final cached = CacheService.getMemoryCache(cacheKey);
    if (cached != null) {
      LogService.debug('Using cached browse response: $cacheKey', 'BookstoreAdapter');
      return cached as BrowseResponse;
    }

    try {
      final uri = Uri.parse('$apiBaseUrl/bookstore/browse').replace(queryParameters: {
        if (featuredOnly == true) 'featured': 'true',
        if (bestsellersOnly == true) 'bestsellers': 'true', 
        if (newReleasesOnly == true) 'new_releases': 'true',
        if (categoryId != null) 'category': categoryId,
        'page': page.toString(),
        'limit': pageSize.toString(),
      });

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final browseResponse = BrowseResponse.fromJson(data);
        
        // Cache the successful response
        CacheService.setMemoryCache(cacheKey, browseResponse, duration: Duration(minutes: 30));
        LogService.debug('Cached browse response: $cacheKey', 'BookstoreAdapter');
        
        return browseResponse;
      } else {
        throw Exception('Failed to browse books: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      LogService.error('Browse books error: $e', 'BookstoreAdapter');
      
      // Try to return a fallback empty response instead of throwing
      return BrowseResponse(
        books: [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
        hasNextPage: false,
      );
    }
  }

  /// Search books by query
  Future<BrowseResponse> searchBooks({
    required String query,
    String? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    // Check cache first
    final cacheKey = 'search_${query}_${categoryId}_${page}_$pageSize';
    final cached = CacheService.getMemoryCache(cacheKey);
    if (cached != null) {
      LogService.debug('Using cached search response: $cacheKey', 'BookstoreAdapter');
      return cached as BrowseResponse;
    }

    try {
      final uri = Uri.parse('$apiBaseUrl/bookstore/search').replace(queryParameters: {
        'q': query,
        if (categoryId != null) 'category': categoryId,
        'page': page.toString(),
        'limit': pageSize.toString(),
      });

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final searchResponse = BrowseResponse.fromJson(data);
        
        // Cache the successful response for shorter duration (search results may change more frequently)
        CacheService.setMemoryCache(cacheKey, searchResponse, duration: Duration(minutes: 15));
        LogService.debug('Cached search response: $cacheKey', 'BookstoreAdapter');
        
        return searchResponse;
      } else {
        throw Exception('Failed to search books: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      LogService.error('Search books error: $e', 'BookstoreAdapter');
      
      // Return empty search results instead of throwing
      return BrowseResponse(
        books: [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
        hasNextPage: false,
      );
    }
  }

  /// Get book categories
  Future<List<BookCategory>> getCategories() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/bookstore/categories'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(_timeoutDuration);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['categories'] as List)
          .map((cat) => BookCategory.fromJson(cat))
          .toList();
    } else {
      throw Exception('Failed to get categories: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get book details by ID
  Future<BookCatalog> getBookDetails(String bookId) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/bookstore/books/$bookId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(_timeoutDuration);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return BookCatalog.fromJson(data);
    } else {
      throw Exception('Failed to get book details: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get credit balance
  Future<CreditBalanceResponse> getCreditBalance() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/bookstore/user/credits'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(_timeoutDuration);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return CreditBalanceResponse(
        totalCredits: data['total_credits'] ?? 0,
        usedCredits: data['used_credits'] ?? 0,
        availableCredits: data['available_credits'] ?? 0,
        lastUpdated: DateTime.parse(data['last_updated'] ?? DateTime.now().toIso8601String()),
      );
    } else {
      throw Exception('Failed to get credit balance: ${response.statusCode} - ${response.body}');
    }
  }

  /// Purchase a book
  Future<PurchaseResponse> purchaseBook({
    required String bookId,
    PurchaseType paymentMethod = PurchaseType.credit,
    int? creditsToUse,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/bookstore/purchase'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'book_id': bookId,
        'payment_method': paymentMethod.toString(),
        if (creditsToUse != null) 'credits_to_use': creditsToUse,
      }),
    ).timeout(_timeoutDuration);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return PurchaseResponse(
        success: data['success'] ?? true,
        transactionId: data['transaction_id'] ?? data['purchase_id'],
        remainingCredits: data['remaining_credits'] ?? 0,
      );
    } else {
      throw Exception('Failed to purchase book: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get user's purchased books (library)
  Future<List<BookCatalog>> getUserLibrary(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/user/library'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['books'] as List)
            .map((book) => BookCatalog.fromJson(book))
            .toList();
      } else if (response.statusCode == 500) {
        // Backend library endpoint is broken - return empty library for now
        LogService.debug('Library endpoint returned 500, returning empty library', 'BookstoreAdapter');
        return [];
      } else {
        LogService.debug('Failed to get user library: ${response.statusCode} - ${response.body}', 'BookstoreAdapter');
        return [];
      }
    } catch (e) {
      // Network error or other issues - return empty library as fallback
      LogService.debug('Library network error, returning empty library: $e', 'BookstoreAdapter');
      return [];
    }
  }

}