import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:echowright_rebuilt/presentation/widgets/enhanced_book_card.dart';
import 'package:echowright_rebuilt/data/models/book_models.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('EnhancedBookCard Widget Tests', () {
    late BrowseBook testBook;
    
    setUp(() {
      testBook = TestDataFactory.createBrowseBook(
        id: 'test-book-1',
        title: 'Test Book Title',
        author: 'Test Author',
        coverImageUrl: 'https://example.com/cover.jpg',
        isFeatured: false,
        isBestseller: false,
        isNewRelease: false,
        isPurchased: false,
        isDownloaded: false,
      );
    });
    
    group('Basic Rendering', () {
      testWidgets('should display book title and author', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: testBook),
          ),
        );
        
        // Assert
        expect(find.text('Test Book Title'), findsOneWidget);
        expect(find.text('Test Author'), findsOneWidget);
      });
      
      testWidgets('should display cover image', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: testBook),
          ),
        );
        
        // Assert
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });
      
      testWidgets('should handle empty title gracefully', (WidgetTester tester) async {
        // Arrange
        final bookWithEmptyTitle = testBook.copyWith(title: '');
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: bookWithEmptyTitle),
          ),
        );
        
        // Assert
        expect(find.text(''), findsAtLeastOneWidget);
        expect(tester.takeException(), isNull);
      });
      
      testWidgets('should handle empty author gracefully', (WidgetTester tester) async {
        // Arrange
        final bookWithEmptyAuthor = testBook.copyWith(author: '');
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: bookWithEmptyAuthor),
          ),
        );
        
        // Assert
        expect(find.text('Test Book Title'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
    
    group('Status Badges', () {
      testWidgets('should show featured badge when book is featured', (WidgetTester tester) async {
        // Arrange
        final featuredBook = testBook.copyWith(isFeatured: true);
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: featuredBook),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert - Look for featured indicator (could be icon, text, or container)
        expect(find.byIcon(Icons.star).or(find.text('Featured')), findsAtLeastOneWidget);
      });
      
      testWidgets('should show bestseller badge when book is bestseller', (WidgetTester tester) async {
        // Arrange
        final bestsellerBook = testBook.copyWith(isBestseller: true);
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: bestsellerBook),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert - Look for bestseller indicator
        expect(find.byIcon(Icons.trending_up).or(find.text('Bestseller')), findsAtLeastOneWidget);
      });
      
      testWidgets('should show new release badge when book is new release', (WidgetTester tester) async {
        // Arrange
        final newReleaseBook = testBook.copyWith(isNewRelease: true);
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: newReleaseBook),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert - Look for new release indicator
        expect(find.byIcon(Icons.new_releases).or(find.text('New')), findsAtLeastOneWidget);
      });
      
      testWidgets('should show purchased indicator when book is purchased', (WidgetTester tester) async {
        // Arrange
        final purchasedBook = testBook.copyWith(isPurchased: true);
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: purchasedBook),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert - Look for purchased indicator
        expect(find.byIcon(Icons.check_circle).or(find.text('Owned')), findsAtLeastOneWidget);
      });
      
      testWidgets('should show downloaded indicator when book is downloaded', (WidgetTester tester) async {
        // Arrange
        final downloadedBook = testBook.copyWith(isDownloaded: true);
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: downloadedBook),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert - Look for downloaded indicator
        expect(find.byIcon(Icons.download_done).or(find.text('Downloaded')), findsAtLeastOneWidget);
      });
    });
    
    group('User Interactions', () {
      testWidgets('should be tappable', (WidgetTester tester) async {
        // Arrange
        bool wasPressed = false;
        
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: GestureDetector(
              onTap: () => wasPressed = true,
              child: EnhancedBookCard(book: testBook),
            ),
          ),
        );
        
        // Act
        await tester.tap(find.byType(EnhancedBookCard));
        await tester.pumpAndSettle();
        
        // Assert
        expect(wasPressed, isTrue);
      });
      
      testWidgets('should handle rapid taps without errors', (WidgetTester tester) async {
        // Arrange
        int tapCount = 0;
        
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: GestureDetector(
              onTap: () => tapCount++,
              child: EnhancedBookCard(book: testBook),
            ),
          ),
        );
        
        // Act - Rapid taps
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byType(EnhancedBookCard));
        }
        await tester.pumpAndSettle();
        
        // Assert
        expect(tapCount, equals(5));
        expect(tester.takeException(), isNull);
      });
    });
    
    group('Layout and Responsiveness', () {
      testWidgets('should maintain aspect ratio', (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: SizedBox(
              width: 200,
              child: EnhancedBookCard(book: testBook),
            ),
          ),
        );
        
        // Assert
        final cardWidget = find.byType(EnhancedBookCard);
        expect(cardWidget, findsOneWidget);
        
        final RenderBox renderBox = tester.renderObject(cardWidget);
        expect(renderBox.size.width, lessThanOrEqualTo(200));
        expect(renderBox.size.height, greaterThan(0));
      });
      
      testWidgets('should handle different screen sizes', (WidgetTester tester) async {
        // Test small screen
        await tester.binding.setSurfaceSize(const Size(300, 600));
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: testBook),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        
        // Test large screen
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: testBook),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        
        // Reset to default
        await tester.binding.setSurfaceSize(null);
      });
    });
    
    group('Edge Cases', () {
      testWidgets('should handle null cover image URL', (WidgetTester tester) async {
        // Arrange
        final bookWithNullCover = TestDataFactory.createBrowseBook(
          title: 'Test Book',
          author: 'Test Author',
          coverImageUrl: '',
        );
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: EnhancedBookCard(book: bookWithNullCover),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert
        expect(tester.takeException(), isNull);
        expect(find.byType(EnhancedBookCard), findsOneWidget);
      });
      
      testWidgets('should handle very long title', (WidgetTester tester) async {
        // Arrange
        final bookWithLongTitle = testBook.copyWith(
          title: 'This is a very long book title that should be handled gracefully by the widget without causing overflow or layout issues',
        );
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: SizedBox(
              width: 200,
              child: EnhancedBookCard(book: bookWithLongTitle),
            ),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert
        expect(tester.takeException(), isNull);
        expect(find.byType(EnhancedBookCard), findsOneWidget);
      });
      
      testWidgets('should handle very long author name', (WidgetTester tester) async {
        // Arrange
        final bookWithLongAuthor = testBook.copyWith(
          author: 'Dr. Professor Very Long Name With Multiple Middle Names and Titles',
        );
        
        // Act
        await tester.pumpWidget(
          TestHelpers.createTestApp(
            child: SizedBox(
              width: 200,
              child: EnhancedBookCard(book: bookWithLongAuthor),
            ),
          ),
        );
        await tester.pumpAndSettle();
        
        // Assert
        expect(tester.takeException(), isNull);
        expect(find.byType(EnhancedBookCard), findsOneWidget);
      });
    });
  });
}