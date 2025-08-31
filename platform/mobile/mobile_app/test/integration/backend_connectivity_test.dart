import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Integration test to verify frontend can connect to all backend endpoints
void main() {
  group('Backend Connectivity Tests', () {
    const String baseUrl = 'http://128.203.92.141:8000';
    const Duration timeout = Duration(seconds: 10);

    test('should connect to health endpoint', () async {
      final response = await http.get(Uri.parse('$baseUrl/health')).timeout(timeout);
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['status'], equals('ok'));
      expect(data['service'], equals('api_gateway'));
    });

    test('should fetch book catalog from browse endpoint', () async {
      final response = await http.get(Uri.parse('$baseUrl/bookstore/browse')).timeout(timeout);
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['books'], isA<List>());
      expect(data['books'].length, greaterThan(0));
      
      // Verify book structure
      final firstBook = data['books'][0];
      expect(firstBook['id'], isNotNull);
      expect(firstBook['title'], isNotNull);
      expect(firstBook['author'], isNotNull);
      expect(firstBook['cover_image_url'], isNotNull);
    });

    test('should fetch featured books', () async {
      final response = await http.get(Uri.parse('$baseUrl/bookstore/featured')).timeout(timeout);
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['books'], isA<List>());
      expect(data['books'].length, greaterThan(0));
    });

    test('should fetch bestsellers', () async {
      final response = await http.get(Uri.parse('$baseUrl/bookstore/bestsellers')).timeout(timeout);
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['books'], isA<List>());
      expect(data['books'].length, greaterThan(0));
    });

    test('should fetch user credits', () async {
      final response = await http.get(Uri.parse('$baseUrl/bookstore/user/credits')).timeout(timeout);
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['total_credits'], isA<int>());
      expect(data['available_credits'], isA<int>());
      expect(data['used_credits'], isA<int>());
    });

    test('should fetch user library', () async {
      final response = await http.get(Uri.parse('$baseUrl/bookstore/user/library')).timeout(timeout);
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['books'], isA<List>());
      expect(data['total_books'], isA<int>());
    });

    test('should fetch book files structure', () async {
      final response = await http.get(Uri.parse('$baseUrl/debug/books')).timeout(timeout);
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['books'], isA<Map>());
      expect(data['book_count'], greaterThan(0));
      
      // Verify book file structure
      final bookEntries = data['books'] as Map<String, dynamic>;
      final firstBookName = bookEntries.keys.first;
      final firstBook = bookEntries[firstBookName];
      expect(firstBook['files'], isA<List>());
      expect(firstBook['file_count'], greaterThan(0));
    });

    test('should search books', () async {
      final response = await http.get(
        Uri.parse('$baseUrl/bookstore/search').replace(queryParameters: {'q': 'gatsby'})
      ).timeout(timeout);
      expect(response.statusCode, equals(200));
      
      final data = jsonDecode(response.body);
      expect(data['books'], isA<List>());
    });

    test('should verify cover image URLs are accessible', () async {
      // First get a book with a cover URL
      final browseResponse = await http.get(Uri.parse('$baseUrl/bookstore/browse')).timeout(timeout);
      final browseData = jsonDecode(browseResponse.body);
      final firstBook = browseData['books'][0];
      final coverUrl = firstBook['cover_image_url'] as String;
      
      // Test cover image accessibility
      final coverResponse = await http.get(Uri.parse('$baseUrl$coverUrl')).timeout(timeout);
      expect(coverResponse.statusCode, equals(200));
      expect(coverResponse.headers['content-type'], contains('image/'));
    });

    test('should verify audio file URLs are accessible', () async {
      // First get a book with an audio URL
      final browseResponse = await http.get(Uri.parse('$baseUrl/bookstore/browse')).timeout(timeout);
      final browseData = jsonDecode(browseResponse.body);
      final firstBook = browseData['books'][0];
      final audioUrl = firstBook['sample_audio_url'] as String;
      
      // Test audio file accessibility
      final audioResponse = await http.get(Uri.parse('$baseUrl$audioUrl')).timeout(timeout);
      expect(audioResponse.statusCode, equals(200));
      expect(audioResponse.headers['content-type'], contains('audio/'));
    });
  });
}