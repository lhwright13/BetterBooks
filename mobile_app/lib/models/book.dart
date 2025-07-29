class Book {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final List<Chapter>? chapters;
  final String? audioUrl;
  final Duration? duration;

  Book({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.chapters,
    this.audioUrl,
    this.duration,
  });

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

  bool get hasChapters => chapters != null && chapters!.isNotEmpty;
}

class Chapter {
  final String id;
  final String title;
  final String audioUrl;
  final Duration? duration;
  final int chapterNumber;

  Chapter({
    required this.id,
    required this.title,
    required this.audioUrl,
    this.duration,
    required this.chapterNumber,
  });

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