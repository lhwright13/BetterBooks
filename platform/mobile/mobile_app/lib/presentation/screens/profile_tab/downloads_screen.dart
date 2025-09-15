import 'package:flutter/material.dart';
import '../../../services/download_service.dart';
import '../../../data/api/api_client.dart';
import '../../../data/models/book_models.dart';
import '../../widgets/enhanced_book_card.dart';
import '../player/mini_player.dart';
import '../player/full_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<String> _downloadedBookIds = [];
  List<BrowseBook> _downloadedBooks = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _loadDownloadedBooks();
  }

  Future<void> _loadDownloadedBooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get downloaded book IDs from DownloadService
      final bookIds = await DownloadService.instance.getDownloadedBookIds();
      final totalSize = await DownloadService.instance.getTotalDownloadSize();

      // Get book details for each downloaded book
      final books = <BrowseBook>[];
      for (final bookId in bookIds) {
        try {
          // Get book details from API
          final detailedBook = await ApiClient.getBookDetails(bookId);
          
          // Convert to BrowseBook for display
          final browseBook = BrowseBook(
            id: detailedBook.id,
            title: detailedBook.title,
            author: detailedBook.author,
            coverImageUrl: detailedBook.coverImageUrl,
            audioUrl: null, // Downloaded books have local audio
            priceUsd: 0.0, // Downloaded books already purchased
            creditPrice: 1, // Default credit price
            isFeatured: false,
            isBestseller: false,
            isNewRelease: false,
            isPurchased: true, // Downloaded books are purchased
            isDownloaded: true,
            downloadProgress: 1.0,
            chapters: detailedBook.chapters,
          );
          
          books.add(browseBook);
        } catch (e) {
          debugPrint('Failed to load details for book $bookId: $e');
          // Skip this book if we can't load its details
          continue;
        }
      }

      setState(() {
        _downloadedBookIds = bookIds;
        _downloadedBooks = books;
        _totalSize = totalSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _deleteDownload(BrowseBook book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "${book.title}"? This will free up storage space but you\'ll need to download it again to listen offline.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DownloadService.instance.deleteDownload(book.id);
        
        setState(() {
          _downloadedBooks.removeWhere((b) => b.id == book.id);
          _downloadedBookIds.remove(book.id);
        });

        // Refresh total size
        final newTotalSize = await DownloadService.instance.getTotalDownloadSize();
        setState(() {
          _totalSize = newTotalSize;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${book.title}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete download: $e')),
          );
        }
      }
    }
  }

  void _playBook(BrowseBook book) async {
    try {
      // Get the downloaded file path
      final filePath = await DownloadService.instance.getDownloadedFilePath(book.id);
      
      if (filePath != null) {
        // Convert BrowseBook to DetailedBook for the player
        final detailedBook = DetailedBook(
          id: book.id,
          title: book.title,
          author: book.author,
          coverImageUrl: book.coverImageUrl,
          audioUrl: filePath, // Use local file path
          totalDuration: null, // BrowseBook doesn't have duration info
          description: null, // BrowseBook doesn't have description
          priceUsd: book.priceUsd,
          chapters: book.chapters,
          reviews: [],
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullPlayerScreen(book: detailedBook.toBrowseBook()),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloaded file not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play book: $e')),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Books'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloadedBooks,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isLoading && _totalSize > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.storage,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage Used',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '${_formatFileSize(_totalSize)} • ${_downloadedBooks.length} books',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildContent(),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading downloads...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load downloads',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDownloadedBooks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_downloadedBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Downloaded Books',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Download books to listen offline',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Browse Library'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _downloadedBooks.length,
      itemBuilder: (context, index) {
        final book = _downloadedBooks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: SizedBox(
              width: 56,
              height: 84,
              child: EnhancedBookCard(book: book),
            ),
            title: Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.author),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.download_done,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Downloaded',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'play') {
                  _playBook(book);
                } else if (value == 'delete') {
                  _deleteDownload(book);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'play',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow),
                      SizedBox(width: 8),
                      Text('Play'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _playBook(book),
          ),
        );
      },
    );
  }
}