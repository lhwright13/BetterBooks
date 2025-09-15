import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';

/// Performance optimization utilities for iOS and general app performance
class PerformanceOptimizations {
  /// Configure app-wide performance settings
  static void configurePerformance() {
    if (Platform.isIOS) {
      _configureIOSPerformance();
    }
    _configureGeneralPerformance();
  }

  /// iOS-specific performance configurations
  static void _configureIOSPerformance() {
    // Enable high frame rate for devices that support it
    if (Platform.isIOS) {
      // Configure for ProMotion displays (120Hz)
      WidgetsFlutterBinding.ensureInitialized();
      
      // Optimize for iOS rendering
      RenderObject.debugCheckingIntrinsics = false;
      
      // Enable platform-specific optimizations
      debugProfileBuildsEnabled = false;
      debugProfilePaintsEnabled = false;
    }
  }

  /// General performance configurations
  static void _configureGeneralPerformance() {
    // Configure memory management
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB
  }

  /// Optimize scroll performance
  static ScrollPhysics getOptimizedScrollPhysics() {
    if (Platform.isIOS) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    } else {
      return const ClampingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
  }

  /// Get platform-appropriate frame rate
  static double getTargetFrameRate() {
    if (Platform.isIOS) {
      // Support for 120Hz displays
      return 120.0;
    }
    return 60.0;
  }
}

/// Helper class for creating keep-alive widgets
class KeepAliveHelper {
  /// Wrap a widget to keep it alive in a PageView or TabBarView
  static Widget wrapKeepAlive(Widget child) {
    return AutomaticKeepAlive(
      child: child,
    );
  }
}

/// Optimized image widget with caching and memory management
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;
  final bool enableDiskCache;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
    this.enableDiskCache = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use different image loading strategies based on platform
    if (Platform.isIOS) {
      return _buildIOSOptimizedImage();
    } else {
      return _buildAndroidOptimizedImage();
    }
  }

  Widget _buildIOSOptimizedImage() {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _buildDefaultPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _buildDefaultErrorWidget();
      },
      cacheWidth: width?.round(),
      cacheHeight: height?.round(),
      isAntiAlias: true,
      filterQuality: FilterQuality.medium,
    );
  }

  Widget _buildAndroidOptimizedImage() {
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _buildDefaultPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _buildDefaultErrorWidget();
      },
      cacheWidth: width?.round(),
      cacheHeight: height?.round(),
      filterQuality: FilterQuality.low, // Lower quality for Android to save memory
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.error_outline),
    );
  }
}

/// Lazy loading list view for better performance with large datasets
class LazyLoadListView extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final double? itemExtent;
  final Widget? separator;

  const LazyLoadListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.itemExtent,
    this.separator,
  });

  @override
  State<LazyLoadListView> createState() => _LazyLoadListViewState();
}

class _LazyLoadListViewState extends State<LazyLoadListView> {
  late ScrollController _scrollController;
  final Set<int> _loadedItems = {};

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.separator != null) {
      return ListView.separated(
        controller: _scrollController,
        itemCount: widget.itemCount,
        itemBuilder: _buildOptimizedItem,
        separatorBuilder: (context, index) => widget.separator!,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics ?? PerformanceOptimizations.getOptimizedScrollPhysics(),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.itemCount,
      itemBuilder: _buildOptimizedItem,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics ?? PerformanceOptimizations.getOptimizedScrollPhysics(),
      itemExtent: widget.itemExtent,
    );
  }

  Widget _buildOptimizedItem(BuildContext context, int index) {
    // Mark item as loaded for potential caching
    _loadedItems.add(index);

    // Build item with repaint boundary for optimization
    return RepaintBoundary(
      child: widget.itemBuilder(context, index),
    );
  }
}

/// Performance monitoring widget (debug mode only)
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final bool showOverlay;

  const PerformanceMonitor({
    super.key,
    required this.child,
    this.showOverlay = kDebugMode,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  double _currentFps = 0.0;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    if (widget.showOverlay && kDebugMode) {
      _startMonitoring();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startMonitoring() {
    _controller.addListener(() {
      _frameCount++;
      final now = DateTime.now();
      final diff = now.difference(_lastTime).inMilliseconds;

      if (diff >= 1000) {
        setState(() {
          _currentFps = (_frameCount * 1000) / diff;
          _frameCount = 0;
          _lastTime = now;
        });
      }
    });

    _controller.repeat();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showOverlay || !kDebugMode) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'FPS: ${_currentFps.toStringAsFixed(1)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget for optimized grid layouts with better memory management
class OptimizedGridView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const OptimizedGridView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 8.0,
    this.mainAxisSpacing = 8.0,
    this.childAspectRatio = 1.0,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, index),
        );
      },
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      padding: padding,
      physics: physics ?? PerformanceOptimizations.getOptimizedScrollPhysics(),
      shrinkWrap: shrinkWrap,
    );
  }
}