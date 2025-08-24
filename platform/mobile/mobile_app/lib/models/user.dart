/**
 * user.dart - User data models for EchoWright mobile app
 * 
 * This file defines the user data structures for representing authenticated users
 * and their profile information in the EchoWright mobile application.
 * 
 * Key responsibilities:
 * - Define User model for user profile and account information
 * - Handle JSON serialization from authentication API responses
 * - Support multiple authentication methods (OAuth, email)
 * - Track email verification and subscription status
 * 
 * Backend integration:
 * - Models match API response format from authentication endpoints
 * - Supports user data from Google OAuth and Apple Sign In
 * - Includes subscription and entitlement information
 */

/// Represents an authenticated user in the EchoWright application
class User {
  final String id;                    // Unique user identifier
  final String? email;                // User email address (nullable for Apple private relay)
  final String? displayName;          // User's display name
  final String? avatarUrl;           // Profile picture URL
  final bool emailVerified;          // Whether email has been verified
  final bool isActive;               // Whether account is active
  final DateTime createdAt;          // Account creation timestamp
  final SubscriptionInfo? subscription; // Current subscription information

  User({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.emailVerified = false,
    this.isActive = true,
    required this.createdAt,
    this.subscription,
  });

  /// Create User from API JSON response
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['user_id'] ?? 'unknown') as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      subscription: json['subscription'] != null 
          ? SubscriptionInfo.fromJson(json['subscription'])
          : null,
    );
  }

  /// Convert User to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'email_verified': emailVerified,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'subscription': subscription?.toJson(),
    };
  }

  /// Create copy of User with modified fields
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? emailVerified,
    bool? isActive,
    DateTime? createdAt,
    SubscriptionInfo? subscription,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      subscription: subscription ?? this.subscription,
    );
  }

  /// Get user's first name from display name
  String get firstName {
    if (displayName == null || displayName!.isEmpty) return 'User';
    final parts = displayName!.split(' ');
    return parts.first;
  }

  /// Get user's initials for avatar fallback
  String get initials {
    if (displayName == null || displayName!.isEmpty) {
      return email?.substring(0, 1).toUpperCase() ?? 'U';
    }
    
    final parts = displayName!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
    } else {
      return parts[0].substring(0, 1).toUpperCase();
    }
  }

  /// Check if user has premium subscription
  bool get isPremium {
    return subscription?.isActive ?? false;
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Subscription information for a user
class SubscriptionInfo {
  final String id;                   // Subscription ID
  final String status;               // Subscription status
  final String productId;            // Product/plan identifier
  final String provider;             // Payment provider (app_store, stripe)
  final DateTime? currentPeriodStart;// Current billing period start
  final DateTime? currentPeriodEnd;  // Current billing period end
  final DateTime? trialStart;        // Trial period start
  final DateTime? trialEnd;          // Trial period end
  final bool isActive;               // Whether subscription is active
  final bool isTrial;                // Whether in trial period

  SubscriptionInfo({
    required this.id,
    required this.status,
    required this.productId,
    required this.provider,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.trialStart,
    this.trialEnd,
    this.isActive = false,
    this.isTrial = false,
  });

  /// Create SubscriptionInfo from API JSON response
  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      id: json['id'] as String,
      status: json['status'] as String,
      productId: json['product_id'] as String,
      provider: json['provider'] as String,
      currentPeriodStart: json['current_period_start'] != null 
          ? DateTime.parse(json['current_period_start'])
          : null,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'])
          : null,
      trialStart: json['trial_start'] != null
          ? DateTime.parse(json['trial_start'])
          : null,
      trialEnd: json['trial_end'] != null
          ? DateTime.parse(json['trial_end'])
          : null,
      isActive: json['is_active'] as bool? ?? false,
      isTrial: json['is_trial'] as bool? ?? false,
    );
  }

  /// Convert SubscriptionInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'product_id': productId,
      'provider': provider,
      'current_period_start': currentPeriodStart?.toIso8601String(),
      'current_period_end': currentPeriodEnd?.toIso8601String(),
      'trial_start': trialStart?.toIso8601String(),
      'trial_end': trialEnd?.toIso8601String(),
      'is_active': isActive,
      'is_trial': isTrial,
    };
  }

  /// Get subscription plan display name
  String get planDisplayName {
    switch (productId.toLowerCase()) {
      case 'com.echowright.monthly':
      case 'price_monthly_999':
        return 'Monthly Premium';
      case 'com.echowright.yearly':
      case 'price_yearly_9999':
        return 'Annual Premium';
      case 'com.echowright.family':
      case 'price_family_1999':
        return 'Family Plan';
      default:
        return 'Premium';
    }
  }

  /// Get subscription renewal display text
  String get renewalText {
    if (currentPeriodEnd == null) return 'Active';
    
    final now = DateTime.now();
    final daysUntilRenewal = currentPeriodEnd!.difference(now).inDays;
    
    if (daysUntilRenewal <= 0) {
      return 'Expired';
    } else if (daysUntilRenewal <= 3) {
      return 'Renews in $daysUntilRenewal days';
    } else {
      return 'Renews ${_formatDate(currentPeriodEnd!)}';
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  String toString() {
    return 'SubscriptionInfo(id: $id, status: $status, productId: $productId)';
  }
}