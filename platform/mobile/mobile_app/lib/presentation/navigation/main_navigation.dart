import 'package:flutter/material.dart';
import '../screens/home_tab/home_screen.dart';
import '../screens/library_tab/library_screen.dart';
import '../screens/discover_tab/discover_screen.dart';
import '../screens/profile_tab/profile_screen.dart';
import '../../services/navigation_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late final ValueNotifier<int> _currentIndexNotifier;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndexNotifier = ValueNotifier<int>(0);
    
    // Initialize the navigation service with our tab controller
    NavigationService.initializeTabController(_currentIndexNotifier);
    
    _screens = [
      const HomeScreen(),
      const LibraryScreen(),
      const DiscoverScreen(),
      const ProfileScreen(),
    ];
  }
  
  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _currentIndexNotifier,
      builder: (context, currentIndex, child) {
        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: currentIndex,
            onTap: (index) => _currentIndexNotifier.value = index,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_books),
                label: 'Library',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.explore),
                label: 'Discover',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}