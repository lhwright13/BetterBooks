import '../api/api_client.dart';
import '../models/book_models.dart';
import 'base_repository.dart';
import '../../core/services/error_handler.dart';

class BookRepository extends BaseRepository {
  BookRepository(ApiClient apiClient) : super(apiClient, ErrorHandler());

  Future<List<BrowseBook>> getBrowseBooks() async {
    return handleApiCall(() async {
      logInfo('Fetching browse books');
      final response = await ApiClient.browseBooks();
      return response.books;
    });
  }

  Future<List<BrowseBook>> searchBooks(String query) async {
    return handleApiCall(() async {
      logInfo('Searching books with query: $query');
      final response = await ApiClient.searchBooks(query: query);
      return response.books;
    });
  }

  Future<DetailedBook> getBookDetails(String bookId) async {
    return handleApiCall(() async {
      logInfo('Fetching book details for ID: $bookId');
      return await ApiClient.getBookDetails(bookId);
    });
  }

  Future<List<BrowseBook>> getFeaturedBooks() async {
    return handleApiCall(() async {
      logInfo('Fetching featured books');
      final response = await ApiClient.getFeaturedBooks();
      return response.books;
    });
  }

  Future<List<BrowseBook>> getBestsellingBooks() async {
    return handleApiCall(() async {
      logInfo('Fetching bestselling books');
      final response = await ApiClient.getBestsellingBooks();
      return response.books;
    });
  }
}