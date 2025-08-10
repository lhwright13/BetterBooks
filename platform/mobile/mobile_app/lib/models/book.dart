/**
 * book.dart - Data models for audiobook content in EchoWright
 * 
 * This file defines the core data structures for representing audiobooks and chapters
 * in the EchoWright system. Books can be either single-file audiobooks or multi-chapter
 * collections, and the models handle both formats seamlessly.
 * 
 * Key responsibilities:
 * - Define Book model for audiobook metadata and structure
 * - Define Chapter model for individual chapter content
 * - Handle JSON serialization from backend API responses
 * - Support both single-file and multi-chapter audiobook formats
 * 
 * Backend integration:
 * - Models match API response format from API Gateway
 * - Audio URLs point to streaming endpoints for playback
 * - Cover URLs reference book cover image resources
 * - Duration tracking for progress indicators and seeking
 */

/// Represents an audiobook in the EchoWright library
/// Can be either a single audio file or a collection of chapters
class Book {
  final String id;              // Unique identifier for the book
  final String title;           // Display title of the audiobook
  final String? author;         // Author name (optional)
  final String? coverUrl;       // URL to book cover image
  final List<Chapter>? chapters;// Chapters for multi-part books
  final String? audioUrl;       // Direct audio URL for single-file books
  final Duration? duration;     // Total playback duration

  Book({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.chapters,
    this.audioUrl,
    this.duration,
  });

  /// Creates a Book instance from JSON API response
  /// Handles both single-file and multi-chapter book formats
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? json['filename'] ?? '',
      title: json['title'] ?? json['filename'] ?? 'Unknown Title',
      author: json['author'],
      coverUrl: json['cover_url'],
      audioUrl: json['audio_url'],
      duration: json['duration'] != null ? Duration(seconds: json['duration']) : null,
      chapters: json['chapters'] != null
          ? (json['chapters'] as List).map((c) => Chapter.fromJson(c)).toList()
          : null,
    );
  }

  /// Check if this book has multiple chapters
  bool get hasChapters => chapters != null && chapters!.isNotEmpty;
}

/// Represents a single chapter within a multi-chapter audiobook
/// Contains metadata and streaming URL for individual chapter playback
class Chapter {
  final String id;              // Unique chapter identifier
  final String title;           // Chapter title for display
  final String audioUrl;        // Streaming URL for this chapter's audio
  final Duration? duration;     // Chapter playback duration
  final int chapterNumber;      // Sequential chapter number

  Chapter({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.duration,
    required this.chapterNumber,
  });

  /// Creates a Chapter instance from JSON API response
  /// Handles missing data gracefully with fallback values
  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Chapter ${json['chapter_number'] ?? ''}',
      audioUrl: json['audio_url'] ?? '',
      chapterNumber: json['chapter_number'] ?? 0,
      duration: json['duration'] != null ? Duration(seconds: json['duration']) : null,
    );
  }
}

/// Represents an AI-detected chapter with enhanced metadata
/// Contains chapter boundaries, summaries, and confidence scores from AI analysis
class DetectedChapter {
  final String id;                    // Unique chapter identifier
  final int chapterNumber;            // Sequential chapter number
  final String title;                 // AI-generated or provided chapter title
  final double startTime;             // Start time in seconds from beginning of audio
  final double endTime;               // End time in seconds from beginning of audio
  final double duration;              // Chapter duration in seconds
  final double confidence;            // AI detection confidence score (0.0-1.0)
  final String? summary;              // AI-generated chapter summary
  final List<String> keyTopics;       // AI-extracted key topics and themes
  final int wordCount;               // Number of words in this chapter
  final int speakerChanges;          // Number of speaker changes detected

  DetectedChapter({
    required this.id,
    required this.chapterNumber,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.confidence,
    this.summary,
    this.keyTopics = const [],
    this.wordCount = 0,
    this.speakerChanges = 0,
  });

  /// Creates a DetectedChapter from AI chapter detection API response
  factory DetectedChapter.fromJson(Map<String, dynamic> json) {
    return DetectedChapter(
      id: json['id'] ?? 'chapter_${json['chapter_number'] ?? 0}',
      chapterNumber: json['chapter_number'] ?? 0,
      title: json['title'] ?? 'Chapter ${json['chapter_number'] ?? 0}',
      startTime: (json['start_time'] ?? 0).toDouble(),
      endTime: (json['end_time'] ?? 0).toDouble(),
      duration: (json['duration'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
      summary: json['summary'],
      keyTopics: (json['key_topics'] as List<dynamic>?)
          ?.map((topic) => topic.toString())
          .toList() ?? [],
      wordCount: json['word_count'] ?? 0,
      speakerChanges: json['speaker_changes'] ?? 0,
    );
  }

  /// Format duration as MM:SS or HH:MM:SS
  String get formattedDuration {
    final hours = (duration ~/ 3600);
    final minutes = ((duration % 3600) ~/ 60);
    final seconds = (duration % 60).round();
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Convert confidence to percentage
  int get confidencePercentage => (confidence * 100).round();
}

/// Represents a chapter summary with different styles and metadata
class ChapterSummary {
  final String chapterId;              // Reference to chapter
  final int chapterNumber;             // Chapter number for display
  final String chapterTitle;           // Chapter title
  final String summaryText;            // Main summary content
  final String style;                  // Summary style (brief, detailed, themes, etc.)
  final List<String> keyPoints;       // Key points extracted from chapter
  final List<String> themes;          // Themes identified in chapter
  final List<String> charactersMenutioned; // Characters mentioned
  final int wordCount;                 // Summary word count
  final double confidenceScore;        // AI confidence in summary quality

  ChapterSummary({
    required this.chapterId,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.summaryText,
    required this.style,
    this.keyPoints = const [],
    this.themes = const [],
    this.charactersMenutioned = const [],
    this.wordCount = 0,
    required this.confidenceScore,
  });

  /// Creates a ChapterSummary from AI summary generation API response
  factory ChapterSummary.fromJson(Map<String, dynamic> json) {
    return ChapterSummary(
      chapterId: json['chapter_id'] ?? '',
      chapterNumber: json['chapter_number'] ?? 0,
      chapterTitle: json['chapter_title'] ?? '',
      summaryText: json['summary_text'] ?? '',
      style: json['style'] ?? 'detailed',
      keyPoints: (json['key_points'] as List<dynamic>?)
          ?.map((point) => point.toString())
          .toList() ?? [],
      themes: (json['themes'] as List<dynamic>?)
          ?.map((theme) => theme.toString())
          .toList() ?? [],
      charactersMenutioned: (json['characters_mentioned'] as List<dynamic>?)
          ?.map((character) => character.toString())
          .toList() ?? [],
      wordCount: json['word_count'] ?? 0,
      confidenceScore: (json['confidence_score'] ?? 0).toDouble(),
    );
  }
}

/// Represents a generated question for chapter engagement
class ChapterQuestion {
  final String questionId;             // Unique question identifier
  final String questionText;           // The actual question
  final String questionType;           // Type: comprehension, analysis, discussion, etc.
  final String difficulty;             // Difficulty: beginner, intermediate, advanced
  final String suggestedAnswer;        // AI-suggested answer or guidance
  final List<String> answerGuidelines; // Guidelines for answering
  final List<String> followUpQuestions; // Related follow-up questions
  final List<String> relatedThemes;    // Themes this question relates to
  final double confidenceScore;        // AI confidence in question quality

  ChapterQuestion({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.difficulty,
    required this.suggestedAnswer,
    this.answerGuidelines = const [],
    this.followUpQuestions = const [],
    this.relatedThemes = const [],
    required this.confidenceScore,
  });

  /// Creates a ChapterQuestion from AI question generation API response
  factory ChapterQuestion.fromJson(Map<String, dynamic> json) {
    return ChapterQuestion(
      questionId: json['question_id'] ?? '',
      questionText: json['question_text'] ?? '',
      questionType: json['question_type'] ?? 'comprehension',
      difficulty: json['difficulty'] ?? 'intermediate',
      suggestedAnswer: json['suggested_answer'] ?? '',
      answerGuidelines: (json['answer_guidelines'] as List<dynamic>?)
          ?.map((guideline) => guideline.toString())
          .toList() ?? [],
      followUpQuestions: (json['follow_up_questions'] as List<dynamic>?)
          ?.map((question) => question.toString())
          .toList() ?? [],
      relatedThemes: (json['related_themes'] as List<dynamic>?)
          ?.map((theme) => theme.toString())
          .toList() ?? [],
      confidenceScore: (json['confidence_score'] ?? 0).toDouble(),
    );
  }
}