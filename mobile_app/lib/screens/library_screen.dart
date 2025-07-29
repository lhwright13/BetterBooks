import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/book.dart';

class LibraryScreen extends StatefulWidget {
  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('BetterBooks Library'),
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
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _playBook(context, book),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  book.hasChapters ? Icons.book : Icons.audiotrack,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
              ),
              SizedBox(width: 16),
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
                    if (book.author != null) ...[
                      SizedBox(height: 4),
                      Text(
                        book.author!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    SizedBox(height: 4),
                    Text(
                      book.hasChapters 
                          ? '${book.chapters!.length} chapters'
                          : 'Single audiobook',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_arrow, size: 30),
            ],
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
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            Text(
              'Select Chapter',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: book.chapters!.length,
                itemBuilder: (context, index) {
                  final chapter = book.chapters![index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${chapter.chapterNumber}'),
                    ),
                    title: Text(chapter.title),
                    onTap: () {
                      Navigator.pop(context);
                      appState.playBook(book, chapter);
                      Navigator.pushNamed(context, '/player');
                    },
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