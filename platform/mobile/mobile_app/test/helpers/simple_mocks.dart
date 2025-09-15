import 'package:mockito/mockito.dart';
import 'package:echowright_rebuilt/data/models/book_models.dart';
import 'package:echowright_rebuilt/data/models/auth_models.dart';
import 'package:echowright_rebuilt/data/repositories/book_repository.dart';
import 'package:echowright_rebuilt/data/repositories/user_repository.dart';
import 'package:echowright_rebuilt/data/repositories/purchase_repository.dart';
import 'package:echowright_rebuilt/data/repositories/library_repository.dart';
import 'package:echowright_rebuilt/data/api/api_client.dart';

/// Simple manual mocks for immediate testing without build_runner
class MockBookRepository extends Mock implements BookRepository {
  List<BrowseBook> _mockBooks = [];
  
  void setMockBooks(List<BrowseBook> books) => _mockBooks = books;
  
  @override
  Future<List<BrowseBook>> getFeaturedBooks() async => _mockBooks.where((b) => b.isFeatured).toList();
  
  @override
  Future<List<BrowseBook>> getBestsellingBooks() async => _mockBooks.where((b) => b.isBestseller).toList();
  
  @override
  Future<List<BrowseBook>> getBrowseBooks() async => _mockBooks;
  
  @override
  Future<List<BrowseBook>> searchBooks(String query) async => _mockBooks;
  @override
  Future<DetailedBook> getBookDetails(String bookId) async {
    final book = _mockBooks.firstWhere((b) => b.id == bookId);
    return DetailedBook(
      id: book.id,
      title: book.title,
      author: book.author,
      coverImageUrl: book.coverImageUrl,
      priceUsd: book.priceUsd,
      chapters: book.chapters,
      reviews: [],
    );
  }
}

class MockUserRepository extends Mock implements UserRepository {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  
  void setAuthenticated(bool authenticated, {Map<String, dynamic>? user}) {
    _isAuthenticated = authenticated;
    _currentUser = user;
  }
  
  @override
  bool isAuthenticated() => _isAuthenticated;
  
  Map<String, dynamic>? getCurrentUser() => _currentUser;
  @override
  Future<AuthResponse> signIn(String email, String password) async {
    _isAuthenticated = true;
    _currentUser = {'id': 'test-user', 'email': email, 'display_name': 'Test User'};
    return AuthResponse(
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      user: _currentUser!,
      expiresAt: DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch,
    );
  }
  
  @override
  Future<AuthResponse> signUp(String email, String password) async {
    return signIn(email, password); // Mock implementation
  }
  
  @override
  Future<AuthResponse> signInWithGoogle({required String idToken, required String accessToken, String? email, String? displayName}) async {
    return signIn(email ?? 'google@example.com', 'google');
  }
  
  @override
  Future<AuthResponse> signInWithApple({required String identityToken, String? authorizationCode, String? email, String? fullName}) async {
    return signIn(email ?? 'apple@example.com', 'apple');
  }
  
  @override
  Future<int> getUserCredits() async {
    return 5; // Mock credits
  }
  
  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
    _currentUser = null;
  }
}

class MockPurchaseRepository extends Mock {
  int _mockCredits = 5;
  
  void setMockCredits(int credits) => _mockCredits = credits;
  
  Future<int> getUserCredits() async => _mockCredits;
  Future<PurchaseResponse> purchaseBook(String bookId) async {
    if (_mockCredits > 0) {
      _mockCredits--;
      return PurchaseResponse(
        success: true,
        message: 'Purchase successful',
        remainingCredits: _mockCredits,
      );
    }
    return PurchaseResponse(
      success: false,
      message: 'Insufficient credits',
      remainingCredits: _mockCredits,
    );
  }
}

class MockLibraryRepository extends Mock {
  List<BrowseBook> _library = [];
  
  void setMockLibrary(List<BrowseBook> books) => _library = books;
  
  Future<List<BrowseBook>> getUserLibrary() async => _library;
  Future<List<Map<String, dynamic>>> getPurchaseHistory() async => [];
}

class MockDownloadService extends Mock {
  Map<String, bool> _downloadedBooks = {};
  Map<String, bool> _downloadingBooks = {};
  
  void setDownloaded(String bookId, bool downloaded) => _downloadedBooks[bookId] = downloaded;
  void setDownloading(String bookId, bool downloading) => _downloadingBooks[bookId] = downloading;
  
  Future<bool> isBookDownloaded(String bookId) async => _downloadedBooks[bookId] ?? false;
  bool isDownloading(String bookId) => _downloadingBooks[bookId] ?? false;
  
  Future<void> downloadBook(dynamic book, {bool isRetry = false}) async {
    _downloadingBooks[book.id] = true;
    await Future.delayed(Duration(milliseconds: 100));
    _downloadingBooks[book.id] = false;
    _downloadedBooks[book.id] = true;
  }
}

class MockVoiceService extends Mock {
  bool _isListening = false;
  bool _isAvailable = true;
  String _lastText = '';
  
  void setAvailable(bool available) => _isAvailable = available;
  void setListening(bool listening) => _isListening = listening;
  void setLastText(String text) => _lastText = text;
  
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get lastRecognizedText => _lastText;
  
  Future<bool> initialize({bool forceReinit = false}) async => _isAvailable;
  Future<bool> startListening({Duration? timeout}) async {
    _isListening = true;
    return true;
  }
  Future<bool> stopListening() async {
    _isListening = false;
    return true;
  }
}

class MockPlayerStateService extends Mock {
  String? _currentBookId;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  double _speed = 1.0;
  int _chapter = 0;
  
  String? get currentBookId => _currentBookId;
  Duration get currentPosition => _position;
  bool get isPlaying => _isPlaying;
  double get playbackSpeed => _speed;
  int get currentChapter => _chapter;
  
  Future<void> loadBook(String bookId) async => _currentBookId = bookId;
  Future<void> play() async => _isPlaying = true;
  Future<void> pause() async => _isPlaying = false;
  Future<void> seek(Duration position) async => _position = position;
  Future<void> setPlaybackSpeed(double speed) async => _speed = speed;
  Future<void> seekToChapter(int chapter) async => _chapter = chapter;
}