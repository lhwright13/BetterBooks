import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/echowright_theme.dart';

/// Common error widgets for consistent error handling across the app
class ErrorWidgets {
  
  /// Generic error widget with retry functionality
  static Widget buildErrorWidget({
    required String message,
    VoidCallback? onRetry,
    String? retryText,
    IconData? icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: EchoWrightTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: EchoWrightTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryText ?? 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EchoWrightTheme.primaryTurquoise,
                  foregroundColor: EchoWrightTheme.textOnPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Network error widget
  static Widget buildNetworkError({VoidCallback? onRetry}) {
    return buildErrorWidget(
      message: 'Unable to connect to the server.\nPlease check your internet connection.',
      icon: Icons.wifi_off,
      onRetry: onRetry,
      retryText: 'Try Again',
    );
  }

  /// Authentication error widget  
  static Widget buildAuthError({VoidCallback? onSignIn}) {
    return buildErrorWidget(
      message: 'Authentication required.\nPlease sign in to continue.',
      icon: Icons.account_circle_outlined,
      onRetry: onSignIn,
      retryText: 'Sign In',
    );
  }

  /// Empty state widget
  static Widget buildEmptyState({
    required String message,
    String? actionText,
    VoidCallback? onAction,
    IconData? icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.library_books_outlined,
              size: 64,
              color: EchoWrightTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: EchoWrightTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EchoWrightTheme.primaryTurquoise,
                  foregroundColor: EchoWrightTheme.textOnPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(actionText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Loading widget
  static Widget buildLoadingWidget({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(EchoWrightTheme.primaryTurquoise),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: EchoWrightTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Error snackbar
  static SnackBar buildErrorSnackBar(String message, {VoidCallback? onRetry}) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: EchoWrightTheme.errorColor,
      action: onRetry != null 
        ? SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: onRetry,
          )
        : null,
      duration: const Duration(seconds: 4),
    );
  }

  /// Success snackbar
  static SnackBar buildSuccessSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      backgroundColor: EchoWrightTheme.primaryTurquoise,
      duration: const Duration(seconds: 3),
    );
  }
}