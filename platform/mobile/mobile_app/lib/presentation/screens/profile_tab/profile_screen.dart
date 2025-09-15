import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../auth_screen.dart';
import '../player/mini_player.dart';
import 'ai_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  
  // Mock user stats
  final int _totalBooks = 24;
  final int _hoursListened = 156;
  final int _currentStreak = 12;
  final int _availableCredits = 3;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await AuthService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  _buildStatsSection(),
                  _buildMenuItems(),
                ],
              ),
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Profile'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _navigateToSettings(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 4,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // User name
                  Text(
                    _currentUser?['display_name'] ?? _currentUser?['email'] ?? 'User',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentUser?['email'] != null)
                    Text(
                      _currentUser!['email'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Credits
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: Theme.of(context).colorScheme.tertiary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_availableCredits Credits',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Listening Stats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.library_books,
                      label: 'Books',
                      value: '$_totalBooks',
                      color: Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.access_time,
                      label: 'Hours',
                      value: '$_hoursListened',
                      color: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.local_fire_department,
                      label: 'Day Streak',
                      value: '$_currentStreak',
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMenuItems() {
    final menuItems = [
      {
        'title': 'AI Personas',
        'subtitle': 'Choose your AI reading companion',
        'icon': Icons.psychology,
        'color': Colors.deepPurple,
        'onTap': () => _navigateToAISettings(),
      },
      {
        'title': 'Purchase Credits',
        'subtitle': 'Buy more audiobook credits',
        'icon': Icons.shopping_cart,
        'color': Colors.green,
        'onTap': () => _navigateToPurchase(),
      },
      {
        'title': 'Wishlist',
        'subtitle': 'Books saved for later',
        'icon': Icons.favorite,
        'color': Colors.red,
        'onTap': () => _navigateToWishlist(),
      },
      {
        'title': 'Listening History',
        'subtitle': 'View your completed books',
        'icon': Icons.history,
        'color': Colors.blue,
        'onTap': () => _navigateToHistory(),
      },
      {
        'title': 'Downloaded Books',
        'subtitle': 'Manage offline content',
        'icon': Icons.download,
        'color': Colors.purple,
        'onTap': () => _navigateToDownloads(),
      },
      {
        'title': 'Account Settings',
        'subtitle': 'Manage your account',
        'icon': Icons.account_circle,
        'color': Colors.indigo,
        'onTap': () => _navigateToAccountSettings(),
      },
      {
        'title': 'App Settings',
        'subtitle': 'Playback and preferences',
        'icon': Icons.settings,
        'color': Colors.grey,
        'onTap': () => _navigateToSettings(),
      },
      {
        'title': 'Help & Support',
        'subtitle': 'Get help and contact support',
        'icon': Icons.help,
        'color': Colors.teal,
        'onTap': () => _navigateToHelp(),
      },
      {
        'title': 'About',
        'subtitle': 'App information and legal',
        'icon': Icons.info,
        'color': Colors.brown,
        'onTap': () => _navigateToAbout(),
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: menuItems.length + 1, // +1 for logout
      itemBuilder: (context, index) {
        if (index == menuItems.length) {
          // Logout item
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Sign out of your account'),
              onTap: _showLogoutDialog,
            ),
          );
        }

        final item = menuItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (item['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item['icon'] as IconData,
                color: item['color'] as Color,
                size: 20,
              ),
            ),
            title: Text(item['title'] as String),
            subtitle: Text(item['subtitle'] as String),
            trailing: const Icon(Icons.chevron_right),
            onTap: item['onTap'] as VoidCallback,
          ),
        );
      },
    );
  }

  void _navigateToAISettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AISettingsScreen()),
    );
  }

  void _navigateToPurchase() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Credits'),
        content: const Text('Credit purchase functionality coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToWishlist() {
    // TODO: Navigate to wishlist screen
    debugPrint('Navigate to wishlist');
  }

  void _navigateToHistory() {
    // TODO: Navigate to listening history
    debugPrint('Navigate to history');
  }

  void _navigateToDownloads() {
    // TODO: Navigate to downloads
    debugPrint('Navigate to downloads');
  }

  void _navigateToAccountSettings() {
    // TODO: Navigate to account settings
    debugPrint('Navigate to account settings');
  }

  void _navigateToSettings() {
    // TODO: Navigate to app settings
    debugPrint('Navigate to settings');
  }

  void _navigateToHelp() {
    // TODO: Navigate to help & support
    debugPrint('Navigate to help');
  }

  void _navigateToAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'EchoWright',
      applicationVersion: '1.0.0',
      applicationIcon: Icon(
        Icons.headphones,
        size: 32,
        color: Theme.of(context).colorScheme.primary,
      ),
      children: [
        const Text('An audiobook platform with AI-powered conversations.'),
        const SizedBox(height: 16),
        const Text('© 2025 EchoWright. All rights reserved.'),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _logout,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    Navigator.pop(context); // Close dialog
    
    try {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }
}