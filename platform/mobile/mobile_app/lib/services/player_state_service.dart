import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../data/models/book_models.dart';
import '../core/services/logging_service.dart';

enum AppPlayerState { stopped, playing, paused, loading }

class PlayerStateService extends ChangeNotifier {
  static PlayerStateService? _instance;
  static PlayerStateService get instance => _instance ??= PlayerStateService._();
  
  late final AudioPlayer _audioPlayer;
  Timer? _positionTimer;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  
  PlayerStateService._() {
    _audioPlayer = AudioPlayer();
    _initializeAudioPlayer();
    _loadPersistedState();
  }
  
  DetailedBook? _currentBook;
  AppPlayerState _playerState = AppPlayerState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  int _currentChapterIndex = 0;
  double _playbackSpeed = 1.0;
  
  // Getters
  DetailedBook? get currentBook => _currentBook;
  AppPlayerState get playerState => _playerState;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  int get currentChapterIndex => _currentChapterIndex;
  double get playbackSpeed => _playbackSpeed;
  bool get isPlaying => _playerState == AppPlayerState.playing;
  bool get hasCurrentBook => _currentBook != null;
  
  String get currentChapterTitle {
    if (_currentBook?.chapters.isNotEmpty == true && 
        _currentChapterIndex < _currentBook!.chapters.length) {
      return _currentBook!.chapters[_currentChapterIndex].title;
    }
    return 'Chapter ${_currentChapterIndex + 1}';
  }
  
  double get progress {
    if (_totalDuration.inMilliseconds == 0) return 0.0;
    return _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
  }
  
  // Methods
  Future<void> setCurrentBook(DetailedBook book, {int chapterIndex = 0}) async {
    // Stop current playback
    await _audioPlayer.stop();
    
    _currentBook = book;
    _currentChapterIndex = chapterIndex;
    _currentPosition = Duration.zero;
    _totalDuration = Duration(seconds: book.totalDuration ?? 0);
    _playerState = AppPlayerState.stopped;
    
    // Load saved progress
    await _loadBookProgress(book.id);
    
    // Prepare audio source if book has audio URL
    await _prepareAudioSource();
    
    notifyListeners();
  }
  
  Future<void> _prepareAudioSource() async {
    if (_currentBook?.audioUrl?.isNotEmpty == true) {
      try {
        await _audioPlayer.setSourceUrl(_currentBook!.audioUrl!);
        logInfo('Audio source prepared for ${_currentBook!.title}', tag: 'PlayerStateService');
      } catch (e) {
        logError('Failed to prepare audio source: $e', tag: 'PlayerStateService');
        // For demo purposes, don't throw - just log the error
      }
    } else {
      logWarning('No audio URL available for book: ${_currentBook?.title}', tag: 'PlayerStateService');
    }
  }
  
  Future<void> play() async {
    if (_currentBook != null) {
      try {
        // If we have a saved position, seek to it first
        if (_currentPosition > Duration.zero) {
          await _audioPlayer.seek(_currentPosition);
        }
        
        await _audioPlayer.resume();
        logInfo('Started playback: ${_currentBook!.title}', tag: 'PlayerStateService');
      } catch (e) {
        logError('Failed to start playback: $e', tag: 'PlayerStateService');
        // For demo, simulate playback without actual audio
        _playerState = AppPlayerState.playing;
        _startPositionTimer();
        notifyListeners();
      }
    }
  }
  
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      logInfo('Paused playback', tag: 'PlayerStateService');
    } catch (e) {
      logError('Failed to pause playback: $e', tag: 'PlayerStateService');
      // For demo, manually set state
      _playerState = AppPlayerState.paused;
      _stopPositionTimer();
      notifyListeners();
    }
  }
  
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      logInfo('Stopped playback', tag: 'PlayerStateService');
    } catch (e) {
      logError('Failed to stop playback: $e', tag: 'PlayerStateService');
      // For demo, manually set state
      _playerState = AppPlayerState.stopped;
      _currentPosition = Duration.zero;
      _stopPositionTimer();
      notifyListeners();
    }
  }
  
  Future<void> togglePlayPause() async {
    if (_playerState == AppPlayerState.playing) {
      await pause();
    } else {
      await play();
    }
  }
  
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      _currentPosition = position;
      _persistProgress();
      logInfo('Seeked to position: ${position.inSeconds}s', tag: 'PlayerStateService');
    } catch (e) {
      logError('Failed to seek: $e', tag: 'PlayerStateService');
      // For demo, just update position locally
      _currentPosition = position;
      _persistProgress();
    }
    notifyListeners();
  }
  
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _audioPlayer.setPlaybackRate(speed);
      _playbackSpeed = speed;
      logInfo('Set playback speed to ${speed}x', tag: 'PlayerStateService');
    } catch (e) {
      logError('Failed to set playback speed: $e', tag: 'PlayerStateService');
      // For demo, just update speed locally
      _playbackSpeed = speed;
    }
    notifyListeners();
  }
  
  Future<void> nextChapter() async {
    if (_currentBook?.chapters.isNotEmpty == true && 
        _currentChapterIndex < _currentBook!.chapters.length - 1) {
      _currentChapterIndex++;
      _currentPosition = Duration.zero;
      
      // If we have chapter-specific audio URLs, load the new chapter
      await _prepareAudioSource();
      
      _persistProgress();
      notifyListeners();
      
      logInfo('Advanced to chapter ${_currentChapterIndex + 1}: ${currentChapterTitle}', tag: 'PlayerStateService');
    }
  }
  
  Future<void> previousChapter() async {
    if (_currentChapterIndex > 0) {
      _currentChapterIndex--;
      _currentPosition = Duration.zero;
      
      // If we have chapter-specific audio URLs, load the new chapter
      await _prepareAudioSource();
      
      _persistProgress();
      notifyListeners();
      
      logInfo('Went back to chapter ${_currentChapterIndex + 1}: ${currentChapterTitle}', tag: 'PlayerStateService');
    }
  }
  
  Future<void> rewind([Duration amount = const Duration(seconds: 15)]) async {
    final newPosition = _currentPosition - amount;
    final targetPosition = newPosition.isNegative ? Duration.zero : newPosition;
    await seekTo(targetPosition);
    logInfo('Rewound ${amount.inSeconds} seconds', tag: 'PlayerStateService');
  }
  
  Future<void> fastForward([Duration amount = const Duration(seconds: 15)]) async {
    final newPosition = _currentPosition + amount;
    final targetPosition = newPosition > _totalDuration ? _totalDuration : newPosition;
    await seekTo(targetPosition);
    logInfo('Fast-forwarded ${amount.inSeconds} seconds', tag: 'PlayerStateService');
  }
  
  Future<void> updatePosition(Duration position) async {
    await seekTo(position);
  }
  
  Future<void> setLoading(bool loading) async {
    if (loading) {
      _playerState = AppPlayerState.loading;
    } else if (_playerState == AppPlayerState.loading) {
      _playerState = AppPlayerState.stopped;
    }
    notifyListeners();
  }
  
  // Clear current book (for logout, etc.)
  Future<void> clearCurrentBook() async {
    await _audioPlayer.stop();
    _stopPositionTimer();
    _currentBook = null;
    _playerState = AppPlayerState.stopped;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _currentChapterIndex = 0;
    notifyListeners();
  }
  
  // Persistence methods
  Future<void> _loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentBookId = prefs.getString('current_book_id');
      final playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
      
      _playbackSpeed = playbackSpeed;
      
      if (currentBookId != null) {
        // Note: Book object would need to be reloaded from API/cache
        // This is a simplified implementation that stores the position
        await _loadBookProgress(currentBookId);
      }
    } catch (e) {
      logError('Failed to load persisted player state: $e', tag: 'PlayerStateService');
    }
  }
  
  Future<void> _loadBookProgress(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final progressData = prefs.getString('book_progress_$bookId');
      
      if (progressData != null) {
        final data = jsonDecode(progressData);
        _currentPosition = Duration(milliseconds: data['position'] ?? 0);
        _currentChapterIndex = data['chapter'] ?? 0;
        logDebug('Loaded progress for book $bookId: ${_currentPosition.inSeconds}s, chapter $_currentChapterIndex', tag: 'PlayerStateService');
      }
    } catch (e) {
      logError('Failed to load book progress for $bookId: $e', tag: 'PlayerStateService');
    }
  }
  
  Future<void> _persistProgress() async {
    if (_currentBook == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save current book ID
      await prefs.setString('current_book_id', _currentBook!.id);
      
      // Save playback speed
      await prefs.setDouble('playback_speed', _playbackSpeed);
      
      // Save book-specific progress
      final progressData = {
        'position': _currentPosition.inMilliseconds,
        'chapter': _currentChapterIndex,
        'lastPlayed': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('book_progress_${_currentBook!.id}', jsonEncode(progressData));
      logDebug('Persisted progress for ${_currentBook!.title}: ${_currentPosition.inSeconds}s, chapter $_currentChapterIndex', tag: 'PlayerStateService');
    } catch (e) {
      logError('Failed to persist progress: $e', tag: 'PlayerStateService');
    }
  }
  
  Future<void> clearBookProgress(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('book_progress_$bookId');
      logInfo('Cleared progress for book $bookId', tag: 'PlayerStateService');
    } catch (e) {
      logError('Failed to clear progress for book $bookId: $e', tag: 'PlayerStateService');
    }
  }

  Future<void> _initializeAudioPlayer() async {
    // Listen to player state changes
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _playerState = AppPlayerState.playing;
          _startPositionTimer();
          break;
        case PlayerState.paused:
          _playerState = AppPlayerState.paused;
          _stopPositionTimer();
          break;
        case PlayerState.stopped:
          _playerState = AppPlayerState.stopped;
          _stopPositionTimer();
          // Check if playback was completed
          if (_currentPosition >= _totalDuration - const Duration(seconds: 1)) {
            _onPlaybackCompleted();
          }
          break;
        default:
          break;
      }
      notifyListeners();
    });
    
    // Listen to duration changes
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });
    
    // Listen to position changes for more responsive updates
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      _persistProgress(); // Save progress periodically
      notifyListeners();
    });
  }
  
  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final position = await _audioPlayer.getCurrentPosition();
        if (position != null) {
          _currentPosition = position;
          _persistProgress();
          notifyListeners();
        }
      } catch (e) {
        logError('Error getting audio position: $e', tag: 'PlayerStateService');
      }
    });
  }
  
  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }
  
  void _onPlaybackCompleted() {
    // Auto-advance to next chapter if available
    if (_currentBook?.chapters.isNotEmpty == true && 
        _currentChapterIndex < _currentBook!.chapters.length - 1) {
      nextChapter();
      play(); // Auto-play next chapter
    } else {
      // Book completed
      _currentPosition = Duration.zero;
      _persistProgress();
    }
  }
  
  @override
  void dispose() {
    _stopPositionTimer();
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    clearCurrentBook();
    super.dispose();
  }
}