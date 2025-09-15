import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

/// Adaptive button that switches between Material and Cupertino based on platform
class AdaptiveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isDestructive;
  final bool isSecondary;
  final double? minWidth;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.isDestructive = false,
    this.isSecondary = false,
    this.minWidth,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoButton(context);
    } else {
      return _buildMaterialButton(context);
    }
  }

  Widget _buildCupertinoButton(BuildContext context) {
    if (isSecondary) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.actionTextStyle.copyWith(
            color: isDestructive
                ? CupertinoColors.destructiveRed
                : foregroundColor ?? CupertinoColors.activeBlue,
          ),
          child: child,
        ),
      );
    } else {
      return CupertinoButton.filled(
        onPressed: onPressed,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        color: isDestructive
            ? CupertinoColors.destructiveRed
            : backgroundColor ?? CupertinoColors.activeBlue,
        child: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.actionTextStyle.copyWith(
            color: foregroundColor ?? CupertinoColors.white,
          ),
          child: child,
        ),
      );
    }
  }

  Widget _buildMaterialButton(BuildContext context) {
    if (isSecondary) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDestructive
              ? Theme.of(context).colorScheme.error
              : foregroundColor ?? Theme.of(context).colorScheme.primary,
          side: BorderSide(
            color: isDestructive
                ? Theme.of(context).colorScheme.error
                : foregroundColor ?? Theme.of(context).colorScheme.primary,
          ),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          minimumSize: minWidth != null ? Size(minWidth!, 0) : null,
        ),
        child: child,
      );
    } else {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive
              ? Theme.of(context).colorScheme.error
              : backgroundColor ?? Theme.of(context).colorScheme.primary,
          foregroundColor: isDestructive
              ? Theme.of(context).colorScheme.onError
              : foregroundColor ?? Theme.of(context).colorScheme.onPrimary,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          minimumSize: minWidth != null ? Size(minWidth!, 0) : null,
        ),
        child: child,
      );
    }
  }

  /// Factory constructor for primary button
  factory AdaptiveButton.primary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    Color? backgroundColor,
    Color? foregroundColor,
    double? minWidth,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return AdaptiveButton(
      key: key,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minWidth: minWidth,
      padding: padding,
      borderRadius: borderRadius,
      child: child,
    );
  }

  /// Factory constructor for secondary button
  factory AdaptiveButton.secondary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    Color? foregroundColor,
    double? minWidth,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return AdaptiveButton(
      key: key,
      onPressed: onPressed,
      foregroundColor: foregroundColor,
      minWidth: minWidth,
      padding: padding,
      borderRadius: borderRadius,
      isSecondary: true,
      child: child,
    );
  }

  /// Factory constructor for destructive button
  factory AdaptiveButton.destructive({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    bool isSecondary = false,
    double? minWidth,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return AdaptiveButton(
      key: key,
      onPressed: onPressed,
      minWidth: minWidth,
      padding: padding,
      borderRadius: borderRadius,
      isDestructive: true,
      isSecondary: isSecondary,
      child: child,
    );
  }
}

/// Adaptive icon button that switches between Material and Cupertino
class AdaptiveIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? color;
  final double? iconSize;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;

  const AdaptiveIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.color,
    this.iconSize,
    this.tooltip,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: padding ?? const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: color ?? CupertinoColors.activeBlue,
          size: iconSize ?? 24,
        ),
      );
    } else {
      return IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: color,
        iconSize: iconSize,
        tooltip: tooltip,
        padding: padding ?? const EdgeInsets.all(8),
      );
    }
  }
}