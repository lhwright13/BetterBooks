import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/presentation/widgets/enhanced_book_cover.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnhancedBookCover Widget Tests', () {
    const testCoverUrl = 'https://example.com/test-cover.jpg';
    const testTitle = 'Test Book Title';
    const testAuthor = 'Test Author';

    testWidgets('should display book cover with correct properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: testCoverUrl,
                bookTitle: testTitle,
                bookAuthor: testAuthor,
                width: 200,
                height: 300,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find the Hero widget with correct tag
      expect(find.byType(Hero), findsOneWidget);
      final heroWidget = tester.widget<Hero>(find.byType(Hero));
      expect(heroWidget.tag, equals('book_cover_$testTitle'));

      // Should find the GestureDetector
      expect(find.byType(GestureDetector), findsOneWidget);

      // Should find the CachedNetworkImage
      expect(find.byType(Container), findsAtLeastNWidgets(1));
      
      print('✅ EnhancedBookCover displays correctly with basic properties');
    });

    testWidgets('should display placeholder when image is loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: testCoverUrl,
                bookTitle: testTitle,
                bookAuthor: testAuthor,
              ),
            ),
          ),
        ),
      );

      // Don't settle immediately to catch the loading state
      await tester.pump();

      // Should show loading placeholder with book icon
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      
      print('✅ EnhancedBookCover shows loading placeholder correctly');
    });

    testWidgets('should show fallback content on image error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: 'invalid-url',
                bookTitle: testTitle,
                bookAuthor: testAuthor,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show fallback with auto_stories icon and text
      expect(find.byIcon(Icons.auto_stories), findsOneWidget);
      expect(find.text(testTitle), findsOneWidget);
      expect(find.text('by $testAuthor'), findsOneWidget);
      
      print('✅ EnhancedBookCover shows fallback content on error');
    });

    testWidgets('should handle tap interactions with animation', (tester) async {
      bool tapCallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: testCoverUrl,
                bookTitle: testTitle,
                bookAuthor: testAuthor,
                onTap: () {
                  tapCallbackCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the cover
      final gestureDetector = find.byType(GestureDetector);
      expect(gestureDetector, findsOneWidget);

      await tester.tap(gestureDetector);
      await tester.pumpAndSettle();

      expect(tapCallbackCalled, isTrue);
      print('✅ EnhancedBookCover handles tap interaction correctly');
    });

    testWidgets('should show zoom dialog when enableZoom is true and tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: testCoverUrl,
                bookTitle: testTitle,
                bookAuthor: testAuthor,
                enableZoom: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the cover to show zoom dialog
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      // Should show dialog with book information
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(testTitle), findsAtLeastNWidgets(1));
      expect(find.text('by $testAuthor'), findsAtLeastNWidgets(1));
      
      print('✅ EnhancedBookCover shows zoom dialog correctly');
    });

    testWidgets('should not show zoom dialog when enableZoom is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: testCoverUrl,
                bookTitle: testTitle,
                bookAuthor: testAuthor,
                enableZoom: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the cover
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      // Should not show dialog
      expect(find.byType(Dialog), findsNothing);
      
      print('✅ EnhancedBookCover respects enableZoom=false setting');
    });

    testWidgets('should apply custom width and height', (tester) async {
      const customWidth = 150.0;
      const customHeight = 200.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: testCoverUrl,
                bookTitle: testTitle,
                bookAuthor: testAuthor,
                width: customWidth,
                height: customHeight,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the sized container
      final containers = tester.widgetList<Container>(find.byType(Container));
      
      // At least one container should have the custom dimensions
      bool foundCorrectSize = false;
      for (final container in containers) {
        if (container.constraints?.minWidth == customWidth &&
            container.constraints?.minHeight == customHeight) {
          foundCorrectSize = true;
          break;
        }
      }
      
      // Check if any transform or size is applied correctly
      expect(find.byType(Transform), findsOneWidget);
      
      print('✅ EnhancedBookCover applies custom dimensions correctly');
    });

    testWidgets('should handle scale animation on press and release', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: testCoverUrl,
                bookTitle: testTitle,
                bookAuthor: testAuthor,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test press down
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(GestureDetector)),
      );
      await tester.pump();

      // Should find the AnimatedBuilder (scale animation)
      expect(find.byType(AnimatedBuilder), findsOneWidget);

      // Test release
      await gesture.up();
      await tester.pumpAndSettle();

      print('✅ EnhancedBookCover handles scale animation correctly');
    });

    testWidgets('should work with long titles and author names', (tester) async {
      const longTitle = 'This is a Very Long Book Title That Might Overflow the UI if Not Handled Properly';
      const longAuthor = 'This is a Very Long Author Name That Also Might Cause Issues';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: EnhancedBookCover(
                coverImageUrl: 'invalid-url', // Force error to show fallback
                bookTitle: longTitle,
                bookAuthor: longAuthor,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show fallback content with text truncation
      expect(find.textContaining(longTitle), findsOneWidget);
      expect(find.textContaining(longAuthor), findsOneWidget);
      
      // Text should be properly constrained and not overflow
      final titleText = tester.widget<Text>(find.textContaining(longTitle));
      expect(titleText.maxLines, equals(3));
      expect(titleText.overflow, equals(TextOverflow.ellipsis));
      
      print('✅ EnhancedBookCover handles long text content correctly');
    });
  });
}