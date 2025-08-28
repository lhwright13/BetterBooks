import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/app_state.dart';
import '../providers/auth_provider.dart';
import '../theme/echowright_theme.dart';
import '../models/bookstore_models.dart';
import '../services/bookstore_adapter.dart';
import '../services/log_service.dart';
import '../widgets/smart_cover_image.dart';
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
      final bookstoreAdapter = BookstoreAdapter();
      
      // Load different book sections from backend
      final [featuredResponse, newReleaseResponse, bestsellersResponse] = await Future.wait([
        bookstoreAdapter.browseBooks(featuredOnly: true, pageSize: 6),
        bookstoreAdapter.browseBooks(newReleasesOnly: true, pageSize: 6),
        bookstoreAdapter.browseBooks(bestsellersOnly: true, pageSize: 6),
      ]);

      setState(() {
        _featuredBooks = featuredResponse.books;
        _newReleaseBooks = newReleaseResponse.books;
        _popularBooks = bestsellersResponse.books;
      });
    } catch (e) {
      // Log the error and show empty lists with user-friendly message
      LogService.error('Failed to load book sections: $e', 'HomeTabScreen');
      
      setState(() {
        _featuredBooks = [];
        _newReleaseBooks = [];
        _popularBooks = [];
      });
      
      // Show a snackbar to inform the user of the issue
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load book recommendations. Please check your internet connection.'),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadBookSections,
            ),
          ),
        );
      }
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
                                  child: SmartCoverImageHelpers.fromBookCatalog(
                                    book: book,
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.circular(12),
                                    placeholder: Center(
                                      child: CircularProgressIndicator(
                                        color: EchoWrightTheme.primaryCoral,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: Container(
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
                                    ),
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

}
