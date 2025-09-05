import 'package:flutter/material.dart';

/// Enhanced section header with premium design and better visual hierarchy
/// Features:
/// - Improved typography with proper spacing
/// - Animated see-all button with subtle hover effects
/// - Better accessibility support
/// - Flexible styling options
/// - Premium visual design matching EchoWright brand
class EnhancedSectionHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool showSeeAll;
  final VoidCallback? onSeeAllTap;
  final IconData? icon;
  final Color? iconColor;
  final String? seeAllText;
  final EdgeInsetsGeometry? padding;

  const EnhancedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showSeeAll = true,
    this.onSeeAllTap,
    this.icon,
    this.iconColor,
    this.seeAllText,
    this.padding,
  });

  @override
  State<EnhancedSectionHeader> createState() => _EnhancedSectionHeaderState();
}

class _EnhancedSectionHeaderState extends State<EnhancedSectionHeader>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Color animation will be initialized in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    _colorAnimation = ColorTween(
      begin: Theme.of(context).colorScheme.primary,
      end: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown() {
    _controller.forward();
  }

  void _onTapUp() {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePadding = widget.padding ?? 
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Container(
      padding: effectivePadding,
      child: Row(
        children: [
          // Icon (if provided)
          if (widget.icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (widget.iconColor ?? theme.colorScheme.primary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.iconColor ?? theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    height: 1.2,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // See All Button with Animation
          if (widget.showSeeAll && widget.onSeeAllTap != null)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onSeeAllTap,
                      onTapDown: (_) => _onTapDown(),
                      onTapUp: (_) => _onTapUp(),
                      onTapCancel: _onTapCancel,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _colorAnimation.value ?? theme.colorScheme.primary,
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.seeAllText ?? 'See all',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _colorAnimation.value ?? theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: _colorAnimation.value ?? theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Specialized header for continue reading section
class ContinueReadingHeader extends EnhancedSectionHeader {
  const ContinueReadingHeader({
    super.key,
    super.onSeeAllTap,
  }) : super(
          title: 'Continue Reading',
          subtitle: 'Pick up where you left off',
          icon: Icons.play_circle_outline_rounded,
          showSeeAll: false, // Usually no see-all for continue reading
        );
}

/// Specialized header for featured books section  
class FeaturedBooksHeader extends EnhancedSectionHeader {
  const FeaturedBooksHeader({
    super.key,
    super.onSeeAllTap,
  }) : super(
          title: 'Featured Books',
          subtitle: 'Staff picks and trending titles',
          icon: Icons.star_border_rounded,
          iconColor: const Color(0xFFFFB000), // Gold color for featured
        );
}

/// Specialized header for new releases section
class NewReleasesHeader extends EnhancedSectionHeader {
  const NewReleasesHeader({
    super.key,
    super.onSeeAllTap,
  }) : super(
          title: 'New Releases',
          subtitle: 'Latest additions to our library',
          icon: Icons.new_releases_outlined,
        );
}

/// Specialized header for categories section
class CategoriesHeader extends EnhancedSectionHeader {
  const CategoriesHeader({
    super.key,
    super.onSeeAllTap,
  }) : super(
          title: 'Browse Categories',
          subtitle: 'Explore by genre and topic',
          icon: Icons.category_outlined,
          showSeeAll: false, // Categories are usually displayed as grid
        );
}

/// Specialized header for daily deals
class DailyDealHeader extends EnhancedSectionHeader {
  const DailyDealHeader({
    super.key,
    super.onSeeAllTap,
  }) : super(
          title: 'Daily Deal',
          subtitle: 'Limited time offers',
          icon: Icons.local_fire_department_outlined,
          iconColor: Colors.deepOrange,
          showSeeAll: false,
        );
}