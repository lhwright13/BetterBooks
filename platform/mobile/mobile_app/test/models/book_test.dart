import 'package:flutter_test/flutter_test.dart';
import 'package:echowright/models/book.dart';

void main() {
  group('Book Model', () {
    group('fromJson constructor', () {
      test('creates Book from complete JSON', () {
        // Arrange
        final json = {
          'id': 'book-123',
          'title': 'Test Book Title',
          'author': 'Test Author',
          'cover_url': 'https://example.com/cover.jpg',
          'audio_url': 'https://example.com/audio.mp3',
          'duration': 3600,
          'chapters': [
            {
              'id': 'chapter-1',
              'title': 'Chapter 1',
              'audio_url': 'https://example.com/chapter1.mp3',
              'chapter_number': 1,
              'duration': 1800,
            }
          ]
        };

        // Act
        final book = Book.fromJson(json);

        // Assert
        expect(book.id, equals('book-123'));
        expect(book.title, equals('Test Book Title'));
        expect(book.author, equals('Test Author'));
        expect(book.coverUrl, equals('https://example.com/cover.jpg'));
        expect(book.audioUrl, equals('https://example.com/audio.mp3'));
        expect(book.duration, equals(Duration(seconds: 3600)));
        expect(book.hasChapters, isTrue);
        expect(book.chapters, hasLength(1));
        expect(book.chapters!.first.title, equals('Chapter 1'));
      });

      test('handles missing optional fields', () {
        // Arrange
        final json = {
          'id': 'book-minimal',
          'title': 'Minimal Book',
        };

        // Act
        final book = Book.fromJson(json);

        // Assert
        expect(book.id, equals('book-minimal'));
        expect(book.title, equals('Minimal Book'));
        expect(book.author, isNull);
        expect(book.coverUrl, isNull);
        expect(book.audioUrl, isNull);
        expect(book.duration, isNull);
        expect(book.hasChapters, isFalse);
        expect(book.chapters, isNull);
      });

      test('uses filename as fallback for id and title', () {
        // Arrange
        final json = {
          'filename': 'test-audio-file.mp3',
        };

        // Act
        final book = Book.fromJson(json);

        // Assert
        expect(book.id, equals('test-audio-file.mp3'));
        expect(book.title, equals('test-audio-file.mp3'));
      });

      test('uses Unknown Title as final fallback', () {
        // Arrange
        final json = <String, dynamic>{};

        // Act
        final book = Book.fromJson(json);

        // Assert
        expect(book.id, equals(''));
        expect(book.title, equals('Unknown Title'));
      });
    });

    group('hasChapters getter', () {
      test('returns true when chapters exist and not empty', () {
        // Arrange
        final book = Book(
          id: 'test',
          title: 'Test Book',
          chapters: [
            Chapter(
              id: 'ch1',
              title: 'Chapter 1',
              audioUrl: 'url',
              chapterNumber: 1,
            )
          ],
        );

        // Act & Assert
        expect(book.hasChapters, isTrue);
      });

      test('returns false when chapters is null', () {
        // Arrange
        final book = Book(
          id: 'test',
          title: 'Test Book',
          chapters: null,
        );

        // Act & Assert
        expect(book.hasChapters, isFalse);
      });

      test('returns false when chapters is empty', () {
        // Arrange
        final book = Book(
          id: 'test',
          title: 'Test Book',
          chapters: [],
        );

        // Act & Assert
        expect(book.hasChapters, isFalse);
      });
    });
  });

  group('Chapter Model', () {
    group('fromJson constructor', () {
      test('creates Chapter from complete JSON', () {
        // Arrange
        final json = {
          'id': 'chapter-123',
          'title': 'Chapter Title',
          'audio_url': 'https://example.com/chapter.mp3',
          'chapter_number': 5,
          'duration': 1800,
        };

        // Act
        final chapter = Chapter.fromJson(json);

        // Assert
        expect(chapter.id, equals('chapter-123'));
        expect(chapter.title, equals('Chapter Title'));
        expect(chapter.audioUrl, equals('https://example.com/chapter.mp3'));
        expect(chapter.chapterNumber, equals(5));
        expect(chapter.duration, equals(Duration(seconds: 1800)));
      });

      test('handles missing optional fields', () {
        // Arrange
        final json = {
          'chapter_number': 3,
        };

        // Act
        final chapter = Chapter.fromJson(json);

        // Assert
        expect(chapter.id, equals(''));
        expect(chapter.title, equals('Chapter 3'));
        expect(chapter.audioUrl, equals(''));
        expect(chapter.chapterNumber, equals(3));
        expect(chapter.duration, isNull);
      });

      test('generates title from chapter number when title missing', () {
        // Arrange
        final json = {
          'chapter_number': 7,
        };

        // Act
        final chapter = Chapter.fromJson(json);

        // Assert
        expect(chapter.title, equals('Chapter 7'));
      });

      test('defaults chapter number to 0 when missing', () {
        // Arrange
        final json = {
          'title': 'Prologue',
        };

        // Act
        final chapter = Chapter.fromJson(json);

        // Assert
        expect(chapter.chapterNumber, equals(0));
      });
    });
  });

  group('DetectedChapter Model', () {
    group('fromJson constructor', () {
      test('creates DetectedChapter from complete JSON', () {
        // Arrange
        final json = {
          'id': 'detected-ch-1',
          'chapter_number': 1,
          'title': 'Detected Chapter',
          'start_time': 0.0,
          'end_time': 1800.0,
          'duration': 1800.0,
          'confidence': 0.95,
          'summary': 'Chapter summary',
          'key_topics': ['topic1', 'topic2'],
          'word_count': 500,
          'speaker_changes': 3,
        };

        // Act
        final chapter = DetectedChapter.fromJson(json);

        // Assert
        expect(chapter.id, equals('detected-ch-1'));
        expect(chapter.chapterNumber, equals(1));
        expect(chapter.title, equals('Detected Chapter'));
        expect(chapter.startTime, equals(0.0));
        expect(chapter.endTime, equals(1800.0));
        expect(chapter.duration, equals(1800.0));
        expect(chapter.confidence, equals(0.95));
        expect(chapter.summary, equals('Chapter summary'));
        expect(chapter.keyTopics, containsAll(['topic1', 'topic2']));
        expect(chapter.wordCount, equals(500));
        expect(chapter.speakerChanges, equals(3));
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final json = {
          'chapter_number': 2,
          'start_time': 1800.0,
          'end_time': 3600.0,
          'duration': 1800.0,
          'confidence': 0.8,
        };

        // Act
        final chapter = DetectedChapter.fromJson(json);

        // Assert
        expect(chapter.id, equals('chapter_2'));
        expect(chapter.title, equals('Chapter 2'));
        expect(chapter.summary, isNull);
        expect(chapter.keyTopics, isEmpty);
        expect(chapter.wordCount, equals(0));
        expect(chapter.speakerChanges, equals(0));
      });
    });

    group('formattedDuration getter', () {
      test('formats duration in MM:SS for less than one hour', () {
        // Arrange
        final chapter = DetectedChapter(
          id: 'test',
          chapterNumber: 1,
          title: 'Test',
          startTime: 0,
          endTime: 150,
          duration: 150, // 2 minutes 30 seconds
          confidence: 1.0,
        );

        // Act & Assert
        expect(chapter.formattedDuration, equals('2:30'));
      });

      test('formats duration in HH:MM:SS for one hour or more', () {
        // Arrange
        final chapter = DetectedChapter(
          id: 'test',
          chapterNumber: 1,
          title: 'Test',
          startTime: 0,
          endTime: 4500,
          duration: 4500, // 1 hour 15 minutes
          confidence: 1.0,
        );

        // Act & Assert
        expect(chapter.formattedDuration, equals('1:15:00'));
      });
    });

    group('confidencePercentage getter', () {
      test('converts confidence to percentage', () {
        // Arrange
        final chapter = DetectedChapter(
          id: 'test',
          chapterNumber: 1,
          title: 'Test',
          startTime: 0,
          endTime: 100,
          duration: 100,
          confidence: 0.85,
        );

        // Act & Assert
        expect(chapter.confidencePercentage, equals(85));
      });

      test('rounds confidence percentage', () {
        // Arrange
        final chapter = DetectedChapter(
          id: 'test',
          chapterNumber: 1,
          title: 'Test',
          startTime: 0,
          endTime: 100,
          duration: 100,
          confidence: 0.876,
        );

        // Act & Assert
        expect(chapter.confidencePercentage, equals(88));
      });
    });
  });

  group('ChapterSummary Model', () {
    group('fromJson constructor', () {
      test('creates ChapterSummary from complete JSON', () {
        // Arrange
        final json = {
          'chapter_id': 'ch-1',
          'chapter_number': 1,
          'chapter_title': 'Chapter One',
          'summary_text': 'This is the summary',
          'style': 'detailed',
          'key_points': ['point1', 'point2'],
          'themes': ['theme1', 'theme2'],
          'characters_mentioned': ['character1', 'character2'],
          'word_count': 150,
          'confidence_score': 0.9,
        };

        // Act
        final summary = ChapterSummary.fromJson(json);

        // Assert
        expect(summary.chapterId, equals('ch-1'));
        expect(summary.chapterNumber, equals(1));
        expect(summary.chapterTitle, equals('Chapter One'));
        expect(summary.summaryText, equals('This is the summary'));
        expect(summary.style, equals('detailed'));
        expect(summary.keyPoints, containsAll(['point1', 'point2']));
        expect(summary.themes, containsAll(['theme1', 'theme2']));
        expect(summary.charactersMenutioned, containsAll(['character1', 'character2']));
        expect(summary.wordCount, equals(150));
        expect(summary.confidenceScore, equals(0.9));
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final json = {
          'chapter_id': 'ch-2',
          'chapter_number': 2,
          'chapter_title': 'Chapter Two',
          'summary_text': 'Another summary',
          'confidence_score': 0.8,
        };

        // Act
        final summary = ChapterSummary.fromJson(json);

        // Assert
        expect(summary.style, equals('detailed'));
        expect(summary.keyPoints, isEmpty);
        expect(summary.themes, isEmpty);
        expect(summary.charactersMenutioned, isEmpty);
        expect(summary.wordCount, equals(0));
      });
    });
  });

  group('ChapterQuestion Model', () {
    group('fromJson constructor', () {
      test('creates ChapterQuestion from complete JSON', () {
        // Arrange
        final json = {
          'question_id': 'q-1',
          'question_text': 'What is the main theme?',
          'question_type': 'analysis',
          'difficulty': 'intermediate',
          'suggested_answer': 'The main theme is...',
          'answer_guidelines': ['guideline1', 'guideline2'],
          'follow_up_questions': ['follow1', 'follow2'],
          'related_themes': ['theme1', 'theme2'],
          'confidence_score': 0.92,
        };

        // Act
        final question = ChapterQuestion.fromJson(json);

        // Assert
        expect(question.questionId, equals('q-1'));
        expect(question.questionText, equals('What is the main theme?'));
        expect(question.questionType, equals('analysis'));
        expect(question.difficulty, equals('intermediate'));
        expect(question.suggestedAnswer, equals('The main theme is...'));
        expect(question.answerGuidelines, containsAll(['guideline1', 'guideline2']));
        expect(question.followUpQuestions, containsAll(['follow1', 'follow2']));
        expect(question.relatedThemes, containsAll(['theme1', 'theme2']));
        expect(question.confidenceScore, equals(0.92));
      });

      test('handles missing optional fields with defaults', () {
        // Arrange
        final json = {
          'question_id': 'q-2',
          'question_text': 'Simple question?',
          'suggested_answer': 'Simple answer',
          'confidence_score': 0.7,
        };

        // Act
        final question = ChapterQuestion.fromJson(json);

        // Assert
        expect(question.questionType, equals('comprehension'));
        expect(question.difficulty, equals('intermediate'));
        expect(question.answerGuidelines, isEmpty);
        expect(question.followUpQuestions, isEmpty);
        expect(question.relatedThemes, isEmpty);
      });
    });
  });
}