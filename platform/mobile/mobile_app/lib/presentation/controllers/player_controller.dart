import '../../services/player_state_service.dart';
import '../../data/models/book_models.dart';
import 'base_controller.dart';

class PlayerController extends BaseController {
  final PlayerStateService _playerService;
  
  DetailedBook? _currentBook;
  bool _isPlaying = false;
  double _progress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  int _currentChapterIndex = 0;

  PlayerController(this._playerService) {
    _initializeListeners();
  }

  // Getters
  DetailedBook? get currentBook => _currentBook;
  bool get isPlaying => _isPlaying;
  double get progress => _progress;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  double get playbackSpeed => _playbackSpeed;
  int get currentChapterIndex => _currentChapterIndex;
  String get currentChapterTitle {
    if (_currentBook?.chapters.isNotEmpty == true && 
        _currentChapterIndex < _currentBook!.chapters.length) {
      return _currentBook!.chapters[_currentChapterIndex].title;
    }
    return 'Chapter ${_currentChapterIndex + 1}';
  }

  void _initializeListeners() {
    _playerService.addListener(_onPlayerStateChanged);
  }

  void _onPlayerStateChanged() {
    final hasChanges = _isPlaying != _playerService.isPlaying ||
                      _progress != _playerService.progress ||
                      _currentPosition != _playerService.currentPosition ||
                      _totalDuration != _playerService.totalDuration ||
                      _playbackSpeed != _playerService.playbackSpeed ||
                      _currentChapterIndex != _playerService.currentChapterIndex;

    if (hasChanges) {
      _isPlaying = _playerService.isPlaying;
      _progress = _playerService.progress;
      _currentPosition = _playerService.currentPosition;
      _totalDuration = _playerService.totalDuration;
      _playbackSpeed = _playerService.playbackSpeed;
      _currentChapterIndex = _playerService.currentChapterIndex;
      notifyListeners();
    }
  }

  Future<void> setCurrentBook(DetailedBook book) async {
    return handleAsyncOperation(
      () async {
        logInfo('Setting current book: ${book.title}');
        
        _currentBook = book;
        await _playerService.setCurrentBook(book);
        
        logInfo('Book set successfully');
        notifyListeners();
      },
      errorMessage: 'Failed to load audiobook. Please try again.',
    );
  }

  Future<void> togglePlayPause() async {
    return handleAsyncOperation(
      () async {
        if (_isPlaying) {
          logInfo('Pausing playback');
          await _playerService.pause();
        } else {
          logInfo('Starting playback');
          await _playerService.play();
        }
      },
      showLoading: false,
      errorMessage: 'Failed to control playback.',
    );
  }

  Future<void> seekTo(Duration position) async {
    return handleAsyncOperation(
      () async {
        logInfo('Seeking to position: ${position.inSeconds}s');
        await _playerService.seekTo(position);
      },
      showLoading: false,
      errorMessage: 'Failed to seek to position.',
    );
  }

  Future<void> fastForward([Duration duration = const Duration(seconds: 10)]) async {
    return handleAsyncOperation(
      () async {
        logInfo('Fast forwarding ${duration.inSeconds}s');
        await _playerService.fastForward(duration);
      },
      showLoading: false,
      errorMessage: 'Failed to fast forward.',
    );
  }

  Future<void> rewind([Duration duration = const Duration(seconds: 10)]) async {
    return handleAsyncOperation(
      () async {
        logInfo('Rewinding ${duration.inSeconds}s');
        await _playerService.rewind(duration);
      },
      showLoading: false,
      errorMessage: 'Failed to rewind.',
    );
  }

  Future<void> nextChapter() async {
    return handleAsyncOperation(
      () async {
        if (_currentBook?.chapters.isNotEmpty == true && 
            _currentChapterIndex < _currentBook!.chapters.length - 1) {
          logInfo('Moving to next chapter');
          await _playerService.nextChapter();
        }
      },
      showLoading: false,
      errorMessage: 'Failed to go to next chapter.',
    );
  }

  Future<void> previousChapter() async {
    return handleAsyncOperation(
      () async {
        if (_currentChapterIndex > 0) {
          logInfo('Moving to previous chapter');
          await _playerService.previousChapter();
        }
      },
      showLoading: false,
      errorMessage: 'Failed to go to previous chapter.',
    );
  }

  Future<void> setPlaybackSpeed(double speed) async {
    return handleAsyncOperation(
      () async {
        logInfo('Setting playback speed to ${speed}x');
        await _playerService.setPlaybackSpeed(speed);
      },
      showLoading: false,
      errorMessage: 'Failed to change playback speed.',
    );
  }

  bool get hasNextChapter {
    return _currentBook?.chapters.isNotEmpty == true && 
           _currentChapterIndex < _currentBook!.chapters.length - 1;
  }

  bool get hasPreviousChapter {
    return _currentChapterIndex > 0;
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerStateChanged);
    super.dispose();
  }
}