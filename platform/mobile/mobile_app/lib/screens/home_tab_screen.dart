import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/app_state.dart';
import '../providers/auth_provider.dart';
import '../theme/echowright_theme.dart';
import '../models/bookstore_models.dart';
import '../api_config.dart';
import 'bookstore_screen.dart';

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key});

  @override
  _HomeTabScreenState createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<BookCatalog> _featuredBooks = [];
  List<BookCatalog> _newReleaseBooks = [];
  List<BookCatalog> _popularBooks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadBooks();
      context.read<AuthProvider>().loadCreditBalance(); // Load credit balance
      _loadBookSections();
    });
  }

  Future<void> _loadBookSections() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the working AppState books data instead of bookstore API
      final appState = context.read<AppState>();
      
      // Convert Book models to BookCatalog models for display
      final allBooks = appState.books;
      final catalogBooks = allBooks.map((book) {
        // Generate cover image URL based on book title
        String? coverImageUrl;
        String? author;
        String? description;
        double price = 12.95;
        
        // Map specific books to their cover images and metadata using OpenLibrary
        switch (book.title) {
          case 'Alice\'s Adventures in Wonderland':
            coverImageUrl = 'https://covers.openlibrary.org/b/id/8164365-L.jpg';
            author = 'Lewis Carroll';
            description = 'A young girl falls down a rabbit hole into a fantasy world.';
            price = 9.95;
            break;
          case 'Moby Dick':
            coverImageUrl = 'https://covers.openlibrary.org/b/id/8893680-L.jpg';
            author = 'Herman Melville';
            description = 'The tale of Captain Ahab\'s quest for revenge against the white whale.';
            price = 19.95;
            break;
          case 'War and Peace':
            coverImageUrl = 'https://covers.openlibrary.org/b/id/8231674-L.jpg';
            author = 'Leo Tolstoy';
            description = 'Epic novel chronicling Russian society during the Napoleonic era.';
            price = 24.95;
            break;
          case 'The Great Gatsby':
            coverImageUrl = 'https://covers.openlibrary.org/b/id/8225261-L.jpg';
            author = 'F. Scott Fitzgerald';
            description = 'The story of Jay Gatsby and the American Dream in the Jazz Age.';
            price = 12.95;
            break;
          case 'The Odyssey':
            coverImageUrl = 'https://covers.openlibrary.org/b/id/8231237-L.jpg';
            author = 'Homer';
            description = 'Ancient Greek epic about Odysseus\'s journey home from Troy.';
            price = 15.95;
            break;
          default:
            author = 'Unknown Author';
            description = 'A great audiobook.';
            coverImageUrl = null;
        }

        return BookCatalog(
          id: book.id,
          title: book.title,
          author: author,
          narrator: null,
          description: description,
          coverImageUrl: coverImageUrl,
          sampleAudioUrl: book.audioUrl,
          priceUsd: price,
          creditPrice: price > 20 ? 2 : 1,
          formattedPrice: '\$${price.toStringAsFixed(2)}',
          durationSeconds: null,
          formattedDuration: 'Unknown',
          language: 'en',
          isFeatured: true,
          isBestseller: price > 15,
          isNewRelease: book.title == 'Alice\'s Adventures in Wonderland',
          averageRating: 4.0 + (price / 10),
          reviewCount: (price * 100).toInt(),
          purchaseCount: (price * 50).toInt(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }).toList();

      setState(() {
        // Distribute books across sections
        _featuredBooks = catalogBooks.take(2).toList();
        _newReleaseBooks = catalogBooks.skip(2).take(2).toList();
        _popularBooks = catalogBooks.skip(1).take(2).toList();
      });
    } catch (e) {
      print('Error loading book sections: $e');
      // Keep empty lists as fallback
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EchoWrightTheme.backgroundDark,
      body: Consumer2<AppState, AuthProvider>(
        builder: (context, appState, authProvider, child) {
          return SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(16, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // EchoWright Logo Header
                  Transform.translate(
                    offset: Offset(0, -35),
                    child: _buildLogoHeader(),
                  ),
                  SizedBox(height: 0),

                  // Credit Balance Display
                  _buildCreditBalanceCard(),
                  SizedBox(height: 16),

                  // Now Playing Mini Player (only show when playing)
                  if (appState.currentBook != null && appState.isPlaying) ...[
                    _buildCurrentlyListeningCard(appState),
                    SizedBox(height: 16),
                  ],

                  // Recommended for You
                  _buildRecommendedSection(),
                  SizedBox(height: 32),

                  // New Releases
                  _buildNewReleasesSection(),
                  SizedBox(height: 32),

                  // Popular Right Now
                  _buildPopularSection(),
                  SizedBox(height: 32),

                  // Trending This Week
                  _buildTrendingSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Container(
      width: 300,
      height: 170,
      alignment: Alignment.centerLeft,
      child: SvgPicture.asset(
        'assets/images/EchoWright.svg',
        width: 300,
        height: 170,
        fit: BoxFit.contain,
      ),
    );
  }


  Widget _buildCurrentlyListeningCard(AppState appState) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EchoWrightTheme.warmCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: EchoWrightTheme.deepForest.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mini book cover
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: EchoWrightTheme.softTan,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: EchoWrightTheme.darkGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.headphones,
              color: EchoWrightTheme.primaryCoral,
              size: 20,
            ),
          ),
          SizedBox(width: 16),

          // Book info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            EchoWrightTheme.primaryCoral.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'NOW PLAYING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: EchoWrightTheme.primaryCoral,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: EchoWrightTheme.primaryCoral,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  appState.currentBook?.title ?? 'Unknown Book',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: EchoWrightTheme.darkGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (appState.currentChapter != null)
                  Text(
                    'Chapter ${appState.currentChapter!.chapterNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: EchoWrightTheme.deepForest,
                    ),
                  ),
              ],
            ),
          ),

          // Play/pause button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: EchoWrightTheme.primaryCoral,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (appState.currentBook != null) {
                    await appState.playPause();
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Icon(
                  appState.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRecommendedSection() {
    if (_isLoading) {
      return _buildLoadingSection('Recommended for You');
    }
    return _buildRealBookSection('Recommended for You', _featuredBooks);
  }

  Widget _buildNewReleasesSection() {
    if (_isLoading) {
      return _buildLoadingSection('New Releases');
    }
    return _buildRealBookSection('New Releases', _newReleaseBooks);
  }

  Widget _buildPopularSection() {
    if (_isLoading) {
      return _buildLoadingSection('Popular Right Now');
    }
    return _buildRealBookSection('Popular Right Now', _popularBooks);
  }

  Widget _buildTrendingSection() {
    return _buildBookSection(
      'Trending This Week',
      [
        {'title': 'The Thursday Murder Club', 'author': 'Richard Osman'},
        {'title': 'The Silent Patient', 'author': 'Alex Michaelides'},
        {'title': 'Educated', 'author': 'Tara Westover'},
        {'title': 'Becoming', 'author': 'Michelle Obama'},
      ],
    );
  }

  Widget _buildBookSection(String title, List<Map<String, String>> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: EchoWrightTheme.darkGreen,
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('View all $title - Coming Soon!'),
                    backgroundColor: EchoWrightTheme.primaryCoral,
                  ),
                );
              },
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  color: EchoWrightTheme.primaryCoral,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Horizontal scrolling book list
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 4),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _buildCategoryBookCard(book);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBookCard(Map<String, String> book) {
    return Container(
      width: 140,
      margin: EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: EchoWrightTheme.softTan,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: EchoWrightTheme.deepForest.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${book['title']} - Coming to EchoWright soon!'),
                backgroundColor: EchoWrightTheme.primaryCoral,
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book cover placeholder
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: EchoWrightTheme.warmCream,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: EchoWrightTheme.darkGreen.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: EchoWrightTheme.darkGreen,
                      size: 40,
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Book title
                Text(
                  book['title']!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: EchoWrightTheme.darkGreen,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),

                // Author
                Text(
                  book['author']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: EchoWrightTheme.deepForest,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),

                // Coming soon text
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: EchoWrightTheme.primaryCoral,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: EchoWrightTheme.darkGreen,
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: 140,
                margin: EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    // Loading book cover placeholder
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: EchoWrightTheme.warmCream.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: EchoWrightTheme.primaryCoral,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: EchoWrightTheme.warmCream.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRealBookSection(String title, List<BookCatalog> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: EchoWrightTheme.darkGreen,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to full bookstore screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BookstoreScreen(),
                  ),
                );
              },
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  color: EchoWrightTheme.primaryCoral,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Horizontal scrolling book list
        SizedBox(
          height: 200,
          child: books.isEmpty
              ? Center(
                  child: Text(
                    'No books available',
                    style: TextStyle(
                      color: EchoWrightTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return Container(
                      width: 140,
                      margin: EdgeInsets.only(right: 16),
                      child: InkWell(
                        onTap: () {
                          // Find the original Book model and play it
                          final appState = context.read<AppState>();
                          final originalBook = appState.books.firstWhere(
                            (b) => b.title == book.title,
                            orElse: () => appState.books.first,
                          );
                          appState.playBook(originalBook);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Book cover with actual image
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: EchoWrightTheme.warmCream,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: EchoWrightTheme.darkGreen.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: book.coverImageUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            book.coverImageUrl!,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  color: EchoWrightTheme.primaryCoral,
                                                  strokeWidth: 2,
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              // For now, show a styled placeholder with book info
                                              return Container(
                                                padding: EdgeInsets.all(8),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.auto_stories,
                                                      color: EchoWrightTheme.primaryCoral,
                                                      size: 32,
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      book.author?.split(' ').last ?? 'Book',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: EchoWrightTheme.darkGreen,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : Icon(
                                          Icons.menu_book_outlined,
                                          color: EchoWrightTheme.darkGreen,
                                          size: 40,
                                        ),
                                ),
                              ),
                              SizedBox(height: 12),

                              // Book title
                              Text(
                                book.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: EchoWrightTheme.darkGreen,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),

                              // Author
                              Text(
                                book.author ?? 'Unknown Author',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: EchoWrightTheme.deepForest,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 6),

                              // Price
                              Text(
                                book.formattedPrice,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: EchoWrightTheme.primaryCoral,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Helper method for time formatting
  Widget _buildCreditBalanceCard() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: EchoWrightTheme.primaryCoral.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: EchoWrightTheme.primaryCoral,
                size: 24,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Credits',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: EchoWrightTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${authProvider.availableCredits} available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: EchoWrightTheme.primaryCoral,
                      ),
                    ),
                  ],
                ),
              ),
              if (authProvider.availableCredits > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: EchoWrightTheme.primaryCoral,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Ready to shop!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "${duration.inMinutes}:$twoDigitSeconds";
    }
  }
}
