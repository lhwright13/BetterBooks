import 'package:flutter/material.dart';
import '../../data/api/api_client.dart';
import '../../data/models/book_models.dart';
import '../../services/download_service.dart';
import '../../services/auth_service.dart';

class BookDetailsScreen extends StatefulWidget {
  final String bookId;
  
  const BookDetailsScreen({
    super.key,
    required this.bookId,
  });

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> 
    with WidgetsBindingObserver {
  DetailedBook? _book;
  bool _isLoading = true;
  String? _error;
  bool _isPurchasing = false;
  bool _isDownloading = false;
  bool _isBookPurchased = false;
  bool _isBookDownloaded = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBookDetails();
    _checkBookStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh book status when app comes back to foreground
      _checkBookStatus();
    }
  }

  Future<void> _loadBookDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final book = await ApiClient.getBookDetails(widget.bookId);
      setState(() {
        _book = book;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.title ?? 'Book Details'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBookDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_book == null) {
      return const Center(child: Text('Book not found'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadBookDetails(),
          _checkBookStatus(),
        ]);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(), // Enables pull-to-refresh
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookHeader(),
            const SizedBox(height: 24),
            _buildDescription(),
            const SizedBox(height: 24),
            _buildChapters(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: _book!.coverImageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _book!.coverImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 60),
                  ),
                )
              : const Icon(Icons.book, size: 60),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _book!.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _book!.author,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildActionButton(),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    onPressed: _addToWishlist,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    if (_book!.description == null || _book!.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(_book!.description!),
      ],
    );
  }

  Widget _buildChapters() {
    if (_book!.chapters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chapters (${_book!.chapters.length})',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _book!.chapters.length,
          itemBuilder: (context, index) {
            final chapter = _book!.chapters[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text('${chapter.chapterNumber}'),
              ),
              title: Text(chapter.title),
              subtitle: chapter.duration != null
                  ? Text('${chapter.duration! ~/ 60} minutes')
                  : null,
              onTap: () => _playChapter(chapter),
            );
          },
        ),
      ],
    );
  }

  Future<void> _checkBookStatus() async {
    try {
      // Check if book is downloaded
      final isDownloaded = await DownloadService.instance.isBookDownloaded(widget.bookId);
      
      // Check if book is purchased by getting user's library
      bool isPurchased = false;
      try {
        final userLibrary = await AuthService.makeAuthenticatedRequest(
          () => ApiClient.getUserLibrary(),
        );
        
        // Check if this book is in the user's library
        isPurchased = userLibrary.books.any((book) => book.id == widget.bookId);
        debugPrint('📚 Book ${widget.bookId} purchase status: $isPurchased (found in library: ${userLibrary.books.length} books)');
      } catch (e) {
        debugPrint('❌ Failed to check purchase status: $e');
        // Fallback: if downloaded, assume purchased
        isPurchased = isDownloaded;
      }
      
      setState(() {
        _isBookDownloaded = isDownloaded;
        _isBookPurchased = isPurchased;
      });
      
      debugPrint('📊 Book status updated - Downloaded: $isDownloaded, Purchased: $isPurchased');
    } catch (e) {
      debugPrint('Error checking book status: $e');
    }
  }
  
  Widget _buildActionButton() {
    if (_isDownloading) {
      return SizedBox(
        width: 120,
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_downloadProgress * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    
    if (_isBookDownloaded) {
      return ElevatedButton.icon(
        onPressed: _playBook,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Listen Now'),
      );
    }
    
    if (_isBookPurchased) {
      return ElevatedButton.icon(
        onPressed: _downloadBook,
        icon: const Icon(Icons.download),
        label: const Text('Download'),
      );
    }
    
    debugPrint('🔘 Rendering purchase button - isPurchasing: $_isPurchasing, isBookPurchased: $_isBookPurchased, isBookDownloaded: $_isBookDownloaded');
    
    return ElevatedButton(
      onPressed: _isPurchasing ? null : () {
        debugPrint('🔘 Purchase button tapped!');
        _purchaseBook();
      },
      child: _isPurchasing 
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text('Purchase (${_book?.chapters.isNotEmpty == true ? '1 credit' : '1 credit'})'),
    );
  }
  
  Future<void> _purchaseBook() async {
    debugPrint('🛒 Purchase button pressed for book ID: ${widget.bookId}');
    
    setState(() {
      _isPurchasing = true;
    });
    
    try {
      debugPrint('🔐 Checking authentication...');
      // Check authentication first
      final isAuth = await AuthService.isAuthenticated();
      debugPrint('🔐 Authentication status: $isAuth');
      
      if (!isAuth) {
        throw Exception('Please log in to purchase books');
      }
      
      debugPrint('🌐 Making purchase API call...');
      // Make authenticated purchase request with automatic token refresh
      final response = await AuthService.makeAuthenticatedRequest(
        () => ApiClient.purchaseBook(widget.bookId),
      );
      
      debugPrint('📦 Purchase API response: ${response.success ? 'SUCCESS' : 'FAILED'}');
      debugPrint('📦 Response message: ${response.message}');
      
      if (response.success) {
        debugPrint('✅ Purchase successful, updating UI state');
        setState(() {
          _isBookPurchased = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        debugPrint('❌ Purchase failed: ${response.message}');
        throw Exception(response.message);
      }
    } catch (e) {
      debugPrint('💥 Purchase error occurred: $e');
      
      // If error indicates book is already owned, refresh the book status
      if (e.toString().contains('already owned') || 
          e.toString().contains('already purchased') ||
          e.toString().contains('Book already owned')) {
        debugPrint('🔄 Book already owned - refreshing status...');
        await _checkBookStatus(); // Refresh the purchase status
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Good news! You already own this book'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              action: SnackBarAction(
                label: _isBookDownloaded ? 'Listen Now' : 'Download',
                onPressed: _isBookDownloaded ? _playBook : _downloadBook,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } finally {
      debugPrint('🏁 Purchase process complete, resetting loading state');
      setState(() {
        _isPurchasing = false;
      });
    }
  }
  
  Future<void> _downloadBook() async {
    if (_book == null) return;
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    
    try {
      // Create a BrowseBook from DetailedBook for download
      final browseBook = BrowseBook(
        id: _book!.id,
        title: _book!.title,
        author: _book!.author,
        coverImageUrl: _book!.coverImageUrl,
        audioUrl: _book!.chapters.isNotEmpty ? _book!.chapters.first.audioUrl : null,
        isPurchased: true,
      );
      
      // Listen to download progress
      final progressStream = DownloadService.instance.getDownloadProgress(_book!.id);
      progressStream?.listen(
        (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
        onDone: () {
          setState(() {
            _isDownloading = false;
            _isBookDownloaded = true;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_book!.title} downloaded successfully!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
        },
        onError: (error) {
          setState(() {
            _isDownloading = false;
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
      await DownloadService.instance.downloadBook(browseBook);
      
    } catch (e) {
      setState(() {
        _isDownloading = false;
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
  
  void _playBook() {
    // TODO: Implement audio player navigation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio player coming soon...')),
    );
  }

  void _addToWishlist() async {
    try {
      await ApiClient.addToWishlist(widget.bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to wishlist!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to wishlist: $e')),
        );
      }
    }
  }

  void _playChapter(Chapter chapter) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audio player coming soon...')),
    );
  }
}