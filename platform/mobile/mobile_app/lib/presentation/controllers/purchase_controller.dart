import '../../data/repositories/purchase_repository.dart';
import 'base_controller.dart';

class PurchaseController extends BaseController {
  final PurchaseRepository _purchaseRepository;
  
  int _userCredits = 0;
  Map<String, dynamic> _subscriptionStatus = {};

  PurchaseController(this._purchaseRepository);

  int get userCredits => _userCredits;
  Map<String, dynamic> get subscriptionStatus => _subscriptionStatus;
  bool get hasActiveSubscription => _subscriptionStatus['isActive'] == true;

  Future<bool> purchaseBook(String bookId) async {
    return handleAsyncOperation(
      () async {
        logInfo('Attempting to purchase book: $bookId');
        
        final canPurchase = await _purchaseRepository.canPurchaseBook(bookId);
        if (!canPurchase) {
          throw Exception('Insufficient credits to purchase this book');
        }
        
        final success = await _purchaseRepository.purchaseBook(bookId);
        
        if (success) {
          // Refresh credits after purchase
          await loadUserCredits();
          logInfo('Book purchased successfully: $bookId');
        }
        
        return success;
      },
      errorMessage: 'Failed to purchase book. Please try again.',
    );
  }

  Future<bool> canPurchaseBook(String bookId) async {
    return handleAsyncOperation(
      () async {
        logInfo('Checking purchase eligibility for book: $bookId');
        return await _purchaseRepository.canPurchaseBook(bookId);
      },
      showLoading: false,
      errorMessage: 'Failed to check purchase eligibility.',
    );
  }

  Future<void> loadUserCredits() async {
    return handleAsyncOperation(
      () async {
        logInfo('Loading user credits');
        try {
          // Try to get credits from API
          _userCredits = await _purchaseRepository.getUserCredits();
        } catch (e) {
          logInfo('Failed to load credits from API, using fallback: $e');
          // Fallback to 5 credits for MVP
          _userCredits = 5;
        }
        
        logInfo('User credits loaded: $_userCredits');
        notifyListeners();
      },
      showLoading: false,
      errorMessage: 'Failed to load credits.',
    );
  }

  Future<void> loadSubscriptionStatus() async {
    return handleAsyncOperation(
      () async {
        logInfo('Loading subscription status');
        _subscriptionStatus = await _purchaseRepository.getSubscriptionStatus();
        
        logInfo('Subscription status loaded: ${_subscriptionStatus['isActive']}');
        notifyListeners();
      },
      showLoading: false,
      errorMessage: 'Failed to load subscription status.',
    );
  }

  Future<void> addCredits(int amount) async {
    return handleAsyncOperation(
      () async {
        logInfo('Adding $amount credits');
        await _purchaseRepository.addCredits(amount);
        
        // Refresh credits after adding
        await loadUserCredits();
        
        logInfo('Credits added successfully');
      },
      errorMessage: 'Failed to add credits. Please try again.',
    );
  }

  Future<List<PurchaseHistory>> getPurchaseHistory() async {
    return handleAsyncOperation(
      () async {
        logInfo('Loading purchase history');
        return await _purchaseRepository.getPurchaseHistory();
      },
      errorMessage: 'Failed to load purchase history.',
    );
  }

  Future<void> refreshData() async {
    return handleAsyncOperation(
      () async {
        logInfo('Refreshing purchase data');
        
        await Future.wait([
          loadUserCredits(),
          loadSubscriptionStatus(),
        ]);
        
        logInfo('Purchase data refreshed');
      },
      errorMessage: 'Failed to refresh purchase data.',
    );
  }

  String getCreditsDisplayText() {
    if (_userCredits == 0) {
      return 'No credits';
    } else if (_userCredits == 1) {
      return '1 credit';
    } else {
      return '$_userCredits credits';
    }
  }

  bool hasEnoughCredits(int required) {
    return _userCredits >= required;
  }
}