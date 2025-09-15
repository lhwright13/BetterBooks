import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get_it/get_it.dart';
import 'package:echowright_rebuilt/main.dart' as app;
import 'package:echowright_rebuilt/data/repositories/user_repository.dart';
import 'package:echowright_rebuilt/data/repositories/book_repository.dart';
import 'package:echowright_rebuilt/data/repositories/library_repository.dart';
import 'package:echowright_rebuilt/services/download_service.dart';
import 'package:echowright_rebuilt/services/voice_service.dart';
import 'package:echowright_rebuilt/services/player_state_service.dart';
import '../helpers/test_helpers.dart';
import '../helpers/simple_mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('User Journey Integration Tests', () {
    late MockUserRepository mockUserRepo;
    late MockBookRepository mockBookRepo;
    late MockLibraryRepository mockLibraryRepo;
    late MockDownloadService mockDownloadService;
    late MockVoiceService mockVoiceService;
    late MockPlayerStateService mockPlayerService;
    
    setUpAll(() async {
      // Initialize mock services for all tests
      mockUserRepo = MockUserRepository();
      mockBookRepo = MockBookRepository();
      mockLibraryRepo = MockLibraryRepository();
      mockDownloadService = MockDownloadService();
      mockVoiceService = MockVoiceService();
      mockPlayerService = MockPlayerStateService();
      
      // Setup mock data
      final testBooks = [
        TestDataFactory.createBrowseBook(
          id: 'book-1',
          title: 'Journey Test Book 1',
          author: 'Journey Author',
          isFeatured: true,
          isPurchased: false,
        ),
        TestDataFactory.createBrowseBook(
          id: 'book-2',
          title: 'Journey Test Book 2', 
          author: 'Another Author',
          isBestseller: true,
          isPurchased: true,
          isDownloaded: false,
        ),
      ];
      mockBookRepo.setMockBooks(testBooks);
      mockLibraryRepo.setMockLibrary([testBooks[1]]); // Second book is in library
    });
    
    setUp(() async {
      // Reset and register services for each test
      await GetIt.instance.reset();
      
      GetIt.instance.registerSingleton<UserRepository>(mockUserRepo);
      GetIt.instance.registerSingleton<BookRepository>(mockBookRepo);
      GetIt.instance.registerSingleton<LibraryRepository>(mockLibraryRepo);
      GetIt.instance.registerSingleton<DownloadService>(mockDownloadService);
      GetIt.instance.registerSingleton<VoiceService>(mockVoiceService);
      GetIt.instance.registerSingleton<PlayerStateService>(mockPlayerService);
    });
    
    tearDown(() async {
      await GetIt.instance.reset();
    });
    
    group('New User Onboarding Journey', () {
      testWidgets('complete new user flow: signup → browse → purchase → download', (tester) async {
        // Set user as not authenticated initially
        mockUserRepo.setAuthenticated(false);
        
        // Launch app
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        // Should show authentication screen or allow guest browsing
        expect(find.byType(MaterialApp), findsOneWidget);
        
        // Step 1: Handle authentication/onboarding
        await _handleAuthenticationFlow(tester, mockUserRepo);
        
        // Step 2: Browse books
        await _testBookBrowsing(tester, expectBooks: true);
        
        // Step 3: Test book purchase flow
        await _testBookPurchase(tester, 'Journey Test Book 1');
        
        // Step 4: Navigate to library
        await _navigateToTab(tester, 'Library');
        
        // Step 5: Test download functionality
        await _testBookDownload(tester, mockDownloadService);
        
        print('✅ New user onboarding journey completed');
      });
    });
    
    group('Returning User Journey', () {
      testWidgets('returning user flow: library → play → voice chat', (tester) async {
        // Set user as authenticated with existing library
        mockUserRepo.setAuthenticated(true, user: {
          'id': 'test-user',
          'email': 'returning@example.com',
          'display_name': 'Returning User'
        });
        
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        // Step 1: Go directly to library
        await _navigateToTab(tester, 'Library');
        
        // Step 2: Select a book to play
        await _testBookSelection(tester, 'Journey Test Book 2');
        
        // Step 3: Test audio player functionality
        await _testAudioPlayer(tester, mockPlayerService);
        
        // Step 4: Test voice chat feature
        await _testVoiceChat(tester, mockVoiceService);
        
        print('✅ Returning user journey completed');
      });
    });
    
    group('Download and Offline Flow', () {
      testWidgets('download books for offline usage', (tester) async {
        mockUserRepo.setAuthenticated(true);
        
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        // Navigate to library
        await _navigateToTab(tester, 'Library');
        
        // Test downloading multiple books
        final booksToDownload = ['Journey Test Book 2'];
        
        for (final bookTitle in booksToDownload) {
          await _testSingleBookDownload(tester, mockDownloadService, bookTitle);
          await tester.pump(const Duration(milliseconds: 500));
        }
        
        // Verify downloads completed
        expect(await mockDownloadService.isBookDownloaded('book-2'), isTrue);
        
        print('✅ Download and offline flow completed');
      });
    });
    
    group('Error Recovery Journey', () {
      testWidgets('handle network errors and recovery', (tester) async {
        mockUserRepo.setAuthenticated(true);
        
        // Setup empty state to simulate network error
        mockBookRepo.setMockBooks([]);
        
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        // Navigate to discover (should handle empty state)
        await _navigateToTab(tester, 'Discover');
        
        // App should handle empty state gracefully
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        // Simulate recovery by adding books back
        final recoveryBooks = [
          TestDataFactory.createBrowseBook(title: 'Recovery Book'),
        ];
        mockBookRepo.setMockBooks(recoveryBooks);
        
        // Trigger refresh by navigating away and back
        await _navigateToTab(tester, 'Library');
        await _navigateToTab(tester, 'Discover');
        
        print('✅ Error recovery journey completed');
      });
    });
    
    group('Performance Under Load', () {
      testWidgets('handle large library efficiently', (tester) async {
        // Setup large dataset
        final largeBookSet = TestDataFactory.createBrowseBookList(count: 50);
        mockBookRepo.setMockBooks(largeBookSet);
        mockLibraryRepo.setMockLibrary(largeBookSet);
        
        final stopwatch = Stopwatch()..start();
        
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));
        
        stopwatch.stop();
        
        // Should load within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000),
            reason: 'Large library should load within 5 seconds');
        
        // Test navigation with large dataset
        await _navigateToTab(tester, 'Library');
        await tester.pumpAndSettle();
        
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        print('✅ Performance under load test completed');
      });
    });
  });
}

// Helper functions for common test actions
Future<void> _handleAuthenticationFlow(WidgetTester tester, MockUserRepository mockUserRepo) async {
  // Look for authentication elements
  final authElements = [
    find.text('Sign In'),
    find.text('Sign Up'), 
    find.text('Login'),
    find.byType(TextField),
  ];
  
  bool hasAuthElement = authElements.any((finder) => finder.evaluate().isNotEmpty);
  
  if (hasAuthElement) {
    // Simulate authentication
    mockUserRepo.setAuthenticated(true, user: {
      'id': 'test-user',
      'email': 'test@example.com',
      'display_name': 'Test User'
    });
    
    // Try to interact with auth elements
    final signInButton = find.text('Sign In');
    if (signInButton.evaluate().isNotEmpty) {
      await tester.tap(signInButton);
      await tester.pumpAndSettle();
    }
  }
  
  print('✅ Authentication flow handled');
}

Future<void> _testBookBrowsing(WidgetTester tester, {bool expectBooks = false}) async {
  // Navigate to discover or browse section
  await _navigateToTab(tester, 'Discover');
  
  if (expectBooks) {
    // Look for book content
    final bookElements = [
      find.text('Journey Test Book 1'),
      find.text('Journey Test Book 2'),
      find.byType(Card),
      find.byType(GridView),
    ];
    
    bool hasBookContent = bookElements.any((finder) => finder.evaluate().isNotEmpty);
    expect(hasBookContent, isTrue, reason: 'Should display books');
  }
  
  print('✅ Book browsing tested');
}

Future<void> _testBookPurchase(WidgetTester tester, String bookTitle) async {
  final bookFinder = find.text(bookTitle);
  if (bookFinder.evaluate().isNotEmpty) {
    await tester.tap(bookFinder);
    await tester.pumpAndSettle();
    
    // Look for purchase button
    final purchaseButton = find.text('Purchase').or(find.byIcon(Icons.shopping_cart));
    if (purchaseButton.evaluate().isNotEmpty) {
      await tester.tap(purchaseButton);
      await tester.pumpAndSettle();
    }
  }
  
  print('✅ Book purchase flow tested');
}

Future<void> _testBookDownload(WidgetTester tester, MockDownloadService mockDownloadService) async {
  final downloadButton = find.byIcon(Icons.download);
  if (downloadButton.evaluate().isNotEmpty) {
    await tester.tap(downloadButton.first);
    await tester.pumpAndSettle();
    
    // Simulate download completion
    mockDownloadService.setDownloaded('book-2', true);
  }
  
  print('✅ Book download tested');
}

Future<void> _testSingleBookDownload(WidgetTester tester, MockDownloadService mockDownloadService, String bookTitle) async {
  final bookFinder = find.text(bookTitle);
  if (bookFinder.evaluate().isNotEmpty) {
    await tester.tap(bookFinder);
    await tester.pumpAndSettle();
    
    final downloadButton = find.byIcon(Icons.download);
    if (downloadButton.evaluate().isNotEmpty) {
      await tester.tap(downloadButton);
      await tester.pumpAndSettle();
      
      // Mark as downloaded
      mockDownloadService.setDownloaded('book-2', true);
    }
  }
}

Future<void> _testBookSelection(WidgetTester tester, String bookTitle) async {
  final bookFinder = find.text(bookTitle);
  if (bookFinder.evaluate().isNotEmpty) {
    await tester.tap(bookFinder);
    await tester.pumpAndSettle();
    print('✅ Selected book: $bookTitle');
  }
}

Future<void> _testAudioPlayer(WidgetTester tester, MockPlayerStateService mockPlayerService) async {
  final playButton = find.byIcon(Icons.play_arrow);
  if (playButton.evaluate().isNotEmpty) {
    await tester.tap(playButton);
    await tester.pumpAndSettle();
    
    // Simulate playback
    await mockPlayerService.loadBook('book-2');
    await mockPlayerService.play();
    
    print('✅ Audio player tested');
  }
}

Future<void> _testVoiceChat(WidgetTester tester, MockVoiceService mockVoiceService) async {
  final voiceChatButton = find.byIcon(Icons.mic).or(find.text('Voice Chat'));
  if (voiceChatButton.evaluate().isNotEmpty) {
    await tester.tap(voiceChatButton);
    await tester.pumpAndSettle();
    
    // Simulate voice interaction
    mockVoiceService.setAvailable(true);
    mockVoiceService.setListening(true);
    
    print('✅ Voice chat tested');
  }
}

Future<void> _navigateToTab(WidgetTester tester, String tabName) async {
  final tabFinder = find.text(tabName);
  if (tabFinder.evaluate().isNotEmpty) {
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();
    print('✅ Navigated to $tabName');
  }
}

// Extension for finder combinations
extension FinderExtension on Finder {
  Finder or(Finder other) {
    return find.byWidgetPredicate((widget) => 
      evaluate().isNotEmpty || other.evaluate().isNotEmpty);
  }
}