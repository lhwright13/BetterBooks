import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/api/api_client.dart';
import '../../data/models/book_models.dart';
import 'player/full_player_screen.dart';

class EnhancedBookDetailsScreen extends StatefulWidget {
  final String bookId;
  
  const EnhancedBookDetailsScreen({
    super.key,
    required this.bookId,
  });

  @override
  State<EnhancedBookDetailsScreen> createState() => _EnhancedBookDetailsScreenState();
}

class _EnhancedBookDetailsScreenState extends State<EnhancedBookDetailsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DetailedBook? _book;
  List<dynamic> _personas = [];
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  bool _isPurchased = false;
  bool _isWishlisted = false;
  bool _isDownloaded = false;
  bool _isPreviewing = false;
  String? _error;

  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadBookDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final book = await ApiClient.getBookDetails(widget.bookId);
      
      // Simulate loading reviews (mock data for MVP)
      final reviews = _generateMockReviews();
      
      setState(() {
        _book = book;
        _personas = []; // TODO: Add personas API call when implemented
        _reviews = reviews;
        _isLoading = false;
        // TODO: Check actual purchase/wishlist status from API
        _isPurchased = false;
        _isWishlisted = false;
        _isDownloaded = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> _generateMockReviews() {
    return [
      {
        'id': '1',
        'user_name': 'Sarah K.',
        'rating': 5,
        'text': 'Absolutely loved this book! The AI persona made it feel like I was having a conversation with the characters.',
        'date': '2 days ago',
      },
      {
        'id': '2',
        'user_name': 'Mike R.',
        'rating': 4,
        'text': 'Great narration and the AI integration is revolutionary. Changed how I experience audiobooks.',
        'date': '1 week ago',
      },
      {
        'id': '3',
        'user_name': 'Emma L.',
        'rating': 5,
        'text': 'The character interactions through AI are incredible. It\'s like having a book club in your headphones.',
        'date': '2 weeks ago',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading ? _buildLoadingState() : _buildContent(),
      bottomNavigationBar: !_isLoading && _book != null ? _buildBottomActions() : null,
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
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
            Text('Error loading book details'),
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

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        _buildSliverAppBar(),
      ],
      body: Column(
        children: [
          _buildBookInfo(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPersonasTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      actions: [
        IconButton(
          onPressed: _toggleWishlist,
          icon: Icon(
            _isWishlisted ? Icons.favorite : Icons.favorite_border,
            color: _isWishlisted ? Colors.red : null,
          ),
        ),
        IconButton(
          onPressed: _shareBook,
          icon: const Icon(Icons.share),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
                Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: 40,
                left: 24,
                right: 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Book cover
                    Container(
                      width: 120,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: _book!.coverImageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _book!.coverImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 60),
                              ),
                            )
                          : const Icon(Icons.book, size: 60),
                    ),
                    const SizedBox(width: 16),
                    
                    // Book info overlay
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _book!.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _book!.author,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating and metadata
          Row(
            children: [
              _buildRatingStars(4.8),
              const SizedBox(width: 8),
              Text(
                '4.8 (2,431 reviews)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Metadata row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildMetadataChip('Length', '7h 23m'),
              _buildMetadataChip('Release Date', '2024'),
              _buildMetadataChip('Language', 'English'),
              if (_book!.chapters.isNotEmpty)
                _buildMetadataChip('Chapters', '${_book!.chapters.length}'),
            ],
          ),
          const SizedBox(height: 16),

          // Preview button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _togglePreview,
              icon: Icon(_isPreviewing ? Icons.stop : Icons.play_arrow),
              label: Text(_isPreviewing ? 'Stop Preview' : 'Play Preview'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star : 
          index < rating ? Icons.star_half : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  Widget _buildMetadataChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 12,
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'AI Personas'),
          Tab(text: 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (_book!.description != null) ...[
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _book!.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
          ],

          // Chapters
          if (_book!.chapters.isNotEmpty) ...[
            Text(
              'Chapters (${_book!.chapters.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _book!.chapters.length > 5 ? 5 : _book!.chapters.length,
              itemBuilder: (context, index) {
                final chapter = _book!.chapters[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      '${chapter.chapterNumber}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: chapter.duration != null 
                      ? Text('${(chapter.duration! / 60).round()} minutes')
                      : null,
                  trailing: IconButton(
                    onPressed: () => _playChapterPreview(chapter),
                    icon: const Icon(Icons.play_arrow),
                  ),
                );
              },
            ),
            if (_book!.chapters.length > 5) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showAllChapters(),
                child: Text('View all ${_book!.chapters.length} chapters'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPersonasTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Personas for this Book',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Chat with book characters and get insights while you listen',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          if (_personas.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.chat,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI Personas Coming Soon',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re working on creating AI personas for this book. Check back soon!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                childAspectRatio: 3,
                mainAxisSpacing: 16,
              ),
              itemCount: _personas.length,
              itemBuilder: (context, index) {
                final persona = _personas[index];
                return _buildPersonaCard(persona);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonaCard(dynamic persona) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona['display_name'] ?? persona['name'] ?? 'Unknown',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (persona['description'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      persona['description'],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                _buildRatingStars(4.6),
                const SizedBox(height: 4),
                Text(
                  '4.6',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall rating
          Row(
            children: [
              Text(
                '4.8',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRatingStars(4.8),
                    const SizedBox(height: 4),
                    Text(
                      '2,431 reviews',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _writeReview,
                child: const Text('Write Review'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Reviews list
          Text(
            'Recent Reviews',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            itemBuilder: (context, index) {
              final review = _reviews[index];
              return _buildReviewCard(review);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(dynamic review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  review['user_name'],
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildRatingStars(review['rating'].toDouble()),
                const SizedBox(width: 8),
                Text(
                  review['date'],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review['text'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          if (_isPurchased) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startListening,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Listen Now'),
              ),
            ),
            const SizedBox(width: 12),
            _buildDownloadButton(),
          ] else ...[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _purchaseBook,
                    icon: const Icon(Icons.star),
                    label: const Text('Buy with 1 Credit'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Or buy for \$12.99',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadButton() {
    return IconButton.filled(
      onPressed: _toggleDownload,
      icon: Icon(
        _isDownloaded ? Icons.download_done : Icons.download,
      ),
      tooltip: _isDownloaded ? 'Downloaded' : 'Download for offline',
    );
  }

  Future<void> _togglePreview() async {
    if (_isPreviewing) {
      await _previewPlayer.stop();
      setState(() => _isPreviewing = false);
    } else {
      // TODO: Play actual preview audio
      setState(() => _isPreviewing = true);
      // Simulate preview duration
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() => _isPreviewing = false);
        }
      });
    }
  }

  void _playChapterPreview(Chapter chapter) {
    // TODO: Implement chapter preview playback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing preview of "${chapter.title}"'),
        action: SnackBarAction(
          label: 'Stop',
          onPressed: () {},
        ),
      ),
    );
  }

  void _showAllChapters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All Chapters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _book!.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = _book!.chapters[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          '${chapter.chapterNumber}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(chapter.title),
                      subtitle: chapter.duration != null 
                          ? Text('${(chapter.duration! / 60).round()} minutes')
                          : null,
                      trailing: IconButton(
                        onPressed: () => _playChapterPreview(chapter),
                        icon: const Icon(Icons.play_arrow),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleWishlist() async {
    setState(() => _isWishlisted = !_isWishlisted);
    
    // TODO: Call API to add/remove from wishlist
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isWishlisted ? 'Added to wishlist' : 'Removed from wishlist',
        ),
      ),
    );
  }

  void _shareBook() {
    Share.share(
      'Check out "${_book!.title}" by ${_book!.author} on EchoWright!',
      subject: _book!.title,
    );
  }

  Future<void> _purchaseBook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purchase "${_book!.title}"?'),
            const SizedBox(height: 16),
            Text(
              'This will use 1 credit from your account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement actual purchase logic
      setState(() => _isPurchased = true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Book purchased successfully!'),
        ),
      );
    }
  }

  Future<void> _toggleDownload() async {
    if (_isDownloaded) {
      setState(() => _isDownloaded = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download removed')),
      );
    } else {
      setState(() => _isDownloaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started')),
      );
      // TODO: Implement actual download logic
    }
  }

  void _startListening() {
    if (_book == null) return;
    
    // Convert DetailedBook to BrowseBook for the player
    final browseBook = BrowseBook(
      id: _book!.id,
      title: _book!.title,
      author: _book!.author,
      coverImageUrl: _book!.coverImageUrl,
      priceUsd: 9.99, // Default price
      creditPrice: 1, // Default credit price
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullPlayerScreen(book: browseBook),
        fullscreenDialog: true,
      ),
    );
  }

  void _writeReview() {
    // TODO: Implement review writing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review functionality coming soon!')),
    );
  }
}