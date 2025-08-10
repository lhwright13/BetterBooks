import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> testApiConnection() async {
  try {
    print('Testing API connection to http://localhost:8000/books/list');
    
    final response = await http.get(
      Uri.parse('http://localhost:8000/books/list'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(Duration(seconds: 5));

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Parsed data: $data');
      print('Single books: ${data['single_books']}');
      print('Chapter books: ${data['chapter_books']}');
    }
  } catch (e) {
    print('API connection error: $e');
    print('Error type: ${e.runtimeType}');
  }
}