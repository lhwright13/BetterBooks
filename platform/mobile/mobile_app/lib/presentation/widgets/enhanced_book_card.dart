import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/models/book_models.dart';
import '../screens/book_details_screen.dart';

/// Enhanced book card with premium design, subtle animations, and micro-interactions
/// Features:
/// - Improved visual hierarchy with better shadows and borders
/// - Smooth hover/press animations
/// - Better typography and spacing
/// - Enhanced cover image handling with elegant fallbacks
/// - Purchase and download status indicators
/// - WCAG AA compliant design
class EnhancedBookCard extends StatefulWidget {
  final BrowseBook book;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool showProgress;
  final double? progress;
  final bool isPurchased;
  final bool isDownloaded;
  final bool isDownloading;
  final double? downloadProgress;

  const EnhancedBookCard({
    super.key,
    required this.book,
    this.width = 140,
    this.height = 220,
    this.onTap,
    this.showProgress = false,
    this.progress,
    this.isPurchased = false,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress,
  });

  @override
  State<EnhancedBookCard> createState() => _EnhancedBookCardState();
}

class _EnhancedBookCardState extends State<EnhancedBookCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _shadowAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  void _navigateToBookDetails() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookDetailsScreen(bookId: widget.book.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _navigateToBookDetails,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                borderRadius: BorderRadius.circular(16),
                splashColor: theme.colorScheme.primary.withOpacity(0.1),
                highlightColor: theme.colorScheme.primary.withOpacity(0.05),
                child: AnimatedBuilder(
                  animation: _shadowAnimation,
                  builder: (context, child) {
                    return Card(
                      elevation: _shadowAnimation.value,
                      shadowColor: theme.colorScheme.primary.withOpacity(0.25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Book Cover with Enhanced Design
                          Expanded(
                            flex: 3,
                            child: _buildEnhancedBookCover(context),
                          ),
                          
                          // Book Information with Better Typography
                          Expanded(
                            flex: 2,
                            child: _buildBookInfo(context),
                          ),
                          
                          // Progress Bar (if applicable)
                          if (widget.showProgress && widget.progress != null)
                            _buildProgressSection(context),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedBookCover(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      children: [
        // Main Cover Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
          ),
          child: _buildCoverImage(context),
        ),
        
        // Gradient Overlay for Better Text Contrast
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  theme.colorScheme.surface.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ),
        
        // Status indicators (purchase/download status)
        _buildStatusIndicators(context),
      ],
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    final theme = Theme.of(context);
    
    // Enhanced fallback widget with premium design
    final fallbackWidget = Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.08),
            theme.colorScheme.primary.withOpacity(0.03),
            theme.colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              size: widget.width > 120 ? 32 : 24,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.width > 100)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.book.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );

    // Generate image URLs to try
    final urlsToTry = _generateImageUrls(widget.book);

    if (urlsToTry.isEmpty) {
      return fallbackWidget;
    }

    return CachedNetworkImage(
      imageUrl: urlsToTry.first,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => _buildShimmerPlaceholder(context),
      errorWidget: (context, url, error) {
        // Try fallback URLs
        if (urlsToTry.length > 1) {
          return CachedNetworkImage(
            imageUrl: urlsToTry[1],
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildShimmerPlaceholder(context),
            errorWidget: (context, url, error) => fallbackWidget,
          );
        }
        return fallbackWidget;
      },
    );
  }

  Widget _buildShimmerPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Shimmer.fromColors(
          baseColor: theme.colorScheme.surface,
          highlightColor: theme.colorScheme.primary.withOpacity(0.1),
          period: const Duration(milliseconds: 1500),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookInfo(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Book Title with Better Typography
          Text(
            widget.book.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: widget.width > 120 ? 13 : 12,
              height: 1.3,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 2),
          
          // Author with Refined Styling
          Text(
            widget.book.author,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
              fontSize: widget.width > 120 ? 11 : 10,
              height: 1.2,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 4),
          
          // Additional book status indicators
          _buildBookStatusIndicators(context),
        ],
      ),
    );
  }

  Widget _buildBookStatusIndicators(BuildContext context) {
    final theme = Theme.of(context);
    
    final statusItems = <Widget>[];
    
    // Show price/credits
    statusItems.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${widget.book.creditPrice} credit${widget.book.creditPrice == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
    
    // Show status badges
    if (widget.book.isFeatured) {
      statusItems.add(
        Icon(
          Icons.star_rounded,
          size: 10,
          color: const Color(0xFFFFB000),
        ),
      );
    }
    
    if (widget.book.isBestseller) {
      statusItems.add(
        Icon(
          Icons.trending_up_rounded,
          size: 10,
          color: theme.colorScheme.secondary,
        ),
      );
    }
    
    if (widget.book.isNewRelease) {
      statusItems.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'NEW',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      );
    }
    
    return statusItems.isNotEmpty
        ? Wrap(
            spacing: 4,
            children: statusItems,
          )
        : const SizedBox.shrink();
  }

  Widget _buildProgressSection(BuildContext context) {
    final theme = Theme.of(context);
    final progress = widget.progress ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).round()}% complete',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 9,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators(BuildContext context) {
    final theme = Theme.of(context);
    
    // Don't show indicators if not purchased
    if (!widget.isPurchased) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Download status indicator
          if (widget.isDownloaded)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.download_done_rounded,
                color: Colors.white,
                size: 16,
              ),
            )
          else if (widget.isDownloading)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: widget.downloadProgress,
                      strokeWidth: 2,
                      color: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                ],
              ),
            )
          else
            // Purchased but not downloaded - show cloud icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_download_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  List<String> _generateImageUrls(BrowseBook book) {
    final urls = <String>[];
    
    // Primary API URL
    if (book.coverImageUrl.isNotEmpty) {
      if (book.coverImageUrl.startsWith('http')) {
        urls.add(book.coverImageUrl);
      } else {
        urls.add('http://128.203.92.141:8000${book.coverImageUrl}');
      }
    }
    
    // OpenLibrary fallback
    final cleanTitle = book.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').replaceAll(' ', '_');
    urls.add('https://covers.openlibrary.org/b/title/$cleanTitle-M.jpg');
    
    return urls;
  }
}