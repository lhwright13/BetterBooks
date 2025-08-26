/// simple_bookstore_service.dart - Simple bookstore API client for EchoWright
/// 
/// This service connects to the simple bookstore API endpoints to provide
/// basic catalog browsing functionality with actual book data and cover images.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/bookstore_models.dart';

// Simple models matching the API response structure
class SimpleBook {
  final String id;
  final String title;
  final String? author;
  final String? narrator;
  final String? description;
  final String? coverImageUrl;
  final String? sampleAudioUrl;
  final double priceUsd;
  final int creditPrice;
  final String formattedPrice;
  final double durationHours;
  final String formattedDuration;
  final bool isFeatured;
  final bool isBestseller;
  final bool isNewRelease;
  final double? averageRating;
  final int reviewCount;

  SimpleBook({
    required this.id,
    required this.title,
    this.author,
    this.narrator,
    this.description,
    this.coverImageUrl,
    this.sampleAudioUrl,
    required this.priceUsd,
    required this.creditPrice,
    required this.formattedPrice,
    required this.durationHours,
    required this.formattedDuration,
    this.isFeatured = false,
    this.isBestseller = false,
    this.isNewRelease = false,
    this.averageRating,
    this.reviewCount = 0,
  });

  factory SimpleBook.fromJson(Map<String, dynamic> json) {
    return SimpleBook(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      narrator: json['narrator'],
      description: json['description'],
      coverImageUrl: json['cover_image_url'],
      sampleAudioUrl: json['sample_audio_url'],
      priceUsd: (json['price_usd'] ?? 0.0).toDouble(),
      creditPrice: json['credit_price'] ?? 1,
      formattedPrice: json['formatted_price'] ?? '\$0.00',
      durationHours: (json['duration_hours'] ?? 0.0).toDouble(),
      formattedDuration: json['formatted_duration'] ?? '0h 0m',
      isFeatured: json['is_featured'] ?? false,
      isBestseller: json['is_bestseller'] ?? false,
      isNewRelease: json['is_new_release'] ?? false,
      averageRating: json['average_rating']?.toDouble(),
      reviewCount: json['review_count'] ?? 0,
    );
  }

  // Convert to full URL for cover images
  String? get fullCoverImageUrl {
    if (coverImageUrl == null) return null;
    if (coverImageUrl!.startsWith('http')) return coverImageUrl;
    return '$apiBaseUrl$coverImageUrl';
  }

  // Convert to BookCatalog for UI compatibility
  BookCatalog toBookCatalog() {
    return BookCatalog(
      id: id,
      title: title,
      author: author,
      narrator: narrator,
      description: description,
      coverImageUrl: fullCoverImageUrl,
      sampleAudioUrl: sampleAudioUrl != null ? '$apiBaseUrl$sampleAudioUrl' : null,
      priceUsd: priceUsd,
      creditPrice: creditPrice,
      formattedPrice: formattedPrice,
      durationSeconds: (durationHours * 3600).toInt(),
      formattedDuration: formattedDuration,
      language: 'en',
      isFeatured: isFeatured,
      isBestseller: isBestseller,
      isNewRelease: isNewRelease,
      averageRating: averageRating,
      reviewCount: reviewCount,
      purchaseCount: 0, // Default for simple API
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class SimpleBrowseResponse {
  final List<SimpleBook> books;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasNextPage;

  SimpleBrowseResponse({
    required this.books,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasNextPage,
  });

  factory SimpleBrowseResponse.fromJson(Map<String, dynamic> json) {
    return SimpleBrowseResponse(
      books: (json['books'] as List)
          .map((book) => SimpleBook.fromJson(book))
          .toList(),
      totalCount: json['total_count'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 10,
      hasNextPage: json['has_next_page'] ?? false,
    );
  }

  // Convert to BrowseResponse for UI compatibility
  BrowseResponse toBrowseResponse() {
    return BrowseResponse(
      books: books.map((book) => book.toBookCatalog()).toList(),
      totalCount: totalCount,
      page: page,
      pageSize: pageSize,
      hasNextPage: hasNextPage,
    );
  }
}

class SimpleCategory {
  final String id;
  final String name;
  final String description;
  final int bookCount;

  SimpleCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.bookCount,
  });

  factory SimpleCategory.fromJson(Map<String, dynamic> json) {
    return SimpleCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      bookCount: json['book_count'] ?? 0,
    );
  }
}

/// Simple bookstore service for basic catalog operations
class SimpleBookstoreService {
  static const Duration _timeoutDuration = Duration(seconds: 30);

  /// Get HTTP headers for requests
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// Browse books with optional filtering
  static Future<SimpleBrowseResponse> browseBooks({
    bool? featuredOnly,
    bool? bestsellersOnly,
    bool? newReleasesOnly,
    String? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (featuredOnly == true) queryParams['featured_only'] = 'true';
      if (bestsellersOnly == true) queryParams['bestsellers_only'] = 'true';
      if (newReleasesOnly == true) queryParams['new_releases_only'] = 'true';
      if (categoryId != null) queryParams['category_id'] = categoryId;

      final uri = Uri.parse('$apiBaseUrl/bookstore/browse').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: _getHeaders())
          .timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SimpleBrowseResponse.fromJson(json);
      } else {
        throw Exception('Failed to browse books: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error browsing books: $e');
    }
  }

  /// Search books by query
  static Future<SimpleBrowseResponse> searchBooks({
    required String query,
    String? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'query': query,
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (categoryId != null) queryParams['category_id'] = categoryId;

      final uri = Uri.parse('$apiBaseUrl/bookstore/search').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(uri, headers: _getHeaders())
          .timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SimpleBrowseResponse.fromJson(json);
      } else {
        throw Exception('Failed to search books: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error searching books: $e');
    }
  }

  /// Get book categories
  static Future<List<SimpleCategory>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/categories'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        return json.map((category) => SimpleCategory.fromJson(category)).toList();
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error loading categories: $e');
    }
  }

  /// Get book details by ID
  static Future<SimpleBook> getBookDetails(String bookId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/books/$bookId'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return SimpleBook.fromJson(json);
      } else {
        throw Exception('Failed to load book details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error loading book details: $e');
    }
  }

  /// Test connection
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/test'),
        headers: _getHeaders(),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Test connection failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error testing connection: $e');
    }
  }
}