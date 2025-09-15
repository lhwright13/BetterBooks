import 'package:flutter/material.dart';
import '../../../data/models/book_models.dart';

class BookOverviewSection extends StatelessWidget {
  final DetailedBook book;
  final VoidCallback? onPlayPreview;

  const BookOverviewSection({
    super.key,
    required this.book,
    this.onPlayPreview,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (book.description?.isNotEmpty == true) ...[
            Text(
              'About this book',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Chapters section
          if (book.chapters.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Chapters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onPlayPreview != null)
                  TextButton.icon(
                    onPressed: onPlayPreview,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Preview'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...book.chapters.take(5).map((chapter) => ChapterTile(
              chapter: chapter,
              onTap: () => _onChapterTap(chapter, context),
            )),
            
            if (book.chapters.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _showAllChapters(context),
                  child: Text(
                    'View all ${book.chapters.length} chapters',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],

          // Additional info
          const SizedBox(height: 24),
          _buildAdditionalInfo(context),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'Author',
          value: book.author,
          icon: Icons.person,
        ),
        if (book.totalDuration != null)
          _InfoTile(
            label: 'Total Duration',
            value: _formatDuration(book.totalDuration!),
            icon: Icons.access_time,
          ),
        _InfoTile(
          label: 'Chapters',
          value: '${book.chapters.length} chapters',
          icon: Icons.list,
        ),
        _InfoTile(
          label: 'Format',
          value: 'Audiobook',
          icon: Icons.headphones,
        ),
      ],
    );
  }

  void _onChapterTap(Chapter chapter, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(chapter.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chapter ${chapter.chapterNumber}'),
            if (chapter.duration != null) ...[
              const SizedBox(height: 8),
              Text('Duration: ${_formatDuration(chapter.duration!)}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Handle chapter play
            },
            child: const Text('Play'),
          ),
        ],
      ),
    );
  }

  void _showAllChapters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                    'All Chapters',
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
            
            // Chapters list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: book.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = book.chapters[index];
                  return ChapterTile(
                    chapter: chapter,
                    onTap: () {
                      Navigator.of(context).pop();
                      _onChapterTap(chapter, context);
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

  String _formatDuration(int durationInSeconds) {
    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

class ChapterTile extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onTap;

  const ChapterTile({
    super.key,
    required this.chapter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            '${chapter.chapterNumber}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        chapter.title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: chapter.duration != null
        ? Text(_formatDuration(chapter.duration!))
        : null,
      trailing: Icon(
        Icons.play_arrow,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  String _formatDuration(int durationInSeconds) {
    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}