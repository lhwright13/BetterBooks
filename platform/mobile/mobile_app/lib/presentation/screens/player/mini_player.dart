import 'package:flutter/material.dart';
import 'full_player_screen.dart';
import '../../../data/models/book_models.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  // Dynamic content - shows only when actually playing
  bool _isPlaying = false;
  double _progress = 0.42;
  String _currentBook = ""; // Empty by default - shows only when playing
  String _currentChapter = "";

  @override
  Widget build(BuildContext context) {
    // Don't show mini player if no book is playing
    if (_currentBook.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar - minimal Japanese style
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            minHeight: 1.5, // Thinner for minimalism
          ),
          // Player controls
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openFullPlayer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Refined book cover placeholder with Japanese aesthetics
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            Theme.of(context).colorScheme.primary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Book info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentBook,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _currentChapter,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Playback controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10),
                          onPressed: _rewind30,
                          iconSize: 24,
                        ),
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: _togglePlayback,
                          iconSize: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10),
                          onPressed: _forward30,
                          iconSize: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullPlayer() {
    // Create a dummy book for demo purposes
    // In a real app, this would come from the current playing context
    final dummyBook = BrowseBook(
      id: 'demo-book',
      title: 'The Great Gatsby',
      author: 'F. Scott Fitzgerald',
      coverImageUrl: 'https://covers.openlibrary.org/b/title/the_great_gatsby-M.jpg',
      isPurchased: true,
      isDownloaded: true,
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullPlayerScreen(book: dummyBook),
        fullscreenDialog: true,
      ),
    );
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    // TODO: Implement actual playback control
  }

  void _rewind30() {
    // TODO: Implement rewind functionality
    debugPrint('Rewind 30 seconds');
  }

  void _forward30() {
    // TODO: Implement forward functionality
    debugPrint('Forward 30 seconds');
  }
}