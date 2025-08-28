import 'package:flutter_test/flutter_test.dart';
import 'package:echowright/models/bookstore_models.dart';

void main() {
  group('BookCatalog Model', () {
    group('fromJson constructor', () {
      test('creates BookCatalog from complete JSON', () {
        // Arrange
        final json = {
          'id': 'book-123',
          'title': 'Test Book',
          'author': 'Test Author',
          'narrator': 'Test Narrator',
          'publisher': 'Test Publisher',
          'description': 'Test Description',
          'cover_image_url': 'https://example.com/cover.jpg',
          'sample_audio_url': 'https://example.com/sample.mp3',
          'sample_duration': 120,
          'price_usd': 14.99,
          'credit_price': 1,
          'formatted_price': '\$14.99',
          'duration_seconds': 18000,
          'formatted_duration': '5h 0m',
          'language': 'en',
          'genre': 'Fiction',
          'category_id': 'fiction',
          'is_featured': true,
          'is_bestseller': false,
          'is_new_release': true,
          'average_rating': 4.5,
          'review_count': 250,
          'purchase_count': 1000,
          'publication_date': '2023-01-15',
          'created_at': '2023-01-01T00:00:00Z',
          'updated_at': '2023-01-15T12:00:00Z',
        };

        // Act
        final book = BookCatalog.fromJson(json);

        // Assert
        expect(book.id, equals('book-123'));
        expect(book.title, equals('Test Book'));
        expect(book.author, equals('Test Author'));
        expect(book.narrator, equals('Test Narrator'));
        expect(book.publisher, equals('Test Publisher'));
        expect(book.description, equals('Test Description'));
        expect(book.coverImageUrl, equals('https://example.com/cover.jpg'));
        expect(book.sampleAudioUrl, equals('https://example.com/sample.mp3'));
        expect(book.sampleDuration, equals(120));
        expect(book.priceUsd, equals(14.99));
        expect(book.creditPrice, equals(1));
        expect(book.formattedPrice, equals('\$14.99'));
        expect(book.durationSeconds, equals(18000));
        expect(book.formattedDuration, equals('5h 0m'));
        expect(book.language, equals('en'));
        expect(book.genre, equals('Fiction'));
        expect(book.categoryId, equals('fiction'));
        expect(book.isFeatured, isTrue);
        expect(book.isBestseller, isFalse);
        expect(book.isNewRelease, isTrue);
        expect(book.averageRating, equals(4.5));
        expect(book.reviewCount, equals(250));
        expect(book.purchaseCount, equals(1000));
        expect(book.publicationDate, isA<DateTime>());
        expect(book.createdAt, isA<DateTime>());
        expect(book.updatedAt, isA<DateTime>());
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final json = {
          'id': 'minimal-book',
          'title': 'Minimal Book',
          'price_usd': 9.99,
          'credit_price': 1,
          'created_at': '2023-01-01T00:00:00Z',
          'updated_at': '2023-01-01T00:00:00Z',
        };

        // Act
        final book = BookCatalog.fromJson(json);

        // Assert
        expect(book.id, equals('minimal-book'));
        expect(book.title, equals('Minimal Book'));
        expect(book.author, isNull);
        expect(book.narrator, isNull);
        expect(book.publisher, isNull);
        expect(book.description, isNull);
        expect(book.coverImageUrl, isNull);
        expect(book.sampleAudioUrl, isNull);
        expect(book.sampleDuration, isNull);
        expect(book.formattedPrice, equals('\$9.99'));
        expect(book.formattedDuration, equals('Unknown length'));
        expect(book.language, equals('en'));
        expect(book.genre, isNull);
        expect(book.categoryId, isNull);
        expect(book.isFeatured, isFalse);
        expect(book.isBestseller, isFalse);
        expect(book.isNewRelease, isFalse);
        expect(book.averageRating, isNull);
        expect(book.reviewCount, equals(0));
        expect(book.purchaseCount, equals(0));
        expect(book.publicationDate, isNull);
      });

      test('handles formatted price fallback', () {
        // Arrange
        final json = {
          'id': 'book-no-formatted-price',
          'title': 'Book Without Formatted Price',
          'price_usd': 12.50,
          'credit_price': 1,
          'created_at': '2023-01-01T00:00:00Z',
          'updated_at': '2023-01-01T00:00:00Z',
        };

        // Act
        final book = BookCatalog.fromJson(json);

        // Assert
        expect(book.formattedPrice, equals('\$12.5'));
      });
    });

    group('toJson method', () {
      test('converts BookCatalog to JSON', () {
        // Arrange
        final book = BookCatalog(
          id: 'test-book',
          title: 'Test Title',
          author: 'Test Author',
          priceUsd: 15.99,
          creditPrice: 1,
          formattedPrice: '\$15.99',
          formattedDuration: '6h 30m',
          language: 'en',
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 15),
        );

        // Act
        final json = book.toJson();

        // Assert
        expect(json['id'], equals('test-book'));
        expect(json['title'], equals('Test Title'));
        expect(json['author'], equals('Test Author'));
        expect(json['price_usd'], equals(15.99));
        expect(json['credit_price'], equals(1));
        expect(json['formatted_price'], equals('\$15.99'));
        expect(json['formatted_duration'], equals('6h 30m'));
        expect(json['language'], equals('en'));
        expect(json['created_at'], isA<String>());
        expect(json['updated_at'], isA<String>());
      });
    });

    group('toString method', () {
      test('provides readable string representation', () {
        // Arrange
        final book = BookCatalog(
          id: 'book-123',
          title: 'Test Book',
          author: 'Test Author',
          priceUsd: 14.99,
          creditPrice: 1,
          formattedPrice: '\$14.99',
          formattedDuration: '5h 0m',
          language: 'en',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final stringRepresentation = book.toString();

        // Assert
        expect(stringRepresentation, contains('book-123'));
        expect(stringRepresentation, contains('Test Book'));
        expect(stringRepresentation, contains('Test Author'));
        expect(stringRepresentation, contains('\$14.99'));
      });
    });
  });

  group('BookCategory Model', () {
    group('fromJson constructor', () {
      test('creates BookCategory from complete JSON', () {
        // Arrange
        final json = {
          'id': 'fiction',
          'name': 'Fiction',
          'description': 'Literary fiction and novels',
          'image_url': 'https://example.com/fiction.jpg',
          'display_order': 1,
          'is_active': true,
          'created_at': '2023-01-01T00:00:00Z',
          'updated_at': '2023-01-15T12:00:00Z',
        };

        // Act
        final category = BookCategory.fromJson(json);

        // Assert
        expect(category.id, equals('fiction'));
        expect(category.name, equals('Fiction'));
        expect(category.description, equals('Literary fiction and novels'));
        expect(category.imageUrl, equals('https://example.com/fiction.jpg'));
        expect(category.displayOrder, equals(1));
        expect(category.isActive, isTrue);
        expect(category.createdAt, isA<DateTime>());
        expect(category.updatedAt, isA<DateTime>());
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final json = {
          'id': 'mystery',
          'name': 'Mystery',
          'created_at': '2023-01-01T00:00:00Z',
          'updated_at': '2023-01-01T00:00:00Z',
        };

        // Act
        final category = BookCategory.fromJson(json);

        // Assert
        expect(category.description, equals(''));
        expect(category.imageUrl, isNull);
        expect(category.displayOrder, equals(0));
        expect(category.isActive, isTrue);
      });
    });

    group('toJson method', () {
      test('converts BookCategory to JSON', () {
        // Arrange
        final category = BookCategory(
          id: 'sci-fi',
          name: 'Science Fiction',
          description: 'Futuristic and scientific stories',
          displayOrder: 3,
          createdAt: DateTime(2023, 1, 1),
          updatedAt: DateTime(2023, 1, 15),
        );

        // Act
        final json = category.toJson();

        // Assert
        expect(json['id'], equals('sci-fi'));
        expect(json['name'], equals('Science Fiction'));
        expect(json['description'], equals('Futuristic and scientific stories'));
        expect(json['display_order'], equals(3));
        expect(json['is_active'], isTrue);
        expect(json['created_at'], isA<String>());
        expect(json['updated_at'], isA<String>());
      });
    });
  });

  group('PurchaseType Enum', () {
    group('fromString method', () {
      test('converts valid strings to PurchaseType', () {
        expect(PurchaseType.fromString('credit'), equals(PurchaseType.credit));
        expect(PurchaseType.fromString('cash'), equals(PurchaseType.cash));
        expect(PurchaseType.fromString('gift'), equals(PurchaseType.gift));
        expect(PurchaseType.fromString('subscription'), equals(PurchaseType.subscription));
      });

      test('handles case insensitive strings', () {
        expect(PurchaseType.fromString('CREDIT'), equals(PurchaseType.credit));
        expect(PurchaseType.fromString('Cash'), equals(PurchaseType.cash));
        expect(PurchaseType.fromString('GIFT'), equals(PurchaseType.gift));
      });

      test('throws ArgumentError for invalid strings', () {
        expect(
          () => PurchaseType.fromString('invalid'),
          throwsArgumentError,
        );
      });
    });

    group('toString method', () {
      test('converts PurchaseType to string', () {
        expect(PurchaseType.credit.toString(), equals('credit'));
        expect(PurchaseType.cash.toString(), equals('cash'));
        expect(PurchaseType.gift.toString(), equals('gift'));
        expect(PurchaseType.subscription.toString(), equals('subscription'));
      });
    });
  });

  group('UserPurchase Model', () {
    group('fromJson constructor', () {
      test('creates UserPurchase from complete JSON', () {
        // Arrange
        final json = {
          'id': 'purchase-123',
          'user_id': 'user-456',
          'book_id': 'book-789',
          'purchase_date': '2023-01-15T10:30:00Z',
          'purchase_type': 'credit',
          'price_paid': 0.0,
          'credits_used': 1,
          'book': {
            'id': 'book-789',
            'title': 'Purchased Book',
            'price_usd': 14.99,
            'credit_price': 1,
            'created_at': '2023-01-01T00:00:00Z',
            'updated_at': '2023-01-01T00:00:00Z',
          }
        };

        // Act
        final purchase = UserPurchase.fromJson(json);

        // Assert
        expect(purchase.id, equals('purchase-123'));
        expect(purchase.userId, equals('user-456'));
        expect(purchase.bookId, equals('book-789'));
        expect(purchase.purchaseDate, isA<DateTime>());
        expect(purchase.purchaseType, equals(PurchaseType.credit));
        expect(purchase.pricePaid, equals(0.0));
        expect(purchase.creditsUsed, equals(1));
        expect(purchase.book, isNotNull);
        expect(purchase.book!.title, equals('Purchased Book'));
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final json = {
          'id': 'purchase-minimal',
          'user_id': 'user-123',
          'book_id': 'book-456',
          'purchase_date': '2023-01-15T10:30:00Z',
          'purchase_type': 'cash',
        };

        // Act
        final purchase = UserPurchase.fromJson(json);

        // Assert
        expect(purchase.pricePaid, isNull);
        expect(purchase.creditsUsed, equals(0));
        expect(purchase.book, isNull);
      });
    });
  });

  group('UserCredit Model', () {
    group('fromJson constructor', () {
      test('creates UserCredit from complete JSON', () {
        // Arrange
        final json = {
          'id': 'credit-123',
          'user_id': 'user-456',
          'total_credits': 10,
          'used_credits': 3,
          'last_updated': '2023-01-15T10:30:00Z',
        };

        // Act
        final userCredit = UserCredit.fromJson(json);

        // Assert
        expect(userCredit.id, equals('credit-123'));
        expect(userCredit.userId, equals('user-456'));
        expect(userCredit.totalCredits, equals(10));
        expect(userCredit.usedCredits, equals(3));
        expect(userCredit.availableCredits, equals(7));
        expect(userCredit.lastUpdated, isA<DateTime>());
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final json = {
          'id': 'credit-minimal',
          'user_id': 'user-123',
          'last_updated': '2023-01-15T10:30:00Z',
        };

        // Act
        final userCredit = UserCredit.fromJson(json);

        // Assert
        expect(userCredit.totalCredits, equals(0));
        expect(userCredit.usedCredits, equals(0));
        expect(userCredit.availableCredits, equals(0));
      });
    });

    group('availableCredits getter', () {
      test('calculates available credits correctly', () {
        // Arrange
        final userCredit = UserCredit(
          id: 'test',
          userId: 'user',
          totalCredits: 15,
          usedCredits: 7,
          lastUpdated: DateTime.now(),
        );

        // Act & Assert
        expect(userCredit.availableCredits, equals(8));
      });
    });
  });

  group('DownloadStatus Enum', () {
    group('fromString method', () {
      test('converts valid strings to DownloadStatus', () {
        expect(DownloadStatus.fromString('pending'), equals(DownloadStatus.pending));
        expect(DownloadStatus.fromString('downloading'), equals(DownloadStatus.downloading));
        expect(DownloadStatus.fromString('completed'), equals(DownloadStatus.completed));
        expect(DownloadStatus.fromString('failed'), equals(DownloadStatus.failed));
        expect(DownloadStatus.fromString('expired'), equals(DownloadStatus.expired));
      });

      test('handles case insensitive strings', () {
        expect(DownloadStatus.fromString('PENDING'), equals(DownloadStatus.pending));
        expect(DownloadStatus.fromString('Downloading'), equals(DownloadStatus.downloading));
      });

      test('throws ArgumentError for invalid strings', () {
        expect(
          () => DownloadStatus.fromString('invalid'),
          throwsArgumentError,
        );
      });
    });

    group('toString method', () {
      test('converts DownloadStatus to string', () {
        expect(DownloadStatus.pending.toString(), equals('pending'));
        expect(DownloadStatus.downloading.toString(), equals('downloading'));
        expect(DownloadStatus.completed.toString(), equals('completed'));
        expect(DownloadStatus.failed.toString(), equals('failed'));
        expect(DownloadStatus.expired.toString(), equals('expired'));
      });
    });
  });

  group('BrowseResponse Model', () {
    group('fromJson constructor', () {
      test('creates BrowseResponse from complete JSON', () {
        // Arrange
        final json = {
          'books': [
            {
              'id': 'book-1',
              'title': 'Book 1',
              'price_usd': 14.99,
              'credit_price': 1,
              'created_at': '2023-01-01T00:00:00Z',
              'updated_at': '2023-01-01T00:00:00Z',
            },
            {
              'id': 'book-2',
              'title': 'Book 2',
              'price_usd': 19.99,
              'credit_price': 2,
              'created_at': '2023-01-01T00:00:00Z',
              'updated_at': '2023-01-01T00:00:00Z',
            }
          ],
          'total_count': 2,
          'page': 1,
          'page_size': 20,
          'has_next_page': false,
        };

        // Act
        final response = BrowseResponse.fromJson(json);

        // Assert
        expect(response.books, hasLength(2));
        expect(response.books.first.title, equals('Book 1'));
        expect(response.books.last.title, equals('Book 2'));
        expect(response.totalCount, equals(2));
        expect(response.page, equals(1));
        expect(response.pageSize, equals(20));
        expect(response.hasNextPage, isFalse);
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final json = {
          'books': [],
          'total_count': 0,
          'page': 1,
          'page_size': 20,
        };

        // Act
        final response = BrowseResponse.fromJson(json);

        // Assert
        expect(response.books, isEmpty);
        expect(response.hasNextPage, isFalse);
      });
    });
  });
}