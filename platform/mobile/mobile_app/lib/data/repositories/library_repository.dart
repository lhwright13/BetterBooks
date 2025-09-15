import '../api/api_client.dart';
import '../models/book_models.dart';
import 'base_repository.dart';
import '../../core/services/error_handler.dart';

class LibraryRepository extends BaseRepository {
  LibraryRepository(ApiClient apiClient) : super(apiClient, ErrorHandler());

  Future<List<BrowseBook>> getUserLibrary() async {
    return handleApiCall(() async {
      logInfo('Fetching user library');
      final response = await ApiClient.getUserLibrary();
      return response.books;
    });
  }

  Future<List<BrowseBook>> getRecentBooks() async {
    return handleApiCall(() async {
      logInfo('Fetching recent books');
      final response = await ApiClient.getUserLibrary();
      // Sort by recent activity (this would typically be handled by the backend)
      return response.books.take(5).toList();
    });
  }

  Future<List<BrowseBook>> getInProgressBooks() async {
    return handleApiCall(() async {
      logInfo('Fetching in-progress books');
      final response = await ApiClient.getUserLibrary();
      // For now, consider books in progress if they have some download progress but aren't fully downloaded
      return response.books.where((book) => 
        book.downloadProgress > 0 && book.downloadProgress < 1.0
      ).toList();
    });
  }

  Future<List<BrowseBook>> getCompletedBooks() async {
    return handleApiCall(() async {
      logInfo('Fetching completed books');
      final response = await ApiClient.getUserLibrary();
      // For now, consider books completed if they are fully downloaded
      return response.books.where((book) => book.downloadProgress >= 1.0).toList();
    });
  }

  Future<List<BrowseBook>> getDownloadedBooks() async {
    return handleApiCall(() async {
      logInfo('Fetching downloaded books');
      final response = await ApiClient.getUserLibrary();
      return response.books.where((book) => book.isDownloaded).toList();
    });
  }

  Future<void> updateBookProgress(String bookId, int progress) async {
    return handleApiCall(() async {
      logInfo('Updating book progress for ID: $bookId, progress: $progress%');
      // This would typically be an API call
      // await apiClient.updateBookProgress(bookId, progress);
    });
  }

  Future<void> addToWishlist(String bookId) async {
    return handleApiCall(() async {
      logInfo('Adding book to wishlist: $bookId');
      // This would typically be an API call
      // await apiClient.addToWishlist(bookId);
    });
  }

  Future<void> removeFromWishlist(String bookId) async {
    return handleApiCall(() async {
      logInfo('Removing book from wishlist: $bookId');
      // This would typically be an API call
      // await apiClient.removeFromWishlist(bookId);
    });
  }

  Future<List<BrowseBook>> getWishlist() async {
    return handleApiCall(() async {
      logInfo('Fetching wishlist');
      // This would typically be an API call
      // return await apiClient.getWishlist();
      return <BrowseBook>[]; // Temporary empty list
    });
  }
}