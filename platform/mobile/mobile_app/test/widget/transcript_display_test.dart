import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echowright_rebuilt/presentation/widgets/transcript_display.dart';
import 'package:echowright_rebuilt/data/models/chat_models.dart';

void main() {
  group('TranscriptDisplay Widget Tests', () {
    testWidgets('should render empty state when no messages', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TranscriptDisplay(
              messages: [],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render nothing when no messages
      expect(find.byType(TranscriptDisplay), findsOneWidget);
      expect(find.text('Conversation'), findsNothing);
    });

    testWidgets('should render messages with persona labels', (WidgetTester tester) async {
      final messages = [
        ChatMessage(
          id: '1',
          content: 'Hello, Gatsby!',
          type: ChatMessageType.voice,
          timestamp: DateTime(2024, 1, 1, 12, 0),
        ),
        ChatMessage(
          id: '2',
          content: 'Hello, old sport!',
          type: ChatMessageType.text,
          personaId: 'gatsby',
          personaName: 'Jay Gatsby',
          timestamp: DateTime(2024, 1, 1, 12, 1),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranscriptDisplay(
              messages: messages,
              enableCollapse: false, // Disable collapse for easier testing
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find both messages
      expect(find.text('Hello, Gatsby!'), findsOneWidget);
      expect(find.text('Hello, old sport!'), findsOneWidget);

      // Should find persona labels
      expect(find.text('You'), findsOneWidget); // User message
      expect(find.text('Jay Gatsby'), findsOneWidget); // Persona message
    });

    testWidgets('should show confidence badge when enabled', (WidgetTester tester) async {
      final messages = [
        ChatMessage(
          id: '1',
          content: 'Test message',
          type: ChatMessageType.voice,
          confidenceLevel: 0.85,
          timestamp: DateTime(2024, 1, 1, 12, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranscriptDisplay(
              messages: messages,
              showConfidence: true,
              enableCollapse: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show confidence percentage
      expect(find.text('85%'), findsOneWidget);
    });

    testWidgets('should handle collapse functionality', (WidgetTester tester) async {
      final messages = [
        ChatMessage(
          id: '1',
          content: 'Test message',
          type: ChatMessageType.text,
          timestamp: DateTime(2024, 1, 1, 12, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranscriptDisplay(
              messages: messages,
              enableCollapse: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find conversation header
      expect(find.text('Conversation'), findsOneWidget);
      expect(find.text('Test message'), findsOneWidget);

      // Should find collapse button
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();

      // Should be collapsed now
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('Test message'), findsNothing);

      // Tap to expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Should be expanded now
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('should show error message styling', (WidgetTester tester) async {
      final messages = [
        ChatMessage(
          id: '1',
          content: 'Error occurred',
          type: ChatMessageType.error,
          timestamp: DateTime(2024, 1, 1, 12, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranscriptDisplay(
              messages: messages,
              enableCollapse: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Error occurred'), findsOneWidget);
      
      // Should show error indicator
      expect(find.text('Message failed to send'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsAtLeastNWidgets(1));
    });

    testWidgets('should show system message styling', (WidgetTester tester) async {
      final messages = [
        ChatMessage(
          id: '1',
          content: 'System notification',
          type: ChatMessageType.system,
          timestamp: DateTime(2024, 1, 1, 12, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TranscriptDisplay(
              messages: messages,
              enableCollapse: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show system message
      expect(find.text('System notification'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
    });
  });

  group('MessageBubble Widget Tests', () {
    testWidgets('should render user message bubble', (WidgetTester tester) async {
      final message = ChatMessage(
        id: '1',
        content: 'User message',
        type: ChatMessageType.text,
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              isUser: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('User message'), findsOneWidget);
    });

    testWidgets('should render AI message bubble', (WidgetTester tester) async {
      final message = ChatMessage(
        id: '1',
        content: 'AI response',
        type: ChatMessageType.text,
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              isUser: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI response'), findsOneWidget);
    });

    testWidgets('should show timestamp when enabled', (WidgetTester tester) async {
      final message = ChatMessage(
        id: '1',
        content: 'Test message',
        type: ChatMessageType.text,
        timestamp: DateTime(2024, 1, 1, 12, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              isUser: true,
              showTimestamp: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test message'), findsOneWidget);
      expect(find.text('12:30'), findsOneWidget);
    });
  });
}