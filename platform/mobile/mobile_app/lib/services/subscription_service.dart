/**
 * subscription_service.dart - In-app purchase and subscription service
 * 
 * This service handles all subscription and payment operations including:
 * - App Store/Google Play in-app purchases
 * - Subscription management and validation
 * - Credit purchasing and tracking
 * - Restoration of purchases
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../models/user.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  bool _purchasePending = false;
  String? _queryProductError;

  // Product IDs (configure these in App Store Connect and Google Play Console)
  static const String kMonthlySubscriptionId = 'echowright_monthly_premium';
  static const String kYearlySubscriptionId = 'echowright_yearly_premium';
  static const String kCreditsPackSmall = 'echowright_credits_3';
  static const String kCreditsPackMedium = 'echowright_credits_10';
  static const String kCreditsPackLarge = 'echowright_credits_25';
  
  static const List<String> _kProductIds = [
    kMonthlySubscriptionId,
    kYearlySubscriptionId,
    kCreditsPackSmall,
    kCreditsPackMedium,
    kCreditsPackLarge,
  ];

  // Getters
  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  List<PurchaseDetails> get purchases => _purchases;
  bool get purchasePending => _purchasePending;
  String? get queryProductError => _queryProductError;

  /// Initialize the subscription service
  Future<void> initialize() async {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) => debugPrint('Purchase stream error: $error'),
    );

    await _initStoreInfo();
  }

  /// Initialize store information and load products
  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      _isAvailable = isAvailable;
      _products = [];
      _purchases = [];
      _purchasePending = false;
      notifyListeners();
      return;
    }

    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    final ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    
    if (productDetailResponse.error != null) {
      _queryProductError = productDetailResponse.error!.message;
      _isAvailable = isAvailable;
      _products = productDetailResponse.productDetails;
      _purchases = [];
      _purchasePending = false;
      notifyListeners();
      return;
    }

    if (productDetailResponse.productDetails.isEmpty) {
      _queryProductError = 'No products found';
      _isAvailable = isAvailable;
      _products = productDetailResponse.productDetails;
      _purchases = [];
      _purchasePending = false;
      notifyListeners();
      return;
    }

    _isAvailable = isAvailable;
    _products = productDetailResponse.productDetails;
    _queryProductError = null;
    notifyListeners();
  }

  /// Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
          _purchasePending = false;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _purchasePending = false;
          _handleSuccessfulPurchase(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
    notifyListeners();
  }

  /// Handle successful purchase
  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    // Here you would typically:
    // 1. Validate the purchase with your backend
    // 2. Grant the user access to premium features or credits
    // 3. Update local user state
    
    debugPrint('Purchase successful: ${purchaseDetails.productID}');
    
    // Add to purchases list if not already there
    if (!_purchases.any((p) => p.productID == purchaseDetails.productID)) {
      _purchases.add(purchaseDetails);
    }
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(String productId) async {
    final ProductDetails productDetails = _products.firstWhere(
      (product) => product.id == productId,
    );

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    try {
      final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      return success;
    } catch (e) {
      debugPrint('Purchase failed: $e');
      return false;
    }
  }

  /// Purchase credits
  Future<bool> purchaseCredits(String productId) async {
    final ProductDetails productDetails = _products.firstWhere(
      (product) => product.id == productId,
    );

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    try {
      final bool success = await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      return success;
    } catch (e) {
      debugPrint('Credit purchase failed: $e');
      return false;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  /// Check if user has active premium subscription
  bool hasActiveSubscription() {
    return _purchases.any((purchase) => 
      (purchase.productID == kMonthlySubscriptionId || 
       purchase.productID == kYearlySubscriptionId) &&
      purchase.status == PurchaseStatus.purchased);
  }

  /// Get credits from credit pack product ID
  int getCreditsFromProductId(String productId) {
    switch (productId) {
      case kCreditsPackSmall:
        return 3;
      case kCreditsPackMedium:
        return 10;
      case kCreditsPackLarge:
        return 25;
      default:
        return 0;
    }
  }

  /// Get subscription period from product ID
  String getSubscriptionPeriod(String productId) {
    switch (productId) {
      case kMonthlySubscriptionId:
        return 'Monthly';
      case kYearlySubscriptionId:
        return 'Yearly';
      default:
        return 'Unknown';
    }
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      iosPlatformAddition.setDelegate(null);
    }
    _subscription.cancel();
    super.dispose();
  }
}

/// iOS payment queue delegate for handling transaction updates
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}