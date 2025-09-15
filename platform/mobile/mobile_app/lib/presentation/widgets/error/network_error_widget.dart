import 'package:flutter/material.dart';
import '../../../core/exceptions/api_exceptions.dart';

/// Widget for displaying network-related errors with retry functionality
class NetworkErrorWidget extends StatelessWidget {
  final ApiException? exception;
  final String? customMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final bool showRetryButton;
  final bool isCompact;
  final IconData? customIcon;

  const NetworkErrorWidget({
    super.key,
    this.exception,
    this.customMessage,
    this.onRetry,
    this.onCancel,
    this.showRetryButton = true,
    this.isCompact = false,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (isCompact) {
      return _buildCompactError(context, theme, colorScheme);
    }
    
    return _buildFullError(context, theme, colorScheme);
  }

  Widget _buildFullError(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Error icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getErrorIcon(),
              size: 40,
              color: colorScheme.error,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Error title
          Text(
            _getErrorTitle(),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Error message
          Text(
            _getErrorMessage(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Action buttons
          _buildActionButtons(context, theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildCompactError(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getErrorIcon(),
            size: 24,
            color: colorScheme.error,
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getErrorTitle(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getErrorMessage(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          
          if (showRetryButton && onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onCancel != null)
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              side: BorderSide(color: colorScheme.outline),
            ),
            child: const Text('Cancel'),
          ),
        
        if (onCancel != null && showRetryButton && onRetry != null)
          const SizedBox(width: 16),
        
        if (showRetryButton && onRetry != null)
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
      ],
    );
  }

  IconData _getErrorIcon() {
    if (customIcon != null) return customIcon!;
    
    if (exception != null) {
      switch (exception!.type) {
        case ApiErrorType.networkError:
          return Icons.wifi_off;
        case ApiErrorType.timeout:
          return Icons.timer_off;
        case ApiErrorType.serverError:
          return Icons.dns_outlined;
        case ApiErrorType.unauthorized:
          return Icons.lock_outline;
        case ApiErrorType.forbidden:
          return Icons.block;
        case ApiErrorType.notFound:
          return Icons.search_off;
        default:
          return Icons.error_outline;
      }
    }
    
    return Icons.error_outline;
  }

  String _getErrorTitle() {
    if (exception != null) {
      switch (exception!.type) {
        case ApiErrorType.networkError:
          return 'Connection Problem';
        case ApiErrorType.timeout:
          return 'Request Timed Out';
        case ApiErrorType.serverError:
          return 'Server Error';
        case ApiErrorType.unauthorized:
          return 'Authentication Required';
        case ApiErrorType.forbidden:
          return 'Access Denied';
        case ApiErrorType.notFound:
          return 'Not Found';
        default:
          return 'Something Went Wrong';
      }
    }
    
    return 'Network Error';
  }

  String _getErrorMessage() {
    if (customMessage != null) return customMessage!;
    
    if (exception != null) {
      return exception!.userMessage;
    }
    
    return 'Please check your internet connection and try again.';
  }
}

/// Factory methods for common error scenarios
extension NetworkErrorWidgetFactory on NetworkErrorWidget {
  /// Create widget for offline/no connectivity
  static Widget offline({
    VoidCallback? onRetry,
    VoidCallback? onCancel,
    bool isCompact = false,
  }) {
    return NetworkErrorWidget(
      exception: const ApiException(
        message: 'No internet connection',
        type: ApiErrorType.networkError,
      ),
      customMessage: 'You appear to be offline. Please check your internet connection and try again.',
      onRetry: onRetry,
      onCancel: onCancel,
      isCompact: isCompact,
      customIcon: Icons.wifi_off,
    );
  }

  /// Create widget for timeout errors
  static Widget timeout({
    VoidCallback? onRetry,
    VoidCallback? onCancel,
    bool isCompact = false,
  }) {
    return NetworkErrorWidget(
      exception: const ApiException(
        message: 'Request timeout',
        type: ApiErrorType.timeout,
      ),
      onRetry: onRetry,
      onCancel: onCancel,
      isCompact: isCompact,
    );
  }

  /// Create widget for server errors
  static Widget serverError({
    VoidCallback? onRetry,
    VoidCallback? onCancel,
    bool isCompact = false,
  }) {
    return NetworkErrorWidget(
      exception: const ApiException(
        message: 'Server error',
        type: ApiErrorType.serverError,
      ),
      onRetry: onRetry,
      onCancel: onCancel,
      isCompact: isCompact,
    );
  }
}