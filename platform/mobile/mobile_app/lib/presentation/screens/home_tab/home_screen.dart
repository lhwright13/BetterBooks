import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../data/api/api_client.dart';
import '../../../data/models/book_models.dart';
import '../book_details_screen.dart';
import '../player/mini_player.dart';
import '../../widgets/enhanced_book_card.dart';
import '../../widgets/enhanced_section_header.dart';
import '../../widgets/enhanced_category_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BrowseBook> _continueReading = [];
  List<BrowseBook> _featuredBooks = [];
  List<BrowseBook> _dailyDeals = [];
  List<BrowseBook> _newReleases = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [featured, newReleases] = await Future.wait([
        ApiClient.getFeaturedBooks(limit: 10),
        ApiClient.browseBooks(page: 1, limit: 10),
      ]);
      
      setState(() {
        _featuredBooks = featured.books;
        _newReleases = newReleases.books;
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
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: Theme.of(context).colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/images/EchoWrightYellow.svg',
              height: 48,
              colorFilter: ColorFilter.mode(
                Colors.black,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              color: Colors.black,
              iconSize: 22,
              onPressed: () {
                // TODO: Implement notifications
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 4, right: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.search_rounded),
              color: Colors.black,
              iconSize: 22,
              onPressed: () {
                // TODO: Navigate to search
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withOpacity(0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHomeData,
                child: _buildHomeContent(),
              ),
            ),
            const MiniPlayer(), // Persistent mini player
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading && _featuredBooks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null && _featuredBooks.isEmpty) {
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
            Text('Unable to load content'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHomeData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      children: [
        // Continue Reading Section
        if (_continueReading.isNotEmpty) ...[
          const ContinueReadingHeader(),
          const SizedBox(height: 16),
          _buildContinueReadingCarousel(),
          const SizedBox(height: 32),
        ],

        // Daily Deal Section  
        if (_dailyDeals.isNotEmpty) ...[
          const DailyDealHeader(),
          const SizedBox(height: 16),
          _buildDailyDealCard(),
          const SizedBox(height: 32),
        ],

        // Featured Books Section
        FeaturedBooksHeader(
          onSeeAllTap: () {
            // TODO: Navigate to featured books
          },
        ),
        const SizedBox(height: 16),
        _buildEnhancedHorizontalBookList(_featuredBooks),
        const SizedBox(height: 32),

        // New Releases Section
        NewReleasesHeader(
          onSeeAllTap: () {
            // TODO: Navigate to new releases
          },
        ),
        const SizedBox(height: 16),
        _buildEnhancedHorizontalBookList(_newReleases),
        const SizedBox(height: 32),

        // Categories Grid
        const CategoriesHeader(),
        const SizedBox(height: 16),
        _buildEnhancedCategoriesGrid(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {bool showSeeAll = true, VoidCallback? onSeeAllTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (showSeeAll)
          TextButton(
            onPressed: onSeeAllTap,
            child: const Text('See all'),
          ),
      ],
    );
  }

  Widget _buildContinueReadingCarousel() {
    return SizedBox(
      height: 140, // Increased height for enhanced cards
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _continueReading.length,
        itemBuilder: (context, index) {
          final book = _continueReading[index];
          return Container(
            width: 320,
            margin: const EdgeInsets.only(right: 12),
            child: EnhancedBookCard(
              book: book,
              width: 320,
              height: 130,
              showProgress: true,
              progress: _getBookProgress(book.id),
              onTap: () => _navigateToBookDetails(book.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContinueReadingCard(BrowseBook book) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildBookCover(
                book.coverImageUrl,
                width: 80,
                height: 96,
                borderRadius: 8,
                bookTitle: book.title,
                bookAuthor: book.author,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Progress bar would go here
                    LinearProgressIndicator(value: _getBookProgress(book.id)), // Varied progress
                    const SizedBox(height: 4),
                    Text('${(_getBookProgress(book.id) * 100).round()}% complete', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyDealCard() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shadowColor: Colors.deepOrange.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepOrange.shade400,
                Colors.deepOrange.shade600,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Fire icon with enhanced styling
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Deal',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Save up to 90% on select titles',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Enhanced action button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // TODO: Navigate to daily deals
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Shop Now',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.deepOrange.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedHorizontalBookList(List<BrowseBook> books) {
    if (books.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No books available',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 240, // Increased height for enhanced cards
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return EnhancedBookCard(
            book: book,
            width: 140,
            height: 220,
            onTap: () => _navigateToBookDetails(book.id),
          );
        },
      ),
    );
  }


  Widget _buildBookCard(BrowseBook book) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 4,
        shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
                flex: 3,
                child: _buildBookCover(
                  book.coverImageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 16,
                  topOnly: true,
                  bookTitle: book.title,
                  bookAuthor: book.author,
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 6.0), // Reduced bottom padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13, // Slightly smaller
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2), // Reduced spacing
                      Text(
                        book.author,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 10,
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
      ),
    );
  }

  Widget _buildEnhancedCategoriesGrid() {
    return EnhancedCategoriesGrid(
      categories: CategoryData.defaultCategories.take(6).toList(),
      crossAxisCount: 3,
      childAspectRatio: 1.1,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onCategoryTap: (category) {
        // TODO: Navigate to category with enhanced transition
        debugPrint('Navigate to ${category.name} category');
      },
    );
  }


  void _navigateToBookDetails(String bookId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookDetailsScreen(bookId: bookId),
      ),
    );
  }

  /// Generate varied progress based on book ID for realistic mock data
  double _getBookProgress(String bookId) {
    final hash = bookId.hashCode.abs();
    final progressValues = [0.05, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95, 1.0];
    return progressValues[hash % progressValues.length];
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