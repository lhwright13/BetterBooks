import 'package:flutter/material.dart';

/// Overlay widget for displaying loading state with optional message and cancellation
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isVisible;
  final VoidCallback? onCancel;
  final Color? backgroundColor;
  final Color? progressColor;
  final double? progress;
  final Widget? child;

  const LoadingOverlay({
    super.key,
    this.message,
    this.isVisible = true,
    this.onCancel,
    this.backgroundColor,
    this.progressColor,
    this.progress,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return child ?? const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (child != null) child!,
        
        // Overlay background
        Container(
          color: backgroundColor ?? Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: _buildLoadingContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Loading indicator
          SizedBox(
            width: 48,
            height: 48,
            child: progress != null
                ? CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    color: progressColor ?? colorScheme.primary,
                    backgroundColor: colorScheme.outline.withValues(alpha: 0.3),
                  )
                : CircularProgressIndicator(
                    strokeWidth: 3,
                    color: progressColor ?? colorScheme.primary,
                  ),
          ),

          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          if (progress != null) ...[
            const SizedBox(height: 16),
            Text(
              '${(progress! * 100).round()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          if (onCancel != null) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: onCancel,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline loading indicator for use within other widgets
class InlineLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool isCompact;

  const InlineLoadingIndicator({
    super.key,
    this.message,
    this.size = 24,
    this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color ?? colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(width: 12),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size > 30 ? 3 : 2,
            color: color ?? colorScheme.primary,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Skeleton loader for content placeholders
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Duration duration;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutSine,
    ));
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.5, 1.0],
              colors: [
                colorScheme.outline.withValues(alpha: 0.1),
                colorScheme.outline.withValues(alpha: 0.3),
                colorScheme.outline.withValues(alpha: 0.1),
              ],
              transform: GradientRotation(_animation.value),
            ),
          ),
        );
      },
    );
  }
}

/// Collection of skeleton loaders for common UI patterns
class SkeletonLoaders {
  /// List item skeleton (avatar + text lines)
  static Widget listItem({
    bool hasAvatar = true,
    int textLines = 2,
    double height = 80,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (hasAvatar) ...[
            SkeletonLoader(
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(24),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
                if (textLines > 1) ...[
                  const SizedBox(height: 8),
                  SkeletonLoader(
                    width: 200,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
                if (textLines > 2) ...[
                  const SizedBox(height: 8),
                  SkeletonLoader(
                    width: 150,
                    height: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card skeleton (image + text)
  static Widget card({
    double width = 200,
    double height = 280,
    double imageHeight = 160,
  }) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(
            width: width,
            height: imageHeight,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 12),
          SkeletonLoader(
            width: width,
            height: 16,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          SkeletonLoader(
            width: width * 0.7,
            height: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  /// Text block skeleton
  static Widget textBlock({
    int lines = 3,
    double spacing = 8,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        final width = isLast ? 0.6 : (0.8 + (index % 2) * 0.2);
        
        return Column(
          children: [
            if (index > 0) SizedBox(height: spacing),
            SkeletonLoader(
              width: double.infinity,
              height: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      }),
    );
  }
}