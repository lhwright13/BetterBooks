import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final Color? iconColor;
  final double iconSize;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
    this.iconColor,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              icon,
              size: iconSize,
              color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Action button
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.explore),
                label: Text(actionText!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Predefined empty states for common scenarios
class EmptyStates {
  static const EmptyStateWidget libraryEmpty = EmptyStateWidget(
    icon: Icons.library_books,
    title: 'Your library is empty',
    subtitle: 'Browse the store to add books to your library',
    actionText: 'Browse Books',
  );
  
  static const EmptyStateWidget searchEmpty = EmptyStateWidget(
    icon: Icons.search_off,
    title: 'No results found',
    subtitle: 'Try adjusting your search terms or filters',
  );
  
  static const EmptyStateWidget downloadedEmpty = EmptyStateWidget(
    icon: Icons.cloud_download,
    title: 'No downloaded books',
    subtitle: 'Download books for offline listening',
  );
  
  static const EmptyStateWidget finishedEmpty = EmptyStateWidget(
    icon: Icons.check_circle_outline,
    title: 'No finished books',
    subtitle: 'Books you\'ve completed will appear here',
  );
  
  static const EmptyStateWidget wishlistEmpty = EmptyStateWidget(
    icon: Icons.favorite_border,
    title: 'Your wishlist is empty',
    subtitle: 'Save books you want to read later',
  );
}