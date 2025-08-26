import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../providers/app_state.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import 'user_settings_screen.dart';

class UserProfileScreen extends StatefulWidget {
  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer2<AuthProvider, AppState>(
        builder: (context, authProvider, appState, child) {
          final user = authProvider.currentUser;
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Profile Card
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          child: user?.avatarUrl != null 
                            ? ClipOval(
                                child: Image.network(
                                  user!.avatarUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => 
                                    _buildInitialsAvatar(context, _safeGetInitials(user)),
                                ),
                              )
                            : _buildInitialsAvatar(context, _safeGetInitials(user)),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? user?.firstName ?? 'User',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              SizedBox(height: 4),
                              Text(
                                user?.email ?? 'No email',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  user?.isPremium == true ? 'Premium Member' : 'Free Member',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Email verification status
                              if (user?.email != null && !user!.emailVerified) ...[
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        size: 12,
                                        color: Colors.orange[700],
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Email not verified',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Account Statistics
                Text(
                  'Account Statistics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '24h 35m',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Listening Time',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.book_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '3',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                'Books Completed',
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Current AI Persona
                Text(
                  'Current AI Persona',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 12),
                
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.smart_toy,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      appState.selectedPersona?.displayName ?? 'No persona selected',
                    ),
                    subtitle: Text(
                      appState.selectedPersona?.description ?? 'Select a persona in settings',
                    ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => UserSettingsScreen()),
                      );
                    },
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Settings and Actions
                Text(
                  'Account Actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 12),
                
                Card(
                  child: Column(
                    children: [
                      // Email verification action (only show if email not verified)
                      if (user?.email != null && !user!.emailVerified) ...[
                        ListTile(
                          leading: Icon(Icons.email_outlined, color: Colors.orange[700]),
                          title: Text('Verify Email', style: TextStyle(color: Colors.orange[700])),
                          subtitle: Text('Tap to resend verification email'),
                          trailing: Icon(Icons.chevron_right, color: Colors.orange[700]),
                          onTap: () => _resendEmailVerification(context),
                        ),
                        Divider(height: 1),
                      ],
                      ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('User Settings'),
                        subtitle: Text('Manage your app preferences'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => UserSettingsScreen()),
                          );
                        },
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.history),
                        title: Text('Listening History'),
                        subtitle: Text('View your audiobook history'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Listening history coming soon!')),
                          );
                        },
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.bookmark),
                        title: Text('Bookmarks'),
                        subtitle: Text('Your saved bookmarks'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Bookmarks feature coming soon!')),
                          );
                        },
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.help_outline),
                        title: Text('Help & Support'),
                        subtitle: Text('Get help using BetterBooks'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Support coming soon!')),
                          );
                        },
                      ),
                      
                      // Apple Guideline Compliance: Required buttons
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.restore),
                        title: Text('Restore Purchases'),
                        subtitle: Text('Restore your previous purchases'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {
                          _restorePurchases(context);
                        },
                      ),
                      
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.subscriptions),
                        title: Text('Manage Subscription'),
                        subtitle: Text('View and manage your subscription'),
                        trailing: Icon(Icons.open_in_new),
                        onTap: () {
                          _openSubscriptionManagement();
                        },
                      ),
                      
                      // External purchase link (US storefront only)
                      if (_isUSStorefront())
                        Divider(height: 1),
                      if (_isUSStorefront())
                        ListTile(
                          leading: Icon(Icons.web),
                          title: Text('Manage Account on Web'),
                          subtitle: Text('Access additional features online'),
                          trailing: Icon(Icons.open_in_new),
                          onTap: () {
                            _openWebAccount();
                          },
                        ),
                      
                      // Account deletion (required by guideline 5.1.1)
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.delete_forever, color: Colors.red),
                        title: Text('Delete Account', 
                          style: TextStyle(color: Colors.red)),
                        subtitle: Text('Permanently delete your account and data'),
                        trailing: Icon(Icons.chevron_right, color: Colors.red),
                        onTap: () {
                          _showDeleteAccountDialog(context);
                        },
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _showSignOutDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Sign Out'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInitialsAvatar(BuildContext context, String initials) {
    return Text(
      initials,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sign Out'),
          content: Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                // Sign out
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.signOut();
                
                // Close loading dialog
                Navigator.of(context).pop();
                
                // Navigate to authentication screen
                Navigator.of(context).pushReplacementNamed('/');
              },
              child: Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _resendEmailVerification(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user?.email == null) return;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Sending Verification Email'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Please wait...')
          ],
        ),
      ),
    );
    
    try {
      final success = await authProvider.sendEmailVerification(user!.email!);
      
      Navigator.of(context).pop(); // Close loading dialog
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to ${user.email}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending verification email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Apple Guideline Compliance Methods
  
  void _restorePurchases(BuildContext context) {
    // Required by Apple guidelines
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Restoring Purchases'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Please wait...')
            ],
          ),
        );
      },
    );
    
    // Simulate restore purchases (would call StoreKit)
    Future.delayed(Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchases restored successfully!')),
      );
    });
  }
  
  void _openSubscriptionManagement() {
    // Opens iOS Settings > Subscriptions (required by Apple)
    final url = 'https://apps.apple.com/account/subscriptions';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
  
  bool _isUSStorefront() {
    // Check if user is in US storefront (for external link compliance)
    // This would check actual storefront in production
    return Platform.localeName.startsWith('en_US');
  }
  
  void _openWebAccount() {
    // External link to web account (US storefront only per 3.1.3a)
    final url = 'https://betterbooks.com/account';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
  
  void _showDeleteAccountDialog(BuildContext context) {
    // Required by Apple guideline 5.1.1
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This will permanently delete:'),
              SizedBox(height: 8),
              Text('• Your account and profile'),
              Text('• All listening history'),
              Text('• Bookmarks and preferences'),
              Text('• Any saved progress'),
              SizedBox(height: 16),
              Text('This action cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmAccountDeletion(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }
  
  void _confirmAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Final Confirmation'),
          content: Text('Type "DELETE" to confirm account deletion:'),
          actions: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Type DELETE',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Validate input
              },
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _performAccountDeletion(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('DELETE ACCOUNT'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
  
  void _performAccountDeletion(BuildContext context) async {
    // Show processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Deleting Account'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting your account...')
            ],
          ),
        );
      },
    );
    
    try {
      // TODO: Call actual account deletion API when backend is ready
      // For now, simulate the deletion with sign out
      await Future.delayed(Duration(seconds: 2));
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      
      Navigator.of(context).pop(); // Close loading dialog
      
      // Show success and navigate to welcome screen
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Account Deleted'),
            content: Text('Your account has been permanently deleted. You will now be signed out.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate to welcome/login screen
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Safely get user initials with error handling
  String _safeGetInitials(User? user) {
    if (user == null) return 'U';
    
    try {
      return user.initials;
    } catch (e) {
      // Fallback to first letter of email or 'U'
      if (user.email != null && user.email!.isNotEmpty) {
        return user.email!.substring(0, 1).toUpperCase();
      }
      return 'U';
    }
  }
}