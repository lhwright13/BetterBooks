import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/presentation/widgets/chapter_selector_sheet.dart';
import 'package:echowright_rebuilt/data/models/book_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChapterSelectorSheet Widget Tests', () {
    late List<Chapter> testChapters;
    const testBookTitle = 'Test Book';
    int selectedChapterIndex = -1;

    void onChapterSelected(int index) {
      selectedChapterIndex = index;
    }

    setUp(() {
      testChapters = [
        Chapter(
          id: 'ch1',
          title: 'Chapter 1: The Beginning',
          audioUrl: 'https://example.com/ch1.mp3',
          chapterNumber: 1,
          duration: 1800, // 30 minutes
        ),
        Chapter(
          id: 'ch2',
          title: 'Chapter 2: The Journey Continues',
          audioUrl: 'https://example.com/ch2.mp3',
          chapterNumber: 2,
          duration: 2100, // 35 minutes
        ),
        Chapter(
          id: 'ch3',
          title: 'Chapter 3: The Final Chapter',
          audioUrl: 'https://example.com/ch3.mp3',
          chapterNumber: 3,
          duration: 1500, // 25 minutes
        ),
      ];
      selectedChapterIndex = -1; // Reset
    });

    testWidgets('should display chapter selector sheet with header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: testChapters,
              currentChapterIndex: 0,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show header with title and book information
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text(testBookTitle), findsOneWidget);
      expect(find.text('${testChapters.length} chapters'), findsOneWidget);
      
      // Should show the drag handle
      expect(find.byType(Container), findsAtLeastNWidgets(1));
      
      print('✅ ChapterSelectorSheet displays header correctly');
    });

    testWidgets('should display all chapters in the list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: testChapters,
              currentChapterIndex: 1,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display all chapter titles
      expect(find.text('Chapter 1: The Beginning'), findsOneWidget);
      expect(find.text('Chapter 2: The Journey Continues'), findsOneWidget);
      expect(find.text('Chapter 3: The Final Chapter'), findsOneWidget);

      // Should show chapter numbers
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsNothing); // Current chapter shows play icon instead
      expect(find.text('3'), findsOneWidget);

      // Should show durations
      expect(find.text('30:00'), findsOneWidget); // 1800 seconds
      expect(find.text('35:00'), findsOneWidget); // 2100 seconds
      expect(find.text('25:00'), findsOneWidget); // 1500 seconds

      print('✅ ChapterSelectorSheet displays all chapters correctly');
    });

    testWidgets('should highlight current chapter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: testChapters,
              currentChapterIndex: 1, // Chapter 2 is current
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show "Now Playing" for current chapter
      expect(find.text('Now Playing'), findsOneWidget);
      
      // Should show play icon for current chapter
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      // Should show play_circle_outline for non-current chapters
      expect(find.byIcon(Icons.play_circle_outline), findsAtLeastNWidgets(2));

      print('✅ ChapterSelectorSheet highlights current chapter correctly');
    });

    testWidgets('should handle chapter selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: testChapters,
              currentChapterIndex: 0,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on chapter 3
      await tester.tap(find.text('Chapter 3: The Final Chapter'));
      await tester.pumpAndSettle();

      // Callback should be called with correct index
      expect(selectedChapterIndex, equals(2)); // 0-indexed, so chapter 3 is index 2
      
      print('✅ ChapterSelectorSheet handles chapter selection correctly');
    });

    testWidgets('should show empty state when no chapters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: [],
              currentChapterIndex: 0,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text('No chapters available'), findsOneWidget);
      expect(find.text('This audiobook doesn\'t have chapter information.'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      
      // Should still show header
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('0 chapters'), findsOneWidget);

      print('✅ ChapterSelectorSheet shows empty state correctly');
    });

    testWidgets('should handle chapters without duration', (tester) async {
      final chaptersNoDuration = [
        Chapter(
          id: 'ch1',
          title: 'Chapter Without Duration',
          audioUrl: 'https://example.com/ch1.mp3',
          chapterNumber: 1,
          // No duration
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: chaptersNoDuration,
              currentChapterIndex: 0,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show chapter without duration info
      expect(find.text('Chapter Without Duration'), findsOneWidget);
      
      // Should not show access_time icon or duration text when duration is null
      expect(find.byIcon(Icons.access_time), findsNothing);

      print('✅ ChapterSelectorSheet handles chapters without duration correctly');
    });

    testWidgets('should display fade animation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: testChapters,
              currentChapterIndex: 0,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      // Should find AnimatedBuilder for fade animation
      expect(find.byType(AnimatedBuilder), findsOneWidget);

      // Pump animation
      await tester.pump(const Duration(milliseconds: 150));
      
      // Should still be animating
      expect(find.byType(AnimatedBuilder), findsOneWidget);

      await tester.pumpAndSettle();

      print('✅ ChapterSelectorSheet displays fade animation correctly');
    });

    testWidgets('should format duration correctly', (tester) async {
      final chaptersVariousDurations = [
        Chapter(
          id: 'ch1',
          title: 'Short Chapter',
          audioUrl: 'https://example.com/ch1.mp3',
          chapterNumber: 1,
          duration: 65, // 1 minute 5 seconds
        ),
        Chapter(
          id: 'ch2',
          title: 'Long Chapter',
          audioUrl: 'https://example.com/ch2.mp3',
          chapterNumber: 2,
          duration: 3661, // 1 hour 1 minute 1 second
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: chaptersVariousDurations,
              currentChapterIndex: 0,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should format durations correctly
      expect(find.text('1:05'), findsOneWidget); // 65 seconds
      expect(find.text('61:01'), findsOneWidget); // 3661 seconds

      print('✅ ChapterSelectorSheet formats durations correctly');
    });

    testWidgets('should handle long chapter titles properly', (tester) async {
      final chaptersLongTitles = [
        Chapter(
          id: 'ch1',
          title: 'This is a Very Long Chapter Title That Should Be Truncated Properly to Prevent UI Overflow Issues',
          audioUrl: 'https://example.com/ch1.mp3',
          chapterNumber: 1,
          duration: 1800,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: chaptersLongTitles,
              currentChapterIndex: 0,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display the long title (truncated by ListTile)
      expect(find.textContaining('This is a Very Long Chapter Title'), findsOneWidget);
      
      // Should find the ListTile that handles text overflow
      expect(find.byType(ListTile), findsOneWidget);

      print('✅ ChapterSelectorSheet handles long chapter titles correctly');
    });

    testWidgets('should handle out of bounds currentChapterIndex gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: testChapters,
              currentChapterIndex: 99, // Out of bounds
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not crash and should display chapters
      expect(find.text('Chapter 1: The Beginning'), findsOneWidget);
      expect(find.text('Chapter 2: The Journey Continues'), findsOneWidget);
      expect(find.text('Chapter 3: The Final Chapter'), findsOneWidget);
      
      // Should not show any "Now Playing" indicator
      expect(find.text('Now Playing'), findsNothing);

      print('✅ ChapterSelectorSheet handles out of bounds index gracefully');
    });

    testWidgets('should be scrollable with many chapters', (tester) async {
      // Create many chapters to test scrolling
      final manyChapters = List.generate(20, (index) => Chapter(
        id: 'ch${index + 1}',
        title: 'Chapter ${index + 1}: Test Chapter',
        audioUrl: 'https://example.com/ch${index + 1}.mp3',
        chapterNumber: index + 1,
        duration: 1800,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChapterSelectorSheet(
              chapters: manyChapters,
              currentChapterIndex: 0,
              onChapterSelected: onChapterSelected,
              bookTitle: testBookTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find ListView for scrolling
      expect(find.byType(ListView), findsOneWidget);

      // Should display chapter count
      expect(find.text('20 chapters'), findsOneWidget);

      // Should be able to scroll to see more chapters
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      print('✅ ChapterSelectorSheet handles many chapters with scrolling correctly');
    });
  });
}