import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/book.dart';
import '../theme/echowright_theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EchoWrightTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Library'),
        backgroundColor: EchoWrightTheme.backgroundDark,
        foregroundColor: EchoWrightTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {}, // TODO: Implement search
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {}, // TODO: Implement filters
          ),
        ],
      ),
      body: const LibraryBody(),
    );
  }
}

class LibraryBody extends StatefulWidget {
  const LibraryBody({super.key});

  @override
  _LibraryBodyState createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<LibraryBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: EchoWrightTheme.primaryTurquoise,
            ),
          );
        }

        if (appState.error != null) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline, 
                    size: 64, 
                    color: EchoWrightTheme.errorColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Error loading books',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: EchoWrightTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    appState.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: EchoWrightTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => appState.loadBooks(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EchoWrightTheme.primaryTurquoise,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (appState.books.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books_outlined, 
                    size: 80, 
                    color: EchoWrightTheme.textMuted,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Your library is empty',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: EchoWrightTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start building your audiobook collection',
                    style: TextStyle(
                      fontSize: 16,
                      color: EchoWrightTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/store'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EchoWrightTheme.accentCoral,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text('Browse Store'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => appState.loadBooks(),
          color: EchoWrightTheme.primaryTurquoise,
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: appState.books.length,
            itemBuilder: (context, index) {
              final book = appState.books[index];
              return BookCard(book: book);
            },
          ),
        );
      },
    );
  }
}

class BookCard extends StatelessWidget {
  final Book book;

  const BookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EchoWrightTheme.dividerDark,
          width: 1,
        ),
        boxShadow: EchoWrightTheme.subtleShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _playBook(context, book),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                // Book cover
                Container(
                  width: 64,
                  height: 80,
                  decoration: BoxDecoration(
                    color: EchoWrightTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    book.hasChapters ? Icons.menu_book_rounded : Icons.headphones_rounded,
                    color: EchoWrightTheme.primaryTurquoise,
                    size: 28,
                  ),
                ),
                SizedBox(width: 20),
                
                // Book information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: EchoWrightTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.author != null) ...[
                        SizedBox(height: 4),
                        Text(
                          book.author!,
                          style: TextStyle(
                            color: EchoWrightTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      SizedBox(height: 12),
                      
                      // Metadata chip
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          book.hasChapters 
                              ? '${book.chapters!.length} chapters'
                              : 'Audiobook',
                          style: TextStyle(
                            color: EchoWrightTheme.primaryTurquoise,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Play button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: EchoWrightTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: EchoWrightTheme.subtleShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _playBook(context, book),
                      borderRadius: BorderRadius.circular(24),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
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

  void _playBook(BuildContext context, Book book) {
    final appState = context.read<AppState>();
    
    if (book.hasChapters) {
      _showChapterSelection(context, book, appState);
    } else {
      appState.playBook(book);
      Navigator.pushNamed(context, '/player');
    }
  }

  void _showChapterSelection(BuildContext context, Book book, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EchoWrightTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              book.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: EchoWrightTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select a chapter',
              style: TextStyle(
                fontSize: 14,
                color: EchoWrightTheme.textSecondary,
              ),
            ),
            SizedBox(height: 24),
            
            // Chapter list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: book.chapters!.length,
                itemBuilder: (context, index) {
                  final chapter = book.chapters![index];
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: EchoWrightTheme.backgroundDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: EchoWrightTheme.dividerDark,
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          appState.playBook(book, chapter);
                          Navigator.pushNamed(context, '/player');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: EchoWrightTheme.primaryTurquoise.withValues(alpha: 0.2),
                                  border: Border.all(
                                    color: EchoWrightTheme.primaryTurquoise,
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${chapter.chapterNumber}',
                                    style: TextStyle(
                                      color: EchoWrightTheme.primaryTurquoise,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  chapter.title,
                                  style: TextStyle(
                                    color: EchoWrightTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.play_arrow_rounded,
                                color: EchoWrightTheme.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}