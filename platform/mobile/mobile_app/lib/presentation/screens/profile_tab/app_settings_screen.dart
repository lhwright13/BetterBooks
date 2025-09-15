import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../player/mini_player.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  // Playback settings
  double _playbackSpeed = 1.0;
  bool _autoPlay = true;
  bool _sleepTimer = false;
  int _sleepTimerMinutes = 15;
  
  // Audio settings
  bool _skipSilences = false;
  bool _boostVolume = false;
  
  // Download settings
  bool _wifiOnlyDownloads = true;
  bool _autoDownloadNewChapters = false;
  
  // Notification settings
  bool _pushNotifications = true;
  bool _downloadCompleteNotifications = true;
  bool _newBooksNotifications = false;
  
  // Display settings
  bool _darkMode = false;
  bool _reduceAnimations = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _pushNotifications = prefs.getBool('notifications_enabled') ?? true;
      _wifiOnlyDownloads = prefs.getBool('download_wifi_only') ?? true;
      _autoPlay = prefs.getBool('auto_play') ?? false;
      _sleepTimer = prefs.getBool('sleep_timer') ?? false;
      _autoDownloadNewChapters = prefs.getBool('auto_download_chapters') ?? false;
      _playbackSpeed = prefs.getDouble('playback_speed') ?? 1.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('notifications_enabled', _pushNotifications);
    await prefs.setBool('download_wifi_only', _wifiOnlyDownloads);
    await prefs.setBool('auto_play', _autoPlay);
    await prefs.setBool('sleep_timer', _sleepTimer);
    await prefs.setBool('auto_download_chapters', _autoDownloadNewChapters);
    await prefs.setDouble('playback_speed', _playbackSpeed);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildPlaybackSection(),
                _buildAudioSection(),
                _buildDownloadSection(),
                _buildNotificationSection(),
                _buildDisplaySection(),
                _buildAboutSection(),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildPlaybackSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Playback',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Playback Speed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Playback Speed'),
                DropdownButton<double>(
                  value: _playbackSpeed,
                  items: const [
                    DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                    DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                    DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                    DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                    DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                    DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _playbackSpeed = value!;
                    });
                  },
                ),
              ],
            ),
            
            // Auto-play next chapter
            SwitchListTile(
              title: const Text('Auto-play next chapter'),
              subtitle: const Text('Automatically continue to the next chapter'),
              value: _autoPlay,
              onChanged: (value) {
                setState(() {
                  _autoPlay = value;
                });
              },
            ),
            
            // Sleep Timer
            SwitchListTile(
              title: const Text('Enable sleep timer'),
              subtitle: const Text('Pause playback after a set time'),
              value: _sleepTimer,
              onChanged: (value) {
                setState(() {
                  _sleepTimer = value;
                });
              },
            ),
            
            if (_sleepTimer)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sleep timer duration'),
                    DropdownButton<int>(
                      value: _sleepTimerMinutes,
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 min')),
                        DropdownMenuItem(value: 15, child: Text('15 min')),
                        DropdownMenuItem(value: 30, child: Text('30 min')),
                        DropdownMenuItem(value: 60, child: Text('1 hour')),
                        DropdownMenuItem(value: 120, child: Text('2 hours')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sleepTimerMinutes = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Skip silences'),
              subtitle: const Text('Automatically skip long pauses'),
              value: _skipSilences,
              onChanged: (value) {
                setState(() {
                  _skipSilences = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Boost volume'),
              subtitle: const Text('Enhance audio for better listening'),
              value: _boostVolume,
              onChanged: (value) {
                setState(() {
                  _boostVolume = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloads',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Wi-Fi only downloads'),
              subtitle: const Text('Prevent downloads over mobile data'),
              value: _wifiOnlyDownloads,
              onChanged: (value) {
                setState(() {
                  _wifiOnlyDownloads = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Auto-download new chapters'),
              subtitle: const Text('Automatically download new releases'),
              value: _autoDownloadNewChapters,
              onChanged: (value) {
                setState(() {
                  _autoDownloadNewChapters = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Push notifications'),
              subtitle: const Text('Receive app notifications'),
              value: _pushNotifications,
              onChanged: (value) {
                setState(() {
                  _pushNotifications = value;
                });
              },
            ),
            
            if (_pushNotifications) ...[
              SwitchListTile(
                title: const Text('Download complete'),
                subtitle: const Text('Notify when downloads finish'),
                value: _downloadCompleteNotifications,
                onChanged: (value) {
                  setState(() {
                    _downloadCompleteNotifications = value;
                  });
                },
              ),
              
              SwitchListTile(
                title: const Text('New books'),
                subtitle: const Text('Notify about new book releases'),
                value: _newBooksNotifications,
                onChanged: (value) {
                  setState(() {
                    _newBooksNotifications = value;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Display',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Dark mode'),
              subtitle: const Text('Use dark theme'),
              value: _darkMode,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                });
                // TODO: Apply theme change
              },
            ),
            
            SwitchListTile(
              title: const Text('Reduce animations'),
              subtitle: const Text('Minimize visual effects'),
              value: _reduceAnimations,
              onChanged: (value) {
                setState(() {
                  _reduceAnimations = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              title: const Text('App Version'),
              subtitle: const Text('1.0.0 (Beta)'),
              trailing: const Icon(Icons.info_outline),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'EchoWright',
                  applicationVersion: '1.0.0 (Beta)',
                  applicationIcon: Icon(
                    Icons.headphones,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  children: const [
                    Text('An audiobook platform with AI-powered conversations.'),
                    SizedBox(height: 16),
                    Text('© 2025 EchoWright. All rights reserved.'),
                  ],
                );
              },
            ),
            
            ListTile(
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _launchPrivacyPolicy,
            ),
            
            ListTile(
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _launchTermsOfService,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse('https://echowright.com/privacy');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy Policy coming soon')),
        );
      }
    }
  }

  Future<void> _launchTermsOfService() async {
    final Uri url = Uri.parse('https://echowright.com/terms');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terms of Service coming soon')),
        );
      }
    }
  }
}