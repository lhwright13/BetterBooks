import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? subtitle;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final IconData? icon;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.subtitle,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
    this.onConfirm,
    this.onCancel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              size: 32,
              color: isDestructive
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            )
          : null,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (subtitle?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
          style: isDestructive
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          child: Text(confirmText),
        ),
      ],
    );
  }

  /// Show a confirmation dialog and return the result
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String? subtitle,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        subtitle: subtitle,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
  }

  /// Show a purchase confirmation dialog
  static Future<bool?> showPurchaseConfirmation(
    BuildContext context, {
    required String bookTitle,
    required int creditCost,
  }) {
    return show(
      context,
      title: 'Purchase Book',
      message: 'Purchase "$bookTitle"?',
      subtitle: 'This will use $creditCost credit${creditCost == 1 ? '' : 's'} from your account.',
      confirmText: 'Purchase',
      icon: Icons.shopping_cart,
    );
  }

  /// Show a delete confirmation dialog
  static Future<bool?> showDeleteConfirmation(
    BuildContext context, {
    required String itemName,
    String itemType = 'item',
  }) {
    return show(
      context,
      title: 'Delete $itemType',
      message: 'Are you sure you want to delete "$itemName"?',
      subtitle: 'This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline,
    );
  }

  /// Show a logout confirmation dialog
  static Future<bool?> showLogoutConfirmation(BuildContext context) {
    return show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      subtitle: 'You will need to sign in again to access your library.',
      confirmText: 'Sign Out',
      icon: Icons.logout,
    );
  }
}
