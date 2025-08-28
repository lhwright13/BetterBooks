import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bookstore_models.dart';
import '../services/bookstore_adapter.dart';
import '../providers/auth_provider.dart';
import '../widgets/smart_cover_image.dart';
import 'book_details_screen.dart';

class BookstoreScreen extends StatefulWidget {
  const BookstoreScreen({Key? key}) : super(key: key);

  @override
  _BookstoreScreenState createState() => _BookstoreScreenState();
}

class _BookstoreScreenState extends State<BookstoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookstoreAdapter _bookstoreService = BookstoreAdapter();
  final TextEditingController _searchController = TextEditingController();
  
  List<BookCatalog> _featuredBooks = [];
  List<BookCatalog> _bestsellers = [];
  List<BookCatalog> _newReleases = [];
  List<BookCategory> _categories = [];
  List<BookCatalog> _searchResults = [];
  CreditBalanceResponse? _creditBalance;
  
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        _creditBalance = await _bookstoreService.getCreditBalance();
      }

      final results = await Future.wait([
        _bookstoreService.browseBooks(featuredOnly: true, pageSize: 10),
        _bookstoreService.browseBooks(bestsellersOnly: true, pageSize: 10),
        _bookstoreService.browseBooks(newReleasesOnly: true, pageSize: 10),
        _bookstoreService.getCategories(),
      ]);

      _featuredBooks = (results[0] as BrowseResponse).books;
      _bestsellers = (results[1] as BrowseResponse).books;
      _newReleases = (results[2] as BrowseResponse).books;
      _categories = results[3] as List<BookCategory>;
      
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchBooks(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await _bookstoreService.searchBooks(query: query);
      setState(() {
        _searchResults = response.books;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Discover Books',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_creditBalance != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '${_creditBalance!.availableCredits}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: [
                Tab(text: 'Featured'),
                Tab(text: 'Best'),
                Tab(text: 'New'),
                Tab(text: 'Browse'),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search audiobooks...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _searchBooks('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: _searchBooks,
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator())
                : _searchController.text.isNotEmpty
                    ? _buildSearchResults()
                    : _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Failed to load bookstore'),
            SizedBox(height: 8),
            Text(_errorMessage!, style: TextStyle(color: Colors.grey)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildBookList(_featuredBooks, 'Featured Books'),
        _buildBookList(_bestsellers, 'Bestsellers'),
        _buildBookList(_newReleases, 'New Releases'),
        _buildCategoriesList(),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No books found'),
            Text('Try different keywords', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return _buildBookList(_searchResults, 'Search Results');
  }

  Widget _buildBookList(List<BookCatalog> books, String title) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No books available'),
            Text('Check back later for new additions!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookCard(book);
      },
    );
  }

  Widget _buildBookCard(BookCatalog book) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookDetailsScreen(book: book),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              Container(
                width: 72,
                height: 108,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: SmartCoverImageHelpers.fromBookCatalog(
                  book: book,
                  width: 72,
                  height: 108,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  errorWidget: Icon(
                    Icons.book,
                    size: 32,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              
              SizedBox(width: 16),
              
              // Book Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    if (book.author != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'by ${book.author}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    
                    if (book.narrator != null) ...[
                      SizedBox(height: 2),
                      Text(
                        'Narrated by ${book.narrator}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                    
                    SizedBox(height: 8),
                    
                    // Rating and Duration
                    Row(
                      children: [
                        if (book.averageRating != null) ...[
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            '${book.averageRating!.toStringAsFixed(1)} (${book.reviewCount})',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          SizedBox(width: 12),
                        ],
                        if (book.durationSeconds != null) ...[
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            book.formattedDuration,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Price and Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.formattedPrice,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${book.creditPrice} credit${book.creditPrice != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Status badges
                        if (book.isFeatured || book.isBestseller || book.isNewRelease)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: book.isFeatured
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                  : book.isBestseller
                                      ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
                                      : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              book.isFeatured
                                  ? 'Featured'
                                  : book.isBestseller
                                      ? 'Bestseller'
                                      : 'New',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: book.isFeatured
                                    ? Theme.of(context).colorScheme.primary
                                    : book.isBestseller
                                        ? Theme.of(context).colorScheme.secondary
                                        : Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildCategoriesList() {
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No categories available'),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryBooksScreen(category: category),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getCategoryIcon(category.name),
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: 8),
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'fiction':
        return Icons.book;
      case 'non-fiction':
        return Icons.school;
      case 'mystery':
        return Icons.search;
      case 'romance':
        return Icons.favorite;
      case 'sci-fi':
      case 'science fiction':
        return Icons.rocket_launch;
      case 'biography':
        return Icons.person;
      case 'business':
        return Icons.business;
      case 'health':
        return Icons.health_and_safety;
      case 'self-help':
        return Icons.psychology;
      case 'history':
        return Icons.history_edu;
      default:
        return Icons.category;
    }
  }
}

class BookDetailsScreen extends StatefulWidget {
  final BookCatalog book;

  const BookDetailsScreen({super.key, required this.book});

  @override
  _BookDetailsScreenState createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _isDescriptionExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Custom app bar with book cover
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.favorite_border,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () {
                  // Add to wishlist
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.share,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () {
                  // Share book
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: EdgeInsets.fromLTRB(20, 100, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Book cover
                    Container(
                      width: 140,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: widget.book.coverImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                widget.book.coverImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.book,
                                    size: 60,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.book,
                              size: 60,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                    ),
                    
                    SizedBox(width: 20),
                    
                    // Book info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          if (widget.book.author != null) ...[
                            SizedBox(height: 8),
                            Text(
                              'by ${widget.book.author}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          
                          if (widget.book.narrator != null) ...[
                            SizedBox(height: 4),
                            Text(
                              'Narrated by ${widget.book.narrator}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          
                          SizedBox(height: 12),
                          
                          // Rating and duration
                          Row(
                            children: [
                              if (widget.book.averageRating != null) ...[
                                Icon(Icons.star, size: 20, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  widget.book.averageRating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '(${widget.book.reviewCount})',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(width: 16),
                              ],
                              if (widget.book.durationSeconds != null) ...[
                                Icon(
                                  Icons.access_time,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  widget.book.formattedDuration,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Book details content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Purchase section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.book.formattedPrice,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  '${widget.book.creditPrice} credit${widget.book.creditPrice != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Status badge
                            if (widget.book.isFeatured || widget.book.isBestseller || widget.book.isNewRelease)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: widget.book.isFeatured
                                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                      : widget.book.isBestseller
                                          ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1)
                                          : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.book.isFeatured
                                      ? 'Featured'
                                      : widget.book.isBestseller
                                          ? 'Bestseller'
                                          : 'New Release',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: widget.book.isFeatured
                                        ? Theme.of(context).colorScheme.primary
                                        : widget.book.isBestseller
                                            ? Theme.of(context).colorScheme.secondary
                                            : Theme.of(context).colorScheme.tertiary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        SizedBox(height: 20),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  // Purchase book
                                },
                                icon: Icon(Icons.shopping_cart),
                                label: Text('Add to Cart'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            
                            SizedBox(width: 12),
                            
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  // Preview/sample
                                },
                                icon: Icon(Icons.play_circle_outline),
                                label: Text('Preview'),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Description section
                  Text(
                    'About This Book',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.description ?? 'No description available for this audiobook.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: _isDescriptionExpanded ? null : 4,
                          overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                        ),
                        
                        if (widget.book.description != null && widget.book.description!.length > 200) ...[
                          SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isDescriptionExpanded = !_isDescriptionExpanded;
                              });
                            },
                            child: Text(
                              _isDescriptionExpanded ? 'Show Less' : 'Read More',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Genre/Category section
                  if (widget.book.genre != null) ...[
                    Text(
                      'Genre',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.book.genre!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                  ],
                  
                  // Publication info section
                  if (widget.book.publisher != null || widget.book.publicationDate != null) ...[
                    Text(
                      'Publication Info',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.book.publisher != null) ...[
                            Row(
                              children: [
                                Text(
                                  'Publisher: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  widget.book.publisher!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (widget.book.publicationDate != null) ...[
                            if (widget.book.publisher != null) SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Published: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '${widget.book.publicationDate!.year}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          Row(
                            children: [
                              Text(
                                'Language: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                widget.book.language == 'en' ? 'English' : widget.book.language,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 80), // Extra padding for bottom navigation
                  ] else ...[
                    SizedBox(height: 80), // Extra padding for bottom navigation
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryBooksScreen extends StatelessWidget {
  final BookCategory category;

  const CategoryBooksScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Category: ${category.name}'),
            SizedBox(height: 8),
            Text('Books in this category coming soon!'),
          ],
        ),
      ),
    );
  }
}