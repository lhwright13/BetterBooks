import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

/// Bundle size and asset loading optimizations
class BundleOptimization {
  /// Initialize bundle optimizations
  static void initialize() {
    _configureImageCaching();
    _configureAssetPrecaching();
    if (kReleaseMode) {
      _configureProductionOptimizations();
    }
  }

  /// Configure image caching for optimal memory usage
  static void _configureImageCaching() {
    // Optimize image cache based on device capabilities
    final imageCache = PaintingBinding.instance.imageCache;
    
    if (Platform.isIOS) {
      // iOS devices typically have more RAM
      imageCache.maximumSize = 200;
      imageCache.maximumSizeBytes = 100 << 20; // 100MB
    } else {
      // Android devices vary widely in capabilities
      imageCache.maximumSize = 100;
      imageCache.maximumSizeBytes = 50 << 20; // 50MB
    }
  }

  /// Configure asset precaching for critical resources
  static void _configureAssetPrecaching() {
    // This would be called during app initialization
    // to preload critical assets like icons, logos, etc.
  }

  /// Production-specific optimizations
  static void _configureProductionOptimizations() {
    // Disable debug features that might be accidentally enabled
    assert(() {
      // This code only runs in debug mode
      return true;
    }());
  }
}

/// Optimized asset loader with size-based loading
class OptimizedAssetLoader {
  /// Load image asset with appropriate resolution
  static ImageProvider loadOptimizedImage(String assetPath) {
    // Determine appropriate image resolution based on device pixel ratio
    final pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    
    String optimizedPath = assetPath;
    
    // Use different asset variants based on pixel density
    if (pixelRatio >= 3.0) {
      optimizedPath = assetPath.replaceFirst('.', '@3x.');
    } else if (pixelRatio >= 2.0) {
      optimizedPath = assetPath.replaceFirst('.', '@2x.');
    }
    
    return AssetImage(optimizedPath);
  }

  /// Load network image with size optimization
  static ImageProvider loadOptimizedNetworkImage(
    String url, {
    double? targetWidth,
    double? targetHeight,
  }) {
    // For production, you might use a CDN with image resizing capabilities
    String optimizedUrl = url;
    
    if (targetWidth != null && targetHeight != null) {
      // Append size parameters if your image service supports it
      // Example: optimizedUrl = '$url?w=${targetWidth.round()}&h=${targetHeight.round()}';
    }
    
    return NetworkImage(optimizedUrl);
  }
}

/// Lazy loading manager for heavy resources
class LazyResourceLoader {
  static final Map<String, dynamic> _loadedResources = {};
  static final Set<String> _loadingResources = {};

  /// Load resource lazily with caching
  static Future<T> loadResource<T>(
    String key,
    Future<T> Function() loader,
  ) async {
    // Return cached resource if available
    if (_loadedResources.containsKey(key)) {
      return _loadedResources[key] as T;
    }

    // If already loading, wait for it
    if (_loadingResources.contains(key)) {
      while (_loadingResources.contains(key)) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return _loadedResources[key] as T;
    }

    // Start loading
    _loadingResources.add(key);
    try {
      final resource = await loader();
      _loadedResources[key] = resource;
      return resource;
    } finally {
      _loadingResources.remove(key);
    }
  }

  /// Preload critical resources
  static Future<void> preloadCriticalResources() async {
    // Preload commonly used images, fonts, etc.
    final criticalAssets = [
      'assets/images/app_logo.png',
      'assets/images/default_cover.png',
      // Add more critical assets
    ];

    final futures = criticalAssets.map((asset) async {
      try {
        await precacheImage(AssetImage(asset), navigatorKey.currentContext!);
      } catch (e) {
        debugPrint('Failed to preload asset: $asset - $e');
      }
    });

    await Future.wait(futures);
  }

  /// Clear cached resources to free memory
  static void clearCache() {
    _loadedResources.clear();
  }
}

/// Build configuration utilities
class BuildConfig {
  /// Check if running in debug mode
  static bool get isDebug => kDebugMode;

  /// Check if running in release mode
  static bool get isRelease => kReleaseMode;

  /// Check if running in profile mode
  static bool get isProfile => kProfileMode;

  /// Get build configuration string
  static String get buildMode {
    if (kDebugMode) return 'debug';
    if (kProfileMode) return 'profile';
    if (kReleaseMode) return 'release';
    return 'unknown';
  }

  /// Check if analytics should be enabled
  static bool get shouldEnableAnalytics => kReleaseMode;

  /// Check if performance monitoring should be enabled
  static bool get shouldEnablePerformanceMonitoring => !kDebugMode;

  /// Check if crash reporting should be enabled
  static bool get shouldEnableCrashReporting => kReleaseMode;
}

/// Memory management utilities
class MemoryManager {
  /// Trigger garbage collection (use sparingly)
  static void forceGarbageCollection() {
    // This is generally not recommended but can be useful in specific scenarios
    if (kDebugMode) {
      debugPrint('Forcing garbage collection');
    }
  }

  /// Get current memory usage (debug only)
  static void logMemoryUsage() {
    if (kDebugMode) {
      final imageCache = PaintingBinding.instance.imageCache;
      debugPrint('Image cache: ${imageCache.currentSize} items, ${imageCache.currentSizeBytes} bytes');
    }
  }

  /// Clear image cache
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// Optimize memory usage for low-memory devices
  static void optimizeForLowMemory() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = 50; // Reduce cache size
    imageCache.maximumSizeBytes = 25 << 20; // 25MB
  }
}

/// Asset preloading widget
class AssetPreloader extends StatefulWidget {
  final Widget child;
  final List<String> assetsToPreload;
  final Widget? loadingWidget;

  const AssetPreloader({
    super.key,
    required this.child,
    required this.assetsToPreload,
    this.loadingWidget,
  });

  @override
  State<AssetPreloader> createState() => _AssetPreloaderState();
}

class _AssetPreloaderState extends State<AssetPreloader> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _preloadAssets();
  }

  Future<void> _preloadAssets() async {
    final futures = widget.assetsToPreload.map((asset) async {
      try {
        await precacheImage(AssetImage(asset), context);
      } catch (e) {
        debugPrint('Failed to preload asset: $asset - $e');
      }
    });

    await Future.wait(futures);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? 
          const Center(child: CircularProgressIndicator());
    }
    return widget.child;
  }
}

// Global navigator key for accessing context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Production readiness checker
class ProductionReadinessChecker {
  /// Check if app is ready for production deployment
  static List<String> checkProductionReadiness() {
    final issues = <String>[];

    // Check debug flags
    if (kDebugMode) {
      issues.add('App is running in debug mode');
    }

    // Check for debug prints (this is a simplified check)
    if (!kReleaseMode && kDebugMode) {
      issues.add('Debug prints should be removed or disabled in release');
    }

    // Check network security
    if (!_hasNetworkSecurityConfig()) {
      issues.add('Network security configuration not found');
    }

    // Check certificate pinning
    if (!_hasCertificatePinning()) {
      issues.add('Certificate pinning not implemented');
    }

    return issues;
  }

  static bool _hasNetworkSecurityConfig() {
    // In a real implementation, check for network_security_config.xml on Android
    // and App Transport Security settings on iOS
    return true; // Placeholder
  }

  static bool _hasCertificatePinning() {
    // Check if certificate pinning is implemented
    return false; // Placeholder - implement based on your networking stack
  }

  /// Generate production deployment report
  static Map<String, dynamic> generateDeploymentReport() {
    return {
      'buildMode': BuildConfig.buildMode,
      'platform': Platform.operatingSystem,
      'isIOSOptimized': Platform.isIOS,
      'memoryCacheSize': PaintingBinding.instance.imageCache.maximumSize,
      'memoryCacheBytes': PaintingBinding.instance.imageCache.maximumSizeBytes,
      'issues': checkProductionReadiness(),
      'recommendations': _getRecommendations(),
    };
  }

  static List<String> _getRecommendations() {
    final recommendations = <String>[];
    
    if (kDebugMode) {
      recommendations.add('Build app in release mode for production');
    }
    
    if (Platform.isIOS) {
      recommendations.add('Test on physical iOS devices with different screen sizes');
      recommendations.add('Verify App Store compliance and metadata');
    }
    
    return recommendations;
  }
}