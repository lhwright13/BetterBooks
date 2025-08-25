/// Book catalog item from the bookstore
class BookCatalog {
  final String id;
  final String title;
  final String? author;
  final String? narrator;
  final String? publisher;
  final String? description;
  final String? coverImageUrl;
  final String? sampleAudioUrl;
  final int? sampleDuration; // in seconds
  final double priceUsd;
  final int creditPrice;
  final String formattedPrice;
  final int? durationSeconds;
  final String formattedDuration;
  final String language;
  final String? genre;
  final String? categoryId;
  final bool isFeatured;
  final bool isBestseller;
  final bool isNewRelease;
  final double? averageRating;
  final int reviewCount;
  final int purchaseCount;
  final DateTime? publicationDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookCatalog({
    required this.id,
    required this.title,
    this.author,
    this.narrator,
    this.publisher,
    this.description,
    this.coverImageUrl,
    this.sampleAudioUrl,
    this.sampleDuration,
    required this.priceUsd,
    required this.creditPrice,
    required this.formattedPrice,
    this.durationSeconds,
    required this.formattedDuration,
    required this.language,
    this.genre,
    this.categoryId,
    this.isFeatured = false,
    this.isBestseller = false,
    this.isNewRelease = false,
    this.averageRating,
    this.reviewCount = 0,
    this.purchaseCount = 0,
    this.publicationDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookCatalog.fromJson(Map<String, dynamic> json) {
    return BookCatalog(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      narrator: json['narrator'],
      publisher: json['publisher'],
      description: json['description'],
      coverImageUrl: json['cover_image_url'],
      sampleAudioUrl: json['sample_audio_url'],
      sampleDuration: json['sample_duration'],
      priceUsd: (json['price_usd'] as num).toDouble(),
      creditPrice: json['credit_price'],
      formattedPrice: json['formatted_price'] ?? '\$${json['price_usd']}',
      durationSeconds: json['duration_seconds'],
      formattedDuration: json['formatted_duration'] ?? 'Unknown length',
      language: json['language'] ?? 'en',
      genre: json['genre'],
      categoryId: json['category_id'],
      isFeatured: json['is_featured'] ?? false,
      isBestseller: json['is_bestseller'] ?? false,
      isNewRelease: json['is_new_release'] ?? false,
      averageRating: json['average_rating']?.toDouble(),
      reviewCount: json['review_count'] ?? 0,
      purchaseCount: json['purchase_count'] ?? 0,
      publicationDate: json['publication_date'] != null 
          ? DateTime.parse(json['publication_date']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'narrator': narrator,
      'publisher': publisher,
      'description': description,
      'cover_image_url': coverImageUrl,
      'sample_audio_url': sampleAudioUrl,
      'sample_duration': sampleDuration,
      'price_usd': priceUsd,
      'credit_price': creditPrice,
      'formatted_price': formattedPrice,
      'duration_seconds': durationSeconds,
      'formatted_duration': formattedDuration,
      'language': language,
      'genre': genre,
      'category_id': categoryId,
      'is_featured': isFeatured,
      'is_bestseller': isBestseller,
      'is_new_release': isNewRelease,
      'average_rating': averageRating,
      'review_count': reviewCount,
      'purchase_count': purchaseCount,
      'publication_date': publicationDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'BookCatalog{id: $id, title: $title, author: $author, price: $formattedPrice}';
  }
}

/// Book category for organizing the catalog
class BookCategory {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookCategory({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.displayOrder,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookCategory.fromJson(Map<String, dynamic> json) {
    return BookCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      imageUrl: json['image_url'],
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// User's purchase history
class UserPurchase {
  final String id;
  final String userId;
  final String bookId;
  final DateTime purchaseDate;
  final PurchaseType purchaseType;
  final double? pricePaid;
  final int creditsUsed;
  final BookCatalog? book; // Populated when fetching detailed purchase info

  const UserPurchase({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.purchaseDate,
    required this.purchaseType,
    this.pricePaid,
    this.creditsUsed = 0,
    this.book,
  });

  factory UserPurchase.fromJson(Map<String, dynamic> json) {
    return UserPurchase(
      id: json['id'],
      userId: json['user_id'],
      bookId: json['book_id'],
      purchaseDate: DateTime.parse(json['purchase_date']),
      purchaseType: PurchaseType.fromString(json['purchase_type']),
      pricePaid: json['price_paid']?.toDouble(),
      creditsUsed: json['credits_used'] ?? 0,
      book: json['book'] != null ? BookCatalog.fromJson(json['book']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'purchase_date': purchaseDate.toIso8601String(),
      'purchase_type': purchaseType.toString(),
      'price_paid': pricePaid,
      'credits_used': creditsUsed,
      'book': book?.toJson(),
    };
  }
}

/// Purchase type enumeration
enum PurchaseType {
  credit,
  cash,
  gift,
  subscription;

  static PurchaseType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'credit':
        return PurchaseType.credit;
      case 'cash':
        return PurchaseType.cash;
      case 'gift':
        return PurchaseType.gift;
      case 'subscription':
        return PurchaseType.subscription;
      default:
        throw ArgumentError('Unknown purchase type: $value');
    }
  }

  @override
  String toString() {
    switch (this) {
      case PurchaseType.credit:
        return 'credit';
      case PurchaseType.cash:
        return 'cash';
      case PurchaseType.gift:
        return 'gift';
      case PurchaseType.subscription:
        return 'subscription';
    }
  }
}

/// User's credit balance and transactions
class UserCredit {
  final String id;
  final String userId;
  final int totalCredits;
  final int usedCredits;
  final DateTime lastUpdated;

  const UserCredit({
    required this.id,
    required this.userId,
    required this.totalCredits,
    required this.usedCredits,
    required this.lastUpdated,
  });

  int get availableCredits => totalCredits - usedCredits;

  factory UserCredit.fromJson(Map<String, dynamic> json) {
    return UserCredit(
      id: json['id'],
      userId: json['user_id'],
      totalCredits: json['total_credits'] ?? 0,
      usedCredits: json['used_credits'] ?? 0,
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'total_credits': totalCredits,
      'used_credits': usedCredits,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

/// Book review from users
class BookReview {
  final String id;
  final String userId;
  final String bookId;
  final int rating; // 1-5 stars
  final String? title;
  final String? content;
  final bool isVerifiedPurchase;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userName; // Populated when fetching reviews

  const BookReview({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.rating,
    this.title,
    this.content,
    this.isVerifiedPurchase = false,
    required this.createdAt,
    required this.updatedAt,
    this.userName,
  });

  factory BookReview.fromJson(Map<String, dynamic> json) {
    return BookReview(
      id: json['id'],
      userId: json['user_id'],
      bookId: json['book_id'],
      rating: json['rating'],
      title: json['title'],
      content: json['content'],
      isVerifiedPurchase: json['is_verified_purchase'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      userName: json['user_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'rating': rating,
      'title': title,
      'content': content,
      'is_verified_purchase': isVerifiedPurchase,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'user_name': userName,
    };
  }
}

/// Wishlist item
class WishlistItem {
  final String id;
  final String userId;
  final String bookId;
  final DateTime addedAt;
  final BookCatalog? book; // Populated when fetching wishlist

  const WishlistItem({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.addedAt,
    this.book,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'],
      userId: json['user_id'],
      bookId: json['book_id'],
      addedAt: DateTime.parse(json['added_at']),
      book: json['book'] != null ? BookCatalog.fromJson(json['book']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'added_at': addedAt.toIso8601String(),
      'book': book?.toJson(),
    };
  }
}

/// Book download information for offline access
class BookDownload {
  final String id;
  final String userId;
  final String bookId;
  final String downloadUrl;
  final DownloadStatus status;
  final int? fileSizeBytes;
  final DateTime? downloadStarted;
  final DateTime? downloadCompleted;
  final String? localFilePath;
  final DateTime expiresAt;

  const BookDownload({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.downloadUrl,
    required this.status,
    this.fileSizeBytes,
    this.downloadStarted,
    this.downloadCompleted,
    this.localFilePath,
    required this.expiresAt,
  });

  factory BookDownload.fromJson(Map<String, dynamic> json) {
    return BookDownload(
      id: json['id'],
      userId: json['user_id'],
      bookId: json['book_id'],
      downloadUrl: json['download_url'],
      status: DownloadStatus.fromString(json['status']),
      fileSizeBytes: json['file_size_bytes'],
      downloadStarted: json['download_started'] != null
          ? DateTime.parse(json['download_started'])
          : null,
      downloadCompleted: json['download_completed'] != null
          ? DateTime.parse(json['download_completed'])
          : null,
      localFilePath: json['local_file_path'],
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'download_url': downloadUrl,
      'status': status.toString(),
      'file_size_bytes': fileSizeBytes,
      'download_started': downloadStarted?.toIso8601String(),
      'download_completed': downloadCompleted?.toIso8601String(),
      'local_file_path': localFilePath,
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}

/// Download status enumeration
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  expired;

  static DownloadStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return DownloadStatus.pending;
      case 'downloading':
        return DownloadStatus.downloading;
      case 'completed':
        return DownloadStatus.completed;
      case 'failed':
        return DownloadStatus.failed;
      case 'expired':
        return DownloadStatus.expired;
      default:
        throw ArgumentError('Unknown download status: $value');
    }
  }

  @override
  String toString() {
    switch (this) {
      case DownloadStatus.pending:
        return 'pending';
      case DownloadStatus.downloading:
        return 'downloading';
      case DownloadStatus.completed:
        return 'completed';
      case DownloadStatus.failed:
        return 'failed';
      case DownloadStatus.expired:
        return 'expired';
    }
  }
}

/// Request models for API calls

class PurchaseRequest {
  final String bookId;
  final PurchaseType paymentMethod;
  final String? paymentToken; // For direct payments
  final String? giftRecipientEmail; // For gift purchases

  const PurchaseRequest({
    required this.bookId,
    required this.paymentMethod,
    this.paymentToken,
    this.giftRecipientEmail,
  });

  Map<String, dynamic> toJson() {
    return {
      'book_id': bookId,
      'payment_method': paymentMethod.toString(),
      'payment_token': paymentToken,
      'gift_recipient_email': giftRecipientEmail,
    };
  }
}

class ReviewSubmission {
  final String bookId;
  final int rating;
  final String? title;
  final String? content;

  const ReviewSubmission({
    required this.bookId,
    required this.rating,
    this.title,
    this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'book_id': bookId,
      'rating': rating,
      'title': title,
      'content': content,
    };
  }
}

/// API Response models

class BrowseResponse {
  final List<BookCatalog> books;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasNextPage;

  const BrowseResponse({
    required this.books,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasNextPage,
  });

  factory BrowseResponse.fromJson(Map<String, dynamic> json) {
    return BrowseResponse(
      books: (json['books'] as List<dynamic>)
          .map((book) => BookCatalog.fromJson(book))
          .toList(),
      totalCount: json['total_count'],
      page: json['page'],
      pageSize: json['page_size'],
      hasNextPage: json['has_next_page'] ?? false,
    );
  }
}

class PurchaseResponse {
  final bool success;
  final String? transactionId;
  final UserPurchase? purchase;
  final String? errorMessage;
  final int? remainingCredits;

  const PurchaseResponse({
    required this.success,
    this.transactionId,
    this.purchase,
    this.errorMessage,
    this.remainingCredits,
  });

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseResponse(
      success: json['success'] ?? false,
      transactionId: json['transaction_id'],
      purchase: json['purchase'] != null 
          ? UserPurchase.fromJson(json['purchase']) 
          : null,
      errorMessage: json['error_message'],
      remainingCredits: json['remaining_credits'],
    );
  }
}

class CreditBalanceResponse {
  final int availableCredits;
  final int totalCredits;
  final int usedCredits;
  final DateTime lastUpdated;

  const CreditBalanceResponse({
    required this.availableCredits,
    required this.totalCredits,
    required this.usedCredits,
    required this.lastUpdated,
  });

  factory CreditBalanceResponse.fromJson(Map<String, dynamic> json) {
    return CreditBalanceResponse(
      availableCredits: json['available_credits'] ?? 0,
      totalCredits: json['total_credits'] ?? 0,
      usedCredits: json['used_credits'] ?? 0,
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }
}