import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

/// Adaptive dialog that uses platform-appropriate styling
class AdaptiveDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final List<AdaptiveDialogAction> actions;
  final IconData? icon;

  const AdaptiveDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    required this.actions,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoDialog(context);
    } else {
      return _buildMaterialDialog(context);
    }
  }

  Widget _buildCupertinoDialog(BuildContext context) {
    return CupertinoAlertDialog(
      title: icon != null
          ? Column(
              children: [
                Icon(icon, size: 32, color: CupertinoColors.activeBlue),
                const SizedBox(height: 8),
                Text(title),
              ],
            )
          : Text(title),
      content: content ??
          (message != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(message!),
                )
              : null),
      actions: actions
          .map((action) => CupertinoDialogAction(
                onPressed: action.onPressed,
                isDestructiveAction: action.isDestructive,
                isDefaultAction: action.isDefault,
                child: Text(action.label),
              ))
          .toList(),
    );
  }

  Widget _buildMaterialDialog(BuildContext context) {
    return AlertDialog(
      icon: icon != null ? Icon(icon, size: 32) : null,
      title: Text(title),
      content: content ??
          (message != null
              ? Text(message!)
              : null),
      actions: actions
          .map((action) => action.isDestructive
              ? TextButton(
                  onPressed: action.onPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(action.label),
                )
              : action.isDefault
                  ? ElevatedButton(
                      onPressed: action.onPressed,
                      child: Text(action.label),
                    )
                  : TextButton(
                      onPressed: action.onPressed,
                      child: Text(action.label),
                    ))
          .toList(),
    );
  }

  /// Show platform-appropriate dialog
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    required List<AdaptiveDialogAction> actions,
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AdaptiveDialog(
        title: title,
        message: message,
        content: content,
        actions: actions,
        icon: icon,
      ),
    );
  }

  /// Show confirmation dialog
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return show<bool>(
      context,
      title: title,
      message: message,
      icon: icon,
      actions: [
        AdaptiveDialogAction(
          label: cancelText,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AdaptiveDialogAction(
          label: confirmText,
          isDefault: !isDestructive,
          isDestructive: isDestructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

/// Action sheet that shows iOS-style options from bottom
class AdaptiveActionSheet extends StatelessWidget {
  final String? title;
  final String? message;
  final List<AdaptiveDialogAction> actions;
  final AdaptiveDialogAction? cancelAction;

  const AdaptiveActionSheet({
    super.key,
    this.title,
    this.message,
    required this.actions,
    this.cancelAction,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoActionSheet(
        title: title != null ? Text(title!) : null,
        message: message != null ? Text(message!) : null,
        actions: actions
            .map((action) => CupertinoActionSheetAction(
                  onPressed: action.onPressed ?? () {},
                  isDestructiveAction: action.isDestructive,
                  child: Text(action.label),
                ))
            .toList(),
        cancelButton: cancelAction != null
            ? CupertinoActionSheetAction(
                onPressed: cancelAction!.onPressed ?? () {},
                child: Text(cancelAction!.label),
              )
            : null,
      );
    } else {
      // For Android, use a bottom sheet with Material design
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null || message != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      if (message != null) ...[
                        if (title != null) const SizedBox(height: 8),
                        Text(
                          message!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ...actions.map((action) => ListTile(
                    title: Text(
                      action.label,
                      style: TextStyle(
                        color: action.isDestructive
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                    onTap: action.onPressed ?? () {},
                  )),
              if (cancelAction != null) ...[
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    cancelAction!.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: cancelAction!.onPressed ?? () {},
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  /// Show platform-appropriate action sheet
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? message,
    required List<AdaptiveDialogAction> actions,
    AdaptiveDialogAction? cancelAction,
  }) {
    if (Platform.isIOS) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => AdaptiveActionSheet(
          title: title,
          message: message,
          actions: actions,
          cancelAction: cancelAction,
        ),
      );
    } else {
      return showModalBottomSheet<T>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        builder: (context) => AdaptiveActionSheet(
          title: title,
          message: message,
          actions: actions,
          cancelAction: cancelAction,
        ),
      );
    }
  }
}

/// Action item for adaptive dialogs
class AdaptiveDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool isDefault;

  const AdaptiveDialogAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });
}