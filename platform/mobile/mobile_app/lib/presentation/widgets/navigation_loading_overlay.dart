import 'package:flutter/material.dart';

/// Loading overlay for navigation transitions and long operations
/// Provides visual feedback during navigation and prevents user interaction
class NavigationLoadingOverlay extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingText;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final double opacity;
  final Duration animationDuration;
  
  const NavigationLoadingOverlay({
    super.key,
    required this.child,
    this.isLoading = false,
    this.loadingText,
    this.backgroundColor,
    this.indicatorColor,
    this.opacity = 0.7,
    this.animationDuration = const Duration(milliseconds: 300),
  });
  
  @override
  State<NavigationLoadingOverlay> createState() => _NavigationLoadingOverlayState();
}

class _NavigationLoadingOverlayState extends State<NavigationLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void didUpdateWidget(NavigationLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            if (_fadeAnimation.value == 0) {
              return const SizedBox.shrink();
            }
            
            return IgnorePointer(
              ignoring: !widget.isLoading,
              child: Container(
                color: (widget.backgroundColor ?? Colors.black)
                    .withOpacity(widget.opacity * _fadeAnimation.value),
                child: Center(
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildLoadingContent(context),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildLoadingContent(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: widget.indicatorColor ?? Theme.of(context).colorScheme.primary,
            strokeWidth: 3,
          ),
          if (widget.loadingText != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.loadingText!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Global navigation loading manager
/// Manages loading states across navigation actions
class NavigationLoadingManager extends ChangeNotifier {
  static final NavigationLoadingManager _instance = NavigationLoadingManager._internal();
  factory NavigationLoadingManager() => _instance;
  NavigationLoadingManager._internal();
  
  bool _isLoading = false;
  String? _loadingText;
  
  bool get isLoading => _isLoading;
  String? get loadingText => _loadingText;
  
  /// Show loading overlay
  void showLoading({String? text}) {
    _isLoading = true;
    _loadingText = text;
    notifyListeners();
  }
  
  /// Hide loading overlay
  void hideLoading() {
    _isLoading = false;
    _loadingText = null;
    notifyListeners();
  }
  
  /// Show loading for a specific duration
  void showLoadingForDuration({
    required Duration duration,
    String? text,
  }) {
    showLoading(text: text);
    Future.delayed(duration, () {
      hideLoading();
    });
  }
}

/// Widget that automatically manages navigation loading states
class NavigationLoadingWrapper extends StatelessWidget {
  final Widget child;
  final NavigationLoadingManager? manager;
  
  const NavigationLoadingWrapper({
    super.key,
    required this.child,
    this.manager,
  });
  
  @override
  Widget build(BuildContext context) {
    final loadingManager = manager ?? NavigationLoadingManager();
    
    return AnimatedBuilder(
      animation: loadingManager,
      builder: (context, _) {
        return NavigationLoadingOverlay(
          isLoading: loadingManager.isLoading,
          loadingText: loadingManager.loadingText,
          child: child,
        );
      },
    );
  }
}

/// Navigation loading state for specific operations
enum NavigationLoadingState {
  idle,
  navigating,
  loading,
  error,
}

/// Extended navigation loading manager with states
class ExtendedNavigationLoadingManager extends ChangeNotifier {
  NavigationLoadingState _state = NavigationLoadingState.idle;
  String? _message;
  Object? _error;
  
  NavigationLoadingState get state => _state;
  String? get message => _message;
  Object? get error => _error;
  bool get isLoading => _state == NavigationLoadingState.loading || 
                       _state == NavigationLoadingState.navigating;
  
  /// Set navigating state
  void setNavigating({String? message}) {
    _state = NavigationLoadingState.navigating;
    _message = message ?? 'Navigating...';
    _error = null;
    notifyListeners();
  }
  
  /// Set loading state
  void setLoading({String? message}) {
    _state = NavigationLoadingState.loading;
    _message = message ?? 'Loading...';
    _error = null;
    notifyListeners();
  }
  
  /// Set error state
  void setError(Object error, {String? message}) {
    _state = NavigationLoadingState.error;
    _message = message ?? 'An error occurred';
    _error = error;
    notifyListeners();
  }
  
  /// Set idle state
  void setIdle() {
    _state = NavigationLoadingState.idle;
    _message = null;
    _error = null;
    notifyListeners();
  }
  
  /// Execute an operation with loading state
  Future<T> executeWithLoading<T>(
    Future<T> Function() operation, {
    String? loadingMessage,
  }) async {
    try {
      setLoading(message: loadingMessage);
      final result = await operation();
      setIdle();
      return result;
    } catch (error) {
      setError(error);
      rethrow;
    }
  }
}