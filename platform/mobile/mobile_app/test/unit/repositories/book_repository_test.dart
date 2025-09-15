import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/data/repositories/book_repository.dart';
import 'package:get_it/get_it.dart';
import '../../helpers/test_helpers.dart';
import '../../helpers/simple_mocks.dart';

void main() {
  group('BookRepository Tests', () {
    late MockBookRepository mockBookRepository;
    
    setUp(() {
      TestHelpers.resetGetIt();
      mockBookRepository = MockBookRepository();
      GetIt.instance.registerSingleton<BookRepository>(mockBookRepository);
    });
    
    tearDown(() {
      GetIt.instance.reset();
    });
    
    group('getFeaturedBooks', () {
      test('should return list of featured books', () async {
        // Arrange
        final testBooks = [
          TestDataFactory.createBrowseBook(isFeatured: true),
          TestDataFactory.createBrowseBook(isFeatured: false),
          TestDataFactory.createBrowseBook(isFeatured: true),
        ];
        mockBookRepository.setMockBooks(testBooks);
        
        // Act
        final result = await mockBookRepository.getFeaturedBooks();
        
        // Assert
        expect(result, hasLength(2));
        expect(result.every((book) => book.isFeatured), isTrue);
      });
      
      test('should return empty list when no featured books exist', () async {
        // Arrange
        final testBooks = [
          TestDataFactory.createBrowseBook(isFeatured: false),
          TestDataFactory.createBrowseBook(isFeatured: false),
        ];
        mockBookRepository.setMockBooks(testBooks);
        
        // Act
        final result = await mockBookRepository.getFeaturedBooks();
        
        // Assert
        expect(result, isEmpty);
      });
    });
    
    group('getBestsellers', () {
      test('should return list of bestseller books', () async {
        // Arrange
        final testBooks = [
          TestDataFactory.createBrowseBook(isBestseller: true),
          TestDataFactory.createBrowseBook(isBestseller: false),
          TestDataFactory.createBrowseBook(isBestseller: true),
        ];
        mockBookRepository.setMockBooks(testBooks);
        
        // Act
        final result = await mockBookRepository.getBestsellers();
        
        // Assert
        expect(result, hasLength(2));
        expect(result.every((book) => book.isBestseller), isTrue);
      });
    });
    
    group('getNewReleases', () {
      test('should return list of new release books', () async {
        // Arrange
        final testBooks = [
          TestDataFactory.createBrowseBook(isNewRelease: true),
          TestDataFactory.createBrowseBook(isNewRelease: false),
          TestDataFactory.createBrowseBook(isNewRelease: true),
        ];
        mockBookRepository.setMockBooks(testBooks);
        
        // Act
        final result = await mockBookRepository.getNewReleases();
        
        // Assert
        expect(result, hasLength(2));
        expect(result.every((book) => book.isNewRelease), isTrue);
      });
    });
    
    group('browseBooks', () {
      test('should return all books when no filters applied', () async {
        // Arrange
        final testBooks = TestDataFactory.createBrowseBookList(count: 5);
        mockBookRepository.setMockBooks(testBooks);
        
        // Act
        final result = await mockBookRepository.getBrowseBooks();
        
        // Assert
        expect(result, hasLength(5));
        expect(result, equals(testBooks));
      });
      
      test('should handle empty book list', () async {
        // Arrange
        mockBookRepository.setMockBooks([]);
        
        // Act
        final result = await mockBookRepository.getBrowseBooks();
        
        // Assert
        expect(result, isEmpty);
      });
    });
    
    group('getBookDetails', () {
      test('should return detailed book when book exists', () async {
        // Arrange
        final testBook = TestDataFactory.createBrowseBook(id: 'test-book-id');
        mockBookRepository.setMockBooks([testBook]);
        
        // Act
        final result = await mockBookRepository.getBookDetails('test-book-id');
        
        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals('test-book-id'));
        expect(result.title, equals(testBook.title));
        expect(result.author, equals(testBook.author));
      });
      
      test('should throw when book does not exist', () async {
        // Arrange
        mockBookRepository.setMockBooks([]);
        
        // Act & Assert
        expect(
          () async => await mockBookRepository.getBookDetails('non-existent-id'),
          throwsA(isA<StateError>()),
        );
      });
    });
    
    group('edge cases', () {
      test('should handle books with null or empty properties', () async {
        // Arrange
        final testBook = TestDataFactory.createBrowseBook(
          title: '',
          author: '',
          audioUrl: null,
        );
        mockBookRepository.setMockBooks([testBook]);
        
        // Act
        final result = await mockBookRepository.getBrowseBooks();
        
        // Assert
        expect(result, hasLength(1));
        expect(result.first.title, isEmpty);
        expect(result.first.author, isEmpty);
        expect(result.first.audioUrl, isNull);
      });
      
      test('should handle large number of books', () async {
        // Arrange
        final testBooks = TestDataFactory.createBrowseBookList(count: 1000);
        mockBookRepository.setMockBooks(testBooks);
        
        // Act
        final result = await mockBookRepository.getBrowseBooks();
        
        // Assert
        expect(result, hasLength(1000));
      });
    });
  });
}