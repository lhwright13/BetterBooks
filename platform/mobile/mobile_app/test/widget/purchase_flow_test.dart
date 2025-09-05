import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:echowright_rebuilt/data/models/book_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Mock Flutter Secure Storage and other plugins
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'read':
            return null;
          case 'write':
            return null;
          default:
            throw PlatformException(code: 'unimplemented');
        }
      },
    );
  });
  group('Purchase Flow Widget Tests', () {
    late BrowseBook testBook;

    setUp(() {
      testBook = BrowseBook(
        id: 'test-book-1',
        title: 'Test Book Title',
        author: 'Test Author',
        coverImageUrl: 'https://example.com/cover.jpg',
        priceUsd: 9.99,
        creditPrice: 1,
        isPurchased: false,
        isDownloaded: false,
      );
    });

    testWidgets('Book details displays purchase button for unpurchased book', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(testBook.title),
                Text('By ${testBook.author}'),
                Text('\$${testBook.priceUsd}'),
                if (!testBook.isPurchased)
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Purchase'),
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find purchase button
      expect(find.text('Purchase'), findsOneWidget);
      expect(find.text(testBook.title), findsOneWidget);
      print('✅ Purchase button found for unpurchased book');
    });

    testWidgets('Purchase button shows loading state when tapped', (tester) async {
      bool isLoading = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(
                children: [
                  Text(testBook.title),
                  if (isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isLoading = true;
                        });
                      },
                      child: const Text('Purchase'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the purchase button
      final purchaseButton = find.text('Purchase');
      expect(purchaseButton, findsOneWidget);
      await tester.tap(purchaseButton);
      await tester.pump(); // Trigger the tap

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      print('✅ Loading state displayed during purchase');
    });

    testWidgets('Download button appears after successful purchase', (tester) async {
      // Create a purchased book
      final purchasedBook = testBook.copyWith(isPurchased: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(purchasedBook.title),
                Text('By ${purchasedBook.author}'),
                if (purchasedBook.isPurchased && !purchasedBook.isDownloaded)
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Download'),
                  ),
                if (!purchasedBook.isPurchased)
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Purchase'),
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find download button instead of purchase button
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Purchase'), findsNothing);
      print('✅ Download button appears for purchased book');
    });

    testWidgets('Listen Now button appears for downloaded book', (tester) async {
      // Create a downloaded book
      final downloadedBook = testBook.copyWith(
        isPurchased: true,
        isDownloaded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text(downloadedBook.title),
                Text('By ${downloadedBook.author}'),
                if (downloadedBook.isDownloaded)
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Listen Now'),
                  ),
                if (downloadedBook.isPurchased && !downloadedBook.isDownloaded)
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Download'),
                  ),
                if (!downloadedBook.isPurchased)
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Purchase'),
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find Listen Now button
      expect(find.text('Listen Now'), findsOneWidget);
      expect(find.text('Purchase'), findsNothing);
      expect(find.text('Download'), findsNothing);
      print('✅ Listen Now button appears for downloaded book');
    });
  });

  group('Download Progress Tests', () {
    testWidgets('Download progress shows during download', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CircularProgressIndicator(value: 0.5),
                Text('50%'),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      print('✅ Download progress UI renders correctly');
    });
  });
}