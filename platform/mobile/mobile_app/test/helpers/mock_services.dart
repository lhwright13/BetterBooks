import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:echowright_rebuilt/data/repositories/book_repository.dart';
import 'package:echowright_rebuilt/data/repositories/user_repository.dart';
import 'package:echowright_rebuilt/data/repositories/purchase_repository.dart';
import 'package:echowright_rebuilt/data/repositories/library_repository.dart';
import 'package:echowright_rebuilt/data/api/api_client.dart';
import 'package:echowright_rebuilt/services/download_service.dart';
import 'package:echowright_rebuilt/services/voice_service.dart';
import 'package:echowright_rebuilt/services/player_state_service.dart';
import 'package:echowright_rebuilt/services/auth_service.dart';
import 'package:echowright_rebuilt/core/network/network_service.dart';

// Import generated mocks
part 'mock_services.mocks.dart';

/// Manual mocks for classes that need specific behavior
class MockApiClientManual extends Mock implements ApiClient {
  bool _shouldFail = false;
  Duration _delay = Duration.zero;
  
  void setShouldFail(bool shouldFail) => _shouldFail = shouldFail;
  void setDelay(Duration delay) => _delay = delay;
  
  Future<T> _handleCall<T>(T Function() call) async {
    if (_delay > Duration.zero) {
      await Future.delayed(_delay);
    }
    
    if (_shouldFail) {
      throw Exception('Mock API failure');
    }
    
    return call();
  }
}

class MockDownloadServiceManual extends Mock implements DownloadService {
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadingBooks = {};
  final Set<String> _downloadedBooks = {};
  
  @override
  Stream<double>? getDownloadProgress(String bookId) {
    if (!_downloadingBooks.contains(bookId)) return null;
    
    return Stream.periodic(const Duration(milliseconds: 100), (count) {
      final progress = (count * 0.1).clamp(0.0, 1.0);
      _downloadProgress[bookId] = progress;
      
      if (progress >= 1.0) {
        _downloadingBooks.remove(bookId);
        _downloadedBooks.add(bookId);
      }
      
      return progress;
    }).take(11); // 0.0 to 1.0 in 0.1 increments
  }
  
  @override
  bool isDownloading(String bookId) => _downloadingBooks.contains(bookId);
  
  @override
  Future<bool> isBookDownloaded(String bookId) async => _downloadedBooks.contains(bookId);
  
  @override
  Future<void> downloadBook(dynamic book, {bool isRetry = false}) async {
    final bookId = book.id;
    _downloadingBooks.add(bookId);
    
    // Simulate download
    await Future.delayed(const Duration(milliseconds: 100));
    
    _downloadingBooks.remove(bookId);
    _downloadedBooks.add(bookId);
  }
  
  @override
  Future<void> cancelDownload(String bookId) async {
    _downloadingBooks.remove(bookId);
    _downloadProgress.remove(bookId);
  }
  
  @override
  Future<void> deleteDownload(String bookId) async {
    _downloadedBooks.remove(bookId);
  }
  
  @override
  Future<List<String>> getDownloadedBookIds() async => _downloadedBooks.toList();
  
  // Mock methods for testing
  void simulateDownloadStart(String bookId) => _downloadingBooks.add(bookId);
  void simulateDownloadComplete(String bookId) {
    _downloadingBooks.remove(bookId);
    _downloadedBooks.add(bookId);
  }
  void clearAllDownloads() {
    _downloadingBooks.clear();
    _downloadedBooks.clear();
    _downloadProgress.clear();
  }
}

class MockVoiceServiceManual extends Mock implements VoiceService {
  bool _isListening = false;
  bool _isAvailable = true;
  String _lastRecognizedText = '';
  
  @override
  bool get isListening => _isListening;
  
  @override
  bool get isAvailable => _isAvailable;
  
  @override
  String get lastRecognizedText => _lastRecognizedText;
  
  @override
  Future<bool> initialize() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _isAvailable;
  }
  
  @override
  Future<void> startListening() async {
    if (!_isAvailable) throw Exception('Voice service not available');
    _isListening = true;
  }
  
  @override
  Future<void> stopListening() async {
    _isListening = false;
  }
  
  @override
  Future<String> recognizeSpeech() async {
    if (!_isListening) throw Exception('Not currently listening');
    
    await Future.delayed(const Duration(milliseconds: 500));
    _lastRecognizedText = 'Mock recognized text';
    return _lastRecognizedText;
  }
  
  // Mock control methods
  void setAvailable(bool available) => _isAvailable = available;
  void setRecognizedText(String text) => _lastRecognizedText = text;
}

class MockPlayerStateServiceManual extends Mock implements PlayerStateService {
  String? _currentBookId;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _currentChapter = 0;
  
  @override
  String? get currentBookId => _currentBookId;
  
  @override
  Duration get currentPosition => _currentPosition;
  
  @override
  bool get isPlaying => _isPlaying;
  
  @override
  double get playbackSpeed => _playbackSpeed;
  
  @override
  int get currentChapter => _currentChapter;
  
  @override
  Future<void> loadBook(String bookId) async {
    _currentBookId = bookId;
    _currentPosition = Duration.zero;
    _currentChapter = 0;
    _isPlaying = false;
  }
  
  @override
  Future<void> play() async {
    if (_currentBookId == null) throw Exception('No book loaded');
    _isPlaying = true;
  }
  
  @override
  Future<void> pause() async {
    _isPlaying = false;
  }
  
  @override
  Future<void> seek(Duration position) async {
    if (_currentBookId == null) throw Exception('No book loaded');
    _currentPosition = position;
  }
  
  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.5, 3.0);
  }
  
  @override
  Future<void> seekToChapter(int chapter) async {
    if (_currentBookId == null) throw Exception('No book loaded');
    _currentChapter = chapter;
    _currentPosition = Duration.zero;
  }
  
  // Mock control methods
  void simulatePlaybackProgress(Duration position) => _currentPosition = position;
  void reset() {
    _currentBookId = null;
    _currentPosition = Duration.zero;
    _isPlaying = false;
    _playbackSpeed = 1.0;
    _currentChapter = 0;
  }
}

/// Factory for creating configured mocks
class MockFactory {
  /// Create a BookRepository mock with common stubbed methods
  static MockBookRepository createBookRepository() {
    final mock = MockBookRepository();
    
    // Add common stubs here
    when(mock.getFeaturedBooks()).thenAnswer((_) async => []);
    when(mock.getBestsellers()).thenAnswer((_) async => []);
    when(mock.browseBooks()).thenAnswer((_) async => []);
    
    return mock;
  }
  
  /// Create a UserRepository mock with common stubbed methods
  static MockUserRepository createUserRepository() {
    final mock = MockUserRepository();
    
    // Add common stubs
    when(mock.isAuthenticated()).thenReturn(false);
    when(mock.getCurrentUser()).thenReturn(null);
    
    return mock;
  }
  
  /// Create a PurchaseRepository mock with common stubbed methods
  static MockPurchaseRepository createPurchaseRepository() {
    final mock = MockPurchaseRepository();
    
    // Add common stubs
    when(mock.getUserCredits()).thenAnswer((_) async => 5);
    
    return mock;
  }
  
  /// Create a LibraryRepository mock with common stubbed methods
  static MockLibraryRepository createLibraryRepository() {
    final mock = MockLibraryRepository();
    
    // Add common stubs
    when(mock.getUserLibrary()).thenAnswer((_) async => []);
    when(mock.getPurchaseHistory()).thenAnswer((_) async => []);
    
    return mock;
  }
  
  /// Create a complete set of mocked services for testing
  static Map<Type, dynamic> createMockServices() {
    return {
      BookRepository: createBookRepository(),
      UserRepository: createUserRepository(),
      PurchaseRepository: createPurchaseRepository(),
      LibraryRepository: createLibraryRepository(),
      DownloadService: MockDownloadServiceManual(),
      VoiceService: MockVoiceServiceManual(),
      PlayerStateService: MockPlayerStateServiceManual(),
    };
  }
}