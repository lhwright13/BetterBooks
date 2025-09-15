import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io';

/// iOS-specific navigation handler with native gestures and behavior
class IOSNavigationHandler {
  // Remove unused channel for now
  // static const MethodChannel _channel = MethodChannel('ios_navigation');

  /// Configure iOS-specific navigation behavior
  static void configureIOSNavigation() {
    if (Platform.isIOS) {
      // Enable swipe-back gesture system-wide
      SystemChannels.platform.invokeMethod('SystemNavigator.setSystemUIOverlayStyle', {
        'statusBarStyle': 'light',
        'systemNavigationBarColor': 0,
        'statusBarColor': 0,
        'systemNavigationBarIconBrightness': 'light',
        'statusBarIconBrightness': 'light',
      });
    }
  }

  /// Create iOS-style page route with swipe-back gesture
  static PageRoute<T> createIOSRoute<T extends Object?>({
    required Widget child,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    if (Platform.isIOS) {
      return CupertinoPageRoute<T>(
        builder: (context) => child,
        settings: settings,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      );
    } else {
      return MaterialPageRoute<T>(
        builder: (context) => child,
        settings: settings,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      );
    }
  }

  /// Enable haptic feedback for iOS
  static void triggerHapticFeedback(HapticFeedbackType type) {
    if (Platform.isIOS) {
      switch (type) {
        case HapticFeedbackType.light:
          HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.medium:
          HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.heavy:
          HapticFeedback.heavyImpact();
          break;
        case HapticFeedbackType.selection:
          HapticFeedback.selectionClick();
          break;
      }
    }
  }

  /// Get platform-appropriate back gesture
  static Widget buildBackGesture({
    required Widget child,
    required VoidCallback onBackGesture,
  }) {
    if (Platform.isIOS) {
      return GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe from left edge to go back
          if (details.primaryVelocity! > 0) {
            triggerHapticFeedback(HapticFeedbackType.light);
            onBackGesture();
          }
        },
        child: child,
      );
    }
    return child;
  }
}

/// Enum for haptic feedback types
enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}

/// iOS-style swipe back gesture detector
class IOSSwipeBackDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSwipeBack;
  final double swipeThreshold;

  const IOSSwipeBackDetector({
    super.key,
    required this.child,
    this.onSwipeBack,
    this.swipeThreshold = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS || onSwipeBack == null) {
      return child;
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final swipeDistance = details.globalPosition.dx;
        
        // Check if swipe started from left edge and moved right
        if (swipeDistance > screenWidth * swipeThreshold && details.primaryVelocity! > 0) {
          IOSNavigationHandler.triggerHapticFeedback(HapticFeedbackType.light);
          onSwipeBack!();
        }
      },
      child: child,
    );
  }
}

/// iOS-style context menu
class IOSContextMenu extends StatelessWidget {
  final Widget child;
  final List<IOSContextMenuAction> actions;
  final String? previewTitle;

  const IOSContextMenu({
    super.key,
    required this.child,
    required this.actions,
    this.previewTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return GestureDetector(
        onLongPressStart: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        child: child,
      );
    } else {
      // For Android, use Material context menu
      return GestureDetector(
        onLongPressStart: (details) {
          _showMaterialContextMenu(context, details.globalPosition);
        },
        child: child,
      );
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    IOSNavigationHandler.triggerHapticFeedback(HapticFeedbackType.medium);
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: previewTitle != null ? Text(previewTitle!) : null,
        actions: actions.map((action) => CupertinoActionSheetAction(
          onPressed: () {
            Navigator.of(context).pop();
            action.onPressed?.call();
          },
          isDestructiveAction: action.isDestructive,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (action.icon != null) ...[
                Icon(action.icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(action.title),
            ],
          ),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showMaterialContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: actions.map((action) => PopupMenuItem(
        child: ListTile(
          leading: action.icon != null ? Icon(action.icon) : null,
          title: Text(action.title),
          contentPadding: EdgeInsets.zero,
        ),
        onTap: action.onPressed,
      )).toList(),
    );
  }
}

/// Action item for iOS context menu
class IOSContextMenuAction {
  final String title;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const IOSContextMenuAction({
    required this.title,
    this.icon,
    this.onPressed,
    this.isDestructive = false,
  });
}

/// iOS-style pull-to-refresh implementation
class IOSPullToRefresh extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final String? semanticsLabel;

  const IOSPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.semanticsLabel,
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

/// iOS-style segmented control
class IOSSegmentedControl<T extends Object> extends StatelessWidget {
  final Map<T, Widget> children;
  final T? groupValue;
  final ValueChanged<T>? onValueChanged;
  final Color? selectedColor;
  final Color? unselectedColor;
  final EdgeInsetsGeometry padding;

  const IOSSegmentedControl({
    super.key,
    required this.children,
    this.groupValue,
    this.onValueChanged,
    this.selectedColor,
    this.unselectedColor,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return Padding(
        padding: padding,
        child: CupertinoSegmentedControl<T>(
          children: children,
          groupValue: groupValue,
          onValueChanged: onValueChanged ?? (T value) {},
          selectedColor: selectedColor,
          unselectedColor: unselectedColor,
        ),
      );
    } else {
      // For Android, create a custom segmented control
      return Padding(
        padding: padding,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: children.entries.map((entry) {
              final isSelected = groupValue == entry.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onValueChanged?.call(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (selectedColor ?? Theme.of(context).colorScheme.primary)
                          : (unselectedColor ?? Colors.transparent),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        child: entry.value,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }
  }
}

/// iOS-style navigation transition
class IOSNavigationTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const IOSNavigationTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }
}