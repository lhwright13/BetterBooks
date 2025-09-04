/**
 * chapter.dart - Chapter model for multi-chapter audiobooks
 * 
 * Represents individual chapters within an audiobook with audio URLs,
 * progress tracking, and metadata.
 */

import 'package:flutter/foundation.dart';

/// Represents a chapter within an audiobook
@immutable
class Chapter {
  final String id;
  final String title;
  final String audioUrl;
  final Duration? duration;
  final int chapterNumber;
  final String? description;
  final double progress; // 0.0 to 1.0
  final bool isDownloaded;
  final String? localPath;

  const Chapter({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.duration,
    required this.chapterNumber,
    this.description,
    this.progress = 0.0,
    this.isDownloaded = false,
    this.localPath,
  });

  Chapter copyWith({
    String? id,
    String? title,
    String? audioUrl,
    Duration? duration,
    int? chapterNumber,
    String? description,
    double? progress,
    bool? isDownloaded,
    String? localPath,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      description: description ?? this.description,
      progress: progress ?? this.progress,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
    );
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      title: json['title'] as String,
      audioUrl: json['audio_url'] as String,
      duration: json['duration_seconds'] != null 
          ? Duration(seconds: json['duration_seconds'] as int)
          : null,
      chapterNumber: json['chapter_number'] as int,
      description: json['description'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      isDownloaded: json['is_downloaded'] as bool? ?? false,
      localPath: json['local_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'audio_url': audioUrl,
      'duration_seconds': duration?.inSeconds,
      'chapter_number': chapterNumber,
      'description': description,
      'progress': progress,
      'is_downloaded': isDownloaded,
      'local_path': localPath,
    };
  }

  String get formattedDuration {
    if (duration == null) return 'Unknown length';
    
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedProgress {
    return '${(progress * 100).toInt()}% complete';
  }

  bool get isCompleted => progress >= 1.0;
  bool get isStarted => progress > 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Chapter &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Chapter{id: $id, title: $title, chapterNumber: $chapterNumber, progress: $progress}';
  }
}