import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/book.dart';
import '../models/persona.dart';

class ApiService {
  static const Duration _timeoutDuration = Duration(seconds: 30);

  static Future<bool> testConnection() async {
    try {
      print('Testing connection to: $apiBaseUrl/health');
      final response = await http.get(
        Uri.parse('$apiBaseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);
      
      print('Health check response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  static Future<List<Book>> getBooks() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/list'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final books = <Book>[];
        
        print('API Response: $data');
        
        // Handle single books
        if (data['single_books'] != null) {
          for (final bookData in data['single_books']) {
            books.add(Book.fromJson({
              'id': bookData,
              'title': bookData.replaceAll('.mp3', ''),
              'audio_url': '$apiBaseUrl/books/play/$bookData',
            }));
          }
        }
        
        // Handle chapter-based books
        if (data['chapter_books'] != null) {
          for (final bookData in data['chapter_books']) {
            final bookName = bookData['name'] as String;
            final chapterFiles = bookData['chapters'] as List<dynamic>;
            final chapters = chapterFiles.map((chapterFile) {
              final chapterFileName = chapterFile.toString();
              final chapterNum = int.tryParse(
                chapterFileName.split(' ').last.replaceAll('.mp3', '')
              ) ?? 0;
              return Chapter(
                id: chapterFileName,
                title: chapterFileName.replaceAll('.mp3', ''),
                audioUrl: '$apiBaseUrl/books/play/${Uri.encodeComponent(bookName)}/${Uri.encodeComponent(chapterFileName)}',
                chapterNumber: chapterNum,
              );
            }).toList();
            
            books.add(Book(
              id: bookName,
              title: bookName,
              chapters: chapters,
            ));
          }
        }
        
        return books;
      } else {
        throw Exception('Failed to load books: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<List<Persona>> getPersonas() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/configs'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['configs'] as List)
            .map((configName) => Persona(
              name: configName.toString(),
              displayName: configName.toString(),
              description: 'AI assistant persona: $configName',
              voice: 'en-US-Neural2-C',
              voiceConfig: {},
            ))
            .toList();
      } else {
        throw Exception('Failed to load personas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<String> sendMessage(String message, String persona) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': message,
          'config': persona,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] ?? 'No response';
      } else {
        throw Exception('Failed to send message: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<String> synthesizeSpeech(String text, String persona) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/tts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'config': persona,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['audio'] ?? '';
      } else {
        throw Exception('Failed to synthesize speech: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<String> getContext(String bookName, String? chapterName, double currentPosition) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/context'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'book_name': bookName,
          'chapter_name': chapterName,
          'current_position': currentPosition,
        }),
      ).timeout(_timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['context'] ?? '';
      } else {
        throw Exception('Failed to get context: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}