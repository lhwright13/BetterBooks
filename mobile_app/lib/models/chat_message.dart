/**
 * chat_message.dart - Chat message data model for Muuchi conversations
 * 
 * This file defines the ChatMessage model used throughout the Muuchi app for
 * representing individual messages in conversations between users and AI personas.
 * Supports both text and voice messages with proper serialization.
 * 
 * Key responsibilities:
 * - Model individual chat messages with metadata
 * - Handle JSON serialization for persistent storage
 * - Support both text and voice message types
 * - Track message timing and authorship
 * 
 * Backend integration:
 * - Messages are sent to LLM Gateway for AI persona responses
 * - Voice messages are processed through TTS Service
 * - Chat history can be stored and retrieved via Context Service
 * - Message format compatible with API Gateway endpoints
 */

/// Represents a single message in a conversation with an AI persona
/// Can be either a text message or voice message from user or AI
class ChatMessage {
  final String id;              // Unique message identifier
  final String content;         // Message text content
  final bool isUser;           // True if message is from user, false if from AI
  final DateTime timestamp;     // When the message was created
  final bool isVoiceMessage;   // True if this was a voice input/output message

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isVoiceMessage = false,
  });

  /// Converts chat message to JSON for storage or API transmission
  /// Used for persisting chat history and sending to backend services
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isVoiceMessage': isVoiceMessage,
    };
  }

  /// Creates ChatMessage from JSON data
  /// Used when loading persisted chat history or receiving API responses
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      isVoiceMessage: json['isVoiceMessage'] ?? false,
    );
  }
}