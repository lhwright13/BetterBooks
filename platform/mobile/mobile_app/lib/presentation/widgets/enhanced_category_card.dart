import 'package:flutter/material.dart';

/// Enhanced category card with premium design and micro-interactions
/// Features:
/// - Subtle gradient backgrounds
/// - Smooth hover animations
/// - Better visual hierarchy
/// - Accessibility support
/// - Premium styling matching EchoWright brand
class EnhancedCategoryCard extends StatefulWidget {
  final String name;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? subtitle;
  final int? bookCount;

  const EnhancedCategoryCard({
    super.key,
    required this.name,
    required this.icon,
    this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.subtitle,
    this.bookCount,
  });

  @override
  State<EnhancedCategoryCard> createState() => _EnhancedCategoryCardState();
}

class _EnhancedCategoryCardState extends State<EnhancedCategoryCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _elevationAnimation = Tween<double>(
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

  void _onTapDown() {
    setState(() => _isHovered = true);
    _scaleController.forward();
  }

  void _onTapUp() {
    setState(() => _isHovered = false);
    _scaleController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isHovered = false);
    _scaleController.reverse();
  }

  Color _getCategoryColor(String categoryName, ThemeData theme) {
    // Return different colors based on category for visual variety
    switch (categoryName.toLowerCase()) {
      case 'fiction':
        return Colors.deepPurple.shade300;
      case 'mystery':
        return Colors.indigo.shade400;
      case 'romance':
        return Colors.pink.shade300;
      case 'sci-fi':
      case 'science fiction':
        return Colors.cyan.shade400;
      case 'biography':
        return Colors.brown.shade400;
      case 'business':
        return Colors.green.shade400;
      case 'fantasy':
        return Colors.purple.shade400;
      case 'thriller':
        return Colors.red.shade400;
      case 'history':
        return Colors.amber.shade600;
      case 'self-help':
        return Colors.teal.shade400;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = widget.backgroundColor ?? 
        _getCategoryColor(widget.name, theme);
    final effectiveIconColor = widget.iconColor ?? Colors.white;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedBuilder(
            animation: _elevationAnimation,
            builder: (context, child) {
              return Card(
                elevation: _elevationAnimation.value,
                shadowColor: categoryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    onTapDown: (_) => _onTapDown(),
                    onTapUp: (_) => _onTapUp(),
                    onTapCancel: _onTapCancel,
                    borderRadius: BorderRadius.circular(16),
                    splashColor: effectiveIconColor.withOpacity(0.1),
                    highlightColor: effectiveIconColor.withOpacity(0.05),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            categoryColor,
                            categoryColor.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Subtle shimmer effect when hovered
                          if (_isHovered)
                            AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, child) {
                                return Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        begin: Alignment(-1.0 + (2.0 * _shimmerController.value), 0.0),
                                        end: Alignment(1.0 + (2.0 * _shimmerController.value), 0.0),
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withOpacity(0.1),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          
                          // Main content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Icon with enhanced styling
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: effectiveIconColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: effectiveIconColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    widget.icon,
                                    size: 28,
                                    color: effectiveIconColor,
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Category name
                                Text(
                                  widget.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: effectiveIconColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                
                                // Subtitle or book count
                                if (widget.subtitle != null || widget.bookCount != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.subtitle ?? 
                                        '${widget.bookCount} book${(widget.bookCount ?? 0) == 1 ? '' : 's'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: effectiveIconColor.withOpacity(0.8),
                                      fontSize: 11,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Enhanced categories grid with improved layout and spacing
class EnhancedCategoriesGrid extends StatelessWidget {
  final List<CategoryData> categories;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final Function(CategoryData)? onCategoryTap;

  const EnhancedCategoriesGrid({
    super.key,
    required this.categories,
    this.crossAxisCount = 3,
    this.childAspectRatio = 1.1,
    this.padding,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return EnhancedCategoryCard(
            name: category.name,
            icon: category.icon,
            backgroundColor: category.backgroundColor,
            iconColor: category.iconColor,
            subtitle: category.subtitle,
            bookCount: category.bookCount,
            onTap: () => onCategoryTap?.call(category),
          );
        },
      ),
    );
  }
}

/// Data class for category information
class CategoryData {
  final String name;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? subtitle;
  final int? bookCount;

  const CategoryData({
    required this.name,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    this.subtitle,
    this.bookCount,
  });

  // Common categories for audiobooks
  static List<CategoryData> get defaultCategories => [
    const CategoryData(
      name: 'Fiction',
      icon: Icons.auto_stories_rounded,
      bookCount: 1247,
    ),
    const CategoryData(
      name: 'Mystery',
      icon: Icons.search_rounded,
      bookCount: 523,
    ),
    const CategoryData(
      name: 'Romance',
      icon: Icons.favorite_rounded,
      bookCount: 789,
    ),
    const CategoryData(
      name: 'Sci-Fi',
      icon: Icons.rocket_launch_rounded,
      bookCount: 456,
    ),
    const CategoryData(
      name: 'Biography',
      icon: Icons.person_rounded,
      bookCount: 334,
    ),
    const CategoryData(
      name: 'Business',
      icon: Icons.business_rounded,
      bookCount: 612,
    ),
    const CategoryData(
      name: 'Fantasy',
      icon: Icons.castle_rounded,
      bookCount: 891,
    ),
    const CategoryData(
      name: 'Thriller',
      icon: Icons.bolt_rounded,
      bookCount: 445,
    ),
    const CategoryData(
      name: 'History',
      icon: Icons.history_edu_rounded,
      bookCount: 298,
    ),
  ];
}