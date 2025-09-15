import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/services/download_service.dart';
import '../../helpers/test_helpers.dart';
import '../../helpers/simple_mocks.dart';

void main() {
  group('DownloadService Tests', () {
    late MockDownloadService mockDownloadService;
    late TestDataFactory testDataFactory;
    
    setUp(() {
      mockDownloadService = MockDownloadService();
      testDataFactory = TestDataFactory();
    });
    
    group('Download Status', () {
      test('should return false for undownloaded book', () async {
        // Arrange
        const bookId = 'test-book-1';
        
        // Act
        final result = await mockDownloadService.isBookDownloaded(bookId);
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should return true after downloading book', () async {
        // Arrange
        const bookId = 'test-book-1';
        final testBook = TestDataFactory.createBrowseBook(id: bookId);
        
        // Act
        await mockDownloadService.downloadBook(testBook);
        final result = await mockDownloadService.isBookDownloaded(bookId);
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should track downloading state during download', () async {
        // Arrange
        const bookId = 'test-book-1';
        mockDownloadService.setDownloading(bookId, true);
        
        // Act
        final result = mockDownloadService.isDownloading(bookId);
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should not be downloading after download completes', () async {
        // Arrange
        const bookId = 'test-book-1';
        final testBook = TestDataFactory.createBrowseBook(id: bookId);
        
        // Act
        await mockDownloadService.downloadBook(testBook);
        final result = mockDownloadService.isDownloading(bookId);
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('Download Management', () {
      test('should handle multiple book downloads', () async {
        // Arrange
        final books = [
          TestDataFactory.createBrowseBook(id: 'book-1'),
          TestDataFactory.createBrowseBook(id: 'book-2'),
          TestDataFactory.createBrowseBook(id: 'book-3'),
        ];
        
        // Act
        for (final book in books) {
          await mockDownloadService.downloadBook(book);
        }
        
        // Assert
        for (final book in books) {
          final isDownloaded = await mockDownloadService.isBookDownloaded(book.id);
          expect(isDownloaded, isTrue);
        }
      });
      
      test('should handle download with retry flag', () async {
        // Arrange
        const bookId = 'test-book-1';
        final testBook = TestDataFactory.createBrowseBook(id: bookId);
        
        // Act
        await mockDownloadService.downloadBook(testBook, isRetry: true);
        final result = await mockDownloadService.isBookDownloaded(bookId);
        
        // Assert
        expect(result, isTrue);
      });
      
      test('should track different books independently', () async {
        // Arrange
        const bookId1 = 'book-1';
        const bookId2 = 'book-2';
        final book1 = TestDataFactory.createBrowseBook(id: bookId1);
        
        // Act
        await mockDownloadService.downloadBook(book1);
        
        // Assert
        expect(await mockDownloadService.isBookDownloaded(bookId1), isTrue);
        expect(await mockDownloadService.isBookDownloaded(bookId2), isFalse);
      });
    });
    
    group('Edge Cases', () {
      test('should handle empty book ID', () async {
        // Act & Assert
        expect(await mockDownloadService.isBookDownloaded(''), isFalse);
        expect(mockDownloadService.isDownloading(''), isFalse);
      });
      
      test('should handle null checks gracefully', () async {
        // Arrange
        const bookId = 'nonexistent-book';
        
        // Act & Assert
        expect(await mockDownloadService.isBookDownloaded(bookId), isFalse);
        expect(mockDownloadService.isDownloading(bookId), isFalse);
      });
      
      test('should handle downloading same book multiple times', () async {
        // Arrange
        const bookId = 'test-book-1';
        final testBook = TestDataFactory.createBrowseBook(id: bookId);
        
        // Act
        await mockDownloadService.downloadBook(testBook);
        await mockDownloadService.downloadBook(testBook); // Download again
        
        // Assert
        expect(await mockDownloadService.isBookDownloaded(bookId), isTrue);
      });
    });
    
    group('State Management', () {
      test('should manually set download state', () async {
        // Arrange
        const bookId = 'test-book-1';
        
        // Act
        mockDownloadService.setDownloaded(bookId, true);
        
        // Assert
        expect(await mockDownloadService.isBookDownloaded(bookId), isTrue);
      });
      
      test('should manually set downloading state', () {
        // Arrange
        const bookId = 'test-book-1';
        
        // Act
        mockDownloadService.setDownloading(bookId, true);
        
        // Assert
        expect(mockDownloadService.isDownloading(bookId), isTrue);
      });
      
      test('should toggle download state', () async {
        // Arrange
        const bookId = 'test-book-1';
        
        // Act & Assert
        mockDownloadService.setDownloaded(bookId, true);
        expect(await mockDownloadService.isBookDownloaded(bookId), isTrue);
        
        mockDownloadService.setDownloaded(bookId, false);
        expect(await mockDownloadService.isBookDownloaded(bookId), isFalse);
      });
    });
  });
}