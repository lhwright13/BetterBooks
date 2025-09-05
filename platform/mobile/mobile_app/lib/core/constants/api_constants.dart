/// API Configuration Constants
class ApiConstants {
  static const String baseUrl = 'http://128.203.92.141:8000';
  
  // Authentication endpoints
  static const String authSignUp = '/auth/signup';
  static const String authSignIn = '/auth/signin';
  static const String authMe = '/auth/me';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  
  // Bookstore endpoints
  static const String bookstoreBrowse = '/bookstore/browse';
  static const String bookstoreSearch = '/bookstore/search';
  static const String bookstoreFeatured = '/bookstore/featured';
  static const String bookstoreBestsellers = '/bookstore/bestsellers';
  static const String bookstoreUserLibrary = '/bookstore/user/library';
  static const String bookstoreUserCredits = '/bookstore/user/credits';
  static const String bookstorePurchase = '/bookstore/purchase';
  
  // Wishlist endpoints
  static const String wishlistAdd = '/bookstore/user/wishlist';
  static const String wishlistRemove = '/bookstore/user/wishlist';
  static const String wishlistGet = '/bookstore/user/wishlist';
  
  // AI endpoints  
  static const String complete = '/complete';
  static const String tts = '/tts';
  static const String personas = '/personas';
  
  // Request timeout
  static const Duration timeout = Duration(seconds: 30);
}