/// Book related data models
library;

class BrowseBook {
  final String id;
  final String title;
  final String author;
  final String coverImageUrl;
  final double priceUsd;
  final int creditPrice;
  final bool isFeatured;
  final bool isBestseller;
  final bool isNewRelease;
  final bool isPurchased;
  final bool isDownloaded;
  final double downloadProgress; // 0.0 to 1.0
  final String? audioUrl;
  final List<Chapter> chapters;

  BrowseBook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverImageUrl,
    this.priceUsd = 9.99,
    this.creditPrice = 1,
    this.isFeatured = false,
    this.isBestseller = false,
    this.isNewRelease = false,
    this.isPurchased = false,
    this.isDownloaded = false,
    this.downloadProgress = 0.0,
    this.audioUrl,
    this.chapters = const [],
  });

  factory BrowseBook.fromJson(Map<String, dynamic> json) {
    return BrowseBook(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverImageUrl: json['cover_image_url'] ?? '',
      priceUsd: (json['price_usd'] ?? 9.99).toDouble(),
      creditPrice: (json['credit_price'] ?? 1) as int,
      isFeatured: json['is_featured'] ?? false,
      isBestseller: json['is_bestseller'] ?? false,
      isNewRelease: json['is_new_release'] ?? false,
      isPurchased: json['is_purchased'] ?? false,
      isDownloaded: json['is_downloaded'] ?? false,
      downloadProgress: (json['download_progress'] ?? 0.0).toDouble(),
      audioUrl: json['audio_url'],
      chapters: (json['chapters'] as List? ?? [])
          .map((chapter) => Chapter.fromJson(chapter))
          .toList(),
    );
  }
  
  /// Create a copy with updated fields
  BrowseBook copyWith({
    String? id,
    String? title,
    String? author,
    String? coverImageUrl,
    double? priceUsd,
    int? creditPrice,
    bool? isFeatured,
    bool? isBestseller,
    bool? isNewRelease,
    bool? isPurchased,
    bool? isDownloaded,
    double? downloadProgress,
    String? audioUrl,
    List<Chapter>? chapters,
  }) {
    return BrowseBook(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      priceUsd: priceUsd ?? this.priceUsd,
      creditPrice: creditPrice ?? this.creditPrice,
      isFeatured: isFeatured ?? this.isFeatured,
      isBestseller: isBestseller ?? this.isBestseller,
      isNewRelease: isNewRelease ?? this.isNewRelease,
      isPurchased: isPurchased ?? this.isPurchased,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      audioUrl: audioUrl ?? this.audioUrl,
      chapters: chapters ?? this.chapters,
    );
  }
}

class BrowseResponse {
  final List<BrowseBook> books;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasNextPage;

  BrowseResponse({
    required this.books,
    required this.totalCount,
    this.page = 1,
    this.pageSize = 20,
    this.hasNextPage = false,
  });

  factory BrowseResponse.fromJson(Map<String, dynamic> json) {
    return BrowseResponse(
      books: (json['books'] as List? ?? [])
          .map((book) => BrowseBook.fromJson(book))
          .toList(),
      totalCount: json['total_count'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 20,
      hasNextPage: json['has_next_page'] ?? false,
    );
  }
}

class DetailedBook {
  final String id;
  final String title;
  final String author;
  final String? description;
  final String coverImageUrl;
  final List<Chapter> chapters;
  final int? totalDuration;

  DetailedBook({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.coverImageUrl,
    this.chapters = const [],
    this.totalDuration,
  });

  factory DetailedBook.fromJson(Map<String, dynamic> json) {
    return DetailedBook(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      description: json['description'],
      coverImageUrl: json['cover_image_url'] ?? '',
      chapters: (json['chapters'] as List? ?? [])
          .map((chapter) => Chapter.fromJson(chapter))
          .toList(),
      totalDuration: json['total_duration'],
    );
  }
}

class Chapter {
  final String id;
  final String title;
  final String audioUrl;
  final int chapterNumber;
  final int? duration;

  Chapter({
    required this.id,
    required this.title,
    required this.audioUrl,
    required this.chapterNumber,
    this.duration,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      title: json['title'],
      audioUrl: json['audio_url'],
      chapterNumber: json['chapter_number'],
      duration: json['duration'],
    );
  }
}

class CreditBalanceResponse {
  final int totalCredits;
  final int usedCredits;
  final int availableCredits;

  CreditBalanceResponse({
    required this.totalCredits,
    required this.usedCredits,
    required this.availableCredits,
  });

  factory CreditBalanceResponse.fromJson(Map<String, dynamic> json) {
    return CreditBalanceResponse(
      totalCredits: json['total_credits'],
      usedCredits: json['used_credits'],
      availableCredits: json['available_credits'],
    );
  }
}

class PurchaseResponse {
  final bool success;
  final String message;
  final int remainingCredits;
  final BrowseBook? book;

  PurchaseResponse({
    required this.success,
    required this.message,
    required this.remainingCredits,
    this.book,
  });

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseResponse(
      success: json['success'] ?? true,
      message: json['message'] ?? 'Purchase successful',
      remainingCredits: json['remaining_credits'] ?? 0,
      book: json['book'] != null ? BrowseBook.fromJson(json['book']) : null,
    );
  }
}