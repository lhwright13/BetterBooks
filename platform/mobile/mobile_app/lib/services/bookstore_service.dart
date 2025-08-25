import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/bookstore_models.dart';
import '../api_config.dart';
import 'auth_service.dart';

/// Service for interacting with the bookstore API
/// Provides methods for browsing, purchasing, and managing audiobooks
class BookstoreService extends ChangeNotifier {
  static final BookstoreService _instance = BookstoreService._internal();
  factory BookstoreService() => _instance;
  BookstoreService._internal();

  final http.Client _client = http.Client();

  // Cache for frequently accessed data
  List<BookCategory>? _cachedCategories;
  List<BookCatalog>? _cachedFeaturedBooks;
  List<UserPurchase>? _cachedPurchases;
  UserCredit? _cachedCredits;
  DateTime? _lastCacheUpdate;

  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Check if cache is valid
  bool get _isCacheValid =>
      _lastCacheUpdate != null &&
      DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;

  /// Get authorization headers for API requests
  Future<Map<String, String>> get _authHeaders async {
    final token = await AuthService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Browse books with optional filtering and pagination
  Future<BrowseResponse> browseBooks({
    String? categoryId,
    bool featuredOnly = false,
    bool bestsellersOnly = false,
    bool newReleasesOnly = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final headers = await _authHeaders;
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (categoryId != null) 'category_id': categoryId,
        if (featuredOnly) 'featured_only': 'true',
        if (bestsellersOnly) 'bestsellers_only': 'true',
        if (newReleasesOnly) 'new_releases_only': 'true',
      };

      final uri = Uri.parse('$apiBaseUrl/bookstore/browse')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return BrowseResponse.fromJson(jsonData);
      } else {
        throw BookstoreException(
          'Failed to browse books: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error browsing books: $e');
      throw BookstoreException('Failed to browse books: $e');
    }
  }

  /// Search books by query with optional filters
  Future<BrowseResponse> searchBooks({
    required String query,
    String? categoryId,
    String? author,
    String? narrator,
    double? minRating,
    int? maxDurationHours,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final headers = await _authHeaders;
      final queryParams = <String, String>{
        'q': query,
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (categoryId != null) 'category_id': categoryId,
        if (author != null) 'author': author,
        if (narrator != null) 'narrator': narrator,
        if (minRating != null) 'min_rating': minRating.toString(),
        if (maxDurationHours != null) 'max_duration_hours': maxDurationHours.toString(),
      };

      final uri = Uri.parse('$apiBaseUrl/bookstore/search')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return BrowseResponse.fromJson(jsonData);
      } else {
        throw BookstoreException(
          'Failed to search books: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error searching books: $e');
      throw BookstoreException('Failed to search books: $e');
    }
  }

  /// Get detailed information about a specific book
  Future<BookCatalog> getBookDetails(String bookId) async {
    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/books/$bookId');

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return BookCatalog.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw BookstoreException('Book not found', 404);
      } else {
        throw BookstoreException(
          'Failed to get book details: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting book details: $e');
      throw BookstoreException('Failed to get book details: $e');
    }
  }

  /// Get all available book categories
  Future<List<BookCategory>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategories != null && _isCacheValid) {
      return _cachedCategories!;
    }

    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/categories');

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final categories = (jsonData['categories'] as List<dynamic>)
            .map((category) => BookCategory.fromJson(category))
            .toList();

        _cachedCategories = categories;
        _lastCacheUpdate = DateTime.now();
        return categories;
      } else {
        throw BookstoreException(
          'Failed to get categories: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting categories: $e');
      throw BookstoreException('Failed to get categories: $e');
    }
  }

  /// Purchase a book using credits or direct payment
  Future<PurchaseResponse> purchaseBook(PurchaseRequest request) async {
    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/purchase');

      final response = await _client.post(
        uri,
        headers: headers,
        body: json.encode(request.toJson()),
      );

      final jsonData = json.decode(response.body);

      if (response.statusCode == 200) {
        final purchaseResponse = PurchaseResponse.fromJson(jsonData);
        
        // Clear cache to force refresh of purchases and credits
        _cachedPurchases = null;
        _cachedCredits = null;
        
        notifyListeners();
        return purchaseResponse;
      } else {
        throw BookstoreException(
          jsonData['error_message'] ?? 'Failed to purchase book',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error purchasing book: $e');
      throw BookstoreException('Failed to purchase book: $e');
    }
  }

  /// Get user's credit balance
  Future<CreditBalanceResponse> getCreditBalance({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCredits != null && _isCacheValid) {
      return CreditBalanceResponse(
        availableCredits: _cachedCredits!.availableCredits,
        totalCredits: _cachedCredits!.totalCredits,
        usedCredits: _cachedCredits!.usedCredits,
        lastUpdated: _cachedCredits!.lastUpdated,
      );
    }

    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/credits/balance');

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final creditBalance = CreditBalanceResponse.fromJson(jsonData);
        
        _cachedCredits = UserCredit(
          id: 'current',
          userId: 'current',
          totalCredits: creditBalance.totalCredits,
          usedCredits: creditBalance.usedCredits,
          lastUpdated: creditBalance.lastUpdated,
        );
        _lastCacheUpdate = DateTime.now();
        
        return creditBalance;
      } else {
        throw BookstoreException(
          'Failed to get credit balance: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting credit balance: $e');
      throw BookstoreException('Failed to get credit balance: $e');
    }
  }

  /// Get user's purchase history
  Future<List<UserPurchase>> getPurchaseHistory({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedPurchases != null && _isCacheValid) {
      return _cachedPurchases!;
    }

    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/purchases');

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final purchases = (jsonData['purchases'] as List<dynamic>)
            .map((purchase) => UserPurchase.fromJson(purchase))
            .toList();

        _cachedPurchases = purchases;
        _lastCacheUpdate = DateTime.now();
        return purchases;
      } else {
        throw BookstoreException(
          'Failed to get purchase history: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting purchase history: $e');
      throw BookstoreException('Failed to get purchase history: $e');
    }
  }

  /// Check if user owns a specific book
  Future<bool> ownsBook(String bookId) async {
    try {
      final purchases = await getPurchaseHistory();
      return purchases.any((purchase) => purchase.bookId == bookId);
    } catch (e) {
      debugPrint('Error checking book ownership: $e');
      return false;
    }
  }

  /// Add book to wishlist
  Future<bool> addToWishlist(String bookId) async {
    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/wishlist');

      final response = await _client.post(
        uri,
        headers: headers,
        body: json.encode({'book_id': bookId}),
      );

      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      } else {
        final jsonData = json.decode(response.body);
        throw BookstoreException(
          jsonData['error_message'] ?? 'Failed to add to wishlist',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error adding to wishlist: $e');
      throw BookstoreException('Failed to add to wishlist: $e');
    }
  }

  /// Remove book from wishlist
  Future<bool> removeFromWishlist(String bookId) async {
    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/wishlist/$bookId');

      final response = await _client.delete(uri, headers: headers);

      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      } else {
        final jsonData = json.decode(response.body);
        throw BookstoreException(
          jsonData['error_message'] ?? 'Failed to remove from wishlist',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error removing from wishlist: $e');
      throw BookstoreException('Failed to remove from wishlist: $e');
    }
  }

  /// Get user's wishlist
  Future<List<WishlistItem>> getWishlist({bool forceRefresh = false}) async {
    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/wishlist');

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return (jsonData['wishlist'] as List<dynamic>)
            .map((item) => WishlistItem.fromJson(item))
            .toList();
      } else {
        throw BookstoreException(
          'Failed to get wishlist: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting wishlist: $e');
      throw BookstoreException('Failed to get wishlist: $e');
    }
  }

  /// Submit a book review
  Future<BookReview> submitReview(ReviewSubmission review) async {
    try {
      final headers = await _authHeaders;
      final uri = Uri.parse('$apiBaseUrl/bookstore/reviews');

      final response = await _client.post(
        uri,
        headers: headers,
        body: json.encode(review.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return BookReview.fromJson(jsonData['review']);
      } else {
        final jsonData = json.decode(response.body);
        throw BookstoreException(
          jsonData['error_message'] ?? 'Failed to submit review',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error submitting review: $e');
      throw BookstoreException('Failed to submit review: $e');
    }
  }

  /// Get reviews for a specific book
  Future<List<BookReview>> getBookReviews(String bookId, {int page = 1, int pageSize = 20}) async {
    try {
      final headers = await _authHeaders;
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      final uri = Uri.parse('$apiBaseUrl/bookstore/books/$bookId/reviews')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return (jsonData['reviews'] as List<dynamic>)
            .map((review) => BookReview.fromJson(review))
            .toList();
      } else {
        throw BookstoreException(
          'Failed to get book reviews: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting book reviews: $e');
      throw BookstoreException('Failed to get book reviews: $e');
    }
  }

  /// Get personalized book recommendations
  Future<List<BookCatalog>> getRecommendations({int limit = 10}) async {
    try {
      final headers = await _authHeaders;
      final queryParams = {'limit': limit.toString()};

      final uri = Uri.parse('$apiBaseUrl/bookstore/recommendations')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return (jsonData['recommendations'] as List<dynamic>)
            .map((book) => BookCatalog.fromJson(book))
            .toList();
      } else {
        throw BookstoreException(
          'Failed to get recommendations: ${response.statusCode}',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting recommendations: $e');
      throw BookstoreException('Failed to get recommendations: $e');
    }
  }

  /// Clear all cached data
  void clearCache() {
    _cachedCategories = null;
    _cachedFeaturedBooks = null;
    _cachedPurchases = null;
    _cachedCredits = null;
    _lastCacheUpdate = null;
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

/// Custom exception for bookstore-related errors
class BookstoreException implements Exception {
  final String message;
  final int? statusCode;

  const BookstoreException(this.message, [this.statusCode]);

  @override
  String toString() => 'BookstoreException: $message';
}

/// Helper extension for formatting currencies
extension CurrencyFormatter on double {
  String get formattedPrice => '\$${toStringAsFixed(2)}';
}

/// Helper extension for formatting durations
extension DurationFormatter on int {
  String get formattedDuration {
    if (this < 60) return '${this}s';
    if (this < 3600) return '${(this / 60).floor()}m ${this % 60}s';
    final hours = (this / 3600).floor();
    final minutes = ((this % 3600) / 60).floor();
    return '${hours}h ${minutes}m';
  }
}