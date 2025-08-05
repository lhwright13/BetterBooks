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
import 'package:google_fonts/google_fonts.dart';
import 'home_tab_screen.dart';
import 'library_screen.dart';
import 'bookstore_screen.dart';
import 'user_profile_screen.dart';
import '../theme/retro_theme.dart';

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
      backgroundColor: ArchitecturalColors.pureWhite,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: ArchitecturalColors.primaryGradient,
          ),
        ),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _buildArchitecturalNavigation(),
    );
  }

  Widget _buildArchitecturalNavigation() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: ArchitecturalColors.pureWhite,
        border: Border(
          top: BorderSide(
            color: ArchitecturalColors.lightGray,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: ArchitecturalColors.shadowBlack,
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildArchitecturalTab(0, 'HOME', Icons.home_outlined, Icons.home),
          _buildArchitecturalTab(1, 'LIBRARY', Icons.library_books_outlined, Icons.library_books),
          _buildArchitecturalTab(2, 'STORE', Icons.store_outlined, Icons.store),
          _buildArchitecturalTab(3, 'PROFILE', Icons.person_outline, Icons.person),
        ],
      ),
    );
  }

  Widget _buildArchitecturalTab(int index, String label, IconData outlineIcon, IconData filledIcon) {
    final isSelected = _currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: ArchitecturalAnimations.fast,
          curve: ArchitecturalAnimations.preciseEase,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? ArchitecturalColors.primaryOrange.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border(
              top: BorderSide(
                color: isSelected 
                    ? ArchitecturalColors.primaryOrange
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: ArchitecturalAnimations.fast,
                child: Icon(
                  isSelected ? filledIcon : outlineIcon,
                  key: ValueKey(isSelected),
                  size: 24,
                  color: isSelected 
                      ? ArchitecturalColors.primaryOrange
                      : ArchitecturalColors.mediumGray,
                ),
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? ArchitecturalColors.primaryOrange
                      : ArchitecturalColors.mediumGray,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}