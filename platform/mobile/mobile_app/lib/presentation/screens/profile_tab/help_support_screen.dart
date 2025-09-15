import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../player/mini_player.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _sendEmail(String email, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch email client');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildQuickHelpSection(context),
                _buildFAQSection(context),
                _buildContactSection(context),
                _buildTechnicalInfoSection(context),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildQuickHelpSection(BuildContext context) {
    final helpItems = [
      {
        'title': 'Getting Started',
        'subtitle': 'Learn the basics of using EchoWright',
        'icon': Icons.play_circle_outline,
        'onTap': () => _showGettingStartedDialog(context),
      },
      {
        'title': 'Download Issues',
        'subtitle': 'Troubleshoot download problems',
        'icon': Icons.download_outlined,
        'onTap': () => _showDownloadHelpDialog(context),
      },
      {
        'title': 'Audio Playback',
        'subtitle': 'Fix audio and playback issues',
        'icon': Icons.headphones_outlined,
        'onTap': () => _showAudioHelpDialog(context),
      },
      {
        'title': 'Account & Billing',
        'subtitle': 'Manage your account and credits',
        'icon': Icons.account_balance_wallet_outlined,
        'onTap': () => _showAccountHelpDialog(context),
      },
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Help',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...helpItems.map((item) => ListTile(
              leading: Icon(item['icon'] as IconData),
              title: Text(item['title'] as String),
              subtitle: Text(item['subtitle'] as String),
              trailing: const Icon(Icons.chevron_right),
              onTap: item['onTap'] as VoidCallback,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection(BuildContext context) {
    final faqItems = [
      {
        'question': 'How do I download books for offline listening?',
        'answer': 'Go to any book in your library and tap the download button. You can also download from the book details page after purchasing.',
      },
      {
        'question': 'How do credits work?',
        'answer': 'Credits are used to purchase audiobooks. Each book typically costs 1 credit. You can buy more credits in your profile.',
      },
      {
        'question': 'Can I listen on multiple devices?',
        'answer': 'Yes! Your account syncs across all your devices. Your progress, library, and settings are automatically synchronized.',
      },
      {
        'question': 'How do I chat with AI personas?',
        'answer': 'While listening to a book, tap the chat icon to start a conversation with book characters or helpful personas.',
      },
      {
        'question': 'What audio formats are supported?',
        'answer': 'EchoWright supports MP3, M4A, and AAC audio formats for the best listening experience.',
      },
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: const Icon(Icons.help_outline),
          children: faqItems
              .map((item) => ExpansionTile(
                    title: Text(
                      item['question']!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          item['answer']!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Support',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email Support'),
              subtitle: const Text('Get help via email (24-48 hour response)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                try {
                  await _sendEmail('support@echowright.com', 'EchoWright Support Request');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open email client')),
                    );
                  }
                }
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Live Chat'),
              subtitle: const Text('Chat with our support team (coming soon)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Live chat coming soon!')),
                );
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Report a Bug'),
              subtitle: const Text('Help us improve the app'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                try {
                  await _sendEmail('bugs@echowright.com', 'Bug Report - EchoWright');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open email client')),
                    );
                  }
                }
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Send Feedback'),
              subtitle: const Text('Share your thoughts and suggestions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                try {
                  await _sendEmail('feedback@echowright.com', 'Feedback - EchoWright');
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open email client')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalInfoSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Technical Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('App Version'),
                Text(
                  '1.0.0 (Beta)',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('API Status'),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGettingStartedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Getting Started'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Sign up or log in to your account\n\n'
            '2. Browse our book catalog\n\n'
            '3. Purchase books with credits\n\n'
            '4. Download books for offline listening\n\n'
            '5. Use the AI chat feature while listening\n\n'
            '6. Enjoy your audiobooks!',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showDownloadHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Issues'),
        content: const SingleChildScrollView(
          child: Text(
            'If downloads are failing:\n\n'
            '• Check your internet connection\n\n'
            '• Ensure you have enough storage space\n\n'
            '• Try pausing and resuming the download\n\n'
            '• Check if Wi-Fi only downloads is enabled in settings\n\n'
            '• Restart the app and try again',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAudioHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Playback Issues'),
        content: const SingleChildScrollView(
          child: Text(
            'If audio is not working:\n\n'
            '• Check your device volume\n\n'
            '• Ensure the book is fully downloaded\n\n'
            '• Try closing and reopening the app\n\n'
            '• Check if other apps can play audio\n\n'
            '• Restart your device\n\n'
            '• Contact support if issues persist',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showAccountHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account & Billing'),
        content: const SingleChildScrollView(
          child: Text(
            'Account Management:\n\n'
            '• View your credit balance in your profile\n\n'
            '• Purchase additional credits as needed\n\n'
            '• Your purchases sync across all devices\n\n'
            '• Contact support for billing issues\n\n'
            '• Account settings are in your profile',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}