import '../api/api_client.dart';
import '../../core/exceptions/api_exceptions.dart';
import '../../core/services/error_handler.dart';

abstract class BaseRepository {
  final ApiClient apiClient;
  final ErrorHandler errorHandler;

  BaseRepository(this.apiClient, this.errorHandler);

  Future<T> handleApiCall<T>(Future<T> Function() apiCall) async {
    try {
      return await apiCall();
    } catch (error, stackTrace) {
      errorHandler.logError(
        'API call failed',
        error: error,
        stackTrace: stackTrace,
        tag: runtimeType.toString(),
      );
      rethrow;
    }
  }

  void logInfo(String message) {
    errorHandler.logError(
      message,
      level: ErrorLevel.info,
      tag: runtimeType.toString(),
    );
  }

  void logError(String message, {dynamic error, StackTrace? stackTrace}) {
    errorHandler.logError(
      message,
      error: error,
      stackTrace: stackTrace,
      tag: runtimeType.toString(),
    );
  }
}