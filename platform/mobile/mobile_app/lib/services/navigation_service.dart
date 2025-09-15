import 'package:flutter/material.dart';

/// Service for managing navigation between different tabs and screens
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  /// Global key for the main navigation state
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Callback to switch tabs in the main navigation
  static ValueNotifier<int>? _tabController;
  
  /// Initialize the tab controller
  static void initializeTabController(ValueNotifier<int> controller) {
    _tabController = controller;
  }
  
  /// Switch to a specific tab in the main navigation
  static void switchToTab(int tabIndex) {
    if (_tabController != null) {
      _tabController!.value = tabIndex;
    }
  }
  
  /// Navigate to the Discover tab
  static void goToDiscover() {
    switchToTab(2); // Discover is at index 2
  }
  
  /// Navigate to the Library tab
  static void goToLibrary() {
    switchToTab(1); // Library is at index 1
  }
  
  /// Navigate to the Home tab
  static void goToHome() {
    switchToTab(0); // Home is at index 0
  }
  
  /// Navigate to the Profile tab
  static void goToProfile() {
    switchToTab(3); // Profile is at index 3
  }
  
  /// Push a new screen onto the navigation stack
  static Future<T?> push<T extends Object?>(Widget screen) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      return Navigator.of(context).push<T>(
        MaterialPageRoute(builder: (_) => screen),
      );
    }
    throw StateError('Navigator context not available');
  }
  
  /// Pop the current screen from the navigation stack
  static void pop<T extends Object?>([T? result]) {
    final context = navigatorKey.currentContext;
    if (context != null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop<T>(result);
    }
  }
  
  /// Push and replace the current screen
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    Widget screen, [
    TO? result,
  ]) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      return Navigator.of(context).pushReplacement<T, TO>(
        MaterialPageRoute(builder: (_) => screen),
        result: result,
      );
    }
    throw StateError('Navigator context not available');
  }
  
  /// Push and remove all previous screens
  static Future<T?> pushAndRemoveUntil<T extends Object?>(
    Widget screen,
    bool Function(Route<dynamic>) predicate,
  ) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      return Navigator.of(context).pushAndRemoveUntil<T>(
        MaterialPageRoute(builder: (_) => screen),
        predicate,
      );
    }
    throw StateError('Navigator context not available');
  }
}