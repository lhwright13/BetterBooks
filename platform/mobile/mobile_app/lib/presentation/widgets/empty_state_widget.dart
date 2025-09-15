import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';

/// Reusable empty state widget for consistent UX across the app
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final Widget? illustration;
  final String? actionText;
  final VoidCallback? onActionPressed;
  final Color? backgroundColor;
  
  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.illustration,
    this.actionText,
    this.onActionPressed,
    this.backgroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: ResponsiveUtils.responsivePadding(context, 
        small: 24, medium: 32, large: 48),
      color: backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon or illustration
          if (illustration != null) ...[
            SizedBox(
              width: ResponsiveUtils.isSmallScreen(context) ? 120 : 160,
              height: ResponsiveUtils.isSmallScreen(context) ? 120 : 160,
              child: illustration!,
            ),
            SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
          ] else if (icon != null) ...[
            Container(
              width: ResponsiveUtils.isSmallScreen(context) ? 64 : 80,
              height: ResponsiveUtils.isSmallScreen(context) ? 64 : 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon!,
                size: ResponsiveUtils.isSmallScreen(context) ? 32 : 40,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ),
            ),
            SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 16 : 24),
          ],
          
          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: ResponsiveUtils.responsiveFontSize(context, 20),
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 8 : 12),
          
          // Message
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          // Action button
          if (actionText != null && onActionPressed != null) ...[
            SizedBox(height: ResponsiveUtils.isSmallScreen(context) ? 20 : 32),
            ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.isSmallScreen(context) ? 24 : 32,
                  vertical: ResponsiveUtils.isSmallScreen(context) ? 12 : 16,
                ),
              ),
              child: Text(
                actionText!,
                style: TextStyle(
                  fontSize: ResponsiveUtils.responsiveFontSize(context, 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Specialized empty state variants for common use cases
class EmptyLibraryWidget extends StatelessWidget {
  final VoidCallback? onBrowseBooks;
  
  const EmptyLibraryWidget({
    super.key,
    this.onBrowseBooks,
  });
  
  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.library_books_outlined,
      title: 'No Books Yet',
      message: 'Your library is empty. Start building your collection by browsing our audiobook catalog.',
      actionText: 'Browse Books',
      onActionPressed: onBrowseBooks,
    );
  }
}

class EmptySearchWidget extends StatelessWidget {
  final String searchQuery;
  final VoidCallback? onClearSearch;
  
  const EmptySearchWidget({
    super.key,
    required this.searchQuery,
    this.onClearSearch,
  });
  
  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: 'No Results Found',
      message: 'We couldn\'t find any books matching "$searchQuery". Try different keywords or browse our categories.',
      actionText: 'Clear Search',
      onActionPressed: onClearSearch,
    );
  }
}

class EmptyDownloadsWidget extends StatelessWidget {
  final VoidCallback? onStartDownloading;
  
  const EmptyDownloadsWidget({
    super.key,
    this.onStartDownloading,
  });
  
  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.download_outlined,
      title: 'No Downloads',
      message: 'You haven\'t downloaded any books yet. Download books to enjoy them offline.',
      actionText: 'Browse Library',
      onActionPressed: onStartDownloading,
    );
  }
}

class EmptyWishlistWidget extends StatelessWidget {
  final VoidCallback? onBrowseBooks;
  
  const EmptyWishlistWidget({
    super.key,
    this.onBrowseBooks,
  });
  
  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.favorite_border,
      title: 'No Wishlist Items',
      message: 'Save books to your wishlist by tapping the heart icon when browsing.',
      actionText: 'Discover Books',
      onActionPressed: onBrowseBooks,
    );
  }
}