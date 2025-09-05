import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../navigation/main_navigation.dart';
import 'preferences_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedPlan = 1; // Default to Plus plan
  bool _isLoading = false;
  bool _showFreeTrial = true;

  final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      id: 'free_trial',
      name: 'Free Trial',
      price: '\$0',
      period: '30 days',
      credits: 1,
      features: [
        '1 credit included',
        'Access to Plus catalog',
        'AI chat with characters',
        'Offline downloads',
        'Cancel anytime'
      ],
      isPopular: false,
      isTrial: true,
    ),
    SubscriptionPlan(
      id: 'plus_monthly',
      name: 'Plus Plan',
      price: '\$14.95',
      period: 'month',
      credits: 1,
      features: [
        '1 credit every month',
        'Access to Plus catalog',
        'AI chat with characters',
        'Offline downloads',
        '30% off additional credits'
      ],
      isPopular: true,
      isTrial: false,
    ),
    SubscriptionPlan(
      id: 'premium_monthly',
      name: 'Premium Plan',
      price: '\$22.95',
      period: 'month',
      credits: 2,
      features: [
        '2 credits every month',
        'Access to Plus catalog',
        'AI chat with characters',
        'Offline downloads',
        '30% off additional credits',
        'Early access to new releases'
      ],
      isPopular: false,
      isTrial: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset(
                      'assets/images/EchoWright.svg',
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Title section
                      Text(
                        'Choose Your Plan',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start your audiobook journey with AI-powered conversations',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Subscription plans
                      ...List.generate(_plans.length, (index) {
                        final plan = _plans[index];
                        return _buildPlanCard(plan, index);
                      }),

                      const SizedBox(height: 24),

                      // Benefits section
                      _buildBenefitsSection(),

                      const SizedBox(height: 24),

                      // Terms
                      Text(
                        'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. You can manage your subscription in your account settings.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom action
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _subscribeToPlan,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(_getButtonText()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _skipSubscription,
                      child: const Text('Skip for now'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, int index) {
    final isSelected = _selectedPlan == index;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => setState(() => _selectedPlan = index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                : Theme.of(context).colorScheme.surface,
          ),
          child: Stack(
            children: [
              if (plan.isPopular)
                Positioned(
                  top: -1,
                  left: 16,
                  right: 16,
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'MOST POPULAR',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(plan.isPopular ? 24 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (plan.isPopular) const SizedBox(height: 16),
                    
                    // Plan header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (plan.isTrial) ...[
                                Text(
                                  'Then ${_plans[1].price}/${_plans[1].period}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: plan.credits.toString(),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: plan.credits > 1 ? ' credits' : ' credit',
                                      style: Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan.price,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: plan.isTrial 
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            if (!plan.isTrial)
                              Text(
                                'per ${plan.period}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Features
                    Column(
                      children: plan.features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              
              if (isSelected)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you get with EchoWright',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildBenefitItem(
            icon: Icons.auto_stories,
            title: 'Vast Library',
            subtitle: 'Thousands of audiobooks across all genres',
          ),
          _buildBenefitItem(
            icon: Icons.chat,
            title: 'AI Conversations',
            subtitle: 'Chat with book characters and get insights',
          ),
          _buildBenefitItem(
            icon: Icons.download,
            title: 'Offline Listening',
            subtitle: 'Download books and listen anywhere',
          ),
          _buildBenefitItem(
            icon: Icons.sync,
            title: 'Sync Across Devices',
            subtitle: 'Pick up where you left off on any device',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText() {
    final plan = _plans[_selectedPlan];
    if (plan.isTrial) {
      return 'Start Free Trial';
    }
    return 'Subscribe for ${plan.price}/${plan.period}';
  }

  Future<void> _subscribeToPlan() async {
    setState(() => _isLoading = true);
    
    // TODO: Implement actual subscription logic with in-app purchases
    // For now, simulate subscription process
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const PreferencesScreen(),
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _skipSubscription() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const PreferencesScreen(),
      ),
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String price;
  final String period;
  final int credits;
  final List<String> features;
  final bool isPopular;
  final bool isTrial;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    required this.credits,
    required this.features,
    required this.isPopular,
    required this.isTrial,
  });
}