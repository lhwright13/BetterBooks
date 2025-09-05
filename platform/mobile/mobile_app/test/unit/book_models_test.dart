import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/data/models/book_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chapter Model Tests', () {
    test('Chapter should create correctly from constructor', () {
      final chapter = Chapter(
        id: 'ch1',
        title: 'Chapter 1: The Beginning',
        audioUrl: 'https://example.com/audio1.mp3',
        chapterNumber: 1,
        duration: 1800, // 30 minutes
      );

      expect(chapter.id, equals('ch1'));
      expect(chapter.title, equals('Chapter 1: The Beginning'));
      expect(chapter.audioUrl, equals('https://example.com/audio1.mp3'));
      expect(chapter.chapterNumber, equals(1));
      expect(chapter.duration, equals(1800));
    });

    test('Chapter should create from JSON correctly', () {
      final json = {
        'id': 'ch2',
        'title': 'Chapter 2: The Journey',
        'audio_url': 'https://example.com/audio2.mp3',
        'chapter_number': 2,
        'duration': 2400,
      };

      final chapter = Chapter.fromJson(json);

      expect(chapter.id, equals('ch2'));
      expect(chapter.title, equals('Chapter 2: The Journey'));
      expect(chapter.audioUrl, equals('https://example.com/audio2.mp3'));
      expect(chapter.chapterNumber, equals(2));
      expect(chapter.duration, equals(2400));
    });

    test('Chapter should handle missing optional fields in JSON', () {
      final json = {
        'id': 'ch3',
        'title': 'Chapter 3: No Duration',
        'audio_url': 'https://example.com/audio3.mp3',
        'chapter_number': 3,
        // duration is missing
      };

      final chapter = Chapter.fromJson(json);

      expect(chapter.id, equals('ch3'));
      expect(chapter.title, equals('Chapter 3: No Duration'));
      expect(chapter.duration, isNull);
    });
  });

  group('BrowseBook Model Tests', () {
    test('BrowseBook should create with default values', () {
      final book = BrowseBook(
        id: 'book1',
        title: 'Test Book',
        author: 'Test Author',
        coverImageUrl: 'https://example.com/cover.jpg',
      );

      expect(book.id, equals('book1'));
      expect(book.title, equals('Test Book'));
      expect(book.author, equals('Test Author'));
      expect(book.coverImageUrl, equals('https://example.com/cover.jpg'));
      expect(book.priceUsd, equals(9.99));
      expect(book.creditPrice, equals(1));
      expect(book.isFeatured, isFalse);
      expect(book.isBestseller, isFalse);
      expect(book.isNewRelease, isFalse);
      expect(book.isPurchased, isFalse);
      expect(book.isDownloaded, isFalse);
      expect(book.downloadProgress, equals(0.0));
      expect(book.audioUrl, isNull);
      expect(book.chapters, isEmpty);
    });

    test('BrowseBook should create with chapters', () {
      final chapters = [
        Chapter(
          id: 'ch1',
          title: 'Chapter 1',
          audioUrl: 'https://example.com/ch1.mp3',
          chapterNumber: 1,
          duration: 1800,
        ),
        Chapter(
          id: 'ch2',
          title: 'Chapter 2',
          audioUrl: 'https://example.com/ch2.mp3',
          chapterNumber: 2,
          duration: 2100,
        ),
      ];

      final book = BrowseBook(
        id: 'book1',
        title: 'Multi-Chapter Book',
        author: 'Test Author',
        coverImageUrl: 'https://example.com/cover.jpg',
        chapters: chapters,
      );

      expect(book.chapters.length, equals(2));
      expect(book.chapters[0].title, equals('Chapter 1'));
      expect(book.chapters[1].title, equals('Chapter 2'));
    });

    test('BrowseBook should create from JSON with chapters', () {
      final json = {
        'id': 'book2',
        'title': 'JSON Book',
        'author': 'JSON Author',
        'cover_image_url': 'https://example.com/cover2.jpg',
        'price_usd': 12.99,
        'credit_price': 2,
        'is_featured': true,
        'is_bestseller': false,
        'is_new_release': true,
        'is_purchased': true,
        'is_downloaded': false,
        'download_progress': 0.5,
        'audio_url': 'https://example.com/audio.mp3',
        'chapters': [
          {
            'id': 'ch1',
            'title': 'First Chapter',
            'audio_url': 'https://example.com/ch1.mp3',
            'chapter_number': 1,
            'duration': 1500,
          },
          {
            'id': 'ch2',
            'title': 'Second Chapter',
            'audio_url': 'https://example.com/ch2.mp3',
            'chapter_number': 2,
            'duration': 1800,
          }
        ],
      };

      final book = BrowseBook.fromJson(json);

      expect(book.id, equals('book2'));
      expect(book.title, equals('JSON Book'));
      expect(book.author, equals('JSON Author'));
      expect(book.priceUsd, equals(12.99));
      expect(book.creditPrice, equals(2));
      expect(book.isFeatured, isTrue);
      expect(book.isNewRelease, isTrue);
      expect(book.isPurchased, isTrue);
      expect(book.isDownloaded, isFalse);
      expect(book.downloadProgress, equals(0.5));
      expect(book.chapters.length, equals(2));
      expect(book.chapters[0].title, equals('First Chapter'));
      expect(book.chapters[1].title, equals('Second Chapter'));
    });

    test('BrowseBook should handle empty chapters in JSON', () {
      final json = {
        'id': 'book3',
        'title': 'No Chapters Book',
        'author': 'Test Author',
        'cover_image_url': 'https://example.com/cover3.jpg',
        'chapters': [], // Empty chapters array
      };

      final book = BrowseBook.fromJson(json);

      expect(book.chapters, isEmpty);
      expect(book.title, equals('No Chapters Book'));
    });

    test('BrowseBook should handle missing chapters in JSON', () {
      final json = {
        'id': 'book4',
        'title': 'Missing Chapters Book',
        'author': 'Test Author',
        'cover_image_url': 'https://example.com/cover4.jpg',
        // chapters field is completely missing
      };

      final book = BrowseBook.fromJson(json);

      expect(book.chapters, isEmpty);
      expect(book.title, equals('Missing Chapters Book'));
    });

    test('BrowseBook copyWith should work with chapters', () {
      final originalChapters = [
        Chapter(
          id: 'ch1',
          title: 'Original Chapter',
          audioUrl: 'https://example.com/original.mp3',
          chapterNumber: 1,
        ),
      ];

      final newChapters = [
        Chapter(
          id: 'ch1',
          title: 'Updated Chapter',
          audioUrl: 'https://example.com/updated.mp3',
          chapterNumber: 1,
        ),
        Chapter(
          id: 'ch2',
          title: 'New Chapter',
          audioUrl: 'https://example.com/new.mp3',
          chapterNumber: 2,
        ),
      ];

      final originalBook = BrowseBook(
        id: 'book1',
        title: 'Original Book',
        author: 'Original Author',
        coverImageUrl: 'https://example.com/cover.jpg',
        chapters: originalChapters,
      );

      final updatedBook = originalBook.copyWith(
        title: 'Updated Book',
        chapters: newChapters,
      );

      expect(updatedBook.title, equals('Updated Book'));
      expect(updatedBook.author, equals('Original Author')); // Unchanged
      expect(updatedBook.chapters.length, equals(2));
      expect(updatedBook.chapters[0].title, equals('Updated Chapter'));
      expect(updatedBook.chapters[1].title, equals('New Chapter'));
    });
  });

  group('DetailedBook Model Tests', () {
    test('DetailedBook should handle chapters correctly', () {
      final chapters = [
        Chapter(
          id: 'ch1',
          title: 'Detailed Chapter 1',
          audioUrl: 'https://example.com/detailed1.mp3',
          chapterNumber: 1,
          duration: 2400,
        ),
      ];

      final detailedBook = DetailedBook(
        id: 'detailed1',
        title: 'Detailed Book',
        author: 'Detailed Author',
        description: 'A very detailed book description',
        coverImageUrl: 'https://example.com/detailed.jpg',
        chapters: chapters,
        totalDuration: 2400,
      );

      expect(detailedBook.chapters.length, equals(1));
      expect(detailedBook.chapters[0].title, equals('Detailed Chapter 1'));
      expect(detailedBook.totalDuration, equals(2400));
    });

    test('DetailedBook should create from JSON with chapters', () {
      final json = {
        'id': 'detailed2',
        'title': 'JSON Detailed Book',
        'author': 'JSON Detailed Author',
        'description': 'JSON description',
        'cover_image_url': 'https://example.com/json_detailed.jpg',
        'total_duration': 4800,
        'chapters': [
          {
            'id': 'ch1',
            'title': 'JSON Chapter 1',
            'audio_url': 'https://example.com/json_ch1.mp3',
            'chapter_number': 1,
            'duration': 2400,
          }
        ],
      };

      final detailedBook = DetailedBook.fromJson(json);

      expect(detailedBook.id, equals('detailed2'));
      expect(detailedBook.title, equals('JSON Detailed Book'));
      expect(detailedBook.description, equals('JSON description'));
      expect(detailedBook.totalDuration, equals(4800));
      expect(detailedBook.chapters.length, equals(1));
      expect(detailedBook.chapters[0].title, equals('JSON Chapter 1'));
    });
  });

  group('BrowseResponse Model Tests', () {
    test('BrowseResponse should create with books containing chapters', () {
      final chaptersBook1 = [
        Chapter(
          id: 'b1ch1',
          title: 'Book 1 Chapter 1',
          audioUrl: 'https://example.com/b1ch1.mp3',
          chapterNumber: 1,
        ),
      ];

      final book1 = BrowseBook(
        id: 'b1',
        title: 'Book with Chapters',
        author: 'Author 1',
        coverImageUrl: 'https://example.com/b1.jpg',
        chapters: chaptersBook1,
      );

      final book2 = BrowseBook(
        id: 'b2',
        title: 'Book without Chapters',
        author: 'Author 2',
        coverImageUrl: 'https://example.com/b2.jpg',
        // No chapters
      );

      final response = BrowseResponse(
        books: [book1, book2],
        totalCount: 2,
        page: 1,
        pageSize: 20,
        hasNextPage: false,
      );

      expect(response.books.length, equals(2));
      expect(response.books[0].chapters.length, equals(1));
      expect(response.books[1].chapters.length, equals(0));
      expect(response.totalCount, equals(2));
    });
  });
}