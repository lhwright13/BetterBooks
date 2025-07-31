/**
 * main_home_screen.dart - Main navigation container for Muuchi mobile app
 * 
 * This file provides the primary navigation structure for the Muuchi audiobook
 * companion app. It implements a bottom tab navigation pattern that allows users
 * to switch between the main functional areas of the application.
 * 
 * Key responsibilities:
 * - Implement bottom tab navigation with 4 main sections
 * - Manage navigation state and tab switching
 * - Provide consistent navigation UI across the app
 * - Coordinate access to Home, Library, Bookstore, and Profile sections
 * 
 * Navigation structure:
 * - Home: Main dashboard with recent activity and quick actions
 * - Library: User's audiobook collection and reading progress
 * - Bookstore: Browse and discover new audiobook content  
 * - Profile: User settings, preferences, and account management
 * 
 * User experience:
 * - Persistent bottom navigation for easy section switching
 * - State preservation when switching between tabs
 * - Intuitive icons and labels for each navigation item
 * - Follows Material Design navigation patterns
 * 
 * Integration points:
 * - Entry point from app startup and authentication
 * - Container for all major app functionality
 * - Navigation context for deep linking and routing
 */

import 'package:flutter/material.dart';
import 'home_tab_screen.dart';
import 'library_screen.dart';
import 'bookstore_screen.dart';
import 'user_profile_screen.dart';

/// Main navigation container with bottom tab bar for primary app sections
/// Provides access to Home, Library, Bookstore, and Profile functionality
class MainHomeScreen extends StatefulWidget {
  @override
  _MainHomeScreenState createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0; // Track which tab is currently selected
  
  // Define the screen widgets for each navigation tab
  // Order matches the bottom navigation bar items
  final List<Widget> _screens = [
    HomeTabScreen(),      // Tab 0: Main dashboard and recent activity
    LibraryScreen(),      // Tab 1: User's audiobook collection  
    BookstoreScreen(),    // Tab 2: Browse and discover new content
    UserProfileScreen(),  // Tab 3: User settings and profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex], // Display the currently selected tab's screen
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Show all tabs, don't animate
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Update selected tab and rebuild UI
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Bookstore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}