import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/book_models.dart';
import '../common/empty_state_widget.dart';
import 'library_book_list_card.dart';

class LibrarySearchModal extends StatefulWidget {
  final List<BrowseBook> books;
  final Function(BrowseBook) onBookTap;
  final Function(BrowseBook) onBookDownload;
  final Function(BrowseBook) onBookMoreOptions;
  final Map<String, bool> downloadingBooks;
  final Map<String, double> downloadProgress;

  const LibrarySearchModal({
    super.key,
    required this.books,
    required this.onBookTap,
    required this.onBookDownload,
    required this.onBookMoreOptions,
    required this.downloadingBooks,
    required this.downloadProgress,
  });

  @override
  State<LibrarySearchModal> createState() => _LibrarySearchModalState();
}

class _LibrarySearchModalState extends State<LibrarySearchModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  List<BrowseBook> _searchResults = [];
  String _currentQuery = '';
  
  @override
  void initState() {
    super.initState();
    _searchResults = widget.books;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }
  
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _currentQuery = '';
        _searchResults = widget.books;
      });
      return;
    }
    
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }
  
  void _performSearch(String query) {
    if (!mounted) return;
    
    final lowercaseQuery = query.toLowerCase();
    final results = widget.books.where((book) {
      return book.title.toLowerCase().contains(lowercaseQuery) ||
             book.author.toLowerCase().contains(lowercaseQuery);
    }).toList();
    
    setState(() {
      _currentQuery = query;
      _searchResults = results;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Search Library',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search books by title or author...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchResults() {
    if (_currentQuery.isEmpty) {
      return _buildSearchSuggestions();
    }
    
    if (_searchResults.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No results found',
        subtitle: 'Try different search terms',
        iconSize: 64,
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return LibraryBookListCard(
          book: book,
          progress: 0.0, // This would come from actual progress data
          isDownloading: widget.downloadingBooks[book.id] ?? false,
          downloadProgress: widget.downloadProgress[book.id] ?? 0.0,
          onTap: () {
            Navigator.of(context).pop();
            widget.onBookTap(book);
          },
          onDownload: () => widget.onBookDownload(book),
          onMoreOptions: () => widget.onBookMoreOptions(book),
        );
      },
    );
  }
  
  Widget _buildSearchSuggestions() {
    final recentBooks = widget.books.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentBooks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Recent Books',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: recentBooks.length,
              itemBuilder: (context, index) {
                final book = recentBooks[index];
                return LibraryBookListCard(
                  book: book,
                  progress: 0.0, // This would come from actual progress data
                  isDownloading: widget.downloadingBooks[book.id] ?? false,
                  downloadProgress: widget.downloadProgress[book.id] ?? 0.0,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onBookTap(book);
                  },
                  onDownload: () => widget.onBookDownload(book),
                  onMoreOptions: () => widget.onBookMoreOptions(book),
                );
              },
            ),
          ),
        ] else
          const Expanded(
            child: EmptyStateWidget(
              icon: Icons.library_books,
              title: 'No books in library',
              subtitle: 'Add some books to search through them',
              iconSize: 64,
            ),
          ),
      ],
    );
  }
}