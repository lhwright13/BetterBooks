/// Subscription management screen with in-app purchases

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';
import '../providers/auth_provider.dart';
import '../theme/echowright_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late SubscriptionService _subscriptionService;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _subscriptionService = SubscriptionService();
    _initializeStore();
  }

  Future<void> _initializeStore() async {
    setState(() => _isLoading = true);
    
    try {
      await _subscriptionService.initialize();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to initialize store: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseSubscription(String productId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      _showMessage('Please sign in to purchase subscriptions');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await _subscriptionService.purchaseSubscription(productId);
      if (success) {
        _showMessage('Subscription purchase initiated!', isSuccess: true);
      } else {
        _showMessage('Purchase failed. Please try again.');
      }
    } catch (e) {
      _showMessage('Purchase failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseCredits(String productId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      _showMessage('Please sign in to purchase credits');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await _subscriptionService.purchaseCredits(productId);
      if (success) {
        final credits = _subscriptionService.getCreditsFromProductId(productId);
        _showMessage('$credits credits purchase initiated!', isSuccess: true);
      } else {
        _showMessage('Purchase failed. Please try again.');
      }
    } catch (e) {
      _showMessage('Purchase failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    
    try {
      await _subscriptionService.restorePurchases();
      _showMessage('Purchases restored successfully!', isSuccess: true);
    } catch (e) {
      _showMessage('Failed to restore purchases: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isSuccess 
              ? EchoWrightTheme.successColor 
              : EchoWrightTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EchoWrightTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: EchoWrightTheme.backgroundDark,
        foregroundColor: EchoWrightTheme.textPrimary,
        title: const Text('Subscription & Credits'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _restorePurchases,
            child: Text(
              'Restore',
              style: TextStyle(color: EchoWrightTheme.primaryTurquoise),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCurrentStatus(),
                      const SizedBox(height: 32),
                      _buildSubscriptionPlans(),
                      const SizedBox(height: 32),
                      _buildCreditPacks(),
                      const SizedBox(height: 32),
                      _buildFeatureComparison(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: EchoWrightTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Store Unavailable',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: EchoWrightTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to connect to app store',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: EchoWrightTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: EchoWrightTheme.primaryCoral,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            EchoWrightTheme.primaryTurquoise.withOpacity(0.1),
            EchoWrightTheme.primaryCoral.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: EchoWrightTheme.primaryTurquoise.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _subscriptionService.hasActiveSubscription()
                    ? Icons.star
                    : Icons.account_circle,
                color: EchoWrightTheme.primaryTurquoise,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                _subscriptionService.hasActiveSubscription()
                    ? 'Premium Member'
                    : 'Free User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: EchoWrightTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _subscriptionService.hasActiveSubscription()
                ? 'Enjoy unlimited book credits and premium features'
                : 'Upgrade to premium for unlimited access',
            style: TextStyle(
              fontSize: 14,
              color: EchoWrightTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPlans() {
    final subscriptionProducts = _subscriptionService.products
        .where((product) => 
            product.id == SubscriptionService.kMonthlySubscriptionId ||
            product.id == SubscriptionService.kYearlySubscriptionId)
        .toList();

    if (subscriptionProducts.isEmpty) {
      return _buildMockSubscriptionPlans();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Subscriptions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        ...subscriptionProducts.map((product) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildSubscriptionCard(
            title: _subscriptionService.getSubscriptionPeriod(product.id),
            price: product.price,
            originalPrice: null,
            savings: product.id == SubscriptionService.kYearlySubscriptionId ? '2 months free' : null,
            onPurchase: () => _purchaseSubscription(product.id),
            isPopular: product.id == SubscriptionService.kYearlySubscriptionId,
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildMockSubscriptionPlans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Subscriptions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildSubscriptionCard(
          title: 'Monthly',
          price: '\$9.99',
          originalPrice: null,
          savings: null,
          onPurchase: () => _showMessage('Mock subscription - Monthly plan selected'),
          isPopular: false,
        ),
        const SizedBox(height: 12),
        
        _buildSubscriptionCard(
          title: 'Yearly',
          price: '\$99.99',
          originalPrice: '\$119.88',
          savings: 'Save \$20',
          onPurchase: () => _showMessage('Mock subscription - Yearly plan selected'),
          isPopular: true,
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard({
    required String title,
    required String price,
    required String? originalPrice,
    required String? savings,
    required VoidCallback onPurchase,
    required bool isPopular,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: isPopular
            ? Border.all(color: EchoWrightTheme.primaryCoral, width: 2)
            : null,
      ),
      child: Stack(
        children: [
          if (isPopular)
            Positioned(
              top: -1,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: EchoWrightTheme.primaryCoral,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$title Premium',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: EchoWrightTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: EchoWrightTheme.primaryCoral,
                            ),
                          ),
                          if (originalPrice != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              originalPrice,
                              style: TextStyle(
                                fontSize: 16,
                                color: EchoWrightTheme.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (savings != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          savings,
                          style: TextStyle(
                            fontSize: 14,
                            color: EchoWrightTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                ElevatedButton(
                  onPressed: onPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular
                        ? EchoWrightTheme.primaryCoral
                        : EchoWrightTheme.primaryTurquoise,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Subscribe',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditPacks() {
    final creditProducts = _subscriptionService.products
        .where((product) => 
            product.id.contains('credits'))
        .toList();

    if (creditProducts.isEmpty) {
      return _buildMockCreditPacks();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Credit Packs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Purchase credits to buy individual books',
          style: TextStyle(
            fontSize: 14,
            color: EchoWrightTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        
        ...creditProducts.map((product) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: _buildCreditPackCard(
            credits: _subscriptionService.getCreditsFromProductId(product.id),
            price: product.price,
            onPurchase: () => _purchaseCredits(product.id),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildMockCreditPacks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Credit Packs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Purchase credits to buy individual books',
          style: TextStyle(
            fontSize: 14,
            color: EchoWrightTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildCreditPackCard(
          credits: 3,
          price: '\$14.99',
          onPurchase: () => _showMessage('Mock purchase - 3 credits for \$14.99'),
        ),
        const SizedBox(height: 8),
        
        _buildCreditPackCard(
          credits: 10,
          price: '\$39.99',
          onPurchase: () => _showMessage('Mock purchase - 10 credits for \$39.99'),
        ),
        const SizedBox(height: 8),
        
        _buildCreditPackCard(
          credits: 25,
          price: '\$89.99',
          onPurchase: () => _showMessage('Mock purchase - 25 credits for \$89.99'),
        ),
      ],
    );
  }

  Widget _buildCreditPackCard({
    required int credits,
    required String price,
    required VoidCallback onPurchase,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: EchoWrightTheme.primaryTurquoise.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: EchoWrightTheme.primaryTurquoise,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$credits Credits',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: EchoWrightTheme.textPrimary,
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 14,
                    color: EchoWrightTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          OutlinedButton(
            onPressed: onPurchase,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: EchoWrightTheme.primaryTurquoise),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'Buy',
              style: TextStyle(
                color: EchoWrightTheme.primaryTurquoise,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Features',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: EchoWrightTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        _buildFeatureRow('Unlimited monthly credits', true, false),
        _buildFeatureRow('Premium AI personas', true, false),
        _buildFeatureRow('Advanced voice features', true, false),
        _buildFeatureRow('Offline downloads', true, false),
        _buildFeatureRow('Skip ads', true, false),
        _buildFeatureRow('Early access to new books', true, false),
        _buildFeatureRow('Basic features', true, true),
        _buildFeatureRow('3 credits per month', false, true),
      ],
    );
  }

  Widget _buildFeatureRow(String feature, bool premium, bool free) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 16,
                color: EchoWrightTheme.textPrimary,
              ),
            ),
          ),
          
          Expanded(
            child: Center(
              child: Icon(
                premium ? Icons.check : Icons.close,
                color: premium ? EchoWrightTheme.successColor : EchoWrightTheme.textMuted,
                size: 20,
              ),
            ),
          ),
          
          Expanded(
            child: Center(
              child: Icon(
                free ? Icons.check : Icons.close,
                color: free ? EchoWrightTheme.successColor : EchoWrightTheme.textMuted,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}