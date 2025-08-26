/**
 * main_home_screen.dart - Main navigation container for EchoWright mobile app
 * 
 * This file provides the primary navigation structure for the EchoWright audiobook
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
import '../theme/echowright_theme.dart';

/// Main navigation container with bottom tab bar for primary app sections
/// Provides access to Home, Library, Bookstore, and Profile functionality
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

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
      backgroundColor: EchoWrightTheme.backgroundDark,
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildCleanBottomNavigation(),
    );
  }

  Widget _buildCleanBottomNavigation() {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: EchoWrightTheme.surfaceDark,
        border: Border(
          top: BorderSide(
            color: EchoWrightTheme.dividerDark,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCleanNavTab(0, 'Home', Icons.home_outlined, Icons.home),
          _buildCleanNavTab(1, 'Library', Icons.library_books_outlined, Icons.library_books),
          _buildCleanNavTab(2, 'Store', Icons.storefront_outlined, Icons.storefront),
          _buildCleanNavTab(3, 'Profile', Icons.person_outlined, Icons.person),
        ],
      ),
    );
  }

  Widget _buildCleanNavTab(int index, String label, IconData outlineIcon, IconData filledIcon) {
    final isSelected = _currentIndex == index;
    
    return Flexible(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(top: 7, bottom: 27, left: 4, right: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? filledIcon : outlineIcon,
                size: 24,
                color: isSelected 
                    ? EchoWrightTheme.primaryTurquoise
                    : EchoWrightTheme.textSecondary,
              ),
              SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? EchoWrightTheme.primaryTurquoise
                      : EchoWrightTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}