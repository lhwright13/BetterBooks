import 'package:flutter/foundation.dart';
import '../../core/services/error_handler.dart';

abstract class BaseController extends ChangeNotifier {
  final ErrorHandler _errorHandler = ErrorHandler();
  
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void clearError() {
    setError(null);
  }

  Future<T> handleAsyncOperation<T>(
    Future<T> Function() operation, {
    bool showLoading = true,
    String? errorMessage,
  }) async {
    try {
      if (showLoading) setLoading(true);
      clearError();
      
      final result = await operation();
      
      if (showLoading) setLoading(false);
      return result;
    } catch (error, stackTrace) {
      if (showLoading) setLoading(false);
      
      final message = errorMessage ?? _errorHandler.getErrorMessage(error);
      setError(message);
      
      _errorHandler.logError(
        'Controller operation failed',
        error: error,
        stackTrace: stackTrace,
        tag: runtimeType.toString(),
      );
      
      rethrow;
    }
  }

  void logInfo(String message) {
    _errorHandler.logError(
      message,
      level: ErrorLevel.info,
      tag: runtimeType.toString(),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}