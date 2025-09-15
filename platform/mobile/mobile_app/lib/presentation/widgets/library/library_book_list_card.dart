import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/book_models.dart';
import '../download_button.dart';
import '../cloud_badge.dart';

class LibraryBookListCard extends StatelessWidget {
  final BrowseBook book;
  final double? progress;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onMoreOptions;

  const LibraryBookListCard({
    super.key,
    required this.book,
    this.progress,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    required this.onTap,
    required this.onDownload,
    required this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Book cover
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: book.coverImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: const Icon(Icons.book, size: 24),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: const Icon(Icons.broken_image, size: 24),
                        ),
                      ),
                    ),
                  ),
                  
                  // Cloud badge for downloaded books
                  if (book.isDownloaded)
                    const Positioned(
                      top: 2,
                      left: 2,
                      child: CloudBadge(isVisible: true),
                    ),
                  
                  // Download progress overlay
                  if (isDownloading)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: downloadProgress,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 12),
              
              // Book information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Author
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Progress indicator
                    if (progress != null && progress! > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(progress! * 100).toInt()}% complete',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // More options button
                  IconButton(
                    onPressed: onMoreOptions,
                    icon: const Icon(Icons.more_vert),
                    visualDensity: VisualDensity.compact,
                  ),
                  
                  // Download button
                  DownloadButton(
                    isDownloaded: book.isDownloaded,
                    isDownloading: isDownloading,
                    downloadProgress: downloadProgress,
                    onDownload: onDownload,
                    showLabel: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}