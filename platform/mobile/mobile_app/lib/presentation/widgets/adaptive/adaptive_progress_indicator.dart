import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

/// Adaptive circular progress indicator
class AdaptiveCircularProgressIndicator extends StatelessWidget {
  final double? value;
  final Color? color;
  final double strokeWidth;
  final double radius;

  const AdaptiveCircularProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.strokeWidth = 4.0,
    this.radius = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoActivityIndicator(
        color: color ?? CupertinoColors.activeBlue,
        radius: radius,
      );
    } else {
      return CircularProgressIndicator(
        value: value,
        color: color,
        strokeWidth: strokeWidth,
      );
    }
  }

  /// Small size indicator
  factory AdaptiveCircularProgressIndicator.small({
    Color? color,
  }) {
    return AdaptiveCircularProgressIndicator(
      color: color,
      radius: 8.0,
      strokeWidth: 2.0,
    );
  }

  /// Large size indicator
  factory AdaptiveCircularProgressIndicator.large({
    Color? color,
  }) {
    return AdaptiveCircularProgressIndicator(
      color: color,
      radius: 15.0,
      strokeWidth: 6.0,
    );
  }
}

/// Adaptive linear progress indicator
class AdaptiveLinearProgressIndicator extends StatelessWidget {
  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double minHeight;

  const AdaptiveLinearProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.minHeight = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      // Use a custom iOS-style linear progress indicator
      return Container(
        height: minHeight,
        decoration: BoxDecoration(
          color: backgroundColor ?? CupertinoColors.systemFill,
          borderRadius: BorderRadius.circular(minHeight / 2),
        ),
        child: value != null
            ? FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value!.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color ?? CupertinoColors.activeBlue,
                    borderRadius: BorderRadius.circular(minHeight / 2),
                  ),
                ),
              )
            : _buildIndeterminateProgress(),
      );
    } else {
      return LinearProgressIndicator(
        value: value,
        color: color,
        backgroundColor: backgroundColor,
        minHeight: minHeight,
      );
    }
  }

  Widget _buildIndeterminateProgress() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 2),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 0.3,
          child: Container(
            decoration: BoxDecoration(
              color: color ?? CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(minHeight / 2),
            ),
            transform: Matrix4.translationValues(
              (MediaQuery.of(context).size.width - 100) * value,
              0.0,
              0.0,
            ),
          ),
        );
      },
    );
  }
}

/// Adaptive refresh indicator for pull-to-refresh
class AdaptiveRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  const AdaptiveRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CustomScrollView(
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
          ),
          SliverToBoxAdapter(child: child),
        ],
      );
    } else {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: color,
        child: child,
      );
    }
  }
}

/// Adaptive loading overlay
class AdaptiveLoadingOverlay extends StatelessWidget {
  final bool isVisible;
  final Widget child;
  final String? message;
  final Color? backgroundColor;

  const AdaptiveLoadingOverlay({
    super.key,
    required this.isVisible,
    required this.child,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isVisible)
          Container(
            color: backgroundColor ??
                (Platform.isIOS
                    ? CupertinoColors.systemBackground.withOpacity(0.8)
                    : Colors.black.withOpacity(0.5)),
            child: Center(
              child: Platform.isIOS
                  ? _buildCupertinoLoadingCard(context)
                  : _buildMaterialLoadingCard(context),
            ),
          ),
      ],
    );
  }

  Widget _buildCupertinoLoadingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 15),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: CupertinoTheme.of(context).textTheme.textStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaterialLoadingCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Adaptive switch/toggle
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor ?? CupertinoColors.activeGreen,
      );
    } else {
      return Switch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      );
    }
  }
}

/// Adaptive checkbox
class AdaptiveCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const AdaptiveCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return GestureDetector(
        onTap: () => onChanged(!value),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value
                ? (activeColor ?? CupertinoColors.activeBlue)
                : CupertinoColors.systemBackground,
            border: value
                ? null
                : Border.all(
                    color: CupertinoColors.systemGrey,
                    width: 1.5,
                  ),
          ),
          child: value
              ? const Icon(
                  CupertinoIcons.check_mark,
                  size: 14,
                  color: CupertinoColors.white,
                )
              : null,
        ),
      );
    } else {
      return Checkbox(
        value: value,
        onChanged: (bool? newValue) => onChanged(newValue ?? false),
        activeColor: activeColor,
      );
    }
  }
}