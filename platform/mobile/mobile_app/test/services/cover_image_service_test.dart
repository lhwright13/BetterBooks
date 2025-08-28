import 'package:flutter_test/flutter_test.dart';
import 'package:echowright/services/cover_image_service.dart';

void main() {
  group('CoverImageService', () {
    test('should handle fallback chain for cover images', () async {
      // Test with a book that has no backend cover
      final coverUrl = await CoverImageService.getCoverImageUrl(
        bookId: 'test-book',
        bookTitle: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
        backendCoverUrl: null, // Force fallback
      );

      // Should return a cover URL from OpenLibrary or Google Books
      expect(coverUrl, isNotNull);
      expect(coverUrl, contains('http'));
    });

    test('should return fallback URL when no covers found', () {
      final fallbackUrl = CoverImageService.getFallbackCoverUrl('Test Book');
      
      expect(fallbackUrl, isNotNull);
      expect(fallbackUrl, contains('placeholder'));
      expect(fallbackUrl, contains('Test'));
    });

    test('should cache results', () async {
      // First call
      final coverUrl1 = await CoverImageService.getCoverImageUrl(
        bookId: 'cache-test',
        bookTitle: 'Test Book',
      );

      // Second call should use cache
      final coverUrl2 = await CoverImageService.getCoverImageUrl(
        bookId: 'cache-test',
        bookTitle: 'Test Book',
      );

      expect(coverUrl1, equals(coverUrl2));
    });

    test('should handle preloading multiple covers', () async {
      final books = [
        {
          'id': 'book1',
          'title': 'The Great Gatsby',
          'author': 'F. Scott Fitzgerald',
        },
        {
          'id': 'book2',
          'title': 'Alice in Wonderland',
          'author': 'Lewis Carroll',
        }
      ];

      final results = await CoverImageService.preloadCovers(books);
      
      expect(results, hasLength(2));
      expect(results.keys, containsAll(['book1', 'book2']));
    });
  });
}