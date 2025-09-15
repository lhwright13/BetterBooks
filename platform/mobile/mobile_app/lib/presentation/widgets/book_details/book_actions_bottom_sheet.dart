import 'package:flutter/material.dart';
import '../../../data/models/book_models.dart';

class BookActionsBottomSheet extends StatelessWidget {
  final DetailedBook book;
  final bool isPurchased;
  final bool isWishlisted;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;
  final VoidCallback? onPurchase;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onWishlist;
  final VoidCallback? onShare;
  final VoidCallback? onPreview;

  const BookActionsBottomSheet({
    super.key,
    required this.book,
    required this.isPurchased,
    required this.isWishlisted,
    required this.isDownloaded,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.onPurchase,
    this.onPlay,
    this.onDownload,
    this.onWishlist,
    this.onShare,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary action row
            Row(
              children: [
                // Main action button (Purchase/Play)
                Expanded(
                  flex: 2,
                  child: _buildMainActionButton(context),
                ),
                
                const SizedBox(width: 12),
                
                // Wishlist button
                _buildIconButton(
                  context,
                  icon: isWishlisted ? Icons.favorite : Icons.favorite_border,
                  onPressed: onWishlist,
                  tooltip: isWishlisted ? 'Remove from Wishlist' : 'Add to Wishlist',
                  isSelected: isWishlisted,
                ),
                
                const SizedBox(width: 8),
                
                // Share button
                _buildIconButton(
                  context,
                  icon: Icons.share,
                  onPressed: onShare,
                  tooltip: 'Share',
                ),
              ],
            ),
            
            // Secondary actions (if purchased)
            if (isPurchased) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  // Download button
                  Expanded(
                    child: _buildDownloadButton(context),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Preview button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPreview,
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('Preview'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionButton(BuildContext context) {
    if (isPurchased) {
      return ElevatedButton.icon(
        onPressed: onPlay,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Play'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPurchase,
        icon: const Icon(Icons.shopping_cart),
        label: const Text('Purchase (1 Credit)'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      );
    }
  }

  Widget _buildDownloadButton(BuildContext context) {
    if (isDownloading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    value: downloadProgress,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(downloadProgress * 100).toInt()}%'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    } else if (isDownloaded) {
      return OutlinedButton.icon(
        onPressed: null, // Already downloaded
        icon: const Icon(Icons.download_done, color: Colors.green),
        label: const Text('Downloaded'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: Colors.green.shade300),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: onDownload,
        icon: const Icon(Icons.download, size: 18),
        label: const Text('Download'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isSelected = false,
  }) {
    return Material(
      color: isSelected 
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}