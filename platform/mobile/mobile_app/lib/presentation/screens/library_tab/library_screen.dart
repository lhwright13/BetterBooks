import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../data/api/api_client.dart';
import '../../../data/models/book_models.dart';
import '../../../services/download_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/navigation_service.dart';
import '../../widgets/cloud_badge.dart';
import '../../widgets/download_button.dart';
import '../book_details_screen.dart';
import '../player/mini_player.dart';
import '../player/full_player_screen.dart';

enum LibraryView { all, collections, finished, notStarted, downloaded }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<BrowseBook> _allBooks = [];
  List<BrowseBook> _finishedBooks = [];
  List<BrowseBook> _notStartedBooks = [];
  bool _isLoading = false;
  bool _isGridView = false;
  final Map<String, bool> _downloadingBooks = {};
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeDownloadService();
    _loadLibraryData();
  }
  
  Future<void> _initializeDownloadService() async {
    await DownloadService.instance.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryData() async {
    setState(() => _isLoading = true);
    
    try {
      // Check authentication first
      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        setState(() {
          _allBooks = [];
          _isLoading = false;
        });
        return;
      }
      
      // Make authenticated request with automatic token refresh
      final response = await AuthService.makeAuthenticatedRequest(
        () => ApiClient.getUserLibrary(),
      );
      
      // Update books with download status
      final updatedBooks = <BrowseBook>[];
      for (final book in response.books) {
        final isDownloaded = await DownloadService.instance.isBookDownloaded(book.id);
        updatedBooks.add(book.copyWith(
          isPurchased: true, // Books in library are purchased
          isDownloaded: isDownloaded,
        ));
      }
      
      setState(() {
        _allBooks = updatedBooks;
        // Filter books by reading status (this would come from backend in real app)
        _finishedBooks = _allBooks.where((book) => _getBookProgress(book.id) >= 1.0).toList();
        _notStartedBooks = _allBooks.where((book) => _getBookProgress(book.id) <= 0.0).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load library: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchInLibrary,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showLibraryOptions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Collections'), 
            Tab(text: 'Finished'),
            Tab(text: 'Not Started'),
            Tab(text: 'Downloaded'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllBooksTab(),
                _buildCollectionsTab(),
                _buildFinishedTab(),
                _buildNotStartedTab(),
                _buildDownloadedTab(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildAllBooksTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allBooks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.library_books,
        title: 'Your library is empty',
        subtitle: 'Browse the store to add books to your library',
        actionText: 'Browse Books',
        onAction: () {
          NavigationService.goToDiscover();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: _isGridView
          ? _buildBooksGrid(_allBooks)
          : _buildBooksList(_allBooks),
    );
  }

  Widget _buildCollectionsTab() {
    // Real collections based on library data
    final collections = [
      {
        'name': 'Currently Reading', 
        'count': _allBooks.where((book) => _getBookProgress(book.id) > 0.0 && _getBookProgress(book.id) < 1.0).length, 
        'icon': Icons.play_arrow
      },
      {
        'name': 'Finished', 
        'count': _finishedBooks.length, 
        'icon': Icons.check_circle
      },
      {
        'name': 'Not Started', 
        'count': _notStartedBooks.length, 
        'icon': Icons.bookmark
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            title: const Text('Create New Collection'),
            subtitle: const Text('Organize your books'),
            onTap: _createNewCollection,
          ),
        ),
        const SizedBox(height: 16),
        ...collections.map((collection) => Card(
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                collection['icon'] as IconData,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(collection['name'] as String),
            subtitle: Text('${collection['count']} books'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openCollection(collection['name'] as String),
          ),
        )),
      ],
    );
  }

  Widget _buildFinishedTab() {
    if (_finishedBooks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No finished books',
        subtitle: 'Books you\'ve completed will appear here',
      );
    }

    return _isGridView
        ? _buildBooksGrid(_finishedBooks)
        : _buildBooksList(_finishedBooks);
  }

  Widget _buildNotStartedTab() {
    if (_notStartedBooks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.radio_button_unchecked,
        title: 'No unstarted books',
        subtitle: 'Books you haven\'t started will appear here',
      );
    }

    return _isGridView
        ? _buildBooksGrid(_notStartedBooks)
        : _buildBooksList(_notStartedBooks);
  }

  Widget _buildDownloadedTab() {
    // Filter for downloaded books (would be tracked in real app)
    final downloadedBooks = _allBooks.where((book) => _isBookDownloaded(book.id)).toList();
    
    if (downloadedBooks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.download,
        title: 'No downloaded books',
        subtitle: 'Download books for offline listening',
      );
    }
    
    return _isGridView
        ? _buildBooksGrid(downloadedBooks)
        : _buildBooksList(downloadedBooks);
  }

  Widget _buildBooksGrid(List<BrowseBook> books) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookGridCard(book);
      },
    );
  }

  Widget _buildBooksList(List<BrowseBook> books) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookListCard(book);
      },
    );
  }

  Widget _buildBookGridCard(BrowseBook book) {
    final isDownloading = _downloadingBooks[book.id] ?? false;
    final downloadProgress = _downloadProgress[book.id] ?? 0.0;
    
    return Card(
      child: InkWell(
        onTap: () => _navigateToBook(book.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  _buildBookCover(
                    book.coverImageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 12,
                    topOnly: true,
                    bookTitle: book.title,
                    bookAuthor: book.author,
                  ),
                  // Show cloud badge if purchased but not downloaded
                  CloudBadge(
                    isVisible: book.isPurchased && !book.isDownloaded && !isDownloading,
                  ),
                  // Show download button in top-right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DownloadButton(
                      isDownloading: isDownloading,
                      isDownloaded: book.isDownloaded,
                      downloadProgress: downloadProgress,
                      showLabel: false,
                      onDownload: () => _downloadBook(book),
                      onPlay: () => _playBook(book),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookListCard(BrowseBook book) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildBookCover(
          book.coverImageUrl,
          width: 48,
          height: 64,
          borderRadius: 4,
          bookTitle: book.title,
          bookAuthor: book.author,
        ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.author),
            const SizedBox(height: 4),
            // Progress indicator
            LinearProgressIndicator(value: _getBookProgress(book.id)), // Varied progress
            const SizedBox(height: 2),
            Text(
              '${(_getBookProgress(book.id) * 100).round()}% complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [Icon(Icons.play_arrow), SizedBox(width: 8), Text('Play')],
              ),
            ),
            const PopupMenuItem(
              value: 'download',
              child: Row(
                children: [Icon(Icons.download), SizedBox(width: 8), Text('Download')],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [Icon(Icons.remove_circle_outline), SizedBox(width: 8), Text('Remove')],
              ),
            ),
          ],
          onSelected: (value) => _handleBookAction(book, value.toString()),
        ),
        onTap: () => _navigateToBook(book.id),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionText),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToBook(String bookId) {
    // Find the book in the library
    final book = _allBooks.firstWhere(
      (book) => book.id == bookId,
      orElse: () => throw StateError('Book not found in library'),
    );
    
    debugPrint('📖 Library book tapped: ${book.title} - isPurchased: ${book.isPurchased}, isDownloaded: ${book.isDownloaded}');
    
    // Since this is the library, all books should be purchased
    // Navigate to player if purchased, otherwise to book details
    if (book.isPurchased) {
      debugPrint('🎵 Navigating to player for purchased book');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullPlayerScreen(book: book),
        ),
      );
    } else {
      debugPrint('🛍️ Navigating to book details for unpurchased book');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookDetailsScreen(bookId: bookId),
        ),
      );
    }
  }

  void _handleBookAction(BrowseBook book, String action) {
    switch (action) {
      case 'play':
        _playBook(book);
        break;
      case 'download':
        _downloadBook(book);
        break;
      case 'remove':
        _removeFromLibrary(book);
        break;
    }
  }
  
  void _playBook(BrowseBook book) {
    debugPrint('▶️ Playing book: ${book.title}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullPlayerScreen(book: book),
      ),
    );
  }
  
  Future<void> _downloadBook(BrowseBook book) async {
    if (!book.isPurchased) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must purchase this book first')),
      );
      return;
    }
    
    setState(() {
      _downloadingBooks[book.id] = true;
      _downloadProgress[book.id] = 0.0;
    });
    
    try {
      // Listen to download progress
      final progressStream = DownloadService.instance.getDownloadProgress(book.id);
      progressStream?.listen(
        (progress) {
          setState(() {
            _downloadProgress[book.id] = progress;
          });
        },
        onDone: () {
          setState(() {
            _downloadingBooks[book.id] = false;
            // Update book in list to reflect downloaded status
            final index = _allBooks.indexWhere((b) => b.id == book.id);
            if (index != -1) {
              _allBooks[index] = _allBooks[index].copyWith(isDownloaded: true);
            }
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${book.title} downloaded successfully!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
        },
        onError: (error) {
          setState(() {
            _downloadingBooks[book.id] = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: $error'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
      );
      
      // Start download
      await DownloadService.instance.downloadBook(book);
      
    } catch (e) {
      setState(() {
        _downloadingBooks[book.id] = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  
  void _removeFromLibrary(BrowseBook book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Library'),
        content: Text('Are you sure you want to remove "${book.title}" from your library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call API to remove book from library
              setState(() {
                _allBooks.remove(book);
                _finishedBooks.remove(book);
                _notStartedBooks.remove(book);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed ${book.title} from library')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSearchInLibrary() {
    // TODO: Implement library search
    debugPrint('Search in library');
  }

  void _showLibraryOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sort),
              title: const Text('Sort'),
              onTap: () {
                Navigator.pop(context);
                _showSortOptions();
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_list),
              title: const Text('Filter'),
              onTap: () {
                Navigator.pop(context);
                _showFilterOptions();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    // TODO: Implement sort options
  }

  void _showFilterOptions() {
    // TODO: Implement filter options
  }

  void _showAddToLibraryOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.explore),
              title: const Text('Browse Store'),
              onTap: () {
                Navigator.pop(context);
                NavigationService.goToDiscover();
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('View Wishlist'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to wishlist
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createNewCollection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Collection'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: 'Collection name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Create collection
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openCollection(String collectionName) {
    // TODO: Navigate to collection detail screen
    debugPrint('Open collection: $collectionName');
  }

  /// Get book reading progress (would come from backend in real app)
  double _getBookProgress(String bookId) {
    // TODO: Get actual progress from backend/local storage
    final hash = bookId.hashCode.abs();
    final progressValues = [0.0, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95, 1.0];
    return progressValues[hash % progressValues.length];
  }
  
  /// Check if book is downloaded (would be tracked in real app)
  bool _isBookDownloaded(String bookId) {
    // TODO: Check actual download status from local storage
    final hash = bookId.hashCode.abs();
    return hash % 4 == 0; // Mock: ~25% of books are downloaded
  }

  Widget _buildBookCover(
    String? imageUrl, {
    double? width,
    double? height,
    double borderRadius = 8,
    bool topOnly = false,
    String? bookTitle,
    String? bookAuthor,
  }) {
    final effectiveWidth = width ?? double.infinity;
    final effectiveHeight = height ?? double.infinity;
    
    final borderRadiusGeometry = topOnly
        ? BorderRadius.vertical(top: Radius.circular(borderRadius))
        : BorderRadius.circular(borderRadius);

    // Enhanced fallback widget with yellow theme
    final fallbackWidget = Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: borderRadiusGeometry,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: width != null && width < 80 ? 20 : 32,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
          ),
          if (width == null || width >= 80) ...[ 
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                bookTitle ?? 'Book Cover',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );

    // Generate OpenLibrary cover URL as fallback
    String? openLibraryUrl;
    if (bookTitle != null) {
      openLibraryUrl = 'https://covers.openlibrary.org/b/title/${bookTitle.toLowerCase().replaceAll(' ', '_')}-M.jpg';
    }

    // Primary image URL (from API) - convert relative to absolute
    String? primaryUrl;
    if (imageUrl?.isNotEmpty == true) {
      if (imageUrl!.startsWith('http')) {
        primaryUrl = imageUrl;
      } else {
        // Convert relative path to absolute URL
        primaryUrl = 'http://128.203.92.141:8000$imageUrl';
      }
    }
    
    // Try primary URL first, then OpenLibrary, then fallback
    final urlsToTry = [
      if (primaryUrl != null) primaryUrl,
      if (openLibraryUrl != null) openLibraryUrl,
    ];

    if (urlsToTry.isEmpty) {
      return fallbackWidget;
    }

    return ClipRRect(
      borderRadius: borderRadiusGeometry,
      child: CachedNetworkImage(
        imageUrl: urlsToTry.first,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          child: Container(
            width: effectiveWidth,
            height: effectiveHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: borderRadiusGeometry,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          // If primary URL fails, try OpenLibrary
          if (urlsToTry.length > 1 && url == urlsToTry.first) {
            return CachedNetworkImage(
              imageUrl: urlsToTry[1],
              width: effectiveWidth,
              height: effectiveHeight,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: Container(
                  width: effectiveWidth,
                  height: effectiveHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: borderRadiusGeometry,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => fallbackWidget,
            );
          }
          return fallbackWidget;
        },
      ),
    );
  }
}