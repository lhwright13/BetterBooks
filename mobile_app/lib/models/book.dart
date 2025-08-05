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