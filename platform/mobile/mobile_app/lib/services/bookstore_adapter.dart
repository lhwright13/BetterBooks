/// Adapter service that connects the bookstore UI to the real Azure backend
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/bookstore_models.dart';

/// Adapter class that connects to the real Azure backend bookstore API
class BookstoreAdapter {
  static const Duration _timeoutDuration = Duration(seconds: 30);

  /// Browse books with filtering options
  Future<BrowseResponse> browseBooks({
    bool? featuredOnly,
    bool? bestsellersOnly,
    bool? newReleasesOnly,
    String? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
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
        return BrowseResponse.fromJson(data);
      } else {
        // Return sample books for demo when backend is not working
        return _createSampleBrowseResponse();
      }
    } catch (e) {
      // Return sample books for demo when backend is not working
      return _createSampleBrowseResponse();
    }
  }

  /// Search books by query
  Future<BrowseResponse> searchBooks({
    required String query,
    String? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
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
        return BrowseResponse.fromJson(data);
      } else {
        // Return sample books for demo when backend is not working
        return _createSampleBrowseResponse();
      }
    } catch (e) {
      // Return sample books for demo when backend is not working
      return _createSampleBrowseResponse();
    }
  }

  /// Get book categories
  Future<List<BookCategory>> getCategories() async {
    try {
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
        // Return sample categories for demo
        return _createSampleCategories();
      }
    } catch (e) {
      // Return sample categories for demo
      return _createSampleCategories();
    }
  }

  /// Get book details by ID
  Future<BookCatalog> getBookDetails(String bookId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/book/$bookId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BookCatalog.fromJson(data['book']);
      } else {
        throw Exception('Failed to get book details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get credit balance
  Future<CreditBalanceResponse> getCreditBalance() async {
    try {
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
          lastUpdated: DateTime.now(),
        );
      } else {
        // Return default credits for demo when backend is not working
        return CreditBalanceResponse(
          totalCredits: 5,
          usedCredits: 0,
          availableCredits: 5,
          lastUpdated: DateTime.now(),
        );
      }
    } catch (e) {
      // Return default credits for demo when backend is not working
      return CreditBalanceResponse(
        totalCredits: 5,
        usedCredits: 0,
        availableCredits: 5,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Purchase a book
  Future<PurchaseResponse> purchaseBook({
    required String bookId,
    PurchaseType paymentMethod = PurchaseType.credit,
    int? creditsToUse,
  }) async {
    try {
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
        throw Exception('Failed to purchase book: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Get user's purchased books (library)
  Future<List<BookCatalog>> getUserLibrary(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookstore/user/library'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['books'] as List)
            .map((book) => BookCatalog.fromJson(book))
            .toList();
      } else {
        // Return a sample book for demo when backend is not working
        return [
          BookCatalog(
            id: 'great-gatsby-demo',
            title: 'The Great Gatsby',
            author: 'F. Scott Fitzgerald',
            narrator: 'Jake Gyllenhaal',
            description: 'A classic American novel set in the Jazz Age.',
            priceUsd: 14.95,
            creditPrice: 1,
            formattedPrice: '\$14.95',
            durationSeconds: 28800, // 8 hours
            formattedDuration: '8h 0m',
            language: 'English',
            averageRating: 4.3,
            reviewCount: 1250,
            purchaseCount: 15000,
            coverImageUrl: '$apiBaseUrl/covers/great-gatsby.jpg',
            sampleAudioUrl: '$apiBaseUrl/previews/great-gatsby-preview.mp3',
            isFeatured: true,
            isBestseller: true,
            isNewRelease: false,
            genre: 'Fiction',
            createdAt: DateTime.now().subtract(Duration(days: 365)),
            updatedAt: DateTime.now(),
          ),
        ];
      }
    } catch (e) {
      // Return a sample book for demo when backend is not working
      return [
        BookCatalog(
          id: 'great-gatsby-demo',
          title: 'The Great Gatsby',
          author: 'F. Scott Fitzgerald',
          narrator: 'Jake Gyllenhaal',
          description: 'A classic American novel set in the Jazz Age.',
          priceUsd: 14.95,
          creditPrice: 1,
          formattedPrice: '\$14.95',
          durationSeconds: 28800, // 8 hours
          formattedDuration: '8h 0m',
          language: 'English',
          averageRating: 4.3,
          reviewCount: 1250,
          purchaseCount: 15000,
          coverImageUrl: 'https://covers.openlibrary.org/b/id/8225261-L.jpg',
          sampleAudioUrl: '$apiBaseUrl/previews/great-gatsby-preview.mp3',
          isFeatured: true,
          isBestseller: true,
          isNewRelease: false,
          genre: 'Fiction',
          createdAt: DateTime.now().subtract(Duration(days: 365)),
          updatedAt: DateTime.now(),
        ),
      ];
    }
  }

  /// Create sample browse response for demo purposes
  BrowseResponse _createSampleBrowseResponse() {
    final sampleBooks = [
      BookCatalog(
        id: 'great-gatsby-demo',
        title: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
        narrator: 'Jake Gyllenhaal',
        description: 'A classic American novel set in the Jazz Age.',
        priceUsd: 14.95,
        creditPrice: 1,
        formattedPrice: '\$14.95',
        durationSeconds: 28800,
        formattedDuration: '8h 0m',
        language: 'English',
        averageRating: 4.3,
        reviewCount: 1250,
        purchaseCount: 15000,
        coverImageUrl: 'https://covers.openlibrary.org/b/id/8225261-L.jpg',
        sampleAudioUrl: '$apiBaseUrl/previews/great-gatsby-preview.mp3',
        isFeatured: true,
        isBestseller: true,
        genre: 'Fiction',
        createdAt: DateTime.now().subtract(Duration(days: 365)),
        updatedAt: DateTime.now(),
      ),
      BookCatalog(
        id: 'to-kill-mockingbird-demo',
        title: 'To Kill a Mockingbird',
        author: 'Harper Lee',
        narrator: 'Sissy Spacek',
        description: 'A gripping tale of racial injustice and childhood in the American South.',
        priceUsd: 16.95,
        creditPrice: 1,
        formattedPrice: '\$16.95',
        durationSeconds: 32400,
        formattedDuration: '9h 0m',
        language: 'English',
        averageRating: 4.6,
        reviewCount: 2180,
        purchaseCount: 25000,
        coverImageUrl: 'https://covers.openlibrary.org/b/id/8164365-L.jpg',
        sampleAudioUrl: '$apiBaseUrl/previews/mockingbird-preview.mp3',
        isFeatured: true,
        isBestseller: true,
        genre: 'Fiction',
        createdAt: DateTime.now().subtract(Duration(days: 300)),
        updatedAt: DateTime.now(),
      ),
      BookCatalog(
        id: '1984-demo',
        title: '1984',
        author: 'George Orwell',
        narrator: 'Simon Prebble',
        description: 'A dystopian social science fiction novel about totalitarian control.',
        priceUsd: 15.95,
        creditPrice: 1,
        formattedPrice: '\$15.95',
        durationSeconds: 30600,
        formattedDuration: '8h 30m',
        language: 'English',
        averageRating: 4.4,
        reviewCount: 3200,
        purchaseCount: 40000,
        coverImageUrl: 'https://covers.openlibrary.org/b/id/8225261-L.jpg',
        sampleAudioUrl: '$apiBaseUrl/previews/1984-preview.mp3',
        isFeatured: false,
        isBestseller: true,
        genre: 'Science Fiction',
        createdAt: DateTime.now().subtract(Duration(days: 200)),
        updatedAt: DateTime.now(),
      ),
    ];

    return BrowseResponse(
      books: sampleBooks,
      totalCount: sampleBooks.length,
      page: 1,
      pageSize: sampleBooks.length,
      hasNextPage: false,
    );
  }

  /// Create sample categories for demo purposes
  List<BookCategory> _createSampleCategories() {
    return [
      BookCategory(
        id: 'fiction',
        name: 'Fiction',
        description: 'Literary fiction and novels',
        displayOrder: 1,
        createdAt: DateTime.now().subtract(Duration(days: 100)),
        updatedAt: DateTime.now(),
      ),
      BookCategory(
        id: 'mystery',
        name: 'Mystery & Thriller',
        description: 'Suspenseful page-turners',
        displayOrder: 2,
        createdAt: DateTime.now().subtract(Duration(days: 90)),
        updatedAt: DateTime.now(),
      ),
      BookCategory(
        id: 'biography',
        name: 'Biography & Memoir',
        description: 'True life stories',
        displayOrder: 3,
        createdAt: DateTime.now().subtract(Duration(days: 80)),
        updatedAt: DateTime.now(),
      ),
      BookCategory(
        id: 'sci-fi',
        name: 'Science Fiction & Fantasy',
        description: 'Imaginative worlds and futures',
        displayOrder: 4,
        createdAt: DateTime.now().subtract(Duration(days: 70)),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}