import '../api/api_client.dart';
import '../models/book_models.dart';
import 'base_repository.dart';
import '../../core/services/error_handler.dart';

class PurchaseRepository extends BaseRepository {
  PurchaseRepository(ApiClient apiClient) : super(apiClient, ErrorHandler());

  Future<bool> purchaseBook(String bookId) async {
    return handleApiCall(() async {
      logInfo('Purchasing book with ID: $bookId');
      final response = await ApiClient.purchaseBook(bookId);
      return response.success;
    });
  }

  Future<bool> canPurchaseBook(String bookId) async {
    return handleApiCall(() async {
      logInfo('Checking if can purchase book: $bookId');
      final creditsResponse = await ApiClient.getUserCredits();
      return creditsResponse.availableCredits > 0; // Assuming each book costs 1 credit
    });
  }

  Future<int> getUserCredits() async {
    return handleApiCall(() async {
      logInfo('Fetching user credits');
      final creditsResponse = await ApiClient.getUserCredits();
      return creditsResponse.availableCredits;
    });
  }

  Future<List<PurchaseHistory>> getPurchaseHistory() async {
    return handleApiCall(() async {
      logInfo('Fetching purchase history');
      // This would typically be an API call
      // return await apiClient.getPurchaseHistory();
      return <PurchaseHistory>[]; // Temporary empty list
    });
  }

  Future<void> addCredits(int amount) async {
    return handleApiCall(() async {
      logInfo('Adding $amount credits');
      // This would typically be an API call for in-app purchases
      // await apiClient.addCredits(amount);
    });
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    return handleApiCall(() async {
      logInfo('Fetching subscription status');
      // This would typically be an API call
      // return await apiClient.getSubscriptionStatus();
      return {
        'isActive': false,
        'plan': null,
        'expiryDate': null,
      };
    });
  }
}

class PurchaseHistory {
  final String id;
  final String bookId;
  final String bookTitle;
  final DateTime purchaseDate;
  final int creditsUsed;

  PurchaseHistory({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.purchaseDate,
    required this.creditsUsed,
  });

  factory PurchaseHistory.fromJson(Map<String, dynamic> json) {
    return PurchaseHistory(
      id: json['id'],
      bookId: json['bookId'],
      bookTitle: json['bookTitle'],
      purchaseDate: DateTime.parse(json['purchaseDate']),
      creditsUsed: json['creditsUsed'],
    );
  }
}