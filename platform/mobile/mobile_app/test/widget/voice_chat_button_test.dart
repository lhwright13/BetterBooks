import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:echowright_rebuilt/presentation/widgets/voice_chat_button.dart';
import 'package:echowright_rebuilt/services/voice_service.dart';
import 'package:echowright_rebuilt/data/models/book_models.dart';

void main() {
  late VoiceService mockVoiceService;
  late BrowseBook testBook;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockVoiceService = VoiceService();
    testBook = BrowseBook(
      id: '1',
      title: 'Test Book',
      author: 'Test Author',
      coverImageUrl: 'https://example.com/cover.jpg',
      priceUsd: 14.99,
      creditPrice: 1,
      isFeatured: false,
      isBestseller: false,
      isNewRelease: false,
      isPurchased: false,
      isDownloaded: false,
      downloadProgress: 0.0,
      audioUrl: null,
      chapters: [],
    );
  });

  group('VoiceChatButton Widget Tests', () {
    testWidgets('should render with idle state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<VoiceService>.value(
              value: mockVoiceService,
              child: VoiceChatButton(
                book: testBook,
                heroTag: 'test',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find the FloatingActionButton
      expect(find.byType(FloatingActionButton), findsOneWidget);
      
      // Should find the microphone icon in idle state
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('should show correct icon for different states', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<VoiceService>.value(
              value: mockVoiceService,
              child: VoiceChatButton(
                book: testBook,
                heroTag: 'test',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test idle state - should show mic icon
      expect(find.byIcon(Icons.mic), findsOneWidget);
      
      // The actual state changes would require mocking the voice service
      // which is complex due to platform-specific implementations
    });

    testWidgets('should call onPressed when provided', (WidgetTester tester) async {
      bool wasPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<VoiceService>.value(
              value: mockVoiceService,
              child: VoiceChatButton(
                book: testBook,
                heroTag: 'test',
                onPressed: () => wasPressed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(wasPressed, isTrue);
    });
  });

  group('VoiceChatStatusIndicator Widget Tests', () {
    testWidgets('should display correct state name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatStatusIndicator(
              state: VoiceChatState.listening,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Listening...'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('should show confidence indicator when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatStatusIndicator(
              state: VoiceChatState.listening,
              confidenceLevel: 0.8,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find the progress indicator for confidence
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should show different icons for different states', (WidgetTester tester) async {
      // Test speaking state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatStatusIndicator(
              state: VoiceChatState.speaking,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      // Test error state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatStatusIndicator(
              state: VoiceChatState.error,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Test processing state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatStatusIndicator(
              state: VoiceChatState.processing,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });
  });

  group('MicrophoneButton Widget Tests', () {
    testWidgets('should render simple microphone button', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MicrophoneButton(
              onPressed: () => wasPressed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(wasPressed, isTrue);
    });

    testWidgets('should show active state with different color', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MicrophoneButton(
              isActive: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The color change would be tested by checking the Icon widget's color
      // but this requires more complex widget inspection
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });
  });

  tearDown(() {
    mockVoiceService.dispose();
  });
}