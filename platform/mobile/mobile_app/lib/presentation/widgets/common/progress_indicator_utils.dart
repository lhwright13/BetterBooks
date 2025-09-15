import 'package:flutter/material.dart';

class ProgressIndicatorUtils {
  /// Show a circular progress dialog that blocks user interaction
  static Future<T?> showProgressDialog<T>(
    BuildContext context, {
    required String message,
    bool barrierDismissible = false,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ProgressDialog(message: message),
    );
  }

  /// Show a progress dialog and execute an async operation
  static Future<T> showProgressDialogForOperation<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() operation,
    bool barrierDismissible = false,
  }) async {
    // Show the progress dialog
    showProgressDialog(
      context,
      message: message,
      barrierDismissible: barrierDismissible,
    );

    try {
      final result = await operation();
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss dialog
      }
      return result;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss dialog
      }
      rethrow;
    }
  }

  /// Hide the current progress dialog if any
  static void hideProgressDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

class ProgressDialog extends StatelessWidget {
  final String message;
  final double? progress; // null for indeterminate, 0.0-1.0 for determinate

  const ProgressDialog({
    super.key,
    required this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null)
              CircularProgressIndicator(value: progress)
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress! * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DownloadProgressWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String? title;
  final String? subtitle;
  final VoidCallback? onCancel;
  final bool showPercentage;

  const DownloadProgressWidget({
    super.key,
    required this.progress,
    this.title,
    this.subtitle,
    this.onCancel,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                ),
                if (showPercentage) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (onCancel != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
