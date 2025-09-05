import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../data/api/api_client.dart';
import '../../../data/models/book_models.dart';
import '../book_details_screen.dart';
import '../player/mini_player.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<BrowseBook> _searchResults = [];
  List<BrowseBook> _bestsellerBooks = [];
  List<BrowseBook> _newReleaseBooks = [];
  List<BrowseBook> _plusCatalogBooks = [];
  
  bool _isSearching = false;
  bool _isLoadingBestsellers = false;
  bool _isLoadingNewReleases = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDiscoverData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscoverData() async {
    setState(() {
      _isLoadingBestsellers = true;
      _isLoadingNewReleases = true;
    });

    try {
      final [bestsellers, newReleases] = await Future.wait([
        ApiClient.getBestsellingBooks(limit: 20),
        ApiClient.browseBooks(limit: 20),
      ]);

      setState(() {
        _bestsellerBooks = bestsellers.books;
        _newReleaseBooks = newReleases.books;
        _plusCatalogBooks = newReleases.books.take(10).toList();
        _isLoadingBestsellers = false;
        _isLoadingNewReleases = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBestsellers = false;
        _isLoadingNewReleases = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await ApiClient.searchBooks(query: query, limit: 20);
      setState(() {
        _searchResults = response.books;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Custom app bar with search
          Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Column(
              children: [
                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search books, authors, narrators...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.mic),
                              onPressed: _voiceSearch,
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: _performSearch,
                    onSubmitted: _performSearch,
                  ),
                ),
                const SizedBox(height: 8),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Browse'),
                    Tab(text: 'Bestsellers'),
                    Tab(text: 'New Releases'),
                    Tab(text: 'Plus'),
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBrowseTab(),
                      _buildBestsellersTab(),
                      _buildNewReleasesTab(),
                      _buildPlusCatalogTab(),
                    ],
                  ),
          ),
          
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _buildSearchResultCard(book);
      },
    );
  }

  Widget _buildSearchResultCard(BrowseBook book) {
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
            if (book.creditPrice > 0)
              Text(
                '${book.creditPrice} credit${book.creditPrice > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToBookDetails(book.id),
      ),
    );
  }

  Widget _buildBrowseTab() {
    final categories = [
      {'name': 'Fiction', 'icon': Icons.auto_stories, 'color': Colors.blue},
      {'name': 'Mystery & Thriller', 'icon': Icons.search, 'color': Colors.purple},
      {'name': 'Romance', 'icon': Icons.favorite, 'color': Colors.pink},
      {'name': 'Science Fiction', 'icon': Icons.rocket_launch, 'color': Colors.orange},
      {'name': 'Biography', 'icon': Icons.person, 'color': Colors.green},
      {'name': 'Business', 'icon': Icons.business, 'color': Colors.teal},
      {'name': 'Self Development', 'icon': Icons.trending_up, 'color': Colors.indigo},
      {'name': 'History', 'icon': Icons.history_edu, 'color': Colors.brown},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editor's Picks section
          Text(
            'Editor\'s Picks',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _buildHorizontalBookList(_newReleaseBooks.take(5).toList()),
          ),
          const SizedBox(height: 24),

          // Browse by Category
          Text(
            'Browse by Category',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4, // Reduced again to fix overflow errors
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                child: InkWell(
                  onTap: () => _navigateToCategory(category['name'] as String),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          (category['color'] as Color).withOpacity(0.1),
                          (category['color'] as Color).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(6), // Even smaller padding
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  category['icon'] as IconData,
                                  color: category['color'] as Color,
                                  size: 18, // Even smaller icon
                                ),
                                const SizedBox(height: 2), // Minimal spacing
                                Flexible( // Add Flexible to prevent overflow
                                  child: Text(
                                    category['name'] as String,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontSize: 11, // Even smaller font
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBestsellersTab() {
    if (_isLoadingBestsellers) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bestsellerBooks.length,
      itemBuilder: (context, index) {
        final book = _bestsellerBooks[index];
        return _buildRankedBookCard(book, index + 1);
      },
    );
  }

  Widget _buildRankedBookCard(BrowseBook book, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank <= 3 ? Theme.of(context).colorScheme.primary : Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildBookCover(
              book.coverImageUrl,
              width: 48,
              height: 64,
              borderRadius: 4,
              bookTitle: book.title,
              bookAuthor: book.author,
            ),
          ],
        ),
        title: Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(book.author),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToBookDetails(book.id),
      ),
    );
  }

  Widget _buildNewReleasesTab() {
    if (_isLoadingNewReleases) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _newReleaseBooks.length,
      itemBuilder: (context, index) {
        final book = _newReleaseBooks[index];
        return _buildBookGridCard(book);
      },
    );
  }

  Widget _buildPlusCatalogTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.all_inclusive,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plus Catalog',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text('Thousands of titles included with your membership'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Included Books',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _plusCatalogBooks.length,
            itemBuilder: (context, index) {
              final book = _plusCatalogBooks[index];
              return _buildBookGridCard(book, showPlusLabel: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalBookList(List<BrowseBook> books) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Container(
          width: 120,
          margin: const EdgeInsets.only(right: 12),
          child: _buildBookGridCard(book),
        );
      },
    );
  }

  Widget _buildBookGridCard(BrowseBook book, {bool showPlusLabel = false}) {
    return Card(
      elevation: 3,
      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _navigateToBookDetails(book.id),
        borderRadius: BorderRadius.circular(16),
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
                    borderRadius: 16,
                    topOnly: true,
                    bookTitle: book.title,
                    bookAuthor: book.author,
                  ),
                  if (showPlusLabel)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Plus',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 2.0), // Further reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Minimize column size
                  children: [
                    Flexible(
                      child: Text(
                        book.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12, // Even smaller
                          height: 1.1, // Tighter line height
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 0.5), // Minimal spacing
                    Flexible(
                      child: Text(
                        book.author,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 9, // Smaller
                          height: 1.0, // Tight line height
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  void _navigateToBookDetails(String bookId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailsScreen(bookId: bookId),
      ),
    );
  }

  void _navigateToCategory(String categoryName) {
    // TODO: Navigate to category screen
    debugPrint('Navigate to category: $categoryName');
  }

  void _voiceSearch() {
    // TODO: Implement voice search
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Voice search coming soon!')),
    );
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

    // Enhanced fallback widget with Japanese minimalism
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
      // Clean up book title for better URL matching
      final cleanTitle = bookTitle.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
          .replaceAll(' ', '_')
          .replaceAll('__', '_'); // Clean up double underscores
      openLibraryUrl = 'https://covers.openlibrary.org/b/title/$cleanTitle-M.jpg';
      debugPrint('OpenLibrary URL for "$bookTitle": $openLibraryUrl');
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
    debugPrint('Primary URL for "$bookTitle": $primaryUrl');
    
    // Try primary URL first, then OpenLibrary, then fallback
    final urlsToTry = [
      if (primaryUrl != null) primaryUrl,
      if (openLibraryUrl != null) openLibraryUrl,
    ];

    // Always show fallback for now to debug the issue
    debugPrint('URLs to try for "$bookTitle": $urlsToTry');
    if (urlsToTry.isEmpty) {
      debugPrint('No URLs available, showing fallback for "$bookTitle"');
      return fallbackWidget;
    }

    // TEMPORARY: Force show fallback to test display
    // return fallbackWidget;

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