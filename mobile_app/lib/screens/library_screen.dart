import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/book.dart';
import '../widgets/holographic_components.dart';
import '../theme/retro_theme.dart';

class LibraryScreen extends StatefulWidget {
  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('EchoWright Library'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: LibraryBody(),
    );
  }
}

class LibraryBody extends StatefulWidget {
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
          return Center(child: CircularProgressIndicator());
        }

        if (appState.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error loading books',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 8),
                Text(
                  appState.error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => appState.loadBooks(),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (appState.books.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_books, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No books available',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 8),
                Text(
                  'Upload some books to get started',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => appState.loadBooks(),
          child: ListView.builder(
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

  const BookCard({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: RetroSpacing.md, vertical: RetroSpacing.sm),
      child: ArchitecturalCard(
        onTap: () => _playBook(context, book),
        padding: EdgeInsets.all(RetroSpacing.lg),
        child: Row(
          children: [
            // Book cover placeholder with clean design
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    RetroColors.primaryTerracotta.withOpacity(0.15),
                    RetroColors.sageGreen.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(RetroSizes.smallRadius),
                border: Border.all(
                  color: RetroColors.primaryTerracotta.withOpacity(0.2),
                  width: RetroSizes.subtleBorder,
                ),
              ),
              child: Icon(
                book.hasChapters ? Icons.menu_book_rounded : Icons.headphones_rounded,
                color: RetroColors.primaryTerracotta,
                size: 28,
              ),
            ),
            SizedBox(width: RetroSpacing.lg),
            
            // Book information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: RetroColors.ivoryWhite,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.author != null) ...[
                    SizedBox(height: RetroSpacing.xs),
                    Text(
                      book.author!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: RetroColors.lightGray,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  SizedBox(height: RetroSpacing.xs),
                  // Terminal-style metadata
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: RetroSpacing.sm,
                      vertical: RetroSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: RetroColors.primaryTerracotta.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: RetroColors.primaryTerracotta.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      book.hasChapters 
                          ? '${book.chapters!.length} CHAPTERS'
                          : 'AUDIOBOOK',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ArchitecturalColors.deepBlack,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Play button with clean styling
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    RetroColors.primaryTerracotta.withOpacity(0.8),
                    RetroColors.deepTeal.withOpacity(0.9),
                  ],
                ),
                border: Border.all(
                  color: RetroColors.primaryTerracotta.withOpacity(0.3),
                  width: RetroSizes.subtleBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: RetroColors.primaryTerracotta.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: RetroColors.ivoryWhite,
                size: 24,
              ),
            ),
          ],
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
      backgroundColor: ArchitecturalColors.charcoalBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RetroSizes.borderRadius),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(RetroSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              book.title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 20,
                color: ArchitecturalColors.pureWhite,
              ),
            ),
            SizedBox(height: RetroSpacing.md),
            
            // Terminal-style section header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: RetroSpacing.sm,
                vertical: RetroSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: RetroColors.primaryTerracotta.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: RetroColors.primaryTerracotta.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Text(
                'SELECT CHAPTER',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ArchitecturalColors.pureWhite,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            SizedBox(height: RetroSpacing.md),
            
            // Chapter list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: book.chapters!.length,
                itemBuilder: (context, index) {
                  final chapter = book.chapters![index];
                  return Container(
                    margin: EdgeInsets.only(bottom: RetroSpacing.sm),
                    child: ArchitecturalCard(
                      padding: EdgeInsets.all(RetroSpacing.md),
                      onTap: () {
                        Navigator.pop(context);
                        appState.playBook(book, chapter);
                        Navigator.pushNamed(context, '/player');
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  RetroColors.primaryTerracotta.withOpacity(0.8),
                                  RetroColors.deepTeal.withOpacity(0.9),
                                ],
                              ),
                              border: Border.all(
                                color: RetroColors.primaryTerracotta.withOpacity(0.3),
                                width: RetroSizes.subtleBorder,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${chapter.chapterNumber}',
                                style: TextStyle(
                                  color: RetroColors.ivoryWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: RetroSpacing.md),
                          Expanded(
                            child: Text(
                              chapter.title,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: ArchitecturalColors.pureWhite,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.play_arrow_rounded,
                            color: RetroColors.primaryTerracotta,
                            size: 20,
                          ),
                        ],
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