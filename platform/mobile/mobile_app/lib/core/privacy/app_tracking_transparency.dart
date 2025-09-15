import 'package:flutter/material.dart';
import 'dart:io';

/// App Tracking Transparency handler for iOS 14.5+
class AppTrackingTransparency {
  // Method channel for future native implementation
  // static const MethodChannel _channel = MethodChannel('app_tracking_transparency');

  /// Request tracking authorization from the user
  static Future<TrackingStatus> requestTrackingAuthorization() async {
    if (!Platform.isIOS) {
      return TrackingStatus.notSupported;
    }

    try {
      // For now, simulate the request since we don't have the native implementation
      // In a real app, this would call native iOS code via method channel
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Return a default status - in production, this would come from native code
      return TrackingStatus.authorized;
    } catch (e) {
      return TrackingStatus.denied;
    }
  }

  /// Get current tracking authorization status
  static Future<TrackingStatus> getTrackingAuthorizationStatus() async {
    if (!Platform.isIOS) {
      return TrackingStatus.notSupported;
    }

    try {
      // Simulate getting status
      return TrackingStatus.notDetermined;
    } catch (e) {
      return TrackingStatus.denied;
    }
  }

  /// Check if tracking is available on this device/OS version
  static bool get isTrackingAvailable {
    return Platform.isIOS;
  }

  /// Show custom pre-permission dialog to explain tracking benefits
  static Future<bool> showPrePermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AppTrackingDialog(),
    ) ?? false;
  }
}

/// Enum for tracking authorization status
enum TrackingStatus {
  notDetermined,
  denied,
  authorized,
  restricted,
  notSupported,
}

/// Custom dialog explaining tracking benefits before showing system dialog
class AppTrackingDialog extends StatelessWidget {
  const AppTrackingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Help Us Improve Your Experience'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'We use tracking to provide you with:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          _BenefitItem(
            icon: Icons.recommend,
            text: 'Personalized book recommendations',
          ),
          _BenefitItem(
            icon: Icons.trending_up,
            text: 'Better app performance insights',
          ),
          _BenefitItem(
            icon: Icons.security,
            text: 'Enhanced security features',
          ),
          SizedBox(height: 16),
          Text(
            'Your privacy is important to us. We only use this data to improve your experience and never sell personal information.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Privacy settings manager
class PrivacyManager {
  // Preference keys for future SharedPreferences implementation
  // static const String _trackingPreferenceKey = 'user_tracking_preference';
  // static const String _analyticsPreferenceKey = 'analytics_preference';
  // static const String _crashReportingPreferenceKey = 'crash_reporting_preference';

  /// Initialize privacy settings
  static Future<void> initialize() async {
    // Check if we need to request tracking permission
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.getTrackingAuthorizationStatus();
      if (status == TrackingStatus.notDetermined) {
        // Don't automatically request - let the user decide when to enable tracking
        debugPrint('Tracking permission not determined - waiting for user action');
      }
    }
  }

  /// Request tracking permission with user education
  static Future<void> requestTrackingPermissionWithEducation(BuildContext context) async {
    if (!Platform.isIOS) return;

    // First show our custom dialog explaining benefits
    final userWantsToSeeSystemDialog = await AppTrackingTransparency.showPrePermissionDialog(context);
    
    if (userWantsToSeeSystemDialog) {
      // Now show the system dialog
      final status = await AppTrackingTransparency.requestTrackingAuthorization();
      await _handleTrackingResponse(status);
    }
  }

  /// Handle tracking authorization response
  static Future<void> _handleTrackingResponse(TrackingStatus status) async {
    switch (status) {
      case TrackingStatus.authorized:
        debugPrint('Tracking authorized - enabling analytics');
        await _setTrackingEnabled(true);
        break;
      case TrackingStatus.denied:
      case TrackingStatus.restricted:
        debugPrint('Tracking denied - disabling analytics');
        await _setTrackingEnabled(false);
        break;
      case TrackingStatus.notDetermined:
        debugPrint('Tracking not determined');
        break;
      case TrackingStatus.notSupported:
        debugPrint('Tracking not supported on this platform');
        break;
    }
  }

  /// Enable or disable tracking
  static Future<void> _setTrackingEnabled(bool enabled) async {
    // Store preference locally
    // In a real app, you'd use SharedPreferences or similar
    debugPrint('Setting tracking enabled: $enabled');
    
    // Configure your analytics SDK here
    // For example: Firebase Analytics, Mixpanel, etc.
  }

  /// Show privacy settings screen
  static void showPrivacySettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PrivacySettingsScreen(),
      ),
    );
  }
}

/// Privacy settings screen
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _analyticsEnabled = true;
  bool _crashReportingEnabled = true;
  bool _personalizationEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Control how your data is used to improve your experience.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
          _buildPrivacyTile(
            title: 'Analytics',
            subtitle: 'Help us understand app usage patterns',
            value: _analyticsEnabled,
            onChanged: (value) => setState(() => _analyticsEnabled = value),
            icon: Icons.analytics,
          ),
          _buildPrivacyTile(
            title: 'Crash Reporting',
            subtitle: 'Automatically report crashes to improve stability',
            value: _crashReportingEnabled,
            onChanged: (value) => setState(() => _crashReportingEnabled = value),
            icon: Icons.bug_report,
          ),
          _buildPrivacyTile(
            title: 'Personalization',
            subtitle: 'Customize recommendations based on your preferences',
            value: _personalizationEnabled,
            onChanged: (value) => setState(() => _personalizationEnabled = value),
            icon: Icons.person,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.policy),
            title: const Text('Privacy Policy'),
            subtitle: const Text('View our privacy policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openPrivacyPolicy(),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            subtitle: const Text('View our terms of service'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openTermsOfService(),
          ),
          if (Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.track_changes),
              title: const Text('App Tracking'),
              subtitle: const Text('Manage cross-app tracking preferences'),
              trailing: const Icon(Icons.settings),
              onTap: () => _showTrackingSettings(),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  void _openPrivacyPolicy() {
    // Open privacy policy URL
    // In a real app, use url_launcher package
    debugPrint('Opening privacy policy');
  }

  void _openTermsOfService() {
    // Open terms of service URL
    debugPrint('Opening terms of service');
  }

  void _showTrackingSettings() async {
    if (Platform.isIOS) {
      await PrivacyManager.requestTrackingPermissionWithEducation(context);
    }
  }
}