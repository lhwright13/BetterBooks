/// Additional response models for API operations

import 'bookstore_models.dart';

/// User library response containing purchased books
class UserLibraryResponse {
  final String userId;
  final List<BookCatalog> books;
  final int totalBooks;

  const UserLibraryResponse({
    required this.userId,
    required this.books,
    required this.totalBooks,
  });

  factory UserLibraryResponse.fromJson(Map<String, dynamic> json) {
    return UserLibraryResponse(
      userId: json['user_id'],
      books: (json['books'] as List<dynamic>)
          .map((book) => BookCatalog.fromJson(book))
          .toList(),
      totalBooks: json['total_books'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'books': books.map((book) => book.toJson()).toList(),
      'total_books': totalBooks,
    };
  }
}

/// Enhanced purchase response with more details
class PurchaseResponse {
  final bool success;
  final String message;
  final String purchaseId;
  final BookCatalog book;
  final int creditsUsed;
  final double priceePaid;
  final int remainingCredits;
  final String? downloadUrl;

  const PurchaseResponse({
    required this.success,
    required this.message,
    required this.purchaseId,
    required this.book,
    this.creditsUsed = 0,
    this.priceePaid = 0.0,
    required this.remainingCredits,
    this.downloadUrl,
  });

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      purchaseId: json['purchase_id'] ?? '',
      book: BookCatalog.fromJson(json['book']),
      creditsUsed: json['credits_used'] ?? 0,
      priceePaid: (json['price_paid'] as num?)?.toDouble() ?? 0.0,
      remainingCredits: json['remaining_credits'] ?? 0,
      downloadUrl: json['download_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'purchase_id': purchaseId,
      'book': book.toJson(),
      'credits_used': creditsUsed,
      'price_paid': priceePaid,
      'remaining_credits': remainingCredits,
      'download_url': downloadUrl,
    };
  }
}

/// Enhanced credit balance response
class CreditBalanceResponse {
  final String userId;
  final int totalCredits;
  final int usedCredits;
  final int availableCredits;

  const CreditBalanceResponse({
    required this.userId,
    required this.totalCredits,
    required this.usedCredits,
    required this.availableCredits,
  });

  factory CreditBalanceResponse.fromJson(Map<String, dynamic> json) {
    return CreditBalanceResponse(
      userId: json['user_id'] ?? '',
      totalCredits: json['total_credits'] ?? 0,
      usedCredits: json['used_credits'] ?? 0,
      availableCredits: json['available_credits'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'total_credits': totalCredits,
      'used_credits': usedCredits,
      'available_credits': availableCredits,
    };
  }
}