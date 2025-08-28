import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:echowright/screens/library_screen.dart';
import 'package:echowright/providers/app_state.dart';
import 'package:echowright/providers/auth_provider.dart';
import 'package:echowright/models/book.dart';

class MockAppState extends ChangeNotifier {
  List<Book> _purchasedBooks = [];
  bool _isLoading = false;
  String? _error;

  List<Book> get purchasedBooks => _purchasedBooks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPurchasedBooks(String userId) async {
    _isLoading = true;
    notifyListeners();
    
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 100));
    
    _purchasedBooks = [
      Book(
        id: 'test-book-1',
        title: 'Test Book 1',
        author: 'Test Author 1',
        coverUrl: 'https://example.com/cover1.jpg',
      ),
      Book(
        id: 'test-book-2',
        title: 'Test Book 2',
        author: 'Test Author 2',
        coverUrl: null, // Test missing cover
      ),
    ];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> playBook(Book book, [Chapter? chapter]) async {
    // Mock implementation
  }
}

class MockAuthProvider extends ChangeNotifier {
  bool get isAuthenticated => true;
  User? get currentUser => User(
    id: 'test-user',
    firstName: 'Test',
    lastName: 'User',
    email: 'test@example.com',
  );
}

void main() {
  group('BookCard Widget Tests', () {
    late MockAppState mockAppState;
    late MockAuthProvider mockAuthProvider;

    setUp(() {
      mockAppState = MockAppState();
      mockAuthProvider = MockAuthProvider();
    });

    Widget createTestWidget({required Widget child}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    testWidgets('BookCard displays book information correctly', (WidgetTester tester) async {
      // Arrange
      final book = Book(
        id: 'test-book',
        title: 'Test Book Title',
        author: 'Test Author',
        coverUrl: 'https://example.com/cover.jpg',
      );

      // Act
      await tester.pumpWidget(
        createTestWidget(
          child: BookCard(book: book),
        ),
      );

      // Assert
      expect(find.text('Test Book Title'), findsOneWidget);
      expect(find.text('Test Author'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('BookCard shows icon when cover URL is null', (WidgetTester tester) async {
      // Arrange
      final book = Book(
        id: 'test-book-no-cover',
        title: 'Book Without Cover',
        author: 'Test Author',
        coverUrl: null,
      );

      // Act
      await tester.pumpWidget(
        createTestWidget(
          child: BookCard(book: book),
        ),
      );

      // Assert
      expect(find.text('Book Without Cover'), findsOneWidget);
      expect(find.text('Test Author'), findsOneWidget);
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
    });

    testWidgets('BookCard shows chapters icon when book has chapters', (WidgetTester tester) async {
      // Arrange
      final book = Book(
        id: 'test-book-chapters',
        title: 'Book With Chapters',
        author: 'Test Author',
        chapters: [
          Chapter(
            id: 'ch1',
            title: 'Chapter 1',
            audioUrl: 'url',
            chapterNumber: 1,
          )
        ],
      );

      // Act
      await tester.pumpWidget(
        createTestWidget(
          child: BookCard(book: book),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.text('1 chapters'), findsOneWidget);
    });

    testWidgets('BookCard handles missing author gracefully', (WidgetTester tester) async {
      // Arrange
      final book = Book(
        id: 'test-book-no-author',
        title: 'Book Without Author',
        author: null,
      );

      // Act
      await tester.pumpWidget(
        createTestWidget(
          child: BookCard(book: book),
        ),
      );

      // Assert
      expect(find.text('Book Without Author'), findsOneWidget);
      // Should not show author text when author is null
      expect(find.text('Test Author'), findsNothing);
    });

    testWidgets('BookCard play button is tappable', (WidgetTester tester) async {
      // Arrange
      final book = Book(
        id: 'test-book-play',
        title: 'Playable Book',
        audioUrl: 'https://example.com/audio.mp3',
      );

      // Act
      await tester.pumpWidget(
        createTestWidget(
          child: BookCard(book: book),
        ),
      );

      // Find and tap the play button
      final playButton = find.byIcon(Icons.play_arrow_rounded);
      expect(playButton, findsOneWidget);
      
      await tester.tap(playButton);
      await tester.pump();

      // Assert - The test passes if no exception is thrown
      expect(playButton, findsOneWidget);
    });

    testWidgets('BookCard entire card is tappable', (WidgetTester tester) async {
      // Arrange
      final book = Book(
        id: 'test-book-tap',
        title: 'Tappable Book',
        audioUrl: 'https://example.com/audio.mp3',
      );

      // Act
      await tester.pumpWidget(
        createTestWidget(
          child: BookCard(book: book),
        ),
      );

      // Find and tap the card
      final card = find.byType(InkWell).first;
      await tester.tap(card);
      await tester.pump();

      // Assert - The test passes if no exception is thrown
      expect(find.text('Tappable Book'), findsOneWidget);
    });

    testWidgets('BookCard displays loading state for cover image', (WidgetTester tester) async {
      // Arrange
      final book = Book(
        id: 'test-book-loading',
        title: 'Book With Loading Cover',
        coverUrl: 'https://example.com/slow-loading-cover.jpg',
      );

      // Act
      await tester.pumpWidget(
        createTestWidget(
          child: BookCard(book: book),
        ),
      );

      // The image widget should be present
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('BookCard truncates long titles', (WidgetTester tester) async {
      // Arrange
      final book = Book(
        id: 'test-book-long-title',
        title: 'This is a Very Long Book Title That Should Be Truncated When Displayed',
        author: 'Test Author',
      );

      // Act
      await tester.pumpWidget(
        createTestWidget(
          child: BookCard(book: book),
        ),
      );

      // Assert
      expect(find.textContaining('This is a Very Long'), findsOneWidget);
      // Check that the Text widget has maxLines and overflow properties
      final textWidget = tester.widget<Text>(find.text('This is a Very Long Book Title That Should Be Truncated When Displayed'));
      expect(textWidget.maxLines, equals(2));
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));
    });
  });

  group('LibraryScreen Integration Tests', () {
    late MockAppState mockAppState;
    late MockAuthProvider mockAuthProvider;

    setUp(() {
      mockAppState = MockAppState();
      mockAuthProvider = MockAuthProvider();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ],
        child: MaterialApp(
          home: LibraryScreen(),
          routes: {
            '/store': (context) => Scaffold(body: Text('Store')),
            '/player': (context) => Scaffold(body: Text('Player')),
          },
        ),
      );
    }

    testWidgets('LibraryScreen displays loading indicator', (WidgetTester tester) async {
      // Arrange
      mockAppState._isLoading = true;

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('LibraryScreen displays error message', (WidgetTester tester) async {
      // Arrange
      mockAppState._error = 'Failed to load books';
      mockAppState._isLoading = false;

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Error loading books'), findsOneWidget);
      expect(find.text('Failed to load books'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('LibraryScreen displays empty state', (WidgetTester tester) async {
      // Arrange
      mockAppState._purchasedBooks = [];
      mockAppState._isLoading = false;
      mockAppState._error = null;

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Your library is empty'), findsOneWidget);
      expect(find.text('Start building your audiobook collection'), findsOneWidget);
      expect(find.text('Browse Store'), findsOneWidget);
    });

    testWidgets('LibraryScreen displays books list', (WidgetTester tester) async {
      // Arrange
      mockAppState._purchasedBooks = [
        Book(id: '1', title: 'Book 1', author: 'Author 1'),
        Book(id: '2', title: 'Book 2', author: 'Author 2'),
      ];
      mockAppState._isLoading = false;
      mockAppState._error = null;

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(BookCard), findsNWidgets(2));
      expect(find.text('Book 1'), findsOneWidget);
      expect(find.text('Book 2'), findsOneWidget);
      expect(find.text('Author 1'), findsOneWidget);
      expect(find.text('Author 2'), findsOneWidget);
    });

    testWidgets('LibraryScreen retry button works', (WidgetTester tester) async {
      // Arrange
      mockAppState._error = 'Network error';
      mockAppState._isLoading = false;

      // Act
      await tester.pumpWidget(createTestWidget());
      
      // Find and tap the retry button
      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);
      
      await tester.tap(retryButton);
      await tester.pump();

      // Assert - The test passes if no exception is thrown
      expect(retryButton, findsOneWidget);
    });

    testWidgets('LibraryScreen browse store button navigates', (WidgetTester tester) async {
      // Arrange
      mockAppState._purchasedBooks = [];
      mockAppState._isLoading = false;
      mockAppState._error = null;

      // Act
      await tester.pumpWidget(createTestWidget());
      
      // Find and tap the browse store button
      final browseButton = find.text('Browse Store');
      expect(browseButton, findsOneWidget);
      
      await tester.tap(browseButton);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Store'), findsOneWidget);
    });
  });
}

// Mock User class for testing
class User {
  final String id;
  final String firstName;
  final String lastName;
  final String email;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });
}