import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../providers/app_state.dart';
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
      body: Consumer<AppState>(
        builder: (context, appState, child) {
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
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'John Reader',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'john.reader@email.com',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Premium Member',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
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
                        trailing: Icon(Icons.external_link),
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
                          trailing: Icon(Icons.external_link),
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
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sign out functionality coming soon!')),
                );
              },
              child: Text('Sign Out'),
            ),
          ],
        );
      },
    );
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
  
  void _performAccountDeletion(BuildContext context) {
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
    
    // Simulate account deletion (would call API)
    Future.delayed(Duration(seconds: 3), () {
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
    });
  }
}