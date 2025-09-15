import 'package:flutter/material.dart';

class SnackBarUtils {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle_outline,
      duration: duration,
      action: action,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Theme.of(context).colorScheme.error,
      icon: Icons.error_outline,
      duration: duration,
      action: action,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.orange,
      icon: Icons.warning_outlined,
      duration: duration,
      action: action,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Theme.of(context).colorScheme.primary,
      icon: Icons.info_outline,
      duration: duration,
      action: action,
    );
  }

  static void showNetworkError(BuildContext context) {
    showError(
      context,
      'No internet connection. Please check your network.',
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () {
          // Can be overridden by caller
        },
      ),
    );
  }

  static void showPurchaseSuccess(
    BuildContext context,
    String bookTitle,
  ) {
    showSuccess(
      context,
      '"$bookTitle" purchased successfully!',
    );
  }

  static void showDownloadComplete(
    BuildContext context,
    String bookTitle,
  ) {
    showSuccess(
      context,
      '"$bookTitle" download completed!',
    );
  }

  static void showWishlistAdded(
    BuildContext context,
    String bookTitle,
  ) {
    showSuccess(
      context,
      '"$bookTitle" added to wishlist',
    );
  }

  static void showWishlistRemoved(
    BuildContext context,
    String bookTitle,
  ) {
    showInfo(
      context,
      '"$bookTitle" removed from wishlist',
    );
  }

  static void _showSnackBar(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    // Hide current snackbar if any
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: action,
      ),
    );
  }
}
