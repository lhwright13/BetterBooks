import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bookstore_models.dart';
import '../services/bookstore_service.dart';
import '../providers/auth_provider.dart';

class BookstoreScreen extends StatefulWidget {
  const BookstoreScreen({Key? key}) : super(key: key);

  @override
  _BookstoreScreenState createState() => _BookstoreScreenState();
}

class _BookstoreScreenState extends State<BookstoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookstoreService _bookstoreService = BookstoreService();
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
      appBar: AppBar(
        title: Text('Bookstore'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_creditBalance != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Chip(
                  avatar: Icon(Icons.account_balance_wallet, size: 16),
                  label: Text('${_creditBalance!.availableCredits} Credits'),
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.star), text: 'Featured'),
            Tab(icon: Icon(Icons.trending_up), text: 'Bestsellers'),
            Tab(icon: Icon(Icons.new_releases), text: 'New'),
            Tab(icon: Icon(Icons.category), text: 'Categories'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for audiobooks...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchBooks('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: _searchBooks,
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
      padding: EdgeInsets.all(16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookCard(book);
      },
    );
  }

  Widget _buildBookCard(BookCatalog book) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookDetailsScreen(book: book),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: book.coverImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.book, size: 40, color: Colors.grey);
                          },
                        ),
                      )
                    : Icon(Icons.book, size: 40, color: Colors.grey),
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
                            book.durationSeconds!.formattedDuration,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                    
                    SizedBox(height: 8),
                    
                    // Price and Purchase
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.formattedPrice,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              '${book.creditPrice} credit${book.creditPrice != 1 ? 's' : ''}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        
                        // Badges
                        Wrap(
                          spacing: 4,
                          children: [
                            if (book.isFeatured)
                              Chip(
                                label: Text('Featured', style: TextStyle(fontSize: 10)),
                                backgroundColor: Colors.blue[100],
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            if (book.isBestseller)
                              Chip(
                                label: Text('Bestseller', style: TextStyle(fontSize: 10)),
                                backgroundColor: Colors.orange[100],
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            if (book.isNewRelease)
                              Chip(
                                label: Text('New', style: TextStyle(fontSize: 10)),
                                backgroundColor: Colors.green[100],
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
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

// Placeholder screens that need to be implemented
class BookDetailsScreen extends StatelessWidget {
  final BookCatalog book;

  const BookDetailsScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Details'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Book Details Screen'),
            SizedBox(height: 16),
            Text('Title: ${book.title}'),
            SizedBox(height: 8),
            Text('Coming Soon!'),
          ],
        ),
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