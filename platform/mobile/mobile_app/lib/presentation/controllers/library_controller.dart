import '../../data/repositories/library_repository.dart';
import '../../data/models/book_models.dart';
import 'base_controller.dart';

enum LibraryFilter {
  all,
  inProgress,
  completed,
  downloaded,
}

enum LibrarySortBy {
  title,
  author,
  recentlyAdded,
  lastPlayed,
  progress,
}

class LibraryController extends BaseController {
  final LibraryRepository _libraryRepository;
  
  List<BrowseBook> _allBooks = [];
  List<BrowseBook> _filteredBooks = [];
  LibraryFilter _currentFilter = LibraryFilter.all;
  LibrarySortBy _currentSort = LibrarySortBy.recentlyAdded;
  String _searchQuery = '';

  LibraryController(this._libraryRepository);

  List<BrowseBook> get books => _filteredBooks;
  LibraryFilter get currentFilter => _currentFilter;
  LibrarySortBy get currentSort => _currentSort;
  String get searchQuery => _searchQuery;
  
  bool get hasBooks => _allBooks.isNotEmpty;
  int get totalBooks => _allBooks.length;
  int get inProgressBooks => _allBooks.where((book) => book.downloadProgress > 0 && book.downloadProgress < 1.0).length;
  int get completedBooks => _allBooks.where((book) => book.downloadProgress >= 1.0).length;
  int get downloadedBooks => _allBooks.where((book) => book.isDownloaded).length;

  Future<void> loadLibrary() async {
    return handleAsyncOperation(
      () async {
        logInfo('Loading user library');
        
        _allBooks = await _libraryRepository.getUserLibrary();
        _applyFiltersAndSort();
        
        logInfo('Library loaded: ${_allBooks.length} books');
      },
      errorMessage: 'Failed to load your library. Please try again.',
    );
  }

  Future<void> refreshLibrary() async {
    clearError();
    return loadLibrary();
  }

  void setFilter(LibraryFilter filter) {
    if (_currentFilter != filter) {
      logInfo('Changing library filter to: ${filter.name}');
      _currentFilter = filter;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  void setSortBy(LibrarySortBy sortBy) {
    if (_currentSort != sortBy) {
      logInfo('Changing library sort to: ${sortBy.name}');
      _currentSort = sortBy;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      logInfo('Searching library with query: "$query"');
      _searchQuery = query.trim().toLowerCase();
      _applyFiltersAndSort();
      notifyListeners();
    }
  }

  void clearSearch() {
    setSearchQuery('');
  }

  void _applyFiltersAndSort() {
    List<BrowseBook> filtered = List.from(_allBooks);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((book) =>
        book.title.toLowerCase().contains(_searchQuery) ||
        book.author.toLowerCase().contains(_searchQuery)
      ).toList();
    }
    
    // Apply status filter
    switch (_currentFilter) {
      case LibraryFilter.inProgress:
        filtered = filtered.where((book) => book.downloadProgress > 0 && book.downloadProgress < 1.0).toList();
        break;
      case LibraryFilter.completed:
        filtered = filtered.where((book) => book.downloadProgress >= 1.0).toList();
        break;
      case LibraryFilter.downloaded:
        filtered = filtered.where((book) => book.isDownloaded).toList();
        break;
      case LibraryFilter.all:
        // No additional filtering needed
        break;
    }
    
    // Apply sorting
    switch (_currentSort) {
      case LibrarySortBy.title:
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case LibrarySortBy.author:
        filtered.sort((a, b) => a.author.compareTo(b.author));
        break;
      case LibrarySortBy.recentlyAdded:
        filtered.sort((a, b) => b.id.compareTo(a.id)); // Assuming newer books have higher IDs
        break;
      case LibrarySortBy.lastPlayed:
        filtered.sort((a, b) => b.downloadProgress.compareTo(a.downloadProgress)); // Sort by progress as proxy for last played
        break;
      case LibrarySortBy.progress:
        filtered.sort((a, b) => b.downloadProgress.compareTo(a.downloadProgress));
        break;
    }
    
    _filteredBooks = filtered;
  }

  Future<void> updateBookProgress(String bookId, double progress) async {
    return handleAsyncOperation(
      () async {
        await _libraryRepository.updateBookProgress(bookId, (progress * 100).toInt());
        
        // Update local state  
        final bookIndex = _allBooks.indexWhere((book) => book.id == bookId);
        if (bookIndex != -1) {
          _allBooks[bookIndex] = _allBooks[bookIndex].copyWith(downloadProgress: progress);
          _applyFiltersAndSort();
          notifyListeners();
        }
      },
      showLoading: false,
      errorMessage: 'Failed to update book progress.',
    );
  }

  BrowseBook? findBookById(String bookId) {
    try {
      return _allBooks.firstWhere((book) => book.id == bookId);
    } catch (e) {
      return null;
    }
  }

  List<BrowseBook> getRecentBooks({int limit = 5}) {
    return _allBooks.take(limit).toList();
  }

  Map<String, int> getLibraryStats() {
    return {
      'total': totalBooks,
      'inProgress': inProgressBooks,
      'completed': completedBooks,
      'downloaded': downloadedBooks,
    };
  }
}