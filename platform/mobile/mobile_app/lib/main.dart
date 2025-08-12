/**
 * main.dart - Entry point for the EchoWright mobile application
 * 
 * This is the root file of the EchoWright Flutter app - an AI-powered audiobook 
 * companion that allows users to interact with books through AI personas, 
 * ask questions about content, and enjoy immersive audiobook experiences.
 * 
 * Key responsibilities:
 * - Initialize the Flutter app with Material Design 3
 * - Set up global state management using Provider pattern
 * - Define navigation routes for all app screens
 * - Configure the app's theme and branding
 * 
 * Architecture integration:
 * - Uses Provider for state management across the app
 * - Connects to backend microservices via API calls
 * - Supports multiple AI personas for book interaction
 * - Handles audiobook playback and voice interaction
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/main_home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/enhanced_player_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/user_settings_screen.dart';
import 'theme/modern_theme.dart';

/// Entry point for the EchoWright application
/// Initializes the app and sets up the root widget
void main() {
  runApp(const EchoWrightApp());
}

/// Root widget for the EchoWright application
/// Sets up global state management and navigation routing
class EchoWrightApp extends StatelessWidget {
  const EchoWrightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Create global app state that manages books, personas, and playbook
      create: (context) => AppState(),
      child: MaterialApp(
        title: 'EchoWright',
        // Modern audiobook experience theme
        theme: ModernTheme.theme,
        // Default route opens the main home screen
        initialRoute: '/',
        // Navigation routes for all app screens
        routes: {
          '/': (context) => MainHomeScreen(),        // Home with book library
          '/library': (context) => LibraryScreen(),  // Detailed library view
          '/player': (context) => EnhancedPlayerScreen(), // Audio player with AI
          '/chat': (context) => ChatScreen(),        // AI chat interface
          '/settings': (context) => UserSettingsScreen(), // User preferences
        },
      ),
    );
  }
}
