/// Adapter service that connects the bookstore UI to the simple API
library;

import '../models/bookstore_models.dart';
import 'simple_bookstore_service.dart';

/// Adapter class that implements the expected BookstoreService interface
/// but uses the simple API endpoints
class BookstoreAdapter {
  /// Browse books with filtering options
  Future<BrowseResponse> browseBooks({
    bool? featuredOnly,
    bool? bestsellersOnly,
    bool? newReleasesOnly,
    String? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await SimpleBookstoreService.browseBooks(
      featuredOnly: featuredOnly,
      bestsellersOnly: bestsellersOnly,
      newReleasesOnly: newReleasesOnly,
      categoryId: categoryId,
      page: page,
      pageSize: pageSize,
    );
    
    return response.toBrowseResponse();
  }

  /// Search books by query
  Future<BrowseResponse> searchBooks({
    required String query,
    String? categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await SimpleBookstoreService.searchBooks(
      query: query,
      categoryId: categoryId,
      page: page,
      pageSize: pageSize,
    );
    
    return response.toBrowseResponse();
  }

  /// Get book categories
  Future<List<BookCategory>> getCategories() async {
    final categories = await SimpleBookstoreService.getCategories();
    
    return categories.map((cat) => BookCategory(
      id: cat.id,
      name: cat.name,
      description: cat.description,
      imageUrl: null, // Simple API doesn't have category images
      displayOrder: 0,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    )).toList();
  }

  /// Get book details by ID
  Future<BookCatalog> getBookDetails(String bookId) async {
    final book = await SimpleBookstoreService.getBookDetails(bookId);
    return book.toBookCatalog();
  }

  /// Mock credit balance for testing
  Future<CreditBalanceResponse> getCreditBalance() async {
    // Return a mock response since simple API doesn't handle credits
    return CreditBalanceResponse(
      totalCredits: 5,
      usedCredits: 2,
      availableCredits: 3,
      lastUpdated: DateTime.now(),
    );
  }
}