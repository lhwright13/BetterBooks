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
import '../widgets/space_background.dart';

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
      backgroundColor: SpaceColors.creamBg,
      body: SpaceBackground(
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _buildSpaceMissionNavigation(),
    );
  }

  Widget _buildSpaceMissionNavigation() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SpaceColors.warmBeige,
            SpaceColors.creamBg,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: SpaceColors.tealBlue.withOpacity(0.3),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: SpaceColors.orbitGlow,
            blurRadius: 16,
            spreadRadius: 0,
            offset: Offset(0, -6),
          ),
          BoxShadow(
            color: SpaceColors.spaceShadow,
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSpaceMissionTab(0, 'HOME', Icons.home_outlined, Icons.home),
          _buildSpaceMissionTab(1, 'LIBRARY', Icons.library_books_outlined, Icons.library_books),
          _buildSpaceMissionTab(2, 'DISCOVER', Icons.explore_outlined, Icons.explore),
          _buildSpaceMissionTab(3, 'PROFILE', Icons.person_outlined, Icons.person),
        ],
      ),
    );
  }

  Widget _buildSpaceMissionTab(int index, String label, IconData outlineIcon, IconData filledIcon) {
    final isSelected = _currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: SpaceAnimations.fast,
          curve: SpaceAnimations.orbitalEase,
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                SpaceColors.dustyRed.withOpacity(0.15),
                SpaceColors.dustyRed.withOpacity(0.05),
              ],
            ) : null,
            border: Border(
              top: BorderSide(
                color: isSelected 
                    ? SpaceColors.dustyRed
                    : Colors.transparent,
                width: 3,
              ),
            ),
            borderRadius: BorderRadius.circular(SpaceSizes.smallRadius),
            boxShadow: isSelected ? [
              BoxShadow(
                color: SpaceColors.orbitGlow,
                blurRadius: 8,
                spreadRadius: 0,
                offset: Offset(0, -2),
              ),
            ] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: SpaceAnimations.fast,
                child: Container(
                  key: ValueKey(isSelected),
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected 
                        ? SpaceColors.dustyRed.withOpacity(0.2)
                        : Colors.transparent,
                    border: isSelected ? Border.all(
                      color: SpaceColors.tealBlue.withOpacity(0.3),
                      width: 1,
                    ) : null,
                  ),
                  child: Icon(
                    isSelected ? filledIcon : outlineIcon,
                    size: 22,
                    color: isSelected 
                        ? SpaceColors.dustyRed
                        : SpaceColors.systemGray,
                  ),
                ),
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected 
                      ? SpaceColors.dustyRed
                      : SpaceColors.commandGray,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}