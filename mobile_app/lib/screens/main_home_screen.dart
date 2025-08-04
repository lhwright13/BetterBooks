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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: RetroColors.terminalGradient,
          ),
        ),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _buildFilingSystemTabs(),
    );
  }

  Widget _buildFilingSystemTabs() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(
            color: RetroColors.gridBlue.withOpacity(0.4),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: RetroColors.neonCyan.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildFileTab(0, 'HOME', Icons.terminal, '001'),
          _buildFileTab(1, 'LIBRARY', Icons.folder_open, '002'),
          _buildFileTab(2, 'STORE', Icons.shopping_cart_outlined, '003'),
          _buildFileTab(3, 'PROFILE', Icons.person_outline, '004'),
        ],
      ),
    );
  }

  Widget _buildFileTab(int index, String label, IconData icon, String fileNumber) {
    final isSelected = _currentIndex == index;
    final tabColors = [
      RetroColors.neonCyan,
      RetroColors.phosphorGreen,
      RetroColors.neonOrange,
      RetroColors.neonPink,
    ];
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF16213E) : Color(0xFF0F0F23),
            border: Border.all(
              color: isSelected 
                  ? tabColors[index]
                  : RetroColors.gridBlue.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: tabColors[index].withOpacity(0.3),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ] : null,
          ),
          child: Stack(
            children: [
              // File number tab (like index cards)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: tabColors[index],
                    border: Border.all(
                      color: RetroColors.gridBlue.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    fileNumber,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              
              // Main tab content
              Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected 
                          ? tabColors[index]
                          : RetroColors.terminalAmber.withOpacity(0.6),
                    ),
                    SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? tabColors[index]
                            : RetroColors.terminalAmber.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}