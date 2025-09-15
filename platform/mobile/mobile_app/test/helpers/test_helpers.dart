import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:faker/faker.dart';
import 'package:echowright_rebuilt/data/models/book_models.dart';
import 'package:echowright_rebuilt/data/models/auth_models.dart';
import 'package:echowright_rebuilt/data/models/chat_models.dart';

/// Test helpers and utilities for creating test data and mocking dependencies
class TestHelpers {
  static final Faker _faker = Faker();
  
  /// Reset GetIt service locator for testing
  static void resetGetIt() {
    GetIt.instance.reset();
  }
  
  /// Create a test app wrapper for widget testing
  static Widget createTestApp({
    required Widget child,
    ThemeData? theme,
    Locale? locale,
  }) {
    return MaterialApp(
      home: Scaffold(body: child),
      theme: theme ?? ThemeData(),
      locale: locale,
    );
  }
  
  /// Create a test app wrapper with navigation
  static Widget createTestAppWithRouter({
    required Widget child,
    String initialRoute = '/',
  }) {
    return MaterialApp(
      initialRoute: initialRoute,
      routes: {
        '/': (context) => Scaffold(body: child),
      },
    );
  }
  
  /// Pump and settle widget with common timeout
  static Future<void> pumpAndSettleWithTimeout(
    WidgetTester tester, [
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    await tester.pumpAndSettle(timeout);
  }
  
  /// Wait for a condition to be true with timeout
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!condition() && stopwatch.elapsed < timeout) {
      await Future.delayed(interval);
    }
    if (!condition()) {
      throw TimeoutException('Condition not met within timeout', timeout);
    }
  }
}

/// Factory for creating test data models
class TestDataFactory {
  static final Faker _faker = Faker();
  
  /// Generate a random BrowseBook
  static BrowseBook createBrowseBook({
    String? id,
    String? title,
    String? author,
    double? priceUsd,
    int? creditPrice,
    String? coverImageUrl,
    String? audioUrl,
    bool? isFeatured,
    bool? isBestseller,
    bool? isNewRelease,
    bool? isPurchased,
    bool? isDownloaded,
    double? downloadProgress,
    List<Chapter>? chapters,
  }) {
    return BrowseBook(
      id: id ?? _faker.guid.guid(),
      title: title ?? _faker.conference.name(),
      author: author ?? _faker.person.name(),
      coverImageUrl: coverImageUrl ?? _faker.image.loremPicsum(),
      priceUsd: priceUsd ?? _faker.randomGenerator.decimal(min: 5, scale: 15),
      creditPrice: creditPrice ?? _faker.randomGenerator.integer(5, min: 1),
      isFeatured: isFeatured ?? _faker.randomGenerator.boolean(),
      isBestseller: isBestseller ?? _faker.randomGenerator.boolean(),
      isNewRelease: isNewRelease ?? _faker.randomGenerator.boolean(),
      isPurchased: isPurchased ?? _faker.randomGenerator.boolean(),
      isDownloaded: isDownloaded ?? _faker.randomGenerator.boolean(),
      downloadProgress: downloadProgress ?? _faker.randomGenerator.decimal(scale: 1),
      audioUrl: audioUrl,
      chapters: chapters ?? [],
    );
  }
  
  /// Generate a list of BrowseBooks
  static List<BrowseBook> createBrowseBookList({int count = 10}) {
    return List.generate(count, (index) => createBrowseBook());
  }
  
  /// Generate a User model
  static Map<String, dynamic> createUser({
    String? id,
    String? email,
    String? displayName,
    int? credits,
    DateTime? createdAt,
  }) {
    return {
      'id': id ?? _faker.guid.guid(),
      'email': email ?? _faker.internet.email(),
      'display_name': displayName ?? _faker.person.name(),
      'credits': credits ?? _faker.randomGenerator.integer(100, min: 0),
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }
  
  /// Generate an AuthResponse
  static AuthResponse createAuthResponse({
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
    int? expiresAt,
  }) {
    return AuthResponse(
      accessToken: accessToken ?? _faker.jwt.valid(),
      refreshToken: refreshToken ?? _faker.jwt.valid(),
      user: user ?? createUser(),
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  }
  
  /// Generate a ChatMessage
  static ChatMessage createChatMessage({
    String? id,
    String? content,
    ChatMessageType? type,
    String? personaId,
    String? personaName,
    DateTime? timestamp,
    double? confidenceLevel,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? _faker.guid.guid(),
      content: content ?? _faker.lorem.sentence(),
      type: type ?? (_faker.randomGenerator.boolean() ? ChatMessageType.text : ChatMessageType.voice),
      personaId: personaId,
      personaName: personaName ?? _faker.person.name(),
      timestamp: timestamp ?? DateTime.now(),
      confidenceLevel: confidenceLevel,
      metadata: metadata,
    );
  }
  
  /// Generate a list of ChatMessages
  static List<ChatMessage> createChatMessageList({int count = 5}) {
    return List.generate(count, (index) => createChatMessage());
  }
  
  /// Generate a Chapter
  static Chapter createChapter({
    String? id,
    String? title,
    String? audioUrl,
    int? chapterNumber,
    int? duration,
  }) {
    return Chapter(
      id: id ?? _faker.guid.guid(),
      title: title ?? 'Chapter ${chapterNumber ?? _faker.randomGenerator.integer(50, min: 1)}',
      audioUrl: audioUrl ?? '${_faker.internet.httpsUrl()}/chapter.mp3',
      chapterNumber: chapterNumber ?? _faker.randomGenerator.integer(50, min: 1),
      duration: duration ?? _faker.randomGenerator.integer(3600, min: 300), // 5 min to 1 hour
    );
  }
  
  /// Generate a BookPersona
  static BookPersona createBookPersona({
    String? id,
    String? personaId,
    String? personaName,
    String? personaDisplayName,
    String? personaDescription,
    bool? isDefault,
    String? customPrompt,
    int? sortOrder,
    Map<String, dynamic>? voiceConfig,
    Map<String, dynamic>? ttsConfig,
    Map<String, dynamic>? generationConfig,
  }) {
    return BookPersona(
      id: id ?? _faker.guid.guid(),
      personaId: personaId ?? _faker.guid.guid(),
      personaName: personaName ?? _faker.person.firstName(),
      personaDisplayName: personaDisplayName ?? _faker.person.name(),
      personaDescription: personaDescription ?? _faker.lorem.sentence(),
      isDefault: isDefault ?? false,
      customPrompt: customPrompt,
      sortOrder: sortOrder ?? 0,
      voiceConfig: voiceConfig,
      ttsConfig: ttsConfig,
      generationConfig: generationConfig,
    );
  }
  
  /// Generate purchase data
  static Map<String, dynamic> createPurchaseData({
    String? bookId,
    String? userId,
    double? amount,
    int? creditsUsed,
    DateTime? purchasedAt,
  }) {
    return {
      'book_id': bookId ?? _faker.guid.guid(),
      'user_id': userId ?? _faker.guid.guid(),
      'amount_usd': amount ?? _faker.randomGenerator.decimal(min: 5, scale: 15),
      'credits_used': creditsUsed ?? _faker.randomGenerator.integer(5, min: 1),
      'purchased_at': (purchasedAt ?? DateTime.now()).toIso8601String(),
    };
  }
  
  /// Generate library item data
  static Map<String, dynamic> createLibraryItem({
    String? bookId,
    String? userId,
    int? currentChapter,
    Duration? currentPosition,
    DateTime? lastAccessed,
    bool? isDownloaded,
    double? progress,
  }) {
    return {
      'book_id': bookId ?? _faker.guid.guid(),
      'user_id': userId ?? _faker.guid.guid(),
      'current_chapter': currentChapter ?? _faker.randomGenerator.integer(20, min: 0),
      'current_position': (currentPosition ?? Duration(minutes: _faker.randomGenerator.integer(60))).inMilliseconds,
      'last_accessed': (lastAccessed ?? DateTime.now()).toIso8601String(),
      'is_downloaded': isDownloaded ?? _faker.randomGenerator.boolean(),
      'progress': progress ?? _faker.randomGenerator.decimal(min: 0, scale: 1),
    };
  }
}

/// Custom matchers for testing
class TestMatchers {
  /// Matcher for BrowseBook equality
  static Matcher equalsBook(BrowseBook expected) {
    return _BookMatcher(expected);
  }
  
  /// Matcher for AuthResponse equality
  static Matcher equalsAuthResponse(AuthResponse expected) {
    return _AuthResponseMatcher(expected);
  }
  
  /// Matcher for approximate Duration
  static Matcher approximatelyDuration(Duration expected, {Duration tolerance = const Duration(seconds: 1)}) {
    return _DurationMatcher(expected, tolerance);
  }
}

class _BookMatcher extends Matcher {
  final BrowseBook expected;
  
  const _BookMatcher(this.expected);
  
  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! BrowseBook) return false;
    return item.id == expected.id &&
           item.title == expected.title &&
           item.author == expected.author;
  }
  
  @override
  Description describe(Description description) =>
      description.add('BrowseBook with id: ${expected.id}, title: ${expected.title}');
}

class _AuthResponseMatcher extends Matcher {
  final AuthResponse expected;
  
  const _AuthResponseMatcher(this.expected);
  
  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! AuthResponse) return false;
    return item.accessToken == expected.accessToken &&
           item.user['id'] == expected.user['id'];
  }
  
  @override
  Description describe(Description description) =>
      description.add('AuthResponse with token: ${expected.accessToken}');
}

class _DurationMatcher extends Matcher {
  final Duration expected;
  final Duration tolerance;
  
  const _DurationMatcher(this.expected, this.tolerance);
  
  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Duration) return false;
    return (item - expected).abs() <= tolerance;
  }
  
  @override
  Description describe(Description description) =>
      description.add('Duration approximately ${expected.inMilliseconds}ms');
}