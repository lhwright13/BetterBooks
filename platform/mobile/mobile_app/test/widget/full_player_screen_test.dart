import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:echowright_rebuilt/presentation/screens/player/full_player_screen.dart';
import 'package:echowright_rebuilt/presentation/widgets/enhanced_book_cover.dart';
import 'package:echowright_rebuilt/presentation/widgets/chapter_selector_sheet.dart';
import 'package:echowright_rebuilt/data/models/book_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock system plugins
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  group('Enhanced FullPlayerScreen Widget Tests', () {
    late BrowseBook testBookWithChapters;
    late BrowseBook testBookWithoutChapters;

    setUp(() {
      testBookWithChapters = BrowseBook(
        id: 'book1',
        title: 'Test Audiobook',
        author: 'Test Author',
        coverImageUrl: 'https://example.com/cover.jpg',
        chapters: [
          Chapter(
            id: 'ch1',
            title: 'Chapter 1: Introduction',
            audioUrl: 'https://example.com/ch1.mp3',
            chapterNumber: 1,
            duration: 1800,
          ),
          Chapter(
            id: 'ch2',
            title: 'Chapter 2: Development',
            audioUrl: 'https://example.com/ch2.mp3',
            chapterNumber: 2,
            duration: 2100,
          ),
          Chapter(
            id: 'ch3',
            title: 'Chapter 3: Conclusion',
            audioUrl: 'https://example.com/ch3.mp3',
            chapterNumber: 3,
            duration: 1500,
          ),
        ],
      );

      testBookWithoutChapters = BrowseBook(
        id: 'book2',
        title: 'Simple Audiobook',
        author: 'Simple Author',
        coverImageUrl: 'https://example.com/simple.jpg',
        chapters: [], // No chapters
      );
    });

    testWidgets('should display enhanced player screen with chapters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Should show app bar with title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Test Audiobook'), findsOneWidget);

      // Should show chapter list button when chapters exist
      expect(find.byIcon(Icons.list), findsOneWidget);

      // Should show enhanced book cover
      expect(find.byType(EnhancedBookCover), findsOneWidget);

      // Should show book title and author
      expect(find.text('Test Audiobook'), findsAtLeastNWidgets(1));
      expect(find.text('By Test Author'), findsOneWidget);

      // Should show chapter indicator
      expect(find.text('Chapter 1 of 3'), findsOneWidget);
      expect(find.text('Chapter 1: Introduction'), findsOneWidget);

      // Should show player controls
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);

      // Should show floating action button for voice AI
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);

      print('✅ Enhanced FullPlayerScreen displays correctly with chapters');
    });

    testWidgets('should display player screen without chapters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithoutChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Should show app bar with title
      expect(find.text('Simple Audiobook'), findsOneWidget);

      // Should NOT show chapter list button when no chapters
      expect(find.byIcon(Icons.list), findsNothing);

      // Should show enhanced book cover
      expect(find.byType(EnhancedBookCover), findsOneWidget);

      // Should show "Ready to play" instead of chapter info
      expect(find.text('Ready to play'), findsOneWidget);

      // Should still show floating action button
      expect(find.byType(FloatingActionButton), findsOneWidget);

      print('✅ Enhanced FullPlayerScreen displays correctly without chapters');
    });

    testWidgets('should open chapter selector when list button is tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the chapter list button
      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      // Should show chapter selector sheet
      expect(find.byType(ChapterSelectorSheet), findsOneWidget);
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('Chapter 1: Introduction'), findsOneWidget);

      print('✅ Chapter selector opens when list button is tapped');
    });

    testWidgets('should handle chapter selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Should start with Chapter 1
      expect(find.text('Chapter 1 of 3'), findsOneWidget);

      // Open chapter selector
      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      // Select Chapter 3
      await tester.tap(find.text('Chapter 3: Conclusion'));
      await tester.pumpAndSettle();

      // Should show Chapter 3 as current
      expect(find.text('Chapter 3 of 3'), findsOneWidget);
      expect(find.text('Chapter 3: Conclusion'), findsOneWidget);

      // Should show snackbar with confirmation
      expect(find.text('Switched to Chapter 3'), findsOneWidget);

      print('✅ Chapter selection works correctly');
    });

    testWidgets('should handle voice AI button tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the voice AI button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Should show voice AI snackbar
      expect(find.text('Voice AI chat coming soon!'), findsOneWidget);
      expect(find.text('Learn More'), findsOneWidget);

      print('✅ Voice AI button tap works correctly');
    });

    testWidgets('should handle playback toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Should initially show play button
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Find the main play button (in the circular container)
      final playButton = find.descendant(
        of: find.byType(Container),
        matching: find.byIcon(Icons.play_arrow),
      );

      // Tap play button
      await tester.tap(playButton.first);
      await tester.pumpAndSettle();

      // Should now show pause button
      expect(find.byIcon(Icons.pause), findsOneWidget);

      print('✅ Playback toggle works correctly');
    });

    testWidgets('should handle speed menu', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Should show default speed
      expect(find.text('1.0x'), findsOneWidget);

      // Tap speed button
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();

      // Should show speed menu
      expect(find.text('Playback Speed'), findsOneWidget);
      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1.25x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);

      // Select 1.5x speed
      await tester.tap(find.text('1.5x'));
      await tester.pumpAndSettle();

      // Should show updated speed
      expect(find.text('1.5x'), findsOneWidget);

      print('✅ Speed menu works correctly');
    });

    testWidgets('should handle sleep timer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Tap sleep timer button
      await tester.tap(find.byIcon(Icons.timer));
      await tester.pumpAndSettle();

      // Should show sleep timer dialog
      expect(find.text('Sleep Timer'), findsOneWidget);
      expect(find.text('Sleep timer functionality coming soon!'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      print('✅ Sleep timer dialog works correctly');
    });

    testWidgets('should handle bookmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Tap bookmark button
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();

      // Should show bookmark confirmation
      expect(find.text('Bookmark added'), findsOneWidget);

      print('✅ Bookmark functionality works correctly');
    });

    testWidgets('should handle options menu', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Tap options menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Should show options menu
      expect(find.text('Chat with AI'), findsOneWidget);
      expect(find.text('Add Note'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      // Test Chat with AI option
      await tester.tap(find.text('Chat with AI'));
      await tester.pumpAndSettle();

      print('✅ Options menu works correctly');
    });

    testWidgets('should handle progress slider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Should show progress slider
      expect(find.byType(Slider), findsOneWidget);

      // Should show time labels
      expect(find.text('12:34'), findsOneWidget);
      expect(find.text('36:52'), findsOneWidget);

      // Test slider interaction
      final slider = find.byType(Slider);
      await tester.tap(slider);
      await tester.pumpAndSettle();

      print('✅ Progress slider works correctly');
    });

    testWidgets('should display chapter indicator correctly for different chapters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows Chapter 1
      expect(find.text('Chapter 1 of 3'), findsOneWidget);
      expect(find.text('Chapter 1: Introduction'), findsOneWidget);

      // Open chapter selector and select Chapter 2
      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chapter 2: Development'));
      await tester.pumpAndSettle();

      // Should now show Chapter 2
      expect(find.text('Chapter 2 of 3'), findsOneWidget);
      expect(find.text('Chapter 2: Development'), findsOneWidget);

      print('✅ Chapter indicator updates correctly');
    });

    testWidgets('should handle back navigation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(),
          ),
          routes: {
            '/player': (context) => FullPlayerScreen(book: testBookWithChapters),
          },
        ),
      );

      // Navigate to player
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(Scaffold))).pushNamed('/player');
      await tester.pumpAndSettle();

      // Should show back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      print('✅ Back navigation works correctly');
    });

    testWidgets('should maintain responsiveness across different screen sizes', (tester) async {
      // Test with smaller screen
      tester.binding.window.physicalSizeTestValue = const Size(350, 600);
      tester.binding.window.devicePixelRatioTestValue = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: FullPlayerScreen(book: testBookWithChapters),
        ),
      );

      await tester.pumpAndSettle();

      // Should still display key components
      expect(find.byType(EnhancedBookCover), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Chapter 1 of 3'), findsOneWidget);

      // Reset screen size
      addTearDown(() {
        tester.binding.window.clearPhysicalSizeTestValue();
        tester.binding.window.clearDevicePixelRatioTestValue();
      });

      print('✅ Player screen is responsive across different screen sizes');
    });
  });
}