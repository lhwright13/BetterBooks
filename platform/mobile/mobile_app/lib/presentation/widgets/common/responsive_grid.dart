import 'package:flutter/material.dart';
import '../../../core/utils/responsive_utils.dart';

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double maxItemWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.maxItemWidth = 300,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = padding != null 
        ? screenWidth - padding!.horizontal
        : screenWidth;
    
    // Calculate optimal number of columns
    int crossAxisCount = (availableWidth / minItemWidth).floor();
    crossAxisCount = crossAxisCount.clamp(1, double.infinity).toInt();
    
    // Ensure items don't exceed maximum width
    final itemWidth = (availableWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
    if (itemWidth > maxItemWidth) {
      crossAxisCount = ((availableWidth + crossAxisSpacing) / (maxItemWidth + crossAxisSpacing)).floor();
      crossAxisCount = crossAxisCount.clamp(1, double.infinity).toInt();
    }

    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: _calculateAspectRatio(context),
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  double _calculateAspectRatio(BuildContext context) {
    // Default aspect ratio, can be overridden
    if (ResponsiveUtils.isTablet(context)) {
      return 0.75; // Slightly taller for tablets
    } else {
      return 0.85; // Standard phone ratio
    }
  }
}

class ResponsiveSliverGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double maxItemWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double? childAspectRatio;

  const ResponsiveSliverGrid({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.maxItemWidth = 300,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate optimal number of columns
    int crossAxisCount = (screenWidth / minItemWidth).floor();
    crossAxisCount = crossAxisCount.clamp(1, double.infinity).toInt();
    
    // Ensure items don't exceed maximum width
    final itemWidth = (screenWidth - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
    if (itemWidth > maxItemWidth) {
      crossAxisCount = ((screenWidth + crossAxisSpacing) / (maxItemWidth + crossAxisSpacing)).floor();
      crossAxisCount = crossAxisCount.clamp(1, double.infinity).toInt();
    }

    return SliverGrid(
      delegate: SliverChildListDelegate(children),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio ?? _calculateAspectRatio(context),
      ),
    );
  }

  double _calculateAspectRatio(BuildContext context) {
    if (ResponsiveUtils.isTablet(context)) {
      return 0.75;
    } else {
      return 0.85;
    }
  }
}

class ResponsiveStaggeredGrid extends StatelessWidget {
  final List<Widget> children;
  final int minCrossAxisCount;
  final int maxCrossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveStaggeredGrid({
    super.key,
    required this.children,
    this.minCrossAxisCount = 2,
    this.maxCrossAxisCount = 4,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    int crossAxisCount;
    
    if (ResponsiveUtils.isTablet(context)) {
      crossAxisCount = maxCrossAxisCount;
    } else if (ResponsiveUtils.isDesktop(context)) {
      crossAxisCount = maxCrossAxisCount;
    } else {
      crossAxisCount = minCrossAxisCount;
    }

    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: 1.0, // Square items for staggered layout
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}
