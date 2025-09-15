import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/auth_models.dart';
import '../models/book_models.dart';

/// Type-safe API client for EchoWright backend
class ApiClient {
  static String? _authToken;
  
  static void setAuthToken(String token) {
    _authToken = token;
  }
  
  static String? get authToken => _authToken;
  
  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }
  
  /// Authentication endpoints
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final request = EmailSignUpRequest(
      email: email,
      password: password,
      displayName: displayName,
    );
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authSignUp}'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to sign up: ${response.body}');
    }
  }
  
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final request = EmailSignInRequest(
      email: email,
      password: password,
    );
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authSignIn}'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to sign in: ${response.body}');
    }
  }
  
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authMe}'),
      headers: _headers,
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get current user: ${response.body}');
    }
  }
  
  static Future<AuthResponse> refreshToken(String refreshToken) async {
    final request = {'refresh_token': refreshToken};
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authRefresh}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to refresh token: ${response.body}');
    }
  }

  static Future<void> logout() async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.authLogout}'),
      headers: _headers,
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to logout: ${response.body}');
    }
  }
  
  /// Bookstore endpoints
  static Future<BrowseResponse> browseBooks({
    bool featured = false,
    bool bestsellers = false,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookstoreBrowse}')
        .replace(queryParameters: {
      'featured': featured.toString(),
      'bestsellers': bestsellers.toString(),
      'page': page.toString(),
      'limit': limit.toString(),
    });
    
    final response = await http.get(uri, headers: _headers)
        .timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return BrowseResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to browse books: ${response.body}');
    }
  }
  
  static Future<BrowseResponse> searchBooks({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookstoreSearch}')
        .replace(queryParameters: {
      'q': query,
      'page': page.toString(),
      'limit': limit.toString(),
    });
    
    final response = await http.get(uri, headers: _headers)
        .timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return BrowseResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to search books: ${response.body}');
    }
  }
  
  static Future<BrowseResponse> getFeaturedBooks({int limit = 10}) async {
    return browseBooks(featured: true, limit: limit);
  }
  
  static Future<BrowseResponse> getBestsellingBooks({int limit = 10}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookstoreBestsellers}')
        .replace(queryParameters: {'limit': limit.toString()});
    
    final response = await http.get(uri, headers: _headers)
        .timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return BrowseResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get bestselling books: ${response.body}');
    }
  }
  
  static Future<DetailedBook> getBookDetails(String bookId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/bookstore/books/$bookId'),
      headers: _headers,
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return DetailedBook.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get book details: ${response.body}');
    }
  }
  
  static Future<CreditBalanceResponse> getUserCredits() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookstoreUserCredits}'),
      headers: _headers,
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return CreditBalanceResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get user credits: ${response.body}');
    }
  }
  
  static Future<BrowseResponse> getUserLibrary() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookstoreUserLibrary}'),
      headers: _headers,
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return BrowseResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get user library: ${response.body}');
    }
  }
  
  static Future<PurchaseResponse> purchaseBook(String bookId) async {
    final request = {'book_id': bookId};
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.bookstorePurchase}'),
      headers: _headers,
      body: jsonEncode(request),
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      return PurchaseResponse.fromJson(jsonDecode(response.body));
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to purchase book');
    }
  }
  
  /// Wishlist endpoints
  static Future<void> addToWishlist(String bookId) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.wishlistAdd}/$bookId'),
      headers: _headers,
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to add to wishlist: ${response.body}');
    }
  }
  
  static Future<void> removeFromWishlist(String bookId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.wishlistRemove}/$bookId'),
      headers: _headers,
    ).timeout(ApiConstants.timeout);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to remove from wishlist: ${response.body}');
    }
  }
  
  static Future<List<BrowseBook>> getUserWishlist({
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.wishlistGet}')
        .replace(queryParameters: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    
    final response = await http.get(uri, headers: _headers)
        .timeout(ApiConstants.timeout);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['books'] as List)
          .map((book) => BrowseBook.fromJson(book))
          .toList();
    } else {
      throw Exception('Failed to get wishlist: ${response.body}');
    }
  }
}